import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/hive_box_names.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/restaurant_grn_item_model.dart';
import '../../../data/models/restaurant/db/restaurant_grn_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../store/restaurant/restaurant_purchase_order_store.dart';
import 'day_management_service.dart';
import 'stock_journal.dart';

/// Thrown by a [RestaurantGrnReceiving.failAtForTesting] checkpoint — stands
/// in for the app stopping at that point.
class GrnInterruptedForTesting implements Exception {
  final String checkpoint;
  GrnInterruptedForTesting(this.checkpoint);
  @override
  String toString() => 'GRN interrupted at $checkpoint (test)';
}

/// Finishes a Restaurant goods receipt (GRN) that was saved as a DRAFT.
///
/// Hive has no transactions across boxes, so safety comes from ORDER and
/// IDEMPOTENCE. `RestaurantPurchaseOrderStore.confirmGRN` saves the header as
/// a draft and its lines, then calls [complete], which runs:
///
/// 1. **Stock**, one line at a time, each exactly once (below).
/// 2. **Supplier payable**, once per GRN
///    (`RestaurantSupplierStore.recordBalanceMovementOnce`).
/// 3. **Damaged-goods documents**, once per type
///    (`RestaurantDamagedGoodsStore.ensureDocumentsForGRN`).
/// 4. **Last**, status → confirmed, then the PO status (BLK-17). Until then
///    the receipt counts nowhere: PO completion reads confirmed GRNs only.
///
/// A stop anywhere before 4 leaves a draft; `resumeInterruptedReceipts`
/// (startup, and the purchase screens) runs [complete] again, and every step
/// skips what it already did.
///
/// **Stock exactly once.** The stock write (items box) and its movement row
/// (movements box) cannot be one atomic write. Each line therefore keeps a
/// durable INTENT in the stock-journal box under `grn:<grnItemId>`, the same
/// method `StockJournal` uses for sales:
///
/// * Inside the item's stock queue, before the stock write, the intent is
///   saved as `applying` with the balance before and after.
/// * After the write it becomes `written`; then the movement row (fixed id
///   `rgrn_<grnItemId>`) is saved and the intent deleted.
///
/// On a re-run: movement row exists → done. `written` → write the row only.
/// `applying` → decided from the stock: equal to `after` → the write happened,
/// write the row only; equal to `before` → it did not, apply it; anything
/// else → `review`: the line is NOT re-applied, and a "Stock Check Needed"
/// alert asks for a count. So a line's stock is never added twice; the only
/// outcome that is not automatic is flagged, never guessed.
class RestaurantGrnReceiving {
  RestaurantGrnReceiving._();

  static const String applying = 'applying';
  static const String written = 'written';
  static const String review = 'review';

  static const double _eps = 1e-9;

  /// Checkpoint to stop at, for fault-injection tests only.
  @visibleForTesting
  static String? failAtForTesting;

  /// How many hits of [failAtForTesting] to pass before stopping — 1 stops
  /// on the second line's checkpoint instead of the first.
  @visibleForTesting
  static int failSkipForTesting = 0;

  /// A no-op unless a test set [failAtForTesting] to [name]. Also called by
  /// `confirmGRN` for the header and lines checkpoints.
  static void checkpoint(String name) {
    if (failAtForTesting != name) return;
    if (failSkipForTesting > 0) {
      failSkipForTesting--;
      return;
    }
    throw GrnInterruptedForTesting(name);
  }

  static void _checkpoint(String name) => checkpoint(name);

  /// GRNs being completed right now — a resume never runs one twice at once.
  static final Set<String> _completing = {};

  static Box get _journal => Hive.box(HiveBoxNames.restaurantStockJournal);

  static String intentKey(String grnItemId) =>
      '${StockJournal.grnKeyPrefix}$grnItemId';

  static String movementId(String grnItemId) => 'rgrn_$grnItemId';

  /// The persisted intent for a line, or null.
  static Map<String, dynamic>? intentFor(String grnItemId) {
    final raw = _journal.get(intentKey(grnItemId));
    return raw == null ? null : Map<String, dynamic>.from(raw as Map);
  }

  static bool isCompleting(String grnId) => _completing.contains(grnId);

  /// Runs steps 1–4 for [grn]. Throws on a failure, leaving the draft for the
  /// next attempt. Returns false without doing anything when [grn] is
  /// already being completed.
  ///
  /// [lines] in the order they were entered — the box returns them by key,
  /// and with two lines for one item the LAST cost must win. A resume passes
  /// none and falls back to creation time.
  static Future<bool> complete(RestaurantGRNModel grn,
      {List<RestaurantGRNItemModel>? lines}) async {
    if (!_completing.add(grn.grnId)) return false;
    try {
      final items = lines ??
          (restaurantGrnItemRepository.getItemsByGRNId(grn.grnId)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

      // A stop while the lines were being saved: the header's totals name
      // lines that never landed. Nothing has been applied yet — stock starts
      // only after every line is saved — so the draft is cancelled (it
      // counts nowhere) and the goods are received again. Billing the
      // header's full amount against a partial receipt would be wrong.
      if (lines == null && !_linesComplete(grn, items)) {
        await restaurantGrnRepository.saveGRN(grn.copyWith(
          status: RestaurantGRNStatus.cancelled.name,
          notes: [
            if ((grn.notes ?? '').isNotEmpty) grn.notes!,
            interruptedNote,
          ].join(' — '),
        ));
        return true;
      }

      // 1. Stock, once per line.
      final staffName =
          RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
      final sessionId = await DayManagementService.getCurrentSessionId();
      final movements = StockMovementRepository();
      for (final line in items) {
        await _applyLine(grn, line, movements, staffName, sessionId);
      }
      _checkpoint('afterStock');

      // 2. Supplier payable — the full delivered value, damaged units
      //    included (credited back when a return or claim settles).
      final amount = grn.totalAmount ?? 0;
      if (amount > 0) {
        await restaurantSupplierStore.recordBalanceMovementOnce(
          supplierId: grn.supplierId,
          amount: amount,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'Goods received',
          docNumber: grn.grnNumber,
          docId: grn.grnId,
          date: grn.receivedDate,
        );
      }
      _checkpoint('afterLedger');

      // 3. Damaged-goods documents. Only reached when something was marked
      //    damaged, so a receipt without damage never touches those boxes.
      if (items.any((i) => (i.damagedQty ?? 0) > 0 && i.damagedHandling != null)) {
        await restaurantDamagedGoodsStore.ensureDocumentsForGRN(
            grn: grn, items: items);
      }
      _checkpoint('afterDamaged');

      // 4. Only now is the receipt confirmed and counted against the PO.
      final current = restaurantGrnRepository.getGRNById(grn.grnId) ?? grn;
      await restaurantGrnRepository.saveGRN(
          current.copyWith(status: RestaurantGRNStatus.confirmed.name));

      final po = restaurantPurchaseOrderRepository.getPurchaseOrderById(grn.poId);
      if (po != null) {
        final newStatus = RestaurantPORules.statusAfterReceipt(po);
        if (newStatus != po.statusEnum) {
          await restaurantPurchaseOrderRepository
              .savePurchaseOrder(po.copyWith(status: newStatus.name));
        }
      }
      return true;
    } finally {
      _completing.remove(grn.grnId);
    }
  }

  /// Note left on a draft cancelled because its lines never finished saving.
  static const String interruptedNote =
      'Cancelled automatically: interrupted before all lines were saved. '
      'Receive these goods again.';

  /// Whether every line the header was built from is on disk. The header's
  /// totals are folds over exactly those lines, and only lines with a
  /// received quantity are saved, so a missing line always shows as a
  /// shortfall. Once any line's stock work has started, all lines were saved.
  static bool _linesComplete(
      RestaurantGRNModel grn, List<RestaurantGRNItemModel> items) {
    final started = items.any((i) =>
        _journal.containsKey(intentKey(i.grnItemId)) ||
        StockMovementRepository().contains(movementId(i.grnItemId)));
    if (started) return true;
    final received = items.fold<double>(0, (s, i) => s + i.receivedQty);
    final amount =
        items.fold<double>(0, (s, i) => s + i.receivedQty * (i.costPrice ?? 0));
    return (received - grn.totalReceivedQty).abs() < 1e-4 &&
        (amount - (grn.totalAmount ?? 0)).abs() < 1e-4 &&
        items.isNotEmpty;
  }

  static Future<void> _applyLine(
    RestaurantGRNModel grn,
    RestaurantGRNItemModel line,
    StockMovementRepository movements,
    String staffName,
    String? sessionId,
  ) async {
    final qty = line.acceptedQty;
    if (qty <= 0) return;

    final key = intentKey(line.grnItemId);
    final rowId = movementId(line.grnItemId);
    if (movements.contains(rowId)) {
      // Done before the stop; only the intent clean-up may be missing.
      if (_journal.containsKey(key)) await _journal.delete(key);
      return;
    }

    final item = itemStore.getItemById(line.itemId);
    if (item == null) return;
    // BLK-18: an item with variants is stocked per variant, and this line has
    // no variant — adding to the item's own stock would put units where
    // nothing sells from. Only reachable for an order written before the PO
    // picker excluded such items; the receipt and payable still stand.
    if (item.hasVariants) return;

    final intent = intentFor(line.grnItemId);
    final state = intent?['state'] as String?;
    if (state == review) return; // Flagged already; never re-applied.

    if (state == written) {
      await _writeMovement(grn, line, item.id, item.name, item.unit,
          (intent!['after'] as num).toDouble(), movements, staffName, sessionId);
      return;
    }

    if (state == applying) {
      final before = (intent!['before'] as num).toDouble();
      final after = (intent['after'] as num).toDouble();
      final current = item.stockQuantity;
      if ((current - after).abs() < _eps) {
        // The stop came after the stock write: only the row is missing.
        await _writeMovement(grn, line, item.id, item.name, item.unit, after,
            movements, staffName, sessionId);
        return;
      }
      if ((current - before).abs() >= _eps) {
        // Stock moved since, so whether this line landed cannot be read from
        // it. Never guess — and never add it a second time.
        await _journal.put(key, {...intent, 'state': review});
        await _raiseReview(grn, line, item.name, item.unit);
        return;
      }
      // Still == before: the write never happened. Apply it below.
    }

    final balance = await itemStore.applyStockDelta(
      itemId: line.itemId,
      delta: qty,
      lastPurchaseCost: line.costPrice,
      beforePersist: (before, after) async {
        await _journal.put(key, {
          'state': applying,
          'grnId': grn.grnId,
          'before': before,
          'after': after,
        });
        _checkpoint('beforeStockWrite');
      },
    );
    _checkpoint('afterStockWrite');

    // Known in-process: the stock write happened. From here a re-run only
    // ever writes the movement row — never the stock again.
    await _journal.put(key, {
      'state': written,
      'grnId': grn.grnId,
      'before': balance - qty,
      'after': balance,
    });
    _checkpoint('afterStockWritten');

    await _writeMovement(grn, line, item.id, item.name, item.unit, balance,
        movements, staffName, sessionId);
  }

  static Future<void> _writeMovement(
    RestaurantGRNModel grn,
    RestaurantGRNItemModel line,
    String itemId,
    String itemName,
    String? unit,
    double balanceAfter,
    StockMovementRepository movements,
    String staffName,
    String? sessionId,
  ) async {
    await movements.saveMovement(StockMovementModel(
      id: movementId(line.grnItemId),
      timestamp: DateTime.now(),
      itemId: itemId,
      variantId: null,
      itemName: itemName,
      type: 'in',
      quantity: line.acceptedQty,
      balanceAfter: balanceAfter,
      reason: 'Purchase (${grn.poNumber})',
      unit: unit ?? 'pcs',
      staffName: staffName,
      sessionId: sessionId,
    ));
    _checkpoint('afterMovement');
    await _journal.delete(intentKey(line.grnItemId));
  }

  static Future<void> _raiseReview(RestaurantGRNModel grn,
      RestaurantGRNItemModel line, String itemName, String? unit) async {
    try {
      await notificationStore.raiseEvent(
        eventCode: StockJournal.reviewEvent,
        subjectType: 'grn_stock_line',
        subjectId: line.grnItemId,
        data: {
          'name': itemName,
          'qty': line.acceptedQty,
          'unit': unit ?? 'pcs',
          'reason': 'Purchase (${grn.poNumber}) ${grn.grnNumber}',
          'context': 'goods receipt',
        },
      );
    } catch (e) {
      // The intent stays `review` either way.
      debugPrint('GRN stock review alert failed: $e');
    }
  }
}
