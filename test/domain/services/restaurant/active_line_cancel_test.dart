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
import 'package:billberrylite/domain/services/restaurant/active_line_cancel.dart';
import 'package:billberrylite/domain/services/restaurant/order_concurrency.dart';
import 'package:billberrylite/domain/services/restaurant/stock_gate.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/services/restaurant/void_order_commit.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

class _TaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// The process stopping at that point. The journal box is closed at that
/// instant, so nothing written afterwards reaches it — the journal is
/// exactly what a real stop would leave.
class _Crash implements Exception {}

Future<void> _freezeJournal() =>
    Hive.box(HiveBoxNames.restaurantStockJournal).close();

enum _Write { normal, crashBefore, crashAfter, falseButSaved, falseNotSaved }

class _Orders extends OrderStore {
  _Orders(super.repository);
  _Write mode = _Write.normal;

  Future<bool> _apply(Future<bool> Function() write) async {
    switch (mode) {
      case _Write.normal:
        return write();
      case _Write.crashBefore:
        await _freezeJournal();
        throw _Crash();
      case _Write.crashAfter:
        await write();
        await _freezeJournal();
        throw _Crash();
      case _Write.falseButSaved:
        await write();
        return false;
      case _Write.falseNotSaved:
        return false;
    }
  }

  @override
  Future<bool> updateOrder(OrderModel order) =>
      _apply(() => super.updateOrder(order));

  @override
  Future<bool> deleteOrder(String orderId) =>
      _apply(() => super.deleteOrder(orderId));
}

class _CrashingItems extends ItemStore {
  _CrashingItems() : super(ItemRepository());
  String? crashAfterWrite;

  @override
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
    Future<void> Function(double before, double after)? beforePersist,
  }) async {
    final balance = await super.applyStockDelta(
      itemId: itemId,
      variantId: variantId,
      delta: delta,
      lastPurchaseCost: lastPurchaseCost,
      beforePersist: beforePersist,
    );
    if (crashAfterWrite == itemId) {
      crashAfterWrite = null;
      await _freezeJournal();
      throw _Crash();
    }
    return balance;
  }
}

/// Batch 3.1 — Takeaway's immediate cancel and Active Orders' single-item
/// cancel ([ActiveLineCancel]): the SAVED order, inside the stock gate, the
/// stock return journaled so a stop at any point returns it exactly once.
///
/// Order o1 (Dine In, T1): line a = 3 × Paneer @100 (KOT 1), line b = 2 ×
/// Paneer @50 (KOT 2). Paneer stock 5 is what is left after placement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _Orders orders;
  late _CrashingItems items;

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
    await Hive.openBox<ItemCancellationModel>(
        HiveBoxNames.restaurantItemCancellations);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);

    items = _CrashingItems();
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
      ..registerSingleton<BusinessDetailsRepository>(_TaxBusiness());
    await itemStore.loadItems();
    await orderStore.loadOrders();
  }

  Future<void> restart() async {
    await locator.reset();
    await Hive.close();
    await openWorld();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('active_line_cancel_');
    await openWorld();
    await openRestaurantSessionForTest();
    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'paneer',
        Items(id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
            stockQuantity: 5));
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

  OrderModel order({
    List<CartItem>? lines,
    List<int> kotNumbers = const [1, 2],
    List<int> kotBoundaries = const [1, 2],
    Map<int, String> kotStatuses = const {1: 'Cooking', 2: 'Cooking'},
    bool inclusive = false,
  }) {
    final l = lines ?? [a(3), b(2)];
    return OrderModel(
      id: 'o1',
      customerName: '',
      customerNumber: '',
      customerEmail: '',
      items: l,
      status: 'Cooking',
      timeStamp: DateTime(2026, 11, 11, 12),
      orderType: 'Dine In',
      tableNo: 'T1',
      totalPrice: 400,
      kotNumbers: kotNumbers,
      itemCountAtLastKot: l.length,
      kotBoundaries: kotBoundaries,
      kotStatuses: kotStatuses,
      isTaxInclusive: inclusive,
    );
  }

  Future<void> persist([OrderModel? o]) async {
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders)
        .put('o1', o ?? order());
    await orderStore.loadOrders();
  }

  /// Another device's write: straight to the box, as Captain's HiveOrders
  /// does — the POS's in-memory copy does not see it.
  Future<void> writeBehindPos(OrderModel o) =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);

  OrderModel? saved() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1');
  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;
  int rows() => StockMovementRepository().movementsForItem('paneer').length;
  int journal() => Hive.box(HiveBoxNames.restaurantStockJournal).length;
  Map<String, int> lines() =>
      {for (final l in saved()?.items ?? <CartItem>[]) l.id: l.quantity};

  Future<ActiveLineCancelResult> cancel(String lineId,
          {int? qty, WhenEmpty whenEmpty = WhenEmpty.refuse}) =>
      ActiveLineCancel.commit(
          orderId: 'o1', lineId: lineId, qty: qty, whenEmpty: whenEmpty);

  Matcher refusedWith(String message) => throwsA(
      isA<ActiveLineCancelRefused>().having((e) => e.message, 'message', message));

  var seq = 0;
  Future<int> captainSend(List<CartItem> lines) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': lines.map((l) => l.toMap()).toList(),
        'orderType': 'Dine In',
        'tableNo': 'T1',
        'totalPrice': 0,
        'requestId': 'r${seq++}',
      }),
    ));
    return response.statusCode;
  }

  Future<int> captainModify(List<CartItem> kept, List<CartItem> cancelled) async {
    final response = await captainModifyOrderHandler(
      Request(
        'PUT',
        Uri.parse('http://localhost/captain/orders/o1/modify'),
        body: jsonEncode({
          'updatedItems': kept.map((l) => l.toMap()).toList(),
          'cancelledItems': cancelled.map((l) => l.toMap()).toList(),
        }),
      ),
      'o1',
    );
    return response.statusCode;
  }

  // ==========================================================================
  group('the SAVED order, not the screen\'s or the store\'s copy', () {
    test('Captain lines the POS has not seen survive a POS cancel', () async {
      await persist();
      final c = makeCartItem(
          id: 'c', productId: 'paneer', title: 'Paneer Tikka', price: 100,
          quantity: 1);
      await writeBehindPos(order(
          lines: [a(3), b(2), c],
          kotNumbers: [1, 2, 3],
          kotBoundaries: [1, 2, 3],
          kotStatuses: {1: 'Cooking', 2: 'Cooking', 3: 'Cooking'}));
      expect(orderStore.getOrderById('o1')!.items, hasLength(2),
          reason: 'the store copy is behind');

      await cancel('a', qty: 1, whenEmpty: WhenEmpty.delete);

      expect(lines(), {'a': 2, 'b': 2, 'c': 1});
      expect(saved()!.kotNumbers, [1, 2, 3]);
      expect(stock(), 6);
    });

    test('through a real Captain add-items request', () async {
      await persist();
      expect(await captainSend([
        makeCartItem(id: 'c', productId: 'paneer', title: 'Paneer Tikka',
            price: 100, quantity: 1),
      ]), 200);
      expect(stock(), 4);

      await cancel('b', whenEmpty: WhenEmpty.refuse);

      expect(lines(), {'a': 3, 'c': 1});
      expect(stock(), 6);
    });

    test('Captain add-items refreshes the POS\'s in-memory copy', () async {
      await persist();
      await captainSend([
        makeCartItem(id: 'c', productId: 'paneer', title: 'Paneer Tikka',
            price: 100, quantity: 1),
      ]);
      expect({for (final l in orderStore.getOrderById('o1')!.items) l.id},
          {'a', 'b', 'c'});
    });

    test('Captain reduced the line below the cancel: refused, nothing moves',
        () async {
      await persist();
      expect(await captainModify([a(1), b(2)], [a(2)]), 200);
      expect(stock(), 7);
      final rowsBefore = rows();

      await expectLater(cancel('a', qty: 2, whenEmpty: WhenEmpty.delete),
          refusedWith(OrderConcurrency.changedElsewhereMessage));

      expect(lines(), {'a': 1, 'b': 2});
      expect(stock(), 7, reason: 'never restored a second time');
      expect(rows(), rowsBefore);
      expect(journal(), 0);
    });

    test('a line Captain already removed: refused, no second restore',
        () async {
      await persist();
      expect(await captainModify([a(3)], [b(2)]), 200);
      expect(stock(), 7);

      await expectLater(cancel('b', whenEmpty: WhenEmpty.refuse),
          refusedWith(ActiveLineCancel.alreadyCancelledMessage));
      expect(stock(), 7);
      expect(lines(), {'a': 3});
    });

    test('the order is gone: refused', () async {
      await persist();
      await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).delete('o1');
      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          refusedWith(OrderConcurrency.goneMessage));
      expect(stock(), 5);
    });

    test('a KOT the kitchen marked Ready since: refused as cooked', () async {
      await persist();
      await writeBehindPos(
          order(kotStatuses: {1: 'Ready', 2: 'Cooking'}));
      expect(orderStore.getOrderById('o1')!.kotStatuses![1], 'Cooking');

      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          refusedWith(ActiveLineCancel.cookedMessage));
      expect(stock(), 5);
      expect(lines(), {'a': 3, 'b': 2});
    });
  });

  // ==========================================================================
  group('what a cancel writes', () {
    test('partial: line reduced, positions kept, stock returned once',
        () async {
      await persist();
      final r = await cancel('a', qty: 2, whenEmpty: WhenEmpty.delete);

      expect(lines(), {'a': 1, 'b': 2});
      expect(saved()!.kotBoundaries, [1, 2]);
      expect(saved()!.totalPrice, 200);
      expect(stock(), 7);
      expect(rows(), 1);
      expect(journal(), 0);
      expect(r.kotNumber, 1);
      expect(r.cancelled.quantity, 2);
      expect(r.stockWarning, isNull);
    });

    test('whole line (Active Orders): its KOT leaves the layout', () async {
      await persist();
      await cancel('a', whenEmpty: WhenEmpty.refuse);
      expect(lines(), {'b': 2});
      expect(saved()!.kotNumbers, [2]);
      expect(saved()!.kotBoundaries, [1]);
      expect(stock(), 8);
    });

    test('the last line, Active Orders: refused — that is a void', () async {
      await persist(order(lines: [a(3)], kotNumbers: [1], kotBoundaries: [1],
          kotStatuses: {1: 'Cooking'}));
      await expectLater(cancel('a', whenEmpty: WhenEmpty.refuse),
          refusedWith(ActiveLineCancel.lastItemMessage));
      expect(lines(), {'a': 3});
      expect(stock(), 5);
    });

    test('the last line, Takeaway with nothing pending: order deleted',
        () async {
      await persist(order(lines: [a(3)], kotNumbers: [1], kotBoundaries: [1],
          kotStatuses: {1: 'Cooking'}));
      final r = await cancel('a', qty: 3, whenEmpty: WhenEmpty.delete);
      expect(r.orderDeleted, isTrue);
      expect(saved(), isNull);
      expect(stock(), 8);
    });

    test('the last line, Takeaway with new lines pending: order kept',
        () async {
      await persist(order(lines: [a(3)], kotNumbers: [1], kotBoundaries: [1],
          kotStatuses: {1: 'Cooking'}));
      final r = await cancel('a', qty: 3, whenEmpty: WhenEmpty.keep);
      expect(r.orderDeleted, isFalse);
      expect(saved()!.items, isEmpty);
      expect(stock(), 8);
    });

    test('tax-inclusive: subTotal is the pre-tax base, GST taken once',
        () async {
      CartItem t(int q) => makeCartItem(
          id: 't', productId: 'paneer', title: 'Paneer Tikka', price: 105,
          quantity: q, taxRate: 0.05);
      await persist(order(lines: [t(3)], kotNumbers: [1], kotBoundaries: [1],
          kotStatuses: {1: 'Cooking'}, inclusive: true));

      await cancel('t', qty: 1, whenEmpty: WhenEmpty.delete);

      final o = saved()!;
      expect(o.totalPrice, closeTo(210, 1e-9));
      expect(o.gstAmount, closeTo(10, 1e-9));
      expect(o.subTotal, closeTo(200, 1e-9));
      expect(o.subTotal! + o.gstAmount!, closeTo(o.totalPrice, 1e-9));
    });

    test('runs inside the stock gate: waits for a sale in progress', () async {
      await persist();
      final release = Completer<void>();
      final holder = StockGate.run(() => release.future);
      var done = false;
      final pending =
          cancel('a', qty: 1, whenEmpty: WhenEmpty.delete).then((_) => done = true);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(done, isFalse);
      expect(lines(), {'a': 3, 'b': 2});
      release.complete();
      await holder;
      await pending;
      expect(lines(), {'a': 2, 'b': 2});
    });

    test('a store save that fails without landing: refused, nothing moves',
        () async {
      await persist();
      orders.mode = _Write.falseNotSaved;
      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          throwsA(isA<ActiveLineCancelRefused>()));
      expect(lines(), {'a': 3, 'b': 2});
      expect(stock(), 5);
      expect(journal(), 0);
    });

    test('a store save that reports failure but landed: stock returned once',
        () async {
      await persist();
      orders.mode = _Write.falseButSaved;
      await cancel('a', qty: 1, whenEmpty: WhenEmpty.delete);
      expect(lines(), {'a': 2, 'b': 2});
      expect(stock(), 6);
      expect(journal(), 0);
    });
  });

  // ==========================================================================
  group('P3 — the last line of an order holding a payment', () {
    OrderModel single({
      double? totalPaid,
      bool? isPaid,
      String? paymentStatus,
      double total = 300,
    }) =>
        order(lines: [a(3)], kotNumbers: [1], kotBoundaries: [1],
                kotStatuses: {1: 'Cooking'})
            .copyWith(
          totalPrice: total,
          totalPaid: totalPaid,
          isPaid: isPaid,
          paymentStatus: paymentStatus,
          paymentMethod: totalPaid == null ? null : 'Cash',
          paymentListJson: totalPaid == null
              ? null
              : '[{"method":"cash","amount":$totalPaid}]',
        );

    test('part-paid, nothing pending: refused, order and payment untouched',
        () async {
      await persist(single(totalPaid: 100, paymentStatus: 'Partially Paid'));
      final before = saved()!;

      await expectLater(cancel('a', qty: 3, whenEmpty: WhenEmpty.delete),
          refusedWith(ActiveLineCancel.paidLastItemMessage));

      final o = saved();
      expect(o, isNotNull, reason: 'never deleted');
      expect(lines(), {'a': 3});
      expect(o!.totalPrice, before.totalPrice);
      expect(o.totalPaid, 100);
      expect(o.paymentListJson, before.paymentListJson);
      expect(o.paymentMethod, 'Cash');
      expect(o.paymentStatus, 'Partially Paid');
      expect(orderStore.getOrderById('o1'), isNotNull);
      expect(stock(), 5, reason: 'no stock returned');
      expect(rows(), 0);
      expect(journal(), 0, reason: 'refused before the journal');
      // Active Orders' void keeps this money (VOIDED, refundable): the
      // End of Day and drawer path for a paid order.
      expect(VoidOrderCommit.wasPaid(o), isTrue);
    });

    test('paid by the old flags only (no totalPaid): refused', () async {
      await persist(single(isPaid: true));
      await expectLater(cancel('a', qty: 3, whenEmpty: WhenEmpty.delete),
          refusedWith(ActiveLineCancel.paidLastItemMessage));
      expect(saved(), isNotNull);

      await persist(single(paymentStatus: 'Paid'));
      await expectLater(cancel('a', qty: 3, whenEmpty: WhenEmpty.delete),
          refusedWith(ActiveLineCancel.paidLastItemMessage));
      expect(saved(), isNotNull);
    });

    test('the store copy shows no payment but the SAVED order has one: refused',
        () async {
      await persist(single());
      await writeBehindPos(single(totalPaid: 50));
      await expectLater(cancel('a', qty: 3, whenEmpty: WhenEmpty.delete),
          refusedWith(ActiveLineCancel.paidLastItemMessage));
      expect(saved()!.totalPaid, 50);
    });

    test('unpaid: still deleted, as before', () async {
      await persist(single());
      final r = await cancel('a', qty: 3, whenEmpty: WhenEmpty.delete);
      expect(r.orderDeleted, isTrue);
      expect(stock(), 8);
    });

    test('an unpaid order totalling zero still deletes (zero is not paid)',
        () async {
      await persist(single(total: 0));
      final r = await cancel('a', qty: 3, whenEmpty: WhenEmpty.delete);
      expect(r.orderDeleted, isTrue);
    });

    test('part-paid, new lines pending (kept): allowed, payment kept',
        () async {
      await persist(single(totalPaid: 100, paymentStatus: 'Partially Paid'));
      final r = await cancel('a', qty: 3, whenEmpty: WhenEmpty.keep);
      expect(r.orderDeleted, isFalse);
      expect(saved()!.totalPaid, 100);
      expect(saved()!.paymentListJson, '[{"method":"cash","amount":100.0}]');
    });

    test('part-paid, not the last line: allowed, payment kept', () async {
      await persist(order().copyWith(
          totalPaid: 100, paymentStatus: 'Partially Paid'));
      await cancel('a', qty: 1, whenEmpty: WhenEmpty.delete);
      expect(lines(), {'a': 2, 'b': 2});
      expect(saved()!.totalPaid, 100);
    });
  });

  // ==========================================================================
  group('4b — a stop at any point: the return happens exactly once', () {
    test('stop before the order write: nothing was cancelled, nothing returned',
        () async {
      await persist();
      orders.mode = _Write.crashBefore;
      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          throwsA(isA<_Crash>()));
      await restart();
      expect(journal(), 1);

      final failures = await StockJournal.recoverCancels();
      expect(failures, isEmpty);
      expect(journal(), 0);
      expect(lines(), {'a': 3, 'b': 2});
      expect(stock(), 5);
      expect(rows(), 0);
    });

    test('stop after the order write: recovery returns it once', () async {
      await persist();
      orders.mode = _Write.crashAfter;
      await expectLater(cancel('a', qty: 2, whenEmpty: WhenEmpty.delete),
          throwsA(isA<_Crash>()));
      await restart();
      expect(lines(), {'a': 1, 'b': 2});
      expect(stock(), 5, reason: 'nothing returned yet');

      await StockJournal.recoverCancels();
      expect(stock(), 7);
      expect(rows(), 1);
      expect(journal(), 0);
      await StockJournal.recoverCancels();
      expect(stock(), 7, reason: 'never twice');
    });

    test('stop after deleting the emptied order: recovery returns it once',
        () async {
      await persist(order(lines: [a(3)], kotNumbers: [1], kotBoundaries: [1],
          kotStatuses: {1: 'Cooking'}));
      orders.mode = _Write.crashAfter;
      await expectLater(cancel('a', qty: 3, whenEmpty: WhenEmpty.delete),
          throwsA(isA<_Crash>()));
      await restart();
      expect(saved(), isNull);

      await StockJournal.recoverCancels();
      expect(stock(), 8);
      expect(journal(), 0);
    });

    test('stop after the stock write, before its row: row only, stock once',
        () async {
      await persist();
      items.crashAfterWrite = 'paneer';
      // The order is saved by then: the cancel reports the unfinished return.
      final r = await cancel('a', qty: 2, whenEmpty: WhenEmpty.delete);
      expect(r.stockWarning, isNotNull);
      await restart();
      expect(stock(), 7);
      expect(rows(), 0);

      await StockJournal.recoverCancels();
      expect(stock(), 7);
      expect(rows(), 1);
      expect(journal(), 0);
    });

    test('the next cancel finishes an earlier interrupted one first', () async {
      await persist();
      orders.mode = _Write.crashAfter;
      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          throwsA(isA<_Crash>()));
      await restart();

      await cancel('b', qty: 1, whenEmpty: WhenEmpty.delete);
      expect(lines(), {'a': 2, 'b': 1});
      expect(stock(), 7);
      expect(journal(), 0);
    });

    test('order gone before recovery could tell: never guessed, review alert',
        () async {
      await persist();
      orders.mode = _Write.crashAfter;
      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          throwsA(isA<_Crash>()));
      await restart();
      // The order was settled elsewhere before the recovery ran.
      await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).delete('o1');

      final failures = await StockJournal.recoverCancels();
      expect(failures, hasLength(1));
      expect(stock(), 5);
      final entry = StockJournal.cancelEntries().single;
      expect(entry.units.every((u) => u.state == StockJournal.review), isTrue);
      expect(
          Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications).values
              .where((n) => n.eventCode == StockJournal.reviewEvent),
          isNotEmpty);
    });

    test('Settle\'s recovery leaves cancel entries alone', () async {
      await persist();
      orders.mode = _Write.crashAfter;
      await expectLater(cancel('a', qty: 1, whenEmpty: WhenEmpty.delete),
          throwsA(isA<_Crash>()));
      await restart();

      expect(StockJournal.all(), isEmpty);
      final failures = await StockJournal.recoverAll();
      expect(failures, isEmpty);
      expect(journal(), 1);
      expect(stock(), 5);
    });

    test('Captain modify: a stop after its stock write is finished once',
        () async {
      await persist();
      items.crashAfterWrite = 'paneer';
      final status = await captainModify([a(1), b(2)], [a(2)]);
      expect(status, 200, reason: 'the order is saved; the return resumes');
      await restart();
      expect(lines(), {'a': 1, 'b': 2});
      expect(stock(), 7);
      expect(rows(), 0);

      await StockJournal.recoverCancels();
      expect(stock(), 7);
      expect(rows(), 1);
      expect(journal(), 0);
    });

    test('a cancel entry whose order write never landed is dropped', () async {
      await persist();
      await StockJournal.openCancel(
        orderId: 'o1',
        target: {'a': 1},
        units: [],
      );
      // Captain modify's shape: several lines, one removed.
      final e2 = await StockJournal.openCancel(
        orderId: 'o1',
        target: {'a': 3, 'b': 0},
        units: [],
      );
      await StockJournal.recoverCancels();
      expect(journal(), 0);
      expect(e2.orderSaved, isFalse);
    });
  });
}
