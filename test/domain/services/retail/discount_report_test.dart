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

import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// `ReportService.getDiscountReport` — the three ways a shop gives money away.
///
/// The contract these pin:
///   * `SaleItemModel.lineDiscountAmount` is a SUBSET of `discountAmount`, so
///     bill + line must reconstruct the header exactly and never exceed it;
///   * a price override is NOT inside `discountAmount` — `price` is already the
///     overridden figure, so it has to be recovered separately;
///   * a loyalty redemption is in neither, and is not reversed by a refund;
///   * the three are disjoint, so their sum is a real figure;
///   * these are LINE aggregates, so the sign rule applies and a return emits a
///     negative row that nets its original.
void main() {
  late Directory tempDir;
  late ReportService service;

  final day = DateTime(2026, 7, 14, 10);
  final windowStart = DateTime(2026, 7, 1);
  final windowEnd = DateTime(2026, 8, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('discount_report_');
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

  /// One sale with one line. `discountAmount` on the line is the TOTAL for that
  /// line (its own + its share of the bill's) — the subset contract.
  Future<void> seedSale(
    String saleId, {
    DateTime? at,
    bool isReturn = false,
    double price = 90,
    double qty = 1,
    double lineTotalDiscount = 0,
    double? ownLineDiscount,
    double? originalPrice,
    int? loyaltyPoints,
    String? discountReason,
    String? lineDiscountReason,
    String? overrideReason,
    double? headerTotal,
  }) async {
    final iso = (at ?? day).toIso8601String();
    final sign = isReturn ? -1 : 1;
    final gross = price * qty;
    final total = headerTotal ?? (gross - lineTotalDiscount);

    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: qty,
        subtotal: gross * sign,
        discountAmount: lineTotalDiscount * sign,
        taxAmount: 0,
        totalAmount: total * sign,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: isReturn,
        loyaltyPointsUsed: loyaltyPoints,
        discountReason: discountReason,
      ),
    );

    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      '$saleId-L1',
      SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: price,
        // Return LINES are stored positive — the sign lives on the header.
        qty: qty,
        discountAmount: lineTotalDiscount,
        gstRate: 0,
        taxableAmount: total,
        gstAmount: 0,
        total: total,
        costPrice: 50,
        originalPrice: originalPrice,
        overrideReason: overrideReason,
        lineDiscountAmount: ownLineDiscount,
        lineDiscountReason: lineDiscountReason,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> run() =>
      service.getDiscountReport(startDate: windowStart, endDate: windowEnd);

  // ── Tests ─────────────────────────────────────────────────────────────────

  test('a sale with no giveaway at all is absent', () async {
    await seedSale('S1');
    expect(await run(), isEmpty);
  });

  test('a bill-discount-only sale isolates to billDiscount', () async {
    await seedSale('S1', lineTotalDiscount: 20);

    final row = (await run()).single;
    expect(row['billDiscount'], closeTo(20, 0.005));
    expect(row['lineDiscount'], closeTo(0, 0.005));
    expect(row['discountTotal'], closeTo(20, 0.005));
    expect(row['overrideDelta'], closeTo(0, 0.005));
    expect(row['loyaltyValue'], closeTo(0, 0.005));
    expect(row['totalGivenAway'], closeTo(20, 0.005));
  });

  test('a line-discount-only sale isolates to lineDiscount', () async {
    await seedSale('S1', lineTotalDiscount: 20, ownLineDiscount: 20);

    final row = (await run()).single;
    expect(row['lineDiscount'], closeTo(20, 0.005));
    expect(row['billDiscount'], closeTo(0, 0.005));
  });

  // If bill + line ever exceeded the header, a report summing both fields
  // would be double-counting the line's own share.
  test('bill + line reconstructs the header discount exactly', () async {
    await seedSale('S1', lineTotalDiscount: 130.50, ownLineDiscount: 90);

    final row = (await run()).single;
    expect(row['lineDiscount'], closeTo(90, 0.005));
    expect(row['billDiscount'], closeTo(40.50, 0.005));
    expect(
      (row['billDiscount'] as double) + (row['lineDiscount'] as double),
      closeTo(row['discountTotal'] as double, 0.005),
    );
  });

  // The override is invisible in discountAmount: `price` is already the
  // overridden figure, so it must be recovered from originalPrice.
  test('a price override is counted, and is not inside the discount', () async {
    await seedSale('S1', price: 90, qty: 2, originalPrice: 100);

    final row = (await run()).single;
    expect(row['overrideDelta'], closeTo(20, 0.005));
    expect(row['discountTotal'], closeTo(0, 0.005));
    expect(row['totalGivenAway'], closeTo(20, 0.005));
    // List value is what the goods would have fetched before any of it.
    expect(row['listValue'], closeTo(200, 0.005));
  });

  test('a loyalty redemption is counted, and is in neither of the others',
      () async {
    await seedSale('S1', loyaltyPoints: 50);

    final row = (await run()).single;
    expect(row['loyaltyPointsUsed'], 50);
    expect(row['loyaltyValue'], closeTo(50, 0.005));
    expect(row['discountTotal'], closeTo(0, 0.005));
    expect(row['overrideDelta'], closeTo(0, 0.005));
    expect(row['totalGivenAway'], closeTo(50, 0.005));
  });

  // THE double-counting guard: all four buckets non-zero at once, and the
  // headline is exactly their sum.
  test('all three mechanisms on one sale stay independent and additive',
      () async {
    await seedSale(
      'S1',
      price: 90,
      qty: 1,
      originalPrice: 100, // override:  10
      lineTotalDiscount: 30, // discount:  30 total…
      ownLineDiscount: 18, // …of which 18 is the line's own, 12 the bill's
      loyaltyPoints: 25, // loyalty:   25
    );

    final row = (await run()).single;
    expect(row['overrideDelta'], closeTo(10, 0.005));
    expect(row['lineDiscount'], closeTo(18, 0.005));
    expect(row['billDiscount'], closeTo(12, 0.005));
    expect(row['discountTotal'], closeTo(30, 0.005));
    expect(row['loyaltyValue'], closeTo(25, 0.005));
    expect(row['totalGivenAway'], closeTo(65, 0.005));
  });

  test('the giveaway rate is measured against list value', () async {
    await seedSale('S1', price: 90, originalPrice: 100, lineTotalDiscount: 10);

    final row = (await run()).single;
    // 10 override + 10 discount = 20 of a 100 list value.
    expect(row['listValue'], closeTo(100, 0.005));
    expect(row['totalGivenAway'], closeTo(20, 0.005));
    expect(row['giveawayPct'], closeTo(20, 0.05));
  });

  // Line-level aggregation, so the sign rule applies — unlike the refund
  // report, which reads already-negated headers.
  test('a return emits a negative row that nets its original', () async {
    await seedSale('S1', lineTotalDiscount: 40);
    await seedSale('R1',
        isReturn: true,
        lineTotalDiscount: 40,
        at: day.add(const Duration(days: 1)));

    final rows = await run();
    expect(rows, hasLength(2));

    final net = rows.fold<double>(
      0,
      (s, r) => s + (r['totalGivenAway'] as double),
    );
    expect(net, closeTo(0, 0.005));
    expect(rows.any((r) => (r['totalGivenAway'] as double) < 0), isTrue);
  });

  // Redeemed points are not handed back on a refund, so the report must not
  // synthesise a reversal it has no data for.
  test('loyalty is not reversed on a return', () async {
    await seedSale('S1', loyaltyPoints: 50);
    await seedSale('R1',
        isReturn: true,
        loyaltyPoints: null,
        lineTotalDiscount: 0,
        at: day.add(const Duration(days: 1)));

    final rows = await run();
    // Only the original row qualifies — the return gave nothing away.
    expect(rows, hasLength(1));
    expect(rows.single['saleId'], 'S1');
    expect(rows.single['loyaltyValue'], closeTo(50, 0.005));
  });

  test('reasons come through for all three mechanisms', () async {
    await seedSale(
      'S1',
      price: 90,
      originalPrice: 100,
      lineTotalDiscount: 30,
      ownLineDiscount: 30,
      discountReason: 'Promotion',
      lineDiscountReason: 'clearance',
      overrideReason: 'damaged_packaging',
    );

    final row = (await run()).single;
    expect(row['discountReason'], 'Promotion');
    expect(row['lineDiscountReasons'], 'Clearance');
    expect(row['overrideReasons'], 'Damaged Packaging');
  });

  test('rows are ordered by the largest giveaway first', () async {
    await seedSale('S1', lineTotalDiscount: 10);
    await seedSale('S2', lineTotalDiscount: 90);

    expect((await run()).first['saleId'], 'S2');
  });

  test('the window start is inclusive and the end exclusive', () async {
    await seedSale('S_early',
        lineTotalDiscount: 10, at: DateTime(2026, 6, 30, 23));
    await seedSale('S_start', lineTotalDiscount: 10, at: windowStart);
    await seedSale('S_end', lineTotalDiscount: 10, at: windowEnd);

    final ids = (await run()).map((r) => r['saleId']).toList();
    expect(ids, contains('S_start'));
    expect(ids, isNot(contains('S_early')));
    expect(ids, isNot(contains('S_end')));
  });

  // A rounding tail is not a give-away.
  test('a sub-paisa giveaway does not become a row', () async {
    await seedSale('S1', lineTotalDiscount: 0.004);
    expect(await run(), isEmpty);
  });
}
