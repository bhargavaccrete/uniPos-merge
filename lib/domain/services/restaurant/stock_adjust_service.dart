import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'day_management_service.dart';

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

  /// Every item/variant currently low or out of stock (opted-in only).
  /// Used by both the inventory alert badge and the low-stock screen so the
  /// count and the list always agree.
  static List<StockAlertEntry> lowStockEntries() {
    final result = <StockAlertEntry>[];
    for (final item in itemStore.items) {
      if (!item.trackInventory ||
          !item.lowStockAlertEnabled ||
          !AppSettings.lowStockAlertsEnabled) {
        continue;
      }
      final threshold = item.effectiveLowStockThreshold;
      if (item.hasVariants) {
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
  /// Returns the new balance.
  static Future<double> addStock({
    required Items item,
    ItemVariante? variant,
    required double qty,
    required String reason,
    String? note,
  }) async {
    double balanceAfter;

    if (variant != null) {
      final updatedVariants = item.variant?.map((v) {
        if (v.variantId == variant.variantId) {
          return ItemVariante(
            variantId: v.variantId,
            price: v.price,
            stockQuantity: (v.stockQuantity ?? 0) + qty,
          );
        }
        return v;
      }).toList();
      balanceAfter = (variant.stockQuantity ?? 0) + qty;
      await itemStore.updateItem(item.copyWith(
        trackInventory: true,
        variant: updatedVariants,
      ));
    } else {
      balanceAfter = item.stockQuantity + qty;
      await itemStore.updateItem(item.copyWith(
        trackInventory: true,
        stockQuantity: balanceAfter,
      ));
    }

    final sessionId = await DayManagementService.getCurrentSessionId();
    await _repo.saveMovement(StockMovementModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      itemId: item.id,
      variantId: variant?.variantId,
      itemName: variant != null
          ? '${item.name} (${_variantNameOf(variant.variantId)})'
          : item.name,
      type: 'in',
      quantity: qty,
      balanceAfter: balanceAfter,
      reason: reason,
      note: note,
      unit: item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs'),
      staffName: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
      sessionId: sessionId,
    ));

    return balanceAfter;
  }
}
