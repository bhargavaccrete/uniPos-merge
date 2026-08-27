import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/quick_item_service.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// `TaxFeature.enabled` reads `BusinessDetailsRepository.isTaxEnabled`, which
/// hits a Hive box. This fake lets the engine be tested without Hive.
class _FakeBusinessDetailsRepository extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// Tests for the single retail billing engine.
///
/// The cases here are the ones that were actually WRONG in the old hand-rolled
/// checkout arithmetic, plus the unit-conversion trap introduced by sharing the
/// restaurant engine (which speaks tax FRACTIONS while retail stores PERCENTS).
void main() {
  setUpAll(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _FakeBusinessDetailsRepository());
    }
  });

  CartItemModel item({
    required double price,
    double qty = 1,
    double gstRatePercent = 0,
  }) =>
      CartItemModel.create(
        cartItemId: 'c-$price-$qty-$gstRatePercent',
        variantId: 'v-$price',
        productId: 'p-$price',
        productName: 'Item $price',
        price: price,
        qty: qty,
        gstRate: gstRatePercent,
      );

  group('GST rate units (percent vs fraction)', () {
    test('an 18% item yields 18% GST, not 1800%', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 100, gstRatePercent: 18)],
        isTaxInclusive: false,
      );

      expect(bill.taxableAmount, 100);
      expect(bill.totalGst, 18);
      expect(bill.grandTotal, 118);
    });

    test('breakdown is keyed by percent, and splits CGST/SGST evenly', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 100, gstRatePercent: 18)],
        isTaxInclusive: false,
      );

      expect(bill.gstBreakdown.keys, contains(18.0));
      expect(bill.cgstAmount, 9);
      expect(bill.sgstAmount, 9);
    });

    test('a zero-rated item adds no tax', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 250, qty: 2)],
        isTaxInclusive: false,
      );

      expect(bill.totalGst, 0);
      expect(bill.grandTotal, 500);
    });
  });

  group('Discount is applied BEFORE tax (the old bug)', () {
    test('a flat discount reduces GST proportionally', () {
      // The old checkout computed GST on the full 100 and produced 68.
      final bill = RetailBillingService.compute(
        items: [item(price: 100, gstRatePercent: 18)],
        isTaxInclusive: false,
        discountValue: 50,
      );

      expect(bill.discountAmount, 50);
      expect(bill.taxableAmount, 50);
      expect(bill.totalGst, 9); // 18% of 50, not of 100
      expect(bill.grandTotal, 59);
    });

    test('a percentage discount reduces GST proportionally', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 200, gstRatePercent: 5)],
        isTaxInclusive: false,
        discountType: DiscountType.percentage,
        discountValue: 10,
      );

      expect(bill.discountAmount, 20);
      expect(bill.taxableAmount, 180);
      expect(bill.totalGst, 9); // 5% of 180
      expect(bill.grandTotal, 189);
    });

    test('tax-inclusive: discount comes off the gross, tax is re-extracted', () {
      // 118 gross incl. 18% -> base 100. After an 18 discount: gross 100,
      // base 100/1.18 = 84.75, tax 15.25.
      final bill = RetailBillingService.compute(
        items: [item(price: 118, gstRatePercent: 18)],
        isTaxInclusive: true,
        discountValue: 18,
      );

      expect(bill.taxableAmount, closeTo(84.75, 0.01));
      expect(bill.totalGst, closeTo(15.25, 0.01));
      expect(bill.grandTotal, closeTo(100, 0.01));
    });
  });

  group('Discount is clamped (never negative)', () {
    test('a flat discount larger than the bill clamps to the bill', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 100, gstRatePercent: 18)],
        isTaxInclusive: false,
        discountValue: 500,
      );

      expect(bill.discountAmount, 100);
      expect(bill.taxableAmount, 0);
      expect(bill.totalGst, 0);
      expect(bill.grandTotal, 0);
    });

    test('a percentage over 100 clamps to the bill', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 100, gstRatePercent: 18)],
        isTaxInclusive: false,
        discountType: DiscountType.percentage,
        discountValue: 250,
      );

      expect(bill.grandTotal, 0);
      expect(bill.grandTotal, greaterThanOrEqualTo(0));
    });
  });

  group('Loyalty redemption reduces the taxable base before GST', () {
    test('taxable and GST both scale down', () {
      // 200 base + 18% = 236. Redeeming 100 leaves half the bill, so both the
      // base and the tax should halve.
      final bill = RetailBillingService.compute(
        items: [item(price: 200, gstRatePercent: 18)],
        isTaxInclusive: false,
        loyaltyRedemption: 100,
      );

      expect(bill.loyaltyRedemption, 100);
      expect(bill.taxableAmount, 100);
      expect(bill.totalGst, closeTo(18, 0.01)); // 18% of 100, not of 200
      expect(bill.grandTotal, closeTo(118, 0.01));
    });

    test('redemption is capped at the bill value', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 50)],
        isTaxInclusive: false,
        loyaltyRedemption: 999,
      );

      expect(bill.loyaltyRedemption, 50);
      expect(bill.grandTotal, 0);
    });
  });

  group('Per-line results reconcile with the bill', () {
    test('line taxable and GST sum to the bill totals', () {
      final bill = RetailBillingService.compute(
        items: [
          item(price: 100, gstRatePercent: 18),
          item(price: 200, qty: 2, gstRatePercent: 5),
        ],
        isTaxInclusive: false,
        discountValue: 50,
      );

      final lineTaxable =
          bill.lines.fold<double>(0, (s, l) => s + l.taxableAmount);
      final lineGst = bill.lines.fold<double>(0, (s, l) => s + l.gstAmount);
      final lineDiscount =
          bill.lines.fold<double>(0, (s, l) => s + l.discountAmount);

      expect(lineTaxable, closeTo(bill.taxableAmount, 0.02));
      expect(lineGst, closeTo(bill.totalGst, 0.02));
      expect(lineDiscount, closeTo(bill.discountAmount, 0.02));
    });

    test('itemTotal is the gross before discount', () {
      final bill = RetailBillingService.compute(
        items: [item(price: 100, qty: 3, gstRatePercent: 18)],
        isTaxInclusive: false,
        discountValue: 100,
      );

      expect(bill.itemTotal, 300);
      expect(bill.taxableAmount, 200);
    });
  });

  group('Round off', () {
    tearDown(() {
      AppSettings.values['Round Off'] = false;
    });

    test('rounds the grand total to the nearest rupee and reports the delta',
        () {
      AppSettings.values['Round Off'] = true;
      AppSettings.roundOffNotifier.value = '1.00';

      // 100 + 5% = 105.00 exactly, so use a rate that produces paise.
      final bill = RetailBillingService.compute(
        items: [item(price: 99.40, gstRatePercent: 18)],
        isTaxInclusive: false,
      );

      // 99.40 * 1.18 = 117.292 -> rounds to 117.00
      expect(bill.grandTotal, 117);
      expect(bill.roundOff, closeTo(-0.29, 0.01));
    });

    test('no rounding when the setting is off', () {
      AppSettings.values['Round Off'] = false;

      final bill = RetailBillingService.compute(
        items: [item(price: 99.40, gstRatePercent: 18)],
        isTaxInclusive: false,
      );

      expect(bill.roundOff, 0);
      expect(bill.grandTotal, closeTo(117.29, 0.01));
    });
  });

  group('Empty cart', () {
    test('returns a zeroed bill', () {
      final bill =
          RetailBillingService.compute(items: [], isTaxInclusive: false);

      expect(bill.grandTotal, 0);
      expect(bill.totalGst, 0);
      expect(bill.lines, isEmpty);
    });
  });

  group('Partial payment (SaleModel.createWithSplitPayment)', () {
    SaleModel make({double? collected}) => SaleModel.createWithSplitPayment(
          saleId: 's1',
          totalItems: 1,
          subtotal: 100,
          discountAmount: 0,
          totalTaxableAmount: 100,
          totalGstAmount: 18,
          grandTotal: 118,
          paymentList: [
            {'method': 'cash', 'amount': collected ?? 118.0}
          ],
          totalPaid: collected ?? 118,
          changeReturn: 0,
          amountCollected: collected,
        );

    test('a fully paid sale has no due and status paid', () {
      final sale = make();
      expect(sale.paidAmount, 118);
      expect(sale.dueAmount, 0);
      expect(sale.status, SaleStatus.paid);
    });

    test('collecting less records the balance as due', () {
      final sale = make(collected: 50);
      expect(sale.paidAmount, 50);
      expect(sale.dueAmount, 68);
      expect(sale.status, SaleStatus.partiallyPaid);
      expect(sale.hasDue, isTrue);
    });

    test('a sub-paisa shortfall still counts as fully paid', () {
      final sale = make(collected: 117.999);
      expect(sale.status, SaleStatus.paid);
      expect(sale.dueAmount, 0);
    });

    test('tendering over the bill is change, not an over-payment', () {
      final sale = make(collected: 500);
      expect(sale.paidAmount, 118); // never exceeds the bill
      expect(sale.dueAmount, 0);
      expect(sale.status, SaleStatus.paid);
    });
  });

  // The engine is deliberately id-blind — it never reads variantId or
  // productId. These pin that a quick item, whose ids resolve to no catalogue
  // row, bills exactly like a catalogue line sitting beside it.
  group('quick items bill through the same engine', () {
    CartItemModel quick({
      required String name,
      required double price,
      double qty = 1,
      double gstRatePercent = 0,
      double? lineDiscountAmount,
    }) =>
        CartItemModel.create(
          cartItemId: '${QuickItemService.idPrefix}$name',
          variantId: QuickItemService.newVariantId(),
          productId: QuickItemService.newProductId(),
          productName: name,
          price: price,
          qty: qty,
          gstRate: gstRatePercent,
          lineDiscountAmount: lineDiscountAmount,
        );

    test('a lone quick item bills like any other line', () {
      final bill = RetailBillingService.compute(
        items: [quick(name: 'Local Bread', price: 45, gstRatePercent: 5)],
        isTaxInclusive: false,
      );

      expect(bill.taxableAmount, 45);
      expect(bill.totalGst, 2.25);
      expect(bill.grandTotal, 47.25);
    });

    test('two quick items stay two lines and both reach the total', () {
      final bill = RetailBillingService.compute(
        items: [
          quick(name: 'Local Bread', price: 45),
          quick(name: 'Plastic Bag', price: 5),
        ],
        isTaxInclusive: false,
      );

      expect(bill.lines.length, 2);
      expect(bill.itemTotal, 50);
      expect(bill.grandTotal, 50);
    });

    test('a mixed basket sums a catalogue line and a quick line', () {
      final bill = RetailBillingService.compute(
        items: [
          item(price: 100, gstRatePercent: 18),
          quick(name: 'Local Bread', price: 45, qty: 2, gstRatePercent: 5),
        ],
        isTaxInclusive: false,
      );

      expect(bill.lines.length, 2);
      expect(bill.itemTotal, 190); // 100 + 90
      expect(bill.taxableAmount, 190);
      expect(bill.totalGst, 22.5); // 18 + 4.5
      expect(bill.grandTotal, 212.5);
    });

    test('a quick line keeps its own GST rate in the breakdown', () {
      final bill = RetailBillingService.compute(
        items: [
          item(price: 100, gstRatePercent: 18),
          quick(name: 'Local Bread', price: 100, gstRatePercent: 5),
        ],
        isTaxInclusive: false,
      );

      expect(bill.gstBreakdown[18]!.totalGstAmount, 18);
      expect(bill.gstBreakdown[5]!.totalGstAmount, 5);
    });

    test('a line discount on a quick item reaches the bill', () {
      final bill = RetailBillingService.compute(
        items: [
          quick(
            name: 'Local Bread',
            price: 100,
            gstRatePercent: 0,
            lineDiscountAmount: 10,
          ),
        ],
        isTaxInclusive: false,
      );

      expect(bill.lineDiscountTotal, 10);
      expect(bill.taxableAmount, 90);
      expect(bill.grandTotal, 90);
    });

    test('a quick item is unaffected by an order-level discount elsewhere '
        'beyond its fair share', () {
      final bill = RetailBillingService.compute(
        items: [
          item(price: 100, gstRatePercent: 0),
          quick(name: 'Local Bread', price: 100, gstRatePercent: 0),
        ],
        isTaxInclusive: false,
        discountType: DiscountType.amount,
        discountValue: 20,
      );

      // Two equal lines share a flat 20 evenly.
      expect(bill.itemTotal, 200);
      expect(bill.discountAmount, 20);
      expect(bill.grandTotal, 180);
      expect(bill.lines[0].discountAmount, 10);
      expect(bill.lines[1].discountAmount, 10);
    });
  });
}
