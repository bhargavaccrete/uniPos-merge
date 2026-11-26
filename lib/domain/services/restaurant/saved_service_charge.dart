import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'cart_calculation_service.dart';

/// Totals of a SAVED active order whose items changed (bill print, item
/// cancel, cart total).
///
/// [OrderModel.serviceCharge] holds the service charge AMOUNT the bill was
/// settled or placed with (`serviceChargeAmount`); the % the cashier entered
/// is not stored. For delivery orders the same field is the flat delivery
/// charge. Reading the amount as a % would turn a ₹100 charge into 100%.
class SavedServiceCharge {
  /// The service-charge % the saved amount was taken at: amount ÷ the order's
  /// payable before service charge (taxable + GST of its saved items, after
  /// its saved discount). 0 for delivery, no charge, or nothing to charge on.
  static double ratePercentOf(OrderModel order, {required bool isDelivery}) {
    final amount = order.serviceCharge ?? 0.0;
    if (isDelivery || amount <= 0) return 0.0;
    final base = _calculate(order, order.items, isDelivery: false, rate: 0);
    final payable = base.taxableAmount + base.totalGST;
    return payable > 0 ? amount / payable * 100 : 0.0;
  }

  /// [items] priced the way [order] was: its saved discount amount and tax
  /// mode, its service-charge % on what [items] now come to (delivery: its
  /// flat delivery charge, unchanged).
  static CartCalculationService calculate(
    OrderModel order,
    List<CartItem> items, {
    required bool isDelivery,
  }) =>
      _calculate(order, items,
          isDelivery: isDelivery,
          rate: ratePercentOf(order, isDelivery: isDelivery));

  static CartCalculationService _calculate(
    OrderModel order,
    List<CartItem> items, {
    required bool isDelivery,
    required double rate,
  }) =>
      CartCalculationService(
        items: items,
        discountType: DiscountType.amount,
        discountValue: order.discount ?? 0.0,
        serviceChargePercentage: isDelivery ? 0.0 : rate,
        deliveryCharge: isDelivery ? (order.serviceCharge ?? 0.0) : 0.0,
        isDeliveryOrder: isDelivery,
        isTaxInclusive: order.isTaxInclusive ?? AppSettings.isTaxInclusive,
        // Points redeemed at payment: the charge was taken on the bill after
        // them, so the base and every recalculation use it too.
        loyaltyRedemption: (order.loyaltyPointsUsed ?? 0).toDouble(),
      );
}
