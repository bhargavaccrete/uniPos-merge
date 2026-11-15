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
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../../../helpers/business_fixture.dart';
import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

/// RECIPE — dishes made from a recipe were each checked against the WHOLE
/// ingredient stock, so two dishes sharing an ingredient, or a dish plus a
/// direct sale of that ingredient, passed together for more than is on hand.
///
/// Stock: bun 4, patty 6, cheese 3 (cheese also sold directly, "don't sell
/// when out"). Burger = bun + 2 patty; Slider = bun + cheese (both made to
/// order); Wrap = made in advance with 1 prepared, "make fresh when out",
/// recipe = 1 bun. Bun and patty keep the model default "sell when out of
/// stock" — an ingredient's own flag never decided what a dish can make.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recipe_shared_');
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
    await openRestaurantSessionForTest();
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

    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    await items.put('bun',
        Items(id: 'bun', name: 'Bun', trackInventory: true, stockQuantity: 4));
    await items.put('patty', Items(
        id: 'patty', name: 'Patty', trackInventory: true, stockQuantity: 6));
    await items.put('cheese', Items(
      id: 'cheese', name: 'Cheese', trackInventory: true, stockQuantity: 3,
      allowOrderWhenOutOfStock: false,
    ));
    await items.put('burger', Items(
      id: 'burger', name: 'Burger', productType: ProductType.recipeBased,
      allowOrderWhenOutOfStock: false,
    ));
    await items.put('slider', Items(
      id: 'slider', name: 'Slider', productType: ProductType.recipeBased,
      allowOrderWhenOutOfStock: false,
    ));
    await items.put('wrap', Items(
      id: 'wrap', name: 'Wrap', productType: ProductType.finishedGood,
      prepMode: ProductType.madeInAdvance, makeFreshWhenOut: true,
      trackInventory: true, stockQuantity: 1, allowOrderWhenOutOfStock: false,
    ));
    final recipes = Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await recipes.put('r-burger', RecipeModel(id: 'r-burger', itemId: 'burger',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'patty', quantity: 2),
        ]));
    await recipes.put('r-slider', RecipeModel(id: 'r-slider', itemId: 'slider',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'cheese', quantity: 1),
        ]));
    await recipes.put('r-wrap', RecipeModel(id: 'r-wrap', itemId: 'wrap',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
        ]));
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var seq = 0;
  CartItem line(String productId, int qty) => makeCartItem(
      id: 'line-${seq++}', productId: productId, title: productId,
      price: 10, quantity: qty);

  Future<List<StockShortfall>> check(List<CartItem> lines,
          {List<CartItem> returning = const []}) =>
      InventoryService.stockShortfalls(lines, returning: returning);

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;

  // ==========================================================================
  group('shared ingredients', () {
    test('each dish alone fits, together they need more buns than exist',
        () async {
      expect(await check([line('burger', 3)]), isEmpty);
      expect(await check([line('slider', 2)]), isEmpty);

      final s = await check([line('burger', 3), line('slider', 2)]);
      expect(s.single.itemId, 'bun');
      expect(s.single.name, 'Bun');
      expect(s.single.available, 4);
      expect(s.single.requested, 5, reason: '3 burgers + 2 sliders');
    });

    test('together within stock still passes', () async {
      expect(await check([line('burger', 2), line('slider', 2)]), isEmpty,
          reason: '4 buns, 4 patties, 2 cheese');
    });

    test('a dish over its own limit is still reported as the dish (unchanged)',
        () async {
      final s = await check([line('burger', 4), line('slider', 1)]);
      expect(s.single.name, 'Burger');
      expect(s.single.available, 3);
    });
  });

  group('direct sales combined with recipes', () {
    test('cheese sold directly and in sliders shares the same 3', () async {
      expect(await check([line('cheese', 2)]), isEmpty);
      expect(await check([line('slider', 2)]), isEmpty);
      final s = await check([line('cheese', 2), line('slider', 2)]);
      expect(s.single.itemId, 'cheese');
      expect(s.single.requested, 4);
      expect(s.single.available, 3);
    });

    test('an ingredient sold directly with "sell when out" is not limited, '
        'but what dishes make from it still is', () async {
      // Bun sells when out: a direct sale of 9 buns alone is never refused…
      expect(await check([line('bun', 9)]), isEmpty);
      // …and does not count against what the dishes can make.
      expect(await check([line('bun', 9), line('burger', 3)]), isEmpty);
      // The dishes together are still limited by the buns on hand.
      expect(await check([line('burger', 3), line('slider', 2)]), hasLength(1));
    });
  });

  group('hybrid (made in advance, make fresh when out)', () {
    test('prepared stock first: wrap ×1 takes no bun', () async {
      expect(await check([line('wrap', 1), line('burger', 3)]), isEmpty,
          reason: '1 prepared wrap + 3 burgers = 3 buns');
    });

    test('beyond prepared stock the wrap is made fresh from buns', () async {
      // 2 wraps = 1 prepared + 1 fresh bun; + 3 burgers = 4 buns: fits.
      expect(await check([line('wrap', 2), line('burger', 3)]), isEmpty);
      // 3 wraps = 1 prepared + 2 fresh; + 3 burgers = 5 buns: short.
      final s = await check([line('wrap', 3), line('burger', 3)]);
      expect(s.single.itemId, 'bun');
      expect(s.single.requested, 5);
    });
  });

  group('returned quantities (Place Order on an existing order)', () {
    test('a made-to-order dish handed back credits its ingredients', () async {
      expect(await check([line('burger', 3), line('slider', 2)]), isNotEmpty);
      // Reducing a burger by 1 in the same update hands back a bun.
      expect(
          await check([line('burger', 3), line('slider', 2)],
              returning: [line('burger', 1)]),
          isEmpty);
    });

    test('a returned direct sale credits the ingredient', () async {
      expect(
          await check([line('cheese', 2), line('slider', 2)],
              returning: [line('cheese', 1)]),
          isEmpty);
    });

    test('a hybrid handed back earns no ingredient credit (it may go back '
        'to prepared stock)', () async {
      final s = await check([line('wrap', 3), line('burger', 3)],
          returning: [line('wrap', 1)]);
      // Net 2 wraps: 1 prepared + 1 fresh; 3 burgers → 4 buns: fits.
      expect(s, isEmpty);
      final t = await check([line('wrap', 1), line('burger', 3), line('slider', 1)],
          returning: [line('wrap', 2)]);
      // Net −1 wrap credits nothing: 3 burgers + 1 slider = 4 buns: fits;
      // one more slider would not.
      expect(t, isEmpty);
      expect(
          await check(
              [line('wrap', 1), line('burger', 3), line('slider', 2)],
              returning: [line('wrap', 2)]),
          hasLength(1));
    });
  });

  // ==========================================================================
  group('through the Captain endpoint', () {
    Future<(int, Map<String, dynamic>)> send(List<CartItem> lines) async {
      final response = await captainSendOrderHandler(Request(
        'POST',
        Uri.parse('http://localhost/captain/send-order'),
        body: jsonEncode({
          'items': lines.map((l) => l.toMap()).toList(),
          'orderType': 'Take Away',
          'totalPrice': 0,
        }),
      ));
      return (
        response.statusCode,
        jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      );
    }

    test('two dishes sharing buns: 409, nothing taken', () async {
      final (status, body) = await send([line('burger', 3), line('slider', 2)]);
      expect(status, 409);
      expect(body['error'], contains('Bun'));
      expect(stock('bun'), 4);
      expect(stock('patty'), 6);
      expect(stock('cheese'), 3);
      expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).isEmpty,
          isTrue);
    });

    test('within stock: accepted, buns never below zero', () async {
      final (status, _) = await send([line('burger', 2), line('slider', 2)]);
      expect(status, 200);
      expect(stock('bun'), 0);
      expect(stock('patty'), 2);
      expect(stock('cheese'), 1);
    });
  });
}
