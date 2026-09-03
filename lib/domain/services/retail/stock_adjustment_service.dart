import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../restaurant/day_management_service.dart';
import 'stock_adjustment_reason.dart';

/// Outcome of an adjustment attempt, so the caller can report precisely.
class StockAdjustmentResult {
  final bool success;
  final String? errorMessage;

  /// Stock level after the adjustment was applied.
  final double? balanceAfter;

  /// Loss number (`LOSS-…`) when the reason was loss-bearing, else null.
  final String? lossNumber;

  const StockAdjustmentResult({
    required this.success,
    this.errorMessage,
    this.balanceAfter,
    this.lossNumber,
  });

  factory StockAdjustmentResult.failure(String message) =>
      StockAdjustmentResult(success: false, errorMessage: message);
}

/// The only sanctioned way to change retail stock outside a document.
///
/// Every other stock movement in retail has a document behind it — a GRN
/// receives, a sale sells, a sale return takes back. Manual correction was the
/// one gap, and before this service it was done by typing over `stockQty` in
/// the Edit Variant form: no reason, no audit row, no before/after. That made
/// the low-stock and profit reports impossible to explain.
///
/// **Three writes, in this order, and never partially.**
/// 1. Move the stock (`ProductStore.updateVariantStock`).
/// 2. Append an audit row ([StockMovementModel]) with reason, who and balance.
/// 3. If the reason is loss-bearing AND stock went down, record the cost as an
///    `InventoryLossModel` via `DamagedGoodsStore`.
///
/// Step 3 is what keeps breakage out of "miscount" territory: both remove
/// units, only one is an expense. See [StockAdjustmentReason.isLoss].
///
/// **Why the audit row reuses restaurant's [StockMovementModel].** Its adapter
/// (typeId 126) is already registered and its box already opened in retail mode
/// by `HiveInit`, and it already carries variantId / type / quantity /
/// balanceAfter / reason / note / staffName. A parallel retail-only model would
/// duplicate all of that. The restaurant-shaped names map directly: `itemId` is
/// the productId, `itemName` the product plus variant descriptor.
class StockAdjustmentService {
  StockAdjustmentService._();

  static final StockMovementRepository _movements = StockMovementRepository();

  /// Fallback unit for the movement log when the variant carries none.
  /// A decimal variant logs its own unit (kg, liter, …) instead.
  static const String _unit = 'pcs';

  /// Admin and Manager may adjust stock; a Cashier may not. An adjustment can
  /// make missing goods vanish from the books, so it stays a manager-level
  /// action.
  ///
  /// Resolved from the signed-in staff member's ROLE. This used to compare
  /// `authService.currentUsername == 'Admin'` — a display name — which denied
  /// Managers too, and decided a privilege question on a label.
  static bool get canAdjust => RestaurantSession.canAccess('inventoryAdjust');

  /// Apply a manual adjustment to [variant]'s stock.
  ///
  /// [newStock] is the absolute level the user wants, not a delta — that is
  /// what a stock count produces, and it keeps the "no change" case trivial to
  /// detect. Pass the [reason] the user picked; [note] is required when
  /// [StockAdjustmentReason.requiresNote] is set.
  static Future<StockAdjustmentResult> adjust({
    required VarianteModel variant,
    required double newStock,
    required StockAdjustmentReason reason,
    String? note,
  }) async {
    if (!canAdjust) {
      return StockAdjustmentResult.failure(
        'Only the admin can adjust stock.',
      );
    }

    if (newStock < 0) {
      return StockAdjustmentResult.failure('Stock cannot be negative.');
    }

    final oldStock = variant.stockQty;
    if (newStock == oldStock) {
      return StockAdjustmentResult.failure(
        'New stock is the same as current stock.',
      );
    }

    final trimmedNote = note?.trim();
    if (reason.requiresNote && (trimmedNote == null || trimmedNote.isEmpty)) {
      return StockAdjustmentResult.failure(
        'A note is required for "${reason.label}".',
      );
    }

    final delta = newStock - oldStock;
    final isIncrease = delta > 0;

    // A loss-bearing reason only costs money when units actually left.
    final recordsLoss = reason.isLoss && !isIncrease;

    try {
      // 1. Move the stock. Through the store, so every Observer watching
      //    inventory repaints — a direct repository write would leave the
      //    in-memory variant stale.
      await productStore.updateVariantStock(variant.varianteId, newStock);

      // 2. Audit row. Written after the move so a failed move never leaves a
      //    log entry claiming a change that did not happen.
      final product = productStore.products.firstWhere(
        (p) => p.productId == variant.productId,
        orElse: () => throw StateError('Product not found'),
      );
      final label = variant.hasAttributes
          ? '${product.productName} (${variant.variantDescription})'
          : product.productName;

      await _movements.saveMovement(StockMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: variant.productId,
        variantId: variant.varianteId,
        itemName: label,
        type: isIncrease ? 'in' : 'out',
        quantity: delta.abs().toDouble(),
        balanceAfter: newStock.toDouble(),
        reason: reason.label,
        note: trimmedNote?.isEmpty ?? true ? null : trimmedNote,
        unit: variant.isDecimalQuantity ? variant.effectiveUnit : _unit,
        staffName: authService.currentUsername ?? 'Admin',
        sessionId: await DayManagementService.getCurrentSessionId(),
      ));

      // 3. Cost side, only for genuine losses.
      String? lossNumber;
      if (recordsLoss) {
        lossNumber = await damagedGoodsStore.recordAdjustmentLoss(
          variantId: variant.varianteId,
          productId: variant.productId,
          productName: product.productName,
          variantInfo: variant.hasAttributes
              ? variant.variantDescription
              : null,
          quantity: delta.abs(),
          costPrice: variant.costPrice,
          reason: reason.label,
          note: trimmedNote?.isEmpty ?? true ? null : trimmedNote,
        );
      }

      return StockAdjustmentResult(
        success: true,
        balanceAfter: newStock,
        lossNumber: lossNumber,
      );
    } catch (e) {
      return StockAdjustmentResult.failure('Adjustment failed: $e');
    }
  }

  /// Adjustment history for one product, newest first — includes its variants.
  static List<StockMovementModel> historyForProduct(String productId) =>
      _movements.movementsForItem(productId);

  /// History for a single variant, newest first.
  static List<StockMovementModel> historyForVariant(String variantId) {
    final all = _movements.allMovements();
    final list = all.where((m) => m.variantId == variantId).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Every adjustment ever recorded, newest first — the history screen's feed.
  static List<StockMovementModel> allAdjustments() {
    final list = _movements.allMovements();
    // Newest first, then the movement id. A stock take applies many
    // adjustments in one loop, so several routinely share a millisecond — and
    // `List.sort` is not stable, so tied rows could reorder between loads.
    list.sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
    return list;
  }
}
