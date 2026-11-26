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
import 'package:billberrylite/domain/services/restaurant/existing_order_update.dart';
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

/// S-04D — Place Order on an EXISTING order (takeaway `_updateExistingOrder`)
/// checks what it adds, crediting what it hands back, inside the shared
/// StockGate, before any write; a failed save moves no stock.
///
/// Paneer: 5 on hand after the saved order's own lines left at placement;
/// "don't sell when out of stock".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('existing_order_update_');
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

  CartItem line(String id, int qty) => makeCartItem(
      id: id, productId: 'paneer', title: 'Paneer Tikka', price: 100,
      quantity: qty);

  Future<OrderModel> persist(List<CartItem> lines) async {
    final o = OrderModel(
      id: 'o1',
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
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
    return o;
  }

  OrderModel saved() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!;
  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;
  int movements() =>
      StockMovementRepository().movementsForItem('paneer').length;

  var builds = 0;

  /// Place Order on o1 as takeaway runs it: [newLines] added, [increases]
  /// (delta lines) raised, [returned] lines removed / reduced.
  Future<ExistingOrderUpdateResult> placeOrder(
    OrderModel o, {
    List<CartItem> increases = const [],
    List<CartItem> newLines = const [],
    List<CartItem> returned = const [],
    required List<CartItem> finalLines,
  }) =>
      ExistingOrderUpdate.commit(
        orderId: o.id,
        baseline: {for (final l in o.items) l.id: l.quantity},
        deduct: [...increases, ...newLines],
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
  test('sufficient stock: added lines are saved, KOT numbered, deducted once',
      () async {
    final o = await persist([line('a', 1)]);
    final r = await placeOrder(o,
        newLines: [line('b', 3)], finalLines: [line('a', 1), line('b', 3)]);

    expect(r.refused, isFalse);
    expect(r.newKotNumber, isNotNull);
    expect(saved().items, hasLength(2));
    expect(saved().kotNumbers, [1, r.newKotNumber]);
    expect(stock(), 2);
    expect(movements(), 1);
  });

  test('insufficient stock: refused before ANY write — no order change, no '
      'KOT number, no restore, no deduction', () async {
    builds = 0;
    final o = await persist([line('a', 2)]);
    final r = await placeOrder(o,
        newLines: [line('b', 6)],
        returned: const [],
        finalLines: [line('a', 2), line('b', 6)]);

    expect(r.refused, isTrue);
    expect(r.message, contains('available 5'));
    expect(builds, 0);
    expect(saved().items, hasLength(1));
    expect(saved().kotNumbers, [1]);
    expect(Hive.box(HiveBoxNames.appCounters).isEmpty, isTrue);
    expect(stock(), 5);
    expect(movements(), 0);
  });

  test('an increase is checked by its delta', () async {
    final o = await persist([line('a', 1)]);
    // 1 → 6 asks for 5: exactly what is on hand.
    expect(
        (await placeOrder(o, increases: [line('a', 5)], finalLines: [line('a', 6)]))
            .refused,
        isFalse);
    expect(stock(), 0);
  });

  test('units handed back in the same update are credited: reduce 3 → 1 and '
      'add 7 needs 7 − 2 = 5', () async {
    final o = await persist([line('a', 3)]);
    final r = await placeOrder(o,
        newLines: [line('b', 7)],
        returned: [line('a', 2)],
        finalLines: [line('a', 1), line('b', 7)]);

    expect(r.refused, isFalse, reason: r.message);
    expect(stock(), 0, reason: '5 + 2 restored − 7 sold');
  });

  test('...but the credit never covers more than is handed back', () async {
    final o = await persist([line('a', 3)]);
    final r = await placeOrder(o,
        newLines: [line('b', 8)],
        returned: [line('a', 2)],
        finalLines: [line('a', 1), line('b', 8)]);
    expect(r.refused, isTrue);
    expect(stock(), 5, reason: 'not even the restore runs');
  });

  test('a failed order save moves no stock — neither restore nor deduction — '
      'and releases the gate', () async {
    final o = await persist([line('a', 3)]);
    orderStore; // built while the box is open
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).close();

    await expectLater(
      placeOrder(o,
          newLines: [line('b', 2)],
          returned: [line('a', 1)],
          finalLines: [line('a', 2), line('b', 2)]),
      throwsA(isA<OrderSaveFailedException>()),
    );
    expect(stock(), 5);
    expect(movements(), 0);

    final next = await StockGate.sell([line('pos', 2)], write: (_) async {})
        .timeout(const Duration(seconds: 2));
    expect(next.refused, isFalse);
    expect(stock(), 3);
  });

  group('5 in stock, two sales for 4 — exactly one succeeds', () {
    Future<bool> addFour() async {
      final o = await persist([line('a', 1)]);
      final r = await placeOrder(o,
          newLines: [line('b', 4)], finalLines: [line('a', 1), line('b', 4)]);
      return !r.refused;
    }

    test('Place Order (existing) and a Captain order', () async {
      final results = await Future.wait<Object>([addFour(), captainOrder(4)]);
      expect([results[0] as bool, results[1] == 200].where((ok) => ok),
          hasLength(1));
      expect(stock(), 1, reason: 'never 5 - 8 = -3');
    });

    test('a Captain order first, then Place Order (existing)', () async {
      final captain = captainOrder(4);
      final placed = addFour();
      expect(await captain, 200);
      expect(await placed, isFalse);
      expect(stock(), 1);
      expect(saved().items, hasLength(1), reason: 'nothing written');
    });

    test('Place Order (existing) and Place Order (new)', () async {
      final results = await Future.wait<Object>([
        addFour(),
        StockGate.sell([line('pos', 4)], write: (_) async {}),
      ]);
      expect(
          [results[0] as bool, !(results[1] as GatedSale).refused]
              .where((ok) => ok),
          hasLength(1));
      expect(stock(), 1);
    });
  });

  test('called from inside the gate it does not deadlock', () async {
    final o = await persist([line('a', 1)]);
    final r = await StockGate.run(() => placeOrder(o,
            newLines: [line('b', 1)], finalLines: [line('a', 1), line('b', 1)]))
        .timeout(const Duration(seconds: 2));
    expect(r.refused, isFalse);
    expect(stock(), 4);
  });
}
