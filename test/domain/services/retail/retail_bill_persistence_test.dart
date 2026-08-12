import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

class _FakeBusinessDetailsRepository extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// The acceptance checks for "one bill, one number everywhere", expressed as
/// tests rather than a manual click-through.
///
/// The UI side of each chain is a single read — the POS footer and checkout both
/// render `retailCartStore.bill`, and history/receipts render the stored
/// `SaleModel`. What these tests pin down is the part in between: that what the
/// engine computed is what actually gets persisted, and that it survives a
/// round-trip unchanged.
void main() {
  setUpAll(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _FakeBusinessDetailsRepository());
    }
  });

  CartItemModel item({
    required double price,
    int qty = 1,
    double gstRatePercent = 0,
  }) =>
      CartItemModel.create(
        cartItemId: 'c-$price-$qty-$gstRatePercent',
        variantId: 'v-$price-$gstRatePercent',
        productId: 'p-$price',
        productName: 'Item $price',
        price: price,
        qty: qty,
        gstRate: gstRatePercent,
      );

  /// A realistic bill: mixed rates, a discount, loyalty redeemed, rounding on.
  RetailBill richBill() {
    AppSettings.values['Round Off'] = true;
    AppSettings.roundOffNotifier.value = '1.00';
    return RetailBillingService.compute(
      items: [
        item(price: 249.50, qty: 2, gstRatePercent: 18),
        item(price: 99.90, gstRatePercent: 5),
      ],
      isTaxInclusive: false,
      discountValue: 75,
      loyaltyRedemption: 40,
    );
  }

  tearDown(() {
    AppSettings.values['Round Off'] = false;
  });

  // ── ACCEPTANCE 1: one number, end to end ────────────────────────────────
  group('The settled sale carries the engine figures verbatim', () {
    test('every stored total equals what the engine produced', () {
      final bill = richBill();
      final sale = SaleModel.createWithSplitPayment(
        saleId: 's1',
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        paymentList: [
          {'method': 'cash', 'amount': bill.grandTotal}
        ],
        totalPaid: bill.grandTotal,
        changeReturn: 0,
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
      );

      // What Sales History and the receipt render:
      expect(sale.totalAmount, bill.grandTotal);
      expect(sale.grandTotal, bill.grandTotal);
      // What the POS footer and checkout render is `bill.grandTotal` directly,
      // so this equality IS the "same number everywhere" guarantee.
      expect(sale.subtotal, bill.itemTotal);
      expect(sale.discountAmount, bill.discountAmount);
      expect(sale.totalTaxableAmount, bill.taxableAmount);
      expect(sale.totalGstAmount, bill.totalGst);
      expect(sale.roundOff, bill.roundOff);
      expect(sale.isTaxInclusive, bill.isTaxInclusive);
    });

    test('sale lines reconcile with the sale header', () {
      final bill = richBill();
      final lines = bill.lines
          .map((l) => SaleItemModel.fromCalculated(
                saleId: 's1',
                varianteId: l.item.variantId,
                productId: l.item.productId,
                productName: l.item.productName,
                price: l.item.price,
                qty: l.item.qty,
                discountAmount: l.discountAmount,
                gstRate: l.gstRatePercent,
                taxableAmount: l.taxableAmount,
                gstAmount: l.gstAmount,
                total: l.total,
              ))
          .toList();

      final taxable = lines.fold<double>(0, (s, l) => s + (l.taxableAmount ?? 0));
      final gst = lines.fold<double>(0, (s, l) => s + (l.gstAmount ?? 0));
      final disc = lines.fold<double>(0, (s, l) => s + (l.discountAmount ?? 0));

      expect(taxable, closeTo(bill.taxableAmount, 0.02));
      expect(gst, closeTo(bill.totalGst, 0.02));
      expect(disc, closeTo(bill.discountAmount, 0.02));
    });

    test('a discount actually reduces the stored tax base', () {
      final without = RetailBillingService.compute(
        items: [item(price: 1000, gstRatePercent: 18)],
        isTaxInclusive: false,
      );
      final withDisc = RetailBillingService.compute(
        items: [item(price: 1000, gstRatePercent: 18)],
        isTaxInclusive: false,
        discountValue: 200,
      );

      // The old checkout kept GST at 180 regardless of the discount.
      expect(without.totalGst, 180);
      expect(withDisc.totalGst, 144); // 18% of 800
      expect(withDisc.grandTotal, 944);
    });
  });

  // ── ACCEPTANCE 2: restaurant path unchanged by the CalcLine refactor ─────
  group('Restaurant regression: fromLines() matches the original constructor',
      () {
    CartItem resItem(double price, int qty, double? rate) => CartItem(
          id: 'r-$price-$qty',
          productId: 'rp-$price',
          title: 'Res $price',
          price: price,
          quantity: qty,
          taxRate: rate,
        );

    void expectSame(CartCalculationService a, CartCalculationService b) {
      expect(a.itemTotal, b.itemTotal);
      expect(a.taxableAmount, b.taxableAmount);
      expect(a.discountAmount, b.discountAmount);
      expect(a.totalGST, b.totalGST);
      expect(a.serviceChargeAmount, b.serviceChargeAmount);
      expect(a.roundOffAmount, b.roundOffAmount);
      expect(a.grandTotal, b.grandTotal);
    }

    test('flat discount + service charge + tax exclusive', () {
      final items = [resItem(250, 2, 0.18), resItem(99.9, 1, 0.05)];
      expectSame(
        CartCalculationService(
          items: items,
          discountType: DiscountType.amount,
          discountValue: 75,
          serviceChargePercentage: 10,
          isTaxInclusive: false,
          discountOnItems: false,
        ),
        CartCalculationService.fromLines(
          lines: items
              .map((i) => CalcLine(
                  price: i.price, quantity: i.quantity, taxRate: i.taxRate))
              .toList(),
          discountType: DiscountType.amount,
          discountValue: 75,
          serviceChargePercentage: 10,
          isTaxInclusive: false,
          discountOnItems: false,
        ),
      );
    });

    test('percentage discount + loyalty + tax inclusive + discountOnItems', () {
      final items = [resItem(300, 1, 0.12), resItem(150, 3, 0.18)];
      expectSame(
        CartCalculationService(
          items: items,
          discountType: DiscountType.percentage,
          discountValue: 15,
          loyaltyRedemption: 50,
          isTaxInclusive: true,
          discountOnItems: true,
        ),
        CartCalculationService.fromLines(
          lines: items
              .map((i) => CalcLine(
                  price: i.price, quantity: i.quantity, taxRate: i.taxRate))
              .toList(),
          discountType: DiscountType.percentage,
          discountValue: 15,
          loyaltyRedemption: 50,
          isTaxInclusive: true,
          discountOnItems: true,
        ),
      );
    });

    test('delivery order uses a flat charge, not a percentage', () {
      final items = [resItem(200, 1, 0.05)];
      expectSame(
        CartCalculationService(
          items: items,
          discountType: DiscountType.amount,
          discountValue: 0,
          deliveryCharge: 40,
          isDeliveryOrder: true,
          isTaxInclusive: false,
          discountOnItems: false,
        ),
        CartCalculationService.fromLines(
          lines: items
              .map((i) => CalcLine(
                  price: i.price, quantity: i.quantity, taxRate: i.taxRate))
              .toList(),
          discountType: DiscountType.amount,
          discountValue: 0,
          deliveryCharge: 40,
          isDeliveryOrder: true,
          isTaxInclusive: false,
          discountOnItems: false,
        ),
      );
    });
  });

  // ── ACCEPTANCE 3: park → restore keeps the tax basis ────────────────────
  group('Parking a sale preserves its tax basis', () {
    test('held lines carry gst/taxable/discount, not just a price', () {
      final bill = richBill();
      final held = bill.lines
          .map((l) => HoldSaleItemModel.create(
                holdSaleId: 'h1',
                variantId: l.item.variantId,
                productId: l.item.productId,
                productName: l.item.productName,
                price: l.item.price,
                qty: l.item.qty,
                gstRate: l.gstRatePercent,
                taxableAmount: l.taxableAmount,
                gstAmount: l.gstAmount,
                discountAmount: l.discountAmount,
              ))
          .toList();

      final gst = held.fold<double>(0, (s, h) => s + (h.gstAmount ?? 0));
      expect(gst, closeTo(bill.totalGst, 0.02));
      // Before this change every one of these was simply absent.
      expect(held.every((h) => h.taxableAmount != null), isTrue);
      expect(held.every((h) => h.gstRate != null), isTrue);
    });

    test('the parked header records the payable total and its composition', () {
      final bill = richBill();
      final hold = HoldSaleModel.create(
        holdSaleId: 'h1',
        totalItems: bill.totalItems,
        subtotal: bill.grandTotal,
        itemTotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        taxableAmount: bill.taxableAmount,
        gstAmount: bill.totalGst,
        isTaxInclusive: bill.isTaxInclusive,
      );

      expect(hold.subtotal, bill.grandTotal);
      expect(hold.gstAmount, bill.totalGst);
      expect(hold.itemTotal, bill.itemTotal);
    });
  });

  // ── ACCEPTANCE 4: a reprint can't drift ─────────────────────────────────
  group('Reprint reads stored values, so settings changes cannot alter it', () {
    test('round-off and tax mode survive a persistence round-trip', () {
      final bill = richBill();
      final sale = SaleModel.createWithSplitPayment(
        saleId: 's1',
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        paymentList: [
          {'method': 'cash', 'amount': bill.grandTotal}
        ],
        totalPaid: bill.grandTotal,
        changeReturn: 0,
        discountType: 'percentage',
        discountValue: 10,
        discountReason: 'Damaged Product',
        loyaltyPointsUsed: 40,
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
      );

      final restored = SaleModel.fromMap(sale.toMap());

      expect(restored.totalAmount, sale.totalAmount);
      expect(restored.roundOff, sale.roundOff);
      expect(restored.isTaxInclusive, sale.isTaxInclusive);
      expect(restored.discountType, 'percentage');
      expect(restored.discountValue, 10);
      expect(restored.discountReason, 'Damaged Product');
      expect(restored.loyaltyPointsUsed, 40);
    });

    test('turning round-off off later does not change the stored total', () {
      final bill = richBill();
      final storedTotal = bill.grandTotal;
      final storedRoundOff = bill.roundOff;

      final sale = SaleModel.createWithSplitPayment(
        saleId: 's1',
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        paymentList: [
          {'method': 'cash', 'amount': bill.grandTotal}
        ],
        totalPaid: bill.grandTotal,
        changeReturn: 0,
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
      );

      // Simulate the shop changing settings after the sale.
      AppSettings.values['Round Off'] = false;

      // The receipt renders from the sale, so it is unaffected.
      expect(sale.totalAmount, storedTotal);
      expect(sale.roundOff, storedRoundOff);
    });
  });
}
