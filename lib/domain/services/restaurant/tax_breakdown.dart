/// One row of the bill's "Tax Summary" — a tax rate with its taxable base and GST.
class TaxRateLine {
  final double ratePercent; // e.g. 5, 18
  final double taxable; // base the GST is charged on (after discount)
  final double gst; // GST amount for this rate

  const TaxRateLine({
    required this.ratePercent,
    required this.taxable,
    required this.gst,
  });
}

/// Builds the per-rate tax summary for a bill.
///
/// Receipts only carry each item's UNDISCOUNTED gross + its rate, and the
/// discount is bill-level. So we re-distribute the discount across rates exactly
/// like `cart_calculation_service.dart` (proportional to each item's gross,
/// discount applied before tax). Computed purely from receipt data so it works
/// for first-prints and re-prints alike.
class TaxBreakdown {
  /// [items] = each line's gross (price*qty) + its tax rate (%).
  /// [billDiscount] = the order's total discount amount.
  /// [reconcileToGst] = the order's authoritative total GST (`sale.taxAmount`).
  /// When provided, the per-rate GST is scaled so the lines sum EXACTLY to it
  /// (and each taxable is back-filled so `taxable × rate = GST`). This guarantees
  /// the bill's breakdown always matches the order, even though the receipt's
  /// per-item prices are mode-adjusted by the global setting.
  /// Returns rates ascending; 0% rates are dropped from the summary table.
  static List<TaxRateLine> compute({
    required List<({double gross, double ratePercent})> items,
    required double billDiscount,
    required bool isTaxInclusive,
    double? reconcileToGst,
  }) {
    final totalGross = items.fold<double>(0, (s, it) => s + it.gross);
    if (totalGross <= 0) return const [];

    // Same proportional, discount-before-tax distribution as the cart service.
    final afterDiscount =
        (totalGross - billDiscount).clamp(0, double.infinity).toDouble();
    final factor = afterDiscount / totalGross;

    final grossByRate = <double, double>{};
    for (final it in items) {
      grossByRate[it.ratePercent] =
          (grossByRate[it.ratePercent] ?? 0) + it.gross;
    }

    var lines = <TaxRateLine>[];
    final rates = grossByRate.keys.toList()..sort();
    for (final rate in rates) {
      if (rate <= 0) continue; // 0% items don't appear in the summary
      final rateShare = grossByRate[rate]! * factor;
      final double taxable;
      final double gst;
      if (isTaxInclusive) {
        taxable = rateShare / (1 + rate / 100);
        gst = rateShare - taxable;
      } else {
        taxable = rateShare;
        gst = taxable * (rate / 100);
      }
      lines.add(TaxRateLine(
          ratePercent: rate, taxable: _round2(taxable), gst: _round2(gst)));
    }

    // Reconcile the GST split to the authoritative total so the printed lines
    // always sum to the order's GST. Each line's taxable is PRESERVED (it is the
    // real per-rate base = the amount shown on the item line); only the GST is
    // scaled, so `Σ taxable = Sub Total` and `Σ gst = Total GST` both hold and
    // the taxable column matches the line amounts exactly.
    if (reconcileToGst != null && reconcileToGst > 0.009 && lines.isNotEmpty) {
      final rawSum = lines.fold<double>(0, (s, l) => s + l.gst);
      if (rawSum > 0.009) {
        final f = reconcileToGst / rawSum;
        lines = [
          for (final l in lines)
            TaxRateLine(
              ratePercent: l.ratePercent,
              gst: _round2(l.gst * f),
              taxable: l.taxable, // preserve the real base; only GST is reconciled
            )
        ];
        // Push any rounding residual onto the largest line so they sum exactly.
        final residual =
            _round2(reconcileToGst - lines.fold<double>(0, (s, l) => s + l.gst));
        if (residual.abs() >= 0.01) {
          var bi = 0;
          for (var i = 1; i < lines.length; i++) {
            if (lines[i].gst > lines[bi].gst) bi = i;
          }
          final b = lines[bi];
          lines[bi] = TaxRateLine(
            ratePercent: b.ratePercent,
            gst: _round2(b.gst + residual),
            taxable: b.taxable, // keep the base; residual only adjusts GST
          );
        }
      }
    }
    return lines;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// Robustly derive the tax mode from the order's own totals — the stored
  /// `isTaxInclusive` flag can be null/stale and fall back to the current global
  /// setting, which may not match how THIS order was priced.
  ///
  /// Inclusive  ⇒ grand ≈ (gross − discount)            (tax already inside)
  /// Exclusive  ⇒ grand ≈ (gross − discount) + tax       (tax added on top)
  static bool isInclusiveFromTotals({
    required double grossBeforeDiscount,
    required double discount,
    required double taxAmount,
    required double grandTotal,
    double serviceCharge = 0,
    double loyaltyDiscount = 0,
    required bool fallback,
  }) {
    if (grossBeforeDiscount <= 0 || taxAmount <= 0.009) return fallback;
    final afterDiscount =
        grossBeforeDiscount - discount + serviceCharge - loyaltyDiscount;
    final inclusiveErr = (grandTotal - afterDiscount).abs();
    final exclusiveErr = (grandTotal - (afterDiscount + taxAmount)).abs();
    return inclusiveErr <= exclusiveErr;
  }
}
