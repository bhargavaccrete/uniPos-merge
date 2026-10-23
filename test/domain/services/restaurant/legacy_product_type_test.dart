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
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Phase 1.0 — how items stored with the PRE-Phase-1 product-type strings
/// sell. Raw strings on purpose: these are the values already on devices and
/// in backups, and they must keep selling exactly like this after Phase 1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('legacy_product_type_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()));

    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    Future<void> put(Items i) => items.put(i.id, i);
    await put(Items(id: 'bun', name: 'Bun', productType: 'rawMaterial',
        trackInventory: true, stockQuantity: 10));
    await put(Items(id: 'sauce', name: 'Sauce', productType: 'semiFinished',
        trackInventory: true, stockQuantity: 10));
    await put(Items(id: 'burger', name: 'Burger', productType: 'recipeBased'));
    await put(Items(id: 'coke', name: 'Coke', productType: 'finishedGood',
        trackInventory: true, stockQuantity: 10));
    await put(Items(id: 'tea', name: 'Tea', trackInventory: true,
        stockQuantity: 10)); // productType null (onboarding / import)
    await put(Items(id: 'thali', name: 'Thali', productType: 'finishedGood'));
    await Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).put(
        'r-burger',
        RecipeModel(id: 'r-burger', itemId: 'burger', ingredients: [
          RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'sauce', quantity: 0.5),
        ]));
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  CartItem line(String id, int qty) => makeCartItem(
      id: 'line-$id', productId: id, title: id, price: 10, quantity: qty);
  Items item(String id) => itemStore.getItemById(id)!;

  test('legacy "recipeBased" sale cascades into its ingredients', () async {
    await InventoryService.deductStockForOrder([line('burger', 2)]);
    expect([stock('bun'), stock('sauce')], [8, 9]);
    expect(stock('burger'), 0);
  });

  test('legacy "recipeBased" availability is "can make" from ingredients', () {
    expect(InventoryService.effectiveAvailableStock(item('burger')), 10);
    expect(InventoryService.isStockGoverned(item('burger')), isTrue);
  });

  test('legacy "finishedGood" (tracked) sells its own stock', () async {
    await InventoryService.deductStockForOrder([line('coke', 3)]);
    expect(stock('coke'), 7);
  });

  test('null product type sells like "finishedGood"', () async {
    await InventoryService.deductStockForOrder([line('tea', 2)]);
    expect(stock('tea'), 8);
  });

  test('legacy untracked "finishedGood" moves nothing', () async {
    await InventoryService.deductStockForOrder([line('thali', 1)]);
    expect(stock('thali'), 0);
    expect(InventoryService.isStockGoverned(item('thali')), isFalse);
  });

  test('legacy "semiFinished" sold at the POS uses its own stock, not its '
      'recipe', () async {
    await InventoryService.deductStockForOrder([line('sauce', 2)]);
    expect(stock('sauce'), 8);
  });

  test('restoring a legacy "recipeBased" line puts its ingredients back',
      () async {
    await InventoryService.deductStockForOrder([line('burger', 2)]);
    await InventoryService.restoreStockForOrder([line('burger', 2)]);
    expect([stock('bun'), stock('sauce')], [10, 10]);
  });

  test('legacy model getters', () {
    expect(item('burger').isRecipeBased, isTrue);
    expect(item('burger').hasRecipe, isTrue);
    expect(item('coke').isFinishedGood, isTrue);
    expect(item('tea').isFinishedGood, isTrue);
    expect(item('coke').hasRecipe, isFalse);
    expect(item('sauce').hasRecipe, isTrue);
    expect(item('bun').sellsAtPos, isFalse);
    expect(item('coke').sellsAtPos, isTrue);
  });
}
