import '../../../core/di/service_locator.dart';
import '../../../core/plan/entitlement_keys.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'inventory_service.dart';

/// Result class for partial refund operations
class PartialRefundResult {
  final Map<CartItem, int> itemsToRefund;
  final String reason;
  final double totalRefundAmount;
  final Map<CartItem, int> itemsToRestock;

  PartialRefundResult({
    required this.itemsToRefund,
    required this.reason,
    required this.totalRefundAmount,
    required this.itemsToRestock,
  });
}

/// Service for handling refund business logic
/// Separates refund processing from UI layer
class RefundService {
  /// Process a partial or full refund for an order
  /// Returns the updated order after refund processing
  static Future<PastOrderModel> processRefund({
    required PastOrderModel order,
    required PartialRefundResult refundResult,
  }) async {
    // Plan gate — a refund edits a committed bill (billing.invoice.edit).
    if (!PlanEnforce.allows(EntKeys.billingInvoiceEdit)) {
      throw Exception('Refunds aren’t available on your current plan.');
    }
    try {

      // Update refunded quantities for each item.
      // Items may be grouped in the refund dialog (same product across KOTs),
      // so distribute refund quantity across all matching original items.
      final List<CartItem> updatedItems = List<CartItem>.from(order.items ?? []);

      refundResult.itemsToRefund.forEach((itemToRefund, quantityToRefund) {
        final groupKey = _itemGroupKey(itemToRefund);
        int remaining = quantityToRefund;

        for (int i = 0; i < updatedItems.length && remaining > 0; i++) {
          final item = updatedItems[i];
          if (_itemGroupKey(item) == groupKey) {
            final available = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
            if (available > 0) {
              final toRefund = available < remaining ? available : remaining;
              updatedItems[i] = item.copyWith(
                refundedQuantity: (item.refundedQuantity ?? 0) + toRefund,
              );
              remaining -= toRefund;
            }
          }
        }
        if (remaining > 0) {
        }
      });

      // Determine new order status
      bool allItemsRefunded = updatedItems.every((item) {
        final originalQty = item.quantity ?? 0;
        final refundedQty = item.refundedQuantity ?? 0;
        return refundedQty >= originalQty;
      });

      final newStatus = allItemsRefunded ? 'FULLY_REFUNDED' : 'PARTIALLY_REFUNDED';

      final _staffLabel = RestaurantSession.isAdmin
          ? 'Admin'
          : '${RestaurantSession.staffName ?? RestaurantSession.effectiveRole} (${RestaurantSession.effectiveRole})';

      // Create updated order
      final updatedOrder = order.copyWith(
        items: updatedItems,
        orderStatus: newStatus,
        refundAmount: (order.refundAmount ?? 0) + refundResult.totalRefundAmount,
        refundReason: (order.refundReason ?? '') +
            '\n[${DateTime.now().toLocal().toString().substring(0, 16)}] $_staffLabel: ${refundResult.reason}',
        refundedAt: DateTime.now(),
        refundedBy: _staffLabel,
      );

      await pastOrderStore.updateOrder(updatedOrder);

      // Restore stock for items marked for restocking
      if (refundResult.itemsToRestock.isNotEmpty) {
        await InventoryService.restoreStockForRefund(refundResult.itemsToRestock);
      }

      // Restore loyalty points proportional to refund amount
      final cid = order.customerId;
      final pointsUsed = order.loyaltyPointsUsed ?? 0;
      if (cid != null && pointsUsed > 0) {
        final refundRatio = order.totalPrice > 0
            ? refundResult.totalRefundAmount / order.totalPrice
            : 0.0;
        final pointsToRestore = (pointsUsed * refundRatio).round();
        if (pointsToRestore > 0) {
          await restaurantCustomerStore.addLoyaltyPoints(cid, pointsToRestore);
        }
      }

      return updatedOrder;
    } catch (e, stackTrace) {
      rethrow; // Rethrow so caller can handle and show error to user
    }
  }

  /// Validate if an order is eligible for refund
  /// Returns error message if not eligible, null if eligible
  static String? validateRefundEligibility(PastOrderModel order) {
    // Check if order time exists
    if (order.orderAt == null) {
      return 'Order time is missing. Cannot process refund.';
    }

    // Check if within refund window (configurable, 0 = no limit)
    final window = AppSettings.refundWindowMinutes;
    if (window > 0) {
      final minutePassed = DateTime.now().difference(order.orderAt!).inMinutes;
      if (minutePassed > window) {
        final label = window < 60
            ? '$window minutes'
            : window == 60
                ? '1 hour'
                : '${(window / 60).toStringAsFixed(window % 60 == 0 ? 0 : 1)} hours';
        return 'Refund window ($label) has passed.';
      }
    }

    // Check if there are refundable items
    final refundableItems = order.items?.where((item) {
      final originalQty = item.quantity ?? 0;
      final alreadyRefunded = item.refundedQuantity ?? 0;
      return originalQty > alreadyRefunded;
    }).toList() ?? [];

    if (refundableItems.isEmpty) {
      return 'All items in this order have already been refunded.';
    }

    return null; // Eligible for refund
  }

  /// Get list of items that can be refunded from an order.
  /// Groups identical items (same product, variant, extras, choices) that were
  /// split across different KOTs into a single entry with combined quantities.
  static List<CartItem> getRefundableItems(PastOrderModel order) {
    final items = order.items ?? [];
    if (items.isEmpty) return [];

    // Group identical items by product+variant+extras+choices
    final Map<String, CartItem> grouped = {};
    for (final item in items) {
      final key = _itemGroupKey(item);
      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        grouped[key] = existing.copyWith(
          quantity: existing.quantity + (item.quantity ?? 0),
          refundedQuantity: (existing.refundedQuantity ?? 0) + (item.refundedQuantity ?? 0),
        );
      } else {
        grouped[key] = item.copyWith(
          quantity: item.quantity ?? 0,
          refundedQuantity: item.refundedQuantity ?? 0,
        );
      }
    }

    // Filter to only items with remaining refundable quantity
    return grouped.values.where((item) {
      return item.quantity > (item.refundedQuantity ?? 0);
    }).toList();
  }

  /// Unique key for grouping identical items (same as print helper logic)
  static String _itemGroupKey(CartItem item) {
    final extrasKey = item.extras?.map((e) => '${e['name']}_${e['price']}_${e['quantity']}').join('|') ?? '';
    final choicesKey = item.choiceNames?.join('|') ?? '';
    return '${item.productId}_${item.variantName ?? ''}_${extrasKey}_${choicesKey}';
  }

  /// Calculate remaining refundable amount
  static double getRemainingRefundableAmount(PastOrderModel order) {
    final originalTotal = order.totalPrice ?? 0.0;
    final alreadyRefunded = order.refundAmount ?? 0.0;
    return originalTotal - alreadyRefunded;
  }

  /// Process void order (mark as voided)
  static Future<PastOrderModel> voidOrder({
    required PastOrderModel order,
    required String reason,
  }) async {
    try {
      // Plan gate — voiding a completed order (billing.invoice.void).
      if (!PlanEnforce.allows(EntKeys.billingInvoiceVoid)) {
        throw Exception('Voiding orders isn’t available on your current plan.');
      }

      final _staffLabel = RestaurantSession.isAdmin
          ? 'Admin'
          : '${RestaurantSession.staffName ?? RestaurantSession.effectiveRole} (${RestaurantSession.effectiveRole})';

      final voidedOrder = order.copyWith(
        orderStatus: 'VOIDED',
        refundReason: reason.isNotEmpty ? 'VOIDED: $reason' : 'VOIDED: No reason provided',
        refundedAt: DateTime.now(),
        voidedBy: _staffLabel,
      );

      await pastOrderStore.updateOrder(voidedOrder);

      // Past orders (already served/paid) — stock was legitimately consumed, no restore.

      return voidedOrder;
    } catch (e, stackTrace) {
      rethrow;
    }
  }
}
