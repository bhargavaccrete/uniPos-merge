import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

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
import 'package:billberrylite/domain/services/restaurant/active_line_cancel.dart';
import 'package:billberrylite/domain/services/restaurant/existing_order_update.dart';
import 'package:billberrylite/domain/services/restaurant/order_line_cancel.dart';
import 'package:billberrylite/domain/services/restaurant/saved_service_charge.dart';
import 'package:billberrylite/domain/services/restaurant/stock_gate.dart';
import 'package:billberrylite/domain/services/restaurant/table_merge.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

class _TaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

class _Orders extends OrderStore {
  _Orders(super.repository);
  bool deleteFails = false;
  @override
  Future<bool> deleteOrder(String orderId) async {
    if (deleteFails) return false;
    return super.deleteOrder(orderId);
  }
}

/// Batch 3.1 — Merge Table ([TableMerge]): both orders as SAVED, inside the
/// stock gate; KOT numbers, positions and statuses kept; money exactly the
/// two orders added together, or refused.
///
/// Target o1 (T1): a = 3 × @100 on KOT 1. Source o2 (T2): s = 2 × @50 on
/// KOT 2. Paneer stock 10.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _Orders orders;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('table_merge_');
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
    await openRestaurantSessionForTest();

    orders = _Orders(OrderRepository());
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
      ..registerSingleton<OrderStore>(orders)
      ..registerSingleton<BusinessDetailsRepository>(_TaxBusiness());
    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'paneer',
        Items(id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
            stockQuantity: 10));
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CartItem line(String id, double price, int qty, {double? taxRate}) =>
      makeCartItem(
          id: id, productId: 'paneer', title: 'Paneer Tikka', price: price,
          quantity: qty, taxRate: taxRate);

  OrderModel mk(
    String id,
    String table,
    List<CartItem> items, {
    List<int>? kotNumbers,
    List<int>? kotBoundaries,
    Map<int, String>? kotStatuses,
    String status = 'Cooking',
    double? discount,
    double? serviceCharge,
    double? totalPaid,
    String? paymentListJson,
    bool inclusive = false,
  }) =>
      OrderModel(
        id: id,
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: items,
        status: status,
        timeStamp: DateTime(2026, 11, 11, 12),
        orderType: 'Dine In',
        tableNo: table,
        totalPrice: items.fold(0.0, (t, l) => t + l.price * l.quantity),
        kotNumbers: kotNumbers ?? [id == 'o1' ? 1 : 2],
        itemCountAtLastKot: items.length,
        kotBoundaries: kotBoundaries ?? [items.length],
        kotStatuses: kotStatuses,
        discount: discount,
        serviceCharge: serviceCharge,
        totalPaid: totalPaid,
        paymentListJson: paymentListJson,
        isTaxInclusive: inclusive,
      );

  Future<void> persist(OrderModel t, OrderModel s) async {
    final box = Hive.box<OrderModel>(HiveBoxNames.restaurantOrders);
    await box.put(t.id, t);
    await box.put(s.id, s);
    await orderStore.loadOrders();
  }

  /// Another write the POS's in-memory copy does not see (Captain, or this
  /// screen's own immediate cancel after the screen opened).
  Future<void> writeBehindPos(OrderModel o) =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);

  OrderModel? saved(String id) =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get(id);
  double stock() =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;

  Future<OrderModel> merge() =>
      TableMerge.commit(targetId: 'o1', sourceId: 'o2');

  Matcher refused() => throwsA(isA<TableMergeRefused>());

  Future<void> expectNothingWritten(OrderModel t, OrderModel s) async {
    expect(saved('o1')!.items.map((l) => l.id), t.items.map((l) => l.id));
    expect(saved('o1')!.kotNumbers, t.kotNumbers);
    expect(saved('o2'), isNotNull);
    expect(saved('o2')!.items.map((l) => l.id), s.items.map((l) => l.id));
  }

  // ==========================================================================
  group('the orders as SAVED', () {
    test('lines, KOT numbers and positions: source after target', () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      final m = await merge();

      expect(m.items.map((l) => '${l.id}:${l.quantity}'), ['a:3', 's:2']);
      expect(m.kotNumbers, [1, 2]);
      expect(m.kotBoundaries, [1, 2]);
      expect(m.itemCountAtLastKot, 2);
      expect(saved('o2'), isNull);
      expect(saved('o1')!.items, hasLength(2));
      expect(stock(), 10, reason: 'a merge moves no stock');
    });

    test('an immediate cancel the screen\'s copy predates stays cancelled',
        () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      await writeBehindPos(mk('o1', 'T1', [line('a', 100, 1)]));

      final m = await merge();
      expect(m.items.map((l) => '${l.id}:${l.quantity}'), ['a:1', 's:2']);
    });

    test('lines Captain added to the source after it was picked are kept',
        () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      await writeBehindPos(mk('o2', 'T2', [line('s', 50, 2), line('c', 80, 1)],
          kotNumbers: [2, 3], kotBoundaries: [1, 2]));

      final m = await merge();
      expect(m.items.map((l) => l.id), ['a', 's', 'c']);
      expect(m.kotNumbers, [1, 2, 3]);
      expect(m.kotBoundaries, [1, 2, 3]);
    });

    test('the source took a payment after it was picked: refused', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)]);
      final s = mk('o2', 'T2', [line('s', 50, 2)]);
      await persist(t, s);
      await writeBehindPos(mk('o2', 'T2', [line('s', 50, 2)], totalPaid: 20));

      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });

    test('the source was settled or removed: refused', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)]);
      await persist(t, mk('o2', 'T2', [line('s', 50, 2)]));
      await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).delete('o2');

      await expectLater(merge(), refused());
      expect(saved('o1')!.items, hasLength(1));
    });

    test('a shared KOT number: refused, nothing written', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)]);
      final s = mk('o2', 'T2', [line('s', 50, 2)], kotNumbers: [1]);
      await persist(t, s);
      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });

    test('runs inside the stock gate', () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      var inside = false;
      final pending = merge();
      await StockGate.run(() async => inside = saved('o2') != null);
      await pending;
      expect(inside, isFalse,
          reason: 'a gate holder queued after the merge sees it finished');
    });

    test('the source cannot be removed: the target is put back', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)]);
      final s = mk('o2', 'T2', [line('s', 50, 2)]);
      await persist(t, s);
      orders.deleteFails = true;

      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });
  });

  // ==========================================================================
  group('KOT statuses', () {
    test('every KOT keeps its own status, so cooked food stays cooked',
        () async {
      await persist(
        mk('o1', 'T1', [line('a', 100, 3)], status: 'Cooking'),
        mk('o2', 'T2', [line('s', 50, 2), line('r', 50, 1)],
            status: 'Processing',
            kotNumbers: [2, 3],
            kotBoundaries: [1, 2],
            kotStatuses: {3: 'Ready'}),
      );
      final m = await merge();

      expect(m.getKotStatus(1), 'Cooking');
      expect(m.getKotStatus(2), 'Processing',
          reason: 'it relied on the source order\'s status');
      expect(m.getKotStatus(3), 'Ready');
      expect(OrderLineCancel.isCooked(m, 'r'), isTrue);
      expect(OrderLineCancel.isCooked(m, 's'), isFalse);
      expect(m.kotStatuses!.containsKey(1), isFalse,
          reason: 'the target\'s KOTs still follow its order status');
    });

    test('a cooked source line cannot be cancelled after the merge', () async {
      await persist(
        mk('o1', 'T1', [line('a', 100, 3)]),
        mk('o2', 'T2', [line('s', 50, 2)], status: 'Served'),
      );
      // A served order is not a merge candidate; the KOT-level case is the
      // realistic one — the source KOT marked Ready by the kitchen.
      await expectLater(merge(), refused());

      await writeBehindPos(mk('o2', 'T2', [line('s', 50, 2)],
          kotStatuses: {2: 'Ready'}));
      await merge();
      await expectLater(
          ActiveLineCancel.commit(
              orderId: 'o1', lineId: 's', whenEmpty: WhenEmpty.refuse),
          throwsA(isA<ActiveLineCancelRefused>()));
      expect(stock(), 10);
    });
  });

  // ==========================================================================
  group('money: exactly the two orders added together, or refused', () {
    void expectSum(OrderModel m, OrderModel t, OrderModel s) {
      final tc = SavedServiceCharge.calculate(t, t.items, isDelivery: false);
      final sc = SavedServiceCharge.calculate(s, s.items, isDelivery: false);
      final mc = SavedServiceCharge.calculate(m, m.items, isDelivery: false);
      expect(m.discount, closeTo((t.discount ?? 0) + (s.discount ?? 0), 1e-9));
      expect(m.serviceCharge,
          closeTo((t.serviceCharge ?? 0) + (s.serviceCharge ?? 0), 1e-9));
      expect(mc.taxableAmount,
          closeTo(tc.taxableAmount + sc.taxableAmount, 0.01));
      expect(mc.totalGST, closeTo(tc.totalGST + sc.totalGST, 0.01));
      expect(mc.serviceChargeAmount,
          closeTo(tc.serviceChargeAmount + sc.serviceChargeAmount, 0.01));
      expect(m.subTotal, closeTo(tc.subtotal + sc.subtotal, 0.01));
      expect(m.gstAmount, closeTo(tc.totalGST + sc.totalGST, 0.01));
      expect(m.totalPrice, closeTo(tc.grandTotal + sc.grandTotal, 0.01));
    }

    test('different discounts, same tax rate: amounts added, totals exact',
        () async {
      final t = mk('o1', 'T1', [line('a', 100, 3, taxRate: 0.05)],
          discount: 30);
      final s = mk('o2', 'T2', [line('s', 50, 2, taxRate: 0.05)]);
      await persist(t, s);

      final m = await merge();
      expectSum(m, t, s);
      expect(m.subTotal, closeTo(370, 1e-9));
      expect(m.gstAmount, closeTo(18.5, 1e-9));
    });

    test('both orders discounted: both amounts carried', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3, taxRate: 0.05)],
          discount: 30);
      final s = mk('o2', 'T2', [line('s', 50, 2, taxRate: 0.05)],
          discount: 10);
      await persist(t, s);

      final m = await merge();
      expectSum(m, t, s);
      expect(m.discount, closeTo(40, 1e-9));
      expect(m.subTotal, closeTo(360, 1e-9));
    });

    test('same service-charge rate: amounts added, a later cancel re-prices '
        'at that rate', () async {
      // 10% on 283.5 (270 + 13.5 GST) and on 105.
      final t = mk('o1', 'T1', [line('a', 100, 3, taxRate: 0.05)],
          discount: 30, serviceCharge: 28.35);
      final s = mk('o2', 'T2', [line('s', 50, 2, taxRate: 0.05)],
          serviceCharge: 10.5);
      await persist(t, s);

      final m = await merge();
      expectSum(m, t, s);
      expect(m.serviceCharge, closeTo(38.85, 1e-9));
      expect(SavedServiceCharge.ratePercentOf(m, isDelivery: false),
          closeTo(10, 1e-9));

      await ActiveLineCancel.commit(
          orderId: 'o1', lineId: 's', whenEmpty: WhenEmpty.refuse);
      final after = saved('o1')!;
      final payable = after.subTotal! + after.gstAmount!;
      expect(after.serviceCharge, closeTo(payable * 0.10, 1e-9));
    });

    test('different service-charge rates: refused, nothing written', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)], serviceCharge: 30);
      final s = mk('o2', 'T2', [line('s', 50, 2)], serviceCharge: 5);
      await persist(t, s);
      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });

    test('a service charge on one order only: refused', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)], serviceCharge: 30);
      final s = mk('o2', 'T2', [line('s', 50, 2)]);
      await persist(t, s);
      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });

    test('a discount over items taxed at different rates: refused', () async {
      // Alone: 90 + 4.50 GST and 100 + 18 GST. Merged, the 10 would spread
      // over both lines and the GST would come to 21.85, not 22.50.
      final t = mk('o1', 'T1', [line('a', 100, 1, taxRate: 0.05)],
          discount: 10);
      final s = mk('o2', 'T2', [line('s', 100, 1, taxRate: 0.18)]);
      await persist(t, s);
      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });

    test('different tax rates and no discount: totals exact', () async {
      final t = mk('o1', 'T1', [line('a', 100, 1, taxRate: 0.05)]);
      final s = mk('o2', 'T2', [line('s', 100, 1, taxRate: 0.18)]);
      await persist(t, s);
      final m = await merge();
      expectSum(m, t, s);
      expect(m.gstAmount, closeTo(23, 1e-9));
    });

    test('different tax modes (inclusive / exclusive): refused', () async {
      final t = mk('o1', 'T1', [line('a', 105, 1, taxRate: 0.05)],
          inclusive: true);
      final s = mk('o2', 'T2', [line('s', 100, 1, taxRate: 0.05)]);
      await persist(t, s);
      await expectLater(
          merge(),
          throwsA(isA<TableMergeRefused>()
              .having((e) => e.message, 'message', contains('tax modes'))));
      await expectNothingWritten(t, s);
    });

    test('a part-paid target keeps its payment; the balance grows', () async {
      const legs = '[{"method":"cash","amount":100.0}]';
      final t = mk('o1', 'T1', [line('a', 100, 3)],
          totalPaid: 100, paymentListJson: legs);
      final s = mk('o2', 'T2', [line('s', 50, 2)]);
      await persist(t, s);

      final m = await merge();
      expect(m.totalPaid, 100);
      expect(m.paymentListJson, legs);
      expect(m.totalPrice, closeTo(400, 1e-9));
      expect(m.amountDue, closeTo(300, 1e-9));
    });

    test('a part-paid source: refused', () async {
      final t = mk('o1', 'T1', [line('a', 100, 3)]);
      final s = mk('o2', 'T2', [line('s', 50, 2)], totalPaid: 50);
      await persist(t, s);
      await expectLater(merge(), refused());
      await expectNothingWritten(t, s);
    });
  });

  // ==========================================================================
  group('Place Order after a merge (the cart\'s diff, as takeaway sends it)',
      () {
    Future<ExistingOrderUpdateResult> placeOrder(
      OrderModel m, {
      required Map<String, int> baseline,
      List<CartItem> newLines = const [],
    }) =>
        ExistingOrderUpdate.commit(
          orderId: m.id,
          baseline: baseline,
          deduct: newLines,
          restores: const [],
          needsKot: newLines.isNotEmpty,
          build: (plan, kot) async {
            final lines = [...m.items, ...plan.lines];
            return m.copyWith(
              items: lines,
              kotNumbers: [...m.kotNumbers, ?kot],
              kotBoundaries: [...m.kotBoundaries, if (kot != null) lines.length],
              itemCountAtLastKot: lines.length,
            );
          },
        );

    test('baseline reset to the merged order: accepted, only new lines '
        'deducted, no duplicate lines or KOTs', () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      final m = await merge();

      final r = await placeOrder(m,
          baseline: {for (final l in m.items) l.id: l.quantity},
          newLines: [line('n', 100, 1)]);
      expect(r.refused, isFalse);
      final o = saved('o1')!;
      expect(o.items.map((l) => l.id), ['a', 's', 'n']);
      expect(o.kotNumbers, hasLength(3));
      expect(o.kotBoundaries, [1, 2, 3]);
      expect(stock(), 9, reason: 'only the new line');
    });

    test('nothing new: accepted, no stock, no KOT', () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      final m = await merge();
      final r = await placeOrder(m,
          baseline: {for (final l in m.items) l.id: l.quantity});
      expect(r.refused, isFalse);
      expect(saved('o1')!.kotNumbers, [1, 2]);
      expect(stock(), 10);
    });

    test('the target-only baseline the cart kept before 3.1: refused as a '
        'change elsewhere', () async {
      await persist(mk('o1', 'T1', [line('a', 100, 3)]),
          mk('o2', 'T2', [line('s', 50, 2)]));
      final m = await merge();
      final r = await placeOrder(m, baseline: {'a': 3});
      expect(r.refused, isTrue);
      expect(r.conflict, isNotNull);
    });
  });
}
