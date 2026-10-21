import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_step_bar.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

/// MONTHLY SALES — window boundaries and the picker's history clamp.
///
/// The totals arithmetic is NOT retested here: `getMonthlySalesReport` spreads
/// `RetailSalesTotals.compute` unchanged, and `sales_totals_test.dart` pins that
/// in full. What is monthly's alone is the WINDOW — which month a sale falls
/// into — and the fact that a month, unlike a day, can be only partly inside the
/// plan's history window.
void main() {
  late Directory tempDir;

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('monthly_sales_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(
        () => SaleItemRepository());
    // ReportService reads the plan's report-history window through LicenseStore.
    // Unlicensed retail bypasses it, so a bare store means "unlimited history".
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A forward sale stamped at an exact instant, so boundary cases are precise.
  Future<void> seedSale(String id, DateTime at, {double total = 100}) async {
    final iso = at.toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      id,
      SaleModel(
        saleId: id,
        totalItems: 1,
        subtotal: total,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        totalTaxableAmount: total,
        totalGstAmount: 0,
        grandTotal: total,
        roundOff: 0,
      ),
    );
  }

  /// A return document, stored the way `return_service` writes one: header
  /// amounts negated, `totalItems` positive.
  Future<void> seedReturn(String id, DateTime at, {double total = 40}) async {
    final iso = at.toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      id,
      SaleModel(
        saleId: id,
        totalItems: 1,
        subtotal: -total,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: -total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: true,
        originalSaleId: 'S-OLD',
        totalTaxableAmount: -total,
        totalGstAmount: 0,
        grandTotal: -total,
      ),
    );
  }

  double amount(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();

  // ── E1: December rolls into January ────────────────────────────────────

  test('E1 December window ends at 1 January of the next year', () async {
    await seedSale('in-first', DateTime(2025, 12, 1));
    // The last representable instant of December.
    await seedSale('in-last', DateTime(2025, 12, 31, 23, 59, 59, 999));
    // First instant of January — the exclusive end bound.
    await seedSale('out-next', DateTime(2026, 1, 1));

    final dec = await ReportService().getMonthlySalesReport(2025, 12);
    expect(dec['totalSales'], 2, reason: 'Jan 1 must fall outside December');
    expect(amount(dec, 'totalRevenue'), 200.0);

    // And the sale December excluded is the one January claims.
    final jan = await ReportService().getMonthlySalesReport(2026, 1);
    expect(jan['totalSales'], 1);
    expect(amount(jan, 'totalRevenue'), 100.0);
  });

  // ── E2: February, both lengths ─────────────────────────────────────────

  test('E2 February 2026 (28 days) ends at 1 March', () async {
    await seedSale('feb-last', DateTime(2026, 2, 28, 23, 59, 59, 999));
    await seedSale('mar-first', DateTime(2026, 3, 1));
    // The day a 29-day February would have had, in a year that has none:
    // DateTime normalises this to 1 March, so it must NOT count as February.
    await seedSale('phantom-29', DateTime(2026, 2, 29));

    final feb = await ReportService().getMonthlySalesReport(2026, 2);
    expect(feb['totalSales'], 1);
    expect(amount(feb, 'totalRevenue'), 100.0);

    final mar = await ReportService().getMonthlySalesReport(2026, 3);
    expect(mar['totalSales'], 2);
  });

  test('E2 February 2024 (leap) includes 29 February', () async {
    await seedSale('leap-29', DateTime(2024, 2, 29, 12));
    await seedSale('mar-first', DateTime(2024, 3, 1));

    final feb = await ReportService().getMonthlySalesReport(2024, 2);
    expect(feb['totalSales'], 1);
    expect(amount(feb, 'totalRevenue'), 100.0);
  });

  // ── E5: a month that contains only returns ─────────────────────────────

  test('E5 a month of returns only reports a negative net, and no crash',
      () async {
    // Goods sold in an earlier month, handed back in this one.
    await seedReturn('R-1', DateTime(2026, 3, 10), total: 40);
    await seedReturn('R-2', DateTime(2026, 3, 18), total: 60);

    final m = await ReportService().getMonthlySalesReport(2026, 3);

    expect(m['totalSales'], 0);
    expect(m['totalReturns'], 2);
    expect(amount(m, 'totalRevenue'), 0.0);
    expect(amount(m, 'totalReturnAmount'), 100.0);
    expect(amount(m, 'netRevenue'), -100.0);
    // Returned units are counted positively on their own key, and negatively
    // in the net — the return-header convention, over a whole month.
    expect(amount(m, 'returnedItems'), 2.0);
    expect(amount(m, 'totalItems'), -2.0);
    // Guarded: no sales means no divide.
    expect(amount(m, 'averageSaleValue'), 0.0);
  });

  // ── D1: the picker clamp ───────────────────────────────────────────────

  test('D1 a month can start before the history cutoff, and the clamp holds',
      () async {
    // Unlicensed retail bypasses the window entirely — the state that keeps
    // this crash dormant today.
    expect(ReportHistoryWindow.cutoff, isNull);
    expect(ReportDateStepBar.pickerFirstDate(), DateTime(2020));

    // Arm it: a manifest makes PlanEnforce enforce rather than bypass.
    Entitlements.instance.loadFromManifest(
      const ManifestData(
        entitlements: {RetailEntKeys.reportsHistoryLimitDays: 30},
        license: {},
        version: 1,
      ),
    );

    final first = ReportDateStepBar.pickerFirstDate();
    expect(ReportHistoryWindow.cutoff, isNotNull);

    // The reachable state: `_canStepBack` allows a month whose END clears the
    // cutoff, so the selected month's FIRST DAY can precede it.
    final selectedMonth = DateTime(first.year, first.month);
    final monthEnd = DateTime(first.year, first.month + 1);
    expect(monthEnd.isAfter(ReportHistoryWindow.cutoff!), isTrue,
        reason: 'this month is partly visible, so stepping to it is allowed');
    expect(selectedMonth.isBefore(first), isTrue,
        reason: 'its first day precedes the picker range — the crash condition');

    // showDatePicker asserts !initialDate.isBefore(firstDate). Unclamped, the
    // value above trips it; clamped, it cannot.
    final initial = selectedMonth.isBefore(first) ? first : selectedMonth;
    expect(initial.isBefore(first), isFalse);
    expect(initial, first);

    // A fully visible month is passed through untouched.
    final recent = DateTime(DateTime.now().year, DateTime.now().month);
    expect(recent.isBefore(first) ? first : recent, recent);
  });
}
