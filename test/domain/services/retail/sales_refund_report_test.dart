import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/shift_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// `ReportService.getSalesRefundReport` — the per-document refund listing.
///
/// The contract these pin:
///   * a return HEADER is stored already negated, so the report must report
///     magnitudes and must NOT apply `RetailSaleFilter.revenueSign` on top;
///   * returned VALUE and money PAID OUT are different figures — a refund
///     against an unpaid invoice cancels a debt, and an exchange sends most of
///     its value into a replacement sale;
///   * exchange legs are listed and flagged, never silently dropped.
void main() {
  late Directory tempDir;
  late ReportService service;

  final day = DateTime(2026, 7, 14, 10);
  final windowStart = DateTime(2026, 7, 1);
  final windowEnd = DateTime(2026, 8, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('refund_report_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<ShiftModel>(HiveBoxNames.shift);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator
        .registerLazySingleton<SaleItemRepository>(() => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<CustomerRepository>(
        () => CustomerRepository());
    locator.registerLazySingleton<ShiftRepository>(() => ShiftRepository());
    // ReportService's constructor reads the plan history cutoff, which goes
    // through PlanEnforce._bypassed -> LicenseStore.
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));

    service = ReportService();
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Seeding ───────────────────────────────────────────────────────────────

  Future<void> seedSale(
    String saleId, {
    double total = 118,
    DateTime? at,
    String? customerId,
    double dueAmount = 0,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        customerId: customerId,
        totalItems: 1,
        subtotal: total / 1.18,
        discountAmount: 0,
        taxAmount: total - total / 1.18,
        totalAmount: total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        paidAmount: total - dueAmount,
        dueAmount: dueAmount,
      ),
    );
  }

  /// A credit note, written the way `ReturnService` writes one: header negated,
  /// `totalItems` positive, `paymentType` holding the refund method.
  Future<void> seedReturn(
    String returnId, {
    required String originalSaleId,
    double value = 118,
    DateTime? at,
    String method = 'cash',
    String? reason = 'damaged',
    String? exchangeGroupId,
    String? paymentListJson,
    String? customerId,
    String? shiftId,
  }) async {
    final iso = (at ?? day.add(const Duration(days: 1))).toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      returnId,
      SaleModel(
        saleId: returnId,
        customerId: customerId,
        totalItems: 1,
        subtotal: -(value / 1.18),
        discountAmount: 0,
        taxAmount: -(value - value / 1.18),
        totalAmount: -value,
        paymentType: method,
        paymentListJson: paymentListJson,
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: true,
        originalSaleId: originalSaleId,
        grandTotal: -value,
        paidAmount: -value,
        returnReason: reason,
        exchangeGroupId: exchangeGroupId,
        shiftId: shiftId,
      ),
    );
  }

  Future<void> seedAdjustment(
    String returnId, {
    required String originalSaleId,
    required double amount,
    String customerId = 'C1',
  }) async {
    await Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).put(
      'CP-$returnId',
      CreditPaymentModel.create(
        paymentId: 'CP-$returnId',
        customerId: customerId,
        saleId: originalSaleId,
        amount: amount,
        paymentMode: 'return_adjustment',
        referenceId: returnId,
        balanceBefore: amount,
        balanceAfter: 0,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> run() =>
      service.getSalesRefundReport(startDate: windowStart, endDate: windowEnd);

  // ── Tests ─────────────────────────────────────────────────────────────────

  test('a period with no refunds returns nothing', () async {
    await seedSale('S1');
    expect(await run(), isEmpty);
  });

  test('forward sales never appear; only return documents do', () async {
    await seedSale('S1');
    await seedSale('S2');
    await seedReturn('RTN_1', originalSaleId: 'S1');

    final rows = await run();
    expect(rows, hasLength(1));
    expect(rows.single['returnSaleId'], 'RTN_1');
    expect(rows.single['originalSaleId'], 'S1');
  });

  // The sign trap: headers are stored negated, so applying revenueSign on top
  // would hand back a negative refund value.
  test('refund value is reported POSITIVE despite a negative header', () async {
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1', value: 118);

    final row = (await run()).single;
    expect(row['refundValue'], closeTo(118, 0.005));
    expect(row['subtotal'], greaterThan(0));
    expect(row['taxAmount'], greaterThan(0));
    // totalItems is the one header field already stored positive.
    expect(row['totalItems'], closeTo(1, 0.005));
  });

  test('the total equals the sum of the stored header magnitudes', () async {
    await seedSale('S1');
    await seedSale('S2');
    await seedReturn('RTN_1', originalSaleId: 'S1', value: 118);
    await seedReturn('RTN_2', originalSaleId: 'S2', value: 236);

    final rows = await run();
    final total = rows.fold<double>(
      0,
      (s, r) => s + (r['refundValue'] as double),
    );
    expect(total, closeTo(354, 0.005));
  });

  test('the refund method is read off the return header', () async {
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1', method: 'upi');

    expect((await run()).single['refundMethod'], 'upi');
  });

  test('the stored reason resolves to its label', () async {
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1', reason: 'wrong_item');

    expect((await run()).single['returnReasonLabel'], 'Wrong Item Given');
  });

  test('a refund written before reasons existed reads as Not recorded',
      () async {
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1', reason: null);

    expect((await run()).single['returnReasonLabel'], 'Not recorded');
  });

  // Money that cancelled a debt is not money that left the till.
  test('a refund against an unpaid invoice splits due from paid out', () async {
    await seedSale('S1', total: 118, customerId: 'C1', dueAmount: 100);
    await seedReturn('RTN_1',
        originalSaleId: 'S1', value: 118, customerId: 'C1');
    await seedAdjustment('RTN_1', originalSaleId: 'S1', amount: 100);

    final row = (await run()).single;
    expect(row['refundValue'], closeTo(118, 0.005));
    expect(row['appliedToDue'], closeTo(100, 0.005));
    expect(row['paidOut'], closeTo(18, 0.005));
  });

  test('paid out never goes negative when the due exceeds the refund',
      () async {
    await seedSale('S1', total: 118, customerId: 'C1', dueAmount: 118);
    await seedReturn('RTN_1',
        originalSaleId: 'S1', value: 118, customerId: 'C1');
    await seedAdjustment('RTN_1', originalSaleId: 'S1', amount: 118);

    expect((await run()).single['paidOut'], closeTo(0, 0.005));
  });

  // An exchange's return leg is rewritten by ExchangeService._stamp AFTER the
  // return is written, so the header no longer describes what changed hands.
  // Deriving paidOut from it would overstate cash out by the whole goods value.
  test('an exchange leg reports only the money difference as paid out',
      () async {
    await seedSale('S1', total: 1062);
    await seedReturn(
      'RTN_1',
      originalSaleId: 'S1',
      value: 1062,
      exchangeGroupId: 'EXC-20260714-001',
      method: 'upi',
      paymentListJson:
          '[{"method":"${ExchangeService.exchangeCreditMethod}","amount":-1000},'
          '{"method":"upi","amount":-62}]',
    );

    final row = (await run()).single;
    expect(row['isExchange'], isTrue);
    expect(row['refundValue'], closeTo(1062, 0.005));
    // Only the money leg — the exchange_credit leg is an accounting entry.
    expect(row['paidOut'], closeTo(62, 0.005));
  });

  test('an exchange with no reason still labels itself Exchange', () async {
    await seedSale('S1');
    await seedReturn('RTN_1',
        originalSaleId: 'S1',
        reason: null,
        exchangeGroupId: 'EXC-20260714-001');

    expect((await run()).single['returnReasonLabel'], 'Exchange');
  });

  test('exchange legs are listed, not dropped', () async {
    await seedSale('S1');
    await seedSale('S2');
    await seedReturn('RTN_1', originalSaleId: 'S1');
    await seedReturn('RTN_2',
        originalSaleId: 'S2', exchangeGroupId: 'EXC-20260714-001');

    final rows = await run();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r['isExchange'] as bool), hasLength(1));
  });

  test('the window start is inclusive and the end exclusive', () async {
    await seedSale('S1');
    await seedReturn('RTN_early',
        originalSaleId: 'S1', at: DateTime(2026, 6, 30, 23));
    await seedReturn('RTN_start', originalSaleId: 'S1', at: windowStart);
    await seedReturn('RTN_end', originalSaleId: 'S1', at: windowEnd);

    final ids = (await run()).map((r) => r['returnSaleId']).toList();
    expect(ids, contains('RTN_start'));
    expect(ids, isNot(contains('RTN_early')));
    expect(ids, isNot(contains('RTN_end')));
  });

  test('rows come back newest first', () async {
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1', at: DateTime(2026, 7, 5));
    await seedReturn('RTN_2', originalSaleId: 'S1', at: DateTime(2026, 7, 20));

    expect((await run()).first['returnSaleId'], 'RTN_2');
  });

  test('a walk-in refund names no customer, and no shift names no staff',
      () async {
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1');

    final row = (await run()).single;
    expect(row['customerName'], 'Walk-in');
    expect(row['staffName'], '—');
  });

  test('the shift link resolves the staff who processed it', () async {
    await Hive.box<ShiftModel>(HiveBoxNames.shift).put(
      'SH1',
      ShiftModel(
        id: 'SH1',
        staffId: 'st1',
        staffName: 'Priya',
        startTime: day,
      ),
    );
    await seedSale('S1');
    await seedReturn('RTN_1', originalSaleId: 'S1', shiftId: 'SH1');

    expect((await run()).single['staffName'], 'Priya');
  });

  test('days to return is measured against the original sale', () async {
    await seedSale('S1', at: DateTime(2026, 7, 2, 10));
    await seedReturn('RTN_1',
        originalSaleId: 'S1', at: DateTime(2026, 7, 9, 10));

    expect((await run()).single['daysToReturn'], 7);
  });
}
