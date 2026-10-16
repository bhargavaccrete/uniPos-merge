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
import 'package:billberrylite/data/models/retail/hive_model/stock_take_item_model_181.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_model_180.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_reason.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/stock_take_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// R-20 in docs/modules/retail_inventory.md: a stock take could be applied
/// twice (take save failed after the lines landed, or a crash between a line's
/// adjustment and its appliedQty), and a partial commit went terminal with its
/// failed lines unappliable.
void main() {
  late Directory tempDir;
  late ProductStore products;
  late StockTakeStore takes;
  const now = '2026-01-01T00:00:00.000';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('stock_take_commit_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await AppConfig.init();
    await AppConfig.forceSetBusinessMode(BusinessMode.retail);
    await RestaurantSession.saveAdminSession();

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<StockTakeModel>(HiveBoxNames.stockTakes);
    await Hive.openBox<StockTakeItemModel>(HiveBoxNames.stockTakeItems);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.appCounters);

    await locator.reset();
    products = ProductStore();
    locator.registerSingleton<ProductStore>(products);
    locator.registerSingleton<AuthService>(AuthService());
    takes = StockTakeStore();

    for (final id in ['a', 'b']) {
      await products.addProduct(ProductModel(
          productId: 'p$id', productName: 'Item $id', category: '',
          hasVariants: false, createdAt: now, updateAt: now));
      await products.addVariant(VarianteModel(
          varianteId: id, productId: 'p$id', stockQty: 10, createdAt: now,
          status: 'active'));
    }
  });

  tearDown(() async {
    await RestaurantSession.clearSession();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<double> stock(String id) async =>
      (await products.getVariantById(id))!.stockQty;
  Future<VarianteModel> v(String id) async =>
      (await products.getVariantById(id))!;
  const reason = StockAdjustmentReason.stockCount;

  test('A: take save lost after every line landed → re-commit applies nothing',
      () async {
    await takes.startTake();
    await takes.countVariant(variant: await v('a'), countedQty: 7);
    expect((await takes.commit(reason: reason)).success, isTrue);
    expect(await stock('a'), 7);

    // Simulate the final take save never landing: the take is still a draft.
    final take = takes.currentTake!;
    await Hive.box<StockTakeModel>(HiveBoxNames.stockTakes)
        .put(take.takeId, take.copyWith(status: StockTakeStatus.draft.name));
    await takes.openTake(take.takeId);

    final again = await takes.commit(reason: reason);
    expect(again.success, isFalse, reason: 'nothing left to apply');
    expect(await stock('a'), 7, reason: 'not applied twice');
  });

  test('B: crash between adjustment and appliedQty → the line is not re-applied',
      () async {
    await takes.startTake();
    await takes.countVariant(variant: await v('a'), countedQty: 7);
    final line = takes.currentItems.single;

    // The adjustment landed (stock + its st_ row) but appliedQty never saved.
    await products.updateVariantStock('a', 7);
    await Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
        .put('st_${line.takeItemId}', StockMovementModel(
          id: 'st_${line.takeItemId}', timestamp: DateTime.now(), itemId: 'pa',
          variantId: 'a', itemName: 'Item a', type: 'out', quantity: 3,
          balanceAfter: 7, reason: reason.label, unit: 'pcs', staffName: 'x'));

    final r = await takes.commit(reason: reason);
    expect(r.success, isTrue);
    expect(await stock('a'), 7, reason: 'skipped, not 4');
    expect(takes.currentTake!.isEditable, isFalse, reason: 'now complete');
  });

  test('C: a partial commit stays open, locks applied lines, finishes later',
      () async {
    await takes.startTake();
    await takes.countVariant(variant: await v('a'), countedQty: 7); // -3
    await takes.countVariant(variant: await v('b'), countedQty: 0); // -10
    await products.updateVariantStock('b', 4); // sales since the count → b fails

    final first = await takes.commit(reason: reason);
    expect(first.appliedLines, 1);
    expect(first.failedLines, hasLength(1));
    expect(takes.currentTake!.isEditable, isTrue, reason: 'not terminal');
    expect(takes.varianceItems.single.variantId, 'b',
        reason: 'only the unapplied line is still pending');

    // The applied line is locked; the take can't be thrown away.
    expect(await takes.countVariant(variant: await v('a'), countedQty: 1),
        isFalse);
    expect(await takes.cancelTake(takes.currentTake!.takeId), isFalse);

    // Recount b and finish.
    await takes.countVariant(variant: await v('b'), countedQty: 0); // -4
    final second = await takes.commit(reason: reason);
    expect(second.appliedLines, 1);
    expect(await stock('a'), 7);
    expect(await stock('b'), 0);
    expect(takes.currentTake!.isEditable, isFalse);
    expect(takes.currentTake!.committedLineCount, 2, reason: 'whole take');
    expect(takes.currentTake!.committedNetQty, -7);
  });

  test('R-48: marking a line applied keeps its count timestamp', () async {
    await takes.startTake();
    await takes.countVariant(variant: await v('a'), countedQty: 7);
    final countedAt = takes.currentItems.single.countedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await takes.commit(reason: reason);

    expect(takes.currentItems.single.countedAt, countedAt);
  });
}
