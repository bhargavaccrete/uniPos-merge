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
import 'package:billberrylite/domain/services/restaurant/settle_line_commit.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Fails a chosen item's next stock write.
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

/// Phase 0.2: the Settle stock journal survives leaving the screen and an
/// app restart. A "restart" closes every Hive box, resets the service
/// locator and reopens from the same directory — only persisted state
/// survives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Future<void> openWorld({ItemStore Function()? store}) async {
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
      ..registerSingleton<ItemStore>(store?.call() ?? ItemStore(ItemRepository()))
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
    await itemStore.loadItems();
    await variantStore.loadVariants();
    await orderStore.loadOrders();
  }

  /// A fresh app process: nothing in memory survives.
  Future<void> restart() async {
    await locator.reset();
    await Hive.close();
    await openWorld();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stock_journal_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    final items = await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    for (final id in ['A', 'B', 'C', 'X', 'Y']) {
      await items.put(id,
          Items(id: id, name: id, trackInventory: true, stockQuantity: 10));
    }
    await items.put('R',
        Items(id: 'R', name: 'R', productType: ProductType.recipeBased));
    await items.put(
        'P',
        Items(id: 'P', name: 'P', trackInventory: true, variant: [
          ItemVariante(
              variantId: 'small', price: 10,
              trackInventory: true, stockQuantity: 5),
        ]));
    final variants =
        await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await variants.put('small', VariantModel(id: 'small', name: 'Small'));
    final recipes = await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await recipes.put(
        'r-R',
        RecipeModel(id: 'r-R', itemId: 'R', ingredients: [
          RecipeIngredientModel(ingredientItemId: 'X', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'Y', quantity: 2),
        ]));
    await Hive.close();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  double smallStock() => Hive.box<Items>(HiveBoxNames.restaurantItems)
      .get('P')!
      .variant!
      .single
      .stockQuantity!;
  List<StockMovementModel> rows(String id) =>
      StockMovementRepository().movementsForItem(id);
  int journalSize() => Hive.box(HiveBoxNames.restaurantStockJournal).length;

  CartItem l(String id, int qty, {String? variant}) => makeCartItem(
      id: 'line-$id', productId: id, title: id, price: 10, quantity: qty,
      variantName: variant);

  OrderModel order(List<CartItem> lines) => OrderModel(
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
        kotNumbers: [1],
        itemCountAtLastKot: lines.length,
        kotBoundaries: [lines.length],
        kotStatuses: {1: 'Cooking'},
      );

  Future<void> persistOrder(OrderModel o) async {
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
  }

  Future<SettleStockIncompleteException> failingCommit(
      OrderModel saved, List<CartItem> lines) async {
    try {
      await SettleLineCommit.commit(snapshot: saved, itemsToSettle: lines);
    } on SettleStockIncompleteException catch (e) {
      return e;
    }
    fail('expected the stock deduction to stop part-way');
  }

  group('end to end — failure, then a restart', () {
    test('B deducted, C fails, app restarts → startup recovery deducts C '
        'once; nothing is repeated', () async {
      await openWorld(store: _FlakyItemStore.new);
      final flaky = itemStore as _FlakyItemStore;
      final saved = order([l('A', 1)]);
      await persistOrder(saved);
      flaky.failNextWrite.add('C');

      await failingCommit(saved, [l('A', 1), l('B', 2), l('C', 1)]);
      expect([stock('B'), stock('C')], [8, 10]);

      await restart();
      await StockJournal.recoverAll();

      expect([stock('A'), stock('B'), stock('C')], [10, 8, 9]);
      expect([rows('B').length, rows('C').length], [1, 1]);
      expect(rows('C').single.balanceAfter, 9);
      expect(journalSize(), 0, reason: 'complete entries are removed');

      await StockJournal.recoverAll(); // a second startup changes nothing
      expect([stock('B'), stock('C')], [8, 9]);
      expect([rows('B').length, rows('C').length], [1, 1]);
    });

    test('variant write fails, app restarts → the variant is deducted once',
        () async {
      await openWorld(store: _FlakyItemStore.new);
      final flaky = itemStore as _FlakyItemStore;
      final saved = order([l('A', 1)]);
      await persistOrder(saved);
      flaky.failNextWrite.add('P');

      await failingCommit(saved, [l('A', 1), l('P', 2, variant: 'Small')]);
      expect(smallStock(), 5);
      expect(rows('P'), isEmpty);

      await restart();
      await StockJournal.recoverAll();

      expect(smallStock(), 3);
      expect(rows('P').single.variantId, 'small');
      expect(rows('P').single.balanceAfter, 3);
    });

    test('recipe ingredient fails, app restarts → only that ingredient is '
        'finished', () async {
      await openWorld(store: _FlakyItemStore.new);
      final flaky = itemStore as _FlakyItemStore;
      final saved = order([l('A', 1)]);
      await persistOrder(saved);
      flaky.failNextWrite.add('Y');

      await failingCommit(saved, [l('A', 1), l('R', 2)]);
      expect([stock('X'), stock('Y')], [8, 10]);

      await restart();
      await StockJournal.recoverAll();

      expect([stock('X'), stock('Y')], [8, 6]);
      expect([rows('X').length, rows('Y').length], [1, 1]);
      expect(rows('Y').single.reason, 'Sale (recipe: R)');
    });

    test('row fails after the stock write, a refund then restores the same '
        'quantity → the retry writes the row only, never deducts again',
        () async {
      await openWorld(store: _FlakyItemStore.new);
      final flaky = itemStore as _FlakyItemStore;
      final saved = order([l('A', 1)]);
      await persistOrder(saved);
      final lines = [l('A', 1), l('B', 2)];

      // B's stock write succeeds, then its movement row cannot be saved.
      flaky.afterWrite = (id) async {
        if (id == 'B') {
          await Hive.box<StockMovementModel>(
                  HiveBoxNames.restaurantStockMovements)
              .close();
        }
      };
      SettleStockIncompleteException? e;
      try {
        await SettleLineCommit.commit(snapshot: saved, itemsToSettle: lines);
      } on SettleStockIncompleteException catch (err) {
        e = err;
      }
      expect(e, isNotNull);
      expect(stock('B'), 8);

      // An unrelated refund puts 2 B back: stock now equals "before" (10).
      flaky.afterWrite = null;
      await Hive.openBox<StockMovementModel>(
          HiveBoxNames.restaurantStockMovements);
      await itemStore.applyStockDelta(itemId: 'B', delta: 2);
      expect(stock('B'), 10);

      await SettleLineCommit.commit(
          snapshot: saved, itemsToSettle: lines, pending: e!.pending);

      expect(stock('B'), 10, reason: 'sold 2, refunded 2 — not sold twice');
      expect(rows('B').single.balanceAfter, 8,
          reason: 'the row records the balance its own write produced');
    });

    test('leaving the screen: the next Settle of any order finishes it',
        () async {
      await openWorld(store: _FlakyItemStore.new);
      final flaky = itemStore as _FlakyItemStore;
      final saved = order([l('A', 1)]);
      await persistOrder(saved);
      flaky.failNextWrite.add('C');
      final lines = [l('A', 1), l('B', 1), l('C', 1)];
      await failingCommit(saved, lines);

      // A new Settle screen: no in-memory pending record.
      await SettleLineCommit.commit(snapshot: saved, itemsToSettle: lines);

      expect([stock('B'), stock('C')], [9, 9]);
      expect([rows('B').length, rows('C').length], [1, 1]);
      expect(journalSize(), 0);
    });
  });

  group('crash points — the on-disk state each crash leaves, recovered by '
      'a fresh app', () {
    JournalUnit unit(String item, double qty,
            {String state = StockJournal.planned,
            double? before,
            double? after}) =>
        JournalUnit(
          uid: 'settle:t1:line-$item',
          itemId: item,
          qty: qty,
          reason: 'Sale',
          itemName: item,
          unit: 'pcs',
          state: state,
          before: before,
          after: after,
        );

    Future<void> crashedWith(List<JournalUnit> units,
        {bool orderSaved = true, List<CartItem>? orderLines}) async {
      await openWorld();
      await persistOrder(order(orderLines ?? [l('A', 1), l('B', 2)]));
      await StockJournal.save(JournalEntry(
        id: 'settle:t1',
        orderId: 'o1',
        createdAt: DateTime(2026, 10, 22, 12),
        target: {'line-A': 1, 'line-B': 2},
        staffName: 'Asha',
        orderSaved: orderSaved,
        units: units,
      ));
      await restart();
    }

    test('crash after the journal, before the order save → discarded, '
        'nothing moves', () async {
      await crashedWith([unit('B', 2)],
          orderSaved: false, orderLines: [l('A', 1)]);
      await StockJournal.recoverAll();
      expect(stock('B'), 10);
      expect(rows('B'), isEmpty);
      expect(journalSize(), 0);
    });

    test('crash after the order save, before it was flagged → applied',
        () async {
      await crashedWith([unit('B', 2)], orderSaved: false);
      await StockJournal.recoverAll();
      expect(stock('B'), 8);
      expect(rows('B').single.id, 'settle:t1:line-B');
      expect(journalSize(), 0);
    });

    test('crash before the unit started → applied once', () async {
      await crashedWith([unit('B', 2)]);
      await StockJournal.recoverAll();
      expect(stock('B'), 8);
      expect(rows('B').length, 1);
    });

    test('crash after "applying" was recorded, before the stock write → '
        'applied once', () async {
      await crashedWith(
          [unit('B', 2, state: StockJournal.applying, before: 10, after: 8)]);
      await StockJournal.recoverAll();
      expect(stock('B'), 8);
      expect(rows('B').single.balanceAfter, 8);
    });

    test('crash after the stock write, before the movement row → only the '
        'row is written', () async {
      await openWorld();
      final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
      await items.put('B', items.get('B')!.copyWith(stockQuantity: 8));
      await locator.reset();
      await Hive.close();
      await crashedWith(
          [unit('B', 2, state: StockJournal.applying, before: 10, after: 8)]);

      await StockJournal.recoverAll();

      expect(stock('B'), 8, reason: 'not deducted a second time');
      expect(rows('B').single.balanceAfter, 8);
      expect(journalSize(), 0);
    });

    test('crash after the movement row, before "done" → nothing more',
        () async {
      await openWorld();
      final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
      await items.put('B', items.get('B')!.copyWith(stockQuantity: 8));
      await StockMovementRepository().saveMovement(StockMovementModel(
        id: 'settle:t1:line-B',
        timestamp: DateTime(2026, 10, 22, 12),
        itemId: 'B',
        itemName: 'B',
        type: 'out',
        quantity: 2,
        balanceAfter: 8,
        reason: 'Sale',
        unit: 'pcs',
        staffName: 'Asha',
      ));
      await locator.reset();
      await Hive.close();
      await crashedWith(
          [unit('B', 2, state: StockJournal.applying, before: 10, after: 8)]);

      await StockJournal.recoverAll();

      expect(stock('B'), 8);
      expect(rows('B').length, 1);
      expect(journalSize(), 0);
    });

    test('stock matches neither before nor after → flagged for review, '
        'never auto-applied', () async {
      await openWorld();
      final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
      await items.put('B', items.get('B')!.copyWith(stockQuantity: 7));
      await locator.reset();
      await Hive.close();
      await crashedWith(
          [unit('B', 2, state: StockJournal.applying, before: 10, after: 8)]);

      await StockJournal.recoverAll();
      await StockJournal.recoverAll();

      expect(stock('B'), 7, reason: 'no guess either way');
      expect(rows('B'), isEmpty);
      expect(StockJournal.all().single.units.single.state, StockJournal.review);
      final alerts = Hive.box<AppNotificationModel>(
              HiveBoxNames.appNotifications)
          .values
          .where((n) => n.eventCode == 'stock_check_needed');
      expect(alerts.length, 1, reason: 'one persisted alert, not one per run');
    });

    test('a mixed entry: done units are skipped, owed ones finished',
        () async {
      await openWorld();
      final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
      await items.put('A', items.get('A')!.copyWith(stockQuantity: 9));
      await locator.reset();
      await Hive.close();
      await crashedWith([
        unit('A', 1, state: StockJournal.done, before: 10, after: 9),
        unit('B', 2),
      ]);

      await StockJournal.recoverAll();

      expect([stock('A'), stock('B')], [9, 8]);
      expect(rows('A'), isEmpty, reason: 'a done unit is not revisited');
      expect(rows('B').length, 1);
    });
  });
}
