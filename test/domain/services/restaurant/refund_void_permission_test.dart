import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
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
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/sign_in_fixture.dart';
import '../../../helpers/test_helpers.dart';

/// BLK-14: a Restaurant refund or void moves money, so the service checks the
/// role before it writes anything. Admin, Manager and Cashier may; a Waiter
/// (orders only) may not, whatever screen the call comes from — and a refused
/// call changes nothing.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('refund_void_perm_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    // canAccess reads the business mode for a Cashier.
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');
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
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()));

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

    // A ₹200 order of 2 soups, 40 points used.
    await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).put(
      'o1',
      PastOrderModel(
        id: 'o1',
        customerName: 'Asha',
        customerId: 'c1',
        totalPrice: 200,
        items: [
          makeCartItem(
              id: 'l1', productId: 'soup', title: 'Soup', price: 100, quantity: 2),
        ],
        orderAt: DateTime.now(),
        orderType: 'Dine In',
        paymentmode: 'Cash',
        orderStatus: 'COMPLETED',
        kotNumbers: [1],
        kotBoundaries: [1],
        loyaltyPointsUsed: 40,
      ),
    );
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  PastOrderModel saved() =>
      Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).get('o1')!;

  /// Everything a refund or void could move.
  Map<String, Object?> state() => {
        'order': saved().toMap().toString(),
        'stock':
            Hive.box<Items>(HiveBoxNames.restaurantItems).get('soup')!.stockQuantity,
        'points':
            Hive.box<Customer>(HiveBoxNames.customer).get('c1')!.loyaltyPoints,
      };

  Future<PastOrderModel> refund() {
    final o = saved();
    return RefundService.processRefund(
      order: o,
      refundResult: PartialRefundResult(
        itemsToRefund: {o.items.first: 1},
        reason: 'test',
        totalRefundAmount: 100,
        itemsToRestock: {o.items.first: 1},
      ),
    );
  }

  Future<PastOrderModel> voidIt() =>
      RefundService.voidOrder(order: saved(), reason: 'Wrong bill');

  Matcher refused(String text) =>
      throwsA(predicate((e) => e.toString().contains(text), 'says "$text"'));

  group('a Waiter', () {
    setUp(() => signInForTest(role: 'Waiter'));

    test('cannot refund — nothing changes', () async {
      final before = state();
      await expectLater(
          refund(), refused(RefundService.refundNotAllowedMessage));
      expect(state(), before);
    });

    test('cannot void — nothing changes', () async {
      final before = state();
      await expectLater(voidIt(), refused(RefundService.voidNotAllowedMessage));
      expect(state(), before);
      expect(saved().orderStatus, 'COMPLETED');
    });
  });

  for (final role in const [null, 'Manager', 'Cashier']) {
    group(role ?? 'Admin', () {
      setUp(() => signInForTest(role: role));

      test('can refund', () async {
        final after = await refund();
        expect(after.refundAmount, 100);
        expect(saved().refundAmount, 100);
      });

      test('can void', () async {
        await voidIt();
        expect(saved().orderStatus, 'VOIDED');
      });
    });
  }

  group('signed out', () {
    setUp(() async {
      await signInForTest();
      await RestaurantSession.clearSession();
    });

    test('cannot refund or void — nothing changes', () async {
      final before = state();
      await expectLater(
          refund(), refused(RefundService.refundNotAllowedMessage));
      await expectLater(voidIt(), refused(RefundService.voidNotAllowedMessage));
      expect(state(), before);
    });
  });
}
