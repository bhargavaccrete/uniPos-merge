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

/// COUNTRY AWARENESS of the tax report — the saved-`BusinessDetails` half of
/// [TaxLabelRule], plus the guarantee that changing country changes only NAMES.
///
/// The bug: the GST report and Checkout hard-coded "GST", "CGST" and "SGST",
/// so a UK shop on 20% VAT was shown two invented sub-taxes of 10% each. The
/// CGST/SGST halves are still WRITTEN in every country (`SaleItemModel` is
/// untouched) — this batch only decides what may be displayed.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 16);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('gst_country_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    // `registerRetailAdapters` covers the retail range only; BusinessDetails is
    // a COMMON adapter (typeId 4) and this is the record the country lives on.
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
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// The one thing these tests vary.
  Future<void> setCountry(String? country) async {
    await businessDetailsRepository.save(
      BusinessDetails(storeName: 'Test Store', country: country),
    );
  }

  Future<void> seedSale(String saleId,
      {required double total, double tax = 0, bool isReturn = false}) async {
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

  /// A line carrying the SAME cgst/sgst halving the app writes everywhere,
  /// regardless of country — that write path is deliberately untouched.
  Future<void> seedLine(String id,
      {required String saleId,
      String productId = 'P-1',
      String variantId = 'V-1',
      required double qty,
      required double total,
      required double rate,
      required double tax}) async {
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      id,
      SaleItemModel(
        saleItemId: id,
        saleId: saleId,
        varianteId: variantId,
        productId: productId,
        productName: 'Widget',
        price: total / qty,
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

  /// One 20%-taxed sale: 120 gross = 100 taxable + 20 tax.
  Future<void> seedStandardPeriod() async {
    await seedSale('S-1', total: 120, tax: 20);
    await seedLine('L-1',
        saleId: 'S-1', qty: 1, total: 120, rate: 20, tax: 20);
  }

  Future<Map<String, dynamic>> report() => ReportService()
      .getGstSummaryReport(startDate: windowStart, endDate: windowEnd);

  // ── Saved-country resolution ─────────────────────────────────────────────

  test('India: name is GST, tax splits, components are CGST/SGST', () async {
    await setCountry('India');
    expect(TaxLabelRule.name, 'GST');
    expect(TaxLabelRule.isIndia, isTrue);
    expect(TaxLabelRule.splitsIntoComponents, isTrue);
    expect(TaxLabelRule.components?.first, 'CGST');
    expect(TaxLabelRule.components?.second, 'SGST');
    expect(TaxLabelRule.reportTitle, 'GST Report');
  });

  test('United Kingdom: name is VAT, no components to show', () async {
    await setCountry('United Kingdom');
    expect(TaxLabelRule.name, 'VAT');
    expect(TaxLabelRule.isIndia, isFalse);
    expect(TaxLabelRule.splitsIntoComponents, isFalse);
    // Null is what stops the screen rendering the stored halves.
    expect(TaxLabelRule.components, isNull);
    expect(TaxLabelRule.reportTitle, 'VAT Report');
  });

  test('United States: name is Sales Tax, no components', () async {
    await setCountry('United States');
    expect(TaxLabelRule.name, 'Sales Tax');
    expect(TaxLabelRule.splitsIntoComponents, isFalse);
    expect(TaxLabelRule.components, isNull);
    expect(TaxLabelRule.reportTitle, 'Sales Tax Report');
  });

  test('an unlisted country: generic Tax, no components', () async {
    await setCountry('Brazil');
    expect(TaxLabelRule.name, 'Tax');
    expect(TaxLabelRule.splitsIntoComponents, isFalse);
    expect(TaxLabelRule.components, isNull);
    expect(TaxLabelRule.reportTitle, 'Tax Report');
  });

  test('an UNSET country falls back to India', () async {
    await setCountry(null);
    expect(TaxLabelRule.name, 'GST');
    expect(TaxLabelRule.splitsIntoComponents, isTrue);
    expect(TaxLabelRule.components?.first, 'CGST');
  });

  test('a blank country falls back to India', () async {
    await setCountry('   ');
    expect(TaxLabelRule.name, 'GST');
    expect(TaxLabelRule.splitsIntoComponents, isTrue);
  });

  test('no saved BusinessDetails at all falls back to India', () async {
    // Nothing written — the record simply does not exist yet.
    expect(TaxLabelRule.name, 'GST');
    expect(TaxLabelRule.splitsIntoComponents, isTrue);
  });

  test('an unregistered repository does not throw', () async {
    // Reached in early boot and in widget tests with no DI. It must read as
    // unset — i.e. India — rather than blowing up a screen.
    await locator.reset();
    expect(TaxLabelRule.name, 'GST');
    expect(TaxLabelRule.splitsIntoComponents, isTrue);
    expect(TaxLabelRule.reportTitle, 'GST Report');
  });

  // ── The figures must not move ────────────────────────────────────────────

  test('every tax total is identical in India, the UK and Brazil', () async {
    await seedStandardPeriod();

    final byCountry = <String, Map<String, dynamic>>{};
    for (final country in ['India', 'United Kingdom', 'Brazil']) {
      await setCountry(country);
      byCountry[country] = await report();
    }

    for (final key in [
      'totalTaxableAmount',
      'totalGstAmount',
      'totalCgstAmount',
      'totalSgstAmount',
      'saleCount',
      'lineCount',
      'returnCount',
    ]) {
      final india = byCountry['India']![key];
      expect(byCountry['United Kingdom']![key], india, reason: key);
      expect(byCountry['Brazil']![key], india, reason: key);
    }

    // And the numbers are the right ones to begin with.
    expect(byCountry['India']!['totalTaxableAmount'], closeTo(100.0, 0.001));
    expect(byCountry['India']!['totalGstAmount'], closeTo(20.0, 0.001));
  });

  test('the cgst/sgst halves are still COMPUTED outside India, just not shown',
      () async {
    await setCountry('United Kingdom');
    await seedStandardPeriod();

    final data = await report();
    // The write path is deliberately untouched, so the report still carries
    // them; it is the SCREEN that is forbidden to render them.
    expect((data['totalCgstAmount'] as num).toDouble(), closeTo(10.0, 0.001));
    expect((data['totalSgstAmount'] as num).toDouble(), closeTo(10.0, 0.001));
    // What the screen actually gates on:
    expect(TaxLabelRule.splitsIntoComponents, isFalse);
  });

  test('per-rate rows carry the same amounts in every country', () async {
    await seedStandardPeriod();

    for (final country in ['India', 'United Kingdom', 'Brazil']) {
      await setCountry(country);
      final rows =
          (await report())['byRate'] as List<Map<String, dynamic>>;
      final row = rows.single;
      expect(row['rate'], 20.0, reason: country);
      expect((row['taxableAmount'] as num).toDouble(),
          closeTo(100.0, 0.001),
          reason: country);
      expect((row['totalGst'] as num).toDouble(), closeTo(20.0, 0.001),
          reason: country);
      expect((row['cgst'] as num).toDouble(), closeTo(10.0, 0.001),
          reason: country);
    }
  });

  test('returns still net down identically in every country', () async {
    await seedStandardPeriod();
    await seedSale('R-1', total: 120, tax: 20, isReturn: true);
    await seedLine('L-2',
        saleId: 'R-1', qty: 1, total: 120, rate: 20, tax: 20);

    for (final country in ['India', 'United Kingdom']) {
      await setCountry(country);
      final data = await report();
      expect((data['totalGstAmount'] as num).toDouble(), closeTo(0.0, 0.001),
          reason: country);
      expect((data['totalTaxableAmount'] as num).toDouble(),
          closeTo(0.0, 0.001),
          reason: country);
    }
  });

  // ── The one generated label ──────────────────────────────────────────────

  test('the rate-band name follows the country, the rate does not', () async {
    await seedStandardPeriod();

    await setCountry('India');
    var band = ((await report())['byCategory'] as List).single
        as Map<String, dynamic>;
    expect(band['categoryName'], 'GST 20% Items');
    expect(band['gstRate'], 20.0);
    final indiaTaxable = (band['taxableAmount'] as num).toDouble();

    await setCountry('United Kingdom');
    band = ((await report())['byCategory'] as List).single
        as Map<String, dynamic>;
    expect(band['categoryName'], 'VAT 20% Items');
    expect(band['gstRate'], 20.0);
    expect((band['taxableAmount'] as num).toDouble(), indiaTaxable);

    await setCountry('United States');
    band = ((await report())['byCategory'] as List).single
        as Map<String, dynamic>;
    expect(band['categoryName'], 'Sales Tax 20% Items');

    await setCountry('Brazil');
    band = ((await report())['byCategory'] as List).single
        as Map<String, dynamic>;
    expect(band['categoryName'], 'Tax 20% Items');
  });

  test('an empty period reports zeros in every country', () async {
    for (final country in ['India', 'United Kingdom', null]) {
      await setCountry(country);
      final data = await report();
      expect((data['totalGstAmount'] as num).toDouble(), 0.0);
      expect(data['byRate'], isEmpty);
      expect(data['byCategory'], isEmpty);
    }
  });
}
