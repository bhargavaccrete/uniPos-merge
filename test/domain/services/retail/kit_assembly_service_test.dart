import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/kit_assembly_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';

/// INTEGRATION TESTS — [RetailInventoryService.assembleKit] and
/// [RetailInventoryService.disassembleKit] against real Hive boxes.
///
/// `RetailInventoryService` reaches for `productStore`, `bundleRepository`,
/// `kitAssemblyRepository` and `authService` through the global
/// service-locator getters in `core/di/service_locator.dart` — there is no
/// way to inject substitutes, so real instances are registered into the
/// same GetIt `locator` singleton the app uses, the way
/// `test/integration/repository_integration_test.dart` sets up repositories
/// against real boxes. `HiveInit.openRetailBoxes()` is deliberately NOT used
/// (it early-returns after the first call in a process because of its
/// `_areRetailBoxesOpen` guard, which would leave every later test's boxes
/// closed) — only the specific boxes this service touches are opened here.
void main() {
  late Directory tempDir;
  late ProductStore productStore;
  late BundleRepository bundleRepo;
  late KitAssemblyRepository kitAssemblyRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kit_assembly_service_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles);
    await Hive.openBox<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    await locator.reset();
    productStore = ProductStore();
    bundleRepo = BundleRepository();
    kitAssemblyRepo = KitAssemblyRepository();
    locator.registerSingleton<ProductStore>(productStore);
    locator.registerSingleton<BundleRepository>(bundleRepo);
    locator.registerSingleton<KitAssemblyRepository>(kitAssemblyRepo);
    locator.registerSingleton<AuthService>(AuthService());
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  const now = '2026-01-01T00:00:00.000';

  ProductModel makeKitProduct({String productId = 'kit-prod'}) => ProductModel(
        productId: productId,
        productName: '12-Pack Cola',
        category: 'Beverages',
        hasVariants: false,
        createdAt: now,
        updateAt: now,
        stockMode: 'repack',
      );

  Future<VarianteModel> addVariant({
    required String variantId,
    required String productId,
    int stockQty = 0,
  }) async {
    final variant = VarianteModel(
      varianteId: variantId,
      productId: productId,
      sku: variantId,
      stockQty: stockQty,
      createdAt: now,
      status: 'active',
    );
    await productStore.addVariant(variant);
    return variant;
  }

  /// Sets up: one kit variant + two component variants + a bundle linking
  /// them, ready for assembleKit/disassembleKit.
  Future<void> setUpKit({
    int kitStock = 0,
    int comp1Stock = 100,
    int comp2Stock = 100,
    int comp1QtyPerKit = 2,
    int comp2QtyPerKit = 3,
  }) async {
    await addVariant(variantId: 'kit-v1', productId: 'kit-prod', stockQty: kitStock);
    await addVariant(variantId: 'comp-1', productId: 'comp-prod-1', stockQty: comp1Stock);
    await addVariant(variantId: 'comp-2', productId: 'comp-prod-2', stockQty: comp2Stock);

    await bundleRepo.saveBundle(RetailBundleModel(
      id: 'bundle-1',
      productId: 'kit-prod',
      variantId: 'kit-v1',
      components: [
        BundleComponentModel(componentVariantId: 'comp-1', quantity: comp1QtyPerKit),
        BundleComponentModel(componentVariantId: 'comp-2', quantity: comp2QtyPerKit),
      ],
      createdAt: now,
      updatedAt: now,
    ));
  }

  group('assembleKit', () {
    test('deducts components and credits the kit variant for one batch', () async {
      await setUpKit(kitStock: 0, comp1Stock: 100, comp2Stock: 100);

      final result = await RetailInventoryService.assembleKit(
        kitProduct: makeKitProduct(),
        kitVariantId: 'kit-v1',
        batchQty: 5,
      );

      final kit = await productStore.getVariantById('kit-v1');
      final comp1 = await productStore.getVariantById('comp-1');
      final comp2 = await productStore.getVariantById('comp-2');

      expect(kit!.stockQty, 5, reason: 'kit credited by batchQty');
      expect(comp1!.stockQty, 100 - 2 * 5, reason: 'comp-1 deducted at 2/kit × 5 kits');
      expect(comp2!.stockQty, 100 - 3 * 5, reason: 'comp-2 deducted at 3/kit × 5 kits');

      expect(result.isReversal, isFalse);
      expect(result.batchQty, 5);
      expect(result.bundleId, 'bundle-1');
      expect(result.variantId, 'kit-v1');
      // one movement per component + one for the produced kit variant
      expect(result.movementIds, hasLength(3));
    });

    test('rejects assembly when a component is short, without mutating any stock', () async {
      await setUpKit(kitStock: 0, comp1Stock: 3, comp2Stock: 100, comp1QtyPerKit: 2);
      // Need 2×5=10 of comp-1 but only have 3 — should fail up front.

      await expectLater(
        () => RetailInventoryService.assembleKit(
          kitProduct: makeKitProduct(),
          kitVariantId: 'kit-v1',
          batchQty: 5,
        ),
        throwsA(isA<Exception>()),
      );

      final kit = await productStore.getVariantById('kit-v1');
      final comp1 = await productStore.getVariantById('comp-1');
      final comp2 = await productStore.getVariantById('comp-2');
      expect(kit!.stockQty, 0, reason: 'all-or-nothing: kit stock untouched');
      expect(comp1!.stockQty, 3, reason: 'all-or-nothing: comp-1 stock untouched');
      expect(comp2!.stockQty, 100, reason: 'all-or-nothing: comp-2 stock untouched');
      expect(kitAssemblyRepo.getAllAssemblies(), isEmpty);
    });

    test('rejects a zero or negative batchQty', () async {
      await setUpKit();

      await expectLater(
        () => RetailInventoryService.assembleKit(
          kitProduct: makeKitProduct(),
          kitVariantId: 'kit-v1',
          batchQty: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects assembly for a variant with no bundle configured', () async {
      await addVariant(variantId: 'unconfigured-v1', productId: 'kit-prod', stockQty: 0);

      await expectLater(
        () => RetailInventoryService.assembleKit(
          kitProduct: makeKitProduct(),
          kitVariantId: 'unconfigured-v1',
          batchQty: 1,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('disassembleKit', () {
    test('deducts kit stock and credits each component back for one batch', () async {
      await setUpKit(kitStock: 10, comp1Stock: 20, comp2Stock: 30, comp1QtyPerKit: 2, comp2QtyPerKit: 3);

      await RetailInventoryService.disassembleKit(
        kitProduct: makeKitProduct(),
        kitVariantId: 'kit-v1',
        batchQty: 4,
      );

      final kit = await productStore.getVariantById('kit-v1');
      final comp1 = await productStore.getVariantById('comp-1');
      final comp2 = await productStore.getVariantById('comp-2');

      expect(kit!.stockQty, 10 - 4, reason: 'kit stock consumed by disassembly');
      expect(comp1!.stockQty, 20 + 2 * 4, reason: 'comp-1 restored at 2/kit × 4 kits');
      expect(comp2!.stockQty, 30 + 3 * 4, reason: 'comp-2 restored at 3/kit × 4 kits');
    });

    test('saves an assembly record with isReversal: true and one movement per row', () async {
      await setUpKit(kitStock: 10, comp1Stock: 20, comp2Stock: 30);

      final result = await RetailInventoryService.disassembleKit(
        kitProduct: makeKitProduct(),
        kitVariantId: 'kit-v1',
        batchQty: 2,
      );

      expect(result.isReversal, isTrue);
      expect(result.batchQty, 2);
      expect(result.bundleId, 'bundle-1');
      expect(result.variantId, 'kit-v1');
      // one movement for the consumed kit + one per component (2 components)
      expect(result.movementIds, hasLength(3));

      final persisted = kitAssemblyRepo.getAllAssemblies();
      expect(persisted, hasLength(1));
      expect(persisted.single.id, result.id);
      expect(persisted.single.isReversal, isTrue);
      expect(persisted.single.movementIds, result.movementIds);

      // Every referenced movement id was actually saved.
      final movements = kitAssemblyRepo.getAllAssemblies().single.movementIds;
      final box = Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
      for (final id in movements) {
        expect(box.get(id), isNotNull, reason: 'movement $id must exist');
      }
    });

    test('rejects disassembly when kit stock is insufficient, without mutating any stock', () async {
      await setUpKit(kitStock: 3, comp1Stock: 50, comp2Stock: 50);

      await expectLater(
        () => RetailInventoryService.disassembleKit(
          kitProduct: makeKitProduct(),
          kitVariantId: 'kit-v1',
          batchQty: 5,
        ),
        throwsA(isA<Exception>()),
      );

      final kit = await productStore.getVariantById('kit-v1');
      final comp1 = await productStore.getVariantById('comp-1');
      final comp2 = await productStore.getVariantById('comp-2');
      expect(kit!.stockQty, 3, reason: 'all-or-nothing: kit stock untouched');
      expect(comp1!.stockQty, 50, reason: 'all-or-nothing: comp-1 stock untouched');
      expect(comp2!.stockQty, 50, reason: 'all-or-nothing: comp-2 stock untouched');
      expect(kitAssemblyRepo.getAllAssemblies(), isEmpty);
    });

    test('rejects a zero or negative batchQty', () async {
      await setUpKit(kitStock: 10);

      await expectLater(
        () => RetailInventoryService.disassembleKit(
          kitProduct: makeKitProduct(),
          kitVariantId: 'kit-v1',
          batchQty: -1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects disassembly for a variant with no bundle configured', () async {
      await addVariant(variantId: 'unconfigured-v1', productId: 'kit-prod', stockQty: 10);

      await expectLater(
        () => RetailInventoryService.disassembleKit(
          kitProduct: makeKitProduct(),
          kitVariantId: 'unconfigured-v1',
          batchQty: 1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('assemble then disassemble the same batch returns stock to its starting point', () async {
      await setUpKit(kitStock: 0, comp1Stock: 100, comp2Stock: 100, comp1QtyPerKit: 2, comp2QtyPerKit: 3);

      await RetailInventoryService.assembleKit(
        kitProduct: makeKitProduct(),
        kitVariantId: 'kit-v1',
        batchQty: 6,
      );
      await RetailInventoryService.disassembleKit(
        kitProduct: makeKitProduct(),
        kitVariantId: 'kit-v1',
        batchQty: 6,
      );

      final kit = await productStore.getVariantById('kit-v1');
      final comp1 = await productStore.getVariantById('comp-1');
      final comp2 = await productStore.getVariantById('comp-2');
      expect(kit!.stockQty, 0);
      expect(comp1!.stockQty, 100);
      expect(comp2!.stockQty, 100);

      final history = kitAssemblyRepo.getAssembliesForVariant('kit-v1');
      expect(history, hasLength(2));
      expect(history.where((a) => a.isReversal).length, 1);
      expect(history.where((a) => !a.isReversal).length, 1);
    });
  });
}
