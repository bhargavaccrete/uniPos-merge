import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/common/tax_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/barcode_generator_service.dart';
import 'package:billberrylite/domain/services/retail/retail_import_schema.dart';
import 'package:billberrylite/domain/services/retail/sku_generator_service.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/common/tax_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/presentation/screens/retail/import_product/retail_import_template_builder.dart';
import 'package:billberrylite/stores/import_product/bulk_import_store.dart';

/// WRITE PATH for the retail bulk-product import — the half that needs real
/// Hive boxes. Row shape and validation are pinned separately by the pure
/// `test/domain/services/retail/retail_import_schema_test.dart`.
///
/// These drive `BulkImportStore.importData()` directly rather than through the
/// file picker, so the CSV/XLSX reading is out of scope here; `parsedRows` is
/// seeded with exactly what a parsed sheet looks like.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_import_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    // Repositories branch on the business mode, so it has to be a real retail
    // install rather than an unconfigured one.
    await AppConfig.init();
    await AppConfig.setBusinessMode(BusinessMode.retail);

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<Tax>(HiveBoxNames.tax);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox(HiveBoxNames.appCounters);
    // TaxFeature.enabled reads BusinessDetails, and the importer consults it
    // before touching any tax column.
    await Hive.openBox<BusinessDetails>('businessDetailsBox');

    // The importer reaches the catalogue through these stores, so the graph
    // has to exist. Everything registered here is a plain zero-arg object.
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<CategoryStore>(
      () => CategoryStore(CategoryRepository()),
    );
    locator.registerLazySingleton<TaxStore>(() => TaxStore(TaxRepository()));
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<SkuGeneratorService>(
      () => SkuGeneratorService(),
    );
    locator.registerLazySingleton<LicenseStore>(
      () => LicenseStore(LicenseApiService()),
    );
    locator.registerLazySingleton<BusinessDetailsRepository>(
      () => BusinessDetailsRepository(),
    );

    // No manifest + retail is exactly what PlanEnforce treats as "not
    // licensed yet, stay open". The product-limit group seeds a manifest,
    // which is what turns enforcement on.
    locator<LicenseStore>().licenseBypassed = true;
    Entitlements.instance.clear();
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Fixtures ───────────────────────────────────────────────────────────────

  List<dynamic> row({
    String handle = 'h1',
    String name = 'Product',
    String category = 'General',
    String opt1Name = '',
    String opt1Value = '',
    String cost = '',
    String price = '10',
    String stock = '',
    String barcode = '',
    String minStock = '',
    String sku = '',
    String unit = '',
    String expiry = '',
  }) {
    final cells = List<dynamic>.filled(RetailImportColumn.values.length, '');
    cells[RetailImportColumn.handle.index] = handle;
    cells[RetailImportColumn.name.index] = name;
    cells[RetailImportColumn.category.index] = category;
    cells[RetailImportColumn.option1Name.index] = opt1Name;
    cells[RetailImportColumn.option1Value.index] = opt1Value;
    cells[RetailImportColumn.costPrice.index] = cost;
    cells[RetailImportColumn.sellingPrice.index] = price;
    cells[RetailImportColumn.stock.index] = stock;
    cells[RetailImportColumn.barcode.index] = barcode;
    cells[RetailImportColumn.minStock.index] = minStock;
    cells[RetailImportColumn.sku.index] = sku;
    cells[RetailImportColumn.unit.index] = unit;
    cells[RetailImportColumn.expiryDate.index] = expiry;
    return cells;
  }

  /// Runs a full import over [dataRows] and returns the store, so a test can
  /// read its log and outcome.
  Future<BulkImportStore> importRows(List<List<dynamic>> dataRows) async {
    await productStore.loadProducts();
    await productStore.loadVariants();
    await categoryStore.loadCategories();

    final store = BulkImportStore();
    store.parsedRows.addAll([kRetailImportHeaderRow, ...dataRows]);
    store.preview = RetailImportParser.parse(store.parsedRows.toList());
    await store.importData();
    return store;
  }

  List<VarianteModel> variantsOf(String productName) {
    final product = productStore.products.firstWhere(
      (p) => p.productName == productName,
    );
    return productStore.variantsFor(product.productId);
  }

  // ── B / D / E. Unit, decimal quantity and expiry reach every variant ──────

  group('unit, decimal quantity and expiry are written to every variant', () {
    test('a kg product persists its unit, its decimal flag and fractional '
        'stock', () async {
      await importRows([
        row(
          handle: 'potato',
          name: 'Potato',
          price: '30',
          stock: '10.5',
          unit: 'kg',
        ),
      ]);

      final variant = variantsOf('Potato').single;
      expect(variant.unit, 'kg');
      expect(variant.effectiveUnit, 'kg');
      expect(variant.isDecimalQuantity, isTrue);
      expect(variant.stockQty, 10.5);
      expect(variant.quantityStep, 0.25);
    });

    test(
      'a pcs product stays whole-number, exactly as before this change',
      () async {
        await importRows([
          row(handle: 'coke', name: 'Coke', price: '25', stock: '100'),
        ]);

        final variant = variantsOf('Coke').single;
        expect(variant.isDecimalQuantity, isFalse);
        expect(variant.effectiveUnit, 'piece');
        expect(variant.stockQty, 100);
        expect(variant.formatQuantity(3), '3');
      },
    );

    test(
      'the product-level unit and expiry reach EVERY variant of a group',
      () async {
        await importRows([
          row(
            handle: 'tea',
            name: 'Tea',
            price: '90',
            unit: 'gm',
            expiry: '2027-03-15',
            opt1Name: 'Grade',
            opt1Value: 'A',
          ),
          row(
            handle: 'tea',
            name: 'Tea',
            price: '95',
            opt1Name: 'Grade',
            opt1Value: 'B',
          ),
          row(
            handle: 'tea',
            name: 'Tea',
            price: '99',
            opt1Name: 'Grade',
            opt1Value: 'C',
          ),
        ]);

        final variants = variantsOf('Tea');
        expect(variants, hasLength(3));
        for (final variant in variants) {
          expect(variant.unit, 'gm');
          expect(variant.isDecimalQuantity, isTrue);
          expect(variant.expiryDateTime, DateTime(2027, 3, 15));
        }
      },
    );

    test('an expiry survives the Hive round-trip at local midnight', () async {
      await importRows([
        row(handle: 'milk', name: 'Milk', price: '62', expiry: '2026-12-31'),
      ]);

      // Read back out of the box, not the in-memory list.
      final stored = Hive.box<VarianteModel>(
        HiveBoxNames.variants,
      ).values.firstWhere((v) => v.expiryDate != null);
      expect(stored.expiryDateTime, DateTime(2026, 12, 31));
      expect(stored.hasExpiry, isTrue);
    });

    test('no expiry column means the variant never expires', () async {
      await importRows([row(handle: 'x', name: 'No Expiry')]);
      expect(variantsOf('No Expiry').single.expiryDate, isNull);
    });
  });

  // ── C. Barcode and SKU are minted, not copied ─────────────────────────────

  group('barcode and SKU', () {
    test(
      'a blank barcode is minted by the repository, not left empty',
      () async {
        await importRows([row(handle: 'x', name: 'No Barcode')]);

        final barcode = variantsOf('No Barcode').single.barcode;
        expect(barcode, isNotNull);
        expect(
          BarcodeGeneratorService.isGenerated(barcode),
          isTrue,
          reason: 'expected a BB-prefixed Code 128 value, got "$barcode"',
        );
      },
    );

    test('a supplied barcode is kept exactly as given', () async {
      await importRows([
        row(handle: 'x', name: 'Has Barcode', barcode: '8901234567890'),
      ]);

      expect(variantsOf('Has Barcode').single.barcode, '8901234567890');
      expect(
        BarcodeGeneratorService.isGenerated(
          variantsOf('Has Barcode').single.barcode,
        ),
        isFalse,
      );
    });

    test('generated barcodes are unique across a whole import', () async {
      await importRows([
        row(handle: 'a', name: 'A'),
        row(handle: 'b', name: 'B'),
        row(handle: 'c', name: 'C'),
      ]);

      final codes = Hive.box<VarianteModel>(
        HiveBoxNames.variants,
      ).values.map((v) => v.barcode).toList();
      expect(codes, hasLength(3));
      expect(codes.toSet(), hasLength(3));
    });

    test('SKU is minted when blank and is NOT the barcode', () async {
      await importRows([
        row(handle: 'x', name: 'Auto Sku', category: 'Electronics'),
      ]);

      final variant = variantsOf('Auto Sku').single;
      expect(variant.sku, isNotNull);
      expect(
        variant.sku,
        isNot(variant.barcode),
        reason: 'sku used to be a copy of the barcode',
      );
      expect(variant.sku, matches(RegExp(r'^[A-Z]{3}-\d{6}$')));
    });

    test('a supplied SKU is kept', () async {
      await importRows([row(handle: 'x', name: 'Given Sku', sku: 'MY-SKU-1')]);
      expect(variantsOf('Given Sku').single.sku, 'MY-SKU-1');
    });
  });

  // ── G. Existing product + new variant ─────────────────────────────────────

  group('G — existing product + new variant', () {
    test('variants are appended to the existing product, with no duplicate '
        'product created', () async {
      await importRows([
        row(
          handle: 'ts',
          name: 'V-Neck',
          opt1Name: 'Size',
          opt1Value: 'S',
          barcode: 'TS-S',
        ),
      ]);
      expect(productStore.products, hasLength(1));

      final store = await importRows([
        row(
          handle: 'ts2',
          name: 'V-Neck',
          opt1Name: 'Size',
          opt1Value: 'M',
          barcode: 'TS-M',
        ),
      ]);

      expect(
        productStore.products,
        hasLength(1),
        reason: 'the same name must not create a second product',
      );
      expect(
        variantsOf('V-Neck').map((v) => v.customAttributes?['Size']),
        containsAll(['S', 'M']),
      );
      expect(store.outcome!.productsUpdated, 1);
      expect(store.outcome!.productsCreated, 0);
      expect(store.outcome!.variantsImported, 1);
    });

    test(
      'matching a product name ignores case and surrounding spaces',
      () async {
        await importRows([row(handle: 'a', name: 'Basmati Rice')]);
        await importRows([
          row(
            handle: 'b',
            name: '  basmati rice  ',
            opt1Name: 'Pack',
            opt1Value: '5kg',
          ),
        ]);

        expect(productStore.products, hasLength(1));
        expect(variantsOf('Basmati Rice'), hasLength(2));
      },
    );

    test('a product that gains a second variant becomes variable', () async {
      await importRows([row(handle: 'a', name: 'Grows')]);
      expect(productStore.products.single.isVariable, isFalse);

      await importRows([
        row(handle: 'b', name: 'Grows', opt1Name: 'Size', opt1Value: 'L'),
      ]);

      expect(
        productStore.products.single.isVariable,
        isTrue,
        reason: 'screens branch on isVariable; two variants IS variable',
      );
    });

    test(
      'appended variants inherit the existing product unit, not the file',
      () async {
        await importRows([
          row(handle: 'a', name: 'Loose Dal', unit: 'kg', stock: '5.5'),
        ]);

        final store = await importRows([
          // The file wrongly says piece; the stored kg must win.
          row(
            handle: 'b',
            name: 'Loose Dal',
            unit: 'piece',
            opt1Name: 'Type',
            opt1Value: 'Toor',
          ),
        ]);

        for (final variant in variantsOf('Loose Dal')) {
          expect(variant.effectiveUnit, 'kg');
          expect(variant.isDecimalQuantity, isTrue);
        }
        expect(store.logMessages.join(), contains('already sold in kg'));
      },
    );
  });

  // ── H. Existing product + existing variant ────────────────────────────────

  group('H — existing product + existing variant', () {
    test(
      'an identical variant is skipped and reported, never duplicated',
      () async {
        await importRows([
          row(
            handle: 'ts',
            name: 'V-Neck',
            opt1Name: 'Size',
            opt1Value: 'S',
            barcode: 'TS-S',
          ),
        ]);

        final store = await importRows([
          row(handle: 'ts', name: 'V-Neck', opt1Name: 'Size', opt1Value: 'S'),
        ]);

        expect(variantsOf('V-Neck'), hasLength(1));
        expect(store.outcome!.variantsSkipped, 1);
        expect(store.outcome!.variantsImported, 0);
        expect(store.logMessages.join(), contains('already exists'));
      },
    );

    test(
      're-importing the very same file twice is a no-op the second time',
      () async {
        final rows = [
          row(
            handle: 'ts',
            name: 'Tee',
            opt1Name: 'Size',
            opt1Value: 'S',
            barcode: 'B-S',
          ),
          row(
            handle: 'ts',
            name: 'Tee',
            opt1Name: 'Size',
            opt1Value: 'M',
            barcode: 'B-M',
          ),
        ];

        await importRows(rows);
        final before = Hive.box<VarianteModel>(HiveBoxNames.variants).length;

        // Same attributes, fresh barcodes — the barcodes in the file are already
        // taken by the first import, so re-use blank ones here.
        final store = await importRows([
          row(handle: 'ts', name: 'Tee', opt1Name: 'Size', opt1Value: 'S'),
          row(handle: 'ts', name: 'Tee', opt1Name: 'Size', opt1Value: 'M'),
        ]);

        expect(productStore.products, hasLength(1));
        expect(Hive.box<VarianteModel>(HiveBoxNames.variants).length, before);
        expect(store.outcome!.variantsSkipped, 2);
      },
    );
  });

  // ── D2. No orphan products ────────────────────────────────────────────────

  group('partial writes are rolled back', () {
    test(
      'a group whose second variant is refused leaves NO product behind',
      () async {
        // Park the barcode on an unrelated product first, so the second row of
        // the group is refused at write time (the parser sees it too, but this
        // pins the write-path guard itself).
        await importRows([
          row(handle: 'other', name: 'Other', barcode: 'CLASH'),
        ]);
        final productsBefore = productStore.products.length;

        await productStore.loadProducts();
        await productStore.loadVariants();

        final store = BulkImportStore();
        store.parsedRows.addAll([
          kRetailImportHeaderRow,
          row(handle: 'g', name: 'Rollback Me', opt1Name: 'S', opt1Value: 'A'),
          row(
            handle: 'g',
            name: 'Rollback Me',
            opt1Name: 'S',
            opt1Value: 'B',
            barcode: 'CLASH',
          ),
        ]);
        // Parse WITHOUT the catalogue so the clash is only caught at write time
        // — which is exactly the concurrent-write case the rollback exists for.
        store.preview = RetailImportParser.parse(store.parsedRows.toList());
        await store.importData();

        expect(store.outcome!.groupsFailed, 1);
        expect(
          productStore.products,
          hasLength(productsBefore),
          reason: 'a half-written product is worse than none',
        );
        expect(
          productStore.products.any((p) => p.productName == 'Rollback Me'),
          isFalse,
        );
        expect(
          Hive.box<VarianteModel>(
            HiveBoxNames.variants,
          ).values.any((v) => v.customAttributes?['S'] == 'A'),
          isFalse,
          reason: 'the first variant of the group must be rolled back too',
        );
        expect(store.logMessages.join(), contains('Rollback Me'));
      },
    );

    test('a refused append leaves the original product and its variants '
        'untouched', () async {
      await importRows([row(handle: 'o', name: 'Other', barcode: 'TAKEN2')]);
      await importRows([
        row(handle: 'p', name: 'Keeper', opt1Name: 'S', opt1Value: 'A'),
      ]);

      await productStore.loadProducts();
      await productStore.loadVariants();

      final store = BulkImportStore();
      store.parsedRows.addAll([
        kRetailImportHeaderRow,
        row(
          handle: 'p',
          name: 'Keeper',
          opt1Name: 'S',
          opt1Value: 'B',
          barcode: 'TAKEN2',
        ),
      ]);
      store.preview = RetailImportParser.parse(store.parsedRows.toList());
      await store.importData();

      expect(store.outcome!.groupsFailed, 1);
      expect(
        variantsOf('Keeper'),
        hasLength(1),
        reason: 'the pre-existing variant must survive',
      );
      expect(variantsOf('Keeper').single.customAttributes?['S'], 'A');
    });
  });

  // ── I / J. Rejected rows never reach the box ──────────────────────────────

  group('I/J — invalid rows', () {
    test('an invalid row is reported and its product is not written', () async {
      final store = await importRows([
        row(handle: 'good', name: 'Good', price: '10'),
        row(handle: 'bad', name: 'Bad', price: 'not a number'),
      ]);

      expect(productStore.products.map((p) => p.productName), ['Good']);
      expect(store.outcome!.rowsRejected, 1);
      expect(store.outcome!.productsCreated, 1);
      expect(store.logMessages.join(), contains('Row 3'));
    });

    test(
      'a blank Handle is reported in the log, not silently dropped',
      () async {
        final store = await importRows([
          row(handle: '', name: 'Orphan'),
          row(handle: 'ok', name: 'Kept'),
        ]);

        expect(productStore.products.map((p) => p.productName), ['Kept']);
        expect(store.logMessages.join(), contains('Handle is required'));
      },
    );

    test('counts add up and are all reported', () async {
      final store = await importRows([
        row(handle: 'a', name: 'A'),
        row(handle: 'b', name: 'B', opt1Name: 'S', opt1Value: 'x'),
        row(handle: 'b', name: 'B', opt1Name: 'S', opt1Value: 'y'),
        row(handle: 'c', name: 'C', price: 'bad'),
      ]);

      final outcome = store.outcome!;
      expect(outcome.productsCreated, 2);
      expect(outcome.variantsImported, 3);
      expect(outcome.rowsRejected, 1);
      expect(outcome.hadProblems, isTrue);
    });
  });

  // ── K. Categories and legacy files ────────────────────────────────────────

  group('K — unchanged behaviour', () {
    test('a missing category is auto-created, as before', () async {
      await importRows([
        row(handle: 'a', name: 'A', category: 'Brand New Category'),
      ]);

      expect(
        categoryStore.categories.any((c) => c.name == 'Brand New Category'),
        isTrue,
      );
    });

    test('a blank category lands in Uncategorized, as before', () async {
      await importRows([row(handle: 'a', name: 'A', category: '')]);

      final product = productStore.products.single;
      final category = categoryStore.categories.firstWhere(
        (c) => c.id == product.category,
      );
      expect(category.name, 'Uncategorized');
    });

    test('two products in the same category share one Category row', () async {
      await importRows([
        row(handle: 'a', name: 'A', category: 'Snacks'),
        row(handle: 'b', name: 'B', category: 'snacks'),
      ]);

      expect(
        categoryStore.categories.where((c) => c.name == 'Snacks'),
        hasLength(1),
      );
    });

    test(
      'a legacy 18-column file still imports, as piece with no expiry',
      () async {
        await productStore.loadProducts();
        await productStore.loadVariants();
        await categoryStore.loadCategories();

        final store = BulkImportStore();
        store.parsedRows.addAll([
          const [
            'Handle*',
            'Name*',
            'Category*',
            'Description',
            'Option1 Name',
            'Option1 Value',
            'Option2 Name',
            'Option2 Value',
            'Option3 Name',
            'Option3 Value',
            'Cost Price',
            'Selling Price*',
            'MRP',
            'Stock',
            'Barcode',
            'Min Stock',
            'Tax Rate',
            'HSN Code',
          ],
          const [
            'sock',
            'Cotton Socks',
            'Clothing',
            'Comfy',
            'Size',
            'S',
            '',
            '',
            '',
            '',
            '2.00',
            '6.00',
            '7.00',
            '30',
            'SOCK-S',
            '5',
            '',
            '',
          ],
        ]);
        store.preview = RetailImportParser.parse(store.parsedRows.toList());
        await store.importData();

        expect(store.outcome!.productsCreated, 1);
        final variant = variantsOf('Cotton Socks').single;
        expect(variant.effectiveUnit, 'piece');
        expect(variant.isDecimalQuantity, isFalse);
        expect(variant.expiryDate, isNull);
        expect(variant.barcode, 'SOCK-S');
        expect(variant.sellingPrice, 6.0);
        expect(variant.costPrice, 2.0);
        expect(variant.stockQty, 30);
        expect(variant.customAttributes, {'Size': 'S'});
        // The one legacy behaviour that deliberately changed.
        expect(variant.sku, isNot('SOCK-S'));
      },
    );
  });

  // ── D7. The plan's product cap is enforced ────────────────────────────────

  group('the product limit is not bypassed', () {
    /// Loads a manifest granting the catalog but capping products at [max].
    void seedPlan({required int max}) {
      locator<LicenseStore>().licenseBypassed = false;
      Entitlements.instance.loadFromManifest(
        ManifestData(
          entitlements: {
            RetailEntKeys.catalog: true,
            RetailEntKeys.catalogProductsAdd: true,
            RetailEntKeys.catalogProductsMax: max,
          },
          license: const {'status': 2},
          version: 1,
        ),
      );
    }

    test('import stops creating products once the cap is reached', () async {
      seedPlan(max: 2);

      final store = await importRows([
        row(handle: 'a', name: 'A'),
        row(handle: 'b', name: 'B'),
        row(handle: 'c', name: 'C'),
        row(handle: 'd', name: 'D'),
      ]);

      expect(
        productStore.products,
        hasLength(2),
        reason: 'bulk import must respect the same cap as Add Product',
      );
      expect(store.outcome!.productsCreated, 2);
      expect(store.outcome!.productsBlockedByLimit, 2);
      expect(store.logMessages.join(), contains('Product limit reached'));
    });

    test(
      'adding a variant to an existing product is still allowed at the cap',
      () async {
        seedPlan(max: 1);

        await importRows([row(handle: 'a', name: 'Only One')]);
        expect(productStore.products, hasLength(1));

        final store = await importRows([
          row(handle: 'b', name: 'Only One', opt1Name: 'Size', opt1Value: 'L'),
          row(handle: 'c', name: 'A Second Product'),
        ]);

        expect(
          variantsOf('Only One'),
          hasLength(2),
          reason: 'appending a variant creates no product, so the cap is moot',
        );
        expect(productStore.products, hasLength(1));
        expect(store.outcome!.productsBlockedByLimit, 1);
      },
    );
  });

  // ── The template the shop actually downloads ──────────────────────────────

  group('the downloaded template round-trips through the parser', () {
    /// Reads the Products sheet through the SAME code the app uses, so this
    /// covers the real xlsio-write → excel-read hop, not a re-implementation.
    List<List<dynamic>> productsSheetOf(List<int> bytes) =>
        RetailImportFileReader.excelRows(Uint8List.fromList(bytes));

    test('the xlsio-written workbook is readable by the excel package and its '
        'sample rows all validate', () async {
      await categoryStore.loadCategories();
      await taxStore.loadTaxes();

      final rows = productsSheetOf(RetailImportTemplateBuilder().build());

      // Header row must be exactly what the parser expects.
      expect(
        rows.first
            .take(RetailImportColumn.values.length)
            .map((c) => c.toString()),
        kRetailImportHeaderRow,
      );

      final parsed = RetailImportParser.parse(rows);

      expect(
        parsed.errors,
        isEmpty,
        reason: parsed.errors.map((e) => e.toString()).join(' | '),
      );
      // The yellow instruction row must be recognised, not imported.
      expect(
        parsed.groups.map((g) => g.name),
        isNot(contains('Product name (on the first row of each group)')),
      );
      expect(parsed.groups.map((g) => g.handle), [
        'coke_can',
        'bt_earbuds',
        'potato',
        'milk_1l',
        'cotton_socks',
        'tshirt_vneck',
      ]);
    });

    test('the sample rows demonstrate every new column', () async {
      await categoryStore.loadCategories();
      await taxStore.loadTaxes();

      final parsed = RetailImportParser.parse(
        productsSheetOf(RetailImportTemplateBuilder().build()),
      );
      final byHandle = {for (final g in parsed.groups) g.handle: g};

      // A loose/weighed sample with fractional stock.
      final potato = byHandle['potato']!;
      expect(potato.unit, 'kg');
      expect(potato.isDecimalQuantity, isTrue);
      expect(potato.variants.single.stockQty, 12.5);

      // A perishable sample.
      expect(byHandle['milk_1l']!.expiryDate, isNotNull);
      expect(
        DateTime.parse(byHandle['milk_1l']!.expiryDate!),
        DateTime(2026, 12, 31),
      );

      // A SKU sample, and a sample deliberately left blank to be generated.
      expect(byHandle['bt_earbuds']!.variants.single.sku, 'ELE-000101');
      expect(byHandle['coke_can']!.variants.single.sku, isNull);
      expect(byHandle['coke_can']!.variants.single.barcode, isNull);

      // Multi-variant samples still group correctly.
      expect(byHandle['cotton_socks']!.variants, hasLength(3));
      expect(byHandle['tshirt_vneck']!.variants, hasLength(4));
      expect(byHandle['tshirt_vneck']!.hsnCode, '6109');
      // Unit set on the parent row only still applies to the whole group.
      expect(byHandle['tshirt_vneck']!.unit, 'piece');
    });

    test('the template imports end to end with no errors', () async {
      await categoryStore.loadCategories();
      await taxStore.loadTaxes();

      final rows = productsSheetOf(RetailImportTemplateBuilder().build());
      await productStore.loadProducts();
      await productStore.loadVariants();

      final store = BulkImportStore();
      store.parsedRows.addAll(rows);
      store.preview = RetailImportParser.parse(store.parsedRows.toList());
      await store.importData();

      expect(store.outcome!.productsCreated, 6);
      expect(store.outcome!.variantsImported, 11);
      expect(store.outcome!.rowsRejected, 0);
      expect(store.outcome!.groupsFailed, 0);

      // The weighed sample really is decimal once stored.
      final potato = variantsOf('Potato (Loose)').single;
      expect(potato.isDecimalQuantity, isTrue);
      expect(potato.stockQty, 12.5);
      // The perishable sample really carries its date.
      expect(
        variantsOf('Full Cream Milk 1L').single.expiryDateTime,
        DateTime(2026, 12, 31),
      );
    });
  });

  // ── CSV is read by the same parser as XLSX ───────────────────────────────

  group('CSV', () {
    /// Serialises rows to CSV bytes the way a shop's spreadsheet export would,
    /// then reads them back through the app's own reader.
    List<List<dynamic>> roundTrip(List<List<dynamic>> rows) {
      final text = const ListToCsvConverter().convert(rows);
      return RetailImportFileReader.csvRows(
        Uint8List.fromList(utf8.encode(text)),
      );
    }

    test('a CSV file produces the same groups as the equivalent sheet', () {
      final rows = roundTrip([
        kRetailImportHeaderRow,
        row(
          handle: 'potato',
          name: 'Potato',
          price: '30',
          stock: '10.5',
          unit: 'kg',
          expiry: '2027-01-31',
        ),
        row(
          handle: 'ts',
          name: 'Tee',
          price: '15',
          opt1Name: 'Size',
          opt1Value: 'S',
        ),
        row(
          handle: 'ts',
          name: 'Tee',
          price: '15',
          opt1Name: 'Size',
          opt1Value: 'M',
        ),
      ]);

      final parsed = RetailImportParser.parse(rows);
      expect(
        parsed.errors,
        isEmpty,
        reason: parsed.errors.map((e) => e.toString()).join(' | '),
      );
      expect(parsed.groups, hasLength(2));
      expect(parsed.groups.first.unit, 'kg');
      expect(parsed.groups.first.isDecimalQuantity, isTrue);
      expect(
        DateTime.parse(parsed.groups.first.expiryDate!),
        DateTime(2027, 1, 31),
      );
      expect(parsed.groups.last.variants, hasLength(2));
    });

    test('a value containing a comma survives quoting', () {
      final rows = roundTrip([
        kRetailImportHeaderRow,
        row(handle: 'h', name: 'Rice, Basmati', price: '90'),
      ]);

      expect(
        RetailImportParser.parse(rows).groups.single.name,
        'Rice, Basmati',
      );
    });

    test('blank lines in the file are ignored', () {
      final text =
          '${const ListToCsvConverter().convert([kRetailImportHeaderRow, row(handle: 'h', name: 'Only One')])}\r\n\r\n';
      final rows = RetailImportFileReader.csvRows(
        Uint8List.fromList(utf8.encode(text)),
      );

      final parsed = RetailImportParser.parse(rows);
      expect(parsed.dataRowCount, 1);
      expect(parsed.groups.single.name, 'Only One');
    });

    test('a CSV import writes the same records an XLSX one would', () async {
      final rows = roundTrip([
        kRetailImportHeaderRow,
        row(
          handle: 'potato',
          name: 'Potato',
          price: '30',
          stock: '2.25',
          unit: 'kg',
        ),
      ]);

      await productStore.loadProducts();
      await productStore.loadVariants();
      await categoryStore.loadCategories();

      final store = BulkImportStore();
      store.parsedRows.addAll(rows);
      store.preview = RetailImportParser.parse(store.parsedRows.toList());
      await store.importData();

      expect(store.outcome!.productsCreated, 1);
      final variant = variantsOf('Potato').single;
      expect(variant.unit, 'kg');
      expect(variant.isDecimalQuantity, isTrue);
      expect(variant.stockQty, 2.25);
    });
  });

  // ── The pure split helper, exercised against real stored variants ─────────

  test(
    'splitAgainstExisting agrees with what is actually in the box',
    () async {
      await importRows([
        row(handle: 'ts', name: 'Tee', opt1Name: 'Size', opt1Value: 'S'),
        row(handle: 'ts', name: 'Tee', opt1Name: 'Size', opt1Value: 'M'),
      ]);

      final existingKeys = variantsOf(
        'Tee',
      ).map((v) => attributeSignature(v.customAttributes)).toSet();

      final parsed = RetailImportParser.parse([
        kRetailImportHeaderRow,
        row(handle: 'ts', name: 'Tee', opt1Name: 'Size', opt1Value: 'M'),
        row(handle: 'ts', name: 'Tee', opt1Name: 'Size', opt1Value: 'XL'),
      ]);

      final split = splitAgainstExisting(parsed.groups.single, existingKeys);
      expect(split.toCreate.map((v) => v.attributes['Size']), ['XL']);
      expect(split.alreadyPresent.map((v) => v.attributes['Size']), ['M']);
    },
  );
}
