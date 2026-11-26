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
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Phase 1.2 — one sale decision for Finished items by preparation mode,
/// plus Trade Items. Ingredients: bun (10), cheese (10). Recipe per dish:
/// 1 bun + 2 cheese → "can make" 5.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Items finished(String id,
          {required String prep,
          bool tracked = false,
          double stock = 0,
          bool makeFresh = false}) =>
      Items(
        id: id,
        name: id,
        productType: ProductType.finishedGood,
        prepMode: prep,
        makeFreshWhenOut: makeFresh,
        trackInventory: tracked,
        stockQuantity: stock,
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finished_prep_');
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
    await put(Items(id: 'bun', name: 'bun', productType: 'rawMaterial',
        trackInventory: true, stockQuantity: 10));
    await put(Items(id: 'cheese', name: 'cheese', productType: 'rawMaterial',
        trackInventory: true, stockQuantity: 10));
    await put(finished('toOrder', prep: ProductType.madeToOrder));
    await put(finished('toOrderNoRecipe', prep: ProductType.madeToOrder));
    await put(finished('cake',
        prep: ProductType.madeInAdvance, tracked: true, stock: 4));
    await put(finished('hybrid',
        prep: ProductType.madeInAdvance,
        tracked: true,
        stock: 2,
        makeFresh: true));
    await put(finished('hybridNoRecipe',
        prep: ProductType.madeInAdvance,
        tracked: true,
        stock: 2,
        makeFresh: true));
    await put(Items(id: 'coke', name: 'coke',
        productType: ProductType.tradeItem,
        trackInventory: true, stockQuantity: 10));

    final recipes = Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes);
    for (final dish in ['toOrder', 'cake', 'hybrid']) {
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
  CartItem line(String id, int qty) => makeCartItem(
      id: 'line-$id', productId: id, title: id, price: 10, quantity: qty);
  Items item(String id) => itemStore.getItemById(id)!;
  List<StockMovementModel> rows(String id) =>
      StockMovementRepository().movementsForItem(id);

  group('sale deduction', () {
    test('made to order, with recipe: ingredients only', () async {
      await InventoryService.deductStockForOrder([line('toOrder', 2)]);
      expect([stock('bun'), stock('cheese')], [8, 6]);
      expect(rows('bun').single.reason, 'Sale (recipe: toOrder)');
    });

    test('made to order, no recipe: nothing moves', () async {
      await InventoryService.deductStockForOrder([line('toOrderNoRecipe', 2)]);
      expect([stock('bun'), stock('cheese')], [10, 10]);
    });

    test('made in advance: own stock only — ingredients are NOT deducted '
        'again', () async {
      await InventoryService.deductStockForOrder([line('cake', 3)]);
      expect(stock('cake'), 1);
      expect([stock('bun'), stock('cheese')], [10, 10]);
      expect(rows('bun'), isEmpty);
    });

    test('hybrid: prepared stock first, the shortfall made fresh', () async {
      await InventoryService.deductStockForOrder([line('hybrid', 5)]);
      expect(stock('hybrid'), 0, reason: '2 from prepared stock');
      expect([stock('bun'), stock('cheese')], [7, 4],
          reason: '3 made fresh: 3 buns, 6 cheese');
      expect(rows('hybrid').single.reason, 'Sale');
      expect(rows('bun').single.reason, 'Sale (recipe: hybrid)');
    });

    test('hybrid with enough prepared stock makes nothing fresh', () async {
      await InventoryService.deductStockForOrder([line('hybrid', 2)]);
      expect(stock('hybrid'), 0);
      expect([stock('bun'), stock('cheese')], [10, 10]);
    });

    test('hybrid with no recipe falls back to prepared stock only', () async {
      await InventoryService.deductStockForOrder([line('hybridNoRecipe', 3)]);
      expect(stock('hybridNoRecipe'), -1);
      expect([stock('bun'), stock('cheese')], [10, 10]);
    });

    test('Trade Item: own stock', () async {
      await InventoryService.deductStockForOrder([line('coke', 4)]);
      expect(stock('coke'), 6);
    });

    test('the plan is the single decision: units per mode', () async {
      final units = await InventoryService.planSaleDeductions(
          [line('cake', 1), line('toOrder', 1), line('hybrid', 3)]);
      String key(SaleStockUnit u) => '${u.lineId}:${u.item.id}:${u.qty}';
      expect(units.map(key), [
        'line-cake:cake:1.0',
        'line-toOrder:bun:1.0',
        'line-toOrder:cheese:2.0',
        'line-hybrid:hybrid:2.0',
        'line-hybrid:bun:1.0',
        'line-hybrid:cheese:2.0',
      ]);
    });
  });

  group('availability', () {
    test('made to order with recipe: can make', () {
      expect(InventoryService.effectiveAvailableStock(item('toOrder')), 5);
      expect(InventoryService.isStockGoverned(item('toOrder')), isTrue);
    });

    test('made to order, no recipe: not limited by stock (sells freely)', () {
      final i = item('toOrderNoRecipe');
      final available = InventoryService.effectiveAvailableStock(i);
      expect(available, double.infinity);
      expect(
          InventoryService.posStatusFromAvailable(
              available: available, allowOrderWhenOutOfStock: false),
          PosStockStatus.notTracked);
      expect(InventoryService.isInStock(i), isTrue);
    });

    test('made in advance: its own stock', () {
      expect(InventoryService.effectiveAvailableStock(item('cake')), 4);
    });

    test('hybrid: prepared + can make', () {
      final i = item('hybrid');
      expect(InventoryService.effectiveAvailableStock(i), 7);
      expect(InventoryService.isStockGoverned(i), isTrue);
      expect(InventoryService.usesDerivedAvailability(i), isTrue);
    });

    test('hybrid with no recipe: prepared stock only', () {
      expect(InventoryService.effectiveAvailableStock(item('hybridNoRecipe')),
          2);
      expect(InventoryService.isInStock(item('hybridNoRecipe')), isTrue);
    });

    test('Trade Item: its own stock', () {
      expect(InventoryService.effectiveAvailableStock(item('coke')), 10);
      expect(InventoryService.usesDerivedAvailability(item('coke')), isFalse);
    });
  });
}
