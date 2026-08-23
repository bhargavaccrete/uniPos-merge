import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/domain/services/restaurant/tax_breakdown.dart';

/// Regression net for [TaxBreakdown] — the per-rate GST summary printed on the
/// bottom of every bill, restaurant AND retail.
///
/// **Why this file exists.** `TaxBreakdown` had NO test coverage, yet it is
/// shared: `esc_pos_receipt_builder.dart:401` prints restaurant thermal bills
/// through it, and `receipt_pdf_service.dart:690/1450` prints retail's. It is
/// also about to be touched by retail line-item discount, because it currently
/// re-derives the per-rate split from line gross plus ONE bill-level discount
/// (see [uniform factor] group below). These tests pin today's behaviour first,
/// so that change cannot silently alter a restaurant invoice.
///
/// This is a GST-compliance artifact, not decoration: the printed Taxable and
/// GST columns are what a customer and an auditor read.
///
/// [TaxBreakdown] is pure — no DI, no Hive, no TaxFeature — so unlike
/// `cart_calculation_service_test.dart` there is nothing to register.
///
/// Money tolerance: `_round2` lands on 2dp, so `closeTo(x, 0.005)` asserts the
/// rounded value without tripping over float representation.
void main() {
  /// Mirrors the record shape both callers build.
  ({double gross, double ratePercent}) item(double gross, double ratePercent) =>
      (gross: gross, ratePercent: ratePercent);

  double sumGst(List<TaxRateLine> lines) =>
      lines.fold<double>(0, (s, l) => s + l.gst);

  double sumTaxable(List<TaxRateLine> lines) =>
      lines.fold<double>(0, (s, l) => s + l.taxable);

  // ==========================================================================
  group('Test 1 — empty and degenerate input', () {
    test('no items produces no rows', () {
      expect(
        TaxBreakdown.compute(
          items: const [],
          billDiscount: 0,
          isTaxInclusive: false,
        ),
        isEmpty,
      );
    });

    test('all-zero gross produces no rows', () {
      final lines = TaxBreakdown.compute(
        items: [item(0, 18), item(0, 5)],
        billDiscount: 0,
        isTaxInclusive: false,
      );
      expect(lines, isEmpty);
      expect(sumTaxable(lines), 0);
      expect(sumGst(lines), 0);
    });

    // Guarded by `totalGross <= 0`, which also catches a negative total from
    // return lines being fed in.
    test('negative total gross produces no rows', () {
      expect(
        TaxBreakdown.compute(
          items: [item(-100, 18)],
          billDiscount: 0,
          isTaxInclusive: false,
        ),
        isEmpty,
      );
    });

    test('a bill of only 0%-rated items produces no rows', () {
      expect(
        TaxBreakdown.compute(
          items: [item(500, 0), item(250, 0)],
          billDiscount: 0,
          isTaxInclusive: false,
        ),
        isEmpty,
      );
    });
  });

  // ==========================================================================
  group('Test 2 — single GST rate, tax EXCLUSIVE', () {
    test('1000 at 18% with no discount', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      expect(lines, hasLength(1));
      expect(lines.single.ratePercent, 18);
      // Exclusive: the gross IS the taxable base; GST is added on top.
      expect(lines.single.taxable, closeTo(1000, 0.005));
      expect(lines.single.gst, closeTo(180, 0.005));
    });

    test('two lines at the same rate collapse into one row', () {
      final lines = TaxBreakdown.compute(
        items: [item(600, 18), item(400, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      expect(lines, hasLength(1));
      expect(lines.single.taxable, closeTo(1000, 0.005));
      expect(lines.single.gst, closeTo(180, 0.005));
    });
  });

  // ==========================================================================
  group('Test 3 — single GST rate, tax INCLUSIVE', () {
    test('1180 at 18% extracts a 1000 base', () {
      final lines = TaxBreakdown.compute(
        items: [item(1180, 18)],
        billDiscount: 0,
        isTaxInclusive: true,
      );

      expect(lines, hasLength(1));
      // Inclusive: GST is carved OUT of the gross, so taxable < gross and
      // taxable + gst == gross.
      expect(lines.single.taxable, closeTo(1000, 0.005));
      expect(lines.single.gst, closeTo(180, 0.005));
      expect(lines.single.taxable + lines.single.gst, closeTo(1180, 0.01));
    });

    test('inclusive and exclusive differ for the same gross', () {
      List<TaxRateLine> at(bool inclusive) => TaxBreakdown.compute(
            items: [item(1000, 18)],
            billDiscount: 0,
            isTaxInclusive: inclusive,
          );

      expect(at(false).single.taxable, closeTo(1000, 0.005));
      expect(at(true).single.taxable, closeTo(847.46, 0.005)); // 1000 / 1.18
      expect(at(true).single.gst, closeTo(152.54, 0.005));
    });
  });

  // ==========================================================================
  group('Test 4 — multiple rates', () {
    test('rows come back ascending by rate', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18), item(500, 5), item(300, 12)],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      expect(lines.map((l) => l.ratePercent).toList(), [5, 12, 18]);
    });

    test('each rate is taxed on its own gross', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18), item(500, 5)],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);
      expect(five.taxable, closeTo(500, 0.005));
      expect(five.gst, closeTo(25, 0.005));
      expect(eighteen.taxable, closeTo(1000, 0.005));
      expect(eighteen.gst, closeTo(180, 0.005));
    });

    // A 0%-rated line is dropped from the SUMMARY but still counts toward
    // totalGross, so it dilutes the discount factor. Pinned because it is easy
    // to "fix" by accident and it changes every mixed-rate bill.
    test('0% lines are dropped from the table but still dilute the discount',
        () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18), item(1000, 0)],
        billDiscount: 200,
        isTaxInclusive: false,
      );

      expect(lines, hasLength(1));
      expect(lines.single.ratePercent, 18);
      // factor = (2000 - 200) / 2000 = 0.9  →  1000 * 0.9 = 900
      // If the 0% line were excluded from totalGross the factor would be 0.8
      // and this would read 800 / 144.
      expect(lines.single.taxable, closeTo(900, 0.005));
      expect(lines.single.gst, closeTo(162, 0.005));
    });
  });

  // ==========================================================================
  group('Test 5 — bill-level discount', () {
    test('a discount scales every rate down proportionally', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 100,
        isTaxInclusive: false,
      );

      // factor = 900 / 1000 = 0.9
      expect(lines.single.taxable, closeTo(900, 0.005));
      expect(lines.single.gst, closeTo(162, 0.005));
    });

    // An ORDER-level discount is uniform by definition, so spreading it evenly
    // across rates is correct — and must stay that way. This is the behaviour
    // every existing restaurant bill relies on.
    test('an order-level discount spreads uniformly across rates', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18), item(1000, 5)],
        billDiscount: 200, // 10% of the 2000 bill
        isTaxInclusive: false,
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);

      // Both rates lose exactly 10%, because the discount belonged to neither.
      expect(five.taxable, closeTo(900, 0.005));
      expect(eighteen.taxable, closeTo(900, 0.005));
    });

    test('a discount larger than the bill clamps to zero, never negative', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 5000,
        isTaxInclusive: false,
      );

      // The row survives, zeroed — nothing downstream has to handle a negative
      // taxable base or negative GST.
      expect(lines, hasLength(1));
      expect(lines.single.taxable, 0);
      expect(lines.single.gst, 0);
    });

    test('a discount equal to the bill zeroes the rows', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 1000,
        isTaxInclusive: false,
      );
      expect(lines.single.taxable, 0);
      expect(lines.single.gst, 0);
    });

    test('discount works the same way in inclusive mode', () {
      final lines = TaxBreakdown.compute(
        items: [item(1180, 18)],
        billDiscount: 118, // 10%
        isTaxInclusive: true,
      );

      // rateShare = 1062  →  taxable = 1062 / 1.18 = 900, gst = 162
      expect(lines.single.taxable, closeTo(900, 0.005));
      expect(lines.single.gst, closeTo(162, 0.005));
    });
  });

  // ==========================================================================
  // What was actually broken before `computeWithLineDiscounts` existed: there
  // was NO WAY to express a discount that belonged to one line. The only input
  // was `billDiscount`, so a per-line discount had to be smuggled in as an
  // order-level one — and *that* is where the uniform spread gave the wrong
  // answer. These tests pin the correct per-rate maths.
  group('Line-item discounts (computeWithLineDiscounts)', () {
    ({double gross, double lineDiscount, double ratePercent}) line(
      double gross,
      double ratePercent, {
      double discount = 0,
    }) =>
        (gross: gross, lineDiscount: discount, ratePercent: ratePercent);

    // THE core property: a line's discount touches its own rate bucket only.
    test('a line discount stays on its own rate', () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [
          line(1000, 18, discount: 400), // 40% off this item
          line(1000, 5), // untouched
        ],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);

      // Correct: the 18% base drops by its own 400, the 5% base does not move.
      expect(eighteen.taxable, closeTo(600, 0.005));
      expect(eighteen.gst, closeTo(108, 0.005));
      expect(five.taxable, closeTo(1000, 0.005));
      expect(five.gst, closeTo(50, 0.005));

      // And explicitly NOT the old smear, which had to route this 400 through
      // billDiscount and gave both rates 800 / 40 / 144.
      expect(five.taxable, isNot(closeTo(800, 0.005)));
      expect(eighteen.taxable, isNot(closeTo(800, 0.005)));
    });

    test('line discounts apply first, then the order discount on the remainder',
        () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [
          line(1000, 18, discount: 400), // net 600
          line(1000, 5), // net 1000
        ],
        billDiscount: 160, // 10% of the 1600 that is left
        isTaxInclusive: false,
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);

      // factor = (1600 - 160) / 1600 = 0.9
      expect(five.taxable, closeTo(900, 0.005));
      expect(five.gst, closeTo(45, 0.005));
      expect(eighteen.taxable, closeTo(540, 0.005));
      expect(eighteen.gst, closeTo(97.2, 0.005));
    });

    test('a line discount works in inclusive mode too', () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [line(1180, 18, discount: 180)], // net 1000
        billDiscount: 0,
        isTaxInclusive: true,
      );

      expect(lines.single.taxable, closeTo(847.46, 0.005)); // 1000 / 1.18
      expect(lines.single.gst, closeTo(152.54, 0.005));
    });

    test('a line discount larger than its line is capped, never bleeding over',
        () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [
          line(500, 18, discount: 900), // capped at 500 → net 0
          line(1000, 5), // must be untouched by the overflow
        ],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);

      expect(eighteen.taxable, 0);
      expect(eighteen.gst, 0);
      expect(five.taxable, closeTo(1000, 0.005)); // the extra 400 went nowhere
    });

    test('discounting every line to zero yields zeroed rows, not NaN', () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [line(1000, 18, discount: 1000)],
        billDiscount: 0,
        isTaxInclusive: false,
      );

      expect(lines, hasLength(1));
      expect(lines.single.taxable, 0);
      expect(lines.single.gst, 0);
      expect(lines.single.gst.isNaN, isFalse);
    });

    test('a line discount on a 0%-rated line still dilutes the order discount',
        () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [
          line(1000, 18),
          line(1000, 0, discount: 500), // net 500, dropped from the table
        ],
        billDiscount: 150,
        isTaxInclusive: false,
      );

      // totalNet = 1500, factor = (1500 - 150) / 1500 = 0.9
      expect(lines, hasLength(1));
      expect(lines.single.taxable, closeTo(900, 0.005));
    });

    test('line discounts reconcile to the order GST like anything else', () {
      final lines = TaxBreakdown.computeWithLineDiscounts(
        items: [line(1000, 18, discount: 400), line(1000, 5)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 160, // raw derivation is 108 + 50 = 158
      );

      expect(sumGst(lines), closeTo(160, 0.005));
      // Taxable still preserved, exactly as with an order-level discount.
      expect(lines.firstWhere((l) => l.ratePercent == 18).taxable,
          closeTo(600, 0.005));
      expect(lines.firstWhere((l) => l.ratePercent == 5).taxable,
          closeTo(1000, 0.005));
    });

    // The backward-compatibility contract that keeps restaurant safe: with
    // every line discount at zero, the new path IS the old path.
    test('zero line discounts are identical to compute()', () {
      const cases = [
        (billDiscount: 0.0, inclusive: false, reconcile: null),
        (billDiscount: 200.0, inclusive: false, reconcile: null),
        (billDiscount: 200.0, inclusive: true, reconcile: null),
        (billDiscount: 0.0, inclusive: false, reconcile: 100.0),
        (billDiscount: 5000.0, inclusive: false, reconcile: null),
      ];

      for (final c in cases) {
        final viaCompute = TaxBreakdown.compute(
          items: [item(1000, 18), item(1000, 12), item(500, 5), item(300, 0)],
          billDiscount: c.billDiscount,
          isTaxInclusive: c.inclusive,
          reconcileToGst: c.reconcile,
        );
        final viaLineDiscounts = TaxBreakdown.computeWithLineDiscounts(
          items: [line(1000, 18), line(1000, 12), line(500, 5), line(300, 0)],
          billDiscount: c.billDiscount,
          isTaxInclusive: c.inclusive,
          reconcileToGst: c.reconcile,
        );

        expect(viaLineDiscounts, hasLength(viaCompute.length), reason: '$c');
        for (var i = 0; i < viaCompute.length; i++) {
          expect(viaLineDiscounts[i].ratePercent,
              viaCompute[i].ratePercent, reason: '$c');
          expect(viaLineDiscounts[i].taxable,
              closeTo(viaCompute[i].taxable, 1e-9), reason: '$c');
          expect(viaLineDiscounts[i].gst,
              closeTo(viaCompute[i].gst, 1e-9), reason: '$c');
        }
      }
    });
  });

  // ==========================================================================
  group('Test 6 — reconcileToGst', () {
    // The contract that matters most: GST is scaled to the order's
    // authoritative total, and TAXABLE IS DELIBERATELY PRESERVED so the
    // Taxable column still matches the printed line amounts.
    test('scales GST to the authoritative total and PRESERVES taxable', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 200, // order says 200, raw derivation says 180
      );

      expect(lines.single.gst, closeTo(200, 0.005));
      // NOT back-solved to 200 / 0.18 = 1111.11.
      expect(lines.single.taxable, closeTo(1000, 0.005));
    });

    test('lines always sum EXACTLY to reconcileToGst', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18), item(1000, 12), item(1000, 5)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 100, // raw sum would be 350
      );

      expect(sumGst(lines), closeTo(100, 0.005));
    });

    // Exercises the residual branch: naive scaling gives 14.29 + 34.29 + 51.43
    // = 100.01, so 0.01 is pushed onto the largest-GST line (18%).
    test('a rounding residual is pushed onto the largest-GST line', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18), item(1000, 12), item(1000, 5)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 100,
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final twelve = lines.firstWhere((l) => l.ratePercent == 12);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);

      expect(five.gst, closeTo(14.29, 0.005));
      expect(twelve.gst, closeTo(34.29, 0.005));
      expect(eighteen.gst, closeTo(51.42, 0.005)); // 51.43 − 0.01 residual

      // Taxable untouched by reconciliation, on every line.
      expect(five.taxable, closeTo(1000, 0.005));
      expect(twelve.taxable, closeTo(1000, 0.005));
      expect(eighteen.taxable, closeTo(1000, 0.005));
    });

    test('null reconcileToGst leaves the raw derivation alone', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
      );
      expect(lines.single.gst, closeTo(180, 0.005));
    });

    test('zero reconcileToGst is ignored (guarded by > 0.009)', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 0,
      );
      expect(lines.single.gst, closeTo(180, 0.005));
    });

    test('a sub-paisa reconcileToGst is ignored', () {
      final lines = TaxBreakdown.compute(
        items: [item(1000, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 0.005,
      );
      expect(lines.single.gst, closeTo(180, 0.005));
    });

    // Raw GST rounds to 0, so there is nothing to scale — guarded by
    // `rawSum > 0.009`, which stops a divide-by-zero blowing the receipt up.
    test('a raw GST sum of zero is not reconciled', () {
      final lines = TaxBreakdown.compute(
        items: [item(0.001, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 50,
      );

      expect(lines, hasLength(1));
      expect(lines.single.gst, 0);
      expect(lines.single.taxable, 0);
    });
  });

  // ==========================================================================
  // Realistic shapes taken from the real call sites, not invented ones.
  //
  //   restaurant — esc_pos_receipt_builder.dart:401
  //     items:          (gross: receiptLineGross(it) → it.total, it.gstRate)
  //     billDiscount:   sale.discountAmount ?? 0
  //     reconcileToGst: sale.totalGstAmount ?? 0     ← ALWAYS passed
  //
  //   retail — receipt_pdf_service.dart:690 / :1450
  //     items:          (gross: price * qty, it.gstRate)
  //     same discount + reconcile arguments
  group('Restaurant regression baseline (thermal receipt path)', () {
    test('single-rate 5% food bill, inclusive, reconciled', () {
      final lines = TaxBreakdown.compute(
        items: [item(210, 5), item(105, 5)],
        billDiscount: 0,
        isTaxInclusive: true,
        reconcileToGst: 15,
      );

      expect(lines, hasLength(1));
      expect(lines.single.ratePercent, 5);
      expect(lines.single.taxable, closeTo(300, 0.005)); // 315 / 1.05
      expect(lines.single.gst, closeTo(15, 0.005));
      // Sub Total and Total Tax on the printed bill must reconcile.
      expect(lines.single.taxable + lines.single.gst, closeTo(315, 0.01));
    });

    test('mixed 5% + 18% bill with a discount, inclusive, reconciled', () {
      final lines = TaxBreakdown.compute(
        items: [item(500, 5), item(236, 18)],
        billDiscount: 100,
        isTaxInclusive: true,
        reconcileToGst: 51.70, // raw derivation lands on 51.68
      );

      final five = lines.firstWhere((l) => l.ratePercent == 5);
      final eighteen = lines.firstWhere((l) => l.ratePercent == 18);

      // Taxable comes from the raw derivation and is NOT rescaled…
      expect(five.taxable, closeTo(411.49, 0.005));
      expect(eighteen.taxable, closeTo(172.83, 0.005));
      // …while GST is nudged 20.57→20.58 and 31.11→31.12 to hit the order total.
      expect(five.gst, closeTo(20.58, 0.005));
      expect(eighteen.gst, closeTo(31.12, 0.005));
      expect(sumGst(lines), closeTo(51.70, 0.005));
    });

    test('exclusive-mode restaurant bill, reconciled to its own GST', () {
      final lines = TaxBreakdown.compute(
        items: [item(800, 5), item(200, 18)],
        billDiscount: 0,
        isTaxInclusive: false,
        reconcileToGst: 76, // 40 + 36
      );

      expect(lines.map((l) => l.ratePercent).toList(), [5, 18]);
      expect(lines[0].taxable, closeTo(800, 0.005));
      expect(lines[0].gst, closeTo(40, 0.005));
      expect(lines[1].taxable, closeTo(200, 0.005));
      expect(lines[1].gst, closeTo(36, 0.005));
      expect(sumGst(lines), closeTo(76, 0.005));
    });

    test('a fully discounted comp bill prints zeroed rows, not negatives', () {
      final lines = TaxBreakdown.compute(
        items: [item(315, 5)],
        billDiscount: 315,
        isTaxInclusive: true,
        reconcileToGst: 0, // nothing collected, so nothing to reconcile
      );

      expect(lines, hasLength(1));
      expect(lines.single.taxable, 0);
      expect(lines.single.gst, 0);
    });
  });

  // ==========================================================================
  group('Rounding', () {
    test('taxable and GST are rounded to 2 decimals', () {
      final lines = TaxBreakdown.compute(
        items: [item(333.33, 18)],
        billDiscount: 0,
        isTaxInclusive: true,
      );

      // 333.33 / 1.18 = 282.4830508…  →  282.48
      expect(lines.single.taxable, closeTo(282.48, 0.005));
      expect(lines.single.gst, closeTo(50.85, 0.005));

      for (final l in lines) {
        expect((l.taxable * 100).roundToDouble() / 100, closeTo(l.taxable, 1e-9));
        expect((l.gst * 100).roundToDouble() / 100, closeTo(l.gst, 1e-9));
      }
    });
  });

  // ==========================================================================
  // Guards the mode DETECTOR, which both receipt paths call before compute.
  // Getting this wrong prints an exclusive bill as inclusive and vice versa.
  group('isInclusiveFromTotals', () {
    test('detects an exclusive bill (tax added on top)', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 1000,
          discount: 0,
          taxAmount: 180,
          grandTotal: 1180,
          fallback: true, // deliberately wrong, must be overridden
        ),
        isFalse,
      );
    });

    test('detects an inclusive bill (tax already inside)', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 1180,
          discount: 0,
          taxAmount: 180,
          grandTotal: 1180,
          fallback: false, // deliberately wrong, must be overridden
        ),
        isTrue,
      );
    });

    test('accounts for a discount', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 1000,
          discount: 100,
          taxAmount: 162,
          grandTotal: 1062,
          fallback: true,
        ),
        isFalse,
      );
    });

    test('accounts for a service charge', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 1000,
          discount: 0,
          taxAmount: 180,
          grandTotal: 1230,
          serviceCharge: 50,
          fallback: true,
        ),
        isFalse,
      );
    });

    test('accounts for loyalty redemption', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 1000,
          discount: 0,
          taxAmount: 180,
          grandTotal: 1080,
          loyaltyDiscount: 100,
          fallback: true,
        ),
        isFalse,
      );
    });

    test('falls back when there is no gross to reason about', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 0,
          discount: 0,
          taxAmount: 180,
          grandTotal: 1180,
          fallback: true,
        ),
        isTrue,
      );
    });

    test('falls back when no tax was charged', () {
      for (final fb in [true, false]) {
        expect(
          TaxBreakdown.isInclusiveFromTotals(
            grossBeforeDiscount: 1000,
            discount: 0,
            taxAmount: 0,
            grandTotal: 1000,
            fallback: fb,
          ),
          fb,
        );
      }
    });

    // An exact tie resolves to inclusive because the comparison is `<=`.
    test('an ambiguous total resolves to inclusive', () {
      expect(
        TaxBreakdown.isInclusiveFromTotals(
          grossBeforeDiscount: 1000,
          discount: 0,
          taxAmount: 180,
          grandTotal: 1090, // exactly between 1000 and 1180
          fallback: false,
        ),
        isTrue,
      );
    });
  });
}
