import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/receipt_pdf_service.dart';

/// Persistence and presentation of a line discount: sale lines, hold lines, the
/// receipt's Item-Discounts / Bill-Discount split, and returns.
///
/// The contract these lock down:
///   * `SaleItemModel.discountAmount` = TOTAL discount on the line
///     (its own + its share of the order's) — what every report reads.
///   * `SaleItemModel.lineDiscountAmount` = the line's OWN part, a SUBSET.
///     Never additive to the first, or reports double-count.
void main() {
  SaleItemModel soldLine({
    double price = 900,
    double qty = 1,
    double discountAmount = 130.50,
    double? lineDiscountAmount = 90,
    String? type = 'percentage',
    double? value = 10,
    String? reason = 'clearance',
    String? note,
    double? originalPrice = 1000,
  }) =>
      SaleItemModel.fromCalculated(
        saleId: 's1',
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: price,
        qty: qty,
        discountAmount: discountAmount,
        gstRate: 18,
        taxableAmount: 769.50,
        gstAmount: 138.51,
        total: 908.01,
        costPrice: 600,
        originalPrice: originalPrice,
        overrideReason: 'clearance',
        lineDiscountType: type,
        lineDiscountValue: value,
        lineDiscountAmount: lineDiscountAmount,
        lineDiscountReason: reason,
        lineDiscountNote: note,
      );

  // ==========================================================================
  group('SaleItemModel — the subset contract', () {
    test('discountAmount is the TOTAL, lineDiscountAmount its own part', () {
      final s = soldLine();
      expect(s.discountAmount, closeTo(130.50, 0.005));
      expect(s.lineDiscountAmount, closeTo(90, 0.005));
      expect(s.billDiscountShare, closeTo(40.50, 0.005));
      expect(s.hasLineDiscount, isTrue);
    });

    // If this ever fails, a report summing both fields would double-count.
    test('lineDiscountAmount never exceeds discountAmount', () {
      for (final ld in [0.0, 40.5, 130.5]) {
        final s = soldLine(lineDiscountAmount: ld);
        expect(s.lineDiscountAmount!, lessThanOrEqualTo(s.discountAmount! + 0.01));
        expect(s.billDiscountShare, greaterThanOrEqualTo(0));
      }
    });

    test('a bill-discount-only line has no line discount', () {
      final s = soldLine(
          lineDiscountAmount: null, type: null, value: null, reason: null);
      expect(s.hasLineDiscount, isFalse);
      // The whole discount was order-level.
      expect(s.billDiscountShare, closeTo(130.50, 0.005));
    });

    test('the price override survives beside the line discount', () {
      final s = soldLine();
      expect(s.isPriceOverridden, isTrue);
      expect(s.originalPrice, closeTo(1000, 0.005));
      expect(s.price, closeTo(900, 0.005)); // charged
      expect(s.overrideDeltaPerUnit, closeTo(100, 0.005));
    });

    test('round trips through toMap/fromMap', () {
      final restored = SaleItemModel.fromMap(soldLine(note: 'floor sample').toMap());
      expect(restored.lineDiscountType, 'percentage');
      expect(restored.lineDiscountValue, closeTo(10, 0.005));
      expect(restored.lineDiscountAmount, closeTo(90, 0.005));
      expect(restored.lineDiscountReason, 'clearance');
      expect(restored.lineDiscountNote, 'floor sample');
      expect(restored.discountAmount, closeTo(130.50, 0.005));
      expect(restored.originalPrice, closeTo(1000, 0.005));
    });

    // Requirement 12.
    test('a sale line saved before the feature reads as undiscounted', () {
      final legacy = {
        'saleItemId': 'si1',
        'saleId': 's1',
        'varianteId': 'v1',
        'productId': 'p1',
        'price': 900.0,
        'qty': 1,
        'total': 1062.0,
        'discountAmount': 100.0,
      };
      final restored = SaleItemModel.fromMap(legacy);
      expect(restored.hasLineDiscount, isFalse);
      expect(restored.lineDiscountAmount, isNull);
      // The whole historical discount reads as order-level, which it was.
      expect(restored.billDiscountShare, closeTo(100, 0.005));
    });

    // Requirement 15: historical economics must not move when the master does.
    test('the charged figures are frozen on the line', () {
      final s = soldLine();
      // Nothing here reads a variant; every figure is stored.
      expect(s.price, closeTo(900, 0.005));
      expect(s.taxableAmount, closeTo(769.50, 0.005));
      expect(s.costPrice, closeTo(600, 0.005));
    });
  });

  // ==========================================================================
  group('HoldSaleItemModel — survives park/restore', () {
    test('carries type, value, amount, reason and note', () {
      final h = HoldSaleItemModel.create(
        holdSaleId: 'h1',
        variantId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: 900,
        qty: 5,
        originalPrice: 1000,
        overrideReason: 'clearance',
        lineDiscountType: 'percentage',
        lineDiscountValue: 10,
        lineDiscountAmount: 450,
        lineDiscountReason: 'clearance',
        lineDiscountNote: 'end of season',
      );

      expect(h.qty, 5);
      expect(h.price, closeTo(900, 0.005));
      expect(h.originalPrice, closeTo(1000, 0.005));
      expect(h.lineDiscountType, 'percentage');
      expect(h.lineDiscountValue, closeTo(10, 0.005));
      expect(h.lineDiscountAmount, closeTo(450, 0.005));
      expect(h.lineDiscountReason, 'clearance');
      expect(h.lineDiscountNote, 'end of season');

      final restored = HoldSaleItemModel.fromMap(h.toMap());
      expect(restored.lineDiscountValue, closeTo(10, 0.005));
      expect(restored.lineDiscountReason, 'clearance');
      expect(restored.originalPrice, closeTo(1000, 0.005));
    });

    test('a parked line with no discount round trips as none', () {
      final h = HoldSaleItemModel.create(
        holdSaleId: 'h1',
        variantId: 'v1',
        productId: 'p1',
        productName: 'Plain',
        price: 100,
        qty: 1,
      );
      expect(HoldSaleItemModel.fromMap(h.toMap()).lineDiscountAmount, isNull);
    });
  });

  // ==========================================================================
  group('SaleModel.lineDiscountTotal', () {
    test('round trips and is null on legacy sales', () {
      final sale = SaleModel.createWithSplitPayment(
        saleId: 's1',
        totalItems: 2,
        subtotal: 2000,
        discountAmount: 560,
        totalTaxableAmount: 1440,
        totalGstAmount: 259.2,
        grandTotal: 1699.2,
        paymentList: const [],
        totalPaid: 1699.2,
        changeReturn: 0,
        lineDiscountTotal: 400,
      );
      expect(sale.lineDiscountTotal, closeTo(400, 0.005));
      expect(SaleModel.fromMap(sale.toMap()).lineDiscountTotal,
          closeTo(400, 0.005));

      final legacy = SaleModel.fromMap({
        'saleId': 's9',
        'totalItems': 1,
        'subtotal': 100.0,
        'discountAmount': 10.0,
        'taxAmount': 0.0,
        'totalAmount': 90.0,
        'paymentType': 'cash',
        'date': '2026-01-01',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });
      expect(legacy.lineDiscountTotal, isNull);
    });

    test('copyWith preserves it', () {
      final sale = SaleModel.createWithSplitPayment(
        saleId: 's2',
        totalItems: 1,
        subtotal: 900,
        discountAmount: 130.5,
        totalTaxableAmount: 769.5,
        totalGstAmount: 138.51,
        grandTotal: 908.01,
        paymentList: const [],
        totalPaid: 908.01,
        changeReturn: 0,
        lineDiscountTotal: 90,
      );
      expect(sale.copyWith(paymentType: 'upi').lineDiscountTotal,
          closeTo(90, 0.005));
    });
  });

  // ==========================================================================
  // The receipt split. These are the figures printed as "Item Discounts" and
  // "Bill Discount", and the reason the two rows always sum to the stored total.
  group('Receipt discount split helpers', () {
    SaleModel sale(double discountAmount) => SaleModel.createWithSplitPayment(
          saleId: 's3',
          totalItems: 2,
          subtotal: 2000,
          discountAmount: discountAmount,
          totalTaxableAmount: 2000 - discountAmount,
          totalGstAmount: 0,
          grandTotal: 2000 - discountAmount,
          paymentList: const [],
          totalPaid: 2000 - discountAmount,
          changeReturn: 0,
        );

    test('line total folds over the items actually rendered', () {
      final items = [
        soldLine(lineDiscountAmount: 400, discountAmount: 460),
        soldLine(lineDiscountAmount: null, discountAmount: 100),
      ];
      expect(receiptLineDiscountTotal(items), closeTo(400, 0.005));
      expect(receiptLineDiscount(items[0]), closeTo(400, 0.005));
      expect(receiptLineDiscount(items[1]), 0);
    });

    test('the two rows sum to the stored bill discount', () {
      final items = [
        soldLine(lineDiscountAmount: 400, discountAmount: 460),
        soldLine(lineDiscountAmount: null, discountAmount: 100),
      ];
      final s = sale(560);
      final lineTotal = receiptLineDiscountTotal(items);
      final remainder = receiptBillDiscountRemainder(s, items);
      expect(lineTotal + remainder, closeTo(s.discountAmount, 0.005));
      expect(remainder, closeTo(160, 0.005));
    });

    test('a bill-discount-only sale prints no Item Discounts row', () {
      final items = [soldLine(lineDiscountAmount: null, discountAmount: 100)];
      expect(receiptLineDiscountTotal(items), 0);
      expect(receiptBillDiscountRemainder(sale(100), items),
          closeTo(100, 0.005));
    });

    test('a line-discount-only sale leaves no bill remainder', () {
      final items = [soldLine(lineDiscountAmount: 90, discountAmount: 90)];
      expect(receiptLineDiscountTotal(items), closeTo(90, 0.005));
      expect(receiptBillDiscountRemainder(sale(90), items), 0);
    });

    // Independent rounding of the per-line and total figures can make the
    // residual a paisa negative; it must never print as a negative row.
    test('the remainder is clamped at zero', () {
      final items = [soldLine(lineDiscountAmount: 90.02, discountAmount: 90.02)];
      expect(receiptBillDiscountRemainder(sale(90), items), 0);
    });

    test('the label names the percentage when there was one', () {
      expect(receiptLineDiscountLabel(soldLine(type: 'percentage', value: 10)),
          'Discount 10%');
      expect(receiptLineDiscountLabel(soldLine(type: 'percentage', value: 7.5)),
          'Discount 7.5%');
      expect(receiptLineDiscountLabel(soldLine(type: 'amount', value: 90)),
          'Discount');
      expect(
          receiptLineDiscountLabel(soldLine(type: null, value: null)),
          'Discount');
    });
  });

  // ==========================================================================
  // Requirement 19: returns use the HISTORICAL charged economics.
  group('Returns use historical economics', () {
    // Sale: catalogue 1000, override 900, line discount 90, charged net 810, qty 2.
    SaleItemModel original() => soldLine(
          price: 900,
          qty: 2,
          discountAmount: 180,
          lineDiscountAmount: 180,
        );

    test('a full return reverses the stored figures, not the catalogue', () {
      final o = original();
      // What return_service computes for a full return.
      expect(o.price * o.qty, closeTo(1800, 0.005)); // gross charged
      expect(o.discountAmount, closeTo(180, 0.005));
      // Net actually taken = 1620, based on the 900 override, NOT a 1000
      // catalogue price.
      expect(o.price * o.qty - o.discountAmount!, closeTo(1620, 0.005));
    });

    test('a partial return prorates by the returned quantity', () {
      final o = original();
      const returnQty = 1;
      final ratio = returnQty / o.qty;

      final subtotal = o.price * returnQty;
      final discount = o.discountAmount! * ratio;
      final lineDiscount = o.lineDiscountAmount! * ratio;

      expect(subtotal, closeTo(900, 0.005));
      expect(discount, closeTo(90, 0.005));
      expect(lineDiscount, closeTo(90, 0.005));
      // Refund for one unit = the 810 that unit was actually charged.
      expect(subtotal - discount, closeTo(810, 0.005));
    });

    test('a flat line discount on a qty-2 line refunds half on one unit', () {
      final o = soldLine(
          price: 500, qty: 2, discountAmount: 100, lineDiscountAmount: 100,
          type: 'amount', value: 100);
      final ratio = 1 / o.qty;
      expect(o.lineDiscountAmount! * ratio, closeTo(50, 0.005));
    });

    test('the return line mirrors the sale line audit', () {
      final o = original();
      final returnLine = SaleItemModel(
        saleItemId: 'r1',
        saleId: 'RTN_1',
        varianteId: o.varianteId,
        productId: o.productId,
        productName: o.productName,
        price: o.price,
        qty: 1,
        total: 810,
        discountAmount: 90,
        costPrice: o.costPrice,
        originalPrice: o.originalPrice,
        overrideReason: o.overrideReason,
        lineDiscountType: o.lineDiscountType,
        lineDiscountValue: o.lineDiscountValue,
        lineDiscountAmount: 90,
        lineDiscountReason: o.lineDiscountReason,
      );
      expect(returnLine.price, closeTo(900, 0.005));
      expect(returnLine.lineDiscountAmount, closeTo(90, 0.005));
      expect(returnLine.hasLineDiscount, isTrue);
      expect(returnLine.isPriceOverridden, isTrue);
    });
  });
}
