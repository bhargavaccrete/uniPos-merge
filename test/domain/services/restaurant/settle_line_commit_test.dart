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
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/settle_line_commit.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Fails a chosen item's next stock write, or runs a hook right after one —
/// the two ways a Settle deduction can stop part-way.
class _FlakyItemStore extends ItemStore {
  _FlakyItemStore() : super(ItemRepository());

  final Set<String> failNextWrite = {};
  Future<void> Function(String itemId)? afterWrite;

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
    final balance = await super.applyStockDelta(
      itemId: itemId,
      variantId: variantId,
      delta: delta,
      lastPurchaseCost: lastPurchaseCost,
      beforePersist: beforePersist,
    );
    await afterWrite?.call(itemId);
    return balance;
  }
}

/// Settle on an existing order (customerdetails.dart `proceed`).
/// F1: reconcile changed lines by line id against the SAVED order.
/// F4: a retry must not deduct the same quantity again.
void main() {
  // Low-stock toasts go through NotificationService, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settle_line_commit_');
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

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      // OrderStore.loadOrders reconciles against past orders.
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerLazySingleton<OrderStore>(
          () => OrderStore(locator<OrderRepository>()));

    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    for (final id in ['A', 'B', 'C']) {
      await items.put(id,
          Items(id: id, name: id, trackInventory: true, stockQuantity: 10));
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

  int movementCount(String id) =>
      StockMovementRepository().movementsForItem(id).length;

  CartItem l(String id, int qty) => makeCartItem(
      id: 'line-$id', productId: id, title: id, price: 10, quantity: qty);

  OrderModel order(List<CartItem> lines,
          {List<int>? kotNumbers, List<int>? kotBoundaries}) =>
      OrderModel(
        id: 'o1',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: lines,
        status: 'Cooking',
        timeStamp: DateTime(2026, 10, 22, 12),
        orderType: 'Dine In',
        tableNo: 'T1',
        totalPrice: 0,
        kotNumbers: kotNumbers ?? [1],
        itemCountAtLastKot: lines.length,
        kotBoundaries: kotBoundaries ?? [lines.length],
        kotStatuses: {for (final n in kotNumbers ?? [1]) n: 'Cooking'},
      );

  /// Saves [saved] as the persisted order and loads it into the store.
  Future<void> persist(OrderModel saved) async {
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders)
        .put(saved.id, saved);
    await orderStore.loadOrders();
  }

  OrderModel savedOrder() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!;

  group('F1 — reconcile changed lines', () {
    test('settle after a qty raise deducts the delta once', () async {
      final saved = order([l('A', 2)]);
      await persist(saved);

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 3)]);

      expect(stock('A'), 9, reason: 'only the +1 is new');
    });

    test('settle with a new line deducts it and appends one KOT boundary',
        () async {
      final saved = order([l('A', 1)]);
      await persist(saved);

      final r = await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 1), l('B', 2)]);

      expect(stock('A'), 10);
      expect(stock('B'), 8);
      expect(r.addedLines.map((c) => c.id), ['line-B']);
      expect(r.order.kotNumbers.length, 2);
      expect(r.order.kotBoundaries, [1, 2]);
      expect(r.order.itemCountAtLastKot, 2);
    });

    test('remove + add of equal count is refused and moves no stock',
        () async {
      final saved = order([l('A', 1), l('B', 1)]);
      await persist(saved);

      await expectLater(
        SettleLineCommit.commit(
            snapshot: saved, itemsToSettle: [l('A', 1), l('C', 1)]),
        throwsA(isA<SettleBlockedException>()),
      );
      expect([stock('A'), stock('B'), stock('C')], [10, 10, 10]);
      expect(savedOrder().items.map((c) => c.id), ['line-A', 'line-B']);
    });

    test('a reduced quantity is refused and moves no stock', () async {
      final saved = order([l('A', 3)]);
      await persist(saved);

      await expectLater(
        SettleLineCommit.commit(snapshot: saved, itemsToSettle: [l('A', 2)]),
        throwsA(isA<SettleBlockedException>()),
      );
      expect(stock('A'), 10);
    });

    test('settle diffs against the saved order, not a stale snapshot',
        () async {
      // The screen opened on [A, B]; B was then cancelled immediately (F3),
      // so the saved order is [A] while the widget still holds [A, B].
      final staleSnapshot = order([l('A', 1), l('B', 1)]);
      await persist(order([l('A', 1)]));

      await SettleLineCommit.commit(
          snapshot: staleSnapshot, itemsToSettle: [l('A', 1), l('C', 1)]);

      expect(stock('C'), 9, reason: 'C is new against the saved order');
      expect(stock('B'), 10, reason: 'B was already restored by its cancel');
    });

    test('saved lines carry the stock stamp: an increase adds to it, a new '
        'line gets its own', () async {
      final saved =
          order([l('A', 1).copyWith(ownStockQty: 1, freshQty: 0)]);
      await persist(saved);

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 3), l('B', 2)]);

      final lines = savedOrder().items;
      String s(CartItem c) => '${c.id}:${c.ownStockQty}/${c.freshQty}';
      expect(lines.map(s), ['line-A:3/0', 'line-B:2/0']);
      expect([stock('A'), stock('B')], [8, 8]);
    });

    test('unchanged lines commit nothing', () async {
      final saved = order([l('A', 2)]);
      await persist(saved);

      final r = await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 2)]);

      expect(r.newKotNumber, isNull);
      expect(stock('A'), 10);
      expect(movementCount('A'), 0);
    });
  });

  group('Fix C — recovery after a partial stock failure', () {
    late _FlakyItemStore flaky;

    setUp(() async {
      flaky = _FlakyItemStore();
      await locator.unregister<ItemStore>();
      locator.registerSingleton<ItemStore>(flaky);
      await itemStore.loadItems();
    });

    Future<SettleStockIncompleteException> failingCommit(
        OrderModel saved, List<CartItem> lines) async {
      try {
        await SettleLineCommit.commit(snapshot: saved, itemsToSettle: lines);
      } on SettleStockIncompleteException catch (e) {
        return e;
      }
      fail('expected the stock deduction to stop part-way');
    }

    test('lines saved, B deducted, C fails → retry deducts C only, once',
        () async {
      final saved = order([l('A', 1)]);
      await persist(saved);
      final lines = [l('A', 1), l('B', 2), l('C', 1)];
      flaky.failNextWrite.add('C');

      final e = await failingCommit(saved, lines);
      expect(savedOrder().items.length, 3, reason: 'lines were saved first');
      expect([stock('B'), stock('C')], [8, 10]);
      expect([movementCount('B'), movementCount('C')], [1, 0]);

      final r = await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: e.pending);

      expect([stock('B'), stock('C')], [8, 9]);
      expect([movementCount('B'), movementCount('C')], [1, 1]);
      expect(savedOrder().kotNumbers.length, 2, reason: 'no second KOT');
      expect(r.newKotNumber, e.pending.result.newKotNumber,
          reason: 'the retry returns the add-on KOT so it can still print');
      expect(r.addedLines.map((c) => c.id), ['line-B', 'line-C']);
    });

    test('stock written but its movement row fails → retry writes the row '
        'without deducting again', () async {
      final saved = order([l('A', 1)]);
      await persist(saved);
      final lines = [l('A', 1), l('B', 2)];
      flaky.afterWrite = (id) async {
        if (id == 'B') {
          await Hive.box<StockMovementModel>(
                  HiveBoxNames.restaurantStockMovements)
              .close();
        }
      };

      final e = await failingCommit(saved, lines);
      expect(stock('B'), 8, reason: 'the stock write itself succeeded');

      flaky.afterWrite = null;
      await Hive.openBox<StockMovementModel>(
          HiveBoxNames.restaurantStockMovements);
      expect(movementCount('B'), 0);

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: e.pending);

      expect(stock('B'), 8, reason: 'not deducted a second time');
      final rows = StockMovementRepository().movementsForItem('B');
      expect(rows.length, 1);
      expect(rows.single.balanceAfter, 8);
      expect(rows.single.reason, 'Sale');
    });

    test('recipe cascade: a failed ingredient is finished on retry, the '
        'others are not repeated', () async {
      final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
      await items.put('X',
          Items(id: 'X', name: 'X', trackInventory: true, stockQuantity: 10));
      await items.put('Y',
          Items(id: 'Y', name: 'Y', trackInventory: true, stockQuantity: 10));
      await items.put('R',
          Items(id: 'R', name: 'R', productType: ProductType.recipeBased));
      await Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).put(
          'r-R',
          RecipeModel(id: 'r-R', itemId: 'R', ingredients: [
            RecipeIngredientModel(ingredientItemId: 'X', quantity: 1),
            RecipeIngredientModel(ingredientItemId: 'Y', quantity: 2),
          ]));
      await itemStore.loadItems();

      final saved = order([l('A', 1)]);
      await persist(saved);
      final lines = [l('A', 1), l('R', 2)];
      flaky.failNextWrite.add('Y');

      final e = await failingCommit(saved, lines);
      expect([stock('X'), stock('Y')], [8, 10]);

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: e.pending);

      expect([stock('X'), stock('Y')], [8, 6]);
      expect([movementCount('X'), movementCount('Y')], [1, 1]);
    });

    Future<void> seedPizza() async {
      await Hive.box<VariantModel>(HiveBoxNames.restaurantVariants)
          .put('small', VariantModel(id: 'small', name: 'Small'));
      await variantStore.loadVariants();
      await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
          'P',
          Items(id: 'P', name: 'P', trackInventory: true, variant: [
            ItemVariante(
                variantId: 'small',
                price: 10,
                trackInventory: true,
                stockQuantity: 5),
          ]));
      await itemStore.loadItems();
    }

    double smallStock() => Hive.box<Items>(HiveBoxNames.restaurantItems)
        .get('P')!
        .variant!
        .single
        .stockQuantity!;

    CartItem pizzaLine(int qty) => makeCartItem(
        id: 'line-P', productId: 'P', title: 'P', price: 10,
        quantity: qty, variantName: 'Small');

    test('a failed variant stock write stops the deduction; the retry '
        'deducts it once with one movement row', () async {
      await seedPizza();
      final saved = order([l('A', 1)]);
      await persist(saved);
      final lines = [l('A', 1), pizzaLine(2)];
      flaky.failNextWrite.add('P');

      final e = await failingCommit(saved, lines);
      expect(smallStock(), 5, reason: 'the variant write failed');
      expect(movementCount('P'), 0,
          reason: 'no success-looking row for a failed write');

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: e.pending);
      expect(smallStock(), 3);
      final rows = StockMovementRepository().movementsForItem('P');
      expect(rows.length, 1);
      expect(rows.single.balanceAfter, 3);
      expect(rows.single.variantId, 'small');

      // A further retry with the same record changes nothing.
      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: e.pending);
      expect(smallStock(), 3);
      expect(movementCount('P'), 1);
    });

    test('a line whose variant no longer exists moves no stock and writes '
        'no movement row', () async {
      await seedPizza();
      final saved = order([l('A', 1)]);
      await persist(saved);
      final gone = makeCartItem(
          id: 'line-P', productId: 'P', title: 'P', price: 10,
          quantity: 1, variantName: 'Large');

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 1), gone]);

      expect(smallStock(), 5);
      expect(movementCount('P'), 0);
    });

    test('a retry that fails again keeps the same pending record', () async {
      final saved = order([l('A', 1)]);
      await persist(saved);
      final lines = [l('A', 1), l('B', 1), l('C', 1)];
      flaky.failNextWrite.add('C');
      final first = await failingCommit(saved, lines);

      flaky.failNextWrite.add('C');
      SettleStockIncompleteException? second;
      try {
        await SettleLineCommit.commit(
            snapshot: saved, itemsToSettle: lines, pending: first.pending);
      } on SettleStockIncompleteException catch (e) {
        second = e;
      }
      expect(second?.pending, same(first.pending));

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: second!.pending);
      expect([stock('B'), stock('C')], [9, 9]);
      expect([movementCount('B'), movementCount('C')], [1, 1]);
    });

    test('after leaving the screen (no pending record) the missing deduction '
        'is recovered', () async {
      final saved = order([l('A', 1)]);
      await persist(saved);
      final lines = [l('A', 1), l('B', 1), l('C', 1)];
      flaky.failNextWrite.add('C');
      await failingCommit(saved, lines);

      await SettleLineCommit.commit(snapshot: saved, itemsToSettle: lines);

      expect(stock('C'), 9);
      expect(movementCount('C'), 1);
    });
  });

  group('F4 — retry does not deduct twice', () {
    test('commit twice with the same lines moves stock once and adds one KOT',
        () async {
      final saved = order([l('A', 1)]);
      await persist(saved);

      // Second call = the user tapping Settle again after a payment-step
      // error; the screen still holds the same snapshot.
      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 1), l('B', 2)]);
      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 1), l('B', 2)]);

      expect(stock('B'), 8);
      expect(movementCount('B'), 1);
      expect(savedOrder().kotNumbers.length, 2);
    });

    test('a failed order save moves no stock; the retry deducts once',
        () async {
      final saved = order([l('A', 1)]);
      await persist(saved);
      orderStore; // build the store while its box is open

      // The repository's box handle is now closed → updateOrder fails.
      await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).close();
      await expectLater(
        SettleLineCommit.commit(
            snapshot: saved, itemsToSettle: [l('A', 1), l('B', 2)]),
        throwsException,
      );
      expect(stock('B'), 10, reason: 'nothing moves when the save fails');

      // Recover: reopen, rebuild the order layer, retry.
      await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      await locator.resetLazySingleton<OrderStore>();
      await locator.resetLazySingleton<OrderRepository>();
      await orderStore.loadOrders();
      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 1), l('B', 2)]);

      expect(stock('B'), 8);
      expect(movementCount('B'), 1);
    });

    test('lines are saved before stock moves', () async {
      final saved = order([l('A', 1)]);
      await persist(saved);

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: [l('A', 1), l('B', 2)]);

      final persisted = savedOrder();
      expect(persisted.items.map((c) => c.id), ['line-A', 'line-B']);
      expect(persisted.itemCountAtLastKot, 2);
    });
  });
}
