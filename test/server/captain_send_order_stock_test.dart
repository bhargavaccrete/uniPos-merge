import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shelf/shelf.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../helpers/business_fixture.dart';
import '../helpers/open_session_fixture.dart';
import '../helpers/test_helpers.dart';

/// S-04 — a Captain order is checked against the POS's own stock before
/// anything is written, by the same rules the POS deducts with.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('captain_stock_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal); // Captain sales and cancels are journaled
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await openRestaurantSessionForTest(); // WF-7: Captain orders need an open day
    registerNoTaxBusinessForTest(); // Captain orders are priced by the POS

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerLazySingleton<OrderStore>(
          () => OrderStore(locator<OrderRepository>()));

    final variants = Hive.box<VariantModel>(HiveBoxNames.restaurantVariants);
    await variants.put('half', VariantModel(id: 'half', name: 'Half'));
    await variants.put('full', VariantModel(id: 'full', name: 'Full'));

    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    // Tracked, "don't sell when out of stock".
    await items.put('paneer', Items(
      id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
      stockQuantity: 5, allowOrderWhenOutOfStock: false,
    ));
    // Tracked, but "sell when out of stock" — never limited.
    await items.put('chai', Items(
      id: 'chai', name: 'Chai', trackInventory: true,
      stockQuantity: 0, allowOrderWhenOutOfStock: true,
    ));
    // Untracked — never limited.
    await items.put('water', Items(
      id: 'water', name: 'Water', trackInventory: false, stockQuantity: 0,
      allowOrderWhenOutOfStock: false,
    ));
    // Variants: Half 3, Full 1 — the item's own stock (100) is irrelevant.
    await items.put('biryani', Items(
      id: 'biryani', name: 'Biryani', trackInventory: true, stockQuantity: 100,
      allowOrderWhenOutOfStock: false,
      variant: [
        ItemVariante(variantId: 'half', price: 120, stockQuantity: 3),
        ItemVariante(variantId: 'full', price: 200, stockQuantity: 1),
      ],
    ));
    // Weight: 2 kg on hand.
    await items.put('chicken', Items(
      id: 'chicken', name: 'Chicken', trackInventory: true, stockQuantity: 2,
      isSoldByWeight: true, unit: 'kg', allowOrderWhenOutOfStock: false,
    ));
    // Made to order from ingredients: buns 4, patties 6 (2 each) → 3 burgers.
    await items.put('bun', Items(
        id: 'bun', name: 'Bun', trackInventory: true, stockQuantity: 4));
    await items.put('patty', Items(
        id: 'patty', name: 'Patty', trackInventory: true, stockQuantity: 6));
    await items.put('burger', Items(
      id: 'burger', name: 'Burger', productType: ProductType.recipeBased,
      allowOrderWhenOutOfStock: false,
    ));
    await Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).put(
      'r-burger',
      RecipeModel(id: 'r-burger', itemId: 'burger', ingredients: [
        RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
        RecipeIngredientModel(ingredientItemId: 'patty', quantity: 2),
      ]),
    );
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var lineSeq = 0;
  CartItem line(String productId, int qty,
          {String? variant, String? weight, String? title, bool? flag}) =>
      makeCartItem(
        id: 'line-${lineSeq++}',
        productId: productId,
        title: title ?? productId,
        price: 10,
        quantity: qty,
        variantName: variant,
        weightDisplay: weight,
        isStockManaged: flag,
      );

  Future<List<StockShortfall>> check(List<CartItem> lines) =>
      InventoryService.stockShortfalls(lines);

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  double variantStock(String id, String variantId) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems)
          .get(id)!
          .variant!
          .firstWhere((v) => v.variantId == variantId)
          .stockQuantity!;
  int orderCount() => Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).length;

  Future<(int, Map<String, dynamic>)> send(List<CartItem> lines,
      {String? requestId}) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': lines.map((l) => l.toMap()).toList(),
        'orderType': 'Take Away',
        'totalPrice': 0,
        'requestId': ?requestId,
      }),
    ));
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  // ==========================================================================
  group('the rule (InventoryService.stockShortfalls)', () {
    test('within stock passes; over stock is short', () async {
      expect(await check([line('paneer', 5)]), isEmpty);
      final s = await check([line('paneer', 6)]);
      expect(s.single.name, 'Paneer Tikka');
      expect(s.single.available, 5);
      expect(s.single.requested, 6);
    });

    test('repeated lines of the same item are combined', () async {
      expect(await check([line('paneer', 3), line('paneer', 2)]), isEmpty);
      final s = await check([line('paneer', 3), line('paneer', 3)]);
      expect(s.single.requested, 6, reason: '3 + 3, not each 3 alone');
    });

    test('"sell when out of stock" and untracked items are never limited',
        () async {
      expect(await check([line('chai', 50), line('water', 50)]), isEmpty);
    });

    test('a variant is checked against its OWN stock, per variant', () async {
      expect(await check([line('biryani', 3, variant: 'Half')]), isEmpty);
      final s = await check([line('biryani', 2, variant: 'Full')]);
      expect(s.single.name, 'Biryani (Full)');
      expect(s.single.available, 1, reason: 'not the item stock of 100');
      // Same variant on two lines combines; different variants do not.
      expect(
          await check([
            line('biryani', 2, variant: 'Half'),
            line('biryani', 1, variant: 'Half'),
            line('biryani', 1, variant: 'Full'),
          ]),
          isEmpty);
      expect(
          (await check([
            line('biryani', 2, variant: 'Half'),
            line('biryani', 2, variant: 'Half'),
          ]))
              .single
              .requested,
          4);
    });

    test('a recipe item uses what its ingredients can make', () async {
      expect(await check([line('burger', 3)]), isEmpty);
      final s = await check([line('burger', 2), line('burger', 2)]);
      expect(s.single.available, 3, reason: 'min(4 buns / 1, 6 patties / 2)');
      expect(s.single.requested, 4);
    });

    test('a weight line asks for quantity × weight in the stock unit',
        () async {
      expect(await check([line('chicken', 1, weight: '1.5KG')]), isEmpty);
      expect(await check([line('chicken', 4, weight: '500GM')]), isEmpty,
          reason: '4 × 0.5 kg = 2 kg, exactly what is on hand');
      final s = await check([
        line('chicken', 1, weight: '1.5KG'),
        line('chicken', 1, weight: '1KG'),
      ]);
      expect(s.single.requested, 2.5);
      expect(s.single.unit, 'kg');
    });

    test('the POS record decides, not flags the client sent', () async {
      // Captain says "not stock managed" — the POS item is, and is short.
      expect(await check([line('paneer', 9, flag: false)]), hasLength(1));
      // Captain says "stock managed" — the POS item allows selling out.
      expect(await check([line('chai', 9, flag: true)]), isEmpty);
    });

    test('a line no item matches, or a variant that is gone, is not limited '
        '(planSale deducts nothing for it)', () async {
      expect(await check([line('ghost', 99, title: 'Ghost')]), isEmpty);
      expect(await check([line('biryani', 99, variant: 'Jumbo')]), isEmpty);
    });
  });

  // ==========================================================================
  group('the Captain send-order endpoint', () {
    test('insufficient stock: 409, nothing written — no order, no KOT, no '
        'deduction', () async {
      final kotBefore = Hive.box(HiveBoxNames.appCounters).toMap();
      final (status, body) = await send([line('paneer', 6)]);

      expect(status, 409);
      expect(body['success'], isFalse);
      expect(body['error'], contains('Insufficient stock'));
      expect(body['error'], contains('Paneer Tikka'));
      expect(orderCount(), 0);
      expect(stock('paneer'), 5);
      expect(StockMovementRepository().movementsForItem('paneer'), isEmpty);
      expect(Hive.box(HiveBoxNames.appCounters).toMap(), kotBefore,
          reason: 'no KOT or order number taken');
    });

    test('one short line refuses the WHOLE order', () async {
      final (status, _) =
          await send([line('paneer', 2), line('biryani', 2, variant: 'Full')]);
      expect(status, 409);
      expect(stock('paneer'), 5, reason: 'the sufficient line is not taken');
      expect(variantStock('biryani', 'full'), 1);
      expect(orderCount(), 0);
    });

    test('sufficient stock: accepted and deducted exactly as before',
        () async {
      final (status, body) = await send([
        line('paneer', 2),
        line('biryani', 1, variant: 'Half'),
        line('chicken', 1, weight: '500GM'),
        line('burger', 1),
        line('chai', 3),
      ]);
      expect(status, 200, reason: body.toString());
      expect(body['success'], isTrue);
      expect(orderCount(), 1);
      expect(stock('paneer'), 3);
      expect(variantStock('biryani', 'half'), 2);
      expect(stock('chicken'), 1.5);
      expect(stock('bun'), 3);
      expect(stock('patty'), 4);
      expect(stock('chai'), -3, reason: 'sell-when-out still sells');
    });

    test('a refused request is not cached: the retry is checked again',
        () async {
      expect((await send([line('paneer', 6)], requestId: 'r1')).$1, 409);
      await itemStore.applyStockDelta(itemId: 'paneer', delta: 5); // restock
      final (status, _) = await send([line('paneer', 6)], requestId: 'r1');
      expect(status, 200);
      expect(stock('paneer'), 4);
    });

    test('two orders at once cannot both take the last stock', () async {
      final results = await Future.wait([
        send([line('paneer', 4)]),
        send([line('paneer', 4)]),
      ]);
      final statuses = results.map((r) => r.$1).toList()..sort();
      expect(statuses, [200, 409]);
      expect(stock('paneer'), 1, reason: 'never 5 - 8 = -3');
      expect(orderCount(), 1);
    });

    // SALE-3: the handler ignored `addOrder` returning false — stock was
    // deducted and 200 returned for an order that does not exist.
    test('an order that cannot be saved: 500, no stock taken, not cached',
        () async {
      await locator.unregister<OrderStore>();
      locator.registerSingleton<OrderStore>(
          _RefusingOrderStore(locator<OrderRepository>()));

      final (status, body) = await send([line('paneer', 2)], requestId: 'r9');
      expect(status, 500);
      expect(body['success'], isFalse);
      expect(stock('paneer'), 5, reason: 'nothing deducted');
      expect(orderCount(), 0);
      expect(StockMovementRepository().movementsForItem('paneer'), isEmpty);

      // Saving works again: the same request id is processed, not replayed.
      await locator.unregister<OrderStore>();
      locator.registerSingleton<OrderStore>(OrderStore(locator<OrderRepository>()));
      final (retry, _) = await send([line('paneer', 2)], requestId: 'r9');
      expect(retry, 200);
      expect(stock('paneer'), 3);
    });
  });
}

/// An order store whose save fails the way the real one reports it.
class _RefusingOrderStore extends OrderStore {
  _RefusingOrderStore(super.repository);
  @override
  Future<bool> addOrder(OrderModel order) async => false;
}
