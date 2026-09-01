import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/sales_totals.dart';
import 'package:billberrylite/util/retail/sale_revenue_filter.dart';

/// Pure tests for the Daily/Monthly sales totals.
///
/// [RetailSalesTotals] takes plain models, so none of this needs Hive, DI or
/// settings — the reason the arithmetic was lifted out of `ReportService`,
/// which had no coverage at all.
///
/// Every sale below is built the way the app actually stores one:
/// `totalAmount == totalTaxableAmount + taxAmount + roundOff`, and a return
/// with every header amount negated EXCEPT `totalItems`, which retail stores
/// positive (`return_service.dart:361`).
void main() {
  /// A forward sale, built so the stored fields satisfy the engine's identity.
  SaleModel sale({
    required double taxable,
    required double tax,
    double roundOff = 0,
    double discount = 0,
    double items = 1,
    double? subtotalOverride,
    bool storeTaxable = true,
    bool storeRoundOff = true,
  }) {
    final total = taxable + tax + roundOff;
    return SaleModel(
      saleId: 'S-${taxable.toStringAsFixed(2)}-${items.toString()}',
      totalItems: items,
      subtotal: subtotalOverride ?? (taxable + discount),
      discountAmount: discount,
      taxAmount: tax,
      totalAmount: total,
      paymentType: 'cash',
      date: '2026-09-01T10:00:00.000',
      createdAt: '2026-09-01T10:00:00.000',
      updatedAt: '2026-09-01T10:00:00.000',
      totalTaxableAmount: storeTaxable ? taxable : null,
      totalGstAmount: tax,
      grandTotal: total,
      roundOff: storeRoundOff ? roundOff : null,
    );
  }

  /// A return document, following the stored retail convention exactly.
  SaleModel returnDoc({
    required double taxable,
    required double tax,
    double discount = 0,
    double items = 1,
    double? totalOverride,
    String id = 'R-1',
  }) {
    return SaleModel(
      saleId: id,
      // POSITIVE — the one header field that is not negated.
      totalItems: items,
      subtotal: -(taxable + discount),
      discountAmount: -discount,
      taxAmount: -tax,
      totalAmount: -(totalOverride ?? (taxable + tax)),
      paymentType: 'cash',
      date: '2026-09-01T12:00:00.000',
      createdAt: '2026-09-01T12:00:00.000',
      updatedAt: '2026-09-01T12:00:00.000',
      isReturn: true,
      originalSaleId: 'S-1',
      totalTaxableAmount: -taxable,
      totalGstAmount: -tax,
      grandTotal: -(totalOverride ?? (taxable + tax)),
      // Never written on a return header — see H9.
    );
  }

  Map<String, dynamic> totals(
    List<SaleModel> forward,
    List<SaleModel> returns, {
    int skipped = 0,
  }) =>
      RetailSalesTotals.compute(
        forward: forward,
        returns: returns,
        skippedRows: skipped,
      );

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();

  // ── Returns ────────────────────────────────────────────────────────────

  test('H1 no return: gross and net agree', () {
    final t = totals([sale(taxable: 100, tax: 18, items: 2)], []);

    expect(num_(t, 'totalRevenue'), 118.0);
    expect(num_(t, 'netRevenue'), 118.0);
    expect(num_(t, 'totalTax'), num_(t, 'netTax'));
    expect(num_(t, 'totalItems'), num_(t, 'grossItems'));
    expect(t['totalReturns'], 0);
  });

  test('H2 partial return nets the header but leaves gross alone', () {
    final t = totals(
      [sale(taxable: 100, tax: 18, items: 4)],
      [returnDoc(taxable: 25, tax: 4.5, items: 1)],
    );

    expect(num_(t, 'totalRevenue'), 118.0);
    expect(num_(t, 'totalReturnAmount'), 29.5);
    expect(num_(t, 'netRevenue'), closeTo(118.0 - 29.5, 0.001));
    expect(num_(t, 'grossItems'), 4.0);
    expect(num_(t, 'returnedItems'), 1.0);
    expect(num_(t, 'totalItems'), 3.0);
  });

  test('H3 full return zeroes the net position but keeps both counts', () {
    final t = totals(
      [sale(taxable: 100, tax: 18, items: 2)],
      [returnDoc(taxable: 100, tax: 18, items: 2)],
    );

    expect(num_(t, 'netRevenue'), 0.0);
    expect(num_(t, 'totalItems'), 0.0);
    expect(num_(t, 'netTax'), 0.0);
    expect(t['totalSales'], 1);
    expect(t['totalReturns'], 1);
    // The gross side still records that a sale happened.
    expect(num_(t, 'totalRevenue'), 118.0);
  });

  test('H4 gross identity holds, and matches the stored taxable', () {
    final forward = [
      sale(taxable: 100, tax: 18, roundOff: 0.40),
      sale(taxable: 250.50, tax: 45.09, roundOff: -0.59, items: 3),
    ];
    final t = totals(forward, [returnDoc(taxable: 25, tax: 4.5)]);

    // Taxable Value + Tax + Round Off = Gross Revenue, by construction.
    expect(
      num_(t, 'totalTaxable') + num_(t, 'totalTax') + num_(t, 'totalRoundOff'),
      closeTo(num_(t, 'totalRevenue'), 0.001),
    );

    // And the residual equals what the engine actually stored — if this ever
    // fails, stored data has drifted from its own total.
    final storedTaxable =
        forward.fold<double>(0, (s, x) => s + (x.totalTaxableAmount ?? 0));
    expect(num_(t, 'totalTaxable'), closeTo(storedTaxable, 0.011));
  });

  test('H5 multiple returns against one sale accumulate', () {
    final t = totals(
      [sale(taxable: 300, tax: 54, items: 6)],
      [
        returnDoc(taxable: 50, tax: 9, items: 1, id: 'R-1'),
        returnDoc(taxable: 100, tax: 18, items: 2, id: 'R-2'),
      ],
    );

    expect(t['totalReturns'], 2);
    expect(num_(t, 'totalReturnAmount'), closeTo(59 + 118, 0.001));
    expect(
      num_(t, 'netRevenue'),
      closeTo(num_(t, 'totalRevenue') - num_(t, 'totalReturnAmount'), 0.001),
    );
    expect(num_(t, 'totalItems'), 3.0);
  });

  test('H6 multi-item return keeps gross and returned counts separate', () {
    final t = totals(
      [sale(taxable: 500, tax: 90, items: 10)],
      [returnDoc(taxable: 200, tax: 36, items: 4)],
    );

    expect(num_(t, 'grossItems'), 10.0);
    expect(num_(t, 'returnedItems'), 4.0);
    expect(num_(t, 'totalItems'), 6.0);
  });

  test('H7 decimal returned quantity is not truncated', () {
    final t = totals(
      [sale(taxable: 400, tax: 0, items: 4.0)],
      [returnDoc(taxable: 250, tax: 0, items: 2.5)],
    );

    expect(num_(t, 'returnedItems'), 2.5);
    expect(num_(t, 'totalItems'), 1.5);
    // The bug this pins: .toInt() reported 1.5 as 1.
    expect(num_(t, 'totalItems').toInt(), isNot(num_(t, 'totalItems')));
  });

  test('H8 return with discount and tax reduces both net figures', () {
    final t = totals(
      [sale(taxable: 180, tax: 32.40, discount: 20, items: 2)],
      [returnDoc(taxable: 90, tax: 16.20, discount: 10, items: 1)],
    );

    // Gross keeps the forward-only figures...
    expect(num_(t, 'totalDiscount'), 20.0);
    expect(num_(t, 'totalTax'), 32.40);
    // ...while the net keys carry the credit note.
    expect(num_(t, 'netDiscount'), closeTo(10.0, 0.001));
    expect(num_(t, 'netTax'), closeTo(16.20, 0.001));
  });

  test('H9 a return carries unrecorded round-off, so no net-taxable is emitted',
      () {
    // A return whose total was scaled by RetailReturnMath.reconciliationFactor:
    // the total moves, taxable and tax do not, and roundOff stays null.
    final r = returnDoc(taxable: 100, tax: 18, totalOverride: 118.35);

    expect(r.roundOff, isNull);
    expect(
      r.totalAmount,
      isNot(closeTo(r.totalTaxableAmount! + r.taxAmount, 0.001)),
    );

    // Which is why these keys must not exist — an identity built on them would
    // be off by that unrecorded residue.
    final t = totals([sale(taxable: 100, tax: 18)], [r]);
    expect(t.containsKey('netTaxable'), isFalse);
    expect(t.containsKey('netRoundOff'), isFalse);
  });

  // ── Tax modes ──────────────────────────────────────────────────────────

  test('H10 tax-exclusive sale reconciles', () {
    final t = totals([sale(taxable: 1000, tax: 180, roundOff: 0)], []);

    expect(num_(t, 'totalTaxable'), 1000.0);
    expect(num_(t, 'totalRevenue'), 1180.0);
  });

  test('H11 tax-inclusive sale reconciles, and subtotal would not', () {
    // Inclusive: the customer pays 1000, of which 152.54 is GST. `subtotal`
    // holds the tax-INCLUSIVE line total, per cart_calculation_service.
    final s = sale(
      taxable: 847.46,
      tax: 152.54,
      discount: 0,
      subtotalOverride: 1000.0,
    );
    final t = totals([s], []);

    expect(num_(t, 'totalRevenue'), closeTo(1000.0, 0.001));
    expect(
      num_(t, 'totalTaxable') + num_(t, 'totalTax') + num_(t, 'totalRoundOff'),
      closeTo(num_(t, 'totalRevenue'), 0.001),
    );

    // The regression guard: deriving taxable from `subtotal` double-counts GST.
    final viaSubtotal = s.subtotal - s.discountAmount + s.taxAmount;
    expect(viaSubtotal, isNot(closeTo(num_(t, 'totalRevenue'), 0.011)));
  });

  test('H12 zero-tax sale', () {
    final t = totals([sale(taxable: 500, tax: 0, roundOff: 0.25)], []);

    expect(num_(t, 'totalTax'), 0.0);
    expect(
      num_(t, 'totalTaxable'),
      closeTo(num_(t, 'totalRevenue') - num_(t, 'totalRoundOff'), 0.001),
    );
  });

  test('H13 legacy row with null totalTaxableAmount and null roundOff', () {
    final t = totals([
      sale(
        taxable: 200,
        tax: 36,
        storeTaxable: false,
        storeRoundOff: false,
      ),
    ], []);

    expect(num_(t, 'totalRoundOff'), 0.0);
    expect(
      num_(t, 'totalTaxable'),
      closeTo(num_(t, 'totalRevenue') - num_(t, 'totalTax'), 0.001),
    );
    expect(
      num_(t, 'totalTaxable') + num_(t, 'totalTax') + num_(t, 'totalRoundOff'),
      closeTo(num_(t, 'totalRevenue'), 0.001),
    );
  });

  // ── Structural ─────────────────────────────────────────────────────────

  test('H14 skipped rows are passed through untouched', () {
    final t = totals([sale(taxable: 100, tax: 18)], [], skipped: 2);

    expect(t['skippedRows'], 2);
    expect(num_(t, 'totalRevenue'), 118.0);
  });

  test('H15 empty window is all zeros with no divide-by-zero', () {
    final t = totals([], []);

    expect(t['totalSales'], 0);
    expect(num_(t, 'totalRevenue'), 0.0);
    expect(num_(t, 'netRevenue'), 0.0);
    expect(num_(t, 'averageSaleValue'), 0.0);
    expect(num_(t, 'totalTaxable'), 0.0);
  });

  test('H16 the emitted key set is fixed, so daily and monthly cannot drift',
      () {
    // Both reports spread this same map, so pinning it here pins both.
    expect(
      totals([sale(taxable: 100, tax: 18)], []).keys.toSet(),
      {
        'totalSales',
        'grossItems',
        'totalRevenue',
        'totalTaxable',
        'totalTax',
        'totalDiscount',
        'totalRoundOff',
        'totalReturns',
        'returnedItems',
        'totalReturnAmount',
        'totalItems',
        'netRevenue',
        'netTax',
        'netDiscount',
        'averageSaleValue',
        'skippedRows',
      },
    );
  });

  test('manual scenario: 2 sales + a partial return, one line at 2.5 kg', () {
    // 2.5 kg rice @ 100, 5% GST exclusive.
    final rice = sale(taxable: 250, tax: 12.50, items: 2.5);
    // 3 soap @ 100, 18% GST, bill rounded up 50 paise.
    final soap = sale(taxable: 300, tax: 54, roundOff: 0.50, items: 3);
    // 1 kg of the rice comes back.
    final back = returnDoc(taxable: 100, tax: 5, items: 1);

    final t = totals([rice, soap], [back]);

    // Gross block, and the identity the card draws under it.
    expect(num_(t, 'grossItems'), 5.5);
    expect(num_(t, 'totalTaxable'), 550.0);
    expect(num_(t, 'totalTax'), 66.50);
    expect(num_(t, 'totalRoundOff'), 0.50);
    expect(num_(t, 'totalRevenue'), 617.0);
    expect(
      num_(t, 'totalTaxable') + num_(t, 'totalTax') + num_(t, 'totalRoundOff'),
      closeTo(617.0, 0.001),
    );

    // Returns block.
    expect(t['totalReturns'], 1);
    expect(num_(t, 'returnedItems'), 1.0);
    expect(num_(t, 'totalReturnAmount'), 105.0);

    // After returns, and the second identity.
    expect(num_(t, 'netRevenue'), 512.0);
    expect(
      num_(t, 'totalRevenue') - num_(t, 'totalReturnAmount'),
      closeTo(num_(t, 'netRevenue'), 0.001),
    );
    expect(num_(t, 'netTax'), 61.50);

    // The summary card's item count, which must equal the Items Sold table.
    expect(num_(t, 'totalItems'), 4.5);

    // Gross revenue over bills rung up — returns are in neither figure.
    expect(num_(t, 'averageSaleValue'), 308.50);
  });

  test('signedItemCount applies the return convention', () {
    expect(
      RetailSaleFilter.signedItemCount(sale(taxable: 10, tax: 0, items: 2.5)),
      2.5,
    );
    expect(
      RetailSaleFilter.signedItemCount(
        returnDoc(taxable: 10, tax: 0, items: 2.5),
      ),
      -2.5,
    );
  });
}
