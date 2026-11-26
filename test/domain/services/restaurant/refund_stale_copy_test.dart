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

/// A past-order store whose saves fail the way the real one reports them:
/// `updateOrder` catches the error and returns false.
class _FailingSaveStore extends PastOrderStore {
  _FailingSaveStore(super.repository);

  @override
  Future<bool> updateOrder(PastOrderModel updatedOrder) async => false;
}

/// L1 / L1b: a refund started from an out-of-date copy of the order (a screen
/// opened from a list loaded earlier, a second tap, two calls at once) is
/// checked and saved against the order as SAVED, one refund per order at a
/// time; a failed save stops the refund before stock or points change.
void main() {
  // BLK-14: refunds and voids check the role; sign in as admin.
  setUpAll(() => signInForTest());

  late Directory tempDir;

  Future<void> setUpStores({bool failingSave = false}) async {
    tempDir = await Directory.systemTemp.createTemp('refund_stale_copy_');
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

  PartialRefundResult refund(CartItem item, int qty, double amount) =>
      PartialRefundResult(
        itemsToRefund: {item: qty},
        reason: 'test',
        totalRefundAmount: amount,
        itemsToRestock: {item: qty},
      );

  Map<String, Object?> state() => {
        'refundAmount': saved().refundAmount,
        'status': saved().orderStatus,
        'refunded': [for (final i in saved().items) i.refundedQuantity],
        'restocked': [for (final i in saved().items) i.restockedQuantity],
        'events': saved().refundEventsJson,
        'stock': stock(),
        'points': points(),
      };

  Matcher refused(String text) =>
      throwsA(predicate((e) => e.toString().contains(text), 'mentions "$text"'));

  group('stale copies', () {
    setUp(() => setUpStores());

    test('a stale over-refund is refused and nothing changes', () async {
      final stale = await order(); // the screen's copy: ₹200 left
      await RefundService.processRefund(
          order: stale, refundResult: refund(stale.items.first, 1, 150));
      final before = state(); // saved: ₹150 refunded, ₹50 left

      await expectLater(
        RefundService.processRefund(
            order: stale, refundResult: refund(stale.items.first, 1, 150)),
        refused('still refundable'),
      );
      expect(state(), before,
          reason: 'first refund not overwritten; no second restock or points');
    });

    test('a stale copy within what is left adds on top of the saved refund',
        () async {
      final stale = await order();
      await RefundService.processRefund(
          order: stale, refundResult: refund(stale.items.first, 1, 150));

      final after = await RefundService.processRefund(
          order: stale, refundResult: refund(stale.items.first, 1, 50));

      expect(after.refundAmount, 200, reason: '150 + 50, nothing lost');
      expect(saved().refundAmount, 200);
      expect(saved().orderStatus, 'FULLY_REFUNDED');
      expect(saved().items.single.refundedQuantity, 2);
      expect(RefundService.refundEventsOf(saved()).map((e) => e.amount),
          [150, 50],
          reason: 'both refunds kept in the history');
      expect(stock(), 12, reason: 'each unit restocked once');
    });

    test('excess quantity from a stale copy is refused', () async {
      final stale = await order(); // shows 2 units refundable
      await RefundService.processRefund(
          order: stale, refundResult: refund(stale.items.first, 1, 100));
      final before = state(); // 1 unit left

      await expectLater(
        RefundService.processRefund(
            order: stale, refundResult: refund(stale.items.first, 2, 100)),
        refused('more than what is left'),
      );
      expect(state(), before);
    });

    test('two refunds started at once: exactly one succeeds', () async {
      final o = await order();

      final results = await Future.wait([
        RefundService.processRefund(
                order: o, refundResult: refund(o.items.first, 1, 150))
            .then<Object>((v) => v, onError: (Object e) => e),
        RefundService.processRefund(
                order: o, refundResult: refund(o.items.first, 1, 150))
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);

      expect(results.whereType<PastOrderModel>(), hasLength(1));
      expect(results.whereType<Exception>(), hasLength(1));
      expect(results.whereType<Exception>().single.toString(),
          contains('still refundable'));
      expect(saved().refundAmount, 150);
      expect(RefundService.refundEventsOf(saved()), hasLength(1));
      expect(stock(), 11, reason: 'restocked once');
      expect(points(), 30, reason: '40 × 150/200, credited once');
    });

    test('an order that is no longer saved is refused', () async {
      final o = await order();
      await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders)
          .delete(o.id);

      await expectLater(
        RefundService.processRefund(
            order: o, refundResult: refund(o.items.first, 1, 100)),
        refused('could not be found'),
      );
      expect(stock(), 10);
      expect(points(), 0);
    });
  });

  group('failed order save (L1b)', () {
    setUp(() => setUpStores(failingSave: true));

    test('stops before stock or loyalty points change', () async {
      final o = await order();
      final before = state();

      await expectLater(
        RefundService.processRefund(
            order: o, refundResult: refund(o.items.first, 1, 100)),
        refused('could not be saved'),
      );
      expect(state(), before, reason: 'order, stock and points unchanged');
    });
  });
}
