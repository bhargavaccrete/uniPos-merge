import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/common/quantity_format.dart';
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

  /// Set when the adjustment was refused because stock moved since the caller
  /// read it — the live level, for the caller to show before retrying.
  final double? liveStock;

  /// True when a caller-supplied movement id was already recorded, so the
  /// adjustment had been applied before and nothing was written this time.
  final bool alreadyApplied;

  /// Set on a SUCCESS that still needs the user's attention — the stock
  /// moved but a loss-bearing adjustment's loss row could not be saved.
  final String? warning;

  const StockAdjustmentResult({
    required this.success,
    this.errorMessage,
    this.balanceAfter,
    this.lossNumber,
    this.liveStock,
    this.alreadyApplied = false,
    this.warning,
  });

  factory StockAdjustmentResult.failure(String message) =>
      StockAdjustmentResult(success: false, errorMessage: message);

  factory StockAdjustmentResult.stale(double live) => StockAdjustmentResult(
        success: false,
        liveStock: live,
        errorMessage:
            'Stock changed to ${formatQty(live)} while this was open — check '
            'the change and save again.',
      );
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
  ///
  /// The change, the audit row and any loss are computed against the LIVE
  /// variant, never the [variant] snapshot a dialog opened with — a sale in
  /// between used to record the wrong delta and loss quantity. A caller that
  /// SHOWED the user a stock level passes it as [expectedStock]; if stock has
  /// moved since, nothing is written and [StockAdjustmentResult.stale] carries
  /// the live level back.
  static Future<StockAdjustmentResult> adjust({
    required VarianteModel variant,
    required double newStock,
    required StockAdjustmentReason reason,
    String? note,
    double? expectedStock,
    /// Deterministic id for the audit row. A batch caller (stock take) passes
    /// one per line so a re-run after a crash finds the row and skips the
    /// line instead of applying it twice.
    String? movementId,
  }) async {
    if (!canAdjust) {
      return StockAdjustmentResult.failure(
        'Only the admin can adjust stock.',
      );
    }

    if (movementId != null && _movements.contains(movementId)) {
      return const StockAdjustmentResult(success: true, alreadyApplied: true);
    }

    if (newStock < 0) {
      return StockAdjustmentResult.failure('Stock cannot be negative.');
    }

    final live = await productStore.getVariantById(variant.varianteId);
    if (live == null) {
      return StockAdjustmentResult.failure('This variant no longer exists.');
    }
    variant = live;
    if (expectedStock != null && live.stockQty != expectedStock) {
      return StockAdjustmentResult.stale(live.stockQty);
    }

    // Resolved BEFORE any write: a missing product used to throw after the
    // stock had already moved, leaving a change with no audit row.
    final product = productStore.getProductById(variant.productId);
    if (product == null) {
      return StockAdjustmentResult.failure('Product not found.');
    }
    // A bundle sells from its components; its own figure is ignored, so
    // adjusting it would record a stock change that changes nothing real.
    if (product.isBundle) {
      return StockAdjustmentResult.failure(
        'A bundle holds no stock of its own — adjust its components instead.',
      );
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
      final label = variant.hasAttributes
          ? '${product.productName} (${variant.variantDescription})'
          : product.productName;

      await _movements.saveMovement(StockMovementModel(
        id: movementId ?? const Uuid().v4(),
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
        // The stock HAS moved and its movement row exists, so this is still a
        // success — but a missing loss row understates the loss report, and
        // `recordAdjustmentLoss` swallows its error, so say it out loud.
        warning: recordsLoss && lossNumber == null
            ? 'Stock adjusted, but the loss record could not be saved — the '
                'loss report will not include it.'
            : null,
      );
    } catch (e) {
      return StockAdjustmentResult.failure('Adjustment failed: $e');
    }
  }

  /// EVERY stock movement for one product (sales, receipts, returns,
  /// adjustments…), newest first, including its variants — the product's full
  /// stock ledger for the Stock History dialog. Not filtered to adjustments.
  static List<StockMovementModel> historyForProduct(String productId) =>
      _movements.movementsForItem(productId);

  /// History for a single variant, newest first.
  static List<StockMovementModel> historyForVariant(String variantId) {
    final all = _movements.allMovements();
    final list = all.where((m) => m.variantId == variantId).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Every manual adjustment (incl. stock-take commits) ever recorded, newest
  /// first — the Stock Adjustment report's feed. The shared movement box holds
  /// every other kind of movement too; only adjustment reasons pass.
  static List<StockMovementModel> allAdjustments() {
    final list = _movements
        .allMovements()
        .where((m) => StockAdjustmentReason.isAdjustment(m.reason))
        .toList();
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
