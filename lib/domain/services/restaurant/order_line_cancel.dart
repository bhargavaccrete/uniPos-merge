import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'cart_calculation_service.dart';
import 'kot_layout.dart';
import 'kot_status_rule.dart';

/// The saved order after cancelling part or all of one KOT'd line.
class OrderLineCancelResult {
  final OrderModel order;

  /// The cancelled quantity of the line, for the stock restore and the
  /// Cancel KOT.
  final CartItem cancelled;

  const OrderLineCancelResult({required this.order, required this.cancelled});
}

/// Commit-time rules for cancelling a line that was already sent to the
/// kitchen (Takeaway immediate cancel, Active Orders single-item cancel).
class OrderLineCancel {
  /// Whether the KOT owning [lineId] in the SAVED [order] is consumed
  /// ([KotStatusRule]), so the line can no longer be cancelled. A KOT with no
  /// status of its own takes the order's (`OrderModel.getKotStatus`).
  static bool isCooked(OrderModel order, String lineId) {
    final idx = order.items.indexWhere((i) => i.id == lineId);
    if (idx == -1) return false;
    final kotIndex = order.kotBoundaries.indexWhere((b) => idx < b);
    final status = (kotIndex != -1 && kotIndex < order.kotNumbers.length)
        ? order.getKotStatus(order.kotNumbers[kotIndex])
        : order.status;
    return KotStatusRule.isConsumed(status);
  }

  /// Active Orders single-item cancel: removes the whole line at
  /// [itemIndexInOrder]. Returns null for the order's last line — an order
  /// must keep at least one KOT (OrderModel asserts it), so emptying it is a
  /// void, which also records the payment correctly.
  ///
  /// Totals are recomputed the way an existing order is everywhere else
  /// (takeaway.dart, RestaurantPrintHelper.printBillForActiveOrder): saved
  /// discount amount, service charge % (or delivery charge), stored tax mode.
  static OrderLineCancelResult? forActiveOrders(
    OrderModel order, {
    required int itemIndexInOrder,
  }) {
    if (order.items.length <= 1) return null;
    final item = order.items[itemIndexInOrder];

    final layout = KotLayout.removeQuantity(
      items: order.items,
      kotNumbers: order.kotNumbers,
      kotBoundaries: order.kotBoundaries,
      kotStatuses: order.kotStatuses ?? {},
      lineId: item.id,
      qty: item.quantity,
    );

    final bool isDelivery = order.orderType.toLowerCase().contains('delivery');
    final bool taxInclusive = order.isTaxInclusive ?? AppSettings.isTaxInclusive;
    final calc = CartCalculationService(
      items: layout.items,
      discountType: DiscountType.amount,
      discountValue: order.discount ?? 0.0,
      serviceChargePercentage: isDelivery ? 0.0 : (order.serviceCharge ?? 0.0),
      deliveryCharge: isDelivery ? (order.serviceCharge ?? 0.0) : 0.0,
      isDeliveryOrder: isDelivery,
      isTaxInclusive: taxInclusive,
    );

    return OrderLineCancelResult(
      order: order.copyWith(
        items: layout.items,
        kotNumbers: layout.kotNumbers,
        kotBoundaries: layout.kotBoundaries,
        kotStatuses: layout.kotStatuses,
        itemCountAtLastKot: layout.itemCountAtLastKot,
        totalPrice: calc.grandTotal,
        subTotal: taxInclusive ? calc.subtotal - calc.totalGST : calc.subtotal,
        gstAmount: calc.totalGST,
      ),
      cancelled: item,
    );
  }
}
