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

/// TOP SELLING PRODUCTS — eligibility, ranking and truncation.
///
/// Top Selling is Product-wise with three rules on top, and nothing else:
///   1. only rows whose net revenue is > 0
///   2. a DETERMINISTIC order — revenue desc, quantity desc, productId asc
///   3. the first N of what survives
///
/// The arithmetic itself is covered by `line_sales_reports_test.dart`; this
/// file pins the three rules and the parity that guarantees nothing else
/// differs.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 5, 12, 10);
  final windowStart = DateTime(2026, 5, 12);
  final windowEnd = DateTime(2026, 5, 13);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('top_selling_');
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

  Future<void> seedSale(String saleId,
      {required double total, bool isReturn = false, DateTime? at}) async {
    final iso = (at ?? day).toIso8601String();
    final signed = isReturn ? -1 : 1;
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: 1,
        subtotal: signed * total,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: signed * total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: isReturn,
        originalSaleId: isReturn ? 'S-1' : null,
        totalTaxableAmount: signed * total,
        totalGstAmount: 0,
        grandTotal: signed * total,
        roundOff: isReturn ? null : 0,
      ),
    );
  }

  /// A sale LINE — always stored positive, return or not.
  Future<void> seedLine(
    String id, {
    required String saleId,
    required String productId,
    String? variantId,
    String? productName,
    required double qty,
    required double total,
  }) async {
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      id,
      SaleItemModel(
        saleItemId: id,
        saleId: saleId,
        varianteId: variantId ?? '$productId-V',
        productId: productId,
        productName: productName ?? productId,
        price: qty == 0 ? 0 : total / qty,
        qty: qty,
        total: total,
        discountAmount: 0,
        taxAmount: 0,
        gstAmount: 0,
        taxableAmount: total,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> top({int limit = 20}) =>
      ReportService().getTopSellingProductsReport(
          limit: limit, startDate: windowStart, endDate: windowEnd);

  Future<List<Map<String, dynamic>>> productWise() =>
      ReportService().getProductWiseSalesReport(
          startDate: windowStart, endDate: windowEnd);

  double revOf(Map<String, dynamic> r) => (r['totalRevenue'] as num).toDouble();
  double qtyOf(Map<String, dynamic> r) => (r['totalQuantity'] as num).toDouble();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['productId'] as String).toList();

  // ── 1. Metric ──────────────────────────────────────────────────────────

  test('1 ranks by net revenue, not quantity', () async {
    await seedSale('S-1', total: 1100);
    // Many units, little money.
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-CHEAP', qty: 100, total: 100);
    // One unit, a lot of money.
    await seedLine('L-2',
        saleId: 'S-1', productId: 'P-RICH', qty: 1, total: 1000);

    final rows = await top();
    expect(ids(rows), ['P-RICH', 'P-CHEAP']);
    expect(qtyOf(rows.first), 1.0);
    expect(qtyOf(rows.last), 100.0);
  });

  // ── 2 & 3. Limit ───────────────────────────────────────────────────────

  test('2 limit returns exactly N when more are eligible', () async {
    await seedSale('S-1', total: 1500);
    for (var i = 1; i <= 5; i++) {
      await seedLine('L-$i',
          saleId: 'S-1', productId: 'P-$i', qty: 1, total: 100.0 * i);
    }

    final rows = await top(limit: 3);
    expect(rows.length, 3);
    // The three biggest, in order.
    expect(ids(rows), ['P-5', 'P-4', 'P-3']);
  });

  test('3 fewer eligible products returns only those, unpadded', () async {
    await seedSale('S-1', total: 200);
    await seedLine('L-1', saleId: 'S-1', productId: 'P-1', qty: 1, total: 200);

    final rows = await top(limit: 20);
    expect(rows.length, 1);
  });

  // ── 4. Deterministic tie-break ─────────────────────────────────────────

  test('4 equal revenue ties break by quantity desc, then productId asc',
      () async {
    await seedSale('S-1', total: 400);
    // Same revenue, different quantity → higher quantity wins.
    await seedLine('L-1', saleId: 'S-1', productId: 'P-B', qty: 5, total: 100);
    await seedLine('L-2', saleId: 'S-1', productId: 'P-A', qty: 2, total: 100);
    // Same revenue AND same quantity as each other → productId ascending.
    await seedLine('L-3', saleId: 'S-1', productId: 'P-Z', qty: 1, total: 100);
    await seedLine('L-4', saleId: 'S-1', productId: 'P-M', qty: 1, total: 100);

    final rows = await top();
    expect(ids(rows), ['P-B', 'P-A', 'P-M', 'P-Z']);

    // And it must not move between loads — the whole point of the fix.
    for (var i = 0; i < 3; i++) {
      expect(ids(await top()), ['P-B', 'P-A', 'P-M', 'P-Z']);
    }
  });

  // ── 5-7. Returns and eligibility ───────────────────────────────────────

  test('5 returns move a product down the ranking', () async {
    await seedSale('S-1', total: 900);
    await seedLine('L-1', saleId: 'S-1', productId: 'P-1', qty: 5, total: 500);
    await seedLine('L-2', saleId: 'S-1', productId: 'P-2', qty: 4, total: 400);
    // Before the return P-1 leads; after it, P-2 does.
    expect(ids(await top()), ['P-1', 'P-2']);

    await seedSale('R-1', total: 300, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-1', qty: 3, total: 300);

    final rows = await top();
    expect(ids(rows), ['P-2', 'P-1']);
    expect(revOf(rows.last), 200.0);
  });

  test('6 a fully returned product nets zero and is excluded', () async {
    await seedSale('S-1', total: 500);
    await seedLine('L-1', saleId: 'S-1', productId: 'P-GONE', qty: 5, total: 500);
    await seedSale('R-1', total: 500, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-GONE', qty: 5, total: 500);

    expect(await top(), isEmpty);

    // But Product-wise still reports it — the row is excluded from the ranking,
    // not from the books.
    final pw = await productWise();
    expect(ids(pw), ['P-GONE']);
    expect(revOf(pw.single), 0.0);
  });

  test('7 negative net revenue is excluded', () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1', saleId: 'S-1', productId: 'P-OK', qty: 1, total: 200);
    await seedLine('L-2', saleId: 'S-1', productId: 'P-BAD', qty: 1, total: 100);
    // More came back than went out for P-BAD.
    await seedSale('R-1', total: 250, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-BAD', qty: 2, total: 250);

    final rows = await top();
    expect(ids(rows), ['P-OK']);

    final pw = await productWise();
    expect(ids(pw), containsAll(['P-OK', 'P-BAD']));
    expect(revOf(pw.firstWhere((r) => r['productId'] == 'P-BAD')), -150.0);
  });

  // ── 8. Decimal quantity ────────────────────────────────────────────────

  test('8 decimal quantity survives ranking and truncation', () async {
    await seedSale('S-1', total: 550);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-RICE', qty: 2.5, total: 300);
    await seedLine('L-2',
        saleId: 'S-1', productId: 'P-DAL', qty: 1.25, total: 250);
    await seedSale('R-1', total: 120, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-RICE', qty: 1, total: 120);

    final rows = await top(limit: 2);
    expect(ids(rows), ['P-DAL', 'P-RICE']);
    expect(qtyOf(rows.last), 1.5);
    expect(formatQty(qtyOf(rows.last)), '1.5');
  });

  // ── 9-11. Product identity ─────────────────────────────────────────────

  test('9 two variants of one product rank as a single row', () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-1',
        variantId: 'V-S',
        productName: 'Shirt',
        qty: 1,
        total: 100);
    await seedLine('L-2',
        saleId: 'S-1',
        productId: 'P-1',
        variantId: 'V-M',
        productName: 'Shirt',
        qty: 2,
        total: 200);

    final rows = await top();
    expect(rows.length, 1);
    expect(revOf(rows.single), 300.0);
    expect(qtyOf(rows.single), 3.0);
  });

  test('10 same product name with different productId stays separate',
      () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-1',
        productName: 'Soap',
        qty: 1,
        total: 200);
    await seedLine('L-2',
        saleId: 'S-1',
        productId: 'P-2',
        productName: 'Soap',
        qty: 1,
        total: 100);

    final rows = await top();
    expect(rows.length, 2);
    expect(ids(rows), ['P-1', 'P-2']);
    expect(rows.every((r) => r['productName'] == 'Soap'), isTrue);
  });

  test('11 a deleted product still ranks under its snapshotted name', () async {
    await seedSale('S-1', total: 100);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-GONE',
        productName: 'Discontinued Tea',
        qty: 1,
        total: 100);
    // Never present in the products box.

    final rows = await top();
    expect(rows.single['productName'], 'Discontinued Tea');
    // The screen's summary-card cast must hold for a row built this way.
    expect(rows.first['productName'] as String, 'Discontinued Tea');
  });

  // ── 12-13. Window ──────────────────────────────────────────────────────

  test('12 an empty period returns an empty list', () async {
    expect(await top(), isEmpty);
  });

  test('13 the window end bound is exclusive', () async {
    await seedSale('S-IN', total: 100, at: DateTime(2026, 5, 12, 23, 59, 59));
    await seedLine('L-IN',
        saleId: 'S-IN', productId: 'P-IN', qty: 1, total: 100);
    // Exactly the exclusive end.
    await seedSale('S-OUT', total: 999, at: DateTime(2026, 5, 13));
    await seedLine('L-OUT',
        saleId: 'S-OUT', productId: 'P-OUT', qty: 1, total: 999);

    final rows = await top();
    expect(ids(rows), ['P-IN'], reason: 'the 13th belongs to the next window');
  });

  // ── 14. Parity with Product-wise ───────────────────────────────────────

  test('14 Top Selling is exactly the first N eligible Product-wise rows',
      () async {
    await seedSale('S-1', total: 1000);
    for (var i = 1; i <= 6; i++) {
      await seedLine('L-$i',
          saleId: 'S-1', productId: 'P-$i', qty: i.toDouble(), total: 100.0 * i);
    }
    // One product returned into negative, one returned to exactly zero.
    await seedSale('R-1', total: 250, isReturn: true);
    await seedLine('RL-1', saleId: 'R-1', productId: 'P-1', qty: 2, total: 250);
    await seedSale('R-2', total: 200, isReturn: true);
    await seedLine('RL-2', saleId: 'R-2', productId: 'P-2', qty: 2, total: 200);

    final pw = await productWise();
    final expected = pw.where((r) => revOf(r) > 0).take(3).toList();
    final rows = await top(limit: 3);

    expect(ids(rows), ids(expected));

    // Every shared figure is identical — the only Top Selling behaviour is
    // filter, order and limit.
    for (final row in rows) {
      final source =
          pw.firstWhere((r) => r['productId'] == row['productId']);
      for (final key in [
        'productName',
        'totalQuantity',
        'totalRevenue',
        'totalDiscount',
        'totalTax',
      ]) {
        expect(row[key], source[key], reason: '$key for ${row['productId']}');
      }
    }

    // The excluded pair really is excluded, and really is still in Product-wise.
    expect(ids(rows), isNot(contains('P-2')));
    expect(ids(pw), contains('P-2'));
  });
}
