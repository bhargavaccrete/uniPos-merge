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
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';

/// Bundle stock rules (R-05/06/07 in docs/modules/retail_inventory.md):
/// a bundle's sellable quantity comes from its components, an unconfigured
/// bundle is never sellable, and a bundle return restores its components.
/// Same real-Hive + locator setup as `kit_assembly_service_test.dart`.
void main() {
  late Directory tempDir;
  late ProductStore productStore;
  late BundleRepository bundleRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bundle_stock_');
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
    locator.registerSingleton<ProductStore>(productStore);
    locator.registerSingleton<BundleRepository>(bundleRepo);
    locator.registerSingleton<AuthService>(AuthService());
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const now = '2026-01-01T00:00:00.000';

  Future<ProductModel> addProduct(String id, {String? stockMode}) async {
    final p = ProductModel(
      productId: id,
      productName: id,
      category: '',
      hasVariants: false,
      createdAt: now,
      updateAt: now,
      stockMode: stockMode,
    );
    await productStore.addProduct(p);
    return p;
  }

  Future<VarianteModel> addVariant(String id, String productId, double stock) async {
    final v = VarianteModel(
      varianteId: id,
      productId: productId,
      sku: id,
      stockQty: stock,
      createdAt: now,
      status: 'active',
    );
    await productStore.addVariant(v);
    return v;
  }

  Future<double> stockOf(String variantId) async =>
      (await productStore.getVariantById(variantId))!.stockQty;

  List<StockMovementModel> movements() =>
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
          .values
          .toList();

  /// Combo = 1 × mug + 2 × tea. The combo variant's own stock is a typed
  /// figure that must never matter.
  Future<(ProductModel, VarianteModel)> setUpCombo({
    double comboOwnStock = 0,
    double mugStock = 10,
    double teaStock = 10,
    bool configured = true,
  }) async {
    await addProduct('mug');
    await addProduct('tea');
    await addVariant('mug-v', 'mug', mugStock);
    await addVariant('tea-v', 'tea', teaStock);
    final combo = await addProduct('combo', stockMode: 'bundle');
    final comboVariant = await addVariant('combo-v', 'combo', comboOwnStock);
    if (configured) {
      await bundleRepo.saveBundle(RetailBundleModel(
        id: 'b1',
        productId: 'combo',
        variantId: 'combo-v',
        components: [
          BundleComponentModel(componentVariantId: 'mug-v', quantity: 1),
          BundleComponentModel(componentVariantId: 'tea-v', quantity: 2),
        ],
        createdAt: now,
        updatedAt: now,
      ));
    }
    return (combo, comboVariant);
  }

  group('R-05 availability comes from components', () {
    test('own stock 0 but components on hand → sellable', () async {
      final (combo, v) = await setUpCombo(comboOwnStock: 0, mugStock: 10, teaStock: 10);
      expect(RetailInventoryService.calculateAvailableToSell(combo, v), 5);
    });

    test('own stock 100 but a component at 0 → not sellable', () async {
      final (combo, v) = await setUpCombo(comboOwnStock: 100, mugStock: 0);
      expect(RetailInventoryService.calculateAvailableToSell(combo, v), 0);
    });

    test('product total for the POS tile uses component availability', () async {
      final (combo, v) = await setUpCombo(comboOwnStock: 0, mugStock: 3, teaStock: 10);
      expect(RetailInventoryService.totalAvailableToSell(combo, [v]), 3);
    });
  });

  group('R-10 stock history for silent writers', () {
    test('a new variant with stock logs Opening stock', () async {
      await addProduct('mug');
      await addVariant('mug-v', 'mug', 7);

      final row = movements().single;
      expect(row.reason, 'Opening stock');
      expect((row.type, row.quantity, row.balanceAfter), ('in', 7.0, 7.0));
    });

    test('a new variant with zero stock logs nothing', () async {
      await addProduct('mug');
      await addVariant('mug-v', 'mug', 0);
      expect(movements(), isEmpty);
    });

    test('a whole-record save that changes stock logs the difference', () async {
      await addProduct('mug');
      final v = await addVariant('mug-v', 'mug', 10);

      await productStore.updateVariant(v.copyWith(stockQty: 6));

      final edit = movements().where((m) => m.reason == 'Stock edited').single;
      expect((edit.type, edit.quantity, edit.balanceAfter), ('out', 4.0, 6.0));
    });

    test('a save that leaves stock alone logs nothing', () async {
      await addProduct('mug');
      final v = await addVariant('mug-v', 'mug', 10);

      await productStore.updateVariant(v.copyWith(mrp: 99));

      expect(movements().where((m) => m.reason == 'Stock edited'), isEmpty);
    });
  });

  group('R-11 selling past zero is not clamped', () {
    CartItemModel line(String productId, String variantId, double qty) =>
        CartItemModel.create(
          cartItemId: 'c-$variantId',
          variantId: variantId,
          productId: productId,
          productName: productId,
          price: 10,
          qty: qty,
        );

    test('sell 5 with 2 on the shelf → -3, and the row reconciles', () async {
      await addProduct('mug');
      await addVariant('mug-v', 'mug', 2);

      await RetailInventoryService.deductStockForSale([line('mug', 'mug-v', 5)]);

      expect(await stockOf('mug-v'), -3);
      final sale = movements().singleWhere((m) => m.reason == 'Sale');
      expect((sale.quantity, sale.balanceAfter), (5.0, -3.0));
      expect(sale.balanceAfter + sale.quantity, 2,
          reason: 'before = after + qty — the shortfall is not lost');
    });

    test('a bundle sale drives a short component negative', () async {
      await setUpCombo(mugStock: 1, teaStock: 10);

      await RetailInventoryService.deductStockForSale([line('combo', 'combo-v', 2)]);

      expect(await stockOf('mug-v'), -1);
      expect(await stockOf('tea-v'), 6);
    });

    test('R-14 re-running a sale\'s deduction applies it once', () async {
      await addProduct('mug');
      await addVariant('mug-v', 'mug', 10);
      final lines = [line('mug', 'mug-v', 3)];

      await RetailInventoryService.deductStockForSale(lines, saleId: 'S1');
      await RetailInventoryService.deductStockForSale(lines, saleId: 'S1');

      expect(await stockOf('mug-v'), 7);
      expect(movements().where((m) => m.reason == 'Sale'), hasLength(1));
    });

    test('R-14 a retry after a mid-way failure applies only the missing lines',
        () async {
      await addProduct('mug');
      await addProduct('tea');
      await addVariant('mug-v', 'mug', 10);
      await addVariant('tea-v', 'tea', 10);
      final lines = [line('mug', 'mug-v', 2), line('tea', 'tea-v', 4)];

      // First attempt got through the mug line only, then died.
      await RetailInventoryService.deductStockForSale([lines.first], saleId: 'S2');
      // Retry runs the whole sale again.
      await RetailInventoryService.deductStockForSale(lines, saleId: 'S2');

      expect(await stockOf('mug-v'), 8, reason: 'not deducted twice');
      expect(await stockOf('tea-v'), 6);
    });

    test('R-14 a bundle sale re-run deducts its components once', () async {
      await setUpCombo(mugStock: 10, teaStock: 10);
      final lines = [line('combo', 'combo-v', 1)];

      await RetailInventoryService.deductStockForSale(lines, saleId: 'S3');
      await RetailInventoryService.deductStockForSale(lines, saleId: 'S3');

      expect(await stockOf('mug-v'), 9);
      expect(await stockOf('tea-v'), 8);
    });

    test('different sales of the same cart line are both deducted', () async {
      await addProduct('mug');
      await addVariant('mug-v', 'mug', 10);
      final lines = [line('mug', 'mug-v', 1)];

      await RetailInventoryService.deductStockForSale(lines, saleId: 'S4');
      await RetailInventoryService.deductStockForSale(lines, saleId: 'S5');

      expect(await stockOf('mug-v'), 8);
    });

    test('a negative component leaves the bundle unsellable, not negative', () async {
      final (combo, v) = await setUpCombo(mugStock: -2, teaStock: 10);
      expect(RetailInventoryService.calculateAvailableToSell(combo, v), 0);
    });
  });

  group('product flags follow the variants', () {
    test('R-58 hasVariants flips when a 2nd variant is added and back on delete',
        () async {
      await addProduct('mug');
      await addVariant('mug-a', 'mug', 1);
      expect(productStore.getProductById('mug')!.hasVariants, isFalse);

      await addVariant('mug-b', 'mug', 1);
      expect(productStore.getProductById('mug')!.hasVariants, isTrue);
      expect(productStore.getProductById('mug')!.productType, 'variable');

      await productStore.deleteVariant('mug-b');
      expect(productStore.getProductById('mug')!.hasVariants, isFalse);
    });

    test('R-66 POS quick-create leaves cost UNKNOWN, not zero', () async {
      final (_, v) = await productStore.createSimpleProduct(
          name: 'Walk-in', categoryId: '', barcode: '8901', sellingPrice: 50);
      expect((await productStore.getVariantById(v.varianteId))!.costPrice,
          isNull);
    });
  });

  group('R-07 unconfigured bundle', () {
    test('a bundle variant with no bundle row is flagged', () async {
      final (combo, v) = await setUpCombo(configured: false);
      expect(RetailInventoryService.isUnconfiguredBundle(combo, v), isTrue);
      expect(RetailInventoryService.calculateAvailableToSell(combo, v), 0);
    });

    test('a configured bundle and a standard product are not flagged', () async {
      final (combo, v) = await setUpCombo();
      final mug = productStore.getProductById('mug')!;
      final mugV = (await productStore.getVariantById('mug-v'))!;
      expect(RetailInventoryService.isUnconfiguredBundle(combo, v), isFalse);
      expect(RetailInventoryService.isUnconfiguredBundle(mug, mugV), isFalse);
    });
  });

  group('R-06 return restores components', () {
    test('sell 2 combos then return them → components back where they started', () async {
      await setUpCombo(comboOwnStock: 0, mugStock: 10, teaStock: 10);

      await RetailInventoryService.restockForReturn(
          productId: 'combo', variantId: 'combo-v', qty: 2);

      expect(await stockOf('mug-v'), 12);
      expect(await stockOf('tea-v'), 14);
      expect(await stockOf('combo-v'), 0, reason: 'bundle never holds stock');
    });

    test('a standard product is restocked on its own variant', () async {
      await setUpCombo();
      await RetailInventoryService.restockForReturn(
          productId: 'mug', variantId: 'mug-v', qty: 3);
      expect(await stockOf('mug-v'), 13);
    });

    test('R-10: a bundle return logs one Return row per component', () async {
      await setUpCombo(mugStock: 10, teaStock: 10);
      await RetailInventoryService.restockForReturn(
          productId: 'combo', variantId: 'combo-v', qty: 2, note: 'CRN-00001');

      final rows = movements().where((m) => m.reason == 'Return').toList();
      expect(rows.map((m) => (m.variantId, m.type, m.quantity, m.balanceAfter)).toSet(), {
        ('mug-v', 'in', 2.0, 12.0),
        ('tea-v', 'in', 4.0, 14.0),
      });
      expect(rows.every((m) => m.note == 'CRN-00001'), isTrue);
    });

    test('R-26: deductStock on a bundle takes its components', () async {
      await setUpCombo(comboOwnStock: 5, mugStock: 10, teaStock: 10);
      await RetailInventoryService.deductStock(
          productId: 'combo', variantId: 'combo-v', qty: 2,
          reason: 'Exchange', note: 'EXC-1');

      expect(await stockOf('mug-v'), 8);
      expect(await stockOf('tea-v'), 6);
      expect(await stockOf('combo-v'), 5, reason: 'own figure untouched');
      expect(movements().where((m) => m.reason == 'Exchange'), hasLength(2));
    });

    test('an unconfigured bundle restores nothing', () async {
      await setUpCombo(configured: false);
      await RetailInventoryService.restockForReturn(
          productId: 'combo', variantId: 'combo-v', qty: 1);
      expect(await stockOf('mug-v'), 10);
      expect(await stockOf('tea-v'), 10);
      expect(await stockOf('combo-v'), 0);
    });
  });
}
