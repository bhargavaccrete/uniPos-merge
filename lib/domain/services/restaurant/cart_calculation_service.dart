

import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../util/restaurant/staticswitch.dart';
import '../../../core/config/tax_feature.dart';

/// How a discount value is interpreted: a flat currency amount, or a percentage
/// of the item total. Lives here (not in a screen) so any caller — restaurant or
/// retail — can reach it without depending on the presentation layer.
enum DiscountType { amount, percentage }

/// One billable line, decoupled from any particular cart model. Restaurant maps
/// its [CartItem] to this; retail maps its own cart model. The engine only ever
/// needed these three values.
///
/// [taxRate] is a FRACTION (0.18 for 18%), matching [CartItem.taxRate]. Callers
/// holding a percentage must divide by 100 before constructing.
class CalcLine {
  final double price;
  final int quantity;
  final double? taxRate;

  const CalcLine({
    required this.price,
    required this.quantity,
    this.taxRate,
  });
}

/// Per-line breakdown, so callers can persist a correct per-item discount share
/// and taxable amount instead of re-deriving them (and getting them wrong).
class CalcLineResult {
  /// price * quantity, before any discount.
  final double originalAmount;

  /// This line's share of the order discount.
  final double discountAmount;

  /// Base this line is taxed on, after discount and loyalty redemption.
  final double taxableAmount;

  final double gstAmount;

  /// The fraction actually applied (0 when the tax feature is off).
  final double taxRate;

  const CalcLineResult({
    required this.originalAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstAmount,
    required this.taxRate,
  });
}

class CartCalculationService {
  final List<CalcLine> lines;
  final DiscountType discountType;
  final double discountValue;
  // ✅ 1. FIX: Corrected typo from 'serivceChargePercentage'
  final double serviceChargePercentage;
  final double deliveryCharge;
  final bool isDeliveryOrder;
  final bool? isTaxInclusive; // Optional: if provided, use this instead of AppSettings
  final bool? discountOnItems; // Optional: if provided, use this instead of AppSettings
  /// ₹ value of loyalty points redeemed. Reduces the taxable base BEFORE GST
  /// (treated like a discount) so GST is charged on the post-redemption amount.
  final double loyaltyRedemption;

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
  late final double loyaltyRedemptionAmount; // actual redemption applied (clamped)

  /// Per-line breakdown, in the same order as [lines].
  late final List<CalcLineResult> lineResults;

  /// Restaurant entry point — takes [CartItem]s and maps them to [CalcLine].
  /// Kept so every existing restaurant call site compiles unchanged.
  CartCalculationService({
    required List<CartItem> items,
    required DiscountType discountType,
    required double discountValue,
    double serviceChargePercentage = 0.0,
    double deliveryCharge = 0.0,
    bool isDeliveryOrder = false,
    bool? isTaxInclusive,
    bool? discountOnItems,
    double loyaltyRedemption = 0.0,
  }) : this.fromLines(
          lines: items
              .map((i) => CalcLine(
                    price: i.price,
                    quantity: i.quantity,
                    taxRate: i.taxRate,
                  ))
              .toList(),
          discountType: discountType,
          discountValue: discountValue,
          serviceChargePercentage: serviceChargePercentage,
          deliveryCharge: deliveryCharge,
          isDeliveryOrder: isDeliveryOrder,
          isTaxInclusive: isTaxInclusive,
          discountOnItems: discountOnItems,
          loyaltyRedemption: loyaltyRedemption,
        );

  /// Model-agnostic entry point. Retail uses this via `RetailBillingService`.
  CartCalculationService.fromLines({
    required this.lines,
    required this.discountType,
    required this.discountValue,
    this.serviceChargePercentage = 0.0,
    this.deliveryCharge = 0.0,
    this.isDeliveryOrder = false,
    this.isTaxInclusive, // If provided, use this instead of AppSettings
    this.discountOnItems, // If provided, use this instead of AppSettings
    this.loyaltyRedemption = 0.0,
  }) {
    // The calculation is triggered the moment the service is created.
    _calculate();
  }

  void _calculate() {
    if (lines.isEmpty) {
      itemTotal = 0;
      taxableAmount = 0;
      discountAmount = 0;
      totalGST = 0;
      serviceChargeAmount = 0;
      roundOffAmount = 0;
      grandTotal = 0;
      loyaltyRedemptionAmount = 0;
      lineResults = const [];
      return;
    }

    // STEP 1: Calculate original total
    final double totalOriginalAmount = lines.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    itemTotal = totalOriginalAmount;

    // STEP 2: Accumulators
    double accumulatedTaxableAmount = 0;
    double accumulatedGST = 0;
    double accumulatedDiscount = 0;
    final List<CalcLineResult> results = [];

    // STEP 3: Loop through items
    final bool taxFeatureEnabled = TaxFeature.enabled;
    for (final item in lines) {
      final double itemOriginalAmount = item.price * item.quantity;
      final double itemTaxRate = taxFeatureEnabled ? (item.taxRate ?? 0) : 0;

      double itemDiscount = 0;
      double itemBase;
      double itemGST;

      // ================= DISCOUNT ON ITEMS =================
      // Use provided value if available, otherwise use AppSettings
      final bool useDiscountOnItems = discountOnItems ?? AppSettings.discountOnItems;
      if (useDiscountOnItems) {
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

        // Use provided value if available, otherwise use AppSettings
        final bool useTaxInclusive = isTaxInclusive ?? AppSettings.isTaxInclusive;
        if (useTaxInclusive) {
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

        // Cap the discount at the bill total. Without this a flat amount larger
        // than the bill (or a percentage over 100) drives afterDiscountTotal
        // negative, which cascades into a negative taxable base, negative GST
        // and a negative grand total — nothing downstream rejects it.
        billDiscount = billDiscount.clamp(0, totalOriginalAmount);

        // Calculate this item's share after bill discount
        final double afterDiscountTotal = totalOriginalAmount - billDiscount;
        final double itemShare = totalOriginalAmount > 0
            ? (itemOriginalAmount / totalOriginalAmount) * afterDiscountTotal
            : 0;

        // Item's portion of discount
        itemDiscount = itemOriginalAmount - itemShare;

        // GST calculated on discounted share
        // Use provided value if available, otherwise use AppSettings
        final bool useTaxInclusive = isTaxInclusive ?? AppSettings.isTaxInclusive;
        if (useTaxInclusive) {
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

      results.add(CalcLineResult(
        originalAmount: itemOriginalAmount,
        discountAmount: itemDiscount,
        taxableAmount: itemBase,
        gstAmount: itemGST,
        taxRate: itemTaxRate,
      ));
    }

    // STEP 4: Loyalty points redemption — reduce the taxable base BEFORE GST
    // (like a discount): scale taxable + GST proportionally so GST reflects the
    // post-redemption amount. Reducible = gross (incl GST) when tax-inclusive,
    // else the pre-tax base.
    double redemptionApplied = 0;
    if (loyaltyRedemption > 0) {
      final bool useTaxInclusive = isTaxInclusive ?? AppSettings.isTaxInclusive;
      final double reducible = useTaxInclusive
          ? (accumulatedTaxableAmount + accumulatedGST)
          : accumulatedTaxableAmount;
      if (reducible > 0) {
        redemptionApplied = loyaltyRedemption.clamp(0, reducible).toDouble();
        final double f = (reducible - redemptionApplied) / reducible;
        accumulatedTaxableAmount *= f;
        accumulatedGST *= f;
        // Scale the per-line figures by the same factor, otherwise the lines
        // no longer sum to the totals and a caller persisting them writes
        // item amounts that don't reconcile with the bill.
        for (int i = 0; i < results.length; i++) {
          final r = results[i];
          results[i] = CalcLineResult(
            originalAmount: r.originalAmount,
            discountAmount: r.discountAmount,
            taxableAmount: r.taxableAmount * f,
            gstAmount: r.gstAmount * f,
            taxRate: r.taxRate,
          );
        }
      }
    }

    // STEP 5: Assign final values (ONLY ONCE!)
    taxableAmount = accumulatedTaxableAmount;
    totalGST = accumulatedGST;
    discountAmount = accumulatedDiscount;
    loyaltyRedemptionAmount = redemptionApplied;
    lineResults = List.unmodifiable(results);

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