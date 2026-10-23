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
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
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

/// Phase 1 safety checkpoint — NEW orders of the new types, end to end:
/// sell through the real plan (stamped lines), then void / cancel / refund,
/// and every unit comes back exactly once, to where it was taken from.
///
/// Stock: bun 10, cheese 10. Recipe for toOrder and hybrid: 1 bun + 2 cheese.
/// hybrid has 2 prepared; cake (made in advance, no recipe use) has 4.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase1_checkpoint_');
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

    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    Future<void> put(Items i) => items.put(i.id, i);
    await put(Items(id: 'bun', name: 'bun', productType: 'rawMaterial',
        trackInventory: true, stockQuantity: 10));
    await put(Items(id: 'cheese', name: 'cheese', productType: 'rawMaterial',
        trackInventory: true, stockQuantity: 10));
    await put(Items(id: 'toOrder', name: 'toOrder',
        productType: ProductType.finishedGood,
        prepMode: ProductType.madeToOrder));
    await put(Items(id: 'hybrid', name: 'hybrid',
        productType: ProductType.finishedGood,
        prepMode: ProductType.madeInAdvance, makeFreshWhenOut: true,
        trackInventory: true, stockQuantity: 2));
    await put(Items(id: 'cake', name: 'cake',
        productType: ProductType.finishedGood,
        prepMode: ProductType.madeInAdvance,
        trackInventory: true, stockQuantity: 4));
    await put(Items(id: 'coke', name: 'coke',
        productType: ProductType.tradeItem,
        trackInventory: true, stockQuantity: 10));
    final recipes = Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes);
    for (final dish in ['toOrder', 'hybrid']) {
      await recipes.put('r-$dish',
          RecipeModel(id: 'r-$dish', itemId: dish, ingredients: [
            RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
            RecipeIngredientModel(ingredientItemId: 'cheese', quantity: 2),
          ]));
    }
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  List<double> all() =>
      ['bun', 'cheese', 'hybrid', 'cake', 'coke'].map(stock).toList();
  CartItem line(String id, int qty) => makeCartItem(
      id: 'line-$id', productId: id, title: id, price: 10, quantity: qty);

  /// A new order, sold through the real plan: its saved (stamped) lines.
  Future<List<CartItem>> sell(List<CartItem> lines) async {
    final plan = await InventoryService.planSale(lines);
    await InventoryService.applyPlannedUnits(plan.units);
    return plan.lines;
  }

  /// The Active Orders / EOD void of [lines] (one unserved KOT).
  Future<List<CartItem>> voidOrder(List<CartItem> lines) async {
    final plan = KotLayout.voidPlan(
      items: lines,
      kotNumbers: [1],
      kotBoundaries: [lines.length],
      kotStatuses: {1: 'Cooking'},
      orderStatus: 'Cooking',
    );
    await InventoryService.restoreLines(plan.restores);
    return plan.recordItems;
  }

  PastOrderModel past(List<CartItem> items, {required String status}) =>
      PastOrderModel(
        id: 'o1',
        customerName: '',
        totalPrice: 100,
        items: items,
        orderAt: DateTime.now(),
        orderType: 'Dine In',
        paymentmode: 'Cash',
        orderStatus: status,
        kotNumbers: [1],
        kotBoundaries: [items.length],
      );

  Future<PastOrderModel> refundAll(PastOrderModel order) async {
    await pastOrderStore.addOrder(order);
    final grouped = {for (final i in order.items) i: i.quantity};
    return RefundService.processRefund(
      order: order,
      refundResult: PartialRefundResult(
        itemsToRefund: grouped,
        reason: 'test',
        totalRefundAmount: 100,
        itemsToRestock: grouped,
      ),
    );
  }

  test('check 1+2: each type sells from the right place; the hybrid uses '
      'prepared stock first and makes only the shortage', () async {
    await sell([
      line('toOrder', 1), // 1 bun, 2 cheese
      line('hybrid', 5), // 2 prepared + 3 fresh: 3 bun, 6 cheese
      line('cake', 3), // own stock
      line('coke', 4), // own stock
    ]);
    expect(all(), [6, 2, 0, 1, 6]);
  });

  test('check 3: void of a new order restores everything once; a refund of '
      'the voided order restores nothing more', () async {
    final sold = await sell(
        [line('toOrder', 1), line('hybrid', 5), line('cake', 3), line('coke', 4)]);
    final record = await voidOrder(sold);
    expect(all(), [10, 10, 2, 4, 10], reason: 'back where it was taken');

    await refundAll(past(record, status: 'VOIDED'));
    expect(all(), [10, 10, 2, 4, 10], reason: 'no duplicate restoration');
  });

  test('check 3: refunding a completed new order restores once; a second '
      'refund is capped', () async {
    final sold = await sell([line('hybrid', 5), line('coke', 4)]);
    final refunded = await refundAll(past(sold, status: 'COMPLETED'));
    expect(all(), [10, 10, 2, 4, 10]);

    // A second full refund request of the same record: nothing left.
    await RefundService.processRefund(
      order: refunded,
      refundResult: PartialRefundResult(
        itemsToRefund: {},
        reason: 'again',
        totalRefundAmount: 0,
        itemsToRestock: {for (final i in refunded.items) i: i.quantity},
      ),
    );
    expect(all(), [10, 10, 2, 4, 10]);
  });

  test('check 3: a partial cancel then a void of the rest restores each '
      'unit once — fresh part first', () async {
    final sold = await sell([line('hybrid', 5)]); // 2 prepared + 3 fresh
    final layout = KotLayout.removeQuantity(
      items: sold,
      kotNumbers: [1],
      kotBoundaries: [1],
      kotStatuses: {1: 'Cooking'},
      lineId: 'line-hybrid',
      qty: 2,
    );
    await InventoryService.restoreLines([(line: sold.single, qty: 2)]);
    expect([stock('bun'), stock('cheese'), stock('hybrid')], [9, 8, 0],
        reason: 'the 2 cancelled were fresh: 2 buns, 4 cheese back');

    await voidOrder(layout.items); // the remaining 3: 1 fresh + 2 prepared
    expect([stock('bun'), stock('cheese'), stock('hybrid')], [10, 10, 2]);
  });
}
