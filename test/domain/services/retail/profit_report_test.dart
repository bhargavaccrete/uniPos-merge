import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// PROFIT REPORT — the four tabs of one screen.
///
/// Overview, Daily Trend, By-Item and By-Sale answer the same question at four
/// grains, so for one period they must reconcile to ONE profit figure. They did
/// not: Overview and By-Item summed LINE ex-tax revenue while By-Sale and
/// Daily used the sale HEADER (`totalAmount - taxAmount`), which is
/// `taxable + roundOff` — so every sale with a round-off gave the tabs a
/// different answer. The decided basis is the line one: round-off is an
/// adjustment to the customer's payable, attributable to no product's margin.
///
/// The second theme is UNKNOWN COST. A line with no cost price on record keeps
/// its revenue (the sale happened) but contributes no cost, which makes the
/// margin look better than it is. Every tab now counts it the same way AND
/// reports how much of its revenue rests on it.
void main() {
  late Directory tempDir;

  // A fixed past day, so the plan-history window can never clip the fixtures.
  final day = DateTime(2026, 4, 15, 10);
  final nextDay = DateTime(2026, 4, 16, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 17);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('profit_report_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(
        () => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<CategoryStore>(
        () => CategoryStore(CategoryRepository()));
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A sale header. `isReturn` follows the stored retail convention: header
  /// amounts negated, lines left positive.
  Future<void> seedSale(
    String saleId, {
    required double total,
    double tax = 0,
    double roundOff = 0,
    bool isReturn = false,
    double items = 1,
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    final signed = isReturn ? -1 : 1;
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: items,
        subtotal: signed * (total - tax - roundOff),
        discountAmount: 0,
        taxAmount: signed * tax,
        totalAmount: signed * total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: isReturn,
        originalSaleId: isReturn ? 'S-1' : null,
        totalTaxableAmount: signed * (total - tax - roundOff),
        totalGstAmount: signed * tax,
        grandTotal: signed * total,
        roundOff: isReturn ? null : roundOff,
      ),
    );
  }

  /// A sale LINE. Always stored positive, return or not.
  ///
  /// [cost] null means "no cost price snapshotted at sale" — the report then
  /// falls back to the live variant, and only if that is also missing is the
  /// cost genuinely unknown.
  Future<void> seedLine(
    String id, {
    required String saleId,
    String productId = 'P-1',
    String variantId = 'V-1',
    String? productName = 'Rice',
    required double qty,
    required double total,
    double tax = 0,
    double? cost,
  }) async {
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      id,
      SaleItemModel(
        saleItemId: id,
        saleId: saleId,
        varianteId: variantId,
        productId: productId,
        productName: productName,
        price: qty == 0 ? 0 : total / qty,
        qty: qty,
        total: total,
        discountAmount: 0,
        taxAmount: tax,
        gstAmount: tax,
        taxableAmount: total - tax,
        costPrice: cost,
      ),
    );
  }

  /// A live variant, the fallback cost source.
  Future<void> seedVariant(String id, {double? cost}) async {
    await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
      id,
      VarianteModel(
        varianteId: id,
        productId: 'P-1',
        costPrice: cost,
        createdAt: day.toIso8601String(),
      ),
    );
    await locator<ProductStore>().loadProducts();
  }

  Future<Map<String, dynamic>> overview() => ReportService()
      .getProfitReport(startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> byItem() => ReportService()
      .getProfitPerItemReport(startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> bySale() => ReportService()
      .getProfitPerSaleReport(startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> byDay() => ReportService()
      .getProfitPerDayReport(startDate: windowStart, endDate: windowEnd);

  double sumOf(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(0.0, (s, r) => s + (r[key] as num).toDouble());

  int sumInt(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<int>(0, (s, r) => s + (r[key] as num).toInt());

  // ── P-1: one revenue basis on all four tabs ──────────────────────────────

  test('round-off never reaches profit on any tab', () async {
    // Header total 100.40 = 100 of line value + 0.40 round-off, no tax.
    await seedSale('S-1', total: 100.40, roundOff: 0.40);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);

    // 100 revenue - 60 cost. The old header basis gave By-Sale and Daily
    // 100.40 - 60 = 40.40, so the same period read two different profits.
    expect((await overview())['grossProfit'], closeTo(40.0, 0.001));
    expect(sumOf(await byItem(), 'totalProfit'), closeTo(40.0, 0.001));
    expect(sumOf(await bySale(), 'profit'), closeTo(40.0, 0.001));
    expect(sumOf(await byDay(), 'totalProfit'), closeTo(40.0, 0.001));
  });

  test('a NEGATIVE round-off is excluded too', () async {
    await seedSale('S-1', total: 99.60, roundOff: -0.40);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);

    expect(sumOf(await bySale(), 'profit'), closeTo(40.0, 0.001));
    expect(sumOf(await byDay(), 'totalProfit'), closeTo(40.0, 0.001));
  });

  test('tax is out of revenue on every tab', () async {
    // 118 inclusive = 100 taxable + 18 GST, cost 60 -> profit 40, not 58.
    await seedSale('S-1', total: 118, tax: 18);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 118, tax: 18, cost: 60);

    expect((await overview())['totalRevenue'], closeTo(100.0, 0.001));
    expect(sumOf(await byItem(), 'totalRevenue'), closeTo(100.0, 0.001));
    expect(sumOf(await bySale(), 'totalRevenue'), closeTo(100.0, 0.001));
    expect(sumOf(await byDay(), 'totalRevenue'), closeTo(100.0, 0.001));

    expect(sumOf(await bySale(), 'profit'), closeTo(40.0, 0.001));
  });

  test('a return is netted negatively on every tab', () async {
    await seedSale('S-1', total: 200);
    await seedLine('L-1', saleId: 'S-1', qty: 2, total: 200, cost: 60);
    await seedSale('R-1', total: 100, isReturn: true);
    await seedLine('L-2', saleId: 'R-1', qty: 1, total: 100, cost: 60);

    // Sold 2 @100 cost 60, returned 1 -> 100 revenue, 60 cost, 40 profit.
    expect((await overview())['grossProfit'], closeTo(40.0, 0.001));
    expect(sumOf(await byItem(), 'totalProfit'), closeTo(40.0, 0.001));
    expect(sumOf(await bySale(), 'profit'), closeTo(40.0, 0.001));
    expect(sumOf(await byDay(), 'totalProfit'), closeTo(40.0, 0.001));

    // And the return's own row is negative, not absent.
    final returnRow = (await bySale()).firstWhere((r) => r['saleId'] == 'R-1');
    expect(returnRow['isReturn'], isTrue);
    expect(returnRow['profit'], closeTo(-40.0, 0.001));
  });

  // ── P-2: By-Item stays internally consistent ─────────────────────────────

  test('By-Item: profit == revenue - cost when some lines have no cost',
      () async {
    await seedSale('S-1', total: 300, items: 2);
    // Same variant, two lines: one costed, one not.
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);
    await seedLine('L-2', saleId: 'S-1', qty: 2, total: 200); // no cost anywhere

    final row = (await byItem()).single;
    final revenue = (row['totalRevenue'] as num).toDouble();
    final cost = (row['totalCost'] as num).toDouble();
    final profit = (row['totalProfit'] as num).toDouble();

    expect(revenue, closeTo(300.0, 0.001));
    expect(cost, closeTo(60.0, 0.001));
    // The bug: profit was accumulated only inside the costed branch, so it read
    // 40 against 300 of revenue and the row failed its own identity.
    expect(profit, closeTo(revenue - cost, 0.001));
    expect(profit, closeTo(240.0, 0.001));
  });

  test('By-Item margin is computed from the derived profit', () async {
    await seedSale('S-1', total: 300, items: 2);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);
    await seedLine('L-2', saleId: 'S-1', qty: 2, total: 200);

    final row = (await byItem()).single;
    // 240 / 300 = 80%, not the 13.3% the old accumulation produced.
    expect((row['profitMargin'] as num).toDouble(), closeTo(80.0, 0.01));
  });

  // ── P-3 / P-4: unknown cost, identically treated and always surfaced ─────

  test('unknown-cost revenue is COUNTED, and reported, on all four tabs',
      () async {
    await seedSale('S-1', total: 300, items: 2);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);
    await seedLine('L-2',
        saleId: 'S-1', variantId: 'V-2', qty: 2, total: 200); // unknown cost

    final o = await overview();
    expect((o['totalRevenue'] as num).toDouble(), closeTo(300.0, 0.001));
    expect((o['totalCost'] as num).toDouble(), closeTo(60.0, 0.001));
    expect(o['unknownCostLines'], 1);
    expect((o['unknownCostRevenue'] as num).toDouble(), closeTo(200.0, 0.001));

    final items = await byItem();
    expect(sumInt(items, 'unknownCostLines'), 1);
    expect(sumOf(items, 'unknownCostRevenue'), closeTo(200.0, 0.001));
    // Only the un-costed variant is flagged.
    final flagged = items.where((r) => (r['unknownCostLines'] as int) > 0);
    expect(flagged.single['variantId'], 'V-2');

    final sales = await bySale();
    expect(sumInt(sales, 'unknownCostLines'), 1);
    expect(sumOf(sales, 'unknownCostRevenue'), closeTo(200.0, 0.001));

    final days = await byDay();
    expect(sumInt(days, 'unknownCostLines'), 1);
    expect(sumOf(days, 'unknownCostRevenue'), closeTo(200.0, 0.001));
  });

  test('a fully un-costed period reports 100% margin AND says why', () async {
    await seedSale('S-1', total: 100);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100);

    final o = await overview();
    expect((o['profitMargin'] as num).toDouble(), closeTo(100.0, 0.001));
    // The figure alone is indistinguishable from a genuinely free product;
    // these two keys are what the screen prints beside it.
    expect(o['unknownCostLines'], 1);
    expect((o['unknownCostRevenue'] as num).toDouble(), closeTo(100.0, 0.001));

    expect((await byDay()).single['unknownCostLines'], 1);
    expect((await bySale()).single['unknownCostLines'], 1);
    expect((await byItem()).single['unknownCostLines'], 1);
  });

  test('unknown cost is NOT collapsed to zero cost', () async {
    await seedSale('S-1', total: 100);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100);

    // Cost stays 0 because nothing is known — but the line count is what
    // distinguishes it from a real zero-cost sale.
    expect(((await overview())['totalCost'] as num).toDouble(), 0.0);
    expect((await overview())['unknownCostLines'], 1);
  });

  test('a costed line is never flagged as unknown', () async {
    await seedSale('S-1', total: 100);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 0);

    // costPrice 0 is a KNOWN cost of zero, not a missing one.
    final o = await overview();
    expect(o['unknownCostLines'], 0);
    expect((o['unknownCostRevenue'] as num).toDouble(), 0.0);
  });

  // ── Cost source precedence ───────────────────────────────────────────────

  test('the cost frozen on the line beats the live variant cost', () async {
    await seedVariant('V-1', cost: 90);
    await seedSale('S-1', total: 100);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);

    // A later supplier price change must not rewrite a past sale's margin.
    expect(((await overview())['totalCost'] as num).toDouble(),
        closeTo(60.0, 0.001));
  });

  test('the live variant cost is used when the line has none', () async {
    await seedVariant('V-1', cost: 70);
    await seedSale('S-1', total: 100);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100);

    final o = await overview();
    expect((o['totalCost'] as num).toDouble(), closeTo(70.0, 0.001));
    expect(o['unknownCostLines'], 0);
    expect((await byItem()).single['unknownCostLines'], 0);
  });

  // ── P-8: deterministic ordering ──────────────────────────────────────────

  test('By-Item ties break on variantId, not insertion order', () async {
    await seedSale('S-1', total: 300, items: 3);
    // Three variants, identical profit of 40 each.
    await seedLine('L-1',
        saleId: 'S-1', variantId: 'V-3', qty: 1, total: 100, cost: 60);
    await seedLine('L-2',
        saleId: 'S-1', variantId: 'V-1', qty: 1, total: 100, cost: 60);
    await seedLine('L-3',
        saleId: 'S-1', variantId: 'V-2', qty: 1, total: 100, cost: 60);

    final ids =
        (await byItem()).map((r) => r['variantId'] as String).toList();
    expect(ids, ['V-1', 'V-2', 'V-3']);
    // Stable across repeated loads — `List.sort` is not a stable sort.
    expect((await byItem()).map((r) => r['variantId']).toList(), ids);
  });

  test('By-Sale ties break on saleId', () async {
    for (final id in ['S-3', 'S-1', 'S-2']) {
      await seedSale(id, total: 100);
      await seedLine('L-$id', saleId: id, qty: 1, total: 100, cost: 60);
    }

    final ids = (await bySale()).map((r) => r['saleId'] as String).toList();
    expect(ids, ['S-1', 'S-2', 'S-3']);
  });

  test('By-Item still ranks by profit before the tie-break', () async {
    await seedSale('S-1', total: 300, items: 2);
    await seedLine('L-1',
        saleId: 'S-1', variantId: 'V-9', qty: 1, total: 200, cost: 50);
    await seedLine('L-2',
        saleId: 'S-1', variantId: 'V-1', qty: 1, total: 100, cost: 60);

    // V-9 profits 150, V-1 profits 40 — id order must not override that.
    expect((await byItem()).map((r) => r['variantId']).toList(),
        ['V-9', 'V-1']);
  });

  // ── P-5: quantity rendering ──────────────────────────────────────────────

  test('a whole quantity formats as "3", a fractional one as "2.5"', () async {
    await seedSale('S-1', total: 300, items: 3);
    await seedLine('L-1', saleId: 'S-1', qty: 3, total: 300, cost: 60);
    await seedSale('S-2', total: 250, items: 2.5);
    await seedLine('L-2',
        saleId: 'S-2', variantId: 'V-2', qty: 2.5, total: 250, cost: 60);

    final rows = {
      for (final r in await byItem()) r['variantId'] as String: r,
    };
    final whole = (rows['V-1']!['totalQuantitySold'] as num).toDouble();
    final part = (rows['V-2']!['totalQuantitySold'] as num).toDouble();

    expect(formatQty(whole), '3');
    expect(formatQty(part), '2.5');
    // The raw value is a double — the screen used to print it directly.
    expect(rows['V-1']!['totalQuantitySold'], isA<double>());
  });

  test('By-Sale totalItems is a double and formats without a trailing .0',
      () async {
    await seedSale('S-1', total: 300, items: 3);
    await seedLine('L-1', saleId: 'S-1', qty: 3, total: 300, cost: 60);

    final items = (await bySale()).single['totalItems'];
    // `signedItemCount` negates a return, so it returns a double.
    expect(items, isA<double>());
    expect(formatQty((items as num).toDouble()), '3');
  });

  // ── The cross-tab invariant ──────────────────────────────────────────────

  test('all four tabs reconcile to the same profit for one seeded period',
      () async {
    // Deliberately mixed: two days, tax, round-off, a decimal quantity, a
    // return, a line with no cost anywhere, and a line costed live.
    await seedVariant('V-3', cost: 20);

    await seedSale('S-1', total: 118.40, tax: 18, roundOff: 0.40, items: 1);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 118, tax: 18, cost: 60);

    await seedSale('S-2', total: 250, items: 2.5);
    await seedLine('L-2',
        saleId: 'S-2', variantId: 'V-2', qty: 2.5, total: 250, cost: 40);

    await seedSale('S-3', total: 90, items: 1, at: nextDay);
    await seedLine('L-3', saleId: 'S-3', variantId: 'V-3', qty: 1, total: 90);

    await seedSale('S-4', total: 75, items: 1, at: nextDay);
    await seedLine('L-4', saleId: 'S-4', variantId: 'V-4', qty: 1, total: 75);

    await seedSale('R-1', total: 100, isReturn: true, items: 1, at: nextDay);
    await seedLine('L-5', saleId: 'R-1', qty: 1, total: 100, cost: 60);

    final o = await overview();
    final items = await byItem();
    final sales = await bySale();
    final days = await byDay();

    final expectedRevenue = 100.0 + 250.0 + 90.0 + 75.0 - 100.0;
    final expectedCost = 60.0 + (40.0 * 2.5) + 20.0 + 0.0 - 60.0;
    final expectedProfit = expectedRevenue - expectedCost;

    expect((o['totalRevenue'] as num).toDouble(),
        closeTo(expectedRevenue, 0.001));
    expect((o['totalCost'] as num).toDouble(), closeTo(expectedCost, 0.001));
    expect((o['grossProfit'] as num).toDouble(), closeTo(expectedProfit, 0.001));

    // THE INVARIANT: the same period, four grains, one answer.
    expect(sumOf(items, 'totalProfit'), closeTo(expectedProfit, 0.001));
    expect(sumOf(sales, 'profit'), closeTo(expectedProfit, 0.001));
    expect(sumOf(days, 'totalProfit'), closeTo(expectedProfit, 0.001));

    // Revenue and cost reconcile too, not just their difference.
    for (final total in [
      sumOf(items, 'totalRevenue'),
      sumOf(sales, 'totalRevenue'),
      sumOf(days, 'totalRevenue'),
    ]) {
      expect(total, closeTo(expectedRevenue, 0.001));
    }
    for (final total in [
      sumOf(items, 'totalCost'),
      sumOf(sales, 'totalCost'),
      sumOf(days, 'totalCost'),
    ]) {
      expect(total, closeTo(expectedCost, 0.001));
    }

    // And so does the unknown-cost disclosure: only L-4 (V-4) has no cost.
    expect(o['unknownCostLines'], 1);
    expect((o['unknownCostRevenue'] as num).toDouble(), closeTo(75.0, 0.001));
    expect(sumInt(items, 'unknownCostLines'), 1);
    expect(sumInt(sales, 'unknownCostLines'), 1);
    expect(sumInt(days, 'unknownCostLines'), 1);
    expect(sumOf(days, 'unknownCostRevenue'), closeTo(75.0, 0.001));

    // Two days, chronological.
    expect(days.length, 2);
    expect(days.first['date'].toString().compareTo(days.last['date'].toString()),
        lessThan(0));
  });

  test('every By-Item row satisfies profit == revenue - cost', () async {
    await seedVariant('V-2', cost: 10);
    await seedSale('S-1', total: 400, items: 4);
    await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, cost: 60);
    await seedLine('L-2', saleId: 'S-1', qty: 1, total: 100); // V-1, no cost
    await seedLine('L-3',
        saleId: 'S-1', variantId: 'V-2', qty: 1, total: 100); // live cost
    await seedLine('L-4',
        saleId: 'S-1', variantId: 'V-3', qty: 1, total: 100); // unknown

    for (final row in await byItem()) {
      expect((row['totalProfit'] as num).toDouble(),
          closeTo((row['totalRevenue'] as num).toDouble() -
              (row['totalCost'] as num).toDouble(),
              0.001),
          reason: 'row ${row['variantId']} broke its own identity');
    }
  });

  // ── Edges ────────────────────────────────────────────────────────────────

  test('an empty period returns zeroes, not nulls', () async {
    final o = await overview();
    expect((o['totalRevenue'] as num).toDouble(), 0.0);
    expect((o['grossProfit'] as num).toDouble(), 0.0);
    expect((o['profitMargin'] as num).toDouble(), 0.0);
    expect(o['unknownCostLines'], 0);
    expect((o['unknownCostRevenue'] as num).toDouble(), 0.0);
    expect(await byItem(), isEmpty);
    expect(await bySale(), isEmpty);
    expect(await byDay(), isEmpty);
  });

  test('a sale with no lines contributes nothing rather than its header',
      () async {
    await seedSale('S-1', total: 500, tax: 40, roundOff: 0.25);

    // On the header basis this booked 459.75 of profit out of thin air.
    expect(((await overview())['grossProfit'] as num).toDouble(), 0.0);
    expect((await bySale()).single['profit'], 0.0);
    expect((await byDay()).single['totalProfit'], 0.0);
  });

  test('a return more than the period sold gives a negative profit everywhere',
      () async {
    await seedSale('R-1', total: 100, isReturn: true);
    await seedLine('L-1', saleId: 'R-1', qty: 1, total: 100, cost: 60);

    expect(((await overview())['grossProfit'] as num).toDouble(),
        closeTo(-40.0, 0.001));
    expect(sumOf(await byItem(), 'totalProfit'), closeTo(-40.0, 0.001));
    expect(sumOf(await bySale(), 'profit'), closeTo(-40.0, 0.001));
    expect(sumOf(await byDay(), 'totalProfit'), closeTo(-40.0, 0.001));
    // Negative revenue must still produce a real margin, not a flat 0%.
    expect((await byItem()).single['profitMargin'], isNot(0.0));
  });
}
