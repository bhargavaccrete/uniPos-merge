import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
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
  static Future<pastOrderModel> processRefund({
    required pastOrderModel order,
    required PartialRefundResult refundResult,
  }) async {
    try {
      print('🔄 RefundService: Processing refund...');
      print('Items to refund: ${refundResult.itemsToRefund.length}');
      print('Total refund amount: ${refundResult.totalRefundAmount}');
      print('Items to restock: ${refundResult.itemsToRestock.length}');

      // Update refunded quantities for each item
      final List<CartItem> updatedItems = List<CartItem>.from(order.items ?? []);

      refundResult.itemsToRefund.forEach((itemToRefund, quantityToRefund) {
        final index = updatedItems.indexWhere((item) =>
            item.id == itemToRefund.id &&
            item.productId == itemToRefund.productId &&
            item.variantName == itemToRefund.variantName);

        if (index != -1) {
          final currentItem = updatedItems[index];
          final newRefundedQuantity = (currentItem.refundedQuantity ?? 0) + quantityToRefund;
          updatedItems[index] = currentItem.copyWith(refundedQuantity: newRefundedQuantity);
          print('✅ Updated refund quantity for ${currentItem.title}: $newRefundedQuantity');
        } else {
          print('⚠️ Could not find item to update: ${itemToRefund.title}');
        }
      });

      // Determine new order status
      bool allItemsRefunded = updatedItems.every((item) {
        final originalQty = item.quantity ?? 0;
        final refundedQty = item.refundedQuantity ?? 0;
        return refundedQty >= originalQty;
      });

      final newStatus = allItemsRefunded ? 'FULLY_REFUNDED' : 'PARTIALLY_REFUNDED';
      print('📝 New order status: $newStatus');

      // Create updated order
      final updatedOrder = order.copyWith(
        items: updatedItems,
        orderStatus: newStatus,
        refundAmount: (order.refundAmount ?? 0) + refundResult.totalRefundAmount,
        refundReason: (order.refundReason ?? '') +
            '\n[${DateTime.now().toLocal().toString().substring(0, 16)}] ${refundResult.reason}',
        refundedAt: DateTime.now(),
      );

      print('💾 Saving updated order...');
      await pastOrderStore.updateOrder(updatedOrder);
      print('✅ Order updated successfully');

      // Restore stock for items marked for restocking
      if (refundResult.itemsToRestock.isNotEmpty) {
        print('📦 Starting stock restoration...');
        await InventoryService.restoreStockForRefund(refundResult.itemsToRestock);
      } else {
        print('⚠️ No items marked for restocking');
      }

      print('✅ RefundService: Refund processing completed');
      return updatedOrder;
    } catch (e, stackTrace) {
      print('❌ RefundService: Error processing refund: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Rethrow so caller can handle and show error to user
    }
  }

  /// Validate if an order is eligible for refund
  /// Returns error message if not eligible, null if eligible
  static String? validateRefundEligibility(pastOrderModel order) {
    // Check if order time exists
    if (order.orderAt == null) {
      return 'Order time is missing. Cannot process refund.';
    }

    // Check if within refund window (60 minutes)
    final minutePassed = DateTime.now().difference(order.orderAt!).inMinutes;
    if (minutePassed > 60) {
      return 'Refund window (60 minutes) has passed.';
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

  /// Get list of items that can be refunded from an order
  static List<CartItem> getRefundableItems(pastOrderModel order) {
    return order.items?.where((item) {
      final originalQty = item.quantity ?? 0;
      final alreadyRefunded = item.refundedQuantity ?? 0;
      return originalQty > alreadyRefunded;
    }).toList() ?? [];
  }

  /// Calculate remaining refundable amount
  static double getRemainingRefundableAmount(pastOrderModel order) {
    final originalTotal = order.totalPrice ?? 0.0;
    final alreadyRefunded = order.refundAmount ?? 0.0;
    return originalTotal - alreadyRefunded;
  }

  /// Process void order (mark as voided)
  static Future<pastOrderModel> voidOrder({
    required pastOrderModel order,
    required String reason,
  }) async {
    try {
      print('🔄 RefundService: Voiding order...');

      final voidedOrder = order.copyWith(
        orderStatus: 'VOIDED',
        refundReason: reason.isNotEmpty ? 'VOIDED: $reason' : 'VOIDED: No reason provided',
        refundedAt: DateTime.now(),
      );

      await pastOrderStore.updateOrder(voidedOrder);

      print('✅ RefundService: Order voided successfully');
      return voidedOrder;
    } catch (e, stackTrace) {
      print('❌ RefundService: Error voiding order: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
