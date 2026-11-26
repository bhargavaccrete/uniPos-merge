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
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
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

class _Crash implements Exception {}

Future<void> _freezeJournal() =>
    Hive.box(HiveBoxNames.restaurantStockJournal).close();

class _Items extends ItemStore {
  _Items() : super(ItemRepository());

  /// The next stock write of this item fails (nothing written).
  String? failOnce;

  @override
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
    Future<void> Function(double before, double after)? beforePersist,
  }) {
    if (failOnce == itemId) {
      failOnce = null;
      throw StateError('disk full');
    }
    return super.applyStockDelta(
      itemId: itemId,
      variantId: variantId,
      delta: delta,
      lastPurchaseCost: lastPurchaseCost,
      beforePersist: beforePersist,
    );
  }
}

enum _Add { normal, crashBefore, crashAfter }

class _Orders extends OrderStore {
  _Orders(super.repository);
  _Add mode = _Add.normal;
  @override
  Future<bool> addOrder(OrderModel order) async {
    switch (mode) {
      case _Add.normal:
        return super.addOrder(order);
      case _Add.crashBefore:
        await _freezeJournal();
        throw _Crash();
      case _Add.crashAfter:
        await super.addOrder(order);
        await _freezeJournal();
        throw _Crash();
    }
  }
}

/// Batch 3.1 (4a) — a Captain send-order's stock goes through the Settle
/// journal: persisted before the order, finished exactly once after a
/// failure or a stop, dropped when the order never saved.
///
/// Bun stock 10, Patty stock 10.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _Items items;
  late _Orders orders;
  // The send-order request cache is process-wide: ids unique per test.
  late String run;

  Future<void> openWorld() async {
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

    items = _Items();
    orders = _Orders(OrderRepository());
    locator
      ..registerSingleton<ItemStore>(items)
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerSingleton<OrderStore>(orders)
      ..registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness());
    await itemStore.loadItems();
    await orderStore.loadOrders();
  }

  Future<void> restart() async {
    await locator.reset();
    await Hive.close();
    await openWorld();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('captain_journal_');
    run = '${DateTime.now().microsecondsSinceEpoch}';
    await openWorld();
    await openRestaurantSessionForTest();
    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    await box.put('bun',
        Items(id: 'bun', name: 'Bun', trackInventory: true, stockQuantity: 10));
    await box.put('patty', Items(
        id: 'patty', name: 'Patty', trackInventory: true, stockQuantity: 10));
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var seq = 0;
  CartItem bun(int q) => makeCartItem(
      id: 'bun-${seq++}', productId: 'bun', title: 'Bun', price: 10,
      quantity: q);
  CartItem patty(int q) => makeCartItem(
      id: 'patty-${seq++}', productId: 'patty', title: 'Patty', price: 20,
      quantity: q);

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
        'requestId': '$run-${requestId ?? 'r${seq++}'}',
      }),
    ));
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  int rows(String id) => StockMovementRepository().movementsForItem(id).length;
  int journal() => Hive.box(HiveBoxNames.restaurantStockJournal).length;
  int orderCount() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).length;

  test('no failure: deducted once, nothing left in the journal', () async {
    final (status, _) = await send([bun(2), patty(3)]);
    expect(status, 200);
    expect(stock('bun'), 8);
    expect(stock('patty'), 7);
    expect(journal(), 0);
  });

  test('the stock write fails part-way: 500 says saved, the rest finishes '
      'once at the next recovery', () async {
    items.failOnce = 'patty';
    final (status, body) = await send([bun(2), patty(3)]);

    expect(status, 500);
    expect(body['orderSaved'], isTrue);
    expect(body['error'], contains('Do not send it again'));
    expect(orderCount(), 1);
    expect(stock('bun'), 8);
    expect(stock('patty'), 10, reason: 'not yet');
    expect(journal(), 1);

    await StockJournal.recoverAll();
    expect(stock('bun'), 8, reason: 'never twice');
    expect(stock('patty'), 7);
    expect(rows('bun'), 1);
    expect(rows('patty'), 1);
    expect(journal(), 0);

    await StockJournal.recoverAll();
    expect(stock('patty'), 7);
  });

  test('a retry with the same request id after that failure: the saved '
      'reply, no second order or deduction', () async {
    items.failOnce = 'patty';
    await send([bun(2), patty(3)], requestId: 'same');
    final (status, body) = await send([bun(2), patty(3)], requestId: 'same');
    expect(status, 200);
    expect(body['duplicate'], isTrue);
    expect(orderCount(), 1);
    expect(stock('bun'), 8);
  });

  test('adding to an existing order: same journal guarantees', () async {
    await send([bun(1)], requestId: 'first', tableNo: 'T1');
    expect(stock('bun'), 9);

    items.failOnce = 'patty';
    final (status, body) =
        await send([bun(2), patty(3)], requestId: 'second', tableNo: 'T1');
    expect(status, 500);
    expect(body['orderSaved'], isTrue);
    expect(orderCount(), 1);
    expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).values.single
        .items, hasLength(3));
    expect(stock('patty'), 10);

    await StockJournal.recoverAll();
    expect(stock('bun'), 7);
    expect(stock('patty'), 7);
    expect(journal(), 0);
  });

  test('adding to an existing order refreshes the POS\'s in-memory copy',
      () async {
    final (_, first) = await send([bun(1)], requestId: 'first', tableNo: 'T1');
    await send([patty(1)], requestId: 'second', tableNo: 'T1');
    expect(orderStore.getOrderById(first['orderId'] as String)!.items,
        hasLength(2));
  });

  test('adding to an existing order, the write fails before it lands: the '
      'entry is dropped at recovery, no stock moves', () async {
    await send([bun(1)], requestId: 'first', tableNo: 'T1');
    expect(stock('bun'), 9);
    // The add-on KOT number cannot be read: the append stops before its
    // order write, after its journal entry.
    await Hive.box(HiveBoxNames.appCounters).close();
    final (status, _) =
        await send([bun(2)], requestId: 'second', tableNo: 'T1');
    expect(status, 500);
    await restart();
    expect(journal(), 1);
    expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).values.single
        .items, hasLength(1));

    await StockJournal.recoverAll();
    expect(journal(), 0);
    expect(stock('bun'), 9);
  });

  test('a stop before the order save: the entry is dropped, no stock moves',
      () async {
    orders.mode = _Add.crashBefore;
    final (status, _) = await send([bun(2), patty(3)]);
    expect(status, 500);
    await restart();
    expect(journal(), 1);
    expect(orderCount(), 0);

    await StockJournal.recoverAll();
    expect(journal(), 0);
    expect(stock('bun'), 10);
    expect(stock('patty'), 10);
  });

  test('a stop after the order save: recovery deducts exactly once',
      () async {
    orders.mode = _Add.crashAfter;
    await send([bun(2), patty(3)]);
    await restart();
    expect(orderCount(), 1);
    expect(stock('bun'), 10, reason: 'nothing deducted yet');

    await StockJournal.recoverAll();
    expect(stock('bun'), 8);
    expect(stock('patty'), 7);
    expect(journal(), 0);
    await StockJournal.recoverAll();
    expect(stock('bun'), 8);
  });
}
