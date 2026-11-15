import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';

/// In-memory stand-in for the checkout journal's intents.
class _Intents implements SaleStockIntents {
  final Map<String, ({double before, double after})> recorded = {};
  final Set<String> conflicts = {};

  @override
  ({double before, double after})? intentFor(String rowId) => recorded[rowId];
  @override
  bool isConflict(String rowId) => conflicts.contains(rowId);
  @override
  Future<void> record(String rowId,
          {required double before, required double after}) async =>
      recorded[rowId] = (before: before, after: after);
  @override
  Future<void> conflict(String rowId,
          {required String label, required double qty}) async =>
      conflicts.add(rowId);
}

/// Fails right after one stock write, before its movement row.
class _StopAfterWrite extends ProductStore {
  bool stop = false;
  @override
  Future<void> updateVariantStock(String variantId, double newStock) async {
    await super.updateVariantStock(variantId, newStock);
    if (stop) {
      stop = false;
      throw StateError('stopped after the write');
    }
  }
}

/// BLK-13B: the row check alone cannot see a stop between a stock write and
/// its row; the recorded before/after can.
void main() {
  late Directory tempDir;
  late _StopAfterWrite products;
  const now = '2026-01-01T00:00:00.000';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_intents_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await locator.reset();
    products = _StopAfterWrite();
    locator
      ..registerSingleton<ProductStore>(products)
      ..registerSingleton<BundleRepository>(BundleRepository())
      ..registerSingleton<AuthService>(AuthService());
    await products.addProduct(ProductModel(productId: 'p1', productName: 'Pen',
        category: '', hasVariants: false, createdAt: now, updateAt: now));
    await products.addVariant(VarianteModel(varianteId: 'v1', productId: 'p1',
        stockQty: 10, createdAt: now, status: 'active'));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final lines = [
    CartItemModel(cartItemId: 'c1', variantId: 'v1', productId: 'p1',
        productName: 'Pen', price: 10, qty: 3, total: 30, addedAt: now),
  ];
  double stock() => Hive.box<VarianteModel>(HiveBoxNames.variants).get('v1')!.stockQty;
  int saleRows() => Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
      .values.where((r) => r.id == 'sale_S1_c1').length;

  test('a stop between the write and its row: the retry writes only the row',
      () async {
    final intents = _Intents();
    products.stop = true;
    await expectLater(
        RetailInventoryService.deductStockForSale(lines, saleId: 'S1', intents: intents),
        throwsA(isA<StateError>()));
    expect(stock(), 7);
    expect(saleRows(), 0);

    await RetailInventoryService.deductStockForSale(lines, saleId: 'S1', intents: intents);
    expect(stock(), 7, reason: 'not deducted a second time');
    expect(saleRows(), 1);
    final row = Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
        .get('sale_S1_c1')!;
    expect(row.balanceAfter, 7);
  });

  test('recorded but never written: applied once', () async {
    final intents = _Intents()..recorded['sale_S1_c1'] = (before: 10, after: 7);
    await RetailInventoryService.deductStockForSale(lines, saleId: 'S1', intents: intents);
    expect(stock(), 7);
    expect(saleRows(), 1);
  });

  test('stock neither as before nor after: reported, nothing written', () async {
    final intents = _Intents()..recorded['sale_S1_c1'] = (before: 12, after: 9);
    await RetailInventoryService.deductStockForSale(lines, saleId: 'S1', intents: intents);
    expect(stock(), 10);
    expect(saleRows(), 0);
    expect(intents.conflicts, {'sale_S1_c1'});
    // Reported once: a later run does not write either.
    await RetailInventoryService.deductStockForSale(lines, saleId: 'S1', intents: intents);
    expect(stock(), 10);
  });

  test('without intents: the plain deduction, unchanged', () async {
    await RetailInventoryService.deductStockForSale(lines, saleId: 'S1');
    await RetailInventoryService.deductStockForSale(lines, saleId: 'S1');
    expect(stock(), 7, reason: 'the existing row check still skips a done line');
    expect(saleRows(), 1);
  });
}
