import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
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

/// GST REPORT — the B-2…B-7 correctness batch.
///
/// The report had zero tests, which is how six defects survived in the one
/// report a business hands to an accountant: a truncated quantity, rates
/// rendered as their floor (merging 12% and 12.5% into one band), a "Total
/// Items Sold" that counted rows and counted credit notes UP, two tabs listing
/// the same rates in different orders, unstable ranking, and dropped rows that
/// were counted but never shown.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 16);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('gst_report_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    // BusinessDetails is a COMMON adapter (typeId 4); the report reads the
    // country off it for the tax NAME.
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BusinessDetailsAdapter());
    }

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);

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
    locator.registerLazySingleton<BusinessDetailsRepository>(
        () => BusinessDetailsRepository());

    // India, so the fixtures read in the app's default wording. Country
    // behaviour itself is covered by `gst_report_country_test.dart`.
    await businessDetailsRepository
        .save(BusinessDetails(storeName: 'Test Store', country: 'India'));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedSale(
    String saleId, {
    required double total,
    double tax = 0,
    bool isReturn = false,
    DateTime? at,
    String? rawCreatedAt,
  }) async {
    final iso = rawCreatedAt ?? (at ?? day).toIso8601String();
    final signed = isReturn ? -1 : 1;
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: 1,
        subtotal: signed * (total - tax),
        discountAmount: 0,
        taxAmount: signed * tax,
        totalAmount: signed * total,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: isReturn,
        originalSaleId: isReturn ? 'S-1' : null,
        totalTaxableAmount: signed * (total - tax),
        totalGstAmount: signed * tax,
        grandTotal: signed * total,
      ),
    );
  }

  /// A sale LINE. Stored positive, return or not — the sign comes from its sale.
  Future<void> seedLine(
    String id, {
    required String saleId,
    String productId = 'P-1',
    String variantId = 'V-1',
    required double qty,
    required double total,
    required double rate,
    required double tax,
  }) async {
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      id,
      SaleItemModel(
        saleItemId: id,
        saleId: saleId,
        varianteId: variantId,
        productId: productId,
        productName: 'Product $productId',
        price: qty == 0 ? 0 : total / qty,
        qty: qty,
        total: total,
        discountAmount: 0,
        taxAmount: tax,
        gstRate: rate,
        taxableAmount: total - tax,
        gstAmount: tax,
        cgstAmount: tax / 2,
        sgstAmount: tax / 2,
      ),
    );
  }

  Future<Map<String, dynamic>> report() => ReportService()
      .getGstSummaryReport(startDate: windowStart, endDate: windowEnd);

  Future<List<Map<String, dynamic>>> byRate() async =>
      ((await report())['byRate'] as List).cast<Map<String, dynamic>>();
  Future<List<Map<String, dynamic>>> byProduct() async =>
      ((await report())['byProduct'] as List).cast<Map<String, dynamic>>();
  Future<List<Map<String, dynamic>>> byCategory() async =>
      ((await report())['byCategory'] as List).cast<Map<String, dynamic>>();

  // ── B-2 — product quantity is a double, and stays one ────────────────────

  group('B-2 quantity', () {
    test('a decimal quantity survives as 2.5, not 2', () async {
      await seedSale('S-1', total: 118, tax: 18);
      await seedLine('L-1',
          saleId: 'S-1', qty: 2.5, total: 118, rate: 18, tax: 18);

      final row = (await byProduct()).single;
      expect(row['quantity'], isA<double>());
      expect((row['quantity'] as num).toDouble(), 2.5);
      // What the screen used to do — the value is lost, silently.
      expect((row['quantity'] as num).toInt(), 2);
      // What it does now.
      expect(formatQty((row['quantity'] as num).toDouble()), '2.5');
    });

    test('a product sold only in half-kilos no longer reads zero', () async {
      await seedSale('S-1', total: 59, tax: 9);
      await seedLine('L-1',
          saleId: 'S-1', qty: 0.5, total: 59, rate: 18, tax: 9);

      final row = (await byProduct()).single;
      expect((row['quantity'] as num).toDouble(), 0.5);
      expect(formatQty((row['quantity'] as num).toDouble()), '0.5');
    });

    test('a whole quantity renders without a trailing .0', () async {
      await seedSale('S-1', total: 300, tax: 0);
      await seedLine('L-1', saleId: 'S-1', qty: 3, total: 300, rate: 0, tax: 0);

      final row = (await byProduct()).single;
      expect(row['quantity'], isA<double>());
      expect(formatQty((row['quantity'] as num).toDouble()), '3');
    });

    test('quantity nets a return down', () async {
      await seedSale('S-1', total: 300, tax: 0);
      await seedLine('L-1', saleId: 'S-1', qty: 3, total: 300, rate: 0, tax: 0);
      await seedSale('R-1', total: 100, tax: 0, isReturn: true);
      await seedLine('L-2', saleId: 'R-1', qty: 1, total: 100, rate: 0, tax: 0);

      expect(((await byProduct()).single['quantity'] as num).toDouble(), 2.0);
    });
  });

  // ── B-3 — rates are formatted, never floored ─────────────────────────────

  group('B-3 fractional rates', () {
    test('12% and 12.5% stay separate rate rows', () async {
      await seedSale('S-1', total: 224.5, tax: 24.5);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 112, rate: 12, tax: 12);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 112.5,
          rate: 12.5, tax: 12.5);

      final rates =
          (await byRate()).map((r) => r['rate'] as double).toList();
      expect(rates, [12.0, 12.5]);
    });

    test('12% and 12.5% stay separate BANDS, each named for its own rate',
        () async {
      await seedSale('S-1', total: 224.5, tax: 24.5);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 112, rate: 12, tax: 12);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 112.5,
          rate: 12.5, tax: 12.5);

      final bands = await byCategory();
      // The bug: the band key was `rate.toInt()`, so both landed in one "12%"
      // band whose badge showed whichever rate arrived first — while By Rate
      // showed two. One screen, two answers.
      expect(bands.length, 2);
      final names = bands.map((b) => b['categoryName'] as String).toSet();
      expect(names, {'GST 12% Items', 'GST 12.5% Items'});
      expect(bands.map((b) => b['gstRate'] as double).toSet(), {12.0, 12.5});
    });

    test('a sub-1% rate is not floored to 0%', () async {
      // India's schedule includes 0.25%.
      await seedSale('S-1', total: 100.25, tax: 0.25);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 100.25, rate: 0.25, tax: 0.25);

      final band = (await byCategory()).single;
      expect(band['gstRate'], 0.25);
      expect(band['categoryName'], isNot(contains('0% Items')));
    });

    test('each band carries only its own rate amounts', () async {
      await seedSale('S-1', total: 224.5, tax: 24.5);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 112, rate: 12, tax: 12);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 112.5,
          rate: 12.5, tax: 12.5);

      final bands = {
        for (final b in await byCategory()) b['gstRate'] as double: b,
      };
      expect((bands[12.0]!['totalGst'] as num).toDouble(), closeTo(12.0, 0.001));
      expect(
          (bands[12.5]!['totalGst'] as num).toDouble(), closeTo(12.5, 0.001));
    });
  });

  // ── B-4 — units sold, signed ─────────────────────────────────────────────

  group('B-4 units sold', () {
    test('totalQuantity is signed units, while lineCount stays a row count',
        () async {
      await seedSale('S-1', total: 300, tax: 0);
      await seedLine('L-1', saleId: 'S-1', qty: 3, total: 300, rate: 0, tax: 0);
      await seedSale('R-1', total: 300, tax: 0, isReturn: true);
      await seedLine('L-2', saleId: 'R-1', qty: 3, total: 300, rate: 0, tax: 0);

      final data = await report();
      // Fully credited: no units sold on balance.
      expect((data['totalQuantity'] as num).toDouble(), 0.0);
      // `lineCount` counts ROWS and cannot go negative — which is exactly why
      // it was the wrong figure to label "Total Items Sold".
      expect(data['lineCount'], 2);
      expect((data['totalGstAmount'] as num).toDouble(), 0.0);
    });

    test('totalQuantity carries decimals', () async {
      await seedSale('S-1', total: 100, tax: 0);
      await seedLine('L-1',
          saleId: 'S-1', qty: 2.5, total: 100, rate: 0, tax: 0);

      final data = await report();
      expect((data['totalQuantity'] as num).toDouble(), 2.5);
      expect(formatQty((data['totalQuantity'] as num).toDouble()), '2.5');
    });

    test('totalQuantity sums every line of every sale', () async {
      await seedSale('S-1', total: 200, tax: 0);
      await seedLine('L-1', saleId: 'S-1', qty: 1, total: 100, rate: 0, tax: 0);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 4, total: 100, rate: 0, tax: 0);

      expect(((await report())['totalQuantity'] as num).toDouble(), 5.0);
    });
  });

  // ── B-5 / B-6 — one deterministic order, decided in the service ──────────

  group('B-5/B-6 ordering', () {
    test('rates come back ascending regardless of the order they were seen',
        () async {
      await seedSale('S-1', total: 354, tax: 54);
      // Seeded highest-rate first, so insertion order is the wrong order.
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 118, rate: 18, tax: 18);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 105, rate: 5, tax: 5);
      await seedLine('L-3',
          saleId: 'S-1', variantId: 'V-3', qty: 1, total: 112, rate: 12,
          tax: 12);

      expect((await byRate()).map((r) => r['rate']).toList(), [5.0, 12.0, 18.0]);
      // And it does not drift between loads.
      expect((await byRate()).map((r) => r['rate']).toList(), [5.0, 12.0, 18.0]);
    });

    test('products tied on tax break on productId', () async {
      await seedSale('S-1', total: 354, tax: 54);
      for (final id in ['P-3', 'P-1', 'P-2']) {
        await seedLine('L-$id',
            saleId: 'S-1',
            productId: id,
            variantId: 'V-$id',
            qty: 1,
            total: 118,
            rate: 18,
            tax: 18);
      }

      final ids =
          (await byProduct()).map((r) => r['productId'] as String).toList();
      expect(ids, ['P-1', 'P-2', 'P-3']);
      expect((await byProduct()).map((r) => r['productId']).toList(), ids);
    });

    test('products still rank by tax before the tie-break', () async {
      await seedSale('S-1', total: 254, tax: 54);
      await seedLine('L-1',
          saleId: 'S-1', productId: 'P-9', variantId: 'V-9', qty: 1,
          total: 236, rate: 18, tax: 36);
      await seedLine('L-2',
          saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 1,
          total: 118, rate: 18, tax: 18);

      expect((await byProduct()).map((r) => r['productId']).toList(),
          ['P-9', 'P-1']);
    });

    test('bands rank by tax, then by rate', () async {
      await seedSale('S-1', total: 400, tax: 41);
      // 5% band collects more tax than the 18% one.
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 105, rate: 5, tax: 5);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 105, rate: 5, tax: 5);
      await seedLine('L-3',
          saleId: 'S-1', variantId: 'V-3', qty: 1, total: 118, rate: 18,
          tax: 8);

      expect((await byCategory()).map((b) => b['gstRate']).toList(),
          [5.0, 18.0]);
    });
  });

  // ── B-7 — rows dropped from the totals are counted and reportable ────────

  group('B-7 skipped rows', () {
    /// Seeds one readable sale and one whose `createdAt` cannot be parsed.
    Future<void> seedOneUndatedSale() async {
      await seedSale('S-1', total: 118, tax: 18);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 118, rate: 18, tax: 18);
      await seedSale('S-2', total: 118, tax: 18, rawCreatedAt: 'not-a-date');
      await seedLine('L-2',
          saleId: 'S-2', variantId: 'V-2', qty: 1, total: 118, rate: 18,
          tax: 18);
    }

    test('an all-time report counts the undated sale as skipped', () async {
      await seedOneUndatedSale();

      final data = await ReportService().getGstSummaryReport();
      expect(data['skippedRows'], 1);
      // And it really is missing from the figures — which is the whole reason
      // the reader has to be told.
      expect((data['totalGstAmount'] as num).toDouble(), closeTo(18.0, 0.001));
      expect(data['saleCount'], 1);
    });

    test('clean data reports no skipped rows', () async {
      await seedSale('S-1', total: 118, tax: 18);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 118, rate: 18, tax: 18);

      expect((await report())['skippedRows'], 0);
      expect((await ReportService().getGstSummaryReport())['skippedRows'], 0);
    });

    test(
        'KNOWN GAP: a BOUNDED window reports 0 skipped, because the repository '
        'drops the row before the counter sees it', () async {
      await seedOneUndatedSale();

      final data = await report();
      // `_salesInWindow` narrows through `SaleRepository.getSalesByDateRange`
      // when both bounds are given, and that method already discards a row it
      // cannot parse (`sale_repository.dart:46`, `return false`). So the
      // counter can only ever fire on the all-time path — and every report
      // SCREEN passes both bounds.
      //
      // Pinning the CURRENT behaviour, not endorsing it: making the counter
      // work on the bounded path changes six other retail reports that render
      // the same notice, so it belongs to its own approved batch.
      expect(data['skippedRows'], 0);
      // The row is still excluded from the figures either way.
      expect((data['totalGstAmount'] as num).toDouble(), closeTo(18.0, 0.001));
      expect(data['saleCount'], 1);
    });
  });

  // ── Contract checks the batch must not break ─────────────────────────────

  group('totals reconcile', () {
    test('the per-rate rows sum to the headline totals', () async {
      await seedSale('S-1', total: 354, tax: 54);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 118, rate: 18, tax: 18);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 105, rate: 5, tax: 5);
      await seedLine('L-3',
          saleId: 'S-1', variantId: 'V-3', qty: 1, total: 112, rate: 12,
          tax: 12);

      final data = await report();
      final rates = (data['byRate'] as List).cast<Map<String, dynamic>>();
      final gst = rates.fold<double>(
          0.0, (s, r) => s + (r['totalGst'] as num).toDouble());
      final taxable = rates.fold<double>(
          0.0, (s, r) => s + (r['taxableAmount'] as num).toDouble());

      expect(gst, closeTo((data['totalGstAmount'] as num).toDouble(), 0.001));
      expect(taxable,
          closeTo((data['totalTaxableAmount'] as num).toDouble(), 0.001));
    });

    test('the per-product rows sum to the headline taxable', () async {
      await seedSale('S-1', total: 236, tax: 36);
      await seedLine('L-1',
          saleId: 'S-1', productId: 'P-1', variantId: 'V-1', qty: 1,
          total: 118, rate: 18, tax: 18);
      await seedLine('L-2',
          saleId: 'S-1', productId: 'P-2', variantId: 'V-2', qty: 1,
          total: 118, rate: 18, tax: 18);

      final data = await report();
      final taxable = (data['byProduct'] as List)
          .cast<Map<String, dynamic>>()
          .fold<double>(
              0.0, (s, r) => s + (r['taxableAmount'] as num).toDouble());
      expect(taxable,
          closeTo((data['totalTaxableAmount'] as num).toDouble(), 0.001));
    });

    test('avgGstRate is the EFFECTIVE rate, not a mean of rates', () async {
      // One product, two lines at different rates: 100@18% and 300@5%.
      await seedSale('S-1', total: 433, tax: 33);
      await seedLine('L-1',
          saleId: 'S-1', qty: 1, total: 118, rate: 18, tax: 18);
      await seedLine('L-2',
          saleId: 'S-1', variantId: 'V-2', qty: 1, total: 315, rate: 5,
          tax: 15);

      final row = (await byProduct()).single;
      // 33 / 400 = 8.25%. A mean of the two rates would say 11.5%.
      expect((row['avgGstRate'] as num).toDouble(), closeTo(8.25, 0.01));
    });
  });

  group('windows and edges', () {
    test('an empty period returns zeros and empty breakdowns', () async {
      final data = await report();
      expect((data['totalGstAmount'] as num).toDouble(), 0.0);
      expect((data['totalTaxableAmount'] as num).toDouble(), 0.0);
      expect((data['totalQuantity'] as num).toDouble(), 0.0);
      expect(data['lineCount'], 0);
      expect(data['byRate'], isEmpty);
      expect(data['byProduct'], isEmpty);
      expect(data['byCategory'], isEmpty);
    });

    test('the start bound is inclusive and the end bound is exclusive',
        () async {
      await seedSale('S-in', total: 118, tax: 18, at: windowStart);
      await seedLine('L-in',
          saleId: 'S-in', qty: 1, total: 118, rate: 18, tax: 18);
      await seedSale('S-out', total: 118, tax: 18, at: windowEnd);
      await seedLine('L-out',
          saleId: 'S-out', variantId: 'V-2', qty: 1, total: 118, rate: 18,
          tax: 18);

      final data = await report();
      expect(data['saleCount'], 1);
      expect((data['totalGstAmount'] as num).toDouble(), closeTo(18.0, 0.001));
    });

    test('a return alone gives negative tax, not an absent row', () async {
      await seedSale('R-1', total: 118, tax: 18, isReturn: true);
      await seedLine('L-1',
          saleId: 'R-1', qty: 1, total: 118, rate: 18, tax: 18);

      final data = await report();
      expect((data['totalGstAmount'] as num).toDouble(), closeTo(-18.0, 0.001));
      expect((data['totalQuantity'] as num).toDouble(), -1.0);
      expect(data['returnCount'], 1);
      expect((await byRate()).single['rate'], 18.0);
    });
  });
}
