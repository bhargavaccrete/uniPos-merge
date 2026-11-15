import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/util/restaurant/refund_allocation.dart';

import '../../../helpers/test_helpers.dart';

/// Batch 2, restaurant End of Day: a voided paid order is held until its
/// refund (M7), refunds come off the method they were paid by, the drawer
/// figure matches, the status tolerates float noise (M3), discounts are not
/// round-off (M1), and the GST table comes from the order's lines (M2).
void main() {
  late Directory tempDir;
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  setUp(() async {
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('eod_money_records_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<Expense>(HiveBoxNames.restaurantExpense);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    locator
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<ExpenseStore>(() => ExpenseStore(ExpenseRepository()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var seq = 0;
  PastOrderModel past({
    String sessionId = 'B',
    double total = 200,
    String paymentmode = 'cash',
    String status = 'COMPLETED',
    Map<String, double>? paid,
    double? totalPaid,
    List<RefundEvent> refunds = const [],
    List<CartItem>? items,
    double? subTotal,
    double gst = 0,
    double? discount,
    double? gstRate,
  }) =>
      PastOrderModel(
        id: 'o${seq++}',
        customerName: '',
        totalPrice: total,
        subTotal: subTotal ?? total - gst,
        gstAmount: gst,
        gstRate: gstRate,
        Discount: discount,
        items: items ?? [makeCartItem(price: total, quantity: 1)],
        orderAt: now,
        orderType: 'Dine In',
        paymentmode: paymentmode,
        orderStatus: status,
        paymentListJson: paid == null
            ? null
            : jsonEncode([for (final e in paid.entries) {'method': e.key, 'amount': e.value}]),
        isSplitPayment: paid != null && paid.length > 1,
        totalPaid: totalPaid,
        refundAmount: refunds.fold<double>(0, (s, e) => s + e.amount),
        refundedAt: refunds.isEmpty ? null : refunds.last.at,
        refundEventsJson: refunds.isEmpty ? null : RefundEvent.encodeAll(refunds),
        sessionId: sessionId,
        isTaxInclusive: false,
        taxEnabled: true,
        kotNumbers: [1],
        kotBoundaries: [1],
      );

  RefundEvent refund(double amount,
          {Map<String, double>? by, String session = 'B', DateTime? at}) =>
      RefundEvent(
        amount: amount,
        at: at ?? now,
        sessionId: session,
        legs: by == null ? null : [for (final e in by.entries) (method: e.key, amount: e.value)],
      );

  Future<void> seed(List<PastOrderModel> orders) async {
    for (final o in orders) {
      await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).put(o.id, o);
    }
  }

  Future<EndOfDayReport> eod(String session, {double actualCash = 0}) async {
    await Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions).put(session,
        RestaurantSessionModel(
            sessionId: session,
            startTime: now.subtract(const Duration(hours: 2)),
            openingCash: 0));
    await Hive.box(HiveBoxNames.dayManagementBox).put('currentSessionId', session);
    return EODService.generateEODReport(
      date: now,
      openingBalance: 0,
      actualCash: actualCash,
      sessionId: session,
    );
  }

  double bucket(EndOfDayReport r, String type) => r.paymentSummaries
      .where((p) => p.paymentType.toLowerCase() == type)
      .fold(0.0, (s, p) => s + p.totalAmount);

  group('M7: a voided paid order is held until its refund', () {
    test('voided, not yet refunded: its cash is still expected', () async {
      await seed([past(total: 300), past(total: 200, status: 'VOIDED')]);
      final r = await eod('B', actualCash: 500);
      expect(bucket(r, 'cash'), closeTo(500, 1e-9));
      expect(r.cashReconciliation.reconciliationStatus, 'Balanced',
          reason: 'no false overage while the refund is pending');
      expect(r.totalSales, closeTo(300, 1e-9), reason: 'still not a sale');
    });

    test('voided and refunded in cash the same session: nothing held', () async {
      await seed([
        past(total: 300),
        past(total: 200, status: 'VOIDED', refunds: [refund(200, by: {'cash': 200})]),
      ]);
      final r = await eod('B', actualCash: 300);
      expect(bucket(r, 'cash'), closeTo(300, 1e-9));
      expect(r.cashReconciliation.reconciliationStatus, 'Balanced');
    });

    test('voided yesterday, refunded today: subtracted ONCE, today', () async {
      await seed([
        past(total: 300),
        past(
          sessionId: 'A',
          total: 200,
          status: 'VOIDED',
          refunds: [refund(200, by: {'cash': 200})],
        ),
      ]);
      final r = await eod('B', actualCash: 100);
      expect(bucket(r, 'cash'), closeTo(300 - 200, 1e-9));
      expect(r.cashReconciliation.reconciliationStatus, 'Balanced');
    });

    test('a split refund comes off the right methods', () async {
      await seed([
        past(
          total: 200,
          status: 'VOIDED',
          paid: {'cash': 100, 'upi': 100},
          refunds: [refund(50, by: {'cash': 30, 'upi': 20})],
        ),
      ]);
      final r = await eod('B', actualCash: 70);
      expect(bucket(r, 'cash'), closeTo(70, 1e-9));
      expect(bucket(r, 'upi'), closeTo(80, 1e-9));
    });

    test('a part-paid void holds only what it collected', () async {
      await seed([past(total: 500, totalPaid: 200, status: 'VOIDED')]);
      final r = await eod('B', actualCash: 200);
      expect(bucket(r, 'cash'), closeTo(200, 1e-9));
    });

    test('an unpaid void still counts nothing', () async {
      await seed([past(total: 500, paymentmode: 'N/A', status: 'VOID')]);
      final r = await eod('B');
      expect(bucket(r, 'cash'), 0);
    });
  });

  group('refunds by method in End of Day', () {
    test("an earlier order's cash refund of a UPI sale comes off cash", () async {
      await seed([
        past(total: 300),
        past(sessionId: 'A', total: 200, paymentmode: 'upi',
            status: 'PARTIALLY_REFUNDED',
            refunds: [refund(80, by: {'cash': 80})]),
      ]);
      final r = await eod('B', actualCash: 220);
      expect(bucket(r, 'cash'), closeTo(300 - 80, 1e-9));
      expect(bucket(r, 'upi'), 0);
    });

    test('a legacy refund (no method) keeps the proportional result', () async {
      await seed([
        past(sessionId: 'A', total: 200, paid: {'cash': 100, 'upi': 100},
            status: 'PARTIALLY_REFUNDED',
            refunds: [refund(50)]),
      ]);
      final r = await eod('B');
      expect(bucket(r, 'cash'), closeTo(-25, 1e-9));
      expect(bucket(r, 'upi'), closeTo(-25, 1e-9));
    });

    test('End of Day and the cash drawer agree on cash', () async {
      final orders = [
        past(total: 300, refunds: [refund(40, by: {'cash': 40})]),
        past(total: 150, status: 'VOIDED', paymentmode: 'upi'),
        past(sessionId: 'A', total: 200, paymentmode: 'upi',
            status: 'PARTIALLY_REFUNDED',
            refunds: [refund(60, by: {'cash': 60}), refund(10, by: {'cash': 10}, session: 'A', at: yesterday)]),
      ];
      await seed(orders);
      final r = await eod('B');
      final drawer = RefundAllocation.sessionCollections(
        orders: orders,
        inSession: (o) => o.sessionId == 'B',
        refundInSession: (e) => e.sessionId == 'B',
      );
      expect(bucket(r, 'cash'), closeTo(drawer['Cash'] ?? 0, 1e-9));
      expect(bucket(r, 'upi'), closeTo(drawer['UPI'] ?? 0, 1e-9));
    });
  });

  test('M3: a 0.0000001 difference reads Balanced', () async {
    await seed([past(total: 199.99)]);
    final r = await eod('B', actualCash: 199.99 + 0.0000001);
    expect(r.cashReconciliation.reconciliationStatus, 'Balanced');
    final over = await eod('B', actualCash: 199.99 + 0.01);
    expect(over.cashReconciliation.reconciliationStatus, 'Overage');
  });

  test('M1: a discount is not reported as round-off', () async {
    // ₹500 of food, ₹50 off, 5% GST on 450 → 472.50.
    await seed([past(total: 472.5, subTotal: 450, gst: 22.5, discount: 50)]);
    final r = await eod('B', actualCash: 472.5);
    expect(r.roundOff, 0);
  });

  test('M1: real rounding is still reported', () async {
    await seed([past(total: 473, subTotal: 450, gst: 22.5, discount: 50)]);
    final r = await eod('B', actualCash: 473);
    expect(r.roundOff, closeTo(0.5, 1e-9));
  });

  group('M2: the GST table comes from the order lines', () {
    test('5% and 18% lines give two rows that add up to the stored GST', () async {
      final items = [
        makeCartItem(id: 'a', price: 100, quantity: 1, taxRate: 0.05),
        makeCartItem(id: 'b', price: 200, quantity: 1, taxRate: 0.18),
      ];
      // 100 @5% = 5, 200 @18% = 36 → 41 GST, 341 total.
      await seed([past(total: 341, subTotal: 300, gst: 41, items: items, gstRate: 0)]);
      final r = await eod('B', actualCash: 341);
      final rows = {for (final t in r.taxSummaries) t.taxName: t};
      expect(rows.keys.toSet(), {'GST 5.0%', 'GST 18.0%'});
      expect(rows['GST 5.0%']!.taxAmount, closeTo(5, 1e-9));
      expect(rows['GST 18.0%']!.taxAmount, closeTo(36, 1e-9));
      expect(rows['GST 18.0%']!.taxableAmount, closeTo(200, 1e-9));
    });

    test('an older order that stored its rate keeps the old row', () async {
      await seed([past(total: 105, subTotal: 100, gst: 5, gstRate: 0.05)]);
      final r = await eod('B', actualCash: 105);
      expect(r.taxSummaries.single.taxName, 'GST 5.0%');
      expect(r.taxSummaries.single.taxAmount, closeTo(5, 1e-9));
    });

    test('no GST billed: no rows', () async {
      await seed([past(total: 100)]);
      final r = await eod('B', actualCash: 100);
      expect(r.taxSummaries, isEmpty);
    });
  });
}
