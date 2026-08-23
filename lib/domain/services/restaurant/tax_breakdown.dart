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
/// Two kinds of discount reach a bill and they must be spread differently:
///
///  * a **line discount** belongs to one item, so it comes off that item's own
///    rate bucket and nothing else;
///  * a **bill discount** belongs to the whole order, so it is inherently
///    uniform and spreads proportionally over whatever is left.
///
/// Line discounts first, then the bill discount on the remainder — matching
/// `cart_calculation_service.dart` (discount before tax) and how a shop explains
/// it ("40% off this shirt, then 10% off the bill"). Computed purely from
/// receipt data, so it works for first-prints and re-prints alike.
class TaxBreakdown {
  /// Per-rate summary for a bill whose discount is entirely order-level.
  ///
  /// [items] = each line's gross (price*qty) + its tax rate (%).
  /// [billDiscount] = the order's total discount amount.
  ///
  /// A thin adapter over [computeWithLineDiscounts] with every line discount at
  /// zero, so this signature — and therefore both existing receipt callers —
  /// stay exactly as they were.
  static List<TaxRateLine> compute({
    required List<({double gross, double ratePercent})> items,
    required double billDiscount,
    required bool isTaxInclusive,
    double? reconcileToGst,
  }) {
    return computeWithLineDiscounts(
      items: items
          .map((it) => (
                gross: it.gross,
                lineDiscount: 0.0,
                ratePercent: it.ratePercent,
              ))
          .toList(),
      billDiscount: billDiscount,
      isTaxInclusive: isTaxInclusive,
      reconcileToGst: reconcileToGst,
    );
  }

  /// Per-rate summary where each line may carry its OWN discount.
  ///
  /// [items] = per line: gross (price*qty), that line's own discount, its rate.
  /// [billDiscount] = order-level discount ONLY. Anything already accounted for
  /// in a line's [lineDiscount] must not be repeated here, or it is deducted
  /// twice.
  /// [reconcileToGst] = the order's authoritative total GST (`sale.taxAmount`).
  /// When provided, the per-rate GST is scaled so the lines sum EXACTLY to it,
  /// while each taxable is PRESERVED (it is the real per-rate base, and matches
  /// the amounts printed on the item lines).
  /// Returns rates ascending; 0% rates are dropped from the summary table.
  ///
  /// A line discount larger than its line is capped at the line — it can never
  /// bleed onto another rate.
  static List<TaxRateLine> computeWithLineDiscounts({
    required List<({double gross, double lineDiscount, double ratePercent})>
        items,
    required double billDiscount,
    required bool isTaxInclusive,
    double? reconcileToGst,
  }) {
    final totalGross = items.fold<double>(0, (s, it) => s + it.gross);
    if (totalGross <= 0) return const [];

    // STEP 1 — each line's own discount comes off its own rate bucket.
    final netByRate = <double, double>{};
    double totalNet = 0;
    for (final it in items) {
      // Capped at the line, and a zero discount leaves `gross` untouched
      // (including a negative gross) so the discount-free path is unchanged.
      final wanted = it.lineDiscount > 0 ? it.lineDiscount : 0.0;
      final capped = wanted > it.gross ? (it.gross > 0 ? it.gross : 0.0) : wanted;
      final net = it.gross - capped;

      netByRate[it.ratePercent] = (netByRate[it.ratePercent] ?? 0) + net;
      totalNet += net;
    }

    // STEP 2 — the order-level remainder is uniform by nature, so it spreads
    // proportionally across what the line discounts left behind.
    final afterBillDiscount =
        (totalNet - billDiscount).clamp(0, double.infinity).toDouble();
    // Guard the division: line discounts can legitimately take the whole bill
    // to zero, which must yield zeroed rows rather than NaN.
    final factor = totalNet > 0 ? afterBillDiscount / totalNet : 0.0;

    var lines = <TaxRateLine>[];
    final rates = netByRate.keys.toList()..sort();
    for (final rate in rates) {
      if (rate <= 0) continue; // 0% items don't appear in the summary
      final rateShare = netByRate[rate]! * factor;
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
