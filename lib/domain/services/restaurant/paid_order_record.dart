import '../../../core/config/tax_feature.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'cart_calculation_service.dart';
import 'saved_service_charge.dart';

/// A payment taken on an order that stays ACTIVE (Dine In paid before it is
/// served), and the past order it later becomes.
///
/// The payment is recorded on the active order in full — the payment
/// calculation's totals and tax, loyalty points, who gave the discount, the
/// shift that took it — and both ways a paid active order leaves (served from
/// Active Orders, completed at End of Day) build the past order from the same
/// [toPastOrder], so neither drops what the other keeps.
class PaidOrderRecord {
  /// [order] with the payment calculation [calc] applied: totals and tax as
  /// charged (the GST saved when the order was placed is replaced), plus
  /// [pointsUsed], the staff who gave a discount and the paying shift.
  static OrderModel applyPayment(
    OrderModel order,
    CartCalculationService calc, {
    int pointsUsed = 0,
    String? discountAppliedBy,
    String? shiftId,
  }) =>
      order.copyWith(
        // Pre-tax base in both tax modes, as completed orders and EOD use it.
        subTotal: calc.subtotal,
        gstAmount: calc.totalGST,
        discount: calc.discountAmount,
        serviceCharge: calc.serviceChargeAmount,
        totalPrice: calc.grandTotal, // net payable (points folded into GST base)
        loyaltyPointsUsed: pointsUsed > 0 ? pointsUsed : null,
        discountAppliedBy:
            calc.discountAmount > 0.009 ? discountAppliedBy : null,
        shiftId: shiftId,
      );

  /// The past order for a paid active order [o]. The shift is the one that
  /// took the payment; [currentShiftId] only for orders saved without one.
  static PastOrderModel toPastOrder(
    OrderModel o, {
    required int billNumber,
    String? storeGstNumber,
    String? currentShiftId,
    String paymentModeFallback = 'Cash',
    bool? taxEnabled,
    double? roundOffStep,
    bool? discountOnItems,
  }) =>
      PastOrderModel(
        id: o.id,
        customerName: o.customerName,
        totalPrice: o.totalPrice,
        items: o.items,
        orderAt: o.timeStamp,
        orderType: o.orderType,
        paymentmode: o.paymentMethod ?? paymentModeFallback,
        remark: o.remark,
        subTotal: o.subTotal,
        Discount: o.discount,
        gstRate: o.gstRate,
        gstAmount: o.gstAmount,
        orderStatus: 'COMPLETED',
        kotNumbers: o.kotNumbers,
        kotBoundaries: o.kotBoundaries,
        billNumber: billNumber,
        paymentListJson: o.paymentListJson,
        isSplitPayment: o.isSplitPayment,
        totalPaid: o.totalPaid,
        changeReturn: o.changeReturn,
        isTaxInclusive: o.isTaxInclusive,
        tableNo: o.tableNo,
        loyaltyPointsUsed: o.loyaltyPointsUsed,
        shiftId: o.shiftId ?? currentShiftId,
        sessionId: o.sessionId,
        discountAppliedBy: o.discountAppliedBy,
        customerId: o.customerId,
        serviceCharge: o.serviceCharge,
        taxEnabled: taxEnabled ?? TaxFeature.enabled,
        storeGstNumber: storeGstNumber,
        roundOffStep: roundOffStep ?? AppSettings.roundOffStepForRecord,
        discountOnItems: discountOnItems ?? AppSettings.discountOnItems,
      );

  /// What the payment screen starts with for a saved order: its discount
  /// amount, and its service charge — the % it was taken at, or for delivery
  /// the flat delivery charge. 0 = nothing saved (the field starts off).
  static ({double discountAmount, double serviceChargeValue}) prefill(
    OrderModel order, {
    required bool isDelivery,
  }) =>
      (
        discountAmount: (order.discount ?? 0) > 0.009 ? order.discount! : 0.0,
        serviceChargeValue: isDelivery
            ? ((order.serviceCharge ?? 0) > 0 ? order.serviceCharge! : 0.0)
            : SavedServiceCharge.ratePercentOf(order, isDelivery: false),
      );
}
