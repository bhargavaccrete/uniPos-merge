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
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../helpers/business_fixture.dart';
import '../helpers/open_session_fixture.dart';
import '../helpers/test_helpers.dart';

/// Batch 3.2c — the POS's in-memory duplicate cache also keeps a fingerprint
/// of the request: the same `requestId` with the same request gets the saved
/// reply; with a different request (items, quantity, table, target order)
/// it gets 409 `requestIdReused`, and nothing is written.
///
/// The cache is process-wide, so every test uses its own request ids.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('captain_fingerprint_');
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
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);
    await openRestaurantSessionForTest();
    registerNoTaxBusinessForTest();

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

    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'dish',
        Items(id: 'dish', name: 'Dish', price: 100, trackInventory: true,
            stockQuantity: 100));
    // Captain lines are priced from the menu (AND-04): every product a test
    // orders must be on it.
    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'dish2',
        Items(id: 'dish2', name: 'Dish 2', price: 100, trackInventory: true,
            stockQuantity: 100));
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var ids = 0;
  String newId() => 'fp-${DateTime.now().microsecondsSinceEpoch}-${ids++}';

  Map<String, dynamic> line(String id, int qty) => makeCartItem(
          id: id, productId: 'dish', title: 'Dish', price: 100, quantity: qty)
      .toMap();
  Map<String, dynamic> other(String id, int qty) => makeCartItem(
          id: id, productId: 'dish2', title: 'Dish 2', price: 100,
          quantity: qty)
      .toMap();

  Map<String, dynamic> body(String requestId,
          {List<Map<String, dynamic>>? items,
          String? tableNo,
          String? orderId,
          String orderType = 'Take Away'}) =>
      {
        'items': items ?? [line('a', 2)],
        'orderType': orderType,
        'tableNo': tableNo,
        'orderId': ?orderId,
        'totalPrice': 200,
        'staffId': 's1',
        'requestId': requestId,
      };

  Future<(int, Map<String, dynamic>)> sendRaw(String raw) async {
    final res = await captainSendOrderHandler(Request(
        'POST', Uri.parse('http://localhost/captain/send-order'),
        body: raw));
    return (
      res.statusCode,
      jsonDecode(await res.readAsString()) as Map<String, dynamic>
    );
  }

  Future<(int, Map<String, dynamic>)> send(Map<String, dynamic> b) =>
      sendRaw(jsonEncode(b));

  Box<OrderModel> orders() => Hive.box<OrderModel>(HiveBoxNames.restaurantOrders);
  Object? lastKot() => Hive.box(HiveBoxNames.appCounters).get('lastKotNumber');
  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('dish')!.stockQuantity;

  // ==========================================================================
  group('new order', () {
    test('same ID, byte-identical request: the saved reply, one order, one KOT',
        () async {
      final raw = jsonEncode(body(newId()));
      final (s1, r1) = await sendRaw(raw);
      final (s2, r2) = await sendRaw(raw);

      expect(s1, 200);
      expect(s2, 200);
      expect(r2['duplicate'], isTrue);
      expect(r2['orderId'], r1['orderId']);
      expect(r2['kotNumber'], r1['kotNumber']);
      expect(orders().length, 1);
      expect(lastKot(), 1);
      expect(stock(), 98, reason: 'deducted once');
    });

    test('same ID, same request in a different key order: still the same',
        () async {
      final id = newId();
      final b = body(id);
      await send(b);
      final reordered = {
        for (final k in b.keys.toList().reversed) k: b[k],
      };
      final (s, r) = await send(reordered);
      expect(s, 200);
      expect(r['duplicate'], isTrue);
      expect(orders().length, 1);
    });

    for (final (what, change) in <(String, Map<String, dynamic> Function(String))>[
      ('a changed quantity', (id) => body(id, items: [line('a', 3)])),
      ('a changed item', (id) => body(id, items: [other('a', 2)])),
      ('only the product changed (same name, price)',
          (id) => body(id, items: [
                makeCartItem(id: 'a', productId: 'dish-b', title: 'Dish',
                        price: 100, quantity: 2)
                    .toMap()
              ])),
      ('an extra item', (id) => body(id, items: [line('a', 2), line('c', 1)])),
      ('a changed table',
          (id) => body(id, tableNo: 'T9', orderType: 'Dine In')),
    ]) {
      test('same ID with $what: 409 requestIdReused, nothing written',
          () async {
        final id = newId();
        final (s1, _) = await send(body(id));
        expect(s1, 200);
        final kotAfterFirst = lastKot();
        final stockAfterFirst = stock();

        final (s2, r2) = await send(change(id));

        expect(s2, 409);
        expect(r2['success'], isFalse);
        expect(r2['requestIdReused'], isTrue);
        expect(r2['duplicate'], isNull, reason: 'never the old reply');
        expect(orders().length, 1);
        expect(lastKot(), kotAfterFirst, reason: 'no KOT number taken');
        expect(stock(), stockAfterFirst);
      });
    }

    test('same ID, only the table changed: 409, nothing written', () async {
      final id = newId();
      final (s1, _) =
          await send(body(id, tableNo: 'T1', orderType: 'Dine In'));
      expect(s1, 200);
      final kot = lastKot();

      final (s2, r2) =
          await send(body(id, tableNo: 'T9', orderType: 'Dine In'));

      expect(s2, 409);
      expect(r2['requestIdReused'], isTrue);
      expect(orders().length, 1);
      expect(orders().values.single.tableNo, 'T1');
      expect(lastKot(), kot);
    });

    test('same ID, same content with regenerated line ids: the saved reply',
        () async {
      final id = newId();
      await send(body(id, items: [line('a1', 2), other('b1', 1)]));
      final (s, r) =
          await send(body(id, items: [line('a2', 2), other('b2', 1)]));
      expect(s, 200);
      expect(r['duplicate'], isTrue);
      expect(orders().length, 1);
      expect(lastKot(), 1);
    });

    test('same ID, the same lines in another order: 409 (order is kept)',
        () async {
      final id = newId();
      await send(body(id, items: [line('a', 2), other('b', 1)]));
      final (s, _) =
          await send(body(id, items: [other('b', 1), line('a', 2)]));
      expect(s, 409);
      expect(orders().length, 1);
    });

    test('different IDs with the same request are two orders (the ID decides)',
        () async {
      await send(body(newId()));
      await send(body(newId()));
      expect(orders().length, 2);
    });
  });

  // ==========================================================================
  // An order saved under a fixed id, so add-items can target it.
  Future<void> persistOrder(String id) async {
    final first = await send(body(newId()));
    expect(first.$1, 200);
    // Re-key under a fixed id so add-items can target it.
    final created = orders().get(first.$2['orderId'])!;
    await orders().delete(created.id);
    await orders().put(id, created.copyWith(id: id));
    await orderStore.loadOrders();
  }

  group('add items', () {
    test('same ID, same add-items request: one new KOT, the saved reply',
        () async {
      await persistOrder('o1');
      final raw = jsonEncode(body(newId(), items: [line('x', 1)], orderId: 'o1'));
      final (s1, r1) = await sendRaw(raw);
      final (s2, r2) = await sendRaw(raw);

      expect(s1, 200);
      expect(r1['addedToExisting'], isTrue);
      expect(s2, 200);
      expect(r2['duplicate'], isTrue);
      expect(orders().get('o1')!.kotNumbers, hasLength(2));
      expect(orders().get('o1')!.items.where((l) => l.id == 'x'), hasLength(1));
    });

    test('same ID with a changed target order: 409, nothing added anywhere',
        () async {
      await persistOrder('o1');
      await persistOrder('o2');
      final id = newId();
      await send(body(id, items: [line('x', 1)], orderId: 'o1'));
      final kot = lastKot();

      final (s, r) = await send(body(id, items: [line('x', 1)], orderId: 'o2'));

      expect(s, 409);
      expect(r['requestIdReused'], isTrue);
      expect(orders().get('o2')!.kotNumbers, hasLength(1));
      expect(orders().get('o1')!.kotNumbers, hasLength(2));
      expect(lastKot(), kot);
    });

    test('same ID with a changed add-items quantity: 409', () async {
      await persistOrder('o1');
      final id = newId();
      await send(body(id, items: [line('x', 1)], orderId: 'o1'));
      final (s, r) = await send(body(id, items: [line('x', 2)], orderId: 'o1'));
      expect(s, 409);
      expect(r['requestIdReused'], isTrue);
      expect(orders().get('o1')!.items.firstWhere((l) => l.id == 'x').quantity,
          1);
    });
  });

  // ==========================================================================
  group('concurrent duplicates (the stock lock serialises them)', () {
    test('two identical requests at once: one order, one KOT', () async {
      final raw = jsonEncode(body(newId()));
      final results = await Future.wait([sendRaw(raw), sendRaw(raw)]);

      expect(results.map((r) => r.$1), everyElement(200));
      expect(results.where((r) => r.$2['duplicate'] == true), hasLength(1));
      expect(results[0].$2['orderId'], results[1].$2['orderId']);
      expect(orders().length, 1);
      expect(lastKot(), 1);
      expect(stock(), 98);
    });

    test('same ID, different requests at once: one order, the other 409',
        () async {
      final id = newId();
      final results = await Future.wait(
          [send(body(id)), send(body(id, items: [line('a', 5)]))]);

      expect(results.map((r) => r.$1).toList()..sort(), [200, 409]);
      expect(orders().length, 1);
      expect(lastKot(), 1);
    });

    test('three identical add-items requests at once: one new KOT', () async {
      await persistOrder('o1');
      final raw =
          jsonEncode(body(newId(), items: [line('x', 1)], orderId: 'o1'));
      final results = await Future.wait([sendRaw(raw), sendRaw(raw), sendRaw(raw)]);

      expect(results.map((r) => r.$1), everyElement(200));
      expect(results.where((r) => r.$2['duplicate'] == true), hasLength(2));
      expect(orders().get('o1')!.kotNumbers, hasLength(2));
    });
  });
}
