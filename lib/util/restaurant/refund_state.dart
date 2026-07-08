import '../../data/models/restaurant/db/pastordermodel_313.dart';

enum RefundState {
  none,
  partial,
  full,
}

class RefundInfo {
  static bool hasRefund(PastOrderModel order) {
    if (order.items.isNotEmpty) {
      final hasItemRefund = order.items.any((item) => (item.refundedQuantity ?? 0) > 0);
      if (hasItemRefund) return true;
    }
    return (order.refundAmount ?? 0.0) > 0.0;
  }

  static bool isFullyRefunded(PastOrderModel order) {
    if (order.items.isNotEmpty) {
      final hasItemRefund = order.items.any((item) => (item.refundedQuantity ?? 0) > 0);
      if (hasItemRefund) {
        return order.items.every((item) {
          final originalQty = item.quantity;
          final refundedQty = item.refundedQuantity ?? 0;
          return refundedQty >= originalQty;
        });
      }
    }
    final total = order.totalPrice;
    final refund = order.refundAmount ?? 0.0;
    return refund > 0.0 && refund >= total;
  }

  static RefundState state(PastOrderModel order) {
    if (isFullyRefunded(order)) {
      return RefundState.full;
    } else if (hasRefund(order)) {
      return RefundState.partial;
    } else {
      return RefundState.none;
    }
  }
}
