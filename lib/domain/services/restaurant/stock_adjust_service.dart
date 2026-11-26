import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/restaurant_inventory_loss_repository.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../../util/restaurant/staticswitch.dart';
import '../common/document_number_service.dart';
import 'day_management_service.dart';
import 'inventory_service.dart';

/// Safe variant-name lookup — returns 'Variant' if not found instead of
/// crashing on an empty catalog (e.g. variant deleted while still on an item).
String _variantNameOf(String variantId) {
  for (final v in variantStore.variants) {
    if (v.id == variantId) return v.name;
  }
  return 'Variant';
}

/// A single item (or variant) that needs attention on the low-stock screen.
class StockAlertEntry {
  final Items item;
  final ItemVariante? variant;
  final double stock;

  StockAlertEntry({required this.item, this.variant, required this.stock});

  bool get isOut => stock <= 0;
  String? get variantName =>
      variant == null ? null : _variantNameOf(variant!.variantId);
}

/// Shared logic for manual stock adjustments so every screen records the
/// movement the same way (manage inventory, low-stock screen, etc.).
class StockAdjustService {
  static final StockMovementRepository _repo = StockMovementRepository();
  static final RestaurantInventoryLossRepository _lossRepo =
      RestaurantInventoryLossRepository();
  static final DocumentNumberService _numbers = DocumentNumberService();

  /// Removal reasons (from `manage_Inventory.dart`'s reason dropdown) that
  /// represent a genuine business loss rather than a bookkeeping fix or an
  /// internal transfer — these also write a [RestaurantInventoryLossModel]
  /// so the cost reaches the food-cost/wastage reports. Mirrors retail's
  /// `StockAdjustmentReason.isLoss`.
  static const Set<String> lossReasons = {
    'Wastage / Spoilage',
    'Theft / Loss',
    'Sample / Complimentary',
  };

  static bool isLossReason(String reason) => lossReasons.contains(reason);

  /// The manual add / remove reasons offered by Manage Inventory and the
  /// Low Stock screen — one list, so both screens say the same thing.
  static const List<String> addReasons = [
    'Restock / Purchase',
    'Customer return',
    'Stock correction',
    'Transfer in',
    'Other',
  ];
  static const List<String> removeReasons = [
    'Wastage / Spoilage',
    'Theft / Loss',
    'Stock correction',
    'Transfer out',
    'Sample / Complimentary',
    'Other',
  ];

  /// Moves [item]'s stock (or [variant]'s) by [delta] and records why — THE
  /// write for every manual adjustment. Returns the new balance.
  ///
  /// The stock goes through [ItemStore.applyStockDelta], the same queued
  /// write sales use: it re-reads the live balance, so a screen's stale copy
  /// of [item] can never overwrite a sale or another adjustment, and it keeps
  /// a variant's own tracking flag. The history row is written only after
  /// the stock is stored, from the balance actually stored.
  ///
  /// Refuses (nothing written): made-to-order items, a removal that would go
  /// below zero (checked on the live balance), and a [unitCost] that is not
  /// above zero. [unitCost] — a purchase price, e.g. for "Restock /
  /// Purchase" — becomes the item's `lastPurchaseCost` in the same write.
  static Future<double> adjustBy({
    required Items item,
    ItemVariante? variant,
    required double delta,
    required String reason,
    String? note,
    double? unitCost,
    String? movementId,
  }) async {
    if (item.isMadeToOrder) {
      throw StateError('${item.name} is made to order and has no stock of its own');
    }
    if (unitCost != null && !(unitCost > 0)) {
      throw ArgumentError.value(unitCost, 'unitCost', 'must be above zero');
    }
    if (delta == 0) {
      return variant != null
          ? (variant.stockQuantity ?? 0)
          : item.stockQuantity;
    }

    // Turning tracking on is a menu edit, so it goes through the gated
    // update — and stops here if that is refused, before any stock moves.
    final live = itemStore.getItemById(item.id);
    if (live == null) {
      throw StateError('${item.name} no longer exists');
    }
    if (!live.trackInventory) {
      final ok = await itemStore.updateItem(live.copyWith(trackInventory: true));
      if (!ok) {
        throw StateError(itemStore.errorMessage ??
            'Stock tracking could not be turned on for ${item.name}');
      }
    }

    final balanceAfter = await itemStore.applyStockDelta(
      itemId: item.id,
      variantId: variant?.variantId,
      delta: delta,
      lastPurchaseCost: unitCost,
      beforePersist: (_, after) async {
        if (delta < 0 && after < 0) {
          throw StateError('Not enough stock of ${item.name} to remove '
              '${_fmtQty(-delta)}');
        }
      },
    );

    final sessionId = await DayManagementService.getCurrentSessionId();
    await _repo.saveMovement(StockMovementModel(
      id: movementId ?? const Uuid().v4(),
      timestamp: DateTime.now(),
      itemId: item.id,
      variantId: variant?.variantId,
      itemName: variant != null
          ? '${item.name} (${_variantNameOf(variant.variantId)})'
          : item.name,
      type: delta > 0 ? 'in' : 'out',
      quantity: delta.abs(),
      balanceAfter: balanceAfter,
      reason: reason,
      note: note,
      unit: item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs'),
      staffName: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
      sessionId: sessionId,
      unitCost: unitCost,
    ));

    if (delta < 0 && isLossReason(reason)) {
      await recordLoss(
        item: item,
        variant: variant,
        quantity: -delta,
        reason: reason,
        note: note,
      );
    }
    return balanceAfter;
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Writes the cost side of a loss-bearing removal. Never moves stock —
  /// the caller has already done that; this only records the money. Returns
  /// the loss number, or null if [quantity] is zero/negative.
  static Future<String?> recordLoss({
    required Items item,
    ItemVariante? variant,
    required double quantity,
    required String reason,
    String? note,
  }) async {
    if (quantity <= 0) return null;
    final number = await _numbers.next('LOSS');
    final loss = RestaurantInventoryLossModel.create(
      lossNumber: number,
      source: RestaurantInventoryLossSource.stockAdjustment,
      itemId: item.id,
      itemName: variant != null
          ? '${item.name} (${_variantNameOf(variant.variantId)})'
          : item.name,
      quantity: quantity,
      costPrice: item.lastPurchaseCost,
      reason: reason,
      note: note,
    );
    await _lossRepo.save(loss);
    return number;
  }

  /// Every item/variant currently low or out of stock (opted-in only).
  /// Used by both the inventory alert badge and the low-stock screen so the
  /// count and the list always agree.
  ///
  /// Recipe-Based items are measured on how many their ingredients can make
  /// (via [InventoryService.effectiveAvailableStock]) rather than on a
  /// `stockQuantity` they never populate — otherwise a Burger with a full
  /// pantry would be reported out of stock forever. Their `trackInventory`
  /// flag is not a gate for the same reason it isn't at the POS: their
  /// ingredients carry their own tracking flags. Every other product type
  /// takes exactly the path it took before.
  static List<StockAlertEntry> lowStockEntries() {
    final result = <StockAlertEntry>[];
    for (final item in itemStore.items) {
      if (!InventoryService.isStockGoverned(item) ||
          !item.lowStockAlertEnabled ||
          !AppSettings.lowStockAlertsEnabled) {
        continue;
      }
      final threshold = item.effectiveLowStockThreshold;
      if (InventoryService.usesDerivedAvailability(item)) {
        final available = InventoryService.effectiveAvailableStock(item);
        // Infinite = nothing constrains it; never an alert.
        if (available.isFinite && (available <= 0 || available <= threshold)) {
          result.add(StockAlertEntry(item: item, stock: available));
        }
      } else if (item.hasVariants) {
        for (final v in item.variant!) {
          final qty = v.stockQuantity ?? 0;
          if (qty <= 0 || qty <= threshold) {
            result.add(StockAlertEntry(item: item, variant: v, stock: qty));
          }
        }
      } else {
        final qty = item.stockQuantity;
        if (qty <= 0 || qty <= threshold) {
          result.add(StockAlertEntry(item: item, stock: qty));
        }
      }
    }
    return result;
  }

  /// Record the item's opening stock (set at creation) as a movement so it
  /// shows in history instead of being a silent balance. No-op if not tracking
  /// or no opening stock. The stock is already on the item — this only logs.
  static Future<void> recordOpeningStock(Items item) async {
    if (!item.trackInventory) return;
    final sessionId = await DayManagementService.getCurrentSessionId();
    final staff = RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');

    if (item.hasVariants) {
      // Variant items track per variant — log each variant's opening stock.
      for (final v in item.variant!) {
        final qty = v.stockQuantity ?? 0;
        if (qty <= 0) continue;
        final vName = _variantNameOf(v.variantId);
        await _repo.saveMovement(StockMovementModel(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          itemId: item.id,
          variantId: v.variantId,
          itemName: '${item.name} ($vName)',
          type: 'in',
          quantity: qty,
          balanceAfter: qty,
          reason: 'Opening stock',
          unit: unit,
          staffName: staff,
          sessionId: sessionId,
        ));
      }
      return;
    }

    if (item.stockQuantity <= 0) return;
    await _repo.saveMovement(StockMovementModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      itemId: item.id,
      itemName: item.name,
      type: 'in',
      quantity: item.stockQuantity,
      balanceAfter: item.stockQuantity,
      reason: 'Opening stock',
      unit: unit,
      staffName: staff,
      sessionId: sessionId,
    ));
  }

  /// Log a stock adjustment when a level was set directly (e.g. edited on the
  /// item screen) — records the in/out delta so the history & running balance
  /// stay honest. No-op if nothing changed. Does NOT mutate stock (already set).
  static Future<void> logAdjustment({
    required Items item,
    String? variantId,
    required double oldStock,
    required double newStock,
    String reason = 'Stock correction',
  }) async {
    if (oldStock == newStock) return;
    final isIn = newStock > oldStock;
    final sessionId = await DayManagementService.getCurrentSessionId();
    await _repo.saveMovement(StockMovementModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      itemId: item.id,
      variantId: variantId,
      itemName: variantId != null
          ? '${item.name} (${_variantNameOf(variantId)})'
          : item.name,
      type: isIn ? 'in' : 'out',
      quantity: (newStock - oldStock).abs(),
      balanceAfter: newStock,
      reason: reason,
      unit: item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs'),
      staffName: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
      sessionId: sessionId,
    ));
  }

  /// Add [qty] to an item (or a specific variant) and log the movement.
  /// Returns the new balance. See [adjustBy].
  ///
  /// Throws [StateError] for a made-to-order item before any write: its
  /// availability comes from ingredients, so a stored quantity would be
  /// phantom stock.
  static Future<double> addStock({
    required Items item,
    ItemVariante? variant,
    required double qty,
    required String reason,
    String? note,
  }) =>
      adjustBy(
        item: item,
        variant: variant,
        delta: qty,
        reason: reason,
        note: note,
      );

  /// Set [item] (or one of its variants) to an absolute [newStock] level and
  /// log the delta as a movement — used by stock-take commit, where each line
  /// already carries the target quantity rather than an amount to add/remove.
  /// Also writes a loss row when [reason] is loss-bearing and stock went
  /// down, exactly as a manual removal from `manage_Inventory.dart` would.
  ///
  /// No-op (returns `true` without writing anything) when [newStock] already
  /// matches the current level.
  ///
  /// [movementId] makes a batch caller (stock-take commit) idempotent: if a
  /// movement with that id already exists, the adjustment was applied before
  /// a crash and nothing is written again.
  static Future<bool> adjustTo({
    required Items item,
    ItemVariante? variant,
    required double newStock,
    required String reason,
    String? note,
    String? movementId,
  }) async {
    if (movementId != null && _repo.contains(movementId)) return true;
    if (newStock < 0) return false;

    // The difference from the LIVE level, not from [item] (the caller's copy
    // may be older than a sale made since), applied through [adjustBy].
    final live = itemStore.getItemById(item.id) ?? item;
    final liveVariant = variant == null
        ? null
        : live.variant
            ?.where((v) => v.variantId == variant.variantId)
            .firstOrNull;
    final oldStock = variant != null
        ? (liveVariant?.stockQuantity ?? variant.stockQuantity ?? 0)
        : live.stockQuantity;
    if (newStock == oldStock) return true;

    await adjustBy(
      item: live,
      variant: liveVariant ?? variant,
      delta: newStock - oldStock,
      reason: reason,
      note: note,
      movementId: movementId,
    );
    return true;
  }
}
