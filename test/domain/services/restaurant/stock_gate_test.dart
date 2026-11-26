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
import 'package:billberrylite/domain/services/restaurant/stock_gate.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../../../helpers/business_fixture.dart';
import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

/// S-04A — POS orders (Takeaway / Dine-in Place Order, Quick Settle) and
/// Captain orders share ONE stock gate: a check and its deduction are a
/// single operation, so no two orders can both pass against the same stock.
///
/// A "POS order" here is exactly what those screens now run:
/// `StockGate.sell(lines, write: <save the order with the plan's lines>)`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stock_gate_');
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

  var seq = 0;
  CartItem paneer(int qty) => makeCartItem(
      id: 'line-${seq++}', productId: 'paneer', title: 'Paneer Tikka',
      price: 100, quantity: qty);

  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;
  int orders() => Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).length;
  int movements() =>
      StockMovementRepository().movementsForItem('paneer').length;

  /// A POS Place Order, as takeaway.dart runs it. [beforeSave] runs inside
  /// the write — the window between check and deduction a rival order would
  /// otherwise slip into.
  Future<GatedSale> posOrder(int qty,
      {Future<void> Function()? beforeSave, bool failWrite = false}) {
    final lines = [paneer(qty)];
    return StockGate.sell(lines, write: (plan) async {
      final kot = await orderStore.getNextKotNumber();
      await beforeSave?.call();
      if (failWrite) throw StateError('order save failed');
      await orderStore.addOrder(OrderModel(
        id: 'pos-${seq++}',
        customerName: 'Walk-in',
        customerNumber: '',
        customerEmail: '',
        items: plan.lines,
        status: 'Processing',
        timeStamp: DateTime.now(),
        orderType: 'Take Away',
        totalPrice: 100.0 * qty,
        kotNumbers: [kot],
        itemCountAtLastKot: 1,
        kotBoundaries: [1],
      ));
    });
  }

  Future<int> captainOrder(int qty, {String? requestId}) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': [paneer(qty).toMap()],
        'orderType': 'Take Away',
        'totalPrice': 0,
        'requestId': ?requestId,
      }),
    ));
    await response.readAsString();
    return response.statusCode;
  }

  /// A tick for the event loop — lets a rival request get as far as it can.
  Future<void> yieldTurns() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // ==========================================================================
  group('5 in stock, two orders for 4 each — exactly one succeeds', () {
    test('POS order and Captain order (POS starts first)', () async {
      final pos = posOrder(4, beforeSave: yieldTurns);
      final captain = captainOrder(4);
      final posResult = await pos;
      final captainStatus = await captain;

      expect(posResult.refused, isFalse);
      expect(captainStatus, 409, reason: 'checked after the POS deduction');
      expect(stock(), 1, reason: 'never 5 - 8 = -3');
      expect(orders(), 1);
      expect(movements(), 1);
    });

    test('Captain order and POS order (Captain starts first)', () async {
      final captain = captainOrder(4);
      // SEC-20: Captain reads its body BEFORE queueing for the gate, so let
      // it arrive before the POS order starts.
      await yieldTurns();
      final pos = posOrder(4);
      final captainStatus = await captain;
      final posResult = await pos;

      expect(captainStatus, 200);
      expect(posResult.refused, isTrue);
      expect(posResult.message, contains('available 1'));
      expect(stock(), 1);
      expect(orders(), 1);
    });

    test('two POS orders', () async {
      final results = await Future.wait([
        posOrder(4, beforeSave: yieldTurns),
        posOrder(4, beforeSave: yieldTurns),
      ]);
      expect(results.where((r) => !r.refused), hasLength(1));
      expect(stock(), 1);
      expect(orders(), 1);
    });

    test('two Captain orders', () async {
      final statuses = await Future.wait([captainOrder(4), captainOrder(4)]);
      expect(statuses..sort(), [200, 409]);
      expect(stock(), 1);
      expect(orders(), 1);
    });
  });

  // ==========================================================================
  group('the gate covers the write AND the deduction', () {
    test('a Captain order waits while a POS order is between its check and '
        'its deduction', () async {
      final hold = Completer<void>();
      final pos = posOrder(4, beforeSave: () => hold.future);
      var captainDone = false;
      final captain = captainOrder(1).then((s) {
        captainDone = true;
        return s;
      });

      await yieldTurns();
      expect(captainDone, isFalse, reason: 'queued behind the POS order');
      expect(stock(), 5, reason: 'POS has checked but not yet deducted');

      hold.complete();
      expect((await pos).refused, isFalse);
      expect(await captain, 200, reason: '1 left after the POS order');
      expect(stock(), 0);
    });
  });

  // ==========================================================================
  group('failure and retry', () {
    test('a failed order releases the gate; nothing was deducted', () async {
      await expectLater(posOrder(4, failWrite: true), throwsStateError);
      expect(stock(), 5, reason: 'no deduction without a saved order');
      expect(movements(), 0);

      // The next orders are not blocked.
      expect((await posOrder(2)).refused, isFalse);
      expect(await captainOrder(1), 200);
      expect(stock(), 2);
    });

    test('a POS retry after a failed save deducts exactly once', () async {
      await expectLater(posOrder(3, failWrite: true), throwsStateError);
      expect((await posOrder(3)).refused, isFalse);
      expect(stock(), 2);
      expect(movements(), 1);
    });

    test('a Captain double send (same requestId, at once) is one order, '
        'deducted once', () async {
      final statuses = await Future.wait([
        captainOrder(2, requestId: 'req-1'),
        captainOrder(2, requestId: 'req-1'),
      ]);
      expect(statuses, [200, 200]);
      expect(orders(), 1);
      expect(stock(), 3);
      expect(movements(), 1);
    });

    test('a refused order writes nothing and the retry is checked again',
        () async {
      final first = await posOrder(6);
      expect(first.refused, isTrue);
      expect(orders(), 0);
      expect(Hive.box(HiveBoxNames.appCounters).isEmpty, isTrue,
          reason: 'no KOT number taken for a refused order');
      await itemStore.applyStockDelta(itemId: 'paneer', delta: 1);
      expect((await posOrder(6)).refused, isFalse);
      expect(stock(), 0);
    });
  });

  // ==========================================================================
  group('normal orders and nesting', () {
    test('valid orders go through and deduct as before', () async {
      final r = await posOrder(2);
      expect(r.refused, isFalse);
      expect(stock(), 3);
      final saved = Hive.box<OrderModel>(HiveBoxNames.restaurantOrders)
          .values
          .single
          .items
          .single;
      expect(saved.ownStockQty, 2, reason: 'the plan stamp is saved');
      expect(await captainOrder(3), 200);
      expect(stock(), 0);
    });

    test('a gated operation that calls the gate again does not deadlock',
        () async {
      final result = await StockGate.run(() async {
        expect(StockGate.isHeld, isTrue);
        return StockGate.run(() async => 'inner');
      }).timeout(const Duration(seconds: 2));
      expect(result, 'inner');
      expect(StockGate.isHeld, isFalse);
    });
  });
}
