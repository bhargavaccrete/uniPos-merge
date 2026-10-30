import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/restaurant/order_line_cancel.dart';
import 'package:billberrylite/domain/services/restaurant/saved_service_charge.dart';

import '../../../helpers/test_helpers.dart';

/// Same fake as cart_calculation_service_test: TaxFeature reads this, tax on.
class _TaxOnBusinessDetails extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// BLK-08: an active order saves its service charge as an AMOUNT. Bill print,
/// item cancel and cart total recalculate at the ORIGINAL % on the items the
/// order now has — never the amount read as a % — and delivery keeps its flat
/// charge.
void main() {
  setUpAll(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _TaxOnBusinessDetails());
    }
  });

  CartItem l(String id, {double price = 100, int qty = 1, double tax = 0.05}) =>
      makeCartItem(
          id: 'line-$id', productId: id, title: id, price: price,
          quantity: qty, taxRate: tax);

  /// An active order placed the way customerdetails saves one: the cashier's
  /// [ratePercent] and discount go in, only the resulting AMOUNTS are saved.
  OrderModel placed(
    List<CartItem> items, {
    double ratePercent = 10,
    bool taxInclusive = false,
    DiscountType discountType = DiscountType.amount,
    double discount = 0,
    String orderType = 'Dine In',
    double? deliveryCharge,
  }) {
    final isDelivery = deliveryCharge != null;
    final calc = CartCalculationService(
      items: items,
      discountType: discountType,
      discountValue: discount,
      serviceChargePercentage: isDelivery ? 0 : ratePercent,
      deliveryCharge: deliveryCharge ?? 0,
      isDeliveryOrder: isDelivery,
      isTaxInclusive: taxInclusive,
    );
    final boundaries = [for (var i = 1; i <= items.length; i++) i];
    return OrderModel(
      id: 'o1',
      customerName: '',
      customerNumber: '',
      customerEmail: '',
      items: items,
      status: 'Cooking',
      timeStamp: DateTime(2026, 10, 30, 12),
      orderType: orderType,
      totalPrice: calc.grandTotal,
      subTotal: calc.subtotal,
      gstAmount: calc.totalGST,
      discount: calc.discountAmount,
      serviceCharge: calc.serviceChargeAmount,
      isTaxInclusive: taxInclusive,
      kotNumbers: boundaries,
      itemCountAtLastKot: items.length,
      kotBoundaries: boundaries,
      kotStatuses: {for (final k in boundaries) k: 'Cooking'},
    );
  }

  /// What the items cost at [ratePercent], priced like [order].
  CartCalculationService atRate(OrderModel order, List<CartItem> items,
          double ratePercent) =>
      CartCalculationService(
        items: items,
        discountType: DiscountType.amount,
        discountValue: order.discount ?? 0,
        serviceChargePercentage: ratePercent,
        isTaxInclusive: order.isTaxInclusive,
      );

  group('rate recovered from the saved amount', () {
    test('tax exclusive', () {
      final o = placed([l('A'), l('B'), l('C')]);
      expect(o.serviceCharge, closeTo(31.5, 1e-9)); // 10% of 315
      expect(SavedServiceCharge.ratePercentOf(o, isDelivery: false),
          closeTo(10, 1e-9));
    });

    test('tax inclusive', () {
      final o = placed([l('A'), l('B')], taxInclusive: true, ratePercent: 5);
      expect(SavedServiceCharge.ratePercentOf(o, isDelivery: false),
          closeTo(5, 1e-9));
    });

    test('with a % discount saved as an amount, and mixed tax rates', () {
      final o = placed([l('A', price: 400), l('B', tax: 0.18)],
          ratePercent: 12.5,
          discountType: DiscountType.percentage,
          discount: 10);
      expect(SavedServiceCharge.ratePercentOf(o, isDelivery: false),
          closeTo(12.5, 1e-9));
    });

    test('no charge, a null charge and delivery give 0', () {
      final none = placed([l('A'), l('B')], ratePercent: 0);
      expect(SavedServiceCharge.ratePercentOf(none, isDelivery: false), 0);
      final nullCharge = OrderModel.fromMap(
          none.toMap()..['serviceCharge'] = null);
      expect(nullCharge.serviceCharge, isNull);
      expect(SavedServiceCharge.ratePercentOf(nullCharge, isDelivery: false),
          0);
      final delivery = placed([l('A'), l('B')],
          orderType: 'Delivery', deliveryCharge: 50);
      expect(SavedServiceCharge.ratePercentOf(delivery, isDelivery: true), 0);
    });

    test('nothing to charge on gives 0, never NaN or infinity', () {
      final free = placed([l('A', price: 0), l('B', price: 0)])
          .copyWith(serviceCharge: 5);
      final rate = SavedServiceCharge.ratePercentOf(free, isDelivery: false);
      expect(rate, 0);
      final calc = SavedServiceCharge.calculate(free, free.items,
          isDelivery: false);
      expect(calc.serviceChargeAmount, 0);
      expect(calc.grandTotal.isFinite, isTrue);
    });
  });

  group('bill print and cart total match the order as placed', () {
    for (final inclusive in [false, true]) {
      test('same items → same charge and total (tax '
          '${inclusive ? 'inclusive' : 'exclusive'}, with a discount)', () {
        final o = placed([l('A', price: 200, qty: 2), l('B', tax: 0.18)],
            taxInclusive: inclusive, discount: 50);
        final calc =
            SavedServiceCharge.calculate(o, o.items, isDelivery: false);
        expect(calc.serviceChargeAmount, closeTo(o.serviceCharge!, 1e-9));
        expect(calc.grandTotal, closeTo(o.totalPrice, 1e-9));
      });
    }

    test('the saved amount is never read as a %', () {
      final o = placed([l('A'), l('B'), l('C')]); // ₹31.50 saved
      final calc = SavedServiceCharge.calculate(o, o.items, isDelivery: false);
      expect(calc.serviceChargeAmount, closeTo(31.5, 1e-9),
          reason: 'not 31.5% of 315 = 99.23');
    });

    test('items added since: charged at the same % on the new total', () {
      final o = placed([l('A'), l('B')]);
      final withNew = [...o.items, l('D', price: 50)];
      final calc = SavedServiceCharge.calculate(o, withNew, isDelivery: false);
      expect(calc.serviceChargeAmount,
          closeTo(atRate(o, withNew, 10).serviceChargeAmount, 1e-9));
      expect(calc.serviceChargeAmount, closeTo(26.25, 1e-9)); // 10% of 262.5
    });

    test('delivery: the flat delivery charge, unchanged', () {
      final o = placed([l('A'), l('B')],
          orderType: 'Delivery', deliveryCharge: 50);
      final calc = SavedServiceCharge.calculate(o, [o.items.first],
          isDelivery: true);
      expect(calc.serviceChargeAmount, 50);
      expect(calc.grandTotal, closeTo(105 + 50, 1e-9));
    });
  });

  group('item cancel (Active Orders)', () {
    test('recalculated at the original % on the remaining items', () {
      final o = placed([l('A'), l('B'), l('C')]); // 31.5 on 315
      final r = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 1)!;

      expect(r.order.serviceCharge, closeTo(21, 1e-9),
          reason: '10% of the remaining 210, saved for the next change');
      expect(r.order.totalPrice, closeTo(210 + 21, 1e-9));
      expect(r.order.gstAmount, closeTo(10, 1e-9));
    });

    test('several cancels in a row keep the same %', () {
      var o = placed([l('A'), l('B'), l('C'), l('D', price: 200)]);
      expect(o.serviceCharge, closeTo(52.5, 1e-9)); // 10% of 525

      o = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 0)!.order;
      expect(o.serviceCharge, closeTo(42, 1e-9)); // 10% of 420
      o = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 0)!.order;
      expect(o.serviceCharge, closeTo(31.5, 1e-9)); // 10% of 315
      expect(SavedServiceCharge.ratePercentOf(o, isDelivery: false),
          closeTo(10, 1e-9));
      expect(o.totalPrice, closeTo(315 + 31.5, 1e-9));
    });

    test('with a saved discount and tax inclusive', () {
      final o = placed([l('A', price: 105), l('B', price: 210)],
          taxInclusive: true, discount: 15);
      final r = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 1)!;
      final expected = atRate(o, [o.items.first], 10);
      expect(r.order.serviceCharge,
          closeTo(expected.serviceChargeAmount, 1e-9));
      expect(r.order.totalPrice, closeTo(expected.grandTotal, 1e-9));
      expect(r.order.gstAmount, closeTo(expected.totalGST, 1e-9));
    });

    test('delivery: the flat delivery charge is kept', () {
      final o = placed([l('A'), l('B')],
          orderType: 'Delivery', deliveryCharge: 50);
      final r = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 0)!;
      expect(r.order.serviceCharge, 50);
      expect(r.order.totalPrice, closeTo(105 + 50, 1e-9));
    });

    test('nothing chargeable left: charge 0, totals finite', () {
      final o = placed([l('A'), l('B', price: 0), l('C', price: 0)]);
      final r = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 0)!;
      expect(r.order.serviceCharge, 0);
      expect(r.order.totalPrice, 0);
      expect(r.order.totalPrice.isFinite, isTrue);
    });

    test('an order with no service charge is unchanged by the fix', () {
      final o = placed([l('A'), l('B'), l('C')], ratePercent: 0);
      final r = OrderLineCancel.forActiveOrders(o, itemIndexInOrder: 2)!;
      expect(r.order.serviceCharge, 0);
      expect(r.order.totalPrice, closeTo(210, 1e-9));
    });
  });
}
