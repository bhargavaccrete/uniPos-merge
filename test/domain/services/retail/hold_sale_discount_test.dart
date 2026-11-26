import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/retail/hold_sale_service.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';

/// Same fake as retail_bill_persistence_test: TaxFeature reads this, tax on.
class _TaxOnBusinessDetails extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// BLK-12: a parked sale stores the bill's `discountAmount` — line discounts
/// AND the order discount together. Restore puts each line's discount back on
/// the line, so it must replay only the ORDER-level remainder; replaying the
/// whole figure took every line discount off twice.
///
/// Parks exactly what `HoldSaleService.park` stores, restores through
/// [HoldSaleService.billDiscountToReplay], and prices both sides with the real
/// retail engine: the restored bill must equal the parked one.
void main() {
  setUpAll(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _TaxOnBusinessDetails());
    }
  });

  CartItemModel line(String id, double price,
          {double qty = 1, double gst = 0, double lineDiscount = 0}) =>
      CartItemModel.create(
        cartItemId: 'c-$id',
        variantId: 'v-$id',
        productId: 'p-$id',
        productName: 'Item $id',
        price: price,
        qty: qty,
        gstRate: gst,
        lineDiscountType: lineDiscount > 0 ? DiscountType.amount.name : null,
        lineDiscountValue: lineDiscount > 0 ? lineDiscount : null,
        lineDiscountAmount: lineDiscount > 0 ? lineDiscount : null,
      );

  /// What park() stores: the header's combined discount, and each line's own.
  (HoldSaleModel, List<HoldSaleItemModel>) park(RetailBill bill) {
    final hold = HoldSaleModel.create(
      holdSaleId: 'HOLD_1',
      totalItems: bill.totalItems,
      subtotal: bill.grandTotal,
      itemTotal: bill.itemTotal,
      discountAmount: bill.discountAmount,
      taxableAmount: bill.taxableAmount,
      gstAmount: bill.totalGst,
      isTaxInclusive: bill.isTaxInclusive,
    );
    final items = [
      for (final l in bill.lines)
        HoldSaleItemModel.create(
          holdSaleId: 'HOLD_1',
          variantId: l.item.variantId,
          productId: l.item.productId,
          productName: l.item.productName,
          price: l.item.price,
          qty: l.item.qty,
          gstRate: l.gstRatePercent,
          lineDiscountType: l.item.lineDiscountType,
          lineDiscountValue: l.item.lineDiscountValue,
          lineDiscountAmount: l.item.lineDiscountAmount,
        ),
    ];
    return (hold, items);
  }

  /// The cart restore() rebuilds — same lines and line discounts — priced
  /// with the order discount it now replays.
  RetailBill restore(List<CartItemModel> cart, bool inclusive,
      HoldSaleModel hold, List<HoldSaleItemModel> items) {
    return RetailBillingService.compute(
      items: cart,
      isTaxInclusive: inclusive,
      discountType: DiscountType.amount,
      discountValue: HoldSaleService.billDiscountToReplay(hold, items),
    );
  }

  void expectSameBill(RetailBill restored, RetailBill parked) {
    expect(restored.grandTotal, closeTo(parked.grandTotal, 0.01));
    expect(restored.discountAmount, closeTo(parked.discountAmount, 0.01));
    expect(restored.taxableAmount, closeTo(parked.taxableAmount, 0.01));
    expect(restored.totalGst, closeTo(parked.totalGst, 0.01));
  }

  test('line + order discount: the restored bill equals the parked one', () {
    final cart = [line('a', 100, lineDiscount: 10)];
    final parked = RetailBillingService.compute(
        items: cart, isTaxInclusive: false, discountValue: 5);
    expect(parked.grandTotal, closeTo(85, 0.001));

    final (hold, items) = park(parked);
    expect(HoldSaleService.billDiscountToReplay(hold, items),
        closeTo(5, 0.001), reason: 'only the order-level 5, not 15');

    final restored = restore(cart, false, hold, items);
    expect(restored.grandTotal, closeTo(85, 0.001),
        reason: 'not 75 — the 10 line discount is taken once');
    expectSameBill(restored, parked);
  });

  test('line discounts only: nothing replayed at order level', () {
    final cart = [
      line('a', 250, qty: 2, lineDiscount: 30),
      line('b', 80, lineDiscount: 5),
    ];
    final parked =
        RetailBillingService.compute(items: cart, isTaxInclusive: false);
    final (hold, items) = park(parked);

    expect(HoldSaleService.billDiscountToReplay(hold, items), 0);
    expectSameBill(restore(cart, false, hold, items), parked);
  });

  test('order discount only: replayed as is', () {
    final cart = [line('a', 300), line('b', 200)];
    final parked = RetailBillingService.compute(
        items: cart, isTaxInclusive: false, discountValue: 40);
    final (hold, items) = park(parked);

    expect(HoldSaleService.billDiscountToReplay(hold, items),
        closeTo(40, 0.001));
    expectSameBill(restore(cart, false, hold, items), parked);
  });

  test('a percentage order discount on top of line discounts', () {
    final cart = [
      line('a', 500, lineDiscount: 50),
      line('b', 200),
    ];
    final parked = RetailBillingService.compute(
      items: cart,
      isTaxInclusive: false,
      discountType: DiscountType.percentage,
      discountValue: 10,
    );
    final (hold, items) = park(parked);

    // 10% of what is left after the line discount: 10% of 650 = 65.
    expect(HoldSaleService.billDiscountToReplay(hold, items),
        closeTo(65, 0.01));
    expectSameBill(restore(cart, false, hold, items), parked);
  });

  for (final inclusive in [false, true]) {
    test('mixed tax rates, tax ${inclusive ? 'inclusive' : 'exclusive'}', () {
      final cart = [
        line('a', 249.50, qty: 2, gst: 18, lineDiscount: 20),
        line('b', 99.90, gst: 5, lineDiscount: 4.90),
        line('c', 60, gst: 12),
      ];
      final parked = RetailBillingService.compute(
          items: cart, isTaxInclusive: inclusive, discountValue: 25);
      final (hold, items) = park(parked);

      expectSameBill(restore(cart, inclusive, hold, items), parked);
    });
  }

  test('never a negative order discount', () {
    final hold = HoldSaleModel.create(
        holdSaleId: 'H', totalItems: 1, subtotal: 90, discountAmount: 9.999);
    final items = [
      HoldSaleItemModel.create(
          holdSaleId: 'H',
          variantId: 'v',
          productId: 'p',
          productName: 'x',
          price: 100,
          qty: 1,
          lineDiscountAmount: 10),
    ];
    expect(HoldSaleService.billDiscountToReplay(hold, items), 0);
  });

  test('a parked sale with no discount fields replays nothing', () {
    final hold =
        HoldSaleModel.create(holdSaleId: 'H', totalItems: 1, subtotal: 100);
    final items = [
      HoldSaleItemModel.create(
          holdSaleId: 'H',
          variantId: 'v',
          productId: 'p',
          productName: 'x',
          price: 100,
          qty: 1),
    ];
    expect(HoldSaleService.billDiscountToReplay(hold, items), 0);
  });
}
