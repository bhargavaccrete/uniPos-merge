import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/pre_refund_events_past_order_adapter.dart';
import '../../../helpers/test_helpers.dart';

/// SB-2b: every restaurant refund is recorded as its own event (validated
/// amount, time, session) in the same order write as the running total, and
/// EOD counts each refund only in the session it happened in — refunds,
/// sales, tax and payment-method/cash adjustments alike.
///
/// Orders refunded before events existed fall back to one event built from
/// `refundAmount` + `refundedAt` (the old result). How their earlier refunds
/// were split across sessions was never stored and cannot be reconstructed.
void main() {
  late Directory tempDir;
  final yesterday = DateTime.now().subtract(const Duration(days: 1));

  setUp(() async {
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('eod_refund_sessions_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');

    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<Expense>(HiveBoxNames.restaurantExpense);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<Customer>(HiveBoxNames.customer);

    locator
      ..registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService())..licenseBypassed = true)
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<ExpenseStore>(
          () => ExpenseStore(ExpenseRepository()))
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<CustomerStore>(
          () => CustomerStore(CustomerRepository()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── helpers ────────────────────────────────────────────────────────────

  Box<PastOrderModel> orders() =>
      Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);

  String events(List<RefundEvent> list) => RefundEvent.encodeAll(list);

  PastOrderModel pastOrder({
    required String id,
    required String sessionId,
    required double total,
    double gst = 0,
    String paymentmode = 'cash',
    double refundAmount = 0,
    DateTime? refundedAt,
    String? refundEventsJson,
    String status = 'COMPLETED',
    String? paymentListJson,
    DateTime? orderAt,
  }) {
    final items = [makeCartItem(price: total, quantity: 1, categoryName: 'Food')];
    return PastOrderModel(
      id: id,
      customerName: 'Test',
      totalPrice: total,
      subTotal: total - gst,
      gstAmount: gst,
      items: items,
      orderAt: orderAt ?? DateTime.now(),
      orderType: 'Take Away',
      paymentmode: paymentmode,
      refundAmount: refundAmount,
      refundedAt: refundedAt,
      refundEventsJson: refundEventsJson,
      orderStatus: status,
      sessionId: sessionId,
      isSplitPayment: paymentListJson != null,
      paymentListJson: paymentListJson,
      kotNumbers: [1],
      kotBoundaries: [1],
    );
  }

  Future<void> seed(List<PastOrderModel> list) async {
    for (final o in list) {
      await orders().put(o.id, o);
    }
  }

  /// The EOD of [sessionId] as `generateEODReport` builds it at close.
  Future<EndOfDayReport> eod(String sessionId, {double actualCash = 0}) =>
      EODService.generateEODReport(
        date: DateTime.now(),
        openingBalance: 0,
        actualCash: actualCash,
        sessionId: sessionId,
      );

  double bucket(EndOfDayReport r, String type) => r.paymentSummaries
      .where((p) => p.paymentType.toLowerCase() == type)
      .fold(0.0, (s, p) => s + p.totalAmount);

  /// Opens [id] as the current session, started at [start].
  Future<void> openSession(String id, DateTime start) async {
    await Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions).put(
        id, RestaurantSessionModel(sessionId: id, startTime: start, openingCash: 0));
    await Hive.box(HiveBoxNames.dayManagementBox).put('currentSessionId', id);
  }

  // ── EOD attribution ────────────────────────────────────────────────────

  group('EOD counts each refund in its own session', () {
    test('sale + ₹300 refund in A, ₹200 refund in B: B counts only 200',
        () async {
      final now = DateTime.now();
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          gst: 50,
          refundAmount: 500,
          refundedAt: now,
          status: 'PARTIALLY_REFUNDED',
          refundEventsJson: events([
            RefundEvent(amount: 300, at: yesterday, sessionId: 'A'),
            RefundEvent(amount: 200, at: now, sessionId: 'B'),
          ]),
        ),
        pastOrder(id: 'B1', sessionId: 'B', total: 400, gst: 20),
      ]);

      final b = await eod('B', actualCash: 200);

      expect(b.totalRefunds, closeTo(200, 1e-9), reason: 'not 500');
      expect(b.totalSales, closeTo(400 - 200, 1e-9));
      expect(b.totalTax, closeTo(20 - 200 * 50 / 1000, 1e-9), reason: 'GST 10, not 25');
      expect(bucket(b, 'cash'), closeTo(400 - 200, 1e-9));
      expect(b.cashReconciliation.difference, closeTo(0, 1e-9),
          reason: 'no false shortage from the refund already paid out in A');
    });

    test("A's own report (taken at A's close) counts the 300", () async {
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          gst: 50,
          refundAmount: 300,
          refundedAt: DateTime.now(),
          status: 'PARTIALLY_REFUNDED',
          refundEventsJson: events([
            RefundEvent(amount: 300, at: DateTime.now(), sessionId: 'A'),
          ]),
        ),
      ]);

      final a = await eod('A');

      expect(a.totalRefunds, closeTo(300, 1e-9));
      expect(a.totalSales, closeTo(700, 1e-9));
      expect(bucket(a, 'cash'), closeTo(700, 1e-9));
    });

    test('three sessions: ₹100 in B then ₹50 in C — C counts 50', () async {
      final now = DateTime.now();
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 150,
          refundedAt: now,
          status: 'PARTIALLY_REFUNDED',
          refundEventsJson: events([
            RefundEvent(amount: 100, at: yesterday, sessionId: 'B'),
            RefundEvent(amount: 50, at: now, sessionId: 'C'),
          ]),
        ),
        pastOrder(id: 'C1', sessionId: 'C', total: 300),
      ]);

      final c = await eod('C');

      expect(c.totalRefunds, closeTo(50, 1e-9));
      expect(c.totalSales, closeTo(250, 1e-9));
      expect(bucket(c, 'cash'), closeTo(250, 1e-9));
    });

    test('split payment refunded in a later session: each method by its share',
        () async {
      final now = DateTime.now();
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 500,
          refundedAt: now,
          status: 'PARTIALLY_REFUNDED',
          paymentListJson: jsonEncode([
            {'method': 'cash', 'amount': 600.0},
            {'method': 'upi', 'amount': 400.0},
          ]),
          refundEventsJson: events([
            RefundEvent(amount: 300, at: yesterday, sessionId: 'A'),
            RefundEvent(amount: 200, at: now, sessionId: 'B'),
          ]),
        ),
        pastOrder(id: 'B1', sessionId: 'B', total: 500, paymentmode: 'cash'),
        pastOrder(id: 'B2', sessionId: 'B', total: 500, paymentmode: 'upi'),
      ]);

      final b = await eod('B');

      // 200 refunded in B, split 60/40 like the original payment.
      expect(bucket(b, 'cash'), closeTo(500 - 120, 1e-9));
      expect(bucket(b, 'upi'), closeTo(500 - 80, 1e-9));
      expect(b.totalRefunds, closeTo(200, 1e-9));
    });

    test('refunded in A, voided in B: B subtracts nothing', () async {
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 300,
          refundedAt: yesterday,
          status: 'PARTIALLY_REFUNDED',
          refundEventsJson: events([
            RefundEvent(amount: 300, at: yesterday, sessionId: 'A'),
          ]),
        ),
        pastOrder(id: 'B1', sessionId: 'B', total: 400),
      ]);
      await RefundService.voidOrder(order: orders().get('O1')!, reason: 'test');
      expect(orders().get('O1')!.orderStatus, 'VOIDED');

      final b = await eod('B');

      expect(b.totalRefunds, 0);
      expect(b.totalSales, closeTo(400, 1e-9));
      expect(bucket(b, 'cash'), closeTo(400, 1e-9));
    });

    test(
        'two sessions on the same day: a refund made earlier today in A is '
        'not counted in B, although it is inside B\'s day window', () async {
      final earlierToday = DateTime.now().subtract(const Duration(minutes: 5));
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 300,
          refundedAt: earlierToday,
          status: 'PARTIALLY_REFUNDED',
          refundEventsJson: events([
            RefundEvent(amount: 300, at: earlierToday, sessionId: 'A'),
          ]),
        ),
        pastOrder(id: 'B1', sessionId: 'B', total: 400),
      ]);

      final b = await eod('B');

      expect(b.totalRefunds, 0, reason: 'attributed by session, not by clock');
      expect(b.totalSales, closeTo(400, 1e-9));
      expect(bucket(b, 'cash'), closeTo(400, 1e-9));
    });

    test('a same-session refund is counted exactly as before', () async {
      await seed([
        pastOrder(
          id: 'B1',
          sessionId: 'B',
          total: 300,
          gst: 15,
          refundAmount: 150,
          refundedAt: DateTime.now(),
          status: 'PARTIALLY_REFUNDED',
          refundEventsJson: events([
            RefundEvent(amount: 150, at: DateTime.now(), sessionId: 'B'),
          ]),
        ),
      ]);

      final b = await eod('B');

      expect(b.totalRefunds, closeTo(150, 1e-9));
      expect(b.totalSales, closeTo(150, 1e-9));
      expect(b.totalTax, closeTo(7.5, 1e-9));
      expect(bucket(b, 'cash'), closeTo(150, 1e-9));
    });
  });

  // ── orders refunded before events existed ──────────────────────────────

  group('old orders without refund events (fallback)', () {
    test('one refund, no events: counted exactly as before (by refundedAt)',
        () async {
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          gst: 50,
          refundAmount: 150,
          refundedAt: DateTime.now(),
          status: 'PARTIALLY_REFUNDED',
        ),
        pastOrder(id: 'B1', sessionId: 'B', total: 400, gst: 20),
      ]);

      final b = await eod('B');

      // The pre-SB-2b result: the whole refundAmount, attributed by refundedAt.
      expect(b.totalRefunds, closeTo(150, 1e-9));
      expect(b.totalSales, closeTo(400 - 150, 1e-9));
      expect(b.totalTax, closeTo(20 - 150 * 50 / 1000, 1e-9));
      expect(bucket(b, 'cash'), closeTo(400 - 150, 1e-9));
    });

    test('an old refund outside the session window is not counted', () async {
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 150,
          refundedAt: yesterday,
          status: 'PARTIALLY_REFUNDED',
        ),
      ]);
      expect((await eod('B')).totalRefunds, 0);
    });

    test(
        'LIMITATION: an old order refunded in A and again in B before events '
        'existed still counts the full running total in B', () async {
      // Only refundAmount (300 + 200) and the LAST refundedAt were stored.
      // Which part was refunded in which session was never recorded, so this
      // historical over-count cannot be reconstructed and is left as it was.
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 500,
          refundedAt: DateTime.now(),
          status: 'PARTIALLY_REFUNDED',
        ),
      ]);
      expect((await eod('B')).totalRefunds, closeTo(500, 1e-9));
    });

    test('an old order refunded again after SB-2b: only the new refund counts',
        () async {
      await openSession('B', DateTime.now().subtract(const Duration(hours: 1)));
      await seed([
        pastOrder(
          id: 'O1',
          sessionId: 'A',
          total: 1000,
          refundAmount: 300,
          refundedAt: yesterday,
          status: 'PARTIALLY_REFUNDED',
        ),
      ]);
      final o = orders().get('O1')!;

      await RefundService.processRefund(
        order: o,
        refundResult: PartialRefundResult(
          itemsToRefund: {o.items.first: 0},
          reason: 'test',
          totalRefundAmount: 100,
          itemsToRestock: {},
        ),
      );

      final saved = RefundService.refundEventsOf(orders().get('O1')!);
      expect(saved.map((e) => e.amount), [300, 100],
          reason: 'old total seeded as one event, then the new refund');
      expect(saved.first.sessionId, isNull);
      expect(saved.last.sessionId, 'B');
      expect((await eod('B')).totalRefunds, closeTo(100, 1e-9));
    });
  });

  // ── recording ──────────────────────────────────────────────────────────

  group('processRefund records each refund', () {
    test('one event per refund: validated amount, refundedAt, session',
        () async {
      await openSession('B', DateTime.now().subtract(const Duration(hours: 1)));
      await seed([
        pastOrder(id: 'O1', sessionId: 'B', total: 100),
      ]);

      var o = orders().get('O1')!;
      o = await RefundService.processRefund(
        order: o,
        refundResult: PartialRefundResult(
          itemsToRefund: {o.items.first: 0},
          reason: 'first',
          totalRefundAmount: 40,
          itemsToRestock: {},
        ),
      );
      // SB-2a clamps a sub-paisa overshoot to exactly what is left (60).
      o = await RefundService.processRefund(
        order: o,
        refundResult: PartialRefundResult(
          itemsToRefund: {o.items.first: 1},
          reason: 'second',
          totalRefundAmount: 60.005,
          itemsToRestock: {},
        ),
      );

      final saved = orders().get('O1')!;
      final ev = RefundService.refundEventsOf(saved);
      expect(ev.map((e) => e.amount), [40, 60]);
      expect(ev.every((e) => e.sessionId == 'B'), isTrue);
      expect(ev.last.at, saved.refundedAt, reason: 'the same instant');
      expect(ev.fold<double>(0, (s, e) => s + e.amount), saved.refundAmount);
    });

    test('a rejected over-refund records no event and changes nothing',
        () async {
      await openSession('B', DateTime.now());
      await seed([pastOrder(id: 'O1', sessionId: 'B', total: 100)]);
      final before = orders().get('O1')!.toMap();

      final o = orders().get('O1')!;
      await expectLater(
        RefundService.processRefund(
          order: o,
          refundResult: PartialRefundResult(
            itemsToRefund: {o.items.first: 1},
            reason: 'too much',
            totalRefundAmount: 150,
            itemsToRestock: {o.items.first: 1},
          ),
        ),
        throwsA(anything),
      );

      expect(orders().get('O1')!.toMap(), before);
      expect(orders().get('O1')!.refundEventsJson, isNull);
    });

    test(
        'M8: a refund after EOD, before Start Day, is refused — it can no '
        'longer slip past every EOD', () async {
      // Day closed: no current session.
      await seed([pastOrder(id: 'O1', sessionId: 'A', total: 100)]);
      final before = orders().get('O1')!.toMap();
      final o = orders().get('O1')!;

      await expectLater(
        RefundService.processRefund(
          order: o,
          refundResult: PartialRefundResult(
            itemsToRefund: {o.items.first: 1},
            reason: 'after close',
            totalRefundAmount: 100,
            itemsToRestock: {},
          ),
        ),
        throwsA(predicate((e) =>
            e.toString().contains(RefundService.refundNeedsOpenSessionMessage))),
      );

      expect(orders().get('O1')!.toMap(), before, reason: 'nothing written');
      expect(orders().get('O1')!.refundEventsJson, isNull);
    });
  });

  // ── Hive and backup compatibility ──────────────────────────────────────

  group('storage compatibility', () {
    test('a record written in the pre-SB-2b format still loads', () async {
      // Fixed, millisecond-precision times: Hive stores DateTime to the ms.
      final original = pastOrder(
        id: 'OLD',
        sessionId: 'A',
        total: 250,
        gst: 12.5,
        refundAmount: 50,
        refundedAt: DateTime(2026, 10, 28, 18, 30),
        orderAt: DateTime(2026, 10, 28, 13, 5),
        status: 'PARTIALLY_REFUNDED',
      );
      await orders().close();
      Hive.registerAdapter(PreRefundEventsPastOrderAdapter(), override: true);
      var box = await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
      await box.put('OLD', original);
      await box.close();

      Hive.registerAdapter(PastOrderModelAdapter(), override: true);
      box = await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
      final loaded = box.get('OLD')!;

      expect(loaded.refundEventsJson, isNull);
      expect(loaded.toMap(), original.toMap(), reason: 'every other field intact');
      expect(RefundService.refundEventsOf(loaded).single.amount, 50,
          reason: 'treated as an old order');
    });

    test('a new record keeps its events through Hive', () async {
      final o = pastOrder(
        id: 'NEW',
        sessionId: 'A',
        total: 100,
        refundAmount: 30,
        refundedAt: DateTime.now(),
        refundEventsJson: events([
          RefundEvent(amount: 30, at: DateTime(2026, 10, 29, 12), sessionId: 'A'),
        ]),
      );
      await orders().put('NEW', o);
      await orders().close();
      final box =
          await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
      expect(box.get('NEW')!.refundEventsJson, o.refundEventsJson);
    });

    test('backup serialisation (toMap → JSON → fromMap) keeps the events', () {
      final o = pastOrder(
        id: 'BK',
        sessionId: 'A',
        total: 100,
        refundAmount: 30,
        refundedAt: DateTime.now(),
        refundEventsJson: events([
          RefundEvent(amount: 30, at: DateTime(2026, 10, 29, 12), sessionId: 'A'),
        ]),
      );
      final restored = PastOrderModel.fromMap(
          jsonDecode(jsonEncode(o.toMap())) as Map<String, dynamic>);
      expect(restored.refundEventsJson, o.refundEventsJson);
      expect(RefundService.refundEventsOf(restored).single.sessionId, 'A');
    });
  });
}
