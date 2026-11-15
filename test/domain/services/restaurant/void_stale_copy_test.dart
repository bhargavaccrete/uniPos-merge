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

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';
import '../../../helpers/sign_in_fixture.dart';

/// A past-order store whose saves fail the way the real one reports them.
class _FailingSaveStore extends PastOrderStore {
  _FailingSaveStore(super.repository);

  @override
  Future<bool> updateOrder(PastOrderModel updatedOrder) async => false;
}

/// Restaurant past-order void from a stale copy: the void is built from the
/// order as SAVED (one operation per order at a time, shared with refunds),
/// so it never writes back an older refund amount, refund history or
/// refunded/restocked quantities; refund notes are kept; a failed save is
/// never reported as success.
void main() {
  // BLK-14: refunds and voids check the role; sign in as admin.
  setUpAll(() => signInForTest());

  late Directory tempDir;

  Future<void> setUpStores({bool failingSave = false}) async {
    tempDir = await Directory.systemTemp.createTemp('void_stale_copy_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
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
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(() => failingSave
          ? _FailingSaveStore(locator<PastOrderRepository>())
          : PastOrderStore(locator<PastOrderRepository>()));

    await Hive.box<Items>(HiveBoxNames.restaurantItems).put('soup',
        Items(id: 'soup', name: 'Soup', trackInventory: true, stockQuantity: 10));
    await itemStore.loadItems();
    await Hive.box<Customer>(HiveBoxNames.customer).put(
        'c1',
        Customer(
            customerId: 'c1',
            name: 'Asha',
            loyaltyPoints: 0,
            createdAt: '2026-10-01T00:00:00.000'));
  }

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

  /// Saves and returns a ₹200 order of 2 soups, 40 points used.
  Future<PastOrderModel> order() async {
    final o = PastOrderModel(
      id: 'o1',
      customerName: 'Asha',
      customerId: 'c1',
      totalPrice: 200,
      items: [
        makeCartItem(id: 'l1', productId: 'soup', title: 'Soup', price: 100, quantity: 2),
      ],
      orderAt: DateTime.now(),
      orderType: 'Dine In',
      paymentmode: 'Cash',
      orderStatus: 'COMPLETED',
      kotNumbers: [1],
      kotBoundaries: [1],
      loyaltyPointsUsed: 40,
    );
    await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).put(o.id, o);
    return o;
  }

  PartialRefundResult refund(CartItem item, int qty, double amount,
          {String reason = 'Cold soup'}) =>
      PartialRefundResult(
        itemsToRefund: {item: qty},
        reason: reason,
        totalRefundAmount: amount,
        itemsToRestock: {item: qty},
      );

  Matcher refused(String text) =>
      throwsA(predicate((e) => e.toString().contains(text), 'mentions "$text"'));

  group('stale void', () {
    setUp(() => setUpStores());

    test('a void from a copy taken before a refund keeps that refund', () async {
      final stale = await order(); // the screen's copy: nothing refunded
      await RefundService.processRefund(
          order: stale, refundResult: refund(stale.items.first, 1, 150));

      final voided = await RefundService.voidOrder(order: stale, reason: 'Wrong bill');

      expect(voided.orderStatus, 'VOIDED');
      expect(saved().orderStatus, 'VOIDED');
      expect(saved().refundAmount, 150, reason: 'not reset to the stale 0');
      expect(RefundService.refundEventsOf(saved()).map((e) => e.amount), [150]);
      expect(saved().items.single.refundedQuantity, 1);
      expect(saved().items.single.restockedQuantity, 1);
      expect(stock(), 11, reason: 'void never moves stock');
      expect(points(), 30, reason: 'void never moves points');
    });

    test('a refund after that void cannot pay out or restock again', () async {
      final stale = await order();
      await RefundService.processRefund(
          order: stale, refundResult: refund(stale.items.first, 1, 150));
      await RefundService.voidOrder(order: stale, reason: 'Wrong bill');

      await expectLater(
        RefundService.processRefund(
            order: stale, refundResult: refund(stale.items.first, 2, 200)),
        refused('still refundable'),
      );
      expect(saved().refundAmount, 150);
      expect(stock(), 11, reason: 'no second restock');
      expect(points(), 30, reason: 'no second loyalty credit');
    });

    test('earlier refund notes are kept; the void is added as a line', () async {
      final o = await order();
      await RefundService.processRefund(
          order: o,
          refundResult: refund(o.items.first, 1, 100, reason: 'Cold soup'));

      await RefundService.voidOrder(order: o, reason: 'Wrong bill');

      final lines = saved().refundReason!.split('\n');
      expect(lines.any((l) => l.contains('Cold soup')), isTrue,
          reason: 'refund note survives');
      expect(lines.last, 'VOIDED: Wrong bill');
    });

    test('with no earlier notes the void text is exactly as before', () async {
      final o = await order();
      await RefundService.voidOrder(order: o, reason: '');
      expect(saved().refundReason, 'VOIDED: No reason provided');
    });

    test('a void and a refund started at once both keep their data', () async {
      final o = await order();

      await Future.wait([
        RefundService.processRefund(
            order: o, refundResult: refund(o.items.first, 1, 100)),
        RefundService.voidOrder(order: o, reason: 'Wrong bill'),
      ]);

      expect(saved().orderStatus, 'VOIDED');
      expect(saved().refundAmount, 100, reason: 'the refund is not lost');
      expect(RefundService.refundEventsOf(saved()), hasLength(1));
      expect(saved().items.single.refundedQuantity, 1);
      expect(stock(), 11);
      expect(points(), 20);
    });

    test('an order that is no longer saved is refused', () async {
      final o = await order();
      await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders)
          .delete(o.id);

      await expectLater(
        RefundService.voidOrder(order: o, reason: 'Wrong bill'),
        refused('could not be found'),
      );
      expect(
          Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders)
              .containsKey(o.id),
          isFalse,
          reason: 'nothing written back');
    });
  });

  group('failed save', () {
    setUp(() => setUpStores(failingSave: true));

    test('is never reported as voided; the record is unchanged', () async {
      final o = await order();
      final before = saved().toMap();

      await expectLater(
        RefundService.voidOrder(order: o, reason: 'Wrong bill'),
        refused('could not be saved'),
      );
      expect(saved().toMap(), before);
      expect(saved().orderStatus, 'COMPLETED');
    });
  });
}
