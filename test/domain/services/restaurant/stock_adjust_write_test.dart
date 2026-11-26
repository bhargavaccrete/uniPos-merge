import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/item_edit_stock.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

/// Manual stock adjustments (Manage Inventory, Low Stock, stock take) go
/// through the same queued write as sales — `ItemStore.applyStockDelta` —
/// so a screen's stale copy of an item can never overwrite another change,
/// and every history row matches the stock actually stored.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stock_adjust_write_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<RestaurantInventoryLossModel>(
        HiveBoxNames.restaurantInventoryLosses);
    await Hive.openBox<RestaurantSupplierLedgerEntryModel>(
        HiveBoxNames.restaurantSupplierLedger);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    locator
      ..registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService())..licenseBypassed = true)
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seed(List<Items> items) async {
    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    for (final i in items) {
      await box.put(i.id, i);
    }
    await itemStore.loadItems();
  }

  Items disk(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!;

  List<StockMovementModel> movements(String id) =>
      StockMovementRepository().movementsForItem(id);

  Items flour({double stock = 10, double? cost}) => Items(
        id: 'flour',
        name: 'Flour',
        productType: ProductType.rawMaterial,
        unit: 'kg',
        trackInventory: true,
        stockQuantity: stock,
        lastPurchaseCost: cost,
      );

  group('one queued write', () {
    test('two adds from the same stale copy both land (no lost update)',
        () async {
      await seed([flour()]);
      final snapshot = itemStore.getItemById('flour')!; // what a screen holds

      await Future.wait([
        StockAdjustService.addStock(
            item: snapshot, qty: 5, reason: 'Stock correction'),
        StockAdjustService.addStock(
            item: snapshot, qty: 3, reason: 'Stock correction'),
      ]);

      expect(disk('flour').stockQuantity, 18);
      expect(movements('flour').map((m) => m.balanceAfter),
          unorderedEquals([15.0, 18.0]));
    });

    test('an adjustment and a sale at the same time both count', () async {
      await seed([flour()]);
      final snapshot = itemStore.getItemById('flour')!;

      await Future.wait([
        StockAdjustService.adjustBy(
            item: snapshot, delta: 4, reason: 'Stock correction'),
        itemStore.applyStockDelta(itemId: 'flour', delta: -2), // a sale
      ]);

      expect(disk('flour').stockQuantity, 12);
    });

    test('a variant adjustment keeps the variant\'s stock tracking', () async {
      await seed([
        Items(
          id: 'water',
          name: 'Water',
          productType: ProductType.tradeItem,
          trackInventory: true,
          variant: [
            ItemVariante(
                variantId: 'v1', price: 20, trackInventory: true,
                stockQuantity: 4),
          ],
        ),
      ]);
      final item = itemStore.getItemById('water')!;

      await StockAdjustService.addStock(
          item: item, variant: item.variant!.first, qty: 2,
          reason: 'Stock correction');

      final v = disk('water').variant!.first;
      expect(v.stockQuantity, 6);
      expect(v.trackInventory, isTrue);
    });

    test('a removal below zero is refused and changes nothing', () async {
      await seed([flour()]);

      await expectLater(
        StockAdjustService.adjustBy(
            item: itemStore.getItemById('flour')!, delta: -11,
            reason: 'Wastage / Spoilage'),
        throwsA(isA<StateError>()),
      );
      expect(disk('flour').stockQuantity, 10);
      expect(movements('flour'), isEmpty);
      expect(
          Hive.box<RestaurantInventoryLossModel>(
                  HiveBoxNames.restaurantInventoryLosses)
              .isEmpty,
          isTrue);
    });
  });

  group('history', () {
    test('each adjustment writes one row that matches stored stock', () async {
      await seed([flour()]);

      await StockAdjustService.adjustBy(
          item: itemStore.getItemById('flour')!, delta: -2,
          reason: 'Wastage / Spoilage', note: 'Wet bag');

      final m = movements('flour').single;
      expect(m.type, 'out');
      expect(m.quantity, 2);
      expect(m.reason, 'Wastage / Spoilage');
      expect(m.note, 'Wet bag');
      expect(m.balanceAfter, disk('flour').stockQuantity);
      expect(m.balanceAfter, 8);
    });

    test('a loss reason also writes a loss row; a correction does not',
        () async {
      await seed([flour(cost: 40)]);
      final losses = Hive.box<RestaurantInventoryLossModel>(
          HiveBoxNames.restaurantInventoryLosses);

      await StockAdjustService.adjustBy(
          item: itemStore.getItemById('flour')!, delta: -1,
          reason: 'Stock correction');
      expect(losses.isEmpty, isTrue);

      await StockAdjustService.adjustBy(
          item: itemStore.getItemById('flour')!, delta: -2,
          reason: 'Wastage / Spoilage');
      expect(losses.values.single.quantity, 2);
    });
  });

  group('Restock / Purchase cost', () {
    test('with a unit cost: item cost and the row\'s cost are recorded, no '
        'supplier ledger', () async {
      await seed([flour(cost: 35)]);

      await StockAdjustService.adjustBy(
          item: itemStore.getItemById('flour')!, delta: 5,
          reason: 'Restock / Purchase', unitCost: 42);

      expect(disk('flour').stockQuantity, 15);
      expect(disk('flour').lastPurchaseCost, 42);
      expect(movements('flour').single.unitCost, 42);
      expect(
          Hive.box<RestaurantSupplierLedgerEntryModel>(
                  HiveBoxNames.restaurantSupplierLedger)
              .isEmpty,
          isTrue);
    });

    test('without a unit cost: the item cost is left alone', () async {
      await seed([flour(cost: 35)]);

      await StockAdjustService.adjustBy(
          item: itemStore.getItemById('flour')!, delta: 5,
          reason: 'Restock / Purchase');

      expect(disk('flour').lastPurchaseCost, 35);
      expect(movements('flour').single.unitCost, isNull);
    });

    for (final bad in [0.0, -3.0]) {
      test('a unit cost of $bad is refused and changes nothing', () async {
        await seed([flour(cost: 35)]);

        await expectLater(
          StockAdjustService.adjustBy(
              item: itemStore.getItemById('flour')!, delta: 5,
              reason: 'Restock / Purchase', unitCost: bad),
          throwsA(isA<ArgumentError>()),
        );
        expect(disk('flour').stockQuantity, 10);
        expect(disk('flour').lastPurchaseCost, 35);
        expect(movements('flour'), isEmpty);
      });
    }
  });

  group('stock take (adjustTo)', () {
    test('sets the counted level against the live stock, once', () async {
      await seed([flour()]);
      final snapshot = itemStore.getItemById('flour')!;
      await itemStore.applyStockDelta(itemId: 'flour', delta: -2); // sale → 8

      final ok = await StockAdjustService.adjustTo(
          item: snapshot, newStock: 7, reason: 'Stock correction',
          movementId: 'st_1');
      final again = await StockAdjustService.adjustTo(
          item: snapshot, newStock: 7, reason: 'Stock correction',
          movementId: 'st_1');

      expect(ok, isTrue);
      expect(again, isTrue);
      expect(disk('flour').stockQuantity, 7);
      expect(movements('flour').single.quantity, 1);
    });

    test('a negative target returns false and changes nothing', () async {
      await seed([flour()]);

      final ok = await StockAdjustService.adjustTo(
          item: itemStore.getItemById('flour')!, newStock: -1,
          reason: 'Stock correction');

      expect(ok, isFalse);
      expect(disk('flour').stockQuantity, 10);
    });
  });

  test('Restock / Purchase and the other reasons are still offered', () {
    expect(StockAdjustService.addReasons, [
      'Restock / Purchase',
      'Customer return',
      'Stock correction',
      'Transfer in',
      'Other',
    ]);
    expect(StockAdjustService.removeReasons, [
      'Wastage / Spoilage',
      'Theft / Loss',
      'Stock correction',
      'Transfer out',
      'Sample / Complimentary',
      'Other',
    ]);
  });

  group('Edit Item save keeps live stock', () {
    Items withStock(double stock, {double variantStock = 4}) => Items(
          id: 'coke',
          name: 'Coke',
          productType: ProductType.tradeItem,
          trackInventory: true,
          stockQuantity: stock,
          variant: [
            ItemVariante(
                variantId: 'v1', price: 40, trackInventory: true,
                stockQuantity: variantStock),
          ],
        );

    test('stock sold while the screen was open is not undone', () {
      final edited = withStock(10, variantStock: 4)
          .copyWith(name: 'Coca-Cola', lowStockThreshold: 3);
      final live = withStock(7, variantStock: 2); // sold meanwhile

      final saved = ItemEditStock.carryLiveStock(edited: edited, live: live);

      expect(saved.stockQuantity, 7);
      expect(saved.variant!.single.stockQuantity, 2);
      expect(saved.name, 'Coca-Cola');
      expect(saved.lowStockThreshold, 3);
    });

    test('no live item: the edit is saved as it is', () {
      final edited = withStock(10);
      expect(
          ItemEditStock.carryLiveStock(edited: edited, live: null)
              .stockQuantity,
          10);
    });
  });
}
