import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_production_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_production_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_ledger_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_purchase_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_supplier_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Service-level stock flows — sale deduction, void/refund restoration,
/// production and GRN receiving — run against real Hive boxes and a minimal
/// service locator.
///
/// What each flow can prove: refund, production and GRN all end with
/// `itemStore.loadItems()`, which would mask a MobX-invisible write, so their
/// tests verify balances, persistence, audit rows and cost. Deduction reloads
/// only at its START, so it is where observability without a reload is
/// proven (see the `reaction` tests).
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inventory_stock_flow_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    // Opened by name: HiveInit's open* helpers keep static "already open"
    // flags that survive Hive.close(), so they would skip reopening.
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<RecipeProductionModel>(
        HiveBoxNames.restaurantRecipeProductions);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox<RestaurantSupplierModel>(
        HiveBoxNames.restaurantSuppliers);
    await Hive.openBox<RestaurantSupplierLedgerEntryModel>(
        HiveBoxNames.restaurantSupplierLedger);
    await Hive.openBox<RestaurantPurchaseOrderModel>(
        HiveBoxNames.restaurantPurchaseOrders);
    await Hive.openBox<RestaurantPurchaseOrderItemModel>(
        HiveBoxNames.restaurantPurchaseOrderItems);
    await Hive.openBox<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);
    await Hive.openBox<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems);
    // confirmGRN numbers the receipt through DocumentNumberService, whose
    // counters live here — the app always opens it at startup.
    await Hive.openBox(HiveBoxNames.appCounters);

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<RecipeProductionRepository>(
          () => RecipeProductionRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<RestaurantSupplierRepository>(
          () => RestaurantSupplierRepository())
      ..registerLazySingleton<RestaurantSupplierLedgerRepository>(
          () => RestaurantSupplierLedgerRepository())
      ..registerLazySingleton<RestaurantSupplierStore>(
          () => RestaurantSupplierStore())
      ..registerLazySingleton<RestaurantPurchaseOrderRepository>(
          () => RestaurantPurchaseOrderRepository())
      ..registerLazySingleton<RestaurantPurchaseOrderItemRepository>(
          () => RestaurantPurchaseOrderItemRepository())
      ..registerLazySingleton<RestaurantGRNRepository>(
          () => RestaurantGRNRepository())
      ..registerLazySingleton<RestaurantGRNItemRepository>(
          () => RestaurantGRNItemRepository());
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ---------------------------------------------------------------- helpers

  Future<void> seedItems(List<Items> items) async {
    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    for (final item in items) {
      await box.put(item.id, item);
    }
    await itemStore.loadItems();
  }

  Future<void> seedVariantNames(Map<String, String> namesById) async {
    final box = Hive.box<VariantModel>(HiveBoxNames.restaurantVariants);
    for (final e in namesById.entries) {
      await box.put(e.key, VariantModel(id: e.key, name: e.value));
    }
    await variantStore.loadVariants();
  }

  Future<void> seedRecipe(RecipeModel recipe) =>
      Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes)
          .put(recipe.id, recipe);

  Items disk(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!;

  double memoryStock(String id) => itemStore.getItemById(id)!.stockQuantity;

  List<StockMovementModel> movements(String itemId) =>
      StockMovementRepository().movementsForItem(itemId);

  ItemVariante variantOf(Items item, String variantId) =>
      item.variant!.firstWhere((v) => v.variantId == variantId);

  /// Values a MobX reaction saw. With no trailing reload in the flows, only
  /// an observable list-entry replacement can populate this.
  List<T> observe<T>(T Function() read) {
    final seen = <T>[];
    final dispose = reaction((_) => read(), seen.add);
    addTearDown(dispose.call);
    return seen;
  }

  Items tracked(String id, String name, double stock, {double? cost}) =>
      Items(
        id: id,
        name: name,
        trackInventory: true,
        stockQuantity: stock,
        lastPurchaseCost: cost,
      );

  Items pizza() => Items(
        id: 'pizza',
        name: 'Pizza',
        trackInventory: true,
        variant: [
          ItemVariante(
              variantId: 'small', price: 100,
              trackInventory: true, stockQuantity: 5),
          ItemVariante(
              variantId: 'large', price: 150,
              trackInventory: false, stockQuantity: 7),
        ],
      );

  RecipeModel burgerRecipe() => RecipeModel(
        id: 'r-burger',
        itemId: 'burger',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'patty', quantity: 2),
        ],
      );

  Items burger() => Items(
        id: 'burger',
        name: 'Burger',
        productType: ProductType.recipeBased,
      );

  // ------------------------------------------------------------ sale deduct

  group('deductStockForOrder', () {
    test('deducts item stock, persists it and logs the balance', () async {
      await seedItems([tracked('tea', 'Tea', 10)]);

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3),
      ]);

      expect(memoryStock('tea'), 7);
      expect(disk('tea').stockQuantity, 7);
      final m = movements('tea').single;
      expect(m.type, 'out');
      expect(m.quantity, 3);
      expect(m.balanceAfter, 7);
      expect(m.reason, 'Sale');
    });

    test('deduction is observable without a trailing reload', () async {
      await seedItems([tracked('tea', 'Tea', 10)]);
      final seen = <double?>[];
      final dispose = reaction(
          (_) => itemStore.getItemById('tea')?.stockQuantity, seen.add);
      addTearDown(dispose.call);

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3),
      ]);

      expect(seen, [7],
          reason: 'an in-place mutation would never notify the observer');
    });

    test('two lines of the same item compound instead of both starting at 10',
        () async {
      await seedItems([tracked('tea', 'Tea', 10)]);

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 2),
        makeCartItem(id: 'l2', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3),
      ]);

      expect(disk('tea').stockQuantity, 5);
      expect(movements('tea').map((m) => m.balanceAfter),
          unorderedEquals([8.0, 5.0]));
    });

    test('variant deduction is observable and keeps every variant field',
        () async {
      await seedItems([pizza()]);
      await seedVariantNames({'small': 'Small', 'large': 'Large'});
      final seen = <double?>[];
      final dispose = reaction(
          (_) => itemStore.getItemById('pizza')?.variant
              ?.firstWhere((v) => v.variantId == 'small')
              .stockQuantity,
          seen.add);
      addTearDown(dispose.call);

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'pizza', title: 'Pizza',
            price: 100, quantity: 2, variantName: 'Small'),
      ]);

      expect(seen, [3]);
      final small = variantOf(disk('pizza'), 'small');
      final large = variantOf(disk('pizza'), 'large');
      expect(small.stockQuantity, 3);
      expect(small.trackInventory, isTrue);
      expect(large.stockQuantity, 7);
      expect(large.trackInventory, isFalse);
      final m = movements('pizza').single;
      expect(m.variantId, 'small');
      expect(m.balanceAfter, 3);
    });

    test('recipe-based sale cascades into ingredients with correct balances',
        () async {
      await seedItems([
        burger(),
        tracked('bun', 'Bun', 10),
        tracked('patty', 'Patty', 20),
      ]);
      await seedRecipe(burgerRecipe());

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'burger', title: 'Burger',
            price: 150, quantity: 2),
      ]);

      expect(disk('bun').stockQuantity, 8);
      expect(disk('patty').stockQuantity, 16);
      expect(movements('bun').single.balanceAfter, 8);
      expect(movements('patty').single.balanceAfter, 16);
      expect(movements('bun').single.reason, 'Sale (recipe: Burger)');
    });

    test('untracked item is left alone', () async {
      await seedItems([
        Items(id: 'water', name: 'Water', stockQuantity: 4),
      ]);

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'water', title: 'Water',
            price: 10, quantity: 2),
      ]);

      expect(disk('water').stockQuantity, 4);
      expect(movements('water'), isEmpty);
    });
  });

  // ------------------------------------------------ variant store not loaded

  group('variant store not yet loaded', () {
    // Names go straight into the box and `variantStore` is never touched, so
    // the service is its first caller — like a server-side order after a
    // restart. The lazy store's constructor load is not awaited.
    Future<void> writeVariantNamesOnly() async {
      final box = Hive.box<VariantModel>(HiveBoxNames.restaurantVariants);
      await box.put('small', VariantModel(id: 'small', name: 'Small'));
      await box.put('large', VariantModel(id: 'large', name: 'Large'));
    }

    test('sale still deducts the variant', () async {
      await seedItems([pizza()]);
      await writeVariantNamesOnly();

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'pizza', title: 'Pizza',
            price: 100, quantity: 2, variantName: 'Small'),
      ]);

      expect(variantOf(disk('pizza'), 'small').stockQuantity, 3);
      expect(movements('pizza').single.balanceAfter, 3);
    });

    // Strict item: ordering beyond stock is not allowed, so the variant stock
    // check actually runs. Small has 5 in stock.
    List<CartItem> smallLine(int qty) => [
          makeCartItem(id: 'l1', productId: 'pizza', title: 'Pizza',
              price: 100, quantity: qty, variantName: 'Small'),
        ];

    test('stock check accepts an in-stock variant', () async {
      await seedItems([pizza().copyWith(allowOrderWhenOutOfStock: false)]);
      await writeVariantNamesOnly();

      expect(await InventoryService.checkStockAvailability(smallLine(2)),
          isTrue);
    });

    test('stock check still rejects an insufficient variant', () async {
      await seedItems([pizza().copyWith(allowOrderWhenOutOfStock: false)]);
      await writeVariantNamesOnly();

      expect(await InventoryService.checkStockAvailability(smallLine(6)),
          isFalse);
    });

    test('refund still restores the variant', () async {
      await seedItems([pizza()]);
      await writeVariantNamesOnly();

      await InventoryService.restoreStockForRefund({
        makeCartItem(id: 'l1', productId: 'pizza', title: 'Pizza',
            price: 100, quantity: 2, variantName: 'Small'): 2,
      });

      expect(variantOf(disk('pizza'), 'small').stockQuantity, 7);
      expect(movements('pizza').single.balanceAfter, 7);
    });
  });

  // ------------------------------------------------ item store never touched

  group('item store not yet loaded (cold start)', () {
    // Items go straight into the box and `itemStore` is never accessed first,
    // so the service creates the lazy store itself. Its constructor load is
    // not awaited; each flow's leading `itemStore.ensureLoaded()` is what makes
    // the list readable here.
    Future<void> writeItemsOnly(List<Items> items) async {
      final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
      for (final item in items) {
        await box.put(item.id, item);
      }
    }

    test('checkStockAvailability sees stock', () async {
      await writeItemsOnly([tracked('tea', 'Tea', 10)]);

      final ok = await InventoryService.checkStockAvailability([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 2),
      ]);

      expect(ok, isTrue);
    });

    test('produceBatch finds its ingredients', () async {
      await writeItemsOnly([
        Items(id: 'dough', name: 'Dough',
            productType: ProductType.semiFinished, trackInventory: true),
        tracked('flour', 'Flour', 10, cost: 40),
      ]);
      await seedRecipe(RecipeModel(
        id: 'r-dough',
        itemId: 'dough',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'flour', quantity: 1),
        ],
      ));

      await InventoryService.produceBatch(
        semiFinishedItem:
            Hive.box<Items>(HiveBoxNames.restaurantItems).get('dough')!,
        batchQty: 2,
      );

      expect(disk('flour').stockQuantity, 8);
      expect(disk('dough').stockQuantity, 2);
    });

    test('sale deducts stock', () async {
      await writeItemsOnly([tracked('tea', 'Tea', 10)]);

      await InventoryService.deductStockForOrder([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3),
      ]);

      expect(disk('tea').stockQuantity, 7);
    });

    test('refund restores stock', () async {
      await writeItemsOnly([tracked('tea', 'Tea', 5)]);

      await InventoryService.restoreStockForRefund({
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3): 3,
      });

      expect(disk('tea').stockQuantity, 8);
    });
  });

  // ---------------------------------------------------------- void / refund

  group('restoreStockForRefund / restoreStockForOrder', () {
    test('restores item stock and logs the post-restore balance', () async {
      await seedItems([tracked('tea', 'Tea', 5)]);

      await InventoryService.restoreStockForRefund({
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3): 3,
      });

      expect(memoryStock('tea'), 8);
      expect(disk('tea').stockQuantity, 8);
      final m = movements('tea').single;
      expect(m.type, 'in');
      expect(m.balanceAfter, 8,
          reason: 'reading the captured item would log the pre-restore 5');
      expect(m.reason, 'Void / Refund return');
    });

    test('restores variant stock, keeps its fields, logs the right balance',
        () async {
      await seedItems([pizza()]);
      await seedVariantNames({'small': 'Small', 'large': 'Large'});

      await InventoryService.restoreStockForRefund({
        makeCartItem(id: 'l1', productId: 'pizza', title: 'Pizza',
            price: 100, quantity: 2, variantName: 'Small'): 2,
      });

      final small = variantOf(disk('pizza'), 'small');
      expect(small.stockQuantity, 7);
      expect(small.trackInventory, isTrue);
      expect(small.price, 100);
      expect(variantOf(disk('pizza'), 'large').stockQuantity, 7);
      final m = movements('pizza').single;
      expect(m.variantId, 'small');
      expect(m.balanceAfter, 7);
    });

    test('identical lines merge into one restore', () async {
      await seedItems([tracked('tea', 'Tea', 5)]);

      // CartItem equality ignores id/quantity, so these share one map key.
      await InventoryService.restoreStockForOrder([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 2),
        makeCartItem(id: 'l2', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3),
      ]);

      expect(disk('tea').stockQuantity, 10);
      final m = movements('tea').single;
      expect(m.quantity, 5);
      expect(m.balanceAfter, 10);
    });

    test('differently configured lines of one item compound', () async {
      await seedItems([tracked('tea', 'Tea', 5)]);

      await InventoryService.restoreStockForOrder([
        makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
            price: 20, quantity: 2),
        makeCartItem(id: 'l2', productId: 'tea', title: 'Tea',
            price: 20, quantity: 3, choiceNames: ['Less sugar']),
      ]);

      expect(disk('tea').stockQuantity, 10);
      expect(movements('tea').map((m) => m.balanceAfter),
          unorderedEquals([7.0, 10.0]));
    });

    test('recipe-based refund restores ingredients with post-restore balances',
        () async {
      await seedItems([
        burger(),
        tracked('bun', 'Bun', 10),
        tracked('patty', 'Patty', 20),
      ]);
      await seedRecipe(burgerRecipe());

      await InventoryService.restoreStockForRefund({
        makeCartItem(id: 'l1', productId: 'burger', title: 'Burger',
            price: 150, quantity: 3): 3,
      });

      expect(disk('bun').stockQuantity, 13);
      expect(disk('patty').stockQuantity, 26);
      expect(movements('bun').single.balanceAfter, 13);
      expect(movements('patty').single.balanceAfter, 26);
      expect(movements('bun').single.reason,
          'Void / Refund return (recipe: Burger)');
    });

    test('untracked item is not restored', () async {
      await seedItems([
        Items(id: 'water', name: 'Water', stockQuantity: 4),
      ]);

      await InventoryService.restoreStockForRefund({
        makeCartItem(id: 'l1', productId: 'water', title: 'Water',
            price: 10, quantity: 2): 2,
      });

      expect(disk('water').stockQuantity, 4);
      expect(movements('water'), isEmpty);
    });

    group('observable without a reload', () {
      test('item restore', () async {
        await seedItems([tracked('tea', 'Tea', 5)]);
        final seen =
            observe(() => itemStore.getItemById('tea')?.stockQuantity);

        await InventoryService.restoreStockForRefund({
          makeCartItem(id: 'l1', productId: 'tea', title: 'Tea',
              price: 20, quantity: 3): 3,
        });

        expect(seen, [8]);
      });

      test('variant restore', () async {
        await seedItems([pizza()]);
        await seedVariantNames({'small': 'Small', 'large': 'Large'});
        final seen = observe(() => itemStore.getItemById('pizza')?.variant
            ?.firstWhere((v) => v.variantId == 'small')
            .stockQuantity);

        await InventoryService.restoreStockForRefund({
          makeCartItem(id: 'l1', productId: 'pizza', title: 'Pizza',
              price: 100, quantity: 2, variantName: 'Small'): 2,
        });

        expect(seen, [7]);
      });

      test('recipe-based refund restores ingredients observably', () async {
        await seedItems([
          burger(),
          tracked('bun', 'Bun', 10),
          tracked('patty', 'Patty', 20),
        ]);
        await seedRecipe(burgerRecipe());
        final bun = observe(() => itemStore.getItemById('bun')?.stockQuantity);
        final patty =
            observe(() => itemStore.getItemById('patty')?.stockQuantity);

        await InventoryService.restoreStockForRefund({
          makeCartItem(id: 'l1', productId: 'burger', title: 'Burger',
              price: 150, quantity: 3): 3,
        });

        expect(bun, [13]);
        expect(patty, [26]);
      });
    });
  });

  // -------------------------------------------------------------- production

  group('produceBatch', () {
    RecipeModel doughRecipe() => RecipeModel(
          id: 'r-dough',
          itemId: 'dough',
          yieldQty: 2,
          ingredients: [
            RecipeIngredientModel(ingredientItemId: 'flour', quantity: 1),
            RecipeIngredientModel(ingredientItemId: 'salt', quantity: 0.5),
          ],
        );

    Items dough() => Items(
          id: 'dough',
          name: 'Dough',
          productType: ProductType.semiFinished,
          trackInventory: true,
          stockQuantity: 1,
        );

    test('keeps the stock increase AND writes the new unit cost', () async {
      final semiFinished = dough();
      await seedItems([
        semiFinished,
        tracked('flour', 'Flour', 10, cost: 40),
        tracked('salt', 'Salt', 5, cost: 2),
      ]);
      await seedRecipe(doughRecipe());

      // The screen passes the instance it already holds — stale by the time
      // the stock write replaces the store entry. It must not be saved back.
      await InventoryService.produceBatch(
          semiFinishedItem: semiFinished, batchQty: 4);

      final expectedCost = doughRecipe().estimatedCostPerUnit(
          (id) => {'flour': 40.0, 'salt': 2.0}[id] ?? 0);
      final stored = disk('dough');
      expect(stored.stockQuantity, 5,
          reason: 'a save() of the stale instance would revert this to 1');
      expect(stored.lastPurchaseCost, expectedCost);
      expect(memoryStock('dough'), 5);
    });

    test('deducts ingredients and logs every balance', () async {
      await seedItems([
        dough(),
        tracked('flour', 'Flour', 10, cost: 40),
        tracked('salt', 'Salt', 5, cost: 2),
      ]);
      await seedRecipe(doughRecipe());

      await InventoryService.produceBatch(
          semiFinishedItem: itemStore.getItemById('dough')!, batchQty: 4);

      expect(disk('flour').stockQuantity, 8);
      expect(disk('salt').stockQuantity, 4);
      expect(movements('flour').single.balanceAfter, 8);
      expect(movements('salt').single.balanceAfter, 4);
      final produced = movements('dough').single;
      expect(produced.type, 'in');
      expect(produced.quantity, 4);
      expect(produced.balanceAfter, 5);
      expect(produced.reason, 'Production batch');
      expect(
          RecipeProductionRepository()
              .getProductionsForItem('dough')
              .single
              .batchQty,
          4);
    });

    test('insufficient ingredient stock throws and changes nothing', () async {
      await seedItems([
        dough(),
        tracked('flour', 'Flour', 1, cost: 40),
        tracked('salt', 'Salt', 5, cost: 2),
      ]);
      await seedRecipe(doughRecipe());

      await expectLater(
        InventoryService.produceBatch(
            semiFinishedItem: itemStore.getItemById('dough')!, batchQty: 4),
        throwsA(isA<Exception>()),
      );

      expect(disk('dough').stockQuantity, 1);
      expect(disk('flour').stockQuantity, 1);
      expect(disk('salt').stockQuantity, 5);
      expect(movements('dough'), isEmpty);
      expect(movements('flour'), isEmpty);
    });

    test('produced stock, its cost and ingredients are observable without '
        'a reload', () async {
      await seedItems([
        dough(),
        tracked('flour', 'Flour', 10, cost: 40),
        tracked('salt', 'Salt', 5, cost: 2),
      ]);
      await seedRecipe(doughRecipe());
      final expectedCost = doughRecipe().estimatedCostPerUnit(
          (id) => {'flour': 40.0, 'salt': 2.0}[id] ?? 0);
      final produced = observe(() {
        final i = itemStore.getItemById('dough');
        return (i?.stockQuantity, i?.lastPurchaseCost);
      });
      final flour =
          observe(() => itemStore.getItemById('flour')?.stockQuantity);

      await InventoryService.produceBatch(
          semiFinishedItem: itemStore.getItemById('dough')!, batchQty: 4);

      expect(produced, [(5.0, expectedCost)]);
      expect(flour, [8]);
    });
  });

  // ------------------------------------------------------------ GRN receipt

  group('confirmGRN', () {
    GRNReceiptLine line({
      String poItemId = 'poi-1',
      required double accepted,
      double? cost,
    }) =>
        (
          poItemId: poItemId,
          itemId: 'rice',
          itemName: 'Rice',
          orderedQty: accepted,
          receivedQty: accepted,
          acceptedQty: accepted,
          damagedQty: null,
          costPrice: cost,
          damagedHandling: null,
        );

    Future<List<RestaurantGRNItemModel>> confirm(List<GRNReceiptLine> lines) =>
        RestaurantPurchaseOrderStore().confirmGRN(
          poId: 'po-1',
          poNumber: 'PO-1',
          supplierId: 'unknown-supplier',
          receivedDate: '2026-09-17',
          lines: lines,
        );

    test('adds stock and writes the purchase cost together', () async {
      await seedItems([tracked('rice', 'Rice', 2, cost: 50)]);

      final grnItems = await confirm([line(accepted: 10, cost: 55)]);

      expect(grnItems, hasLength(1));
      final stored = disk('rice');
      expect(stored.stockQuantity, 12);
      expect(stored.lastPurchaseCost, 55);
      expect(memoryStock('rice'), 12);
      final m = movements('rice').single;
      expect(m.type, 'in');
      expect(m.quantity, 10);
      expect(m.balanceAfter, 12);
      expect(m.reason, 'Purchase (PO-1)');
    });

    test('two lines for one item compound; last cost wins', () async {
      await seedItems([tracked('rice', 'Rice', 2, cost: 50)]);

      await confirm([
        line(poItemId: 'poi-1', accepted: 3, cost: 51),
        line(poItemId: 'poi-2', accepted: 4, cost: 52),
      ]);

      final stored = disk('rice');
      expect(stored.stockQuantity, 9);
      expect(stored.lastPurchaseCost, 52);
      expect(movements('rice').map((m) => m.balanceAfter),
          unorderedEquals([5.0, 9.0]));
    });

    test('a line without a cost keeps the existing cost', () async {
      await seedItems([tracked('rice', 'Rice', 2, cost: 50)]);

      await confirm([line(accepted: 5)]);

      expect(disk('rice').stockQuantity, 7);
      expect(disk('rice').lastPurchaseCost, 50);
    });

    test('zero accepted records the GRN line but moves no stock', () async {
      await seedItems([tracked('rice', 'Rice', 2, cost: 50)]);

      final grnItems = await confirm([line(accepted: 0, cost: 55)]);

      expect(grnItems, hasLength(1));
      expect(disk('rice').stockQuantity, 2);
      expect(disk('rice').lastPurchaseCost, 50);
      expect(movements('rice'), isEmpty);
    });

    test('stock and cost are observable without a reload', () async {
      await seedItems([tracked('rice', 'Rice', 2, cost: 50)]);
      final seen = observe(() {
        final i = itemStore.getItemById('rice');
        return (i?.stockQuantity, i?.lastPurchaseCost);
      });

      await confirm([line(accepted: 10, cost: 55)]);

      expect(seen, [(12.0, 55.0)]);
    });
  });
}
