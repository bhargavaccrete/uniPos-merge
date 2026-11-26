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
import 'package:billberrylite/domain/services/restaurant/existing_order_update.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

/// Stock writes on the items in [failing] throw, as a stuck write would.
class _Items extends ItemStore {
  _Items() : super(ItemRepository());
  final failing = <String>{};

  @override
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
    Future<void> Function(double before, double after)? beforePersist,
  }) {
    if (failing.contains(itemId)) {
      throw StateError('stock write failed for $itemId');
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

/// Batch 3.2b P5 — Place Order on an existing order finishes cancel returns
/// a stop left part-way BEFORE it moves stock, inside the stock gate, and
/// refuses (nothing written) while one is still owed on this order or on an
/// item it writes. Settle's journal recovery is not involved.
///
/// Paneer 5 and Naan 5 on hand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _Items items;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eou_cancel_recovery_');
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
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await openRestaurantSessionForTest();

    items = _Items();
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

    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    for (final (id, name) in [('paneer', 'Paneer Tikka'), ('naan', 'Naan')]) {
      await box.put(
          id,
          Items(id: id, name: name, trackInventory: true, stockQuantity: 5,
              allowOrderWhenOutOfStock: false));
    }
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CartItem paneer(String id, int qty) => makeCartItem(
      id: id, productId: 'paneer', title: 'Paneer Tikka', price: 100,
      quantity: qty);
  CartItem naan(String id, int qty) => makeCartItem(
      id: id, productId: 'naan', title: 'Naan', price: 40, quantity: qty);

  Future<OrderModel> persist(String id, List<CartItem> lines) async {
    final o = OrderModel(
      id: id,
      customerName: '',
      customerNumber: '',
      customerEmail: '',
      items: lines,
      status: 'Cooking',
      timeStamp: DateTime(2026, 11, 12, 12),
      orderType: 'Dine In',
      tableNo: 'T-$id',
      totalPrice: 0,
      kotNumbers: [1],
      itemCountAtLastKot: lines.length,
      kotBoundaries: [lines.length],
      kotStatuses: {1: 'Cooking'},
    );
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
    return o;
  }

  /// A cancel a stop left after its order write: [line] is saved at
  /// [savedQty], and [qty] of it is still to go back to stock.
  Future<JournalEntry> leftCancel(String orderId, CartItem line,
          {required int savedQty, required int qty}) async =>
      StockJournal.openCancel(
        orderId: orderId,
        target: {line.id: savedQty},
        units: await InventoryService.planRestoreUnits(
            [(line: line, qty: qty)]),
      );

  OrderModel saved(String id) =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get(id)!;
  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  int rows(String id) => StockMovementRepository().movementsForItem(id).length;
  int cancels() => StockJournal.cancelEntries().length;
  Object? lastKot() =>
      Hive.box(HiveBoxNames.appCounters).get('lastKotNumber');

  var builds = 0;

  Future<ExistingOrderUpdateResult> placeOrder(
    OrderModel o, {
    List<CartItem> newLines = const [],
    List<CartItem> returned = const [],
    required List<CartItem> finalLines,
  }) =>
      ExistingOrderUpdate.commit(
        orderId: o.id,
        baseline: {for (final l in o.items) l.id: l.quantity},
        deduct: newLines,
        returning: returned,
        restores: [for (final r in returned) (line: r, qty: r.quantity)],
        needsKot: newLines.isNotEmpty,
        build: (plan, kot) async {
          builds++;
          return o.copyWith(
            items: finalLines,
            kotNumbers: [...o.kotNumbers, ?kot],
            kotBoundaries: [
              ...o.kotBoundaries,
              if (kot != null) finalLines.length,
            ],
            itemCountAtLastKot: finalLines.length,
          );
        },
      );

  void expectNothingWritten(OrderModel before, Object? kotBefore) {
    expect(builds, 0, reason: 'refused before the order was built');
    expect({for (final l in saved(before.id).items) l.id: l.quantity},
        {for (final l in before.items) l.id: l.quantity});
    expect(saved(before.id).kotNumbers, before.kotNumbers);
    expect(lastKot(), kotBefore, reason: 'no KOT number taken');
  }

  setUp(() => builds = 0);

  // ==========================================================================
  test('a cancel left part-way on this order is finished first, then the '
      'Place Order runs', () async {
    final o = await persist('o1', [paneer('a', 2)]);
    await leftCancel('o1', paneer('a', 3), savedQty: 2, qty: 1);

    final r = await placeOrder(o,
        newLines: [paneer('b', 2)],
        finalLines: [paneer('a', 2), paneer('b', 2)]);

    expect(r.refused, isFalse);
    expect(cancels(), 0, reason: 'the return finished');
    expect(stock('paneer'), 4, reason: '5 + 1 returned − 2 sold');
    expect(rows('paneer'), 2);
    expect(saved('o1').items, hasLength(2));
  });

  test('its return still fails: refused before ANY write, the entry kept',
      () async {
    final o = await persist('o1', [paneer('a', 2)]);
    await leftCancel('o1', paneer('a', 3), savedQty: 2, qty: 1);
    items.failing.add('paneer');
    final kotBefore = lastKot();

    final r = await placeOrder(o,
        newLines: [naan('n', 1)],
        finalLines: [paneer('a', 2), naan('n', 1)]);

    expect(r.refused, isTrue);
    expect(r.conflict, startsWith(ExistingOrderUpdate.cancelPendingMessage));
    expect(r.conflict, contains('Paneer Tikka'));
    expectNothingWritten(o, kotBefore);
    expect(stock('naan'), 5, reason: 'naan not deducted');
    expect(stock('paneer'), 5);
    expect(cancels(), 1, reason: 'kept for the next attempt');

    // Once the write works again the same Place Order goes through.
    items.failing.clear();
    final again = await placeOrder(o,
        newLines: [naan('n', 1)],
        finalLines: [paneer('a', 2), naan('n', 1)]);
    expect(again.refused, isFalse);
    expect(stock('paneer'), 6);
    expect(stock('naan'), 4);
    expect(cancels(), 0);
  });

  test('another order\'s owed return on an item this sells: refused',
      () async {
    final o = await persist('o1', [paneer('a', 1)]);
    await persist('o2', [paneer('x', 1)]);
    await leftCancel('o2', paneer('x', 2), savedQty: 1, qty: 1);
    items.failing.add('paneer');
    final kotBefore = lastKot();

    final r = await placeOrder(o,
        newLines: [paneer('b', 1)],
        finalLines: [paneer('a', 1), paneer('b', 1)]);

    expect(r.refused, isTrue);
    expect(r.conflict, startsWith(ExistingOrderUpdate.cancelPendingMessage));
    expectNothingWritten(o, kotBefore);
  });

  test('another order\'s owed return on an item this only RESTORES: refused',
      () async {
    final o = await persist('o1', [paneer('a', 2), naan('n', 1)]);
    await persist('o2', [paneer('x', 1)]);
    await leftCancel('o2', paneer('x', 2), savedQty: 1, qty: 1);
    items.failing.add('paneer');

    final r = await placeOrder(o,
        returned: [paneer('a', 2)], finalLines: [naan('n', 1)]);

    expect(r.refused, isTrue);
    expect(r.conflict, startsWith(ExistingOrderUpdate.cancelPendingMessage));
    expect(builds, 0);
    expect(saved('o1').items, hasLength(2));
  });

  test('another order\'s owed return on an unrelated item: not blocking',
      () async {
    final o = await persist('o1', [paneer('a', 1)]);
    await persist('o2', [naan('x', 1)]);
    await leftCancel('o2', naan('x', 2), savedQty: 1, qty: 1);
    items.failing.add('naan');

    final r = await placeOrder(o,
        newLines: [paneer('b', 1)],
        finalLines: [paneer('a', 1), paneer('b', 1)]);

    expect(r.refused, isFalse);
    expect(stock('paneer'), 4);
    expect(cancels(), 1, reason: 'the naan return still waits for its turn');
  });

  test('a return handed to a person (review) does not block', () async {
    final o = await persist('o1', [paneer('a', 2)]);
    final entry = await leftCancel('o1', paneer('a', 3), savedQty: 2, qty: 1);
    for (final u in entry.units) {
      u.state = StockJournal.review;
    }
    await StockJournal.markOrderSaved(entry);

    final r = await placeOrder(o,
        newLines: [paneer('b', 1)],
        finalLines: [paneer('a', 2), paneer('b', 1)]);

    expect(r.refused, isFalse);
    expect(stock('paneer'), 4, reason: 'the review unit is never auto-applied');
    expect(cancels(), 1);
  });

  test('Settle\'s journal entries are left to Settle\'s own recovery',
      () async {
    final o = await persist('o1', [paneer('a', 1)]);
    // A Settle entry whose order write never happened: Settle's recovery
    // would discard it. Place Order must not run that recovery.
    await StockJournal.open(
      orderId: 'never-saved',
      target: {'z': 1},
      units: await InventoryService.planSaleDeductions([naan('z', 1)]),
    );

    final r = await placeOrder(o,
        newLines: [paneer('b', 1)],
        finalLines: [paneer('a', 1), paneer('b', 1)]);

    expect(r.refused, isFalse);
    expect(StockJournal.all(), hasLength(1));
    expect(stock('naan'), 5);
  });
}
