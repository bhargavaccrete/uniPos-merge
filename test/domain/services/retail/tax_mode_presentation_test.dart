import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';

class _FakeBusinessDetailsRepository extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// Inclusive vs exclusive pricing, end to end through the engine.
///
/// The engine was always right; what broke was PRESENTATION — the checkout
/// summary showed a "+ tax" row on an inclusive bill whose grand total already
/// contained it, and hid the taxable base that would have explained the gap.
/// These lock the figures the screen renders each way.
void main() {
  setUpAll(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _FakeBusinessDetailsRepository());
    }
  });

  CartItemModel item({double price = 100, double rate = 18}) =>
      CartItemModel.create(
        cartItemId: 'c1',
        variantId: 'v1',
        productId: 'p1',
        productName: 'Widget',
        price: price,
        qty: 1,
        gstRate: rate,
      );

  /// Mirrors `_CheckoutScreenState._showTaxableRow`.
  bool showsTaxableRow(RetailBill b) =>
      (b.itemTotal - b.taxableAmount).abs() > 0.009;

  group('exclusive — tax is ADDED to reach the total', () {
    // Built per test, not in the group body: a group body runs at collection
    // time, before setUpAll registers the repository TaxFeature reads.
    RetailBill build() => RetailBillingService.compute(
          items: [item()],
          isTaxInclusive: false,
        );

    test('the item total is the pre-tax base', () {
      final bill = build();
      expect(bill.itemTotal, 100);
      expect(bill.taxableAmount, 100);
    });

    test('tax is charged on top', () {
      final bill = build();
      expect(bill.totalGst, 18);
      expect(bill.grandTotal, 118);
    });

    test('itemTotal + tax reconciles to the grand total', () {
      final bill = build();
      expect(bill.itemTotal + bill.totalGst, closeTo(bill.grandTotal, 0.01));
    });

    test('no Taxable Amount row — it would just repeat the Item Total', () {
      final bill = build();
      expect(showsTaxableRow(bill), isFalse);
    });
  });

  group('inclusive — tax is EXTRACTED from the price', () {
    RetailBill build() => RetailBillingService.compute(
          items: [item()],
          isTaxInclusive: true,
        );

    test('the item total already contains the tax', () {
      final bill = build();
      expect(bill.itemTotal, 100);
      expect(bill.grandTotal, 100);
    });

    test('the base is the price less the tax', () {
      final bill = build();
      expect(bill.taxableAmount, 84.75);
      expect(bill.totalGst, 15.25);
    });

    test('base + tax reconciles to the grand total, NOT itemTotal + tax', () {
      final bill = build();
      expect(bill.taxableAmount + bill.totalGst, closeTo(bill.grandTotal, 0.01));
      // The regression: the screen rendered "+15.25" under a ₹100 item total
      // and then a ₹100 grand total.
      expect(bill.itemTotal + bill.totalGst, isNot(closeTo(bill.grandTotal, 0.01)));
    });

    test('the Taxable Amount row IS shown, so the customer can reconcile', () {
      final bill = build();
      expect(showsTaxableRow(bill), isTrue);
    });
  });

  group('the two modes stay distinct', () {
    test('the same cart bills differently by mode', () {
      final exclusive = RetailBillingService.compute(
          items: [item()], isTaxInclusive: false);
      final inclusive = RetailBillingService.compute(
          items: [item()], isTaxInclusive: true);

      expect(exclusive.grandTotal, isNot(inclusive.grandTotal));
      expect(exclusive.grandTotal, 118);
      expect(inclusive.grandTotal, 100);
    });

    test('the mode is carried on the bill so the screen can label rows', () {
      expect(
          RetailBillingService.compute(items: [item()], isTaxInclusive: true)
              .isTaxInclusive,
          isTrue);
      expect(
          RetailBillingService.compute(items: [item()], isTaxInclusive: false)
              .isTaxInclusive,
          isFalse);
    });

    test('a zero-rated item is identical in both modes', () {
      final ex = RetailBillingService.compute(
          items: [item(rate: 0)], isTaxInclusive: false);
      final inc = RetailBillingService.compute(
          items: [item(rate: 0)], isTaxInclusive: true);

      expect(ex.grandTotal, 100);
      expect(inc.grandTotal, 100);
      expect(showsTaxableRow(ex), isFalse);
      expect(showsTaxableRow(inc), isFalse);
    });
  });

  group('discounts behave correctly in both modes', () {
    test('exclusive: discount comes off the base, tax follows it down', () {
      final b = RetailBillingService.compute(
        items: [item()],
        isTaxInclusive: false,
        discountType: DiscountType.percentage,
        discountValue: 10,
      );
      expect(b.taxableAmount, 90);
      expect(b.totalGst, 16.20);
      expect(b.grandTotal, 106.20);
      expect(showsTaxableRow(b), isTrue);
    });

    test('inclusive: discount comes off the gross, tax is re-extracted', () {
      final b = RetailBillingService.compute(
        items: [item()],
        isTaxInclusive: true,
        discountType: DiscountType.percentage,
        discountValue: 10,
      );
      expect(b.grandTotal, 90);
      expect(b.taxableAmount, 76.27);
      expect(b.totalGst, 13.73);
      expect(b.taxableAmount + b.totalGst, closeTo(b.grandTotal, 0.01));
    });
  });
}
