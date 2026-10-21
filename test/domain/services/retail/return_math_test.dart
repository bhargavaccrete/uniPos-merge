import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/return_math.dart';

/// Pure money math for sale returns.
///
/// The two defects this suite exists to pin:
///   * B1 — a tax-INCLUSIVE partial return used to add GST on top of a price
///     that already contained it, refunding ~15% more than was charged.
///   * B5 — nothing tracked how much of a line had already come back, so the
///     same units could be refunded repeatedly.
void main() {
  /// A line as CHECKOUT wrote it: engine figures, via `fromCalculated`.
  SaleItemModel line({
    String variantId = 'v1',
    double price = 100,
    double qty = 1,
    double discountAmount = 0,
    double? lineDiscountAmount,
    required double taxableAmount,
    required double gstAmount,
    required double total,
    double gstRate = 18,
  }) =>
      SaleItemModel.fromCalculated(
        saleId: 's1',
        varianteId: variantId,
        productId: 'p1',
        productName: 'Test Item',
        price: price,
        qty: qty,
        discountAmount: discountAmount,
        gstRate: gstRate,
        taxableAmount: taxableAmount,
        gstAmount: gstAmount,
        total: total,
        costPrice: 60,
        lineDiscountAmount: lineDiscountAmount,
      );

  /// A return line as the RETURN path stores it: qty positive.
  SaleItemModel returnedLine({required String variantId, required double qty}) =>
      SaleItemModel.fromCalculated(
        saleId: 'RTN_1',
        varianteId: variantId,
        productId: 'p1',
        productName: 'Test Item',
        price: 100,
        qty: qty,
        discountAmount: 0,
        gstRate: 18,
        taxableAmount: 100,
        gstAmount: 18,
        total: 118,
      );

  SaleModel sale({
    required double totalAmount,
    double subtotal = 0,
    double discountAmount = 0,
    double taxAmount = 0,
    double dueAmount = 0,
    String paymentType = 'cash',
  }) =>
      SaleModel(
        saleId: 's1',
        totalItems: 1,
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        paymentType: paymentType,
        date: '2026-08-24T10:00:00.000',
        createdAt: '2026-08-24T10:00:00.000',
        updatedAt: '2026-08-24T10:00:00.000',
        dueAmount: dueAmount,
      );

  // ==========================================================================
  // B1 — the over-refund. THE test of this file.
  group('tax-inclusive returns refund what was charged', () {
    // MRP 118 at 18% inclusive: the customer paid 118, of which 18 is GST.
    // Stored: price=118 (inclusive), taxable=100, gst=18, total=118.
    SaleItemModel inclusiveLine({double qty = 1}) => line(
          price: 118,
          qty: qty,
          taxableAmount: 100.0 * qty,
          gstAmount: 18.0 * qty,
          total: 118.0 * qty,
        );

    test('a partial return of 1 refunds 118, NOT 136', () {
      final sold = [inclusiveLine(qty: 3)];
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 354),
        soldLines: sold,
        returnQtyByVariantId: {'v1': 1},
      );

      // The old formula was `price*qty - discount + tax` = 118 - 0 + 18 = 136.
      expect(r.totalAmount, closeTo(118, 0.005));
      expect(r.totalAmount, isNot(closeTo(136, 0.005)));
    });

    test('the returned LINE keeps the inclusive tax shape', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 354),
        soldLines: [inclusiveLine(qty: 3)],
        returnQtyByVariantId: {'v1': 1},
      );

      final l = r.lines.single;
      // Not taxable=118 / gst=21.24 / total=139.24, which is what rebuilding
      // the line through the exclusive branch produced.
      expect(l.taxableAmount, closeTo(100, 0.005));
      expect(l.gstAmount, closeTo(18, 0.005));
      expect(l.total, closeTo(118, 0.005));
    });

    test('a fully-returned inclusive line nets its revenue to zero', () {
      final sold = inclusiveLine(qty: 1);
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 118),
        soldLines: [sold],
        returnQtyByVariantId: {'v1': 1},
      );

      // Reports compute ex-tax revenue as `total - gstAmount`. Sale and return
      // must cancel exactly, or product/profit reports drift.
      double netRevenue(double total, double gst) => total - gst;
      expect(
        netRevenue(sold.total, sold.gstAmount!) -
            netRevenue(r.lines.single.total, r.lines.single.gstAmount),
        closeTo(0, 0.005),
      );
    });
  });

  // ==========================================================================
  group('tax-exclusive returns are unchanged', () {
    test('a partial return of 1 refunds 118 on a 100 + 18 line', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 354),
        soldLines: [
          line(price: 100, qty: 3, taxableAmount: 300, gstAmount: 54, total: 354)
        ],
        returnQtyByVariantId: {'v1': 1},
      );

      expect(r.subtotal, closeTo(100, 0.005));
      expect(r.taxAmount, closeTo(18, 0.005));
      expect(r.totalAmount, closeTo(118, 0.005));
    });
  });

  // ==========================================================================
  group('discounts prorate and keep the subset contract', () {
    // The approved worked example: 1000 -> override 900 -> line 10% (90)
    // -> bill 5% of 810 (40.50) -> taxable 769.50, total discount 130.50.
    SaleItemModel discounted({double qty = 2}) => line(
          price: 900,
          qty: qty,
          discountAmount: 130.50 * qty,
          lineDiscountAmount: 90.0 * qty,
          taxableAmount: 769.50 * qty,
          gstAmount: 138.51 * qty,
          total: 908.01 * qty,
        );

    test('returning 1 of 2 halves every discount figure', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 1816.02),
        soldLines: [discounted()],
        returnQtyByVariantId: {'v1': 1},
      );

      final l = r.lines.single;
      expect(l.discountAmount, closeTo(130.50, 0.005));
      expect(l.lineDiscountAmount, closeTo(90, 0.005));
      expect(l.total, closeTo(908.01, 0.005));
    });

    test('lineDiscountAmount stays a SUBSET of discountAmount', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 1816.02),
        soldLines: [discounted()],
        returnQtyByVariantId: {'v1': 1},
      );

      final l = r.lines.single;
      expect(l.lineDiscountAmount!, lessThanOrEqualTo(l.discountAmount));
    });

    test('a line with no discount of its own carries null, not zero', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 118),
        soldLines: [line(taxableAmount: 100, gstAmount: 18, total: 118)],
        returnQtyByVariantId: {'v1': 1},
      );
      expect(r.lines.single.lineDiscountAmount, isNull);
    });
  });

  // ==========================================================================
  group('round-off reconciliation', () {
    test('returning every line equals what was charged, to the paisa', () {
      // Lines sum to 908.01; the bill was rounded to 908.
      final sold = [line(price: 900, taxableAmount: 769.50, gstAmount: 138.51, total: 908.01)];
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 908),
        soldLines: sold,
        returnQtyByVariantId: {'v1': 1},
      );

      expect(r.totalAmount, closeTo(908, 0.005));
    });

    test('repeated partial returns can never sum past the bill', () {
      final sold = [line(price: 100, qty: 3, taxableAmount: 300, gstAmount: 54, total: 354)];
      final s = sale(totalAmount: 353);

      var refunded = 0.0;
      for (var i = 0; i < 3; i++) {
        refunded += RetailReturnMath.compute(
          sale: s,
          soldLines: sold,
          returnQtyByVariantId: {'v1': 1},
        ).totalAmount;
      }

      expect(refunded, lessThanOrEqualTo(353 + 0.02));
    });

    test('a factor outside the round-off band falls back to plain proration', () {
      // Header disagrees wildly with the lines — trusting it would mis-refund.
      final sold = [line(taxableAmount: 100, gstAmount: 18, total: 118)];
      expect(
        RetailReturnMath.reconciliationFactor(sale(totalAmount: 5000), sold),
        1.0,
      );
    });

    test('zero-value lines do not divide by zero', () {
      final sold = [line(price: 0, taxableAmount: 0, gstAmount: 0, total: 0)];
      expect(RetailReturnMath.reconciliationFactor(sale(totalAmount: 0), sold), 1.0);
    });
  });

  // ==========================================================================
  // B5 — the repeat-refund protection.
  group('remaining returnable quantity', () {
    final sold = [line(price: 100, qty: 3, taxableAmount: 300, gstAmount: 54, total: 354)];

    test('nothing returned yet leaves the full sold quantity', () {
      expect(
        RetailReturnMath.remainingByVariant(soldLines: sold, returnedLines: []),
        {'v1': 3},
      );
    });

    test('three separate single returns walk it down 2, 1, 0', () {
      final returned = <SaleItemModel>[];
      final seen = <double>[];
      for (var i = 0; i < 3; i++) {
        returned.add(returnedLine(variantId: 'v1', qty: 1.0));
        seen.add(RetailReturnMath.remainingByVariant(
          soldLines: sold,
          returnedLines: returned,
        )['v1']!);
      }
      expect(seen, [2, 1, 0]);
    });

    test('a fourth unit has nothing left to give back', () {
      final returned = List.generate(3, (_) => returnedLine(variantId: 'v1', qty: 1.0));
      expect(
        RetailReturnMath.remainingByVariant(soldLines: sold, returnedLines: returned)['v1'],
        0,
      );
    });

    test('remaining never goes negative', () {
      final returned = List.generate(5, (_) => returnedLine(variantId: 'v1', qty: 1.0));
      expect(
        RetailReturnMath.remainingByVariant(soldLines: sold, returnedLines: returned)['v1'],
        0,
      );
    });

    test('quantities are tracked per variant, not pooled', () {
      final twoLines = [
        line(variantId: 'v1', qty: 2, taxableAmount: 200, gstAmount: 36, total: 236),
        line(variantId: 'v2', qty: 5, taxableAmount: 500, gstAmount: 90, total: 590),
      ];
      final remaining = RetailReturnMath.remainingByVariant(
        soldLines: twoLines,
        returnedLines: [returnedLine(variantId: 'v1', qty: 2)],
      );
      expect(remaining, {'v1': 0, 'v2': 5});
    });

    test('returnedQtyByVariant sums positive return-line quantities', () {
      expect(
        RetailReturnMath.returnedQtyByVariant([
          returnedLine(variantId: 'v1', qty: 1.0),
          returnedLine(variantId: 'v1', qty: 2),
          returnedLine(variantId: 'v2', qty: 4),
        ]),
        {'v1': 3, 'v2': 4},
      );
    });
  });

  // ==========================================================================
  group('historical economics survive a catalogue change', () {
    test('the refund ignores any later master price', () {
      // Sold at an overridden 900 while the catalogue said 1000; the catalogue
      // has since moved to 1200. None of that can reach the stored line.
      final sold = [
        line(price: 900, taxableAmount: 900, gstAmount: 162, total: 1062),
      ];
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 1062),
        soldLines: sold,
        returnQtyByVariantId: {'v1': 1},
      );

      expect(r.lines.single.price, closeTo(900, 0.005));
      expect(r.totalAmount, closeTo(1062, 0.005));
    });
  });

  // ==========================================================================
  group('input guards', () {
    final sold = [line(taxableAmount: 100, gstAmount: 18, total: 118)];

    test('an empty request returns empty figures', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 118),
        soldLines: sold,
        returnQtyByVariantId: {},
      );
      expect(r.isEmpty, isTrue);
      expect(r.totalAmount, 0);
    });

    test('an unknown variant is ignored rather than throwing', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 118),
        soldLines: sold,
        returnQtyByVariantId: {'ghost': 1},
      );
      expect(r.isEmpty, isTrue);
    });

    test('a non-positive quantity is ignored', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 118),
        soldLines: sold,
        returnQtyByVariantId: {'v1': 0},
      );
      expect(r.isEmpty, isTrue);
    });

    test('every figure is positive — the caller negates the header', () {
      final r = RetailReturnMath.compute(
        sale: sale(totalAmount: 118),
        soldLines: sold,
        returnQtyByVariantId: {'v1': 1},
      );
      expect(r.subtotal, greaterThan(0));
      expect(r.taxAmount, greaterThan(0));
      expect(r.totalAmount, greaterThan(0));
    });
  });
}
