import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
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

/// B-1 — CGST + SGST must reconcile to Total GST.
///
/// Every write path stores the halves as two INDEPENDENTLY rounded copies of
/// `gst / 2` (`SaleItemModel:260`, `GstService:60`,
/// `RetailBillingService:209`). On an odd paisa the two roundings do not close:
/// ₹18.05 stores 9.03 twice, which displayed as ₹18.06 beside a Total GST of
/// ₹18.05 — on the same card, under a divider that reads as a sum.
///
/// Total GST is authoritative. The report now DERIVES the components from it:
/// CGST is the ordinary half, SGST is the residual. Stored data is untouched.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 16);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('gst_split_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
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

  Future<void> seedSale(String saleId,
      {required double total,
      required double tax,
      bool isReturn = false}) async {
    final iso = day.toIso8601String();
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

  /// The stored halves are seeded exactly as the app writes them — two
  /// INDEPENDENTLY rounded copies of `gst / 2`, residual and all.
  double r2(double v) => double.parse(v.toStringAsFixed(2));

  Future<void> seedLine(String id,
      {required String saleId,
      String productId = 'P-1',
      String variantId = 'V-1',
      required double total,
      required double rate,
      required double tax,
      double qty = 1}) async {
    final half = r2(tax / 2);
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      id,
      SaleItemModel(
        saleItemId: id,
        saleId: saleId,
        varianteId: variantId,
        productId: productId,
        productName: 'Product $productId',
        price: total / qty,
        qty: qty,
        total: total,
        discountAmount: 0,
        taxAmount: tax,
        gstRate: rate,
        taxableAmount: total - tax,
        gstAmount: tax,
        cgstAmount: half,
        sgstAmount: half,
      ),
    );
  }

  Future<Map<String, dynamic>> report() => ReportService()
      .getGstSummaryReport(startDate: windowStart, endDate: windowEnd);

  double d(Object? v) => (v as num).toDouble();

  /// Exactly what the screen prints — `toStringAsFixed(2)` on all three.
  void expectDisplayedSplitCloses(
    double cgst,
    double sgst,
    double totalGst, {
    String? reason,
  }) {
    final displayed = r2(cgst + sgst).toStringAsFixed(2);
    expect(displayed, r2(totalGst).toStringAsFixed(2), reason: reason);
  }

  // ── 1. The already-clean case must not move ──────────────────────────────

  test('an even GST is split in half, untouched', () async {
    await seedSale('S-1', total: 118, tax: 18);
    await seedLine('L-1', saleId: 'S-1', total: 118, rate: 18, tax: 18);

    final data = await report();
    expect(d(data['totalCgstAmount']), 9.0);
    expect(d(data['totalSgstAmount']), 9.0);
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });

  // ── 2 & 3. The ₹0.01 mismatch, in both directions ────────────────────────

  test('₹18.05 of GST: stored halves say 18.06, the report says 18.05',
      () async {
    await seedSale('S-1', total: 118.05, tax: 18.05);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);

    // The stored line is the broken pair the bug report describes.
    final stored = Hive.box<SaleItemModel>(HiveBoxNames.saleItems).get('L-1')!;
    expect(stored.cgstAmount, 9.03);
    expect(stored.sgstAmount, 9.03);
    expect(r2(stored.cgstAmount! + stored.sgstAmount!), 18.06);

    final data = await report();
    expect(d(data['totalGstAmount']), closeTo(18.05, 0.001));
    expect(d(data['totalCgstAmount']), 9.03);
    // The residual, deterministically on SGST.
    expect(d(data['totalSgstAmount']), 9.02);
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });

  test('a residual in the other direction lands on SGST too', () async {
    // 12.35 halves to 6.17 + 6.17 = 12.34 — a paisa SHORT, not over.
    await seedSale('S-1', total: 112.35, tax: 12.35);
    await seedLine('L-1', saleId: 'S-1', total: 112.35, rate: 12, tax: 12.35);

    final data = await report();
    expect(d(data['totalCgstAmount']), 6.17);
    expect(d(data['totalSgstAmount']), 6.18);
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });

  test('a sub-paisa-splittable total still closes', () async {
    // ₹0.01 cannot be halved at all: 0.01 + 0.00.
    await seedSale('S-1', total: 100.01, tax: 0.01);
    await seedLine('L-1', saleId: 'S-1', total: 100.01, rate: 0.25, tax: 0.01);

    final data = await report();
    expect(d(data['totalCgstAmount']) + d(data['totalSgstAmount']),
        closeTo(0.01, 0.0001));
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });

  // ── 4. Many lines, where the OLD code drifted furthest ───────────────────

  test('20 odd-paisa lines: the old sum drifts 20 paise, the report does not',
      () async {
    await seedSale('S-1', total: 2401, tax: 361);
    for (var i = 0; i < 20; i++) {
      await seedLine('L-$i',
          saleId: 'S-1',
          variantId: 'V-$i',
          total: 118.05,
          rate: 18,
          tax: 18.05);
    }

    final data = await report();
    // Each stored line is over by a paisa; summing them was over by 20.
    final storedSum = Hive.box<SaleItemModel>(HiveBoxNames.saleItems)
        .values
        .fold<double>(0.0, (s, i) => s + i.cgstAmount! + i.sgstAmount!);
    expect(r2(storedSum), 361.20);

    expect(d(data['totalGstAmount']), closeTo(361.0, 0.001));
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
    expect(d(data['totalCgstAmount']), 180.5);
    expect(d(data['totalSgstAmount']), 180.5);
  });

  test('every By Rate row closes on its own total', () async {
    await seedSale('S-1', total: 500, tax: 42.9);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);
    await seedLine('L-2',
        saleId: 'S-1', variantId: 'V-2', total: 112.35, rate: 12, tax: 12.35);
    await seedLine('L-3',
        saleId: 'S-1', variantId: 'V-3', total: 105.55, rate: 5, tax: 12.5);

    final rows = ((await report())['byRate'] as List)
        .cast<Map<String, dynamic>>();
    expect(rows, hasLength(3));
    for (final row in rows) {
      expectDisplayedSplitCloses(
          d(row['cgst']), d(row['sgst']), d(row['totalGst']),
          reason: 'rate ${row['rate']}');
    }
  });

  test('every By Category band closes on its own total', () async {
    await seedSale('S-1', total: 500, tax: 30.4);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);
    await seedLine('L-2',
        saleId: 'S-1', variantId: 'V-2', total: 112.35, rate: 12, tax: 12.35);

    final bands = ((await report())['byCategory'] as List)
        .cast<Map<String, dynamic>>();
    expect(bands, hasLength(2));
    for (final band in bands) {
      expectDisplayedSplitCloses(
          d(band['cgst']), d(band['sgst']), d(band['totalGst']),
          reason: 'band ${band['categoryName']}');
    }
  });

  // ── 5. Sign ──────────────────────────────────────────────────────────────

  test('a credit note yields two NEGATIVE components that still close',
      () async {
    await seedSale('R-1', total: 118.05, tax: 18.05, isReturn: true);
    await seedLine('L-1', saleId: 'R-1', total: 118.05, rate: 18, tax: 18.05);

    final data = await report();
    expect(d(data['totalGstAmount']), closeTo(-18.05, 0.001));
    expect(d(data['totalCgstAmount']), -9.03);
    expect(d(data['totalSgstAmount']), -9.02);
    expect(d(data['totalCgstAmount']), lessThan(0));
    expect(d(data['totalSgstAmount']), lessThan(0));
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });

  test('a period that nets to zero splits to zero, not to two halves',
      () async {
    await seedSale('S-1', total: 118.05, tax: 18.05);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);
    await seedSale('R-1', total: 118.05, tax: 18.05, isReturn: true);
    await seedLine('L-2',
        saleId: 'R-1', variantId: 'V-2', total: 118.05, rate: 18, tax: 18.05);

    final data = await report();
    expect(d(data['totalGstAmount']), closeTo(0.0, 0.001));
    expect(d(data['totalCgstAmount']), 0.0);
    expect(d(data['totalSgstAmount']), 0.0);
  });

  test('a partly-returned period still closes', () async {
    await seedSale('S-1', total: 236.10, tax: 36.10);
    await seedLine('L-1',
        saleId: 'S-1', qty: 2, total: 236.10, rate: 18, tax: 36.10);
    await seedSale('R-1', total: 118.05, tax: 18.05, isReturn: true);
    await seedLine('L-2',
        saleId: 'R-1', variantId: 'V-2', total: 118.05, rate: 18, tax: 18.05);

    final data = await report();
    expect(d(data['totalGstAmount']), closeTo(18.05, 0.001));
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });

  // ── 6. Total GST is untouched ────────────────────────────────────────────

  test('reconciliation never moves Total GST, taxable or any other figure',
      () async {
    await seedSale('S-1', total: 118.05, tax: 18.05);
    await seedLine('L-1',
        saleId: 'S-1', qty: 2.5, total: 118.05, rate: 18, tax: 18.05);

    final data = await report();
    // The authoritative figures come straight off the lines, as before.
    expect(d(data['totalGstAmount']), closeTo(18.05, 0.001));
    expect(d(data['totalTaxableAmount']), closeTo(100.0, 0.001));
    expect(d(data['totalQuantity']), 2.5);
    expect(data['saleCount'], 1);
    expect(data['lineCount'], 1);

    final row = ((data['byRate'] as List).single) as Map<String, dynamic>;
    expect(d(row['totalGst']), closeTo(18.05, 0.001));
    expect(d(row['taxableAmount']), closeTo(100.0, 0.001));
  });

  test('the stored line data is not rewritten', () async {
    await seedSale('S-1', total: 118.05, tax: 18.05);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);

    await report();

    // Reporting is read-only: the un-reconciled halves are still on disk.
    final stored = Hive.box<SaleItemModel>(HiveBoxNames.saleItems).get('L-1')!;
    expect(stored.cgstAmount, 9.03);
    expect(stored.sgstAmount, 9.03);
    expect(stored.gstAmount, 18.05);
  });

  // ── 7. The invariant, over a spread of awkward totals ────────────────────

  test('CGST + SGST closes on Total GST for every odd-paisa amount', () async {
    const taxes = [
      18.05, 12.35, 5.55, 9.99, 0.05, 0.01, 3.03, 7.77, 100.01, 0.99, 33.33,
    ];
    for (var i = 0; i < taxes.length; i++) {
      final tax = taxes[i];
      await seedSale('S-$i', total: 1000 + tax, tax: tax);
      await seedLine('L-$i',
          saleId: 'S-$i', variantId: 'V-$i', total: 1000 + tax, rate: 18,
          tax: tax);

      final data = await report();
      expectDisplayedSplitCloses(d(data['totalCgstAmount']),
          d(data['totalSgstAmount']), d(data['totalGstAmount']),
          reason: 'after adding tax $tax');
    }
  });

  // ── 8 & 9. Country awareness is unchanged ────────────────────────────────

  test('non-India stores get the same reconciled numbers but show neither',
      () async {
    await seedSale('S-1', total: 118.05, tax: 18.05);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);

    await setCountry('India');
    final india = await report();

    await setCountry('United Kingdom');
    final uk = await report();

    // The FIGURES stay country-independent — that invariant was approved with
    // the country batch and reconciliation must not break it.
    expect(d(uk['totalCgstAmount']), d(india['totalCgstAmount']));
    expect(d(uk['totalSgstAmount']), d(india['totalSgstAmount']));
    expect(d(uk['totalGstAmount']), d(india['totalGstAmount']));

    // What differs is only whether the screen may render them.
    expect(TaxLabelRule.splitsIntoComponents, isFalse);
    expect(TaxLabelRule.components, isNull);
    expect(TaxLabelRule.name, 'VAT');
  });

  test('India still splits, and the labels are unchanged', () async {
    await setCountry('India');
    expect(TaxLabelRule.splitsIntoComponents, isTrue);
    expect(TaxLabelRule.components?.first, 'CGST');
    expect(TaxLabelRule.components?.second, 'SGST');
    expect(TaxLabelRule.name, 'GST');
    expect(TaxLabelRule.reportTitle, 'GST Report');
  });

  test('an unset country keeps the India split', () async {
    await setCountry(null);
    await seedSale('S-1', total: 118.05, tax: 18.05);
    await seedLine('L-1', saleId: 'S-1', total: 118.05, rate: 18, tax: 18.05);

    expect(TaxLabelRule.splitsIntoComponents, isTrue);
    final data = await report();
    expectDisplayedSplitCloses(d(data['totalCgstAmount']),
        d(data['totalSgstAmount']), d(data['totalGstAmount']));
  });
}
