import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/restaurant/paid_order_record.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/services/restaurant/saved_service_charge.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/pre_paid_order_fields_order_adapter.dart';
import '../../../helpers/test_helpers.dart';

/// Same fake as cart_calculation_service_test: TaxFeature reads this, tax on.
class _TaxOnBusinessDetails extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// BLK-09: a Dine In payment taken on an order that stays active records the
/// payment in full (totals and GST as charged, points, discount staff, paying
/// shift); both ways the order later leaves Active Orders build the same past
/// order; the payment screen starts from the saved discount and charge.
void main() {
  setUp(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _TaxOnBusinessDetails());
    }
  });

  CartItem l(String id, {double price = 100, int qty = 1, double tax = 0.05}) =>
      makeCartItem(
          id: 'line-$id', productId: id, title: id, price: price,
          quantity: qty, taxRate: tax);

  /// A Dine In order as placed: three ₹100 lines at 5%, 10% service charge,
  /// no discount — subTotal/gstAmount are the PLACEMENT figures.
  OrderModel placed({bool taxInclusive = false, String? shiftId}) {
    final items = [l('A'), l('B'), l('C')];
    final calc = CartCalculationService(
      items: items,
      discountType: DiscountType.amount,
      discountValue: 0,
      serviceChargePercentage: 10,
      isTaxInclusive: taxInclusive,
    );
    return OrderModel(
      id: 'o1',
      customerName: 'Asha',
      customerNumber: '9000000000',
      customerEmail: '',
      items: items,
      status: 'Cooking',
      timeStamp: DateTime(2026, 10, 30, 12),
      orderType: 'Dine In',
      tableNo: 'T1',
      totalPrice: calc.grandTotal,
      subTotal: calc.subtotal,
      gstAmount: calc.totalGST,
      discount: calc.discountAmount,
      serviceCharge: calc.serviceChargeAmount,
      isTaxInclusive: taxInclusive,
      kotNumbers: [1],
      itemCountAtLastKot: 3,
      kotBoundaries: [3],
      kotStatuses: {1: 'Cooking'},
      sessionId: 's1',
      shiftId: shiftId,
    );
  }

  /// The payment screen's calculation (customerdetails buildCalc): a ₹50
  /// discount given at payment, 10% service charge, [points] redeemed.
  CartCalculationService payment(OrderModel o, {double points = 0}) =>
      CartCalculationService(
        items: o.items,
        discountType: DiscountType.amount,
        discountValue: 50,
        serviceChargePercentage: 10,
        isTaxInclusive: o.isTaxInclusive,
        loyaltyRedemption: points,
      );

  /// What proceed() records for a Dine In table paid before it is served.
  OrderModel paid(OrderModel o, CartCalculationService calc,
          {int points = 0}) =>
      PaidOrderRecord.applyPayment(
        o.copyWith(
          customerId: 'c1',
          paymentMethod: 'Cash',
          isPaid: true,
          paymentStatus: 'Paid',
          totalPaid: calc.grandTotal,
          billNumber: 7,
        ),
        calc,
        pointsUsed: points,
        discountAppliedBy: 'Ravi (manager)',
        shiftId: 'shift-pay',
      );

  PastOrderModel servedFromActiveOrders(OrderModel o) =>
      PaidOrderRecord.toPastOrder(o,
          billNumber: o.billNumber!,
          currentShiftId: 'shift-eod',
          paymentModeFallback: 'N/A',
          taxEnabled: true,
          roundOffStep: 0,
          discountOnItems: false);

  PastOrderModel completedAtEndOfDay(OrderModel o) =>
      PaidOrderRecord.toPastOrder(o,
          billNumber: o.billNumber!,
          currentShiftId: 'shift-eod',
          taxEnabled: true,
          roundOffStep: 0,
          discountOnItems: false);

  group('the payment is recorded on the active order', () {
    for (final inclusive in [false, true]) {
      test('discount at payment: GST and totals are the payment\'s '
          '(tax ${inclusive ? 'inclusive' : 'exclusive'})', () {
        final o = placed(taxInclusive: inclusive);
        final calc = payment(o);
        final p = paid(o, calc);

        expect(p.subTotal, closeTo(calc.subtotal, 1e-9));
        expect(p.gstAmount, closeTo(calc.totalGST, 1e-9));
        expect(p.gstAmount, isNot(closeTo(o.gstAmount!, 1e-6)),
            reason: 'the GST saved when the order was placed is replaced');
        expect(p.discount, closeTo(50, 1e-9));
        expect(p.serviceCharge, closeTo(calc.serviceChargeAmount, 1e-9));
        expect(p.totalPrice, closeTo(calc.grandTotal, 1e-9));
        expect(p.subTotal! + p.gstAmount! + p.serviceCharge!,
            closeTo(p.totalPrice, 1e-9));
        expect(p.discountAppliedBy, 'Ravi (manager)');
        expect(p.shiftId, 'shift-pay');
        expect(p.loyaltyPointsUsed, isNull);
      });
    }

    test('points redeemed: recorded, and GST is on the bill after them', () {
      final o = placed();
      final calc = payment(o, points: 100);
      final p = paid(o, calc, points: 100);

      expect(p.loyaltyPointsUsed, 100);
      expect(p.gstAmount, closeTo(calc.totalGST, 1e-9));
      expect(p.gstAmount, lessThan(payment(o).totalGST));
      expect(p.totalPrice, closeTo(calc.grandTotal, 1e-9));
    });

    test('no discount: no discount staff recorded', () {
      final o = placed();
      final calc = CartCalculationService(
          items: o.items,
          discountType: DiscountType.amount,
          discountValue: 0,
          serviceChargePercentage: 10,
          isTaxInclusive: false);
      expect(paid(o, calc).discountAppliedBy, isNull);
    });
  });

  group('both ways out of Active Orders build the same past order', () {
    test('served from Active Orders == completed at End of Day', () {
      final p = paid(placed(), payment(placed(), points: 100), points: 100);
      final a = servedFromActiveOrders(p).toMap();
      final b = completedAtEndOfDay(p).toMap();
      expect(a, b);
    });

    test('the past order keeps the payment, points, customer and shift', () {
      final o = placed();
      final calc = payment(o, points: 100);
      final past = servedFromActiveOrders(paid(o, calc, points: 100));

      expect(past.totalPrice, closeTo(calc.grandTotal, 1e-9));
      expect(past.subTotal, closeTo(calc.subtotal, 1e-9));
      expect(past.gstAmount, closeTo(calc.totalGST, 1e-9));
      expect(past.Discount, closeTo(50, 1e-9));
      expect(past.serviceCharge, closeTo(calc.serviceChargeAmount, 1e-9));
      expect(past.loyaltyPointsUsed, 100);
      expect(past.discountAppliedBy, 'Ravi (manager)');
      expect(past.customerId, 'c1');
      expect(past.shiftId, 'shift-pay',
          reason: 'the shift that took the cash, not the one open at EOD');
      expect(past.sessionId, 's1');
      expect(past.billNumber, 7);
      expect(past.tableNo, 'T1');
      expect(past.orderStatus, 'COMPLETED');
    });

    test('an order saved without a shift falls back to the current shift',
        () {
      final old = placed(); // no shiftId, as before BLK-09
      expect(completedAtEndOfDay(old.copyWith(billNumber: 3)).shiftId,
          'shift-eod');
      expect(servedFromActiveOrders(old.copyWith(billNumber: 3)).shiftId,
          'shift-eod');
    });

    test('a reprint of the past order totals what was paid', () {
      final o = placed();
      final calc = payment(o, points: 100);
      final past = completedAtEndOfDay(paid(o, calc, points: 100));

      // RestaurantPrintHelper.printPastOrder's calculation.
      final reprint = CartCalculationService(
        items: past.items,
        discountType: DiscountType.amount,
        discountValue: past.Discount ?? 0,
        isDeliveryOrder: true,
        deliveryCharge: past.serviceCharge ?? 0,
        isTaxInclusive: past.isTaxInclusive,
        taxEnabled: past.taxEnabled,
        discountOnItems: past.discountOnItems,
        roundOffStep: past.roundOffStep,
        loyaltyRedemption: (past.loyaltyPointsUsed ?? 0).toDouble(),
      );
      expect(reprint.grandTotal, closeTo(past.totalPrice, 1e-9));
      expect(reprint.totalGST, closeTo(past.gstAmount!, 1e-9));
    });
  });

  group('payment screen starts from the saved order', () {
    test('saved 10% service charge and discount', () {
      final p = paid(placed(), payment(placed()));
      final f = PaidOrderRecord.prefill(p, isDelivery: false);
      expect(f.serviceChargeValue, closeTo(10, 1e-9));
      expect(f.discountAmount, closeTo(50, 1e-9));
    });

    test('points used at payment: the % is still exactly 10', () {
      final p = paid(placed(), payment(placed(), points: 100), points: 100);
      expect(SavedServiceCharge.ratePercentOf(p, isDelivery: false),
          closeTo(10, 1e-9));
      expect(PaidOrderRecord.prefill(p, isDelivery: false).serviceChargeValue,
          closeTo(10, 1e-9));
      // And the active-order bill print / cart total match the payment.
      final again = SavedServiceCharge.calculate(p, p.items, isDelivery: false);
      expect(again.grandTotal, closeTo(p.totalPrice, 1e-9));
    });

    test('delivery: the flat delivery charge', () {
      final o = placed().copyWith(orderType: 'Delivery', serviceCharge: 40);
      final f = PaidOrderRecord.prefill(o, isDelivery: true);
      expect(f.serviceChargeValue, 40);
    });

    test('nothing saved: both start off', () {
      final o = placed().copyWith(serviceCharge: 0, discount: 0);
      final f = PaidOrderRecord.prefill(o, isDelivery: false);
      expect(f.serviceChargeValue, 0);
      expect(f.discountAmount, 0);
    });
  });

  group('Hive and backup compatibility', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paid_order_record_');
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
    });

    tearDown(() async {
      await Hive.close();
      Hive.registerAdapter(OrderModelAdapter(), override: true);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('an active order saved before BLK-09 still reads; new fields null',
        () async {
      final original = placed().copyWith(
          billNumber: 4, customerId: 'c1', paymentMethod: 'UPI');
      Hive.registerAdapter(PrePaidOrderFieldsOrderAdapter(), override: true);
      var box = await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      await box.put('OLD', original);
      await box.close();

      Hive.registerAdapter(OrderModelAdapter(), override: true);
      box = await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      final loaded = box.get('OLD')!;

      expect(loaded.loyaltyPointsUsed, isNull);
      expect(loaded.discountAppliedBy, isNull);
      expect(loaded.shiftId, isNull);
      expect(loaded.toMap(), original.toMap());
      expect(loaded.billNumber, 4);
      expect(loaded.sessionId, 's1');
    });

    test('the new fields round-trip through Hive', () async {
      final p = paid(placed(), payment(placed(), points: 100), points: 100);
      var box = await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      await box.put(p.id, p);
      await box.close();
      box = await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      final loaded = box.get(p.id)!;

      expect(loaded.loyaltyPointsUsed, 100);
      expect(loaded.discountAppliedBy, 'Ravi (manager)');
      expect(loaded.shiftId, 'shift-pay');
      expect(loaded.toMap(), p.toMap());
    });

    test('backup map: new fields round-trip; an old map without them parses',
        () {
      final p = paid(placed(), payment(placed(), points: 100), points: 100);
      expect(OrderModel.fromMap(p.toMap()).toMap(), p.toMap());

      final oldMap = p.toMap()
        ..remove('loyaltyPointsUsed')
        ..remove('discountAppliedBy')
        ..remove('shiftId');
      final old = OrderModel.fromMap(oldMap);
      expect(old.loyaltyPointsUsed, isNull);
      expect(old.discountAppliedBy, isNull);
      expect(old.shiftId, isNull);
      expect(old.totalPrice, p.totalPrice);
    });
  });

  group('refund of a pay-first order', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paid_order_refund_');
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
      await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
      await Hive.openBox<Category>(HiveBoxNames.category);
      await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
      await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
      await Hive.openBox<StockMovementModel>(
          HiveBoxNames.restaurantStockMovements);
      await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
      await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
      await Hive.openBox<Customer>(HiveBoxNames.customer);
      await Hive.openBox(HiveBoxNames.dayManagementBox);
      await openRestaurantSessionForTest();

      locator
        ..registerLazySingleton<LicenseStore>(
            () => LicenseStore(LicenseApiService())..licenseBypassed = true)
        ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
        ..registerLazySingleton<VariantStore>(
            () => VariantStore(VariantRepositoryRes()))
        ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
        ..registerLazySingleton<NotificationStore>(
            () => NotificationStore(NotificationRepository()))
        ..registerLazySingleton<CustomerStore>(
            () => CustomerStore(CustomerRepository()))
        ..registerLazySingleton<PastOrderRepository>(
            () => PastOrderRepository())
        ..registerLazySingleton<PastOrderStore>(
            () => PastOrderStore(locator<PastOrderRepository>()));

      await Hive.box<Customer>(HiveBoxNames.customer).put(
          'c1',
          Customer(
              customerId: 'c1',
              name: 'Asha',
              loyaltyPoints: 0,
              createdAt: '2026-10-01T00:00:00.000'));
    });

    tearDown(() async {
      await locator.reset();
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('restores the points used, in proportion', () async {
      final o = placed();
      final calc = payment(o, points: 100);
      final past = completedAtEndOfDay(paid(o, calc, points: 100));
      await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders)
          .put(past.id, past);

      final half = past.totalPrice / 2;
      await RefundService.processRefund(
        order: past,
        refundResult: PartialRefundResult(
          itemsToRefund: {past.items.first: 1},
          reason: 'test',
          totalRefundAmount: half,
          itemsToRestock: const {},
        ),
      );

      expect(
          Hive.box<Customer>(HiveBoxNames.customer).get('c1')!.loyaltyPoints,
          50,
          reason: 'half the bill refunded → half of the 100 points back');
    });
  });
}
