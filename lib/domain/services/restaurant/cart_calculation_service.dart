

import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../presentation/screens/restaurant/start order/cart/customerdetails.dart';
import '../../../util/restaurant/staticswitch.dart';

class CartCalculationService {
  final List<CartItem> items;
  final DiscountType discountType;
  final double discountValue;
  // ✅ 1. FIX: Corrected typo from 'serivceChargePercentage'
  final double serviceChargePercentage;
  final double deliveryCharge;
  final bool isDeliveryOrder;



  // --- Final Calculated Properties ---
  late final double subtotal;
  late final double discountAmount;
  late final double totalGST;
  late final double serviceChargeAmount;
  late final double grandTotal;

  CartCalculationService({
    required this.items,
    required this.discountType,
    required this.discountValue,
    this.serviceChargePercentage = 0.0,
    this.deliveryCharge = 0.0,
    this.isDeliveryOrder = false,
  }) {
    // The calculation is triggered the moment the service is created.
    _calculate();
  }

  void _calculate() {
    if (items.isEmpty) {
      subtotal = 0;
      discountAmount = 0;
      totalGST = 0;
      serviceChargeAmount = 0;
      grandTotal = 0;
      return;
    }

    // Step 1: Calculate gross subtotal
    subtotal = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    // Step 2: Determine taxable amount. This depends on when the discount is applied.
    double taxableAmount = subtotal;

    if (AppSettings.discountOnItems) {
      taxableAmount = (discountType == DiscountType.percentage)
          ? subtotal * (1 - (discountValue / 100))
          : subtotal - discountValue;
    }
    taxableAmount = taxableAmount.clamp(0, double.infinity);

    // Step 3: Calculate total GST based on the taxable amount.
    totalGST = _calculateGstOnBase(taxableAmount);

    // ✅ 2. FIX: Use a local variable for all discount calculations first.
    double calculatedDiscount;
    if (AppSettings.discountOnItems) {
      // If discount is on items, it's the difference between the original and taxable amount.
      calculatedDiscount = subtotal - taxableAmount;
    } else {
      // If discount is on the total, calculate it based on the cart total.
      double baseForCartDiscount = AppSettings.isTaxInclusive ? subtotal : (subtotal + totalGST);
      calculatedDiscount = (discountType == DiscountType.percentage)
          ? baseForCartDiscount * (discountValue / 100)
          : discountValue;
    }

    // ✅ 2 . FIX: Assign to the 'late final' field only ONCE, after clamping the result.
    discountAmount = calculatedDiscount.clamp(0, subtotal + totalGST);

    // Step 5: Calculate Service Charge or Delivery Charge
    if (isDeliveryOrder) {
      // For delivery orders, use flat delivery charge
      serviceChargeAmount = deliveryCharge;
    } else {
      // For other orders, calculate percentage-based service charge
      double baseForServiceCharge = AppSettings.isTaxInclusive
          ? (subtotal - discountAmount)
          : (subtotal + totalGST - discountAmount);

      serviceChargeAmount = baseForServiceCharge > 0 ? baseForServiceCharge * (serviceChargePercentage / 100) : 0;
    }

    // Step 6: Calculate Grand Total
    grandTotal = (AppSettings.isTaxInclusive)
        ? (subtotal - discountAmount + serviceChargeAmount)
        : (subtotal + totalGST - discountAmount + serviceChargeAmount);
  }

  // Helper method to calculate GST from a given base amount
  double _calculateGstOnBase(double taxableBase) {
    if (taxableBase <= 0 || subtotal <= 0) return 0;
    double calculatedGst = 0; // Renamed for clarity

    for (final item in items) {
      // This prevents division by zero if subtotal is somehow 0
      final double itemProportion = subtotal > 0 ? (item.price * item.quantity) / subtotal : 0;
      final double itemTaxableAmount = taxableBase * itemProportion;
      final double itemTaxRate = item.taxRate ?? 0;

      if (itemTaxRate > 0) {
        calculatedGst += AppSettings.isTaxInclusive
            ? itemTaxableAmount - (itemTaxableAmount / (1 + itemTaxRate))
            : itemTaxableAmount * itemTaxRate;
      }
    }
    return calculatedGst;
  }
}