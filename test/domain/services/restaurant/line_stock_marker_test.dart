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
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/services/restaurant/line_stock.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Phase 1.3 — the per-line stock marker: what a sale took (prepared stock
/// vs made fresh) is recorded on the order line, and every restore reads
/// that record instead of the item's CURRENT type, capped by what is still
/// restorable (restockedQuantity).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CartItem stamped(int qty, {int? own, int? fresh, int? restocked}) =>
      makeCartItem(id: 'l', productId: 'p', title: 'P', price: 10,
              quantity: qty)
          .copyWith(
              ownStockQty: own, freshQty: fresh, restockedQuantity: restocked);

  group('LineStock (pure)', () {
    test('take: fresh first, then prepared stock', () {
      final r = LineStock.take(stamped(5, own: 2, fresh: 3), 4);
      expect([r.fromFresh, r.fromOwn, r.counted], [3, 1, 4]);
      expect(r.isLegacy, isFalse);
    });

    test('take is capped by what is still restorable', () {
      final r = LineStock.take(stamped(5, own: 2, fresh: 3, restocked: 4), 3);
      expect([r.fromFresh, r.fromOwn, r.counted], [0, 1, 1]);
    });

    test('a fully restocked line returns nothing', () {
      final r = LineStock.take(stamped(2, own: 2, fresh: 0, restocked: 2), 2);
      expect([r.fromFresh, r.fromOwn, r.counted], [0, 0, 0]);
    });

    test('units that moved no stock return nothing but still count', () {
      final r = LineStock.take(stamped(3, own: 0, fresh: 0), 2);
      expect([r.fromFresh, r.fromOwn, r.counted], [0, 0, 2]);
    });

    test('an unstamped (pre-Phase 1) line is legacy', () {
      final r = LineStock.take(stamped(3), 2);
      expect(r.isLegacy, isTrue);
      expect(r.counted, 2);
    });

    test('reduced: quantity and stamps shrink, fresh first', () {
      final line = LineStock.reduced(stamped(5, own: 2, fresh: 3), 4);
      expect([line.quantity, line.freshQty, line.ownStockQty], [1, 0, 1]);
    });

    test('restocked: adds to restockedQuantity, quantity unchanged', () {
      final line = LineStock.restocked(stamped(5, own: 5, fresh: 0), 2);
      expect([line.quantity, line.restockedQuantity], [5, 2]);
    });

    test('withSale: an increase adds to the stamps', () {
      final line =
          LineStock.withSale(stamped(5, own: 2, fresh: 3), own: 1, fresh: 0);
      expect([line.ownStockQty, line.freshQty], [3, 3]);
    });

    test('the new fields survive toMap / fromMap and copyWith', () {
      final line = stamped(4, own: 1, fresh: 3, restocked: 2);
      final back = CartItem.fromMap(line.toMap());
      expect([back.ownStockQty, back.freshQty, back.restockedQuantity],
          [1, 3, 2]);
      final old = CartItem.fromMap(line.toMap()
        ..remove('ownStockQty')
        ..remove('freshQty')
        ..remove('restockedQuantity'));
      expect(old.hasStockStamp, isFalse);
    });
  });

  group('sale stamps and restores', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('line_stock_');
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
      await put(Items(id: 'thali', name: 'thali',
          productType: ProductType.finishedGood));
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
    CartItem line(String id, int qty) => makeCartItem(
        id: 'line-$id', productId: id, title: id, price: 10, quantity: qty);

    Future<CartItem> sell(String id, int qty) async {
      final plan = await InventoryService.planSale([line(id, qty)]);
      await InventoryService.applyPlannedUnits(plan.units);
      return plan.lines.single;
    }

    test('the plan stamps each line with what it took', () async {
      final plan = await InventoryService.planSale([
        line('toOrder', 2),
        line('cake', 3),
        line('hybrid', 5),
        line('thali', 1),
      ]);
      String s(CartItem c) => '${c.id}:${c.ownStockQty}/${c.freshQty}';
      expect(plan.lines.map(s), [
        'line-toOrder:0/2',
        'line-cake:3/0',
        'line-hybrid:2/3',
        'line-thali:0/0',
      ]);
    });

    test('restoring part of a hybrid line reverses the fresh part first',
        () async {
      final sold = await sell('hybrid', 5);
      expect([stock('hybrid'), stock('bun'), stock('cheese')], [0, 7, 4]);

      await InventoryService.restoreLines([(line: sold, qty: 2)]);
      expect([stock('hybrid'), stock('bun'), stock('cheese')], [0, 9, 8]);
    });

    test('restoring all of a hybrid line: fresh back to ingredients, the '
        'rest to prepared stock', () async {
      final sold = await sell('hybrid', 5);
      await InventoryService.restoreLines([(line: sold, qty: 5)]);
      expect([stock('hybrid'), stock('bun'), stock('cheese')], [2, 10, 10]);
    });

    test('a restore follows what the sale did, not the item\'s current type',
        () async {
      final sold = await sell('toOrder', 2); // made fresh: 2 buns, 4 cheese
      final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
      await items.put('toOrder', items.get('toOrder')!.copyWith(
          prepMode: ProductType.madeInAdvance,
          trackInventory: true,
          stockQuantity: 0));
      await itemStore.loadItems();

      await InventoryService.restoreLines([(line: sold, qty: 2)]);

      expect([stock('bun'), stock('cheese')], [10, 10]);
      expect(stock('toOrder'), 0, reason: 'never sold from prepared stock');
    });

    test('a line already restocked restores nothing more', () async {
      final sold = await sell('cake', 3);
      await InventoryService.restoreLines(
          [(line: LineStock.restocked(sold, 3), qty: 3)]);
      expect(stock('cake'), 1);
    });

    test('an unstamped legacy line restores by the current type, as before',
        () async {
      await InventoryService.deductStockForOrder([line('cake', 2)]);
      await InventoryService.restoreLines([(line: line('cake', 2), qty: 2)]);
      expect(stock('cake'), 4);
    });
  });
}
