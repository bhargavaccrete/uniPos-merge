import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/eod_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/restaurant/eod_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// END OF DAY HISTORY — the viewer of stored close records.
///
/// Unlike every other retail report this one recomputes nothing: each card is a
/// snapshot frozen at close time. That inverts where defects live — the
/// arithmetic is out of reach, so what can go wrong is SELECTION (which records
/// appear), PRESENTATION (what a card says), and fields that were
/// restaurant-shaped and mean nothing for retail.
///
/// Two of the three fixes here are in the WRITE path, because a stored tax name
/// and a stored reconciliation status cannot be re-rendered later.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 18, 30);

  late EodRepository eodRepo;

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('eod_history_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    for (final register in <void Function()>[
      () => Hive.registerAdapter(BusinessDetailsAdapter()),
      () => Hive.registerAdapter(CashMovementModelAdapter()),
      () => Hive.registerAdapter(ExpenseAdapter()),
      () => Hive.registerAdapter(RestaurantSessionModelAdapter()),
    ]) {
      try {
        register();
      } catch (_) {
        // Already registered by another suite in the same isolate.
      }
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantEod)) {
      Hive.registerAdapter(EndOfDayReportAdapter());
      Hive.registerAdapter(OrderTypeSummaryAdapter());
      Hive.registerAdapter(CategorySalesAdapter());
      Hive.registerAdapter(PaymentSummaryAdapter());
      Hive.registerAdapter(CashReconciliationAdapter());
      Hive.registerAdapter(TaxSummaryAdapter());
    }

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);
    await Hive.openBox<RestaurantSessionModel>(
        HiveBoxNames.restaurantSessions);
    await Hive.openBox('dayManagementBox');

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(
        () => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<EodStore>(() => EodStore(EodRepository()));
    locator.registerLazySingleton<CashMovementStore>(
        () => CashMovementStore(CashMovementRepository()));
    locator.registerLazySingleton<ExpenseStore>(
        () => ExpenseStore(ExpenseRepository()));
    locator.registerLazySingleton<CustomerStore>(
        () => CustomerStore(CustomerRepository()));
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
    locator.registerLazySingleton<BusinessDetailsRepository>(
        () => BusinessDetailsRepository());
    locator.registerLazySingleton<CreditPaymentRepository>(
        () => CreditPaymentRepository());

    eodRepo = EodRepository();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> setCountry(String? country) => businessDetailsRepository
      .save(BusinessDetails(storeName: 'Test Store', country: country));

  /// A taxed cash sale. Header CGST/SGST are what the EOD tax summary reads.
  Future<void> seedSale(
    String saleId, {
    required double total,
    double tax = 0,
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: 1,
        subtotal: total - tax,
        discountAmount: 0,
        taxAmount: tax,
        totalAmount: total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        totalTaxableAmount: total - tax,
        totalGstAmount: tax,
        totalCgstAmount: tax / 2,
        totalSgstAmount: tax / 2,
        grandTotal: total,
        paidAmount: total,
        dueAmount: 0,
      ),
    );
  }

  /// A stored close record, written straight to the box — the shape the History
  /// list reads.
  Future<void> seedReport(
    String id, {
    required DateTime date,
    String? mode = 'retail',
    String? sessionId,
    double totalSales = 1000,
    double difference = 0,
    String status = 'Balanced',
    List<TaxSummary> taxSummaries = const [],
  }) async {
    await Hive.box<EndOfDayReport>(HiveBoxNames.retailEOD).put(
      id,
      EndOfDayReport(
        reportId: id,
        date: date,
        openingBalance: 0,
        orderSummaries: const [],
        totalDiscount: 0,
        totalTax: taxSummaries.fold(0.0, (s, t) => s + t.taxAmount),
        categorySales: const [],
        paymentSummaries: const [],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: totalSales,
          actualCash: totalSales + difference,
          difference: difference,
          reconciliationStatus: status,
        ),
        totalSales: totalSales,
        closingBalance: totalSales,
        taxSummaries: taxSummaries,
        totalOrderCount: 1,
        totalRefunds: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        mode: mode,
        sessionId: sessionId,
      ),
    );
  }

  /// The predicate the History list applies, kept verbatim so the test breaks
  /// if the screen's filter is ever widened.
  List<EndOfDayReport> retailOnly(List<EndOfDayReport> all) =>
      all.where((r) => r.mode == 'retail').toList();

  Future<EndOfDayReport> generate({
    double actualCash = 0,
    DateTime? date,
  }) =>
      EODService.generateRetailEODReport(
        date: date ?? day,
        openingBalance: 0,
        actualCash: actualCash,
      );

  // ── session attribution ──────────────────────────────────────────────────

  group('the close is attributed to its session', () {
    test('a generated retail report carries the open session id', () async {
      // Retail shares DayManagementService but the generator never stamped the
      // id, so every retail report was written with sessionId == null — and
      // `saveEODReport` then fell back to de-duplicating by DATE, deleting the
      // earlier close whenever a second session was closed the same day.
      await Hive.box('dayManagementBox').put('currentSessionId', 'sess-A');

      final report = await generate(actualCash: 500);

      expect(report.sessionId, 'sess-A');
    });

    test('two same-date closes under different sessions both survive',
        () async {
      final box = Hive.box('dayManagementBox');

      await box.put('currentSessionId', 'sess-morning');
      await EODService.saveEODReport(await generate(actualCash: 1000));

      await box.put('currentSessionId', 'sess-evening');
      await EODService.saveEODReport(await generate(actualCash: 2000));

      final stored = retailOnly(await eodRepo.getAllEODReports());
      expect(stored, hasLength(2), reason: 'the morning close must survive');
      expect(
        stored.map((r) => r.sessionId).toSet(),
        {'sess-morning', 'sess-evening'},
      );
      expect(
        stored.map((r) => r.cashReconciliation.actualCash).toSet(),
        {1000.0, 2000.0},
      );
    });

    test('re-closing the SAME session replaces rather than duplicates',
        () async {
      await Hive.box('dayManagementBox').put('currentSessionId', 'sess-A');

      await EODService.saveEODReport(await generate(actualCash: 1000));
      await EODService.saveEODReport(await generate(actualCash: 1500));

      final stored = retailOnly(await eodRepo.getAllEODReports());
      expect(stored, hasLength(1));
      expect(stored.single.cashReconciliation.actualCash, 1500);
    });

    test('with no open session it still writes, falling back to date',
        () async {
      // Nothing put in dayManagementBox — getCurrentSessionId returns null.
      final report = await generate(actualCash: 500);
      expect(report.sessionId, isNull);
      expect(report.date, day, reason: 'falls back to the passed date');
    });
  });

  // ── trading day ──────────────────────────────────────────────────────────

  /// Opens a real session so `getDayStartTimestamp()` resolves.
  Future<void> openSession(String id, DateTime startedAt) async {
    await Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions)
        .put(
      id,
      RestaurantSessionModel(
        sessionId: id,
        startTime: startedAt,
        openingCash: 0,
      ),
    );
    await Hive.box('dayManagementBox').put('currentSessionId', id);
  }

  group('the report is dated by TRADING DAY, not by when EOD was run', () {
    test('a close carries the time the session OPENED', () async {
      final opened = DateTime(2026, 4, 15, 9, 15);
      await openSession('sess-day', opened);

      // `date:` is what the screen would pass — deliberately a different day.
      final report = await generate(date: DateTime(2026, 4, 16, 2, 30));

      expect(report.date, opened);
    });

    test('an after-midnight close still belongs to the day it opened',
        () async {
      // Opens 15 Apr 23:00, closed 16 Apr 02:00. The sales window already
      // spans the boundary; dating the record from `now()` filed the close
      // under the 16th, so the report disagreed with its own sales.
      await openSession('sess-night', DateTime(2026, 4, 15, 23, 0));

      final report = await generate(date: DateTime(2026, 4, 16, 2, 0));

      expect(report.date.day, 15);
      expect(report.date.hour, 23);
    });

    test('two sessions on one date keep their own open times', () async {
      await openSession('sess-am', DateTime(2026, 4, 15, 8, 0));
      await EODService.saveEODReport(await generate());
      await openSession('sess-pm', DateTime(2026, 4, 15, 17, 0));
      await EODService.saveEODReport(await generate());

      final stored = retailOnly(await eodRepo.getAllEODReports());
      expect(stored, hasLength(2));
      expect(stored.map((r) => r.date.hour).toSet(), {8, 17});
    });
  });

  // ── EOD-a — retail-only selection ────────────────────────────────────────

  group('retail-only filtering', () {
    test('a restaurant close and a legacy null-mode close are both excluded',
        () async {
      await seedReport('R-1', date: day);
      await seedReport('R-2', date: day, mode: 'restaurant');
      // null means RESTAURANT, per `EndOfDayReport.mode` — the comment that
      // claimed otherwise is what EOD-a corrected.
      await seedReport('R-3', date: day, mode: null);

      final all = await eodRepo.getAllEODReports();
      expect(all, hasLength(3));
      expect(retailOnly(all).map((r) => r.reportId), ['R-1']);
    });

    test('an empty box yields an empty list, not an error', () async {
      expect(await eodRepo.getAllEODReports(), isEmpty);
    });
  });

  // ── EOD-3 — same-day closes ──────────────────────────────────────────────

  group('EOD-3 same-day closes', () {
    test('two closes on one date both persist, with distinct times', () async {
      final morning = DateTime(2026, 4, 15, 11, 5);
      final evening = DateTime(2026, 4, 15, 21, 40);
      await seedReport('R-AM', date: morning, totalSales: 400);
      await seedReport('R-PM', date: evening, totalSales: 900);

      final reports = retailOnly(await eodRepo.getAllEODReports());
      expect(reports, hasLength(2));
      // Same calendar day…
      expect(reports.every((r) => r.date.day == 15), isTrue);
      // …distinguishable only by the time the card now prints.
      expect(reports.map((r) => r.date.hour).toSet(), {11, 21});
      expect(reports.map((r) => r.totalSales).toSet(), {400.0, 900.0});
    });

    test('the record carries a real time, not midnight', () async {
      final report = await generate(date: day);
      expect(report.date, day);
      expect(report.date.hour, 18);
      expect(report.date.minute, 30);
    });

    test('a sessionId is carried when present and null otherwise', () async {
      await seedReport('R-1', date: day, sessionId: 'sess-abc');
      await seedReport('R-2', date: day);

      final byId = {
        for (final r in await eodRepo.getAllEODReports()) r.reportId: r,
      };
      expect(byId['R-1']!.sessionId, 'sess-abc');
      expect(byId['R-2']!.sessionId, isNull);
    });

    test('a generated retail close is stamped with its session', () async {
      // This used to assert the opposite — that retail closes carry no
      // sessionId. That was not a property of retail, it was the defect: the
      // generator never stamped the id, so `saveEODReport` de-duplicated by
      // DATE and a second close on one day deleted the first. Retail shares
      // DayManagementService and has had sessions all along.
      await Hive.box('dayManagementBox').put('currentSessionId', 'sess-xyz');

      final report = await generate();
      expect(report.sessionId, 'sess-xyz');
    });
  });

  // ── ordering ─────────────────────────────────────────────────────────────

  test('reports come back newest first', () async {
    await seedReport('R-OLD', date: DateTime(2026, 4, 10, 20));
    await seedReport('R-NEW', date: DateTime(2026, 4, 15, 20));
    await seedReport('R-MID', date: DateTime(2026, 4, 12, 20));

    final ids =
        (await eodRepo.getAllEODReports()).map((r) => r.reportId).toList();
    expect(ids, ['R-NEW', 'R-MID', 'R-OLD']);
    // Stable across loads.
    expect((await eodRepo.getAllEODReports()).map((r) => r.reportId).toList(),
        ids);
  });

  // ── EOD-2 — reconciliation tolerance ─────────────────────────────────────

  group('EOD-2 float tolerance', () {
    test('the tolerance is half a paisa', () {
      expect(kCashReconciliationTolerance, 0.005);
    });

    test('an exactly counted drawer is Balanced', () async {
      await seedSale('S-1', total: 1000);
      final report = await generate(actualCash: 1000);

      expect(report.cashReconciliation.reconciliationStatus, 'Balanced');
      expect(report.cashReconciliation.difference, closeTo(0, 0.0001));
    });

    test('a residual of 1e-10 is Balanced, not a Shortage', () async {
      await seedSale('S-1', total: 1000);
      final report = await generate(actualCash: 1000 - 0.0000000001);

      // The old `cashDifference == 0` branded this 'Shortage' — permanently,
      // because the status is stored.
      expect(report.cashReconciliation.reconciliationStatus, 'Balanced');
      // And the REAL number is preserved; only the decision changed.
      expect(report.cashReconciliation.difference, isNot(0));
      expect(report.cashReconciliation.difference.abs(),
          lessThan(kCashReconciliationTolerance));
    });

    test('a genuine shortage is still a Shortage', () async {
      await seedSale('S-1', total: 1000);
      final report = await generate(actualCash: 950);

      expect(report.cashReconciliation.reconciliationStatus, 'Shortage');
      expect(report.cashReconciliation.difference, closeTo(-50, 0.001));
    });

    test('a genuine overage is still an Overage', () async {
      await seedSale('S-1', total: 1000);
      final report = await generate(actualCash: 1050);

      expect(report.cashReconciliation.reconciliationStatus, 'Overage');
      expect(report.cashReconciliation.difference, closeTo(50, 0.001));
    });

    test('one paisa is a real difference, not noise', () async {
      await seedSale('S-1', total: 1000);
      final report = await generate(actualCash: 1000.01);

      expect(report.cashReconciliation.reconciliationStatus, 'Overage');
    });

    test('the card gate hides a sub-tolerance residual', () async {
      // The expression the list card now uses.
      bool showsBanner(double difference) =>
          difference.abs() >= kCashReconciliationTolerance;

      expect(showsBanner(0.0000000001), isFalse,
          reason: 'this used to render "Difference: ₹0.00"');
      expect(showsBanner(0), isFalse);
      expect(showsBanner(-0.004), isFalse);
      expect(showsBanner(0.01), isTrue);
      expect(showsBanner(-50), isTrue);
    });
  });

  // ── EOD-1 — country-aware tax ────────────────────────────────────────────

  group('EOD-1 tax summary', () {
    test('India stores CGST and SGST', () async {
      await setCountry('India');
      await seedSale('S-1', total: 1180, tax: 180);

      final report = await generate();
      expect(report.taxSummaries.map((t) => t.taxName), ['CGST', 'SGST']);
      expect(report.taxSummaries.first.taxAmount, closeTo(90, 0.001));
    });

    test('the UK stores ONE row named VAT — never CGST or SGST', () async {
      await setCountry('United Kingdom');
      await seedSale('S-1', total: 1200, tax: 200);

      final report = await generate();
      expect(report.taxSummaries, hasLength(1));
      expect(report.taxSummaries.single.taxName, 'VAT');
      // The two halves, unsplit — nothing invented, nothing dropped.
      expect(report.taxSummaries.single.taxAmount, closeTo(200, 0.001));
      // The whole base, not a half: there is nothing to halve it between.
      expect(report.taxSummaries.single.taxableAmount, closeTo(1000, 0.001));
      expect(report.taxSummaries.map((t) => t.taxName),
          isNot(contains('CGST')));
      expect(report.taxSummaries.map((t) => t.taxName),
          isNot(contains('SGST')));
    });

    test('the US stores one row named Sales Tax', () async {
      await setCountry('United States');
      await seedSale('S-1', total: 1100, tax: 100);

      expect((await generate()).taxSummaries.single.taxName, 'Sales Tax');
    });

    test('an unlisted country stores the generic name', () async {
      await setCountry('Brazil');
      await seedSale('S-1', total: 1100, tax: 100);

      expect((await generate()).taxSummaries.single.taxName, 'Tax');
    });

    test('an unset country keeps the India split', () async {
      await setCountry(null);
      await seedSale('S-1', total: 1180, tax: 180);

      expect((await generate()).taxSummaries.map((t) => t.taxName),
          ['CGST', 'SGST']);
    });

    test('an untaxed day stores no tax rows in any country', () async {
      await setCountry('United Kingdom');
      await seedSale('S-1', total: 1000);

      expect((await generate()).taxSummaries, isEmpty);
    });

    test('the stored total tax is the same figure in every country', () async {
      await seedSale('S-1', total: 1180, tax: 180);

      await setCountry('India');
      final india = await generate();
      await setCountry('United Kingdom');
      final uk = await generate();

      // Only the NAMING differs — this is a presentation rule, not a tax rule.
      expect(uk.totalTax, closeTo(india.totalTax, 0.001));
      expect(uk.totalSales, closeTo(india.totalSales, 0.001));
    });
  });

  // ── EOD-1 — the DISPLAY rule, which fixes history without migration ──────

  group('EOD-1 display of historical records', () {
    /// The rule `EODReportDetailScreen._taxRows` applies.
    List<({String label, double amount})> taxRows(EndOfDayReport report) {
      if (TaxLabelRule.splitsIntoComponents) {
        return report.taxSummaries
            .map((t) => (label: t.taxName, amount: t.taxAmount))
            .toList();
      }
      if (report.totalTax == 0 && report.taxSummaries.isEmpty) {
        return const [];
      }
      return [(label: TaxLabelRule.name, amount: report.totalTax)];
    }

    /// A close saved BEFORE this fix: CGST/SGST rows on disk, whatever the
    /// country.
    Future<EndOfDayReport> legacyRecord() async {
      await seedReport('R-1', date: day, taxSummaries: [
        TaxSummary(
            taxName: 'CGST', taxRate: 0, taxAmount: 90, taxableAmount: 500),
        TaxSummary(
            taxName: 'SGST', taxRate: 0, taxAmount: 90, taxableAmount: 500),
      ]);
      return (await eodRepo.getAllEODReports()).single;
    }

    test('India renders the stored breakdown', () async {
      await setCountry('India');
      final rows = taxRows(await legacyRecord());

      expect(rows.map((r) => r.label), ['CGST', 'SGST']);
      expect(rows.map((r) => r.amount), [90.0, 90.0]);
    });

    test('a UK store never renders the stored CGST/SGST rows', () async {
      await setCountry('United Kingdom');
      final rows = taxRows(await legacyRecord());

      // The record is untouched on disk; the screen simply does not show them.
      expect(rows, hasLength(1));
      expect(rows.single.label, 'VAT');
      // The AUTHORITATIVE total, not the halves added back up.
      expect(rows.single.amount, 180.0);
    });

    test('a record with no tax renders no section at all', () async {
      await setCountry('United Kingdom');
      await seedReport('R-1', date: day);

      expect(taxRows((await eodRepo.getAllEODReports()).single), isEmpty);
    });
  });

  // ── retail keeps the restaurant-shaped sections empty ────────────────────

  group('retail-shaped record', () {
    test('order and category summaries are empty, so those sections hide',
        () async {
      await seedSale('S-1', total: 1000);
      final report = await generate();

      // The detail screen guards both with `isNotEmpty`.
      expect(report.orderSummaries, isEmpty);
      expect(report.categorySales, isEmpty);
      expect(report.mode, 'retail');
    });

    test('a generated close is marked retail and appears in the History list',
        () async {
      await seedSale('S-1', total: 1000);
      final report = await generate();
      await eodRepo.addEODReport(report);

      expect(retailOnly(await eodRepo.getAllEODReports()).map((r) => r.mode),
          ['retail']);
    });
  });

  // ── collections ──────────────────────────────────────────────────────────

  group('credit collections on a close', () {
    Future<void> seedCollection(String id,
        {required double amount, String mode = 'cash'}) async {
      final iso = day.toIso8601String();
      await Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).put(
        id,
        CreditPaymentModel(
          paymentId: id,
          customerId: 'C-1',
          saleId: 'S-1',
          amount: amount,
          paymentMode: mode,
          date: iso,
          createdAt: iso,
          balanceBefore: 0,
          balanceAfter: 0,
        ),
      );
    }

    test('cash, card and UPI collections are carried onto the record',
        () async {
      await seedCollection('P-1', amount: 100, mode: 'cash');
      await seedCollection('P-2', amount: 200, mode: 'card');
      await seedCollection('P-3', amount: 300, mode: 'upi');

      final report = await generate();
      expect(report.cashCollections, closeTo(100, 0.001));
      expect(report.cardCollections, closeTo(200, 0.001));
      expect(report.upiCollections, closeTo(300, 0.001));
    });

    test(
        'KNOWN GAP: a collection under an unknown mode is missing from the '
        'three stored figures', () async {
      await seedCollection('P-1', amount: 100, mode: 'cash');
      await seedCollection('P-2', amount: 250, mode: 'cheque');

      final report = await generate();
      // `EndOfDayReport` has no Other bucket, so the cheque collection lands in
      // none of the three. Pinning CURRENT behaviour, not endorsing it: adding
      // an Other field is a model change and belongs to its own batch.
      expect(report.cashCollections, closeTo(100, 0.001));
      expect(report.cardCollections, 0);
      expect(report.upiCollections, 0);
    });
  });
}
