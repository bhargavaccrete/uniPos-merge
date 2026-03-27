import 'package:flutter_test/flutter_test.dart';
import 'package:unipos/domain/services/restaurant/cart_calculation_service.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/customerdetails.dart';
import '../../../helpers/test_helpers.dart';

/// Unit tests for CartCalculationService — the financial engine of the app.
///
/// These tests verify that all bill calculations are correct:
/// subtotal, discount, tax (inclusive/exclusive), service charge, grand total.
///
/// WHY THIS MATTERS: If these calculations are wrong, every bill is wrong.
/// A ₹1 error × 50 orders/day × 30 days = ₹1,500/month lost.
void main() {
  // Helper shortcut — wraps makeCartItem from test_helpers.dart
  makeItem({required double price, int quantity = 1, double? taxRate}) =>
      makeCartItem(price: price, quantity: quantity, taxRate: taxRate);

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 1: Empty cart
  // ══════════════════════════════════════════════════════════════════════
  group('Empty cart', () {
    test('all totals should be zero', () {
      final calc = CartCalculationService(
        items: [],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      expect(calc.itemTotal, equals(0));
      expect(calc.taxableAmount, equals(0));
      expect(calc.discountAmount, equals(0));
      expect(calc.totalGST, equals(0));
      expect(calc.grandTotal, equals(0));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 2: Basic calculations (no discount, no tax)
  // ══════════════════════════════════════════════════════════════════════
  group('Basic calculations — no discount, no tax', () {
    test('single item total', () {
      final calc = CartCalculationService(
        items: [makeItem(price: 250)],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      expect(calc.itemTotal, equals(250));
      expect(calc.grandTotal, closeTo(250, 0.01));
    });

    test('multiple items with quantities', () {
      final calc = CartCalculationService(
        items: [
          makeItem(price: 100, quantity: 2), // 200
          makeItem(price: 50, quantity: 3),  // 150
        ],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // 200 + 150 = 350
      expect(calc.itemTotal, equals(350));
      expect(calc.grandTotal, closeTo(350, 0.01));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 3: Tax Exclusive (prices are base, tax added on top)
  // ══════════════════════════════════════════════════════════════════════
  group('Tax exclusive — tax added on top of price', () {
    test('5% tax on single item', () {
      final calc = CartCalculationService(
        items: [makeItem(price: 100, taxRate: 0.05)],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Price: ₹100, Tax: 100 × 0.05 = ₹5
      // Total: ₹105
      expect(calc.itemTotal, equals(100));
      expect(calc.totalGST, closeTo(5.0, 0.01));
      expect(calc.grandTotal, closeTo(105, 0.01));
    });

    test('18% tax on multiple items', () {
      final calc = CartCalculationService(
        items: [
          makeItem(price: 200, taxRate: 0.18), // Tax: 36
          makeItem(price: 100, taxRate: 0.18), // Tax: 18
        ],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Total: 300, Tax: 54, Grand: 354
      expect(calc.itemTotal, equals(300));
      expect(calc.totalGST, closeTo(54, 0.01));
      expect(calc.grandTotal, closeTo(354, 0.01));
    });

    test('mixed tax rates (5% and 18%)', () {
      final calc = CartCalculationService(
        items: [
          makeItem(price: 200, taxRate: 0.05), // Tax: 10
          makeItem(price: 100, taxRate: 0.18), // Tax: 18
        ],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Tax: 10 + 18 = 28, Grand: 300 + 28 = 328
      expect(calc.totalGST, closeTo(28, 0.01));
      expect(calc.grandTotal, closeTo(328, 0.01));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 4: Tax Inclusive (prices already include tax)
  // ══════════════════════════════════════════════════════════════════════
  group('Tax inclusive — tax extracted from price', () {
    test('5% inclusive tax', () {
      final calc = CartCalculationService(
        items: [makeItem(price: 105, taxRate: 0.05)],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: true,
        discountOnItems: false,
      );

      // Price ₹105 includes 5% tax
      // Base = 105 / 1.05 = 100
      // GST = 105 - 100 = 5
      // Grand total = base + GST = 105
      expect(calc.itemTotal, equals(105));
      expect(calc.taxableAmount, closeTo(100, 0.01));
      expect(calc.totalGST, closeTo(5, 0.01));
      expect(calc.grandTotal, closeTo(105, 0.01));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 5: Discount — Amount
  // ══════════════════════════════════════════════════════════════════════
  group('Amount discount', () {
    test('₹50 discount on ₹300 order', () {
      final calc = CartCalculationService(
        items: [
          makeItem(price: 100, taxRate: 0.05),
          makeItem(price: 200, taxRate: 0.05),
        ],
        discountType: DiscountType.amount,
        discountValue: 50,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Original: 300, Discount: 50, After discount: 250
      // Tax: 250 × 0.05 = 12.5
      // Grand: 250 + 12.5 = 262.5
      expect(calc.discountAmount, closeTo(50, 0.01));
      expect(calc.taxableAmount, closeTo(250, 0.01));
      expect(calc.totalGST, closeTo(12.5, 0.01));
      expect(calc.grandTotal, closeTo(262.5, 0.01));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 6: Discount — Percentage
  //
  // TODO(human): Implement this test!
  // ══════════════════════════════════════════════════════════════════════
  group('Percentage discount', () {
    test('10% discount on ₹300 order (tax exclusive, 5% GST)', () {
      final calc = CartCalculationService(
        items: [
          makeItem(price: 100, taxRate: 0.05),
          makeItem(price: 200, taxRate: 0.05),
        ],
        discountType: DiscountType.percentage,
        discountValue: 10, // 10%
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // STEP-BY-STEP CALCULATION:
      //
      // 1. Original total = ₹100 + ₹200 = ₹300
      //
      // 2. Discount = 10% of ₹300 = ₹30
      //    This is percentage-based, so: 300 × (10/100) = 30
      //
      // 3. Taxable amount = ₹300 - ₹30 = ₹270
      //    Discount is applied FIRST, before tax. Tax is calculated
      //    on the discounted amount, not the original.
      //
      // 4. GST = 5% of ₹270 = ₹13.50
      //    Since isTaxInclusive=false, tax is ADDED on top.
      //    Both items have 5% tax, so: 270 × 0.05 = 13.50
      //
      // 5. Grand total = ₹270 + ₹13.50 = ₹283.50
      //    taxableAmount + totalGST (no service charge in this test)

      expect(calc.discountAmount, closeTo(30, 0.01));
      expect(calc.taxableAmount, closeTo(270, 0.01));
      expect(calc.totalGST, closeTo(13.5, 0.01));
      expect(calc.grandTotal, closeTo(283.5, 0.01));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 7: Service Charge
  // ══════════════════════════════════════════════════════════════════════
  group('Service charge', () {
    test('10% service charge applied after tax', () {
      final calc = CartCalculationService(
        items: [makeItem(price: 100, taxRate: 0.05)],
        discountType: DiscountType.amount,
        discountValue: 0,
        serviceChargePercentage: 10,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Base: 100, Tax: 5, Before service: 105
      // Service: 105 × 10% = 10.5
      // Grand: 100 + 5 + 10.5 = 115.5
      expect(calc.serviceChargeAmount, closeTo(10.5, 0.01));
      expect(calc.grandTotal, closeTo(115.5, 0.01));
    });

    test('delivery charge is flat amount, not percentage', () {
      final calc = CartCalculationService(
        items: [makeItem(price: 100, taxRate: 0.05)],
        discountType: DiscountType.amount,
        discountValue: 0,
        deliveryCharge: 50,
        isDeliveryOrder: true,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Base: 100, Tax: 5, Delivery: 50 (flat)
      // Grand: 100 + 5 + 50 = 155
      expect(calc.serviceChargeAmount, equals(50));
      expect(calc.grandTotal, closeTo(155, 0.01));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // TEST GROUP 8: Combined scenario
  // ══════════════════════════════════════════════════════════════════════
  group('Combined scenario', () {
    test('discount + tax exclusive + service charge', () {
      final calc = CartCalculationService(
        items: [
          makeItem(price: 200, quantity: 2, taxRate: 0.05), // 400
          makeItem(price: 100, quantity: 1, taxRate: 0.18), // 100
        ],
        discountType: DiscountType.amount,
        discountValue: 50,
        serviceChargePercentage: 10,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // Original: 500, Discount: 50, After discount: 450
      // Item1 share: (400/500) × 450 = 360, Tax: 360 × 0.05 = 18
      // Item2 share: (100/500) × 450 = 90, Tax: 90 × 0.18 = 16.2
      // Taxable: 360 + 90 = 450
      // GST: 18 + 16.2 = 34.2
      // Before service: 450 + 34.2 = 484.2
      // Service: 484.2 × 10% = 48.42
      // Grand: 450 + 34.2 + 48.42 = 532.62
      expect(calc.discountAmount, closeTo(50, 0.01));
      expect(calc.taxableAmount, closeTo(450, 0.01));
      expect(calc.totalGST, closeTo(34.2, 0.01));
      expect(calc.serviceChargeAmount, closeTo(48.42, 0.01));
      expect(calc.grandTotal, closeTo(532.62, 0.01));
    });
  });
}
