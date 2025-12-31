

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
  /// Item Total = Gross total of all items (before discount)
  /// In tax-inclusive mode: includes GST in prices
  /// In tax-exclusive mode: base prices only
  late final double itemTotal;

  /// Taxable Amount = Base amount after discount (before adding GST)
  /// In tax-inclusive mode: extracted base from discounted gross
  /// In tax-exclusive mode: discounted base price
  late final double taxableAmount;

  /// For backward compatibility - same as taxableAmount
  /// @deprecated Use taxableAmount instead
  double get subtotal => taxableAmount;

  late final double discountAmount;
  late final double totalGST;
  late final double serviceChargeAmount;
  late final double grandTotal;
  late final double roundOffAmount; // Amount added/subtracted for rounding

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
      itemTotal = 0;
      taxableAmount = 0;
      discountAmount = 0;
      totalGST = 0;
      serviceChargeAmount = 0;
      roundOffAmount = 0;
      grandTotal = 0;
      return;
    }

    // STEP 1: Calculate original total
    final double totalOriginalAmount = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    itemTotal = totalOriginalAmount;

    // STEP 2: Accumulators
    double accumulatedTaxableAmount = 0;
    double accumulatedGST = 0;
    double accumulatedDiscount = 0;

    // STEP 3: Loop through items
    for (final item in items) {
      final double itemOriginalAmount = item.price * item.quantity;
      final double itemTaxRate = item.taxRate ?? 0;

      double itemDiscount = 0;
      double itemBase;
      double itemGST;

      // ================= DISCOUNT ON ITEMS =================
      if (AppSettings.discountOnItems) {
        // Calculate discount per item
        if (discountType == DiscountType.percentage) {
          itemDiscount = itemOriginalAmount * (discountValue / 100);
        } else {
          itemDiscount = totalOriginalAmount > 0
              ? (itemOriginalAmount / totalOriginalAmount) * discountValue
              : 0;
        }
        itemDiscount = itemDiscount.clamp(0, itemOriginalAmount);

        // Discount applied FIRST, then GST on discounted amount
        final discountedItemAmount = itemOriginalAmount - itemDiscount;

        if (AppSettings.isTaxInclusive) {
          itemBase = itemTaxRate > 0
              ? discountedItemAmount / (1 + itemTaxRate)
              : discountedItemAmount;
          itemGST = discountedItemAmount - itemBase;
        } else {
          itemBase = discountedItemAmount;
          itemGST = itemBase * itemTaxRate;
        }
      }

      // ================= DISCOUNT OFF ITEMS =================
      else {
        // Calculate bill-level discount (but apply proportionally later)
        double billDiscount = 0;
        if (discountType == DiscountType.percentage) {
          billDiscount = totalOriginalAmount * (discountValue / 100);
        } else {
          billDiscount = discountValue;
        }

        // Calculate this item's share after bill discount
        final double afterDiscountTotal = totalOriginalAmount - billDiscount;
        final double itemShare = totalOriginalAmount > 0
            ? (itemOriginalAmount / totalOriginalAmount) * afterDiscountTotal
            : 0;

        // Item's portion of discount
        itemDiscount = itemOriginalAmount - itemShare;

        // GST calculated on discounted share
        if (AppSettings.isTaxInclusive) {
          itemBase = itemTaxRate > 0
              ? itemShare / (1 + itemTaxRate)
              : itemShare;
          itemGST = itemShare - itemBase;
        } else {
          itemBase = itemShare;
          itemGST = itemBase * itemTaxRate;
        }
      }

      // Accumulate totals
      accumulatedTaxableAmount += itemBase;
      accumulatedGST += itemGST;
      accumulatedDiscount += itemDiscount;
    }

    // STEP 4: Assign final values (ONLY ONCE!)
    taxableAmount = accumulatedTaxableAmount;
    totalGST = accumulatedGST;
    discountAmount = accumulatedDiscount;

    // STEP 5: Service Charge
    if (isDeliveryOrder) {
      serviceChargeAmount = deliveryCharge;
    } else {
      double payableBeforeServiceCharge = taxableAmount + totalGST;
      serviceChargeAmount = payableBeforeServiceCharge > 0
          ? payableBeforeServiceCharge * (serviceChargePercentage / 100)
          : 0;
    }

    // STEP 6: Grand Total
    double calculatedTotal = taxableAmount + totalGST + serviceChargeAmount;

    // STEP 7: Round Off
    if (AppSettings.roundOff) {
      final roundTo = double.parse(AppSettings.selectedRoundOffValue);
      final roundedTotal = _roundToNearest(calculatedTotal, roundTo);
      roundOffAmount = roundedTotal - calculatedTotal;
      grandTotal = roundedTotal;
    } else {
      roundOffAmount = 0;
      grandTotal = calculatedTotal;
    }
  }

  /// Round a value to the nearest specified amount
  double _roundToNearest(double value, double nearest) {
    if (nearest <= 0) return value;
    return (value / nearest).round() * nearest;
  }
}