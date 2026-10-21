import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// RETAIL EOD — how a return is signed.
///
/// The defect these pin: return headers are stored ALREADY negated, and the
/// retail EOD negated them a second time. `-(-1000)` is `+1000`, so every
/// refund was ADDED to the day's takings — the figure the shop closes against
/// moved by twice the refund, in the wrong direction.
///
/// Seeds a known day into real Hive boxes and asserts against hand-computed
/// figures — the strategy `eod_service_test.dart` uses for restaurant.
void main() {
  late Directory tempDir;

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('retail_eod_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.appCounters);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<CustomerStore>(
        () => CustomerStore(CustomerRepository()));
    locator.registerLazySingleton<ExpenseStore>(
        () => ExpenseStore(ExpenseRepository()));
    locator.registerLazySingleton<CreditPaymentRepository>(
        () => CreditPaymentRepository());
    // ReportService consults the plan's report-history window, which reads
    // LicenseStore. Unlicensed retail bypasses, so a bare store is enough.
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
    locator.registerLazySingleton<SaleItemRepository>(
        () => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A forward sale, stamped now so it lands inside the EOD window.
  Future<void> seedSale({
    required String id,
    required double total,
    double tax = 0,
    String paymentType = 'cash',
  }) async {
    // Stamped a moment in the past on purpose: the EOD window's end bound is
    // EXCLUSIVE and is computed as `DateTime.now()` inside the report, so a
    // seed seeded on the same millisecond falls outside it intermittently.
    final now = DateTime.now()
        .subtract(const Duration(seconds: 2))
        .toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      id,
      SaleModel(
        saleId: id,
        totalItems: 1,
        subtotal: total - tax,
        discountAmount: 0,
        taxAmount: tax,
        totalAmount: total,
        paymentType: paymentType,
        date: now,
        createdAt: now,
        updatedAt: now,
        totalTaxableAmount: total - tax,
        totalGstAmount: tax,
        totalCgstAmount: tax / 2,
        totalSgstAmount: tax / 2,
        grandTotal: total,
      ),
    );
  }

  /// A return, stored the way `ReturnService` writes one: header NEGATED.
  Future<void> seedReturn({
    required String id,
    required String originalSaleId,
    required double total,
    double tax = 0,
    String refundMethod = 'cash',
  }) async {
    // Stamped a moment in the past on purpose: the EOD window's end bound is
    // EXCLUSIVE and is computed as `DateTime.now()` inside the report, so a
    // seed seeded on the same millisecond falls outside it intermittently.
    final now = DateTime.now()
        .subtract(const Duration(seconds: 2))
        .toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      id,
      SaleModel(
        saleId: id,
        totalItems: 1,
        subtotal: -(total - tax),
        discountAmount: 0,
        taxAmount: -tax,
        totalAmount: -total,
        paymentType: refundMethod,
        date: now,
        createdAt: now,
        updatedAt: now,
        isReturn: true,
        originalSaleId: originalSaleId,
        totalTaxableAmount: -(total - tax),
        totalGstAmount: -tax,
        totalCgstAmount: -(tax / 2),
        totalSgstAmount: -(tax / 2),
        grandTotal: -total,
      ),
    );
  }

  Future<EndOfDayReport> generate() => EODService.generateRetailEODReport(
        date: DateTime.now(),
        openingBalance: 1000,
        actualCash: 0,
      );

  // ==========================================================================
  group('a return reduces the day, never inflates it', () {
    test('1000 sold, 400 returned gives total sales of 600', () async {
      await seedSale(id: 'S1', total: 1000);
      await seedReturn(id: 'RTN_1', originalSaleId: 'S1', total: 400);

      final report = await generate();

      // The bug produced 1400 here: 1000 + (-(-400)).
      expect(report.totalSales, closeTo(600, 0.01));
    });

    test('a fully returned day nets to zero, not double', () async {
      await seedSale(id: 'S1', total: 500);
      await seedReturn(id: 'RTN_1', originalSaleId: 'S1', total: 500);

      final report = await generate();

      expect(report.totalSales, closeTo(0, 0.01));
    });

    test('a day with no returns is unaffected by the fix', () async {
      await seedSale(id: 'S1', total: 250);
      await seedSale(id: 'S2', total: 750);

      final report = await generate();

      expect(report.totalSales, closeTo(1000, 0.01));
    });
  });

  // ==========================================================================
  group('totalRefunds is positive so the row can render', () {
    test('a 400 refund reports as +400', () async {
      await seedSale(id: 'S1', total: 1000);
      await seedReturn(id: 'RTN_1', originalSaleId: 'S1', total: 400);

      final report = await generate();

      // `eod_report_detail_screen` gates the row on `> 0`, so a negative
      // figure meant refunds were silently never shown at all.
      expect(report.totalRefunds, closeTo(400, 0.01));
      expect(report.totalRefunds, greaterThan(0));
    });

    test('several refunds sum as magnitudes', () async {
      await seedSale(id: 'S1', total: 1000);
      await seedReturn(id: 'RTN_1', originalSaleId: 'S1', total: 150);
      await seedReturn(id: 'RTN_2', originalSaleId: 'S1', total: 250);

      final report = await generate();

      expect(report.totalRefunds, closeTo(400, 0.01));
      expect(report.totalSales, closeTo(600, 0.01));
    });

    test('no returns means no refunds', () async {
      await seedSale(id: 'S1', total: 300);

      final report = await generate();

      expect(report.totalRefunds, closeTo(0, 0.01));
    });
  });

  // ==========================================================================
  group('tax reconciles with the returns it nets', () {
    test('CGST + SGST equals totalTax once a return is in the day', () async {
      await seedSale(id: 'S1', total: 1180, tax: 180);
      await seedReturn(id: 'RTN_1', originalSaleId: 'S1', total: 590, tax: 90);

      final report = await generate();

      // Skipping returns here while `totalTax` netted them left the two
      // permanently unable to agree on any day containing a refund.
      final cgst = report.taxSummaries
          .where((t) => t.taxName == 'CGST')
          .fold<double>(0, (s, t) => s + t.taxAmount);
      final sgst = report.taxSummaries
          .where((t) => t.taxName == 'SGST')
          .fold<double>(0, (s, t) => s + t.taxAmount);

      expect(report.totalTax, closeTo(90, 0.01));
      expect(cgst + sgst, closeTo(report.totalTax, 0.02));
    });
  });
}
