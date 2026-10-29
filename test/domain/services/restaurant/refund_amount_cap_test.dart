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
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';
import '../../../helpers/open_session_fixture.dart';

/// BLK-06: a restaurant refund never pays back more than is still refundable
/// (what was actually paid minus earlier refunds), never refunds more units
/// than are left, and a rejected refund changes nothing — order, stock,
/// refund history or loyalty points.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('refund_amount_cap_');
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
    await openRestaurantSessionForTest(); // refunds need an open session (SB-2b-M8)

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
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()));

    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'soup', Items(id: 'soup', name: 'Soup', trackInventory: true, stockQuantity: 10));
    await itemStore.loadItems();
    await Hive.box<Customer>(HiveBoxNames.customer)
        .put('c1', Customer(
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

  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('soup')!.stockQuantity;
  int points() =>
      Hive.box<Customer>(HiveBoxNames.customer).get('c1')!.loyaltyPoints;
  PastOrderModel saved() =>
      Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).get('o1')!;

  CartItem line(String id, int qty, {double price = 100, double? taxRate}) =>
      makeCartItem(
          id: id,
          productId: 'soup',
          title: 'Soup',
          price: price,
          quantity: qty,
          taxRate: taxRate);

  /// Saves and returns an order paid [paid] for [items].
  Future<PastOrderModel> order(
    List<CartItem> items, {
    required double paid,
    int? pointsUsed,
    bool? taxEnabled,
  }) async {
    final o = PastOrderModel(
      id: 'o1',
      customerName: 'Asha',
      customerId: 'c1',
      totalPrice: paid,
      items: items,
      orderAt: DateTime.now(),
      orderType: 'Dine In',
      paymentmode: 'Cash',
      orderStatus: 'COMPLETED',
      kotNumbers: [1],
      kotBoundaries: [1],
      loyaltyPointsUsed: pointsUsed,
      taxEnabled: taxEnabled,
    );
    await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders)
        .put(o.id, o);
    return o;
  }

  PartialRefundResult refund(CartItem item, int qty, double amount,
          {bool restock = true}) =>
      PartialRefundResult(
        itemsToRefund: {item: qty},
        reason: 'test',
        totalRefundAmount: amount,
        itemsToRestock: restock ? {item: qty} : {},
      );

  /// Everything a rejected refund must leave as it was.
  Map<String, Object?> state() => {
        'refundAmount': saved().refundAmount,
        'status': saved().orderStatus,
        'refunded': [for (final i in saved().items) i.refundedQuantity],
        'restocked': [for (final i in saved().items) i.restockedQuantity],
        'reason': saved().refundReason,
        'stock': stock(),
        'points': points(),
      };

  Matcher rejected(String text) =>
      throwsA(predicate((e) => e.toString().contains(text), 'mentions "$text"'));

  group('the amount cap', () {
    test('a refund above what is left is rejected and changes nothing',
        () async {
      final o = await order([line('l1', 2)], paid: 200, pointsUsed: 50);
      final before = state();

      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 1, 250)),
        rejected('still refundable'),
      );
      expect(state(), before);
    });

    test('repeated partial refunds stop at what was paid', () async {
      var o = await order([line('l1', 2)], paid: 200);

      o = await RefundService.processRefund(
          order: o, refundResult: refund(o.items.first, 1, 100));
      expect(o.refundAmount, 100);
      expect(o.orderStatus, 'PARTIALLY_REFUNDED');

      // The second unit is worth 100 but only 100 is left; 120 is refused.
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 1, 120)),
        rejected('still refundable'),
      );
      expect(saved().refundAmount, 100);

      o = await RefundService.processRefund(
          order: saved(), refundResult: refund(saved().items.first, 1, 100));
      expect(o.refundAmount, 200);
      expect(o.orderStatus, 'FULLY_REFUNDED');
      expect(RefundService.getRemainingRefundableAmount(o), 0);
    });

    test('a negative amount is rejected', () async {
      final o = await order([line('l1', 1)], paid: 100);
      final before = state();
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 1, -50)),
        rejected('cannot be negative'),
      );
      expect(state(), before);
    });
  });

  group('rounding tolerance', () {
    test('a sub-paisa overshoot is accepted and saved as exactly what was left',
        () async {
      final o = await order([line('l1', 3)], paid: 100);

      final after = await RefundService.processRefund(
          order: o, refundResult: refund(o.items.first, 3, 100.005));

      expect(after.refundAmount, 100, reason: 'capped, never above paid');
      expect(saved().refundAmount, 100);
    });

    test('an overshoot beyond the tolerance is rejected', () async {
      final o = await order([line('l1', 3)], paid: 100);
      final before = state();
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 3, 100.02)),
        rejected('still refundable'),
      );
      expect(state(), before);
    });
  });

  group('quantities', () {
    test('more units than are left is rejected, nothing written', () async {
      final o = await order([line('l1', 2)], paid: 200);
      final before = state();

      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 3, 150)),
        rejected('more than what is left'),
      );
      expect(state(), before, reason: 'stock not restored, nothing recorded');
    });

    test('units split across two KOT lines are counted together', () async {
      // Same product on KOT 1 and KOT 2: 2 + 1 units, one already refunded.
      final o = await order([
        line('k1', 2),
        line('k2', 1).copyWith(refundedQuantity: 1),
      ], paid: 300);
      final before = state();

      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 3, 150)),
        rejected('more than what is left'),
      );
      expect(state(), before);

      final ok = await RefundService.processRefund(
          order: o, refundResult: refund(o.items.first, 2, 200));
      expect([for (final i in ok.items) i.refundedQuantity], [2, 1]);
    });

    test('a negative quantity is rejected', () async {
      final o = await order([line('l1', 2)], paid: 200);
      final before = state();
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, -1, 50)),
        rejected('negative'),
      );
      expect(state(), before);
    });
  });

  group('loyalty points', () {
    test('points come back in proportion to the capped amount', () async {
      // Four 100 lines; 300 of the value was paid in points, 100 in money.
      final o = await order([line('l1', 4)], paid: 100, pointsUsed: 300);
      final amount = RefundService.partialRefundAmount(
          selectedValue: 200, allItemsValue: 400, paidTotal: 100, remaining: 100);
      expect(amount, 50, reason: 'half the goods = half of what was paid');

      await RefundService.processRefund(
          order: o, refundResult: refund(o.items.first, 2, amount));

      expect(saved().refundAmount, 50);
      expect(points(), 150);
    });

    test('a rejected over-refund restores no points', () async {
      final o = await order([line('l1', 4)], paid: 100, pointsUsed: 300);
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(o.items.first, 2, 200)),
        rejected('still refundable'),
      );
      expect(points(), 0);
    });

    test('refunding everything never restores more points than were used',
        () async {
      var o = await order([line('l1', 4)], paid: 100, pointsUsed: 300);
      for (var i = 0; i < 4; i++) {
        o = await RefundService.processRefund(
            order: saved(), refundResult: refund(saved().items.first, 1, 25));
      }
      expect(o.orderStatus, 'FULLY_REFUNDED');
      expect(points(), lessThanOrEqualTo(300));
    });
  });

  group('the dialog amount (partialRefundAmount)', () {
    test('tax switched off: one of two items refunds what was paid for it',
        () {
      // Lines carry 5% tax, but the order was settled with tax off: 2 x 100.
      // The dialog values each line at 105.
      expect(
        RefundService.partialRefundAmount(
            selectedValue: 105, allItemsValue: 210, paidTotal: 200, remaining: 200),
        closeTo(100, 1e-9),
      );
    });

    test('a service charge leaves item amounts exactly as before', () {
      // 1000 of items + 100 service charge paid; one 250 item.
      expect(
        RefundService.partialRefundAmount(
            selectedValue: 250, allItemsValue: 1000, paidTotal: 1100, remaining: 1100),
        250,
        reason: 'not scaled up; the charge comes back with the last items',
      );
    });

    test('an ordinary order is unchanged', () {
      expect(
        RefundService.partialRefundAmount(
            selectedValue: 105, allItemsValue: 210, paidTotal: 210, remaining: 210),
        105,
      );
    });

    test('never more than is still refundable', () {
      expect(
        RefundService.partialRefundAmount(
            selectedValue: 300, allItemsValue: 400, paidTotal: 400, remaining: 120),
        120,
      );
    });

    test('tax-off order refunded through the service', () async {
      final o = await order([line('l1', 2, taxRate: 0.05)],
          paid: 200, taxEnabled: false);
      final amount = RefundService.partialRefundAmount(
          selectedValue: 105, allItemsValue: 210, paidTotal: 200, remaining: 200);

      final after = await RefundService.processRefund(
          order: o, refundResult: refund(o.items.first, 1, amount));
      expect(after.refundAmount, closeTo(100, 1e-9));
    });
  });

  // SB-2b-M8: a refund needs an open business session.
  group('open session', () {
    test('no session (day ended, not yet started): refused, nothing changes',
        () async {
      await Hive.box(HiveBoxNames.dayManagementBox).delete('currentSessionId');
      final o = await order([line('l1', 2)], paid: 200, pointsUsed: 50);
      final before = state();

      await expectLater(
        RefundService.processRefund(
            order: o, refundResult: refund(o.items.first, 1, 100)),
        rejected(RefundService.refundNeedsOpenSessionMessage),
      );
      expect(state(), before);
      expect(saved().refundEventsJson, isNull, reason: 'no refund recorded');
    });

    test('a closed session: refused, nothing changes', () async {
      await openRestaurantSessionForTest(sessionId: 'closed', closed: true);
      final o = await order([line('l1', 2)], paid: 200, pointsUsed: 50);
      final before = state();

      await expectLater(
        RefundService.processRefund(
            order: o, refundResult: refund(o.items.first, 1, 100)),
        rejected(RefundService.refundNeedsOpenSessionMessage),
      );
      expect(state(), before);
      expect(saved().refundEventsJson, isNull);
    });

    test('an open session: the refund goes through, still capped (SB-2a)',
        () async {
      await openRestaurantSessionForTest(sessionId: 'open');
      final o = await order([line('l1', 2)], paid: 200, pointsUsed: 50);

      await expectLater(
        RefundService.processRefund(
            order: o, refundResult: refund(o.items.first, 1, 250)),
        rejected('still refundable'),
      );

      final after = await RefundService.processRefund(
          order: saved(), refundResult: refund(saved().items.first, 1, 100));
      expect(after.refundAmount, 100);
      expect(stock(), 11, reason: 'restocked');
      expect(points(), 25, reason: 'half the points back');
      expect(RefundService.refundEventsOf(saved()).single.sessionId, 'open',
          reason: 'recorded in the open session (SB-2b)');
    });
  });
}
