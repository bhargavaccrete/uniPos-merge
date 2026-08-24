import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/receipt_pdf_service.dart';

/// CREDIT NOTE rendering.
///
/// A return is stored with its HEADER negated and its LINES positive. That is
/// the accounting representation and it stays exactly as it is — these pin the
/// separate question of what the customer's printed copy shows.
///
/// The defect: `receiptBillDiscountRemainder` subtracted a positive line total
/// from a negative header, so the result was always negative on a return and
/// the existing clamp deleted the Bill Discount row from every credit note.
void main() {
  SaleItemModel line({
    required double price,
    int qty = 1,
    double? lineDiscountAmount,
    double discountAmount = 0,
  }) =>
      SaleItemModel.fromCalculated(
        saleId: 'RTN_1',
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: price,
        qty: qty,
        discountAmount: discountAmount,
        gstRate: 18,
        taxableAmount: price * qty,
        gstAmount: price * qty * 0.18,
        total: price * qty * 1.18,
        lineDiscountAmount: lineDiscountAmount,
      );

  /// A return header, stored the way `ReturnService` writes one: NEGATED.
  SaleModel returnHeader({required double discountAmount}) {
    final now = DateTime.now().toIso8601String();
    return SaleModel(
      saleId: 'RTN_1',
      totalItems: 1,
      subtotal: -1000,
      discountAmount: -discountAmount,
      taxAmount: -180,
      totalAmount: -1180,
      paymentType: 'cash',
      date: now,
      createdAt: now,
      updatedAt: now,
      isReturn: true,
      originalSaleId: 'S1',
    );
  }

  SaleModel saleHeader({required double discountAmount}) {
    final now = DateTime.now().toIso8601String();
    return SaleModel(
      saleId: 'S1',
      totalItems: 1,
      subtotal: 1000,
      discountAmount: discountAmount,
      taxAmount: 180,
      totalAmount: 1180,
      paymentType: 'cash',
      date: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ==========================================================================
  group('a credit note keeps its Bill Discount row', () {
    test('an order-level discount survives onto the printed return', () {
      // 150 total discount, 90 of it on the line → 60 is order-level.
      final items = [line(price: 900, lineDiscountAmount: 90, discountAmount: 150)];

      final remainder = receiptBillDiscountRemainder(
        returnHeader(discountAmount: 150),
        items,
      );

      // Before the fix this was `-150 - 90 = -240`, clamped to 0, and the row
      // vanished from every credit note.
      expect(remainder, closeTo(60, 0.005));
    });

    test('a return with only line discounts shows no order-level row', () {
      final items = [line(price: 900, lineDiscountAmount: 90, discountAmount: 90)];

      expect(
        receiptBillDiscountRemainder(returnHeader(discountAmount: 90), items),
        0,
      );
    });

    test('a return with no discount at all shows nothing', () {
      final items = [line(price: 900)];

      expect(
        receiptBillDiscountRemainder(returnHeader(discountAmount: 0), items),
        0,
      );
    });
  });

  // ==========================================================================
  group('forward sales are unchanged', () {
    test('an ordinary bill still splits line and order discount', () {
      final items = [line(price: 900, lineDiscountAmount: 90, discountAmount: 150)];

      expect(
        receiptBillDiscountRemainder(saleHeader(discountAmount: 150), items),
        closeTo(60, 0.005),
      );
    });

    test('the paisa clamp still holds', () {
      // Independent rounding can push the residual a paisa negative; it must
      // never print as a negative row.
      final items = [line(price: 900, lineDiscountAmount: 90.02, discountAmount: 90.02)];

      expect(
        receiptBillDiscountRemainder(saleHeader(discountAmount: 90), items),
        0,
      );
    });

    test('a sale and its mirror-image return print the same remainder', () {
      final items = [line(price: 900, lineDiscountAmount: 90, discountAmount: 150)];

      expect(
        receiptBillDiscountRemainder(returnHeader(discountAmount: 150), items),
        closeTo(
          receiptBillDiscountRemainder(saleHeader(discountAmount: 150), items),
          0.005,
        ),
      );
    });
  });
}
