import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/services/restaurant/kot_layout.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Stock behaviour of the two paths that produce a 'VOIDED' order, followed
/// by a refund. Characterises F2 (Phase 0 plan): no production code changed.
///
/// - Active Orders void (activeorder.dart:150-221) restores unserved KOT
///   lines itself, via InventoryService.restoreStockForRefund.
/// - Past-order void (RefundService.voidOrder, refund_service.dart:200-229)
///   restores nothing.
/// Both records then reach RefundService.processRefund, which restocks every
/// ticked line without knowing which path produced the record.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('refund_after_void_');
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
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    locator
      ..registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService())..licenseBypassed = true)
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()));

    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    await box.put(
        'coke',
        Items(
            id: 'coke', name: 'Coke', trackInventory: true, stockQuantity: 8));
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('coke')!.stockQuantity;

  CartItem line() => makeCartItem(
      id: 'l1', productId: 'coke', title: 'Coke', price: 40, quantity: 2);

  PastOrderModel record({required String status}) => PastOrderModel(
        id: 'o1',
        customerName: '',
        totalPrice: 80,
        items: [line()],
        orderAt: DateTime.now(),
        orderType: 'Dine In',
        paymentmode: 'Cash',
        orderStatus: status,
        kotNumbers: [1],
        kotBoundaries: [1],
      );

  PartialRefundResult refundWithRestock() => PartialRefundResult(
        itemsToRefund: {line(): 2},
        reason: 'Customer complaint',
        totalRefundAmount: 80,
        itemsToRestock: {line(): 2},
      );

  // Sale already deducted 2 → stock 8 at setUp.

  test(
      'Active Orders paid void then refund restores the unserved lines once',
      () async {
    // What the Active Orders void does (activeorder.dart / endday.dart):
    // plan per unserved line, restore, and keep those lines marked
    // restocked on the VOIDED record (Phase 1.3 — closes F2).
    final plan = KotLayout.voidPlan(
      items: [line()],
      kotNumbers: [1],
      kotBoundaries: [1],
      kotStatuses: {1: 'Cooking'},
      orderStatus: 'Cooking',
    );
    await InventoryService.restoreLines(plan.restores);
    expect(stock(), 10, reason: 'the void restored the 2 unserved Cokes');

    final voided =
        record(status: 'VOIDED').copyWith(items: plan.recordItems);
    await pastOrderStore.addOrder(voided);
    await RefundService.processRefund(
        order: voided, refundResult: refundWithRestock());

    expect(stock(), 10, reason: 'stock must come back once, not twice');
  });

  test('past-order void restores nothing; a refund with restock restores once',
      () async {
    final completed = record(status: 'COMPLETED');
    await pastOrderStore.addOrder(completed);
    final voided =
        await RefundService.voidOrder(order: completed, reason: 'Wrong bill');
    expect(stock(), 8, reason: 'voidOrder never moves stock');

    await RefundService.processRefund(
        order: voided, refundResult: refundWithRestock());

    expect(stock(), 10);
  });

  test('refund of a completed order still restocks ticked lines', () async {
    final completed = record(status: 'COMPLETED');
    await pastOrderStore.addOrder(completed);

    final refunded = await RefundService.processRefund(
        order: completed, refundResult: refundWithRestock());

    expect(stock(), 10);
    expect(refunded.refundAmount, 80);
  });
}
