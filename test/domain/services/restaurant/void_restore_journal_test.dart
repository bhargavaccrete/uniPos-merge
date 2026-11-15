import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/services/restaurant/kot_layout.dart';
import 'package:billberrylite/domain/services/restaurant/settle_new_order.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/services/restaurant/void_order_commit.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// The process stopping at that point. The journal box is closed at that
/// instant, so nothing the in-process error handling writes afterwards reaches
/// disk — the journal is exactly what a real stop would leave.
class _Crash implements Exception {}

Future<void> _freezeJournal() =>
    Hive.box(HiveBoxNames.restaurantStockJournal).close();

class _CrashingItems extends ItemStore {
  _CrashingItems() : super(ItemRepository());
  String? crashBeforeWrite;
  String? crashAfterWrite;

  @override
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
    Future<void> Function(double before, double after)? beforePersist,
  }) async {
    if (crashBeforeWrite == itemId) {
      crashBeforeWrite = null;
      // `applying` (before/after) is saved, then the stop — no stock write.
      return super.applyStockDelta(
        itemId: itemId,
        variantId: variantId,
        delta: delta,
        lastPurchaseCost: lastPurchaseCost,
        beforePersist: (b, a) async {
          await beforePersist?.call(b, a);
          await _freezeJournal();
          throw _Crash();
        },
      );
    }
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

/// How the void record's save behaves.
enum _Save { normal, crashAfterWrite, falseButSaved, throwsButSaved, falseNotSaved,
  throwsNotSaved, falseThenUnreadable, savedThenUnreadable }

class _Past extends PastOrderStore {
  _Past(super.repository, this.repo);
  final _Repo repo;
  _Save mode = _Save.normal;

  @override
  Future<bool> addOrder(PastOrderModel pastOrder) async {
    switch (mode) {
      case _Save.normal:
        return super.addOrder(pastOrder);
      case _Save.crashAfterWrite:
        await super.addOrder(pastOrder);
        await _freezeJournal();
        throw _Crash();
      case _Save.falseButSaved:
        await super.addOrder(pastOrder);
        return false;
      case _Save.throwsButSaved:
        await super.addOrder(pastOrder);
        throw StateError('write reported an error after landing');
      case _Save.falseNotSaved:
        return false;
      case _Save.throwsNotSaved:
        throw StateError('disk full');
      case _Save.falseThenUnreadable:
        repo.readFails = true;
        return false;
      case _Save.savedThenUnreadable:
        await super.addOrder(pastOrder);
        repo.readFails = true;
        return false;
    }
  }
}

class _Repo extends PastOrderRepository {
  bool readFails = false;
  @override
  Future<PastOrderModel?> getOrderById(String orderId) async {
    if (readFails) throw StateError('read failed');
    return super.getOrderById(orderId);
  }
}

class _Orders extends OrderStore {
  _Orders(super.repository);
  bool crashOnDelete = false;
  @override
  Future<bool> deleteOrder(String orderId) async {
    if (crashOnDelete) {
      crashOnDelete = false;
      await _freezeJournal();
      throw _Crash();
    }
    return super.deleteOrder(orderId);
  }
}

/// SALE-4 + owner rule: a void restores its stock exactly once — never twice,
/// never permanently missing — across a stop at any point, and a saved void
/// record is never left without its stock return.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _CrashingItems items;
  late _Past past;
  late _Repo repo;
  late _Orders orders;

  Future<void> openWorld() async {
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);

    items = _CrashingItems();
    repo = _Repo();
    past = _Past(repo, repo);
    orders = _Orders(OrderRepository());
    locator
      ..registerSingleton<ItemStore>(items)
      ..registerLazySingleton<VariantStore>(() => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerSingleton<PastOrderRepository>(repo)
      ..registerSingleton<PastOrderStore>(past)
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerSingleton<OrderStore>(orders)
      ..registerLazySingleton<TableStore>(() => TableStore(TableRepository()));
    await itemStore.loadItems();
    await variantStore.loadVariants();
    await orderStore.loadOrders();
  }

  Future<void> restart() async {
    await locator.reset();
    await Hive.close();
    await openWorld();
  }

  // A: stamped line, all from own stock. R: recipe (legacy line → fresh).
  // P: variant Small. W: sold by weight, 2 × 500 g.
  final lines = [
    makeCartItem(id: 'lA', productId: 'A', title: 'A', price: 10, quantity: 2)
        .copyWith(ownStockQty: 2, freshQty: 0),
    makeCartItem(id: 'lR', productId: 'R', title: 'R', price: 10, quantity: 2),
    makeCartItem(id: 'lP', productId: 'P', title: 'P', price: 10, quantity: 1,
        variantName: 'Small'),
    makeCartItem(id: 'lW', productId: 'W', title: 'W', price: 10, quantity: 2)
        .copyWith(weightDisplay: '500GM'),
  ];

  OrderModel activeOrder({Map<int, String>? kotStatuses}) => OrderModel(
        id: 'o1',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: lines,
        status: 'Processing',
        timeStamp: DateTime(2026, 11, 6, 12),
        orderType: 'Dine In',
        tableNo: 'T5',
        totalPrice: 60,
        kotNumbers: [1],
        itemCountAtLastKot: lines.length,
        kotBoundaries: [lines.length],
        kotStatuses: kotStatuses ?? {1: 'Processing'},
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('void_restore_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    final box = await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    for (final id in ['A', 'X', 'Y']) {
      await box.put(id, Items(id: id, name: id, trackInventory: true, stockQuantity: 10));
    }
    await box.put('R', Items(id: 'R', name: 'R', productType: ProductType.recipeBased));
    await box.put('P', Items(id: 'P', name: 'P', trackInventory: true, variant: [
      ItemVariante(variantId: 'small', price: 10, trackInventory: true, stockQuantity: 5),
    ]));
    await box.put('W', Items(id: 'W', name: 'W', trackInventory: true, stockQuantity: 2,
        isSoldByWeight: true, unit: 'kg'));
    final variants = await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await variants.put('small', VariantModel(id: 'small', name: 'Small'));
    final recipes = await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await recipes.put('r-R', RecipeModel(id: 'r-R', itemId: 'R', ingredients: [
      RecipeIngredientModel(ingredientItemId: 'X', quantity: 1),
      RecipeIngredientModel(ingredientItemId: 'Y', quantity: 2),
    ]));
    await Hive.close();
    await openWorld();
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put('o1', activeOrder());
    await Hive.box<TableModel>(HiveBoxNames.restaurantTables)
        .put('T5', TableModel(id: 'T5', status: 'Running', currentOrderId: 'o1'));
    await restart();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  double stock(String id) => Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  double small() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('P')!.variant!.single.stockQuantity!;
  List<StockMovementModel> rows() => [
        for (final id in ['A', 'X', 'Y', 'P', 'W'])
          ...StockMovementRepository().movementsForItem(id),
      ];
  int journal() => Hive.box(HiveBoxNames.restaurantStockJournal).length;
  bool active() => Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).containsKey('o1');
  String? recordStatus() =>
      Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).get('o1')?.orderStatus;
  String tableStatus() => Hive.box<TableModel>(HiveBoxNames.restaurantTables).get('T5')!.status;
  String snapshot() =>
      [stock('A'), stock('X'), stock('Y'), small(), stock('W'), rows().length,
        journal(), active(), recordStatus(), tableStatus()].join('|');

  /// What one finished void leaves.
  void expectRestoredOnce() {
    expect(stock('A'), 12, reason: 'A returned once');
    expect(stock('X'), 12, reason: 'recipe ingredient X returned once');
    expect(stock('Y'), 14, reason: 'recipe ingredient Y returned once');
    expect(small(), 6, reason: 'variant returned once');
    expect(stock('W'), 3, reason: 'weight returned once (2 × 0.5 kg)');
    expect(rows(), hasLength(5), reason: 'one row per stock write');
    expect(rows().every((r) => r.type == 'in'), isTrue);
    expect(rows().map((r) => r.id).toSet(), hasLength(5), reason: 'fixed ids, no repeats');
    expect(recordStatus(), 'VOID');
    expect(active(), isFalse, reason: 'removed from active orders');
    expect(tableStatus(), 'Available');
    expect(journal(), 0, reason: 'nothing left to finish');
  }

  void expectUntouched() {
    expect([stock('A'), stock('X'), stock('Y'), small(), stock('W')], [10, 10, 10, 5, 2]);
    expect(rows(), isEmpty);
    expect(active(), isTrue, reason: 'the order stays active');
    expect(recordStatus(), isNull);
    expect(tableStatus(), 'Running');
  }

  Future<VoidResult> voidIt() {
    final order = activeOrder();
    final plan = KotLayout.voidPlan(
      items: order.items,
      kotNumbers: order.kotNumbers,
      kotBoundaries: order.kotBoundaries,
      kotStatuses: order.kotStatuses ?? {},
      orderStatus: order.status,
    );
    return VoidOrderCommit.commit(
      order: order,
      record: PastOrderModel(
        id: 'o1',
        customerName: '',
        totalPrice: 60,
        items: plan.recordItems,
        orderAt: DateTime(2026, 11, 6, 12),
        orderType: 'Dine In',
        paymentmode: 'N/A',
        subTotal: 60,
        gstRate: 0,
        gstAmount: 0,
        kotNumbers: order.kotNumbers,
        kotBoundaries: order.kotBoundaries,
        orderStatus: 'VOID',
        tableNo: 'T5',
      ),
      restores: plan.restores,
    );
  }

  Future<void> recoverThrice() async {
    await restart();
    await VoidOrderCommit.recoverAll();
    final once = snapshot();
    for (var i = 0; i < 2; i++) {
      await restart();
      await VoidOrderCommit.recoverAll();
      expect(snapshot(), once, reason: 'recovery run ${i + 2} changed nothing');
    }
  }

  test('no interruption: restored once', () async {
    expect((await voidIt()).stockFinished, isTrue);
    expectRestoredOnce();
  });

  group('a stop at every point: recovery restores exactly once', () {
    test('entry saved, no void record: dropped, order stays active', () async {
      await StockJournal.openVoid(
        orderId: 'o1', tableNo: 'T5', staffName: 'S', sessionId: null,
        units: await InventoryService.planRestoreUnits(KotLayout.voidPlan(
          items: lines, kotNumbers: [1], kotBoundaries: [lines.length],
          kotStatuses: {1: 'Processing'}, orderStatus: 'Processing').restores),
      );
      await recoverThrice();
      expectUntouched();
      expect(journal(), 0);
    });

    test('record saved, then the stop', () async {
      past.mode = _Save.crashAfterWrite;
      await expectLater(voidIt(), throwsA(anything));
      await recoverThrice();
      expectRestoredOnce();
    });

    test('record saved, stop while removing the active order', () async {
      orders.crashOnDelete = true;
      await expectLater(voidIt(), throwsA(isA<_Crash>()));
      await recoverThrice();
      expectRestoredOnce();
    });

    for (final id in ['A', 'X', 'Y', 'P', 'W']) {
      test('unit $id: applying recorded, stock not yet written', () async {
        items.crashBeforeWrite = id;
        final r = await voidIt();
        expect(r.stockFinished, isFalse);
        await recoverThrice();
        expectRestoredOnce();
      });

      test('unit $id: stock written, its row not yet', () async {
        items.crashAfterWrite = id;
        final r = await voidIt();
        expect(r.stockFinished, isFalse);
        await recoverThrice();
        expectRestoredOnce();
      });
    }

    test('voiding again in the same session resumes, never plans twice', () async {
      items.crashAfterWrite = 'X';
      expect((await voidIt()).stockFinished, isFalse);
      await restart();
      // The order is gone from the list; a second void attempt must not
      // restore anything again.
      await VoidOrderCommit.recoverAll();
      await VoidOrderCommit.recoverAll();
      expectRestoredOnce();
    });
  });

  group('the save reports failure: the record is re-read, never trusted', () {
    test('false, but the record landed → stock restored once', () async {
      past.mode = _Save.falseButSaved;
      expect((await voidIt()).stockFinished, isTrue);
      expectRestoredOnce();
    });

    test('throws, but the record landed → stock restored once', () async {
      past.mode = _Save.throwsButSaved;
      expect((await voidIt()).stockFinished, isTrue);
      expectRestoredOnce();
    });

    test('false, no record → entry removed, nothing restored', () async {
      past.mode = _Save.falseNotSaved;
      await expectLater(voidIt(), throwsA(isA<OrderSaveFailedException>()));
      expectUntouched();
      expect(journal(), 0);
    });

    test('throws, no record → entry removed, nothing restored', () async {
      past.mode = _Save.throwsNotSaved;
      await expectLater(voidIt(), throwsA(isA<OrderSaveFailedException>()));
      expectUntouched();
      expect(journal(), 0);
    });

    test('record cannot be read after a failed save → entry kept; absent later '
        '→ dropped', () async {
      past.mode = _Save.falseThenUnreadable;
      await expectLater(voidIt(), throwsA(isA<OrderSaveFailedException>()));
      expect(journal(), 1, reason: 'never discarded on a failed read');
      expect(rows(), isEmpty);
      await recoverThrice();
      expectUntouched();
      expect(journal(), 0);
    });

    test('record landed but cannot be read → entry kept; recovery restores once',
        () async {
      past.mode = _Save.savedThenUnreadable;
      await expectLater(voidIt(), throwsA(isA<OrderSaveFailedException>()));
      expect(journal(), 1, reason: 'a saved void keeps its stock return');
      expect(rows(), isEmpty);
      await recoverThrice();
      expectRestoredOnce();
    });
  });

  test('stock changed by something else after a stop: reported, not written',
      () async {
    items.crashAfterWrite = 'A';
    await voidIt();
    await restart();
    // A was written to 12; something else sets it to 7 before recovery.
    await itemStore.applyStockDelta(itemId: 'A', delta: -5);
    items.crashBeforeWrite = null;
    // The unit was `applying`; recovery finds neither before (10) nor after (12).
    await Hive.box(HiveBoxNames.restaurantStockJournal).put(
        StockJournal.voidKey('o1'),
        (Hive.box(HiveBoxNames.restaurantStockJournal).get(StockJournal.voidKey('o1'))
            as Map));
    await VoidOrderCommit.recoverAll();
    await VoidOrderCommit.recoverAll();
    expect(stock('A'), 7, reason: 'never written on a guess');
    expect(StockMovementRepository().movementsForItem('A'), isEmpty);
    expect(Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications)
        .values.where((n) => n.eventCode == StockJournal.reviewEvent), hasLength(1));
    expect(stock('X'), 12, reason: 'the other units still finished');
    expect(journal(), 1, reason: 'kept as the record of what to check');
  });

  test('served KOT lines are not returned', () async {
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders)
        .put('o1', activeOrder(kotStatuses: {1: 'Served'}));
    final order = activeOrder(kotStatuses: {1: 'Served'});
    final plan = KotLayout.voidPlan(items: order.items, kotNumbers: [1],
        kotBoundaries: [lines.length], kotStatuses: {1: 'Served'}, orderStatus: 'Served');
    expect(await InventoryService.planRestoreUnits(plan.restores), isEmpty);
  });

  test('the planner returns what restoreLines returns', () async {
    final requests = [for (final l in lines) (line: l, qty: l.quantity)];
    final planned = await InventoryService.planRestoreUnits(requests);
    final byKey = <String, double>{};
    for (final u in planned) {
      final key = '${u.item.id}:${u.variantId}';
      byKey[key] = (byKey[key] ?? 0) + u.qty;
    }
    final before = {for (final id in ['A', 'X', 'Y', 'W']) id: stock(id)};
    final smallBefore = small();
    await InventoryService.restoreLines(requests);
    for (final id in ['A', 'X', 'Y', 'W']) {
      expect(stock(id) - before[id]!, closeTo(byKey['$id:null'] ?? 0, 1e-9),
          reason: 'item $id');
    }
    expect(small() - smallBefore, byKey['P:small']);
  });

  test("Settle's recovery leaves void entries alone", () async {
    items.crashAfterWrite = 'X';
    await voidIt();
    await restart();
    final stocks = snapshot();
    await StockJournal.recoverAll();
    expect(snapshot(), stocks);
    expect(StockJournal.all(), isEmpty, reason: 'Settle does not even see them');
    expect(StockJournal.voidEntries(), hasLength(1));
  });

  test('entries written before `direction` existed still deduct', () {
    final old = JournalUnit.fromMap({
      'uid': 'settle:1:l', 'itemId': 'A', 'variantId': null, 'qty': 2.0,
      'reason': 'Sale', 'itemName': 'A', 'unit': 'pcs', 'unitCost': null,
      'state': StockJournal.planned, 'before': null, 'after': null,
    });
    expect(old.isInbound, isFalse);
    expect(old.delta, -2);
    expect(old.toMap().containsKey('direction'), isFalse,
        reason: 'a sale entry is written exactly as before');
  });

  test('a table already holding another order is not freed', () async {
    await Hive.box<TableModel>(HiveBoxNames.restaurantTables)
        .put('T5', TableModel(id: 'T5', status: 'Running', currentOrderId: 'o2'));
    await restart();
    await voidIt();
    expect(tableStatus(), 'Running');
  });
}
