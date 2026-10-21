import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/models/retail/hive_model/grn_item_model_214.dart';
import '../../../data/models/retail/hive_model/grn_model_213.dart';
import '../../../data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../store/retail/damaged_goods_store.dart';
import '../restaurant/day_management_service.dart';

/// Outcome of [GrnReceivingService.receive].
class GrnReceiveResult {
  final bool success;
  final String? errorMessage;
  final double acceptedQty;
  final DamagedGoodsOutcome damaged;

  const GrnReceiveResult._({
    required this.success,
    this.errorMessage,
    this.acceptedQty = 0,
    this.damaged = const DamagedGoodsOutcome(),
  });

  factory GrnReceiveResult.failure(String message) =>
      GrnReceiveResult._(success: false, errorMessage: message);
}

/// The one write path for receiving goods against a PO.
///
/// Hive has no transactions, so safety comes from ORDER and IDEMPOTENCE:
///
/// 1. The GRN is written as a **draft** — the "receipt in progress" marker.
/// 2. Stock + cost per line, each followed by a movement with the fixed id
///    `grn_<grnItemId>`; a line whose movement exists is already applied.
/// 3. The supplier accrual, skipped if a `purchase` row for this GRN exists.
/// 4. Damaged-goods documents, skipped if any already exist for this GRN.
/// 5. **Last**, status → confirmed and the PO status update.
///
/// A crash anywhere before 5 leaves a draft; [resumeInterrupted] re-runs the
/// same steps and each one skips what it already did. The only residual
/// window is a crash between a line's stock write and its movement write,
/// which would re-add that one line on resume.
class GrnReceivingService {
  GrnReceivingService._();

  static final StockMovementRepository _movements = StockMovementRepository();

  /// GRN numbers with a receive in progress — a second tap on Confirm
  /// arrives with the same reserved number and is turned away.
  static final Set<String> _inFlight = {};

  static String _movementId(GRNItemModel item) => 'grn_${item.grnItemId}';

  static Future<GrnReceiveResult> receive(
    GRNModel grn,
    List<GRNItemModel> items,
  ) async {
    if (!_inFlight.add(grn.grnNumber)) {
      return GrnReceiveResult.failure('This receipt is already being saved');
    }
    try {
      if (await purchaseOrderStore.isGRNNumberUsed(grn.grnNumber)) {
        return GrnReceiveResult.failure(
            '${grn.grnNumber} has already been received');
      }
      await purchaseOrderStore.createGRN(grn, items);
      final saved = await purchaseOrderStore.getGRNItems(grn.grnId);
      final damaged = await _complete(
        purchaseOrderStore.grns.firstWhere((g) => g.grnId == grn.grnId,
            orElse: () => grn),
        saved,
      );
      return GrnReceiveResult._(
        success: true,
        acceptedQty: saved.fold(0.0, (s, i) => s + _qtyToStock(i)),
        damaged: damaged,
      );
    } finally {
      _inFlight.remove(grn.grnNumber);
    }
  }

  /// Finishes every receipt a crash left as a draft. Returns how many were
  /// completed. Safe to call any time; cheap when there are none.
  static Future<int> resumeInterrupted() async {
    final drafts = await purchaseOrderStore.getDraftGRNs();
    var done = 0;
    for (final grn in drafts) {
      if (!_inFlight.add(grn.grnNumber)) continue;
      try {
        await _complete(grn, await purchaseOrderStore.getGRNItems(grn.grnId));
        done++;
      } catch (e) {
        debugPrint('GRN resume failed for ${grn.grnNumber}: $e');
      } finally {
        _inFlight.remove(grn.grnNumber);
      }
    }
    return done;
  }

  /// The variant's cost after receiving [receivedQty] at [receiptCost] on top
  /// of [onHand] units at [currentCost] — a moving weighted average, the
  /// standard perpetual-inventory cost.
  ///
  /// Overwriting with the latest receipt price re-costed stock already on the
  /// shelf: 100 @ ₹50 then 10 @ ₹80 made all 110 cost ₹80 and understated
  /// profit by ₹3,000; one mistyped receipt re-priced every later sale.
  ///
  /// Nothing on hand to average with (stock ≤ 0, possible since sales may go
  /// negative) or no current cost → the receipt cost. A receipt with no price
  /// leaves the cost as it was (returns [currentCost]).
  static double? weightedAverageCost({
    required double onHand,
    required double? currentCost,
    required double receivedQty,
    required double? receiptCost,
  }) {
    if (receiptCost == null || receiptCost <= 0 || receivedQty <= 0) {
      return currentCost;
    }
    if (onHand <= 0 || currentCost == null || currentCost <= 0) {
      return receiptCost;
    }
    return (onHand * currentCost + receivedQty * receiptCost) /
        (onHand + receivedQty);
  }

  /// Accepted units enter stock; `goodQty` covers rows written before
  /// acceptedQty existed.
  static double _qtyToStock(GRNItemModel item) =>
      item.acceptedQty > 0 ? item.acceptedQty : item.goodQty;

  static Future<DamagedGoodsOutcome> _complete(
    GRNModel grn,
    List<GRNItemModel> items,
  ) async {
    // 2. Stock + cost, one idempotent line at a time.
    final staffName = authService.currentUsername ?? 'Staff';
    final sessionId = await DayManagementService.getCurrentSessionId();
    for (final item in items) {
      final qty = _qtyToStock(item);
      if (qty <= 0 || _movements.contains(_movementId(item))) continue;

      final variant = await productStore.getVariantById(item.variantId);
      if (variant == null) continue;

      // Averaged against the stock on hand BEFORE this receipt is added.
      final newCost = weightedAverageCost(
        onHand: variant.stockQty,
        currentCost: variant.costPrice,
        receivedQty: qty,
        receiptCost: item.costPrice,
      );
      final newStock = variant.stockQty + qty;
      await productStore.updateVariantStock(item.variantId, newStock);
      if (newCost != null && newCost != variant.costPrice) {
        await productStore.updateVariantCostPrice(item.variantId, newCost);
      }

      await _movements.saveMovement(StockMovementModel(
        id: _movementId(item),
        timestamp: DateTime.now(),
        itemId: item.productId,
        variantId: item.variantId,
        itemName: item.variantInfo == null || item.variantInfo!.isEmpty
            ? (item.productName ?? 'Item')
            : '${item.productName ?? 'Item'} (${item.variantInfo})',
        type: 'in',
        quantity: qty,
        balanceAfter: newStock,
        reason: 'Goods received',
        note: '${grn.grnNumber} · ${grn.poNumber}',
        unit: variant.isDecimalQuantity ? variant.effectiveUnit : 'pcs',
        staffName: staffName,
        sessionId: sessionId,
        unitCost: item.costPrice,
      ));
    }

    // 3. Accrue the full delivered value (damaged units included — they are
    //    recovered later by a credit note or a settled claim).
    if (!supplierStore.hasLedgerEntryForDoc(grn.grnId, SupplierLedgerType.purchase)) {
      await supplierStore.recordBalanceMovement(
        supplierId: grn.supplierId,
        amount: grn.totalAmount ?? 0,
        type: SupplierLedgerType.purchase,
        description: 'Goods received against ${grn.poNumber}',
        docNumber: grn.grnNumber,
        docId: grn.grnId,
        date: grn.receivedDate,
      );
    }

    // 4. Damaged-goods documents. recordFromGRN never throws.
    var damaged = const DamagedGoodsOutcome();
    if (!await damagedGoodsStore.hasDocumentsForGRN(grn.grnId)) {
      damaged = await damagedGoodsStore.recordFromGRN(grn: grn, items: items);
    }

    // 5. Only now is the receipt confirmed and counted against the PO.
    await purchaseOrderStore.confirmGRN(grn.grnId);
    return damaged;
  }
}
