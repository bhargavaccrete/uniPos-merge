import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/cart_model_202.dart';
import '../restaurant/cart_calculation_service.dart';
import 'gst_service.dart';

export '../restaurant/cart_calculation_service.dart' show DiscountType;

/// One priced line of a retail bill, already reconciled with the bill totals.
///
/// Callers persist these straight onto `SaleItemModel` — they must not re-derive
/// a per-item taxable amount, because the item's share of an order-level
/// discount is only knowable from the whole bill.
class RetailBillLine {
  /// The cart row this line was computed from.
  final CartItemModel item;

  /// price * qty, before any discount.
  final double originalAmount;

  /// This line's share of the order discount.
  final double discountAmount;

  /// Base this line is taxed on — after discount and loyalty redemption.
  final double taxableAmount;

  final double gstAmount;
  final double cgstAmount;
  final double sgstAmount;

  /// GST rate as a PERCENT (18 for 18%), matching `CartItemModel.gstRate`.
  final double gstRatePercent;

  const RetailBillLine({
    required this.item,
    required this.originalAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.gstRatePercent,
  });

  /// What this line contributes to the grand total.
  double get total => taxableAmount + gstAmount;
}

/// The computed result of a retail bill. Every retail screen that creates a
/// record reads its numbers from here.
class RetailBill {
  /// Gross total of all lines, before any discount.
  final double itemTotal;

  /// Resolved discount in currency, whatever type was entered.
  final double discountAmount;

  /// Sum of line taxable amounts — after discount and loyalty, before GST.
  final double taxableAmount;

  final double totalGst;
  final double cgstAmount;
  final double sgstAmount;

  /// Currency value of loyalty points actually applied (clamped to the bill).
  final double loyaltyRedemption;

  /// Rounding adjustment applied to reach [grandTotal]; may be negative.
  final double roundOff;

  /// The amount payable. This is the ONLY number that should ever be shown as
  /// the bill total, on any screen.
  final double grandTotal;

  /// GST totals grouped by rate, keyed by PERCENT (18.0 for 18%).
  final Map<double, GstRateBreakdown> gstBreakdown;

  final List<RetailBillLine> lines;

  /// Tax mode this bill was computed under — persist it so a reprint months
  /// later renders the same way even if the store toggles the setting.
  final bool isTaxInclusive;

  const RetailBill({
    required this.itemTotal,
    required this.discountAmount,
    required this.taxableAmount,
    required this.totalGst,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.loyaltyRedemption,
    required this.roundOff,
    required this.grandTotal,
    required this.gstBreakdown,
    required this.lines,
    required this.isTaxInclusive,
  });

  /// Total quantity across all lines.
  int get totalItems => lines.fold(0, (s, l) => s + l.item.qty);

  static const RetailBill empty = RetailBill(
    itemTotal: 0,
    discountAmount: 0,
    taxableAmount: 0,
    totalGst: 0,
    cgstAmount: 0,
    sgstAmount: 0,
    loyaltyRedemption: 0,
    roundOff: 0,
    grandTotal: 0,
    gstBreakdown: {},
    lines: [],
    isTaxInclusive: false,
  );
}

/// The single source of truth for retail money math.
///
/// Every retail screen that CREATES a record — POS footer, cart panel, checkout
/// (including Pay Later), hold sale, restore-from-park, returns — computes via
/// this service and persists what it returns. Screens that DISPLAY a settled
/// record read the stored `SaleModel` fields instead and must never call this,
/// or a later change to a tax rate or the round-off setting would silently
/// reprice historical invoices.
///
/// Internally this delegates to [CartCalculationService], the same engine the
/// restaurant side uses, so the two verticals can never drift apart.
class RetailBillingService {
  RetailBillingService._();

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  /// Compute a bill. Synchronous so it can be called directly from `build()`.
  ///
  /// [isTaxInclusive] must be supplied by the caller — fetch it once via
  /// [loadTaxInclusive] and hold it, rather than reading it per frame.
  static RetailBill compute({
    required List<CartItemModel> items,
    required bool isTaxInclusive,
    DiscountType discountType = DiscountType.amount,
    double discountValue = 0,
    double loyaltyRedemption = 0,
    bool? discountOnItems,
  }) {
    if (items.isEmpty) return RetailBill.empty;

    final calc = CartCalculationService.fromLines(
      lines: items
          .map((i) => CalcLine(
                price: i.price,
                quantity: i.qty,
                // CartItemModel.gstRate is a PERCENT (18); the engine expects a
                // FRACTION (0.18). Getting this wrong is a 100x error.
                taxRate: (i.gstRate ?? 0) / 100.0,
              ))
          .toList(),
      discountType: discountType,
      discountValue: discountValue,
      loyaltyRedemption: loyaltyRedemption,
      isTaxInclusive: isTaxInclusive,
      discountOnItems: discountOnItems,
      // Retail has no service or delivery charge — that is restaurant-only.
      serviceChargePercentage: 0,
      deliveryCharge: 0,
      isDeliveryOrder: false,
    );

    final lines = <RetailBillLine>[];
    for (int i = 0; i < items.length; i++) {
      final r = calc.lineResults[i];
      final gst = _r2(r.gstAmount);
      final half = _r2(gst / 2);
      lines.add(RetailBillLine(
        item: items[i],
        originalAmount: _r2(r.originalAmount),
        discountAmount: _r2(r.discountAmount),
        taxableAmount: _r2(r.taxableAmount),
        gstAmount: gst,
        cgstAmount: half,
        sgstAmount: half,
        gstRatePercent: _r2(r.taxRate * 100.0),
      ));
    }

    final totalGst = _r2(calc.totalGST);
    final halfGst = _r2(totalGst / 2);

    return RetailBill(
      itemTotal: _r2(calc.itemTotal),
      discountAmount: _r2(calc.discountAmount),
      taxableAmount: _r2(calc.taxableAmount),
      totalGst: totalGst,
      cgstAmount: halfGst,
      sgstAmount: halfGst,
      loyaltyRedemption: _r2(calc.loyaltyRedemptionAmount),
      roundOff: _r2(calc.roundOffAmount),
      grandTotal: _r2(calc.grandTotal),
      gstBreakdown: _breakdown(lines),
      lines: List.unmodifiable(lines),
      isTaxInclusive: isTaxInclusive,
    );
  }

  /// Retail's tax-inclusive flag. Retail stores this under its own
  /// SharedPreferences key via [GstService], separate from the restaurant
  /// `AppSettings` toggle — so it must be passed to [compute] explicitly rather
  /// than letting the engine fall back to the restaurant setting.
  static Future<bool> loadTaxInclusive() => gstService.isTaxInclusiveMode();

  /// Convenience wrapper that resolves the tax mode itself.
  static Future<RetailBill> computeAsync({
    required List<CartItemModel> items,
    DiscountType discountType = DiscountType.amount,
    double discountValue = 0,
    double loyaltyRedemption = 0,
    bool? discountOnItems,
  }) async {
    return compute(
      items: items,
      isTaxInclusive: await loadTaxInclusive(),
      discountType: discountType,
      discountValue: discountValue,
      loyaltyRedemption: loyaltyRedemption,
      discountOnItems: discountOnItems,
    );
  }

  static Map<double, GstRateBreakdown> _breakdown(List<RetailBillLine> lines) {
    final map = <double, GstRateBreakdown>{};
    for (final l in lines) {
      final rate = l.gstRatePercent;
      final existing = map[rate];
      map[rate] = GstRateBreakdown(
        gstRate: rate,
        taxableAmount: (existing?.taxableAmount ?? 0) + l.taxableAmount,
        cgstAmount: (existing?.cgstAmount ?? 0) + l.cgstAmount,
        sgstAmount: (existing?.sgstAmount ?? 0) + l.sgstAmount,
        totalGstAmount: (existing?.totalGstAmount ?? 0) + l.gstAmount,
      );
    }
    return map;
  }
}
