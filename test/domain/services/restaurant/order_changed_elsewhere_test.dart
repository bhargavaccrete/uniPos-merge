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
import 'package:billberrylite/domain/services/restaurant/existing_order_update.dart';
import 'package:billberrylite/domain/services/restaurant/order_concurrency.dart';
import 'package:billberrylite/domain/services/restaurant/settle_line_commit.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// INVX-1 — Captain writes the order box directly; the POS screen's copy of
/// an open order can be behind. Place Order and Settle re-read the saved
/// order inside the stock gate and refuse — nothing written — when saving
/// the screen's lines would drop Captain's lines or revive lines Captain
/// cancelled (and already restored).
///
/// Order o1 (Dine In, T1, KOT 1): line a = 3 × Paneer. Paneer stock 5.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('order_elsewhere_');
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
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);
    await Hive.openBox(HiveBoxNames.appCounters);
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

    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
      'paneer',
      Items(
        id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
        stockQuantity: 5, allowOrderWhenOutOfStock: false,
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
  CartItem line(String id, int qty) => makeCartItem(
      id: id, productId: 'paneer', title: 'Paneer Tikka', price: 100,
      quantity: qty);
  CartItem fresh(int qty) => line('pos-${seq++}', qty);

  /// The order as the POS screen opened it (orderStore memory = saved).
  Future<OrderModel> persist() async {
    final o = OrderModel(
      id: 'o1',
      customerName: '',
      customerNumber: '',
      customerEmail: '',
      items: [line('a', 3)],
      status: 'Cooking',
      timeStamp: DateTime(2026, 11, 8, 12),
      orderType: 'Dine In',
      tableNo: 'T1',
      totalPrice: 300,
      kotNumbers: [1],
      itemCountAtLastKot: 1,
      kotBoundaries: [1],
      kotStatuses: {1: 'Cooking'},
      isTaxInclusive: false,
    );
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
    return o;
  }

  OrderModel? saved() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1');
  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;
  int movements() =>
      StockMovementRepository().movementsForItem('paneer').length;
  Map<dynamic, dynamic> counters() =>
      Map.of(Hive.box(HiveBoxNames.appCounters).toMap());
  bool journalEmpty() =>
      Hive.box(HiveBoxNames.restaurantStockJournal).isEmpty;

  /// Captain "Add Items" on o1 — writes the box, not orderStore.
  Future<void> captainAdds(int qty) async {
    final r = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': [line('cap', qty).toMap()],
        'orderType': 'Dine In',
        'tableNo': 'T1',
        'orderId': 'o1',
        'totalPrice': 0,
      }),
    ));
    expect(r.statusCode, 200, reason: await r.readAsString());
  }

  /// Captain Modify on o1: keep [keep] of line a, cancel the rest.
  Future<void> captainReducesA(int from, int keep) async {
    final r = await captainModifyOrderHandler(
      Request(
        'PUT',
        Uri.parse('http://localhost/captain/orders/o1/modify'),
        body: jsonEncode({
          'updatedItems': [line('a', keep).toMap()],
          'cancelledItems': [line('a', from - keep).toMap()],
        }),
      ),
      'o1',
    );
    expect(r.statusCode, 200, reason: await r.readAsString());
  }

  var builds = 0;

  /// Place Order as takeaway runs it, from the screen's [baseline].
  Future<ExistingOrderUpdateResult> placeOrder({
    required Map<String, int> baseline,
    required List<CartItem> finalLines,
    List<CartItem> newLines = const [],
    List<({CartItem line, int qty})> restores = const [],
    List<CartItem> returning = const [],
    OrderModel Function(OrderModel saved)? onBuild,
  }) =>
      ExistingOrderUpdate.commit(
        orderId: 'o1',
        baseline: baseline,
        deduct: newLines,
        returning: returning,
        restores: restores,
        needsKot: newLines.isNotEmpty,
        build: (plan, kot) async {
          builds++;
          final latest = orderStore.getOrderById('o1')!;
          onBuild?.call(latest);
          return latest.copyWith(
            items: finalLines,
            kotNumbers: [...latest.kotNumbers, ?kot],
            kotBoundaries: [
              ...latest.kotBoundaries,
              if (kot != null) finalLines.length,
            ],
            itemCountAtLastKot: finalLines.length,
          );
        },
      );

  // ==========================================================================
  group('the rules (OrderConcurrency)', () {
    test('Place Order: any difference from the baseline is another device',
        () {
      expect(
          OrderConcurrency.differsFromBaseline(
              baseline: {'a': 3}, saved: [line('a', 3)]),
          isFalse);
      expect(
          OrderConcurrency.differsFromBaseline(
              baseline: {'a': 3}, saved: [line('a', 3), line('cap', 1)]),
          isTrue, reason: 'line added elsewhere');
      expect(
          OrderConcurrency.differsFromBaseline(
              baseline: {'a': 3}, saved: [line('a', 1)]),
          isTrue, reason: 'line reduced elsewhere');
      expect(
          OrderConcurrency.differsFromBaseline(
              baseline: {'a': 3, 'b': 1}, saved: [line('a', 3)]),
          isTrue, reason: 'line removed elsewhere');
    });

    test('Settle: only what saving the lines would undo', () {
      bool undo(List<CartItem> base, List<CartItem> s, List<CartItem> cur) =>
          OrderConcurrency.settleWouldUndo(
              baseline: base, saved: s, current: cur);
      // The screen's own immediate cancel (snapshot predates it): fine.
      expect(undo([line('a', 3)], [line('a', 1)], [line('a', 1)]), isFalse);
      // New lines the screen adds: fine.
      expect(undo([line('a', 3)], [line('a', 3)], [line('a', 3), line('n', 1)]),
          isFalse);
      // Added elsewhere, missing from the screen: would be dropped.
      expect(undo([line('a', 3)], [line('a', 3), line('cap', 1)], [line('a', 3)]),
          isTrue);
      // Reduced elsewhere, screen still asks for more: would be re-sold.
      expect(undo([line('a', 3)], [line('a', 1)], [line('a', 3)]), isTrue);
      // Removed elsewhere, screen still has it.
      expect(undo([line('a', 3), line('b', 1)], [line('a', 3)],
          [line('a', 3), line('b', 1)]), isTrue);
    });
  });

  // ==========================================================================
  group('Place Order on an existing order', () {
    test('Captain added lines while the screen was open: refused, nothing '
        'written — no order, KOT, restore or stock change', () async {
      await persist();
      final baseline = {'a': 3}; // what the cart diffed against
      await captainAdds(1);
      final afterCaptain = saved()!;
      final stockAfterCaptain = stock();
      final movementsAfterCaptain = movements();
      final countersAfterCaptain = counters();
      builds = 0;

      final r = await placeOrder(
        baseline: baseline,
        newLines: [fresh(1)],
        finalLines: [line('a', 2), fresh(1)],
        restores: [(line: line('a', 3), qty: 1)],
        returning: [line('a', 1)],
      );

      expect(r.refused, isTrue);
      expect(r.conflict, OrderConcurrency.changedElsewhereMessage);
      expect(builds, 0);
      expect(saved()!.items.map((l) => (l.id, l.quantity)),
          afterCaptain.items.map((l) => (l.id, l.quantity)),
          reason: "Captain's line kept, line a not reduced");
      expect(saved()!.kotNumbers, afterCaptain.kotNumbers);
      expect(saved()!.totalPrice, afterCaptain.totalPrice);
      expect(stock(), stockAfterCaptain, reason: 'no restore, no deduction');
      expect(movements(), movementsAfterCaptain);
      expect(counters(), countersAfterCaptain, reason: 'no KOT number taken');
    });

    test('reopened (baseline from the refreshed order) it goes through and '
        "keeps Captain's line", () async {
      await persist();
      await captainAdds(1);
      expect((await placeOrder(baseline: {'a': 3}, finalLines: [line('a', 3)]))
          .refused, isTrue);

      // The refusal refreshed the POS's in-memory order, as the cart reads it.
      final reopened = orderStore.getOrderById('o1')!;
      final baseline = {for (final l in reopened.items) l.id: l.quantity};
      expect(baseline, {'a': 3, 'cap': 1});

      final r = await placeOrder(
        baseline: baseline,
        newLines: [fresh(1)],
        finalLines: [...reopened.items, fresh(1)],
      );
      expect(r.refused, isFalse, reason: r.message);
      expect(saved()!.items.map((l) => l.id), containsAll(['a', 'cap']));
    });

    test('Captain cancelled part of a line: refused, the screen cannot '
        'restore it a second time', () async {
      await persist();
      await captainReducesA(3, 1);
      expect(stock(), 7, reason: 'Captain restored 2');

      // The screen still thinks a = 3 and reduces it to 2 (restore 1).
      final r = await placeOrder(
        baseline: {'a': 3},
        finalLines: [line('a', 2)],
        restores: [(line: line('a', 3), qty: 1)],
        returning: [line('a', 1)],
      );
      expect(r.refused, isTrue);
      expect(stock(), 7, reason: 'not 8');
      expect(saved()!.items.single.quantity, 1);
    });

    test('order gone (settled or voided elsewhere): refused, not recreated',
        () async {
      await persist();
      await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).delete('o1');
      final r =
          await placeOrder(baseline: {'a': 3}, finalLines: [line('a', 3)]);
      expect(r.refused, isTrue);
      expect(r.conflict, OrderConcurrency.goneMessage);
      expect(saved(), isNull);
    });

    test('build reads the SAVED order: KOT status and payment changed '
        'elsewhere are kept', () async {
      await persist();
      // The KDS marks KOT 1 Ready and a part payment lands — box only.
      await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(
          'o1',
          saved()!.copyWith(kotStatuses: {1: 'Ready'}, totalPaid: 120));
      OrderModel? seen;
      final r = await placeOrder(
        baseline: {'a': 3},
        newLines: [fresh(1)],
        finalLines: [line('a', 3), fresh(1)],
        onBuild: (latest) => seen = latest,
      );
      expect(r.refused, isFalse);
      expect(seen!.kotStatuses![1], 'Ready');
      expect(seen!.totalPaid, 120);
      expect(saved()!.kotStatuses![1], 'Ready');
      expect(saved()!.totalPaid, 120);
    });
  });

  // ==========================================================================
  group('Settle on an existing order', () {
    test('Captain added lines: refused before any write — no journal, KOT, '
        'order change or stock', () async {
      final snapshot = await persist();
      await captainAdds(1);
      final afterCaptain = saved()!;
      final stockAfterCaptain = stock();
      final countersAfterCaptain = counters();

      await expectLater(
        SettleLineCommit.commit(
            snapshot: snapshot, itemsToSettle: [line('a', 3), fresh(1)]),
        throwsA(isA<OrderChangedElsewhereException>()),
      );
      expect(saved()!.items.map((l) => l.id),
          afterCaptain.items.map((l) => l.id));
      expect(stock(), stockAfterCaptain);
      expect(counters(), countersAfterCaptain);
      expect(journalEmpty(), isTrue);
    });

    test('Captain cancelled part of a line: refused, not sold again',
        () async {
      final snapshot = await persist();
      await captainReducesA(3, 1);
      await expectLater(
        SettleLineCommit.commit(snapshot: snapshot, itemsToSettle: [line('a', 3)]),
        throwsA(isA<OrderChangedElsewhereException>()),
      );
      expect(stock(), 7);
      expect(saved()!.items.single.quantity, 1);
      expect(journalEmpty(), isTrue);
    });

    test("the screen's own immediate cancel is not a conflict", () async {
      final snapshot = await persist();
      // Immediate cancel on this screen: saved a 3 → 1 via orderStore.
      await orderStore.updateOrder(saved()!.copyWith(items: [line('a', 1)]));
      final r = await SettleLineCommit.commit(
          snapshot: snapshot, itemsToSettle: [line('a', 1), fresh(1)]);
      expect(r.newKotNumber, isNotNull);
      expect(saved()!.items.map((l) => l.quantity), [1, 1]);
      expect(stock(), 4);
    });
  });
}
