import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOW STOCK ALERT — the one report with no date dimension.
///
/// It had no tests at all. The report reads `productStore.products` — an
/// OBSERVABLE hydrated asynchronously from the store's constructor — while
/// reading variants from the repository, so a cold consumer is reading a list
/// that may still be filling.
///
/// **Honest note on the hydration tests below:** the pre-fix code happened to
/// survive this, because `loadProducts` mutates the list IN PLACE and the
/// report awaits `getAllVariants()` before iterating — so hydration usually
/// lands in that gap. It was correct by accident, not by construction, and the
/// ordering is a microtask race rather than a guarantee. `ensureLoaded()` makes
/// it explicit. These tests therefore pin the CONTRACT — a cold consumer sees
/// the catalogue — rather than reproducing a failure.
void main() {
  // `StockAlertService.getThreshold()` reads SharedPreferences.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final now = DateTime(2026, 4, 15, 10).toIso8601String();

  setUp(() async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({});

    tempDir = await Directory.systemTemp.createTemp('low_stock_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles);

    // ProductStore is registered but deliberately NOT touched in setUp — the
    // report must be the first consumer, which is the cold-start shape.
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<BundleRepository>(() => BundleRepository());
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

  // ── Fixtures — written straight to the boxes, never through the store ────

  Future<void> seedProduct(
    String id, {
    String name = 'Product',
    String? stockMode,
  }) async {
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
      id,
      ProductModel(
        productId: id,
        productName: name,
        category: '',
        hasVariants: false,
        stockMode: stockMode,
        createdAt: now,
        updateAt: now,
      ),
    );
  }

  Future<void> seedVariant(
    String id, {
    required String productId,
    required double stockQty,
    double? minStock,
    double? costPrice,
    double? mrp,
    String? barcode,
    String status = 'active',
  }) async {
    await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
      id,
      VarianteModel(
        varianteId: id,
        productId: productId,
        stockQty: stockQty,
        minStock: minStock,
        costPrice: costPrice,
        mrp: mrp,
        barcode: barcode,
        status: status,
        createdAt: now,
      ),
    );
  }

  Future<void> seedBundle(
    String variantId, {
    required String productId,
    required List<({String variantId, int qty})> components,
  }) async {
    await Hive.box<RetailBundleModel>(HiveBoxNames.bundles).put(
      'B-$variantId',
      RetailBundleModel(
        id: 'B-$variantId',
        productId: productId,
        variantId: variantId,
        components: components
            .map((c) => BundleComponentModel(
                  componentVariantId: c.variantId,
                  quantity: c.qty,
                ))
            .toList(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> report({int threshold = 10}) =>
      ReportService().getLowStockReport(threshold: threshold);

  double stockOf(Map<String, dynamic> row) =>
      (row['currentStock'] as num).toDouble();

  // ── LS-1 — the cold-start race ───────────────────────────────────────────

  group('LS-1 hydration', () {
    test('a cold report sees the catalogue instead of reporting nothing low',
        () async {
      await seedProduct('P-1', name: 'Rice');
      await seedVariant('V-1', productId: 'P-1', stockQty: 2);

      // The report is the FIRST thing to touch ProductStore here, so its
      // observable is still hydrating when the method is entered. The screen
      // renders a SUCCESS state on an empty result — "All products are well
      // stocked" — so an unhydrated read is indistinguishable from good news.
      final rows = await report();
      expect(rows, hasLength(1));
      expect(rows.single['productName'], 'Rice');
    });

    test('a cold report still reports nothing when nothing IS low', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 500);

      // The success state must stay reachable — the fix must not turn an empty
      // result into a false positive either.
      expect(await report(), isEmpty);
    });

    test('a second call after hydration agrees with the first', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 2);

      final cold = await report();
      final warm = await report();
      expect(warm.length, cold.length);
      expect(warm.single['variantId'], cold.single['variantId']);
    });
  });

  // ── Threshold rules (unchanged by this batch — pinned) ───────────────────

  group('reorder point', () {
    test('a variant minStock overrides the global threshold', () async {
      await seedProduct('P-1');
      // Below the global 10, but above its own reorder point of 2.
      await seedVariant('V-1', productId: 'P-1', stockQty: 5, minStock: 2);

      expect(await report(threshold: 10), isEmpty);
    });

    test('a variant minStock flags a row the global threshold would not',
        () async {
      await seedProduct('P-1');
      // Above the global 10, but at its own reorder point of 50.
      await seedVariant('V-1', productId: 'P-1', stockQty: 40, minStock: 50);

      final row = (await report(threshold: 10)).single;
      expect((row['reorderPoint'] as num).toDouble(), 50.0);
    });

    test('the global threshold applies when minStock is null', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 8);

      final row = (await report(threshold: 10)).single;
      expect((row['reorderPoint'] as num).toDouble(), 10.0);
    });

    test('stock EQUAL to the reorder point is flagged', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 10);

      expect(await report(threshold: 10), hasLength(1));
    });

    test('stock one above the reorder point is not flagged', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 11);

      expect(await report(threshold: 10), isEmpty);
    });

    test('the threshold argument is honoured', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 7);

      expect(await report(threshold: 5), isEmpty);
      expect(await report(threshold: 10), hasLength(1));
    });
  });

  // ── LS-4 — one runtime type for reorderPoint ─────────────────────────────

  group('LS-4 reorderPoint type', () {
    test('the global fallback emits a double, not an int', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 2);

      final row = (await report(threshold: 10)).single;
      expect(row['reorderPoint'], isA<double>());
      // The old emission was the `int` 10 — this is what used to render "10"
      // beside another row's "5.0".
      expect(formatQty((row['reorderPoint'] as num).toDouble()), '10');
    });

    test('a variant-level reorder point is the same type', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 1, minStock: 5);

      final row = (await report()).single;
      expect(row['reorderPoint'], isA<double>());
      expect(formatQty((row['reorderPoint'] as num).toDouble()), '5');
    });

    test('both kinds of row report the SAME runtime type in one result',
        () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 1, minStock: 5);
      await seedVariant('V-2', productId: 'P-1', stockQty: 2);

      final rows = await report(threshold: 10);
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row['reorderPoint'], isA<double>(),
            reason: row['variantId'] as String);
      }
    });

    test('a fractional reorder point survives', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 1, minStock: 2.5);

      final row = (await report()).single;
      expect((row['reorderPoint'] as num).toDouble(), 2.5);
      expect(formatQty((row['reorderPoint'] as num).toDouble()), '2.5');
    });
  });

  // ── LS-5 — export formatting ─────────────────────────────────────────────

  group('LS-5 export quantities', () {
    test('a whole quantity exports as an int so the PDF drops the .0',
        () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 3);

      final row = (await report()).single;
      // The raw value stays a double for calculations…
      expect(row['currentStock'], isA<double>());
      // …while the export cell is integral, which is what the PDF stringifies.
      expect(exportQty(stockOf(row)), 3);
      expect(exportQty(stockOf(row)).toString(), '3');
    });

    test('a fractional quantity stays fractional and numeric', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 2.5);

      final row = (await report()).single;
      expect(exportQty(stockOf(row)), 2.5);
      expect(exportQty(stockOf(row)), isA<num>());
    });

    test('the reorder point exports the same way', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 1, minStock: 4);

      final row = (await report()).single;
      expect(exportQty((row['reorderPoint'] as num).toDouble()), 4);
    });
  });

  // ── LS-6 — deterministic order ───────────────────────────────────────────

  group('LS-6 ordering', () {
    test('lowest stock first', () async {
      await seedProduct('P-1');
      await seedVariant('V-HIGH', productId: 'P-1', stockQty: 9);
      await seedVariant('V-LOW', productId: 'P-1', stockQty: 1);
      await seedVariant('V-MID', productId: 'P-1', stockQty: 5);

      expect((await report()).map((r) => r['variantId']).toList(),
          ['V-LOW', 'V-MID', 'V-HIGH']);
    });

    test('equal-stock rows break on variant id, stably', () async {
      await seedProduct('P-1');
      for (final id in ['V-3', 'V-1', 'V-2']) {
        await seedVariant(id, productId: 'P-1', stockQty: 0);
      }

      final first = (await report()).map((r) => r['variantId']).toList();
      expect(first, ['V-1', 'V-2', 'V-3']);
      // It must not drift between loads — the screen and its export read the
      // same list.
      expect((await report()).map((r) => r['variantId']).toList(), first);
      expect((await report()).map((r) => r['variantId']).toList(), first);
    });

    test('the tie-break never overrides the stock order', () async {
      await seedProduct('P-1');
      // 'V-1' sorts first by id but holds more stock.
      await seedVariant('V-1', productId: 'P-1', stockQty: 8);
      await seedVariant('V-9', productId: 'P-1', stockQty: 0);

      expect((await report()).map((r) => r['variantId']).toList(),
          ['V-9', 'V-1']);
    });
  });

  // ── Stock semantics per product type ─────────────────────────────────────

  group('stock mode', () {
    test('a BUNDLE is judged on available-to-sell, not its own stockQty',
        () async {
      await seedProduct('P-KIT', name: 'Gift Box', stockMode: 'bundle');
      // Its own stockQty is deliberately high and meaningless.
      await seedVariant('V-KIT', productId: 'P-KIT', stockQty: 999);

      await seedProduct('P-A');
      await seedProduct('P-B');
      await seedVariant('V-A', productId: 'P-A', stockQty: 100);
      // The scarce component: 6 units at 2 per bundle = 3 bundles sellable.
      await seedVariant('V-B', productId: 'P-B', stockQty: 6);

      await seedBundle('V-KIT', productId: 'P-KIT', components: [
        (variantId: 'V-A', qty: 1),
        (variantId: 'V-B', qty: 2),
      ]);

      final rows = await report(threshold: 10);
      final kit = rows.firstWhere((r) => r['variantId'] == 'V-KIT');
      expect(stockOf(kit), 3.0, reason: 'bounded by the scarcest component');
      expect(kit['isBundle'], isTrue);
      // 999 would never have been flagged at all.
      expect(rows.map((r) => r['variantId']), contains('V-KIT'));
    });

    test('a bundle with no components configured reads as zero', () async {
      await seedProduct('P-KIT', stockMode: 'bundle');
      await seedVariant('V-KIT', productId: 'P-KIT', stockQty: 50);

      final row = (await report()).single;
      expect(stockOf(row), 0.0);
      expect(row['isBundle'], isTrue);
    });

    test('a REPACK/kit variant uses its own stockQty', () async {
      // Unlike a bundle, an assembled kit really does carry stock —
      // `RetailInventoryService.assembleKit` credits it on production.
      await seedProduct('P-RE', name: 'Spice Pack', stockMode: 'repack');
      await seedVariant('V-RE', productId: 'P-RE', stockQty: 4);

      final row = (await report(threshold: 10)).single;
      expect(stockOf(row), 4.0);
      expect(row['isBundle'], isFalse);
    });

    test('a standard product uses its own stockQty', () async {
      await seedProduct('P-1', stockMode: 'standard');
      await seedVariant('V-1', productId: 'P-1', stockQty: 6);

      final row = (await report()).single;
      expect(stockOf(row), 6.0);
      expect(row['isBundle'], isFalse);
    });
  });

  // ── Quantities and edges ─────────────────────────────────────────────────

  group('quantities and edges', () {
    test('a decimal stock of 2.5 survives to the row', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 2.5);

      final row = (await report()).single;
      expect(stockOf(row), 2.5);
      expect(row['currentStock'], isA<double>());
      expect(formatQty(stockOf(row)), '2.5');
    });

    test('zero stock is flagged', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 0);

      expect(stockOf((await report()).single), 0.0);
    });

    test('negative stock is flagged and kept negative', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: -4);

      // Current behaviour, pinned: an oversold variant reports its real
      // figure rather than being clamped to zero.
      expect(stockOf((await report()).single), -4.0);
    });

    test('a product with no variants contributes no rows', () async {
      await seedProduct('P-1');

      // Current behaviour, pinned: it is silently skipped, not reported.
      expect(await report(), isEmpty);
    });

    test('an empty catalogue returns an empty list', () async {
      expect(await report(), isEmpty);
    });
  });

  // ── LS-2 — ONE critical rule, shared with Stock Alerts ───────────────────

  group('LS-2 critical band', () {
    /// The report row the screen and the Stock Alerts card both classify.
    Future<Map<String, dynamic>> rowAt({
      required double stock,
      double? minStock,
      int threshold = 10,
    }) async {
      await Hive.box<VarianteModel>(HiveBoxNames.variants).clear();
      await Hive.box<ProductModel>(HiveBoxNames.products).clear();
      await seedProduct('P-1');
      await seedVariant('V-1',
          productId: 'P-1', stockQty: stock, minStock: minStock);
      return (await report(threshold: threshold)).single;
    }

    test('reorder point 2 → critical at or below 1', () async {
      // ceil(2/3) = 1.
      expect(StockAlertService.isCritical(await rowAt(stock: 1, minStock: 2)),
          isTrue);
      expect(StockAlertService.isCritical(await rowAt(stock: 2, minStock: 2)),
          isFalse,
          reason: 'the old flat `stock <= 3` called this critical forever');
    });

    test('reorder point 10 → critical at or below 4', () async {
      // ceil(10/3) = 4.
      expect(StockAlertService.isCritical(await rowAt(stock: 4, minStock: 10)),
          isTrue);
      expect(StockAlertService.isCritical(await rowAt(stock: 5, minStock: 10)),
          isFalse);
    });

    test('reorder point 30 → critical at or below 10', () async {
      // ceil(30/3) = 10. The old rule left this row amber until it hit 3.
      expect(StockAlertService.isCritical(await rowAt(stock: 10, minStock: 30)),
          isTrue);
      expect(StockAlertService.isCritical(await rowAt(stock: 11, minStock: 30)),
          isFalse);
      expect(StockAlertService.isCritical(await rowAt(stock: 8, minStock: 30)),
          isTrue,
          reason: 'the old `stock <= 3` rule called this merely low');
    });

    test('the critical threshold is capped at the reorder point', () async {
      // A fractional reorder point: ceil(0.5/3) floors to 1, which is ABOVE the
      // reorder point, so the cap pulls it back to 0.5.
      expect(
          StockAlertService.isCritical(await rowAt(stock: 0.5, minStock: 0.5)),
          isTrue);
      // Without the cap, 1 would have been the critical line and this row —
      // which is not even low — could not exist. The cap keeps critical ⊆ low.
      final row = await rowAt(stock: 0.5, minStock: 0.5);
      expect((row['reorderPoint'] as num).toDouble(), 0.5);
    });

    test('the critical threshold never drops below 1', () async {
      // ceil(1/3) = 1 already; the floor matters for reorder points of 2 and 3.
      expect(StockAlertService.isCritical(await rowAt(stock: 1, minStock: 3)),
          isTrue);
      expect(StockAlertService.isCritical(await rowAt(stock: 0, minStock: 1)),
          isTrue);
    });

    test('the LOW boundary is unchanged and still inclusive', () async {
      // A row exactly at its reorder point is low but NOT critical.
      final row = await rowAt(stock: 10, minStock: 10);
      expect(stockOf(row), 10.0);
      expect(StockAlertService.isCritical(row), isFalse);
    });

    test('the Critical count equals the rows the rule classifies critical',
        () async {
      await seedProduct('P-1');
      await seedVariant('V-CRIT', productId: 'P-1', stockQty: 2, minStock: 10);
      await seedVariant('V-LOW', productId: 'P-1', stockQty: 8, minStock: 10);
      await seedVariant('V-ZERO', productId: 'P-1', stockQty: 0, minStock: 10);

      final rows = await report(threshold: 10);
      final critical = rows.where(StockAlertService.isCritical).toList();

      expect(rows, hasLength(3));
      expect(critical.map((r) => r['variantId']).toSet(),
          {'V-CRIT', 'V-ZERO'});
      // The card's number is exactly this count — out-of-stock rows included,
      // matching the Stock Alerts card, where the old `> 0 && <= 3` excluded
      // them.
      expect(critical.length, 2);
    });

    test('row severity uses the same predicate as the count', () async {
      // The screen colours a row red when `isCritical(row)` and amber
      // otherwise; both now read this one function, over the same map.
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 2, minStock: 30);
      await seedVariant('V-2', productId: 'P-1', stockQty: 25, minStock: 30);

      final rows = await report(threshold: 10);
      final byId = {for (final r in rows) r['variantId'] as String: r};
      expect(StockAlertService.isCritical(byId['V-1']!), isTrue);
      expect(StockAlertService.isCritical(byId['V-2']!), isFalse);
      // And the count over the same list agrees with the per-row answers.
      expect(rows.where(StockAlertService.isCritical).length, 1);
    });
  });

  // ── LS-3 — one threshold list, one stored value ──────────────────────────

  group('LS-3 threshold source', () {
    test('the report screen draws its options from the centralized list',
        () async {
      // The screen builds its filter buttons from exactly this list; a second
      // list is what LS-3 removed.
      expect(StockAlertService.thresholdOptions, isNotEmpty);
      expect(StockAlertService.thresholdOptions, contains(15));
      expect(StockAlertService.thresholdOptions, contains(25));
      expect(StockAlertService.thresholdOptions, contains(50));
    });

    test('all six options are available', () async {
      expect(StockAlertService.thresholdOptions, [5, 10, 15, 20, 25, 50]);
    });

    test('the STORED threshold is what the screen seeds its filter with',
        () async {
      SharedPreferences.setMockInitialValues({'stock_alert_threshold': 25});

      // This is the call `initState` now makes; it used to be a hard-coded 10.
      expect(await StockAlertService().getThreshold(), 25);
    });

    test('the default is used when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StockAlertService().getThreshold(),
          StockAlertService.defaultThreshold);
      expect(StockAlertService.defaultThreshold, 10);
    });

    test('changing the selected threshold changes the report', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 22);

      expect(await report(threshold: 5), isEmpty);
      expect(await report(threshold: 20), isEmpty);
      expect(await report(threshold: 25), hasLength(1));
      expect(await report(threshold: 50), hasLength(1));
    });

    test('a variant minStock still overrides the SELECTED global threshold',
        () async {
      await seedProduct('P-1');
      // Well under the selected 50, but above its own reorder point of 2.
      await seedVariant('V-1', productId: 'P-1', stockQty: 5, minStock: 2);

      // Not low at ANY global threshold, because its own reorder point is 2.
      for (final threshold in StockAlertService.thresholdOptions) {
        expect(await report(threshold: threshold), isEmpty,
            reason: 'global threshold $threshold must not override minStock');
      }

      // And the converse: a high minStock flags a row the smallest global
      // threshold would never catch.
      await seedVariant('V-2', productId: 'P-1', stockQty: 80, minStock: 100);
      final row = (await report(threshold: 5))
          .firstWhere((r) => r['variantId'] == 'V-2');
      expect((row['reorderPoint'] as num).toDouble(), 100.0);
    });

    test('a null minStock uses the selected global threshold', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 12);

      expect(await report(threshold: 10), isEmpty);
      final row = (await report(threshold: 15)).single;
      expect((row['reorderPoint'] as num).toDouble(), 15.0);
    });
  });

  // ── LS-7 — a withdrawn variant is not an actionable alert ────────────────

  group('LS-7 inactive variants', () {
    test('a deactivated variant is excluded even at zero stock', () async {
      await seedProduct('P-1');
      await seedVariant('V-DEAD',
          productId: 'P-1', stockQty: 0, status: 'inactive');

      // It can never be reordered, so it would have sat at zero — and raised a
      // low-stock notification — for the life of the store.
      expect(await report(), isEmpty);
    });

    test('an ACTIVE variant at the same stock is still flagged', () async {
      await seedProduct('P-1');
      await seedVariant('V-DEAD',
          productId: 'P-1', stockQty: 0, status: 'inactive');
      await seedVariant('V-LIVE', productId: 'P-1', stockQty: 0);

      expect((await report()).single['variantId'], 'V-LIVE');
    });

    test('deactivating one variant leaves its siblings alone', () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 1);
      await seedVariant('V-2', productId: 'P-1', stockQty: 2,
          status: 'inactive');
      await seedVariant('V-3', productId: 'P-1', stockQty: 3);

      expect((await report()).map((r) => r['variantId']).toList(),
          ['V-1', 'V-3']);
    });

    test('an UNKNOWN status is NOT excluded', () async {
      // `VarianteModel` documents `out_of_stock` as a third value, and an
      // out-of-stock row is the most urgent thing this report shows. The filter
      // is exclusion of an explicit 'inactive', NOT `isSellable`
      // (`status == 'active'`), which would have dropped these.
      await seedProduct('P-1');
      await seedVariant('V-OOS',
          productId: 'P-1', stockQty: 0, status: 'out_of_stock');
      await seedVariant('V-ODD', productId: 'P-1', stockQty: 1, status: '');

      expect((await report()).map((r) => r['variantId']).toSet(),
          {'V-OOS', 'V-ODD'});
    });

    test('an inactive BUNDLE is excluded too', () async {
      await seedProduct('P-KIT', stockMode: 'bundle');
      await seedVariant('V-KIT',
          productId: 'P-KIT', stockQty: 0, status: 'inactive');

      expect(await report(), isEmpty);
    });

    test('a catalogue of only withdrawn variants reports nothing low',
        () async {
      await seedProduct('P-1');
      await seedVariant('V-1', productId: 'P-1', stockQty: 0,
          status: 'inactive');
      await seedVariant('V-2', productId: 'P-1', stockQty: 0,
          status: 'inactive');

      // The screen's success state is correct here: there is nothing to act on.
      expect(await report(), isEmpty);
    });

    test('an inactive variant is excluded at every threshold', () async {
      await seedProduct('P-1');
      await seedVariant('V-DEAD', productId: 'P-1', stockQty: 1,
          status: 'inactive');

      for (final threshold in [5, 10, 15, 20, 25, 50]) {
        expect(await report(threshold: threshold), isEmpty,
            reason: 'threshold $threshold');
      }
    });

    test('an inactive variant with its own minStock is still excluded',
        () async {
      await seedProduct('P-1');
      await seedVariant('V-DEAD',
          productId: 'P-1', stockQty: 1, minStock: 100, status: 'inactive');

      expect(await report(), isEmpty);
    });
  });

  // ── The row contract the screen and export depend on ─────────────────────

  test('every emitted field the screen and export read is intact', () async {
    await seedProduct('P-1', name: 'Basmati Rice');
    await seedVariant('V-1',
        productId: 'P-1',
        stockQty: 2,
        minStock: 5,
        costPrice: 40,
        mrp: 60,
        barcode: '8901234567890');

    final row = (await report()).single;
    expect(row['productId'], 'P-1');
    expect(row['productName'], 'Basmati Rice');
    expect(row['variantId'], 'V-1');
    expect(row['variantLabel'], isA<String>());
    expect(stockOf(row), 2.0);
    expect(row['isBundle'], isFalse);
    expect((row['reorderPoint'] as num).toDouble(), 5.0);
    expect(row['costPrice'], 40.0);
    expect(row['mrp'], 60.0);
    expect(row['barcode'], '8901234567890');
  });

  test('a null cost price stays null rather than becoming zero', () async {
    await seedProduct('P-1');
    await seedVariant('V-1', productId: 'P-1', stockQty: 1);

    // "No cost on record" and "costs nothing" are different facts; the screen
    // renders the first as "—".
    expect((await report()).single['costPrice'], isNull);
  });
}
