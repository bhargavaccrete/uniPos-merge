import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/return_math.dart';

/// AND-28: Sales History badges a sale RETURNED only when every sold unit came
/// back — worked out for the whole list in one pass.
void main() {
  final now = DateTime(2026, 11, 20).toIso8601String();

  SaleModel sale(String id, {String? returnOf}) => SaleModel(
        saleId: id,
        totalItems: 1,
        subtotal: 100,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: returnOf == null ? 100 : -100,
        paymentType: 'cash',
        date: now,
        createdAt: now,
        updatedAt: now,
        isReturn: returnOf != null,
        originalSaleId: returnOf,
      );

  SaleItemModel line(String saleId, String variant, double qty) =>
      SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: variant,
        productId: 'p1',
        productName: 'Item',
        price: 100,
        qty: qty,
        discountAmount: 0,
        gstRate: 0,
        taxableAmount: 100 * qty,
        gstAmount: 0,
        total: 100 * qty,
      );

  Set<String> ids(List<SaleModel> sales, List<SaleItemModel> lines) =>
      RetailReturnMath.fullyReturnedSaleIds(sales: sales, lines: lines);

  test('no returns: nothing is badged', () {
    expect(ids([sale('S1')], [line('S1', 'v1', 2)]), isEmpty);
  });

  test('one full return badges the sale', () {
    expect(
      ids([sale('S1'), sale('R1', returnOf: 'S1')],
          [line('S1', 'v1', 2), line('R1', 'v1', 2)]),
      {'S1'},
    );
  });

  test('a partial return does not', () {
    expect(
      ids([sale('S1'), sale('R1', returnOf: 'S1')],
          [line('S1', 'v1', 3), line('R1', 'v1', 1)]),
      isEmpty,
    );
  });

  test('two partial returns that add up to everything badge it', () {
    expect(
      ids([
        sale('S1'),
        sale('R1', returnOf: 'S1'),
        sale('R2', returnOf: 'S1'),
      ], [
        line('S1', 'v1', 3),
        line('R1', 'v1', 1),
        line('R2', 'v1', 2),
      ]),
      {'S1'},
    );
  });

  test('one variant back, another still out: not badged', () {
    expect(
      ids([sale('S1'), sale('R1', returnOf: 'S1')], [
        line('S1', 'v1', 1),
        line('S1', 'v2', 1),
        line('R1', 'v1', 1),
      ]),
      isEmpty,
    );
  });

  test('returns only count against their own original', () {
    expect(
      ids([sale('S1'), sale('S2'), sale('R1', returnOf: 'S2')], [
        line('S1', 'v1', 1),
        line('S2', 'v1', 1),
        line('R1', 'v1', 1),
      ]),
      {'S2'},
    );
  });

  test('a sale with no lines is not badged', () {
    expect(ids([sale('S1')], const []), isEmpty);
  });

  test('a return whose original is missing is ignored', () {
    expect(
      ids([sale('S1'), sale('R1', returnOf: 'GONE')],
          [line('S1', 'v1', 1), line('R1', 'v1', 1)]),
      isEmpty,
    );
  });

  test('return documents are never in the result', () {
    final result = ids([sale('S1'), sale('R1', returnOf: 'S1')],
        [line('S1', 'v1', 1), line('R1', 'v1', 1)]);
    expect(result.contains('R1'), isFalse);
  });
}
