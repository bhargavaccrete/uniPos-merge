import 'dart:async';
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
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/restaurant/stock_gate.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../helpers/open_session_fixture.dart';
import '../helpers/test_helpers.dart';

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// Batch 3, through the Captain endpoints as Captain calls them:
///
/// * SEC-2 / INVX-2 / INVX-3 — Modify only says which saved lines to keep;
///   everything else comes from the saved order, with the POS cancel rules.
/// * WF-7 — no Captain order outside an open POS day.
/// * INVX-4 — a saved order is cached and answered 200 even when a
///   display-only follow-up fails.
/// * SEC-20 — the body is read before the stock gate.
///
/// Order o1 (Dine In, T1): line a = 3 × Paneer @100 (KOT 1), line b = 2 ×
/// Paneer @50 (KOT 2). Paneer stock 5 is what is left after its placement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('captain_modify_');
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
    await Hive.openBox<ItemCancellationModel>(
        HiveBoxNames.restaurantItemCancellations);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal); // Captain sales and cancels are journaled
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await openRestaurantSessionForTest();

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
          () => OrderStore(locator<OrderRepository>()))
      ..registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness());
    // No TableStore is registered: the table display update fails, as any
    // display-only follow-up can (INVX-4).

    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    await items.put('paneer', Items(
      id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
      stockQuantity: 5, allowOrderWhenOutOfStock: false,
    ));
    await items.put('bun',
        Items(id: 'bun', name: 'Bun', trackInventory: true, stockQuantity: 4));
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

  CartItem a(int qty) => makeCartItem(
      id: 'a', productId: 'paneer', title: 'Paneer Tikka', price: 100,
      quantity: qty);
  CartItem b(int qty) => makeCartItem(
      id: 'b', productId: 'paneer', title: 'Paneer Tikka', price: 50,
      quantity: qty);

  Future<void> persist({
    List<CartItem>? lines,
    List<int> kotNumbers = const [1, 2],
    List<int> kotBoundaries = const [1, 2],
    Map<int, String> kotStatuses = const {1: 'Cooking', 2: 'Cooking'},
  }) async {
    final items = lines ?? [a(3), b(2)];
    final o = OrderModel(
      id: 'o1',
      customerName: '',
      customerNumber: '',
      customerEmail: '',
      items: items,
      status: 'Cooking',
      timeStamp: DateTime(2026, 11, 8, 12),
      orderType: 'Dine In',
      tableNo: 'T1',
      totalPrice: 400,
      kotNumbers: kotNumbers,
      itemCountAtLastKot: items.length,
      kotBoundaries: kotBoundaries,
      kotStatuses: kotStatuses,
      isTaxInclusive: false,
    );
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
  }

  OrderModel? saved() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1');
  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  List<ItemCancellationModel> cancellations() =>
      Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations)
          .values
          .toList();
  Map<dynamic, dynamic> counters() =>
      Map.of(Hive.box(HiveBoxNames.appCounters).toMap());

  /// Captain's Modify: every line of the order it loaded, kept or cancelled
  /// (captain_home_screen `_confirmUpdate`).
  Future<(int, Map<String, dynamic>)> modify(
    List<CartItem> kept,
    List<CartItem> cancelled, {
    String orderId = 'o1',
  }) async {
    final response = await captainModifyOrderHandler(
      Request(
        'PUT',
        Uri.parse('http://localhost/captain/orders/$orderId/modify'),
        body: jsonEncode({
          'updatedItems': kept.map((l) => l.toMap()).toList(),
          'cancelledItems': cancelled.map((l) => l.toMap()).toList(),
        }),
      ),
      orderId,
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  var seq = 0;
  CartItem paneer(int qty) => makeCartItem(
      id: 'new-${seq++}', productId: 'paneer', title: 'Paneer Tikka',
      price: 100, quantity: qty);

  Future<(int, Map<String, dynamic>)> send(List<CartItem> lines,
      {String? requestId, String? tableNo}) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': lines.map((l) => l.toMap()).toList(),
        'orderType': tableNo == null ? 'Take Away' : 'Dine In',
        'tableNo': ?tableNo,
        'totalPrice': 0,
        'requestId': ?requestId,
      }),
    ));
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  int orderCount() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).length;

  // ==========================================================================
  group('SEC-2 — Modify never deletes an order', () {
    test('every line cancelled: 409, order, stock and counters untouched',
        () async {
      await persist();
      final before = counters();
      final (status, body) = await modify([], [a(3), b(2)]);

      expect(status, 409);
      expect(body['error'], 'To cancel the whole order, void it on the POS.');
      expect(saved(), isNotNull);
      expect(saved()!.items.map((l) => l.quantity), [3, 2]);
      expect(stock('paneer'), 5);
      expect(cancellations(), isEmpty);
      expect(counters(), before, reason: 'no Cancel KOT number taken');
    });
  });

  // ==========================================================================
  group('INVX-2 / INVX-3 — Modify follows the saved order and POS rules', () {
    test('reduce a line: saved prices, KOT layout kept, restore once, audit '
        'row written', () async {
      await persist();
      // Captain's copy of line a carries a tampered price; the POS ignores it.
      final (status, body) =
          await modify([a(1).copyWith(price: 1), b(2)], [a(2)]);

      expect(status, 200, reason: body.toString());
      final o = saved()!;
      expect(o.items.map((l) => (l.id, l.quantity, l.price)),
          [('a', 1, 100.0), ('b', 2, 50.0)]);
      expect(o.kotNumbers, [1, 2]);
      expect(o.kotBoundaries, [1, 2]);
      expect(o.totalPrice, closeTo(200, 0.01),
          reason: '1 × 100 + 2 × 50 at SAVED prices');
      expect(stock('paneer'), 7, reason: '2 restored, once');

      final rows = cancellations();
      expect(rows, hasLength(1));
      expect(rows.single.quantity, 2);
      expect(rows.single.amount, 200);
      expect(rows.single.kotNumber, 1);
      expect(rows.single.orderId, 'o1');
      expect(rows.single.sessionId, 'test-session');

      expect(orderStore.getOrderById('o1')!.items.first.quantity, 1,
          reason: "the POS's in-memory order sees the Captain change");
    });

    test('remove a whole line: its KOT leaves the layout', () async {
      await persist();
      final (status, _) = await modify([b(2)], [a(3)]);

      expect(status, 200);
      final o = saved()!;
      expect(o.items.map((l) => l.id), ['b']);
      expect(o.kotNumbers, [2]);
      expect(o.kotBoundaries, [1]);
      expect(stock('paneer'), 8);
    });

    test('the same request again: 409, stock restored exactly once',
        () async {
      await persist();
      expect((await modify([a(1), b(2)], [a(2)])).$1, 200);
      final (status, body) = await modify([a(1), b(2)], [a(2)]);

      expect(status, 409);
      expect(body['error'], contains('changed on the POS'));
      expect(stock('paneer'), 7, reason: 'not 9');
      expect(cancellations(), hasLength(1));
    });

    test('a quantity above the saved one is refused, nothing written',
        () async {
      await persist();
      final before = counters();
      final (status, _) = await modify([a(5), b(2)], []);
      expect(status, 409);
      expect(saved()!.items.map((l) => l.quantity), [3, 2]);
      expect(stock('paneer'), 5);
      expect(counters(), before);
    });

    test('a line the order does not have is refused', () async {
      await persist();
      final ghost = makeCartItem(
          id: 'ghost', productId: 'paneer', title: 'Paneer Tikka', price: 100,
          quantity: 1);
      final (status, _) = await modify([a(3), b(2), ghost], []);
      expect(status, 409);
      expect(saved()!.items, hasLength(2));
    });

    test('a line added on the POS after Captain loaded the order: 409, the '
        'new line survives', () async {
      await persist(
        lines: [a(3), b(2), paneer(1).copyWith(id: 'c')],
        kotNumbers: [1, 2, 3],
        kotBoundaries: [1, 2, 3],
        kotStatuses: {1: 'Cooking', 2: 'Cooking', 3: 'Cooking'},
      );
      // Captain only knows a and b.
      final (status, _) = await modify([a(1), b(2)], [a(2)]);
      expect(status, 409);
      expect(saved()!.items.map((l) => l.id), ['a', 'b', 'c']);
      expect(stock('paneer'), 5);
    });

    test('cancelled list that disagrees with the kept quantities is refused',
        () async {
      await persist();
      // Keeps 1 of 3 but claims 3 cancelled — would restore 1 unit too many.
      final (status, _) = await modify([a(1), b(2)], [a(3)]);
      expect(status, 409);
      expect(stock('paneer'), 5);
      expect(saved()!.items.first.quantity, 3);
    });

    test('a line on a cooked KOT is refused; an uncooked one goes through',
        () async {
      await persist(kotStatuses: {1: 'Ready', 2: 'Cooking'});
      final (status, body) = await modify([a(1), b(2)], [a(2)]);
      expect(status, 409);
      expect(body['error'], contains('cooked'));
      expect(stock('paneer'), 5, reason: 'cooked food never back on the shelf');
      expect(cancellations(), isEmpty);

      final (ok, _) = await modify([a(3), b(1)], [b(1)]);
      expect(ok, 200);
      expect(stock('paneer'), 6);
    });

    test('restores from the SAVED stamp, never the stamp Captain sends',
        () async {
      // A burger line whose sale made 2 fresh (2 buns, 4 patties taken).
      final burger = makeCartItem(
              id: 'brg', productId: 'burger', title: 'Burger', price: 120,
              quantity: 2)
          .copyWith(ownStockQty: 0, freshQty: 2);
      await persist(
        lines: [burger, b(2)],
        kotStatuses: {1: 'Cooking', 2: 'Cooking'},
      );
      // Captain's copy claims the units came from prepared stock.
      final tampered = burger.copyWith(ownStockQty: 2, freshQty: 0);
      final (status, _) = await modify(
          [tampered.copyWith(quantity: 1), b(2)], [tampered.copyWith(quantity: 1)]);

      expect(status, 200);
      expect(stock('bun'), 5, reason: '1 burger back into its ingredients');
      expect(stock('patty'), 8);
      expect(saved()!.items.first.freshQty, 1, reason: 'stamp shrinks with it');
    });

    test('runs inside the stock gate: waits for a sale in progress', () async {
      await persist();
      final hold = Completer<void>();
      final held = StockGate.run(() => hold.future);
      final pending = modify([a(1), b(2)], [a(2)]);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(saved()!.items.first.quantity, 3, reason: 'not applied yet');
      expect(stock('paneer'), 5);
      hold.complete();
      await held;
      expect((await pending).$1, 200);
      expect(stock('paneer'), 7);
    });
  });

  // ==========================================================================
  group('WF-7 — Captain orders need an open POS day', () {
    test('no day started: 409, nothing written', () async {
      await Hive.box(HiveBoxNames.dayManagementBox).delete('currentSessionId');
      final before = counters();
      final (status, body) = await send([paneer(1)]);

      expect(status, 409);
      expect(body['error'], 'Start the day on the POS first.');
      expect(orderCount(), 0);
      expect(stock('paneer'), 5);
      expect(counters(), before);
    });

    test('End of Day overdue: 409, nothing written', () async {
      await openRestaurantSessionForTest(
          startTime: DateTime.now().subtract(const Duration(hours: 25)));
      final (status, body) = await send([paneer(1)]);

      expect(status, 409);
      expect(body['error'], 'Day has ended. Complete End of Day on the POS.');
      expect(orderCount(), 0);
      expect(stock('paneer'), 5);
    });

    test('a retry of an order taken before the day ended still gets its '
        'reply; a new order does not', () async {
      expect((await send([paneer(1)], requestId: 'r1')).$1, 200);
      await openRestaurantSessionForTest(
          startTime: DateTime.now().subtract(const Duration(hours: 25)));

      final (retry, body) = await send([paneer(1)], requestId: 'r1');
      expect(retry, 200);
      expect(body['duplicate'], isTrue);
      expect((await send([paneer(1)], requestId: 'r2')).$1, 409);
      expect(orderCount(), 1);
      expect(stock('paneer'), 4);
    });
  });

  // ==========================================================================
  group('INVX-4 — a saved order is answered and cached', () {
    test('a failing display follow-up (table status) still answers 200; the '
        'same request id returns the saved reply, no second order', () async {
      final (status, body) =
          await send([paneer(1)], requestId: 'r-table', tableNo: 'T9');
      expect(status, 200, reason: body.toString());
      expect(body['success'], isTrue);
      expect(orderCount(), 1);
      expect(stock('paneer'), 4);

      final (retry, again) =
          await send([paneer(1)], requestId: 'r-table', tableNo: 'T9');
      expect(retry, 200);
      expect(again['duplicate'], isTrue);
      expect(again['orderId'], body['orderId']);
      expect(orderCount(), 1, reason: 'no duplicate order');
      expect(stock('paneer'), 4, reason: 'no second deduction');
    });

    test('adding to an existing order: same guarantees', () async {
      await persist();
      final response = await captainSendOrderHandler(Request(
        'POST',
        Uri.parse('http://localhost/captain/send-order'),
        body: jsonEncode({
          'items': [paneer(1).toMap()],
          'orderType': 'Dine In',
          'tableNo': 'T1',
          'orderId': 'o1',
          'totalPrice': 0,
          'requestId': 'r-add',
        }),
      ));
      expect(response.statusCode, 200);
      await response.readAsString();
      final retry = await captainSendOrderHandler(Request(
        'POST',
        Uri.parse('http://localhost/captain/send-order'),
        body: jsonEncode({
          'items': [paneer(1).toMap()],
          'orderType': 'Dine In',
          'tableNo': 'T1',
          'orderId': 'o1',
          'totalPrice': 0,
          'requestId': 'r-add',
        }),
      ));
      expect(retry.statusCode, 200);
      expect(jsonDecode(await retry.readAsString())['duplicate'], isTrue);
      expect(saved()!.items, hasLength(3), reason: 'added once');
      expect(stock('paneer'), 4);
    });
  });

  // ==========================================================================
  group('SEC-20 — the body is read before the stock gate', () {
    test('a Captain request whose body has not arrived does not block a POS '
        'sale', () async {
      final body = StreamController<List<int>>();
      final captain = captainSendOrderHandler(Request(
        'POST',
        Uri.parse('http://localhost/captain/send-order'),
        body: body.stream,
      ));

      final sale = await StockGate.sell([paneer(1)], write: (_) async {})
          .timeout(const Duration(seconds: 2));
      expect(sale.refused, isFalse);
      expect(stock('paneer'), 4);

      body.add(utf8.encode(jsonEncode({
        'items': [paneer(1).toMap()],
        'orderType': 'Take Away',
        'totalPrice': 0,
      })));
      await body.close();
      expect((await captain).statusCode, 200);
      expect(stock('paneer'), 3);
    });

    test('a body that is not JSON: 400 without touching the gate', () async {
      final response = await captainSendOrderHandler(Request(
        'POST',
        Uri.parse('http://localhost/captain/send-order'),
        body: 'not json',
      ));
      expect(response.statusCode, 400);
      expect(orderCount(), 0);
    });
  });
}
