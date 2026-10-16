import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_reason.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// R-17 / R-18 in docs/modules/retail_inventory.md: dialogs saved from the
/// variant they OPENED with. The adjustment now computes from the live
/// variant and refuses when the level the user saw has moved; Edit Variant
/// builds its save on the live variant (exercised here via updateVariant).
void main() {
  late Directory tempDir;
  late ProductStore store;
  const now = '2026-01-01T00:00:00.000';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('stock_adj_stale_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await AppConfig.init();
    await AppConfig.forceSetBusinessMode(BusinessMode.retail);
    await RestaurantSession.saveAdminSession();

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    await locator.reset();
    store = ProductStore();
    locator.registerSingleton<ProductStore>(store);
    locator.registerSingleton<AuthService>(AuthService());

    await store.addProduct(ProductModel(
        productId: 'p', productName: 'Mug', category: '', hasVariants: false,
        createdAt: now, updateAt: now));
    await store.addVariant(VarianteModel(
        varianteId: 'v', productId: 'p', stockQty: 10, createdAt: now,
        status: 'active'));
  });

  tearDown(() async {
    await RestaurantSession.clearSession();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<VarianteModel> live() async => (await store.getVariantById('v'))!;
  StockMovementModel lastAdjustment() =>
      StockAdjustmentService.allAdjustments().first;

  group('R-18 adjustment computes from live stock', () {
    test('a stale snapshot no longer skews the recorded change', () async {
      final opened = await live(); // dialog opens at 10
      await store.updateVariantStock('v', 8); // a sale lands meanwhile

      final r = await StockAdjustmentService.adjust(
        variant: opened,
        newStock: 5,
        reason: StockAdjustmentReason.stockCount,
      );

      expect(r.success, isTrue);
      expect((await live()).stockQty, 5);
      expect((lastAdjustment().type, lastAdjustment().quantity), ('out', 3.0),
          reason: 'true change 8 → 5, not the snapshot 10 → 5');
    });

    test('with expectedStock, a moved level is refused and reported', () async {
      final opened = await live();
      await store.updateVariantStock('v', 8);

      final r = await StockAdjustmentService.adjust(
        variant: opened,
        newStock: 5,
        reason: StockAdjustmentReason.stockCount,
        expectedStock: 10,
      );

      expect(r.success, isFalse);
      expect(r.liveStock, 8);
      expect((await live()).stockQty, 8, reason: 'nothing written');
      expect(StockAdjustmentService.allAdjustments(), isEmpty);
    });

    test('with expectedStock matching, it proceeds', () async {
      final r = await StockAdjustmentService.adjust(
        variant: await live(),
        newStock: 12,
        reason: StockAdjustmentReason.foundExtra,
        expectedStock: 10,
      );

      expect(r.success, isTrue);
      expect((lastAdjustment().type, lastAdjustment().quantity), ('in', 2.0));
    });
  });

  test('R-26 adjusting a bundle is refused — it holds no stock of its own',
      () async {
    await store.addProduct(ProductModel(
        productId: 'pb', productName: 'Combo', category: '', hasVariants: false,
        createdAt: now, updateAt: now, stockMode: 'bundle'));
    await store.addVariant(VarianteModel(
        varianteId: 'vb', productId: 'pb', stockQty: 0, createdAt: now,
        status: 'active'));

    final r = await StockAdjustmentService.adjust(
      variant: (await store.getVariantById('vb'))!,
      newStock: 5,
      reason: StockAdjustmentReason.foundExtra,
    );

    expect(r.success, isFalse);
    expect((await store.getVariantById('vb'))!.stockQty, 0);
  });

  test('R-17 a save built on the live variant keeps stock that moved', () async {
    final opened = await live(); // Edit Variant opens at 10
    await store.updateVariantStock('v', 7); // a sale lands meanwhile

    // What Edit Variant now does: re-read, then apply the form's fields.
    final base = await live();
    await store.updateVariant(base.copyWith(mrp: 99));

    expect((await live()).stockQty, 7);
    expect((await live()).mrp, 99);
    expect(
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
          .values
          .where((m) => m.reason == 'Stock edited'),
      isEmpty,
      reason: 'no phantom stock change',
    );

    // The old behaviour, for contrast: saving from the snapshot reverts it.
    await store.updateVariant(opened.copyWith(mrp: 98));
    expect((await live()).stockQty, 10);
  });
}
