import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';

/// HIVE TESTS FOR END-OF-DAY (EOD) MODEL
///
/// The EOD model is the most complex in the app — it contains 5 nested
/// sub-models, each with their own Hive typeId:
///
///   EndOfDayReport (typeId 117)
///     ├── List<OrderTypeSummary> (typeId 118)
///     ├── List<CategorySales> (typeId 119)
///     ├── List<PaymentSummary> (typeId 120)
///     ├── CashReconciliation (typeId 121)
///     └── List<TaxSummary> (typeId 124)
///
/// If any adapter is broken, the daily closing report is lost —
/// management can't review past days' performance.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_eod_');
    Hive.init(tempDir.path);

    // Register all adapters — EOD needs 6 adapters to work
    // (EndOfDayReport + 5 sub-models)
    await HiveInit.registerRestaurantAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ════════════════════════════════════════════════════════════════════════
  // SUB-MODEL TESTS — Test each nested model independently first.
  // If a sub-model fails, we know exactly which one broke.
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: OrderTypeSummary (sub-model)', () {
    test('round-trip with all fields', () async {
      final box = await Hive.openBox<OrderTypeSummary>('test_ots');

      final original = OrderTypeSummary(
        orderType: 'Dine In',
        orderCount: 15,
        totalAmount: 12500,
        averageOrderValue: 833.33,
      );

      await box.put('ots-1', original);
      final loaded = box.get('ots-1');

      expect(loaded, isNotNull);
      expect(loaded!.orderType, equals('Dine In'));
      expect(loaded.orderCount, equals(15));
      expect(loaded.totalAmount, equals(12500));
      expect(loaded.averageOrderValue, closeTo(833.33, 0.01));

      await box.close();
    });
  });

  group('Hive: CategorySales (sub-model)', () {
    test('round-trip with percentage', () async {
      final box = await Hive.openBox<CategorySales>('test_cs');

      final original = CategorySales(
        categoryName: 'Main Course',
        totalAmount: 45200,
        itemsSold: 156,
        percentage: 63.5,
      );

      await box.put('cs-1', original);
      final loaded = box.get('cs-1');

      expect(loaded, isNotNull);
      expect(loaded!.categoryName, equals('Main Course'));
      expect(loaded.totalAmount, equals(45200));
      expect(loaded.itemsSold, equals(156));
      expect(loaded.percentage, equals(63.5));

      await box.close();
    });
  });

  group('Hive: PaymentSummary (sub-model)', () {
    test('round-trip with transaction count', () async {
      final box = await Hive.openBox<PaymentSummary>('test_ps');

      final original = PaymentSummary(
        paymentType: 'Cash',
        totalAmount: 14400,
        transactionCount: 25,
        percentage: 60,
      );

      await box.put('ps-1', original);
      final loaded = box.get('ps-1');

      expect(loaded, isNotNull);
      expect(loaded!.paymentType, equals('Cash'));
      expect(loaded.totalAmount, equals(14400));
      expect(loaded.transactionCount, equals(25));
      expect(loaded.percentage, equals(60));

      await box.close();
    });
  });

  group('Hive: CashReconciliation (sub-model)', () {
    test('balanced reconciliation', () async {
      final box = await Hive.openBox<CashReconciliation>('test_cr');

      final original = CashReconciliation(
        systemExpectedCash: 10900,
        actualCash: 10900,
        difference: 0,
        reconciliationStatus: 'Balanced',
      );

      await box.put('cr-1', original);
      final loaded = box.get('cr-1');

      expect(loaded, isNotNull);
      expect(loaded!.systemExpectedCash, equals(10900));
      expect(loaded.actualCash, equals(10900));
      expect(loaded.difference, equals(0));
      expect(loaded.reconciliationStatus, equals('Balanced'));
      expect(loaded.remarks, isNull);

      await box.close();
    });

    test('shortage with remarks', () async {
      final box = await Hive.openBox<CashReconciliation>('test_cr_shortage');

      final original = CashReconciliation(
        systemExpectedCash: 10900,
        actualCash: 10400,
        difference: -500,
        reconciliationStatus: 'Shortage',
        remarks: 'Investigated - petty cash not recorded',
      );

      await box.put('cr-2', original);
      final loaded = box.get('cr-2');

      expect(loaded!.difference, equals(-500));
      expect(loaded.reconciliationStatus, equals('Shortage'));
      expect(loaded.remarks, equals('Investigated - petty cash not recorded'));

      await box.close();
    });
  });

  group('Hive: TaxSummary (sub-model)', () {
    test('round-trip with tax breakdown', () async {
      final box = await Hive.openBox<TaxSummary>('test_ts');

      final original = TaxSummary(
        taxName: 'GST 5%',
        taxRate: 5.0,
        taxAmount: 850,
        taxableAmount: 17000,
      );

      await box.put('ts-1', original);
      final loaded = box.get('ts-1');

      expect(loaded, isNotNull);
      expect(loaded!.taxName, equals('GST 5%'));
      expect(loaded.taxRate, equals(5.0));
      expect(loaded.taxAmount, equals(850));
      expect(loaded.taxableAmount, equals(17000));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // FULL EOD REPORT — The complete model with all 5 nested sub-models.
  // This is the most critical test — if this passes, all 6 adapters
  // and their nesting relationships work correctly.
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: EndOfDayReport — full nested model', () {
    test('save and read complete EOD report with all sub-models', () async {
      final box = await Hive.openBox<EndOfDayReport>('test_eod');

      // Build a realistic EOD report with ALL sub-models populated
      final report = EndOfDayReport(
        reportId: 'eod-2026-03-24',
        date: DateTime(2026, 3, 24),
        openingBalance: 5000,
        closingBalance: 10900,
        totalSales: 24000,
        totalOrderCount: 42,
        totalDiscount: 1200,
        totalTax: 1170,
        totalRefunds: 450,
        totalExpenses: 500,
        cashExpenses: 300,
        mode: 'restaurant',

        // Nested: Order type breakdown (3 types)
        orderSummaries: [
          OrderTypeSummary(
            orderType: 'Dine In',
            orderCount: 15,
            totalAmount: 12500,
            averageOrderValue: 833.33,
          ),
          OrderTypeSummary(
            orderType: 'Take Away',
            orderCount: 22,
            totalAmount: 8300,
            averageOrderValue: 377.27,
          ),
          OrderTypeSummary(
            orderType: 'Delivery',
            orderCount: 5,
            totalAmount: 3200,
            averageOrderValue: 640,
          ),
        ],

        // Nested: Category sales breakdown
        categorySales: [
          CategorySales(
              categoryName: 'Main Course',
              totalAmount: 15120,
              itemsSold: 89,
              percentage: 63),
          CategorySales(
              categoryName: 'Beverages',
              totalAmount: 5280,
              itemsSold: 45,
              percentage: 22),
          CategorySales(
              categoryName: 'Starters',
              totalAmount: 3600,
              itemsSold: 32,
              percentage: 15),
        ],

        // Nested: Payment method breakdown
        paymentSummaries: [
          PaymentSummary(
              paymentType: 'Cash',
              totalAmount: 14400,
              transactionCount: 25,
              percentage: 60),
          PaymentSummary(
              paymentType: 'Card',
              totalAmount: 6000,
              transactionCount: 10,
              percentage: 25),
          PaymentSummary(
              paymentType: 'UPI',
              totalAmount: 3600,
              transactionCount: 7,
              percentage: 15),
        ],

        // Nested: Cash reconciliation
        cashReconciliation: CashReconciliation(
          systemExpectedCash: 10900,
          actualCash: 10900,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),

        // Nested: Tax breakdown
        taxSummaries: [
          TaxSummary(
              taxName: 'GST 5%',
              taxRate: 5.0,
              taxAmount: 850,
              taxableAmount: 17000),
          TaxSummary(
              taxName: 'GST 18%',
              taxRate: 18.0,
              taxAmount: 320,
              taxableAmount: 1778),
        ],
      );

      // Save to Hive
      await box.put(report.reportId, report);

      // Read back
      final loaded = box.get('eod-2026-03-24');

      // ── Verify top-level fields ──
      expect(loaded, isNotNull);
      expect(loaded!.reportId, equals('eod-2026-03-24'));
      expect(loaded.date, equals(DateTime(2026, 3, 24)));
      expect(loaded.openingBalance, equals(5000));
      expect(loaded.closingBalance, equals(10900));
      expect(loaded.totalSales, equals(24000));
      expect(loaded.totalOrderCount, equals(42));
      expect(loaded.totalDiscount, equals(1200));
      expect(loaded.totalTax, equals(1170));
      expect(loaded.totalRefunds, equals(450));
      expect(loaded.totalExpenses, equals(500));
      expect(loaded.cashExpenses, equals(300));
      expect(loaded.mode, equals('restaurant'));

      // ── Verify nested OrderTypeSummary list ──
      expect(loaded.orderSummaries.length, equals(3));
      expect(loaded.orderSummaries[0].orderType, equals('Dine In'));
      expect(loaded.orderSummaries[0].orderCount, equals(15));
      expect(loaded.orderSummaries[0].totalAmount, equals(12500));
      expect(loaded.orderSummaries[1].orderType, equals('Take Away'));
      expect(loaded.orderSummaries[2].orderType, equals('Delivery'));

      // Verify order counts sum to total
      final totalOrders = loaded.orderSummaries.fold<int>(
          0, (sum, o) => sum + o.orderCount);
      expect(totalOrders, equals(loaded.totalOrderCount));

      // ── Verify nested CategorySales list ──
      expect(loaded.categorySales.length, equals(3));
      expect(loaded.categorySales[0].categoryName, equals('Main Course'));
      expect(loaded.categorySales[0].itemsSold, equals(89));
      expect(loaded.categorySales[0].percentage, equals(63));

      // ── Verify nested PaymentSummary list ──
      expect(loaded.paymentSummaries.length, equals(3));
      expect(loaded.paymentSummaries[0].paymentType, equals('Cash'));
      expect(loaded.paymentSummaries[0].totalAmount, equals(14400));
      expect(loaded.paymentSummaries[0].percentage, equals(60));

      // Verify payment amounts sum to total sales
      final totalPayments = loaded.paymentSummaries.fold<double>(
          0, (sum, p) => sum + p.totalAmount);
      expect(totalPayments, equals(loaded.totalSales));

      // ── Verify nested CashReconciliation ──
      expect(loaded.cashReconciliation.systemExpectedCash, equals(10900));
      expect(loaded.cashReconciliation.actualCash, equals(10900));
      expect(loaded.cashReconciliation.difference, equals(0));
      expect(loaded.cashReconciliation.reconciliationStatus, equals('Balanced'));

      // ── Verify nested TaxSummary list ──
      expect(loaded.taxSummaries.length, equals(2));
      expect(loaded.taxSummaries[0].taxName, equals('GST 5%'));
      expect(loaded.taxSummaries[0].taxAmount, equals(850));
      expect(loaded.taxSummaries[1].taxName, equals('GST 18%'));
      expect(loaded.taxSummaries[1].taxRate, equals(18.0));

      await box.close();
    });

    test('save report with empty lists (day with no orders)', () async {
      final box = await Hive.openBox<EndOfDayReport>('test_eod_empty');

      // Edge case: slow day with zero orders
      final report = EndOfDayReport(
        reportId: 'eod-empty',
        date: DateTime(2026, 3, 24),
        openingBalance: 5000,
        closingBalance: 5000,
        totalSales: 0,
        totalOrderCount: 0,
        totalDiscount: 0,
        totalTax: 0,
        totalRefunds: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        orderSummaries: [],       // empty
        categorySales: [],        // empty
        paymentSummaries: [],     // empty
        taxSummaries: [],         // empty
        cashReconciliation: CashReconciliation(
          systemExpectedCash: 5000,
          actualCash: 5000,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),
      );

      await box.put(report.reportId, report);
      final loaded = box.get('eod-empty');

      expect(loaded, isNotNull);
      expect(loaded!.totalSales, equals(0));
      expect(loaded.totalOrderCount, equals(0));
      expect(loaded.orderSummaries, isEmpty);
      expect(loaded.categorySales, isEmpty);
      expect(loaded.paymentSummaries, isEmpty);
      expect(loaded.taxSummaries, isEmpty);
      // Opening = closing when no orders
      expect(loaded.openingBalance, equals(loaded.closingBalance));

      await box.close();
    });

    test('multiple EOD reports — query by date', () async {
      final box = await Hive.openBox<EndOfDayReport>('test_eod_multi');

      // 3 days of reports
      for (int day = 22; day <= 24; day++) {
        final report = EndOfDayReport(
          reportId: 'eod-2026-03-$day',
          date: DateTime(2026, 3, day),
          openingBalance: 5000,
          closingBalance: 10000 + day * 100,
          totalSales: 20000 + day * 500,
          totalOrderCount: 30 + day,
          totalDiscount: 0,
          totalTax: 0,
          totalRefunds: 0,
          totalExpenses: 0,
          cashExpenses: 0,
          orderSummaries: [],
          categorySales: [],
          paymentSummaries: [],
          taxSummaries: [],
          cashReconciliation: CashReconciliation(
            systemExpectedCash: 10000,
            actualCash: 10000,
            difference: 0,
            reconciliationStatus: 'Balanced',
          ),
        );
        await box.put(report.reportId, report);
      }

      expect(box.length, equals(3));

      // Query: find reports for March 2026
      final marchReports = box.values.where((r) =>
          r.date.month == 3 && r.date.year == 2026).toList();
      expect(marchReports.length, equals(3));

      // Query: find report with highest sales
      final best = box.values.reduce((a, b) =>
          a.totalSales > b.totalSales ? a : b);
      expect(best.date.day, equals(24)); // day 24 has highest sales

      await box.close();
    });

    test('toMap and fromMap round-trip (export/import)', () async {
      final original = EndOfDayReport(
        reportId: 'eod-map-test',
        date: DateTime(2026, 3, 24),
        openingBalance: 5000,
        closingBalance: 10900,
        totalSales: 24000,
        totalOrderCount: 42,
        totalDiscount: 1200,
        totalTax: 1170,
        totalRefunds: 450,
        totalExpenses: 500,
        cashExpenses: 300,
        mode: 'restaurant',
        orderSummaries: [
          OrderTypeSummary(
              orderType: 'Dine In',
              orderCount: 15,
              totalAmount: 12500,
              averageOrderValue: 833.33),
        ],
        categorySales: [
          CategorySales(
              categoryName: 'Main Course',
              totalAmount: 15120,
              itemsSold: 89,
              percentage: 63),
        ],
        paymentSummaries: [
          PaymentSummary(
              paymentType: 'Cash',
              totalAmount: 14400,
              transactionCount: 25,
              percentage: 60),
        ],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: 10900,
          actualCash: 10900,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),
        taxSummaries: [
          TaxSummary(
              taxName: 'GST 5%',
              taxRate: 5,
              taxAmount: 850,
              taxableAmount: 17000),
        ],
      );

      // Convert to Map (simulates backup export)
      final map = original.toMap();

      // Reconstruct from Map (simulates backup import)
      final restored = EndOfDayReport.fromMap(map);

      // Verify all top-level fields
      expect(restored.reportId, equals(original.reportId));
      expect(restored.totalSales, equals(original.totalSales));
      expect(restored.totalOrderCount, equals(original.totalOrderCount));
      expect(restored.mode, equals('restaurant'));

      // Verify nested models survived map round-trip
      expect(restored.orderSummaries.length, equals(1));
      expect(restored.orderSummaries[0].orderType, equals('Dine In'));
      expect(restored.categorySales[0].categoryName, equals('Main Course'));
      expect(restored.paymentSummaries[0].paymentType, equals('Cash'));
      expect(restored.cashReconciliation.reconciliationStatus, equals('Balanced'));
      expect(restored.taxSummaries[0].taxName, equals('GST 5%'));
    });
  });
}
