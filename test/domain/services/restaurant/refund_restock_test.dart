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
import 'package:billberrylite/domain/services/restaurant/refund_restock_rule.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Refund dialog "Add back to stock": per-line, type-based defaults, the
/// cashier's own choice wins, and only ticked lines restore — each from what
/// its sale actually took (the line's stamp).
void main() {
  Items item(String? type, {String? prepMode, bool makeFresh = false}) =>
      Items(
        id: 'x',
        name: 'X',
        productType: type,
        prepMode: prepMode,
        makeFreshWhenOut: makeFresh,
      );

  group('default for "Add back to stock"', () {
    test('Finished items start unchecked — every preparation mode', () {
      expect(
          RefundRestockRule.defaultFor(
              item(ProductType.finishedGood, prepMode: ProductType.madeToOrder)),
          isFalse);
      expect(
          RefundRestockRule.defaultFor(item(ProductType.finishedGood,
              prepMode: ProductType.madeInAdvance)),
          isFalse);
      expect(
          RefundRestockRule.defaultFor(item(ProductType.finishedGood,
              prepMode: ProductType.madeInAdvance, makeFresh: true)),
          isFalse,
          reason: 'hybrid');
    });

    test('legacy Finished items start unchecked', () {
      expect(RefundRestockRule.defaultFor(item(null)), isFalse);
      expect(RefundRestockRule.defaultFor(item(ProductType.recipeBased)),
          isFalse);
    });

    test('Trade, Raw and Semi-Finished start checked', () {
      expect(RefundRestockRule.defaultFor(item(ProductType.tradeItem)), isTrue);
      expect(
          RefundRestockRule.defaultFor(item(ProductType.rawMaterial)), isTrue);
      expect(
          RefundRestockRule.defaultFor(item(ProductType.semiFinished)), isTrue);
    });

    test('an item that no longer exists starts unchecked', () {
      expect(RefundRestockRule.defaultFor(null), isFalse);
    });
  });

  group('per-line selection', () {
    final burger = makeCartItem(id: 'l-burger', productId: 'burger', price: 150);
    final coke = makeCartItem(id: 'l-coke', productId: 'coke', price: 40);
    final types = {
      'burger': item(ProductType.finishedGood, prepMode: ProductType.madeToOrder),
      'coke': item(ProductType.tradeItem),
    };
    RefundRestockSelection selection() =>
        RefundRestockSelection([burger, coke], (id) => types[id]);

    test('each line starts from its own type default', () {
      final s = selection();
      expect(s.isSelected(burger), isFalse);
      expect(s.isSelected(coke), isTrue);
    });

    test('overriding one line leaves the other alone', () {
      final s = selection()..select(burger, true);
      expect(s.isSelected(burger), isTrue);
      expect(s.isSelected(coke), isTrue);
      s.select(coke, false);
      expect(s.isSelected(burger), isTrue);
      expect(s.isSelected(coke), isFalse);
    });

    test('a choice survives rebuilt line objects with the same id', () {
      final s = selection()..select(burger, true);
      final rebuilt = burger.copyWith(quantity: 5);
      expect(s.isSelected(rebuilt), isTrue);
    });

    test('a line its void already restocked offers nothing to add back', () {
      final voided = coke.copyWith(quantity: 2, restockedQuantity: 2);
      final half = coke.copyWith(quantity: 2, restockedQuantity: 1);
      expect(RefundRestockRule.restorable(voided), 0);
      expect(RefundRestockRule.restorable(half), 1);
      expect(RefundRestockRule.restorable(coke.copyWith(quantity: 2)), 2,
          reason: 'never restocked');

      final s = RefundRestockSelection([voided], (_) => types['coke']);
      expect(s.isSelected(voided), isFalse);
      s.select(voided, true);
      expect(s.restockFor({voided: 2}), isEmpty,
          reason: 'even if ticked, nothing is left to return');
    });

    test('grouping KOT-split lines adds up what was already restocked', () {
      final k1 = coke.copyWith(quantity: 1, restockedQuantity: 1);
      final k2 = makeCartItem(id: 'l-coke-2', productId: 'coke', price: 40)
          .copyWith(quantity: 1, restockedQuantity: 1);
      final grouped = RefundService.getRefundableItems(PastOrderModel(
        id: 'o',
        customerName: '',
        totalPrice: 80,
        items: [k1, k2],
        orderAt: DateTime.now(),
        orderType: 'Dine In',
        paymentmode: 'Cash',
        orderStatus: 'VOIDED',
        kotNumbers: [1, 2],
        kotBoundaries: [1, 2],
      ));
      expect(grouped.single.quantity, 2);
      expect(grouped.single.restockedQuantity, 2);
      expect(RefundRestockRule.restorable(grouped.single), 0);
    });

    test('only selected lines with a refunded quantity are restocked', () {
      final s = selection();
      expect(s.restockFor({burger: 2, coke: 2}), {coke: 2});
      s.select(burger, true);
      expect(s.restockFor({burger: 2, coke: 0}), {burger: 2});
    });
  });

  group('refund restores only selected lines, from the right source', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('refund_restock_');
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
        ..registerLazySingleton<PastOrderRepository>(
            () => PastOrderRepository())
        ..registerLazySingleton<PastOrderStore>(
            () => PastOrderStore(locator<PastOrderRepository>()));

      // After a sale of Burger 2 (made to order, fresh), Sandwich 3 (hybrid:
      // 2 prepared + 1 fresh) and Coke 2: Bun 20 − 2 − 1 = 17.
      final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
      for (final i in [
        Items(
            id: 'bun',
            name: 'Bun',
            productType: ProductType.rawMaterial,
            trackInventory: true,
            stockQuantity: 17),
        Items(
            id: 'burger',
            name: 'Burger',
            productType: ProductType.finishedGood,
            prepMode: ProductType.madeToOrder),
        Items(
            id: 'sandwich',
            name: 'Sandwich',
            productType: ProductType.finishedGood,
            prepMode: ProductType.madeInAdvance,
            makeFreshWhenOut: true,
            trackInventory: true,
            stockQuantity: 0),
        Items(
            id: 'coke',
            name: 'Coke',
            productType: ProductType.tradeItem,
            trackInventory: true,
            stockQuantity: 22),
      ]) {
        await box.put(i.id, i);
      }
      final recipes = Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes);
      for (final id in ['burger', 'sandwich']) {
        await recipes.put(
            'r-$id',
            RecipeModel(id: 'r-$id', itemId: id, ingredients: [
              RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
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

    final burger = makeCartItem(
            id: 'l-burger', productId: 'burger', title: 'Burger',
            price: 150, quantity: 2)
        .copyWith(ownStockQty: 0, freshQty: 2, restockedQuantity: 0);
    final sandwich = makeCartItem(
            id: 'l-sandwich', productId: 'sandwich', title: 'Sandwich',
            price: 100, quantity: 3)
        .copyWith(ownStockQty: 2, freshQty: 1, restockedQuantity: 0);
    final coke = makeCartItem(
            id: 'l-coke', productId: 'coke', title: 'Coke',
            price: 40, quantity: 2)
        .copyWith(ownStockQty: 2, freshQty: 0, restockedQuantity: 0);

    Future<void> refund(
        Map<CartItem, int> qty, RefundRestockSelection selection) async {
      final order = PastOrderModel(
        id: 'o1',
        customerName: '',
        totalPrice: 680,
        items: [burger, sandwich, coke],
        orderAt: DateTime.now(),
        orderType: 'Take Away',
        paymentmode: 'Cash',
        orderStatus: 'COMPLETED',
        kotNumbers: [1],
        kotBoundaries: [3],
      );
      await pastOrderStore.addOrder(order);
      await RefundService.processRefund(
        order: order,
        refundResult: PartialRefundResult(
          itemsToRefund: qty,
          reason: 'Customer complaint',
          totalRefundAmount: 1,
          itemsToRestock: selection.restockFor(qty),
        ),
      );
    }

    RefundRestockSelection defaults() => RefundRestockSelection(
        [burger, sandwich, coke], (id) => itemStore.getItemById(id));

    test('defaults: the cooked Burger and Sandwich restore nothing; Coke does',
        () async {
      await refund({burger: 2, sandwich: 3, coke: 2}, defaults());

      expect(stock('bun'), 17, reason: 'no ingredients back for cooked food');
      expect(stock('sandwich'), 0);
      expect(stock('coke'), 24);
    });

    test('Burger ticked by the cashier: its own sale source comes back',
        () async {
      await refund({burger: 2, coke: 2}, defaults()..select(burger, true));

      expect(stock('bun'), 19, reason: 'made fresh → its ingredients return');
      expect(stock('coke'), 24);
    });

    test('hybrid ticked: fresh part first, then prepared stock', () async {
      await refund({sandwich: 2}, defaults()..select(sandwich, true));

      expect(stock('bun'), 18, reason: 'the 1 fresh unit → 1 Bun');
      expect(stock('sandwich'), 1, reason: 'then 1 prepared unit');
    });

    test('paid void then refund: the dialog offers nothing; stock unchanged',
        () async {
      // The Active Orders void already put both Cokes back (stamped).
      final voided = coke.copyWith(restockedQuantity: 2);
      final order = PastOrderModel(
        id: 'o2',
        customerName: '',
        totalPrice: 80,
        items: [voided],
        orderAt: DateTime.now(),
        orderType: 'Dine In',
        paymentmode: 'Cash',
        orderStatus: 'VOIDED',
        kotNumbers: [1],
        kotBoundaries: [1],
      );
      await pastOrderStore.addOrder(order);
      final lines = RefundService.getRefundableItems(order);
      final s = RefundRestockSelection(lines, (id) => itemStore.getItemById(id));

      expect(s.isSelected(lines.single), isFalse);
      await RefundService.processRefund(
        order: order,
        refundResult: PartialRefundResult(
          itemsToRefund: {lines.single: 2},
          reason: 'Paid by mistake',
          totalRefundAmount: 80,
          itemsToRestock: s.restockFor({lines.single: 2}),
        ),
      );
      expect(stock('coke'), 22);
    });

    test('Coke unticked by the cashier: nothing comes back', () async {
      await refund({coke: 2}, defaults()..select(coke, false));

      expect(stock('coke'), 22);
    });
  });
}
