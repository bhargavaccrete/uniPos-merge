import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
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
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

/// D-A3: Low Stock "Add" on a Recipe-Based row wrote a stockQuantity nothing
/// reads, flipped trackInventory on, and logged a fictitious movement.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stock_adjust_guard_');
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

  Items cheese(double stock) => Items(
        id: 'cheese',
        name: 'Cheese',
        productType: ProductType.rawMaterial,
        trackInventory: true,
        stockQuantity: stock,
        lowStockAlertEnabled: true,
        lowStockThreshold: 5,
      );

  Items burger() => Items(
        id: 'burger',
        name: 'Burger',
        productType: ProductType.recipeBased,
        lowStockAlertEnabled: true,
        lowStockThreshold: 5,
      );

  Future<void> seedBurgerRecipe() =>
      Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).put(
        'r-burger',
        RecipeModel(
          id: 'r-burger',
          itemId: 'burger',
          ingredients: [
            RecipeIngredientModel(ingredientItemId: 'cheese', quantity: 1),
          ],
        ),
      );

  test('addStock refuses a Recipe-Based item and writes nothing', () async {
    await seed([cheese(2), burger()]);
    await seedBurgerRecipe();

    await expectLater(
      StockAdjustService.addStock(
          item: itemStore.getItemById('burger')!,
          qty: 5,
          reason: 'Restock / Purchase'),
      throwsStateError,
    );

    final b = disk('burger');
    expect(b.stockQuantity, 0);
    expect(b.trackInventory, isFalse);
    expect(movements('burger'), isEmpty);
  });

  test('addStock still adds to a Raw Material and logs one movement',
      () async {
    await seed([cheese(3)]);

    final balance = await StockAdjustService.addStock(
        item: itemStore.getItemById('cheese')!,
        qty: 5,
        reason: 'Restock / Purchase');

    expect(balance, 8);
    expect(disk('cheese').stockQuantity, 8);
    final m = movements('cheese').single;
    expect(m.type, 'in');
    expect(m.quantity, 5);
    expect(m.reason, 'Restock / Purchase');
  });

  test('lowStockEntries still lists a Recipe-Based item by can-make count',
      () async {
    await seed([cheese(2), burger()]);
    await seedBurgerRecipe();

    final entries = StockAdjustService.lowStockEntries();
    final burgerEntry = entries.singleWhere((e) => e.item.id == 'burger');
    expect(burgerEntry.stock, 2);
  });
}
