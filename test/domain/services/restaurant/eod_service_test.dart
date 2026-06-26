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

import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';

import '../../../helpers/test_helpers.dart';

/// EOD AGGREGATION TESTS — `EODService.generateEODReport`
///
/// This is the highest-value untested financial logic: every figure the owner
/// reviews at day-end (sales, discount, tax, refunds, cash reconciliation,
/// order/payment/category/tax breakdowns) is produced here.
///
/// Strategy: seed a *known* day of past orders + expenses + cash movements into
/// real Hive boxes, pass an explicit `sessionId` (deterministic session-filter
/// path), and assert every output against hand-computed expected values.
void main() {
  late Directory tempDir;
  const session = 'S1';

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('eod_service_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    // ExpenseRepository chooses its box from AppConfig — force restaurant mode.
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');

    // Boxes that generateEODReport (and its stores/repos) read.
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<Expense>(HiveBoxNames.restaurantExpense);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox); // untyped; stays empty

    // Register the stores the global `pastOrderStore` / `expenseStore` resolve.
    locator.registerLazySingleton<PastOrderStore>(
        () => PastOrderStore(PastOrderRepository()));
    locator.registerLazySingleton<ExpenseStore>(
        () => ExpenseStore(ExpenseRepository()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Seeding helpers ─────────────────────────────────────────────────────────

  PastOrderModel order({
    required String id,
    required String orderType,
    required String paymentmode,
    required double totalPrice,
    double? subTotal,
    double discount = 0,
    double gstRate = 0.05,
    double? gstAmount,
    double refundAmount = 0,
    String status = 'COMPLETED',
    required String category,
    String? paymentListJson,
  }) {
    final items = <CartItem>[
      makeCartItem(price: totalPrice, quantity: 1, categoryName: category),
    ];
    return PastOrderModel(
      id: id,
      customerName: 'Test',
      totalPrice: totalPrice,
      items: items,
      orderAt: DateTime.now(),
      orderType: orderType,
      paymentmode: paymentmode,
      subTotal: subTotal,
      Discount: discount,
      gstRate: gstRate,
      gstAmount: gstAmount,
      refundAmount: refundAmount,
      orderStatus: status,
      sessionId: session,
      paymentListJson: paymentListJson,
      kotNumbers: [1],
      kotBoundaries: [items.length],
    );
  }

  Future<void> seedOrders(List<PastOrderModel> orders) async {
    final box = Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    for (final o in orders) {
      await box.put(o.id, o);
    }
  }

  Future<void> seedExpense(String id, double amount, String paymentType) async {
    final box = Hive.box<Expense>(HiveBoxNames.restaurantExpense);
    await box.put(
      id,
      Expense(
        id: id,
        dateandTime: DateTime.now(),
        amount: amount,
        paymentType: paymentType,
        sessionId: session,
      ),
    );
  }

  Future<void> seedCashMovement(String id, String type, double amount) async {
    final box =
        Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await box.put(
      id,
      CashMovementModel(
        id: id,
        timestamp: DateTime.now(),
        type: type,
        amount: amount,
        reason: 'test',
        staffName: 'Tester',
        sessionId: session,
      ),
    );
  }

  PaymentSummary paymentFor(EndOfDayReport r, String type) =>
      r.paymentSummaries.firstWhere((p) => p.paymentType == type);
  OrderTypeSummary orderTypeFor(EndOfDayReport r, String type) =>
      r.orderSummaries.firstWhere((o) => o.orderType == type);
  CategorySales categoryFor(EndOfDayReport r, String name) =>
      r.categorySales.firstWhere((c) => c.categoryName == name);

  // ════════════════════════════════════════════════════════════════════════
  // A full known day — every figure hand-computed.
  //
  //   O1 Take Away / Cash  total 100  sub 95   disc 10  gst 5    COMPLETED
  //   O2 Dine In   / Card  total 200  sub 190  disc 0   gst 10   COMPLETED
  //   O3 Take Away / Cash  total 300  sub 285  disc 20  gst 15   refund 150  PARTIALLY_REFUNDED
  //   O4 Dine In   / UPI   total 500  sub 475  gst 25   refund 500  FULLY_REFUNDED  (excluded from sales)
  //   O5 Take Away / Cash  total 80                                VOID            (excluded entirely)
  //   Expenses: 50 cash + 30 card.   Cash movements: +200 in, -100 out.
  //   opening 1000, actualCash 1290.
  // ════════════════════════════════════════════════════════════════════════
  group('generateEODReport — full day', () {
    late EndOfDayReport report;

    setUp(() async {
      await seedOrders([
        order(id: 'O1', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 100, subTotal: 95, discount: 10, gstAmount: 5, category: 'Pizza'),
        order(id: 'O2', orderType: 'Dine In', paymentmode: 'card', totalPrice: 200, subTotal: 190, gstAmount: 10, category: 'Main Course'),
        order(id: 'O3', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 300, subTotal: 285, discount: 20, gstAmount: 15, refundAmount: 150, status: 'PARTIALLY_REFUNDED', category: 'Pizza'),
        order(id: 'O4', orderType: 'Dine In', paymentmode: 'upi', totalPrice: 500, subTotal: 475, gstAmount: 25, refundAmount: 500, status: 'FULLY_REFUNDED', category: 'Desserts'),
        order(id: 'O5', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 80, status: 'VOID', category: 'Beverages'),
      ]);
      await seedExpense('E1', 50, 'cash');
      await seedExpense('E2', 30, 'card');
      await seedCashMovement('M1', 'in', 200);
      await seedCashMovement('M2', 'out', 100);

      report = await EODService.generateEODReport(
        date: DateTime.now(),
        openingBalance: 1000,
        actualCash: 1290,
        sessionId: session,
      );
    });

    test('financial totals net out refunds and exclude void/fully-refunded', () {
      expect(report.totalSales, closeTo(450, 0.001)); // 100 + 200 + (300-150)
      expect(report.totalDiscount, closeTo(30, 0.001)); // 10 + 0 + 20
      expect(report.totalTax, closeTo(22.5, 0.001)); // 5 + 10 + 15*0.5
      expect(report.totalRefunds, closeTo(650, 0.001)); // 150 + 500 (refunded ≠ void)
      expect(report.totalOrderCount, 3); // active orders only
      expect(report.totalExpenses, closeTo(80, 0.001)); // 50 + 30
      expect(report.cashExpenses, closeTo(50, 0.001)); // cash only
    });

    test('cash reconciliation: opening + cashSales + in − out − cashExpenses', () {
      // 1000 + 250 + 200 − 100 − 50 = 1300
      expect(report.closingBalance, closeTo(1300, 0.001));
      expect(report.cashReconciliation.systemExpectedCash, closeTo(250, 0.001));
      expect(report.cashReconciliation.actualCash, closeTo(1290, 0.001));
      expect(report.cashReconciliation.difference, closeTo(-10, 0.001)); // 1290 − 1300
      expect(report.cashReconciliation.reconciliationStatus, 'Shortage');
    });

    test('order-type summary groups active orders', () {
      expect(report.orderSummaries.length, 2);
      final takeAway = orderTypeFor(report, 'Take Away');
      expect(takeAway.orderCount, 2);
      expect(takeAway.totalAmount, closeTo(250, 0.001)); // 100 + 150
      expect(takeAway.averageOrderValue, closeTo(125, 0.001));
      final dineIn = orderTypeFor(report, 'Dine In');
      expect(dineIn.orderCount, 1);
      expect(dineIn.totalAmount, closeTo(200, 0.001));
    });

    test('payment summary buckets net cash/card (UPI excluded with refund)', () {
      expect(report.paymentSummaries.length, 2);
      expect(paymentFor(report, 'Cash').totalAmount, closeTo(250, 0.001));
      expect(paymentFor(report, 'Cash').transactionCount, 2);
      expect(paymentFor(report, 'Card').totalAmount, closeTo(200, 0.001));
      // grandTotal 450 → percentages sum to 100
      final pctSum = report.paymentSummaries
          .fold<double>(0, (s, p) => s + p.percentage);
      expect(pctSum, closeTo(100, 0.001));
    });

    test('category sales apply proportional refund and sort by amount', () {
      expect(report.categorySales.length, 2);
      expect(report.categorySales.first.categoryName, 'Pizza'); // sorted desc
      expect(categoryFor(report, 'Pizza').totalAmount, closeTo(250, 0.001)); // 100 + 300*0.5
      expect(categoryFor(report, 'Main Course').totalAmount, closeTo(200, 0.001));
    });

    test('tax summary aggregates one GST bucket with refund-adjusted amounts', () {
      expect(report.taxSummaries.length, 1);
      final gst = report.taxSummaries.single;
      expect(gst.taxName, 'GST 5.0%');
      expect(gst.taxAmount, closeTo(22.5, 0.001)); // 5 + 10 + 7.5
      expect(gst.taxableAmount, closeTo(427.5, 0.001)); // 95 + 190 + 285*0.5
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Edge cases — paths the full-day scenario doesn't exercise.
  // ════════════════════════════════════════════════════════════════════════
  group('generateEODReport — edge cases', () {
    Future<EndOfDayReport> run() => EODService.generateEODReport(
          date: DateTime.now(),
          openingBalance: 0,
          actualCash: 0,
          sessionId: session,
        );

    test('split payment is decoded into per-method buckets', () async {
      await seedOrders([
        order(
          id: 'SP', orderType: 'Take Away', paymentmode: 'split',
          totalPrice: 100, category: 'Pizza',
          paymentListJson:
              '[{"method":"cash","amount":70},{"method":"card","amount":30}]',
        ),
      ]);

      final r = await run();
      expect(r.paymentSummaries.length, 2);
      expect(paymentFor(r, 'Cash').totalAmount, closeTo(70, 0.001));
      expect(paymentFor(r, 'Card').totalAmount, closeTo(30, 0.001));
      // Only the cash leg counts toward the drawer.
      expect(r.cashReconciliation.systemExpectedCash, closeTo(70, 0.001));
    });

    test('different GST rates produce separate tax buckets', () async {
      await seedOrders([
        order(id: 'T5', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 100, subTotal: 95, gstRate: 0.05, gstAmount: 5, category: 'Pizza'),
        order(id: 'T12', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 100, subTotal: 88, gstRate: 0.12, gstAmount: 12, category: 'Pizza'),
      ]);

      final r = await run();
      expect(r.taxSummaries.length, 2);
      expect(r.taxSummaries.firstWhere((t) => t.taxName == 'GST 5.0%').taxAmount, closeTo(5, 0.001));
      expect(r.taxSummaries.firstWhere((t) => t.taxName == 'GST 12.0%').taxAmount, closeTo(12, 0.001));
      expect(r.totalTax, closeTo(17, 0.001));
    });

    test('CANCELLED orders are excluded from every total', () async {
      await seedOrders([
        order(id: 'OK', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 100, discount: 10, gstAmount: 5, category: 'Pizza'),
        order(id: 'CXL', orderType: 'Dine In', paymentmode: 'cash', totalPrice: 200, discount: 20, gstAmount: 10, status: 'CANCELLED', category: 'Main Course'),
      ]);

      final r = await run();
      expect(r.totalSales, closeTo(100, 0.001));
      expect(r.totalDiscount, closeTo(10, 0.001));
      expect(r.totalOrderCount, 1);
      expect(r.totalRefunds, closeTo(0, 0.001));
    });

    test('payment method case variants collapse into one bucket', () async {
      await seedOrders([
        order(id: 'P1', orderType: 'Take Away', paymentmode: 'CASH', totalPrice: 100, category: 'Pizza'),
        order(id: 'P2', orderType: 'Take Away', paymentmode: 'cash', totalPrice: 50, category: 'Pizza'),
        order(id: 'P3', orderType: 'Take Away', paymentmode: 'Cash', totalPrice: 25, category: 'Pizza'),
      ]);

      final r = await run();
      expect(r.paymentSummaries.length, 1);
      expect(paymentFor(r, 'Cash').totalAmount, closeTo(175, 0.001));
      expect(paymentFor(r, 'Cash').transactionCount, 3);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Empty day — no orders/expenses/movements.
  // ════════════════════════════════════════════════════════════════════════
  test('generateEODReport — empty day yields zeros and balanced drawer', () async {
    final report = await EODService.generateEODReport(
      date: DateTime.now(),
      openingBalance: 1000,
      actualCash: 1000,
      sessionId: session,
    );

    expect(report.totalSales, 0);
    expect(report.totalDiscount, 0);
    expect(report.totalTax, 0);
    expect(report.totalRefunds, 0);
    expect(report.totalOrderCount, 0);
    expect(report.orderSummaries, isEmpty);
    expect(report.paymentSummaries, isEmpty);
    expect(report.categorySales, isEmpty);
    expect(report.taxSummaries, isEmpty);
    expect(report.closingBalance, closeTo(1000, 0.001)); // opening, no cash flow
    expect(report.cashReconciliation.difference, closeTo(0, 0.001));
    expect(report.cashReconciliation.reconciliationStatus, 'Balanced');
  });
}
