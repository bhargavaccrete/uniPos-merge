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
import 'package:billberrylite/domain/services/restaurant/settle_new_order.dart';
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

/// A past-order store whose save fails the way the real one reports it.
class _RefusingPastOrderStore extends PastOrderStore {
  _RefusingPastOrderStore(super.repository);

  @override
  Future<bool> addOrder(PastOrderModel pastOrder) async => false;
}

/// S-04B — Settle & Print / Delivery on a NEW order (customerdetails
/// `_placeOrder`, `isSettle`) checks stock at placement, inside the shared
/// StockGate, and never deducts for a bill that was not saved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settle_new_order_');
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
  Box<PastOrderModel> pastBox() =>
      Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
  int movements() =>
      StockMovementRepository().movementsForItem('paneer').length;

  var builds = 0;

  /// Settle & Print as customerdetails runs it (fields trimmed to the ones
  /// the commit itself fills in).
  Future<SettleNewOrderResult> settle(int qty) {
    final items = [paneer(qty)];
    return SettleNewOrder.commit(
      items: items,
      build: (lines, kot, bill) async {
        builds++;
        return PastOrderModel(
          id: 'bill-${seq++}',
          customerName: 'Walk-in',
          totalPrice: 100.0 * qty,
          items: lines,
          orderAt: DateTime.now(),
          orderType: 'Take Away',
          paymentmode: 'Cash',
          subTotal: 100.0 * qty,
          gstRate: 0,
          gstAmount: 0,
          kotNumbers: [kot],
          kotBoundaries: [items.length],
          billNumber: bill,
        );
      },
    );
  }

  Future<int> captainOrder(int qty) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': [paneer(qty).toMap()],
        'orderType': 'Take Away',
        'totalPrice': 0,
      }),
    ));
    await response.readAsString();
    return response.statusCode;
  }

  // ==========================================================================
  test('sufficient stock: the bill is saved, numbered, and stock deducted once',
      () async {
    final r = await settle(3);

    expect(r.refused, isFalse);
    expect(pastBox().length, 1);
    final saved = pastBox().values.single;
    expect(saved.billNumber, r.billNumber);
    expect(saved.kotNumbers, [r.kotNumber]);
    expect(saved.items.single.ownStockQty, 3, reason: 'stamped plan lines');
    expect(r.order!.id, saved.id);
    expect(stock(), 2);
    expect(movements(), 1);
  });

  test('insufficient stock: refused before ANY write — no bill, no KOT or '
      'bill number, no deduction', () async {
    builds = 0;
    final r = await settle(6);

    expect(r.refused, isTrue);
    expect(r.sale.message, contains('Paneer Tikka'));
    expect(r.sale.message, contains('available 5'));
    expect(r.order, isNull);
    expect(builds, 0, reason: 'the bill is never even built');
    expect(pastBox().isEmpty, isTrue);
    expect(Hive.box(HiveBoxNames.appCounters).isEmpty, isTrue,
        reason: 'no KOT or bill number taken');
    expect(stock(), 5);
    expect(movements(), 0);
  });

  test('a bill save that returns false deducts nothing and releases the gate',
      () async {
    // PastOrderStore.addOrder reports a failed write by returning false — the
    // result the screen used to ignore (it deducted and showed success).
    locator.unregister<PastOrderStore>();
    locator.registerLazySingleton<PastOrderStore>(
        () => _RefusingPastOrderStore(locator<PastOrderRepository>()));

    await expectLater(settle(3), throwsA(isA<OrderSaveFailedException>()));
    expect(stock(), 5, reason: 'never deduct for an unsaved bill');
    expect(movements(), 0);

    // The gate is free: a Captain order goes straight through.
    expect(await captainOrder(2), 200);
    expect(stock(), 3);
  });

  test('a bill save that throws deducts nothing and releases the gate',
      () async {
    await pastBox().close(); // the write now throws a HiveError
    await expectLater(settle(3), throwsA(isA<HiveError>()));
    expect(stock(), 5);
    expect(movements(), 0);
    expect(await captainOrder(2), 200);
    expect(stock(), 3);
  });

  group('5 in stock, two orders for 4 — exactly one succeeds', () {
    test('Settle & Print and a Captain order', () async {
      final results = await Future.wait<Object>([settle(4), captainOrder(4)]);
      final settled = results[0] as SettleNewOrderResult;
      final captain = results[1] as int;

      expect([!settled.refused, captain == 200].where((ok) => ok),
          hasLength(1));
      expect(stock(), 1, reason: 'never 5 - 8 = -3');
    });

    test('a Captain order first, then Settle & Print', () async {
      final captain = captainOrder(4);
      // SEC-20: Captain reads its body BEFORE queueing for the gate, so let
      // it arrive before Settle starts.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final settled = settle(4);
      expect(await captain, 200);
      expect((await settled).refused, isTrue);
      expect(stock(), 1);
      expect(pastBox().isEmpty, isTrue);
    });

    test('Settle & Print and a Place Order (StockGate.sell)', () async {
      final results = await Future.wait<Object>([
        settle(4),
        StockGate.sell([paneer(4)], write: (_) async {}),
      ]);
      final settled = results[0] as SettleNewOrderResult;
      final placed = results[1] as GatedSale;
      expect([!settled.refused, !placed.refused].where((ok) => ok),
          hasLength(1));
      expect(stock(), 1);
    });

    test('two Settle & Prints', () async {
      final results = await Future.wait([settle(4), settle(4)]);
      expect(results.where((r) => !r.refused), hasLength(1));
      expect(pastBox().length, 1);
      expect(stock(), 1);
    });
  });

  test('called from inside the gate it does not deadlock', () async {
    final r = await StockGate.run(() => settle(2))
        .timeout(const Duration(seconds: 2));
    expect(r.refused, isFalse);
    expect(stock(), 3);
  });
}
