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

/// LINE-LEVEL SALES REPORTS — product, variant and category.
///
/// These three aggregate the SAME sale lines by different keys, so they must
/// agree on sign, quantity, revenue, discount and tax and differ only in how
/// rows are grouped. The bug this file exists for: `totalQuantity` is a
/// `double` (retail sells by weight) and all three screens read it back
/// `as int`, which throws on the Dart VM for every non-empty period.
void main() {
  late Directory tempDir;

  // A fixed past day, so the plan-history window can never clip the fixtures.
  final day = DateTime(2026, 4, 15, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 16);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('line_sales_');
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
    // Header item count. Stored POSITIVE even on a return — the one header
    // field `return_service` does not negate.
    double items = 1,
  }) async {
    final iso = day.toIso8601String();
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
  Future<void> seedLine(
    String id, {
    required String saleId,
    required String productId,
    required String variantId,
    String? productName,
    required double qty,
    required double total,
    double discount = 0,
    double tax = 0,
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
        discountAmount: discount,
        taxAmount: tax,
        gstAmount: tax,
        taxableAmount: total - tax,
      ),
    );
  }

  Future<void> seedProduct(String id, String name, {String category = ''}) async {
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
      id,
      ProductModel(
        productId: id,
        productName: name,
        category: category,
        hasVariants: false,
        createdAt: day.toIso8601String(),
        updateAt: day.toIso8601String(),
      ),
    );
    await productStore.loadProducts();
  }

  Future<List<Map<String, dynamic>>> products() =>
      ReportService().getProductWiseSalesReport(
          startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> variants() =>
      ReportService().getVariantWiseSalesReport(
          startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> categories() =>
      ReportService().getCategoryWiseSalesReport(
          startDate: windowStart, endDate: windowEnd);

  double qtyOf(Map<String, dynamic> r) => (r['totalQuantity'] as num).toDouble();
  double revOf(Map<String, dynamic> r) => (r['totalRevenue'] as num).toDouble();

  // ── Quantity type contract — the B1 regression guard ───────────────────

  test('totalQuantity is a double in all three reports, never an int',
      () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-1',
        variantId: 'V-1',
        productName: 'Rice',
        qty: 3,
        total: 300);
    await seedProduct('P-1', 'Rice');

    for (final rows in [await products(), await variants(), await categories()]) {
      expect(rows, isNotEmpty);
      // The exact expression the screens used to run — `as int` on this throws.
      expect(rows.first['totalQuantity'], isA<double>());
      expect(() => rows.first['totalQuantity'] as int, throwsA(isA<TypeError>()));
      // What they run now.
      expect(() => (rows.first['totalQuantity'] as num).toDouble(),
          returnsNormally);
    }
  });

  test('normal integer quantity', () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 3, total: 300);

    final rows = await products();
    expect(qtyOf(rows.single), 3.0);
    expect(formatQty(qtyOf(rows.single)), '3');
    expect(revOf(rows.single), 300.0);
  });

  test('decimal quantity survives as 2.5, not 2', () async {
    await seedSale('S-1', total: 250);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 2.5, total: 250);

    final rows = await products();
    expect(qtyOf(rows.single), 2.5);
    expect(formatQty(qtyOf(rows.single)), '2.5');
    // Export cell: a num, so Excel keeps a numeric cell; fractional stays double.
    expect(exportQty(qtyOf(rows.single)), 2.5);
  });

  test('emit-time rounding removes float noise', () async {
    await seedSale('S-1', total: 30);
    // 0.1 + 0.2 is 0.30000000000000004 in binary floating point.
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 0.1, total: 10);
    await seedLine('L-2',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-2', qty: 0.2, total: 20);

    final rows = await products();
    expect(qtyOf(rows.single), 0.3);
    expect(formatQty(qtyOf(rows.single)), '0.3');
  });

  // ── Returns ────────────────────────────────────────────────────────────

  test('sale plus partial return nets the quantity and revenue', () async {
    await seedSale('S-1', total: 400);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 4, total: 400);
    await seedSale('R-1', total: 100, isReturn: true);
    // Return LINES are stored positive; the sale's sign is what nets them.
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-1', variantId: 'V-1', qty: 1, total: 100);

    final rows = await products();
    expect(qtyOf(rows.single), 3.0);
    expect(revOf(rows.single), 300.0);
  });

  test('decimal partial return: 2.5 kg sold, 1 kg back', () async {
    await seedSale('S-1', total: 250);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 2.5, total: 250);
    await seedSale('R-1', total: 100, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-1', variantId: 'V-1', qty: 1, total: 100);

    final rows = await products();
    expect(qtyOf(rows.single), 1.5);
    expect(formatQty(qtyOf(rows.single)), '1.5');
  });

  test('full return zeroes the product row without dropping it', () async {
    await seedSale('S-1', total: 400);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 4, total: 400);
    await seedSale('R-1', total: 400, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1', productId: 'P-1', variantId: 'V-1', qty: 4, total: 400);

    final rows = await products();
    expect(rows.single['productId'], 'P-1');
    expect(qtyOf(rows.single), 0.0);
    expect(revOf(rows.single), 0.0);
  });

  // ── Grouping ───────────────────────────────────────────────────────────

  test('two variants of one product merge in Product-wise, split in Variant-wise',
      () async {
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

    final byProduct = await products();
    expect(byProduct.length, 1);
    expect(qtyOf(byProduct.single), 3.0);
    expect(revOf(byProduct.single), 300.0);

    final byVariant = await variants();
    expect(byVariant.length, 2);
    expect(byVariant.fold<double>(0, (s, r) => s + qtyOf(r)), 3.0);
  });

  test('two products sharing a name stay separate rows', () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-1',
        variantId: 'V-1',
        productName: 'Soap',
        qty: 1,
        total: 100);
    await seedLine('L-2',
        saleId: 'S-1',
        productId: 'P-2',
        variantId: 'V-2',
        productName: 'Soap',
        qty: 2,
        total: 200);

    final rows = await products();
    expect(rows.length, 2, reason: 'grouped by productId, never by name');
    expect(rows.map((r) => r['productId']).toSet(), {'P-1', 'P-2'});
    expect(rows.every((r) => r['productName'] == 'Soap'), isTrue);
  });

  test('a deleted product still reports under its snapshotted name', () async {
    await seedSale('S-1', total: 100);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-GONE',
        variantId: 'V-1',
        productName: 'Discontinued Tea',
        qty: 1,
        total: 100);
    // Never added to the products box — the catalogue row is gone.

    final rows = await products();
    expect(rows.single['productName'], 'Discontinued Tea');
    expect(revOf(rows.single), 100.0);
  });

  test('a null productName reports as Unknown rather than crashing', () async {
    await seedSale('S-1', total: 100);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-1',
        variantId: 'V-1',
        productName: null,
        qty: 1,
        total: 100);

    final rows = await products();
    expect(rows.single['productName'], 'Unknown');
    // The screen's cast must hold for a row built this way.
    expect(rows.single['productName'] as String? ?? 'Unknown', 'Unknown');
  });

  test('a product with no category falls into one Uncategorized bucket',
      () async {
    await seedSale('S-1', total: 300);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 1, total: 100);
    await seedLine('L-2',
        saleId: 'S-1', productId: 'P-2', variantId: 'V-2', qty: 2, total: 200);

    final rows = await categories();
    expect(rows.length, 1);
    expect(rows.single['category'], 'Uncategorized');
    expect(qtyOf(rows.single), 3.0);
    expect(rows.single['productCount'], 2);
  });

  // ── Cross-report parity ────────────────────────────────────────────────

  test('product, variant and category agree on every grand total', () async {
    await seedSale('S-1', total: 660, tax: 60);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-1',
        variantId: 'V-1',
        qty: 2.5,
        total: 275,
        discount: 25,
        tax: 25);
    await seedLine('L-2',
        saleId: 'S-1',
        productId: 'P-2',
        variantId: 'V-2',
        qty: 3,
        total: 385,
        discount: 15,
        tax: 35);
    await seedSale('R-1', total: 110, isReturn: true);
    await seedLine('RL-1',
        saleId: 'R-1',
        productId: 'P-1',
        variantId: 'V-1',
        qty: 1,
        total: 110,
        discount: 10,
        tax: 10);

    final p = await products();
    final v = await variants();
    final c = await categories();

    double sum(List<Map<String, dynamic>> rows, String key) =>
        double.parse(rows
            .fold<double>(0, (s, r) => s + (r[key] as num).toDouble())
            .toStringAsFixed(2));

    for (final key in [
      'totalQuantity',
      'totalRevenue',
      'totalDiscount',
      'totalTax',
    ]) {
      expect(sum(p, key), sum(v, key), reason: '$key: product vs variant');
      expect(sum(p, key), sum(c, key), reason: '$key: product vs category');
    }

    // And the netted values themselves.
    expect(sum(p, 'totalQuantity'), 4.5);
    expect(sum(p, 'totalRevenue'), 550.0);
  });

  // ── Reconciliation against Daily Sales ─────────────────────────────────

  test('Daily header item count equals its Items Sold table (C2)', () async {
    // The Daily screen shows two numbers derived by DIFFERENT paths: the
    // summary card's subtitle comes from the HEADER (`sale.totalItems`, netted
    // by `signedItemCount`), while the Items Sold table beneath it comes from
    // the LINES (`getVariantWiseSalesReport`). They agree because a sale's
    // `totalItems` is written as `lines.fold(qty)` — but nothing enforces that,
    // and the two numbers sit on the same screen. This pins the relationship.
    //
    // Two paths on purpose: this asserts they agree, it does not merge them.

    // 3 pieces + 2.5 kg on one bill → header totalItems 5.5.
    await seedSale('S-1', total: 550, items: 5.5);
    await seedLine('L-1',
        saleId: 'S-1',
        productId: 'P-SOAP',
        variantId: 'V-SOAP',
        productName: 'Soap',
        qty: 3,
        total: 300);
    await seedLine('L-2',
        saleId: 'S-1',
        productId: 'P-RICE',
        variantId: 'V-RICE',
        productName: 'Rice',
        qty: 2.5,
        total: 250);

    // 1 kg of rice comes back. The return header stores totalItems POSITIVE.
    await seedSale('R-1', total: 100, isReturn: true, items: 1);
    await seedLine('RL-1',
        saleId: 'R-1',
        productId: 'P-RICE',
        variantId: 'V-RICE',
        productName: 'Rice',
        qty: 1,
        total: 100);

    final daily = await ReportService().getDailySalesReport(day);
    final items = await ReportService().getVariantWiseSalesReport(
        startDate: windowStart, endDate: windowEnd);

    final headerItems = (daily['totalItems'] as num).toDouble();
    final tableItems = double.parse(items
        .fold<double>(0, (s, r) => s + qtyOf(r))
        .toStringAsFixed(3));

    expect(headerItems, 4.5, reason: '3 + 2.5 sold, 1 returned');
    expect(tableItems, headerItems,
        reason: 'the card subtitle and the table below it must agree');

    // The gross/returned split is header-only, and must not disturb the net.
    expect((daily['grossItems'] as num).toDouble(), 5.5);
    expect((daily['returnedItems'] as num).toDouble(), 1.0);
  });

  test('Product-wise revenue differs from Daily by exactly the round-off',
      () async {
    // Header total includes a 40p rounding; the line total does not.
    await seedSale('S-1', total: 300.40, tax: 0, roundOff: 0.40);
    await seedLine('L-1',
        saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 3, total: 300);

    final daily = await ReportService().getDailySalesReport(day);
    final byProduct = await products();

    final dailyRevenue = (daily['totalRevenue'] as num).toDouble();
    final lineRevenue = byProduct.fold<double>(0, (s, r) => s + revOf(r));
    final roundOff = (daily['totalRoundOff'] as num).toDouble();

    expect(dailyRevenue, 300.40);
    expect(lineRevenue, 300.0);
    // The documented, legitimate gap — round-off lives only on the header and
    // must never be allocated down to lines.
    expect(dailyRevenue - lineRevenue, closeTo(roundOff, 0.001));
  });
}
