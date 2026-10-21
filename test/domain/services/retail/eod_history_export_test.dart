import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/printer_repository.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';
import 'package:billberrylite/domain/store/restaurant/printer_store.dart';
import 'package:billberrylite/domain/services/retail/eod_history_export.dart';
import 'package:billberrylite/domain/services/retail/eod_settlement_print.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';

/// EOD HISTORY — the P2/P3 batch: settlement reprint, exports, and the period
/// filter's date arithmetic.
///
/// The builders are pure, so most of this needs no Hive; the country-aware tax
/// rule reads `BusinessDetails`, which is why a box is opened at all.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 18, 30);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('eod_export_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    try {
      Hive.registerAdapter(BusinessDetailsAdapter());
    } catch (_) {
      // Already registered by another suite in the same isolate.
    }

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);
    await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);

    locator.registerLazySingleton<BusinessDetailsRepository>(
        () => BusinessDetailsRepository());
    // A real store with nothing paired — the shop that has never set up a
    // printer, which is the case the reprint has to report rather than swallow.
    locator.registerLazySingleton<PrinterStore>(
        () => PrinterStore(PrinterRepository(), ThermalPrinterService()));
    await businessDetailsRepository
        .save(BusinessDetails(storeName: 'Test Store', country: 'India'));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> setCountry(String? country) => businessDetailsRepository
      .save(BusinessDetails(storeName: 'Test Store', country: country));

  EndOfDayReport record({
    String id = 'R-1',
    DateTime? date,
    String? sessionId,
    double totalSales = 1000,
    double totalTax = 0,
    double totalDiscount = 0,
    double totalRefunds = 0,
    double openingBalance = 0,
    double totalExpenses = 0,
    double cashExpenses = 0,
    double cashCollections = 0,
    double cardCollections = 0,
    double upiCollections = 0,
    double totalCost = 0,
    double grossProfit = 0,
    int customersWithDue = 0,
    double totalOutstanding = 0,
    double difference = 0,
    String status = 'Balanced',
    int orderCount = 1,
    List<TaxSummary> taxSummaries = const [],
    List<PaymentSummary> paymentSummaries = const [],
  }) {
    return EndOfDayReport(
      reportId: id,
      date: date ?? day,
      openingBalance: openingBalance,
      orderSummaries: const [],
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      categorySales: const [],
      paymentSummaries: paymentSummaries,
      cashReconciliation: CashReconciliation(
        systemExpectedCash: totalSales,
        actualCash: totalSales + difference,
        difference: difference,
        reconciliationStatus: status,
      ),
      totalSales: totalSales,
      closingBalance: totalSales,
      taxSummaries: taxSummaries,
      totalOrderCount: orderCount,
      totalRefunds: totalRefunds,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      mode: 'retail',
      sessionId: sessionId,
      cashCollections: cashCollections,
      cardCollections: cardCollections,
      upiCollections: upiCollections,
      totalCost: totalCost,
      grossProfit: grossProfit,
      customersWithDue: customersWithDue,
      totalOutstanding: totalOutstanding,
    );
  }

  /// Finds one Section/Item row in a detail export.
  Object? cell(EodExport export, String section, String item) {
    for (final row in export.rows) {
      if (row[0] == section && row[1] == item) return row[2];
    }
    return null;
  }

  // ── EOD-M2 — the list export ─────────────────────────────────────────────

  group('list export', () {
    test('one row per close, in the order given', () {
      final export = EodHistoryExport.list(
        reports: [record(id: 'R-1'), record(id: 'R-2'), record(id: 'R-3')],
        period: 'All time',
      );

      expect(export.rows, hasLength(3));
      expect(export.headers, EodHistoryExport.listHeaders);
    });

    test('date and time are SEPARATE columns', () {
      final export = EodHistoryExport.list(
        reports: [record(date: DateTime(2026, 4, 15, 21, 40))],
        period: 'All time',
      );

      final row = export.rows.single;
      // Two closes on one day is the case EOD-3 exists for; a spreadsheet
      // groups them far better as two fields than as one string.
      expect(row[0], isNot(contains(':')));
      expect(row[1], contains(':'));
    });

    test('a session is shortened, and blank when absent', () {
      final withSession = EodHistoryExport.list(
        reports: [record(sessionId: 'session-abcdef-123')],
        period: 'All time',
      );
      final without =
          EodHistoryExport.list(reports: [record()], period: 'All time');

      expect(withSession.rows.single[2], isNotEmpty);
      expect(withSession.rows.single[2], isNot('session-abcdef-123'));
      expect(without.rows.single[2], '');
    });

    test('the summary counts each reconciliation status', () {
      final export = EodHistoryExport.list(
        reports: [
          record(id: 'R-1', status: 'Balanced'),
          record(id: 'R-2', status: 'Shortage', difference: -50),
          record(id: 'R-3', status: 'Shortage', difference: -10),
          record(id: 'R-4', status: 'Overage', difference: 20),
        ],
        period: 'This Month',
      );

      expect(export.summary['Report Period'], 'This Month');
      expect(export.summary['Closes'], 4);
      expect(export.summary['Balanced'], 1);
      expect(export.summary['Shortage'], 2);
      expect(export.summary['Overage'], 1);
    });

    test('the summary total is the sum of exactly the rows exported', () {
      final export = EodHistoryExport.list(
        reports: [
          record(id: 'R-1', totalSales: 400),
          record(id: 'R-2', totalSales: 600),
        ],
        period: 'All time',
      );

      expect(export.summary['Total Sales'], contains('1000'));
    });

    test('an empty period still produces headers and a zeroed summary', () {
      final export =
          EodHistoryExport.list(reports: const [], period: 'Today');

      expect(export.rows, isEmpty);
      expect(export.headers, EodHistoryExport.listHeaders);
      expect(export.summary['Closes'], 0);
      expect(export.summary['Balanced'], 0);
    });

    test('every row has one cell per header', () {
      final export = EodHistoryExport.list(
        reports: [record(), record(id: 'R-2', sessionId: 's-1')],
        period: 'All time',
      );

      for (final row in export.rows) {
        expect(row, hasLength(export.headers.length));
      }
    });
  });

  // ── EOD-M2 — the detail export ───────────────────────────────────────────

  group('detail export', () {
    test('carries the sections the screen renders', () {
      final export = EodHistoryExport.detail(record(
        totalSales: 1000,
        openingBalance: 200,
        orderCount: 7,
      ));

      expect(cell(export, 'Cash Summary', 'Opening Balance'), contains('200'));
      expect(cell(export, 'Sales', 'Total Sales'), contains('1000'));
      expect(cell(export, 'Sales', 'Transactions'), 7);
      expect(cell(export, 'Reconciliation', 'Status'), 'Balanced');
      expect(export.headers, EodHistoryExport.detailHeaders);
    });

    test('sections with nothing in them are omitted, as on screen', () {
      final export = EodHistoryExport.detail(record());

      // The screen guards each of these; a file full of zero rows would be
      // worse than a shorter file.
      expect(cell(export, 'Expenses', 'Total Expenses'), isNull);
      expect(cell(export, 'Credit Collections', 'Total'), isNull);
      expect(cell(export, 'Outstanding', 'Total Outstanding'), isNull);
      expect(cell(export, 'Sales', 'Total Discount'), isNull);
    });

    test('sections with content are included', () {
      final export = EodHistoryExport.detail(record(
        totalDiscount: 50,
        totalRefunds: 30,
        totalExpenses: 300,
        cashExpenses: 200,
        cashCollections: 100,
        cardCollections: 50,
        upiCollections: 25,
        customersWithDue: 3,
        totalOutstanding: 900,
        totalCost: 400,
        grossProfit: 600,
      ));

      expect(cell(export, 'Sales', 'Total Discount'), contains('50'));
      expect(cell(export, 'Sales', 'Refunds'), contains('30'));
      expect(cell(export, 'Expenses', 'Non-Cash Expenses'), contains('100'));
      expect(cell(export, 'Credit Collections', 'Total'), contains('175'));
      expect(cell(export, 'Outstanding', 'Customers with Due'), 3);
      expect(cell(export, 'Profit', 'Gross Profit'), contains('600'));
    });

    test('payment summaries become one row each', () {
      final export = EodHistoryExport.detail(record(paymentSummaries: [
        PaymentSummary(
            paymentType: 'Cash', totalAmount: 700, transactionCount: 4, percentage: 0),
        PaymentSummary(
            paymentType: 'UPI', totalAmount: 300, transactionCount: 2, percentage: 0),
      ]));

      expect(cell(export, 'Payments', 'Cash'), contains('700'));
      expect(cell(export, 'Payments', 'UPI'), contains('300'));
    });

    test('a session appears only when the record has one', () {
      expect(cell(EodHistoryExport.detail(record()), 'Close', 'Session'),
          isNull);
      expect(
          cell(EodHistoryExport.detail(record(sessionId: 'sess-1')), 'Close',
              'Session'),
          isNotNull);
    });

    test('every row has one cell per header', () {
      final export = EodHistoryExport.detail(record(totalExpenses: 10));
      for (final row in export.rows) {
        expect(row, hasLength(export.headers.length));
      }
    });
  });

  // ── EOD-1 carried into the export ────────────────────────────────────────

  group('country-aware tax in the export', () {
    /// A close saved BEFORE the country fix: CGST/SGST on disk whatever the
    /// country.
    final legacy = <TaxSummary>[
      TaxSummary(taxName: 'CGST', taxRate: 0, taxAmount: 90, taxableAmount: 500),
      TaxSummary(taxName: 'SGST', taxRate: 0, taxAmount: 90, taxableAmount: 500),
    ];

    test('India exports the stored breakdown', () async {
      await setCountry('India');
      final export = EodHistoryExport.detail(
          record(totalTax: 180, taxSummaries: legacy));

      expect(cell(export, 'Tax', 'CGST'), contains('90'));
      expect(cell(export, 'Tax', 'SGST'), contains('90'));
      expect(cell(export, 'Tax', 'Total Tax'), contains('180'));
    });

    test('the UK exports ONE VAT row and never the stored halves', () async {
      await setCountry('United Kingdom');
      final export = EodHistoryExport.detail(
          record(totalTax: 180, taxSummaries: legacy));

      expect(cell(export, 'Tax', 'CGST'), isNull);
      expect(cell(export, 'Tax', 'SGST'), isNull);
      // The AUTHORITATIVE total, not the halves added back up.
      expect(cell(export, 'Tax', 'VAT'), contains('180'));
    });

    test('an untaxed close exports no Tax section at all', () async {
      await setCountry('United Kingdom');
      final export = EodHistoryExport.detail(record());

      expect(cell(export, 'Tax', 'Total Tax'), isNull);
      expect(EodHistoryExport.taxRowsFor(record()), isEmpty);
    });

    test('the screen and the file share one rule', () async {
      await setCountry('United States');
      final rows =
          EodHistoryExport.taxRowsFor(record(totalTax: 100, taxSummaries: legacy));

      expect(rows.single.label, 'Sales Tax');
      expect(rows.single.amount, 100);
    });
  });

  // ── EOD-M1 — what the reprint sends ──────────────────────────────────────

  group('settlement reprint mapping', () {
    test('payment methods and order types come from the record', () {
      final figures = EodSettlementPrint.figuresFor(record(paymentSummaries: [
        PaymentSummary(
            paymentType: 'Cash', totalAmount: 700, transactionCount: 3, percentage: 0),
        PaymentSummary(
            paymentType: 'Credit', totalAmount: 300, transactionCount: 1, percentage: 0),
      ]));

      expect(figures.paymentMethods.map((p) => p.name), ['Cash', 'Credit']);
      // Retail stores no order types, so the ticket's block is simply empty.
      expect(figures.orderTypes, isEmpty);
    });

    test('total credit is the Credit bucket, matched case-insensitively', () {
      final figures = EodSettlementPrint.figuresFor(record(paymentSummaries: [
        PaymentSummary(
            paymentType: 'cash', totalAmount: 700, transactionCount: 3, percentage: 0),
        PaymentSummary(
            paymentType: ' CREDIT ', totalAmount: 300, transactionCount: 1, percentage: 0),
      ]));

      expect(figures.totalCredit, 300);
    });

    test('no credit sales means no credit line', () {
      final figures = EodSettlementPrint.figuresFor(record(paymentSummaries: [
        PaymentSummary(
            paymentType: 'Cash', totalAmount: 1000, transactionCount: 5, percentage: 0),
      ]));

      expect(figures.totalCredit, 0);
    });

    test('net sale is the stored total less its tax; gross is the total', () {
      final figures =
          EodSettlementPrint.figuresFor(record(totalSales: 1180, totalTax: 180));

      expect(figures.netSale, closeTo(1000, 0.001));
      expect(figures.grossSale, closeTo(1180, 0.001));
    });

    test('an untaxed close has net equal to gross', () {
      final figures = EodSettlementPrint.figuresFor(record(totalSales: 500));
      expect(figures.netSale, figures.grossSale);
    });

    test('reprinting with no printer paired reports WHY, rather than failing '
        'silently', () async {
      // Nothing paired: neither a receipt printer nor a KOT one to fall back
      // to. The caller gets a reason it can show the user, instead of a
      // button that appears to do nothing.
      expect(await EodSettlementPrint.reprint(record()),
          EodReprintOutcome.noPrinter);
    });
  });

  // ── EOD-M3 — the period filter's arithmetic ──────────────────────────────

  group('period filter bounds', () {
    /// The predicate `_visibleReports` applies.
    bool visible(DateTime date, ReportPeriod period, DateTime now) {
      final start = reportPeriodStartBound(period, now);
      final end = reportPeriodEndBound(period, now);
      return !date.isBefore(start) && date.isBefore(end);
    }

    final now = DateTime(2026, 4, 15, 12);

    test('Today takes the calendar day, start inclusive and end exclusive', () {
      expect(visible(DateTime(2026, 4, 15, 0, 0), ReportPeriod.today, now),
          isTrue);
      expect(visible(DateTime(2026, 4, 15, 23, 59), ReportPeriod.today, now),
          isTrue);
      expect(visible(DateTime(2026, 4, 16), ReportPeriod.today, now), isFalse);
      expect(
          visible(DateTime(2026, 4, 14, 23, 59), ReportPeriod.today, now),
          isFalse);
    });

    test('This Month excludes the first instant of the next month', () {
      expect(visible(DateTime(2026, 4, 1), ReportPeriod.thisMonth, now), isTrue);
      expect(
          visible(DateTime(2026, 4, 30, 23, 59), ReportPeriod.thisMonth, now),
          isTrue);
      expect(visible(DateTime(2026, 5, 1), ReportPeriod.thisMonth, now),
          isFalse);
      expect(visible(DateTime(2026, 3, 31, 23, 59), ReportPeriod.thisMonth, now),
          isFalse);
    });

    test('This Year spans the calendar year', () {
      expect(visible(DateTime(2026, 1, 1), ReportPeriod.thisYear, now), isTrue);
      expect(visible(DateTime(2026, 12, 31, 23), ReportPeriod.thisYear, now),
          isTrue);
      expect(visible(DateTime(2027, 1, 1), ReportPeriod.thisYear, now), isFalse);
      expect(visible(DateTime(2025, 12, 31), ReportPeriod.thisYear, now),
          isFalse);
    });

    test('This Week runs Monday to Monday', () {
      // 15 Apr 2026 is a Wednesday; its week starts Monday the 13th.
      expect(visible(DateTime(2026, 4, 13), ReportPeriod.thisWeek, now), isTrue);
      expect(visible(DateTime(2026, 4, 19, 23), ReportPeriod.thisWeek, now),
          isTrue);
      expect(visible(DateTime(2026, 4, 20), ReportPeriod.thisWeek, now),
          isFalse);
      expect(visible(DateTime(2026, 4, 12, 23), ReportPeriod.thisWeek, now),
          isFalse);
    });

    test('two closes on one day both survive a Today filter', () {
      // The filter must not collapse same-day closes — that is what EOD-3 made
      // visible in the first place.
      expect(visible(DateTime(2026, 4, 15, 11, 5), ReportPeriod.today, now),
          isTrue);
      expect(visible(DateTime(2026, 4, 15, 21, 40), ReportPeriod.today, now),
          isTrue);
    });
  });
}
