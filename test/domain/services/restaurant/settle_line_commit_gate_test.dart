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
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/settle_line_commit.dart';
import 'package:billberrylite/domain/services/restaurant/stock_gate.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../../../helpers/business_fixture.dart';
import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

/// Fails a chosen item's next stock write — a deduction stopping part-way.
class _FlakyItemStore extends ItemStore {
  _FlakyItemStore() : super(ItemRepository());

  final Set<String> failNextWrite = {};

  @override
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
    Future<void> Function(double before, double after)? beforePersist,
  }) async {
    if (failNextWrite.remove(itemId)) {
      throw StateError('simulated stock write failure for $itemId');
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

/// S-04C — Settle on an EXISTING order (SettleLineCommit) checks the stock
/// its increases and new lines need, inside the shared StockGate, before any
/// write of the settle.
///
/// Paneer: 5 on hand AFTER the saved order's own line left at placement;
/// "don't sell when out of stock".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _FlakyItemStore items;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settle_gate_');
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
    await openRestaurantSessionForTest(); // WF-7: Captain orders need an open day
    registerNoTaxBusinessForTest(); // Captain orders are priced by the POS
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);

    items = _FlakyItemStore();
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
      ..registerLazySingleton<OrderStore>(
          () => OrderStore(locator<OrderRepository>()));

    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
      'paneer',
      Items(
        id: 'paneer',
        name: 'Paneer Tikka',
        trackInventory: true,
        stockQuantity: 5,
        allowOrderWhenOutOfStock: false,
      ),
    );
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CartItem line(String id, int qty) => makeCartItem(
      id: id, productId: 'paneer', title: 'Paneer Tikka', price: 100,
      quantity: qty);

  OrderModel order(String id, List<CartItem> lines) => OrderModel(
        id: id,
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: lines,
        status: 'Cooking',
        timeStamp: DateTime(2026, 11, 5, 12),
        orderType: 'Dine In',
        tableNo: 'T1',
        totalPrice: 0,
        kotNumbers: [1],
        itemCountAtLastKot: lines.length,
        kotBoundaries: [lines.length],
        kotStatuses: {1: 'Cooking'},
      );

  Future<OrderModel> persist(OrderModel o) async {
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
    return o;
  }

  OrderModel saved(String id) =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get(id)!;
  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;
  int movements() =>
      StockMovementRepository().movementsForItem('paneer').length;

  Future<int> captainOrder(int qty) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': [line('cap-${DateTime.now().microsecondsSinceEpoch}', qty).toMap()],
        'orderType': 'Take Away',
        'totalPrice': 0,
      }),
    ));
    await response.readAsString();
    return response.statusCode;
  }

  // ==========================================================================
  test('sufficient stock: the increase and the new line settle as before',
      () async {
    final o = await persist(order('o1', [line('a', 1)]));
    final r = await SettleLineCommit.commit(
        snapshot: o, itemsToSettle: [line('a', 3), line('b', 2)]);

    expect(stock(), 1, reason: '5 - (2 increase + 2 new)');
    expect(movements(), 2);
    expect(r.newKotNumber, isNotNull);
    expect(saved('o1').items.map((c) => c.quantity), [3, 2]);
    expect(StockJournal.all(), isEmpty);
  });

  group('insufficient stock: refused before ANY write of the settle', () {
    Future<void> expectRefused(List<CartItem> settleLines) async {
      final o = await persist(order('o1', [line('a', 1)]));
      final countersBefore = Hive.box(HiveBoxNames.appCounters).toMap();

      await expectLater(
        SettleLineCommit.commit(snapshot: o, itemsToSettle: settleLines),
        throwsA(isA<SettleStockShortException>()
            .having((e) => e.message, 'message', contains('available 5'))),
      );

      expect(saved('o1').items.map((c) => c.quantity), [1],
          reason: 'order lines unchanged');
      expect(saved('o1').kotNumbers, [1], reason: 'no add-on KOT');
      expect(Hive.box(HiveBoxNames.appCounters).toMap(), countersBefore,
          reason: 'no KOT number taken');
      expect(StockJournal.all(), isEmpty, reason: 'no journal entry');
      expect(stock(), 5);
      expect(movements(), 0);
    }

    test('a new line beyond stock', () =>
        expectRefused([line('a', 1), line('b', 6)]));

    test('an increase beyond stock (only the DELTA is asked for)', () =>
        expectRefused([line('a', 7)]));

    test('increase + new line together beyond stock', () =>
        expectRefused([line('a', 4), line('b', 3)]));
  });

  test('the delta, not the full line, is checked', () async {
    // Saved 1; settling 6 asks for 5 more — exactly what is on hand.
    final o = await persist(order('o1', [line('a', 1)]));
    await SettleLineCommit.commit(snapshot: o, itemsToSettle: [line('a', 6)]);
    expect(stock(), 0);
  });

  group('5 in stock, two sales for 4 — exactly one succeeds', () {
    Future<bool> settleAdding4() async {
      final o = await persist(order('o1', [line('a', 1)]));
      try {
        await SettleLineCommit.commit(
            snapshot: o, itemsToSettle: [line('a', 1), line('b', 4)]);
        return true;
      } on SettleStockShortException {
        return false;
      }
    }

    test('Settle and a Captain order', () async {
      final results = await Future.wait<Object>([settleAdding4(), captainOrder(4)]);
      final settled = results[0] as bool;
      final captain = results[1] as int;
      expect([settled, captain == 200].where((ok) => ok), hasLength(1));
      expect(stock(), 1, reason: 'never 5 - 8 = -3');
    });

    test('a Captain order first, then Settle', () async {
      final captain = captainOrder(4);
      final settled = settleAdding4();
      expect(await captain, 200);
      expect(await settled, isFalse);
      expect(stock(), 1);
      expect(saved('o1').items, hasLength(1), reason: 'settle wrote nothing');
    });

    test('Settle and a Place Order (StockGate.sell)', () async {
      final results = await Future.wait<Object>([
        settleAdding4(),
        StockGate.sell([line('pos', 4)], write: (_) async {}),
      ]);
      final settled = results[0] as bool;
      final placed = results[1] as GatedSale;
      expect([settled, !placed.refused].where((ok) => ok), hasLength(1));
      expect(stock(), 1);
    });
  });

  test('a failed order save deducts nothing and releases the gate', () async {
    final o = await persist(order('o1', [line('a', 1)]));
    orderStore; // built while the box is open
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).close();

    await expectLater(
      SettleLineCommit.commit(
          snapshot: o, itemsToSettle: [line('a', 1), line('b', 2)]),
      throwsException,
    );
    expect(stock(), 5, reason: 'nothing moves when the save fails');
    expect(movements(), 0);
    expect(StockJournal.all(), isEmpty);

    // The gate is free for the next sale.
    final next = await StockGate.sell([line('pos', 2)], write: (_) async {})
        .timeout(const Duration(seconds: 2));
    expect(next.refused, isFalse);
    expect(stock(), 3);
  });

  group('interrupted and retried settle', () {
    test('a deduction that stops part-way is finished by the retry, once, '
        'without being re-checked', () async {
      final o = await persist(order('o1', [line('a', 1)]));
      final settleLines = [line('a', 1), line('b', 4)];
      items.failNextWrite.add('paneer');

      SettlePendingStock? pending;
      try {
        await SettleLineCommit.commit(snapshot: o, itemsToSettle: settleLines);
      } on SettleStockIncompleteException catch (e) {
        pending = e.pending;
      }
      expect(pending, isNotNull);
      expect(saved('o1').items, hasLength(2), reason: 'lines saved first');
      expect(stock(), 5, reason: 'the 4 are owed, not yet deducted');

      final r = await SettleLineCommit.commit(
          snapshot: o, itemsToSettle: settleLines, pending: pending);
      expect(stock(), 1);
      expect(movements(), 1);
      expect(r.newKotNumber, pending!.result.newKotNumber);
      expect(StockJournal.all(), isEmpty);
    });

    test('stock still owed by an interrupted settle is NOT sold again: the '
        'next settle finishes it first, then checks', () async {
      final o1 = await persist(order('o1', [line('a', 1)]));
      items.failNextWrite.add('paneer');
      await expectLater(
        SettleLineCommit.commit(
            snapshot: o1, itemsToSettle: [line('a', 1), line('b', 4)]),
        throwsA(isA<SettleStockIncompleteException>()),
      );
      expect(stock(), 5, reason: '4 owed');

      final o2 = await persist(order('o2', [line('x', 1)]));
      await expectLater(
        SettleLineCommit.commit(
            snapshot: o2, itemsToSettle: [line('x', 1), line('y', 4)]),
        throwsA(isA<SettleStockShortException>()
            .having((e) => e.message, 'message', contains('available 1'))),
      );
      expect(stock(), 1, reason: 'the owed 4 were deducted, o2 refused');
      expect(saved('o2').items, hasLength(1));
    });
  });

  test('called from inside the gate it does not deadlock', () async {
    final o = await persist(order('o1', [line('a', 1)]));
    await StockGate.run(() => SettleLineCommit.commit(
            snapshot: o, itemsToSettle: [line('a', 2)]))
        .timeout(const Duration(seconds: 2));
    expect(stock(), 4);
  });
}
