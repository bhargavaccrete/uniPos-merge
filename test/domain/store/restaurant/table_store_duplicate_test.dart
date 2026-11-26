import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';

/// A table's name is its storage key. Adding a second "1" overwrote the
/// running Table 1 (reset to Available) and showed two tiles; deleting one
/// then removed both.
void main() {
  late Directory tempDir;
  late TableStore store;
  Box<TableModel> box() => Hive.box<TableModel>(HiveBoxNames.restaurantTables);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('table_dup_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
    locator.registerSingleton<LicenseStore>(
        LicenseStore(LicenseApiService())..licenseBypassed = true);
    store = TableStore(TableRepository());
    await store.loadTables();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('a second table with the same name is refused; the running one is '
      'untouched', () async {
    expect(await store.addTable(TableModel(id: '1')), isTrue);
    await store.updateTableStatus('1', 'Running',
        total: 250, orderId: 'order-7', orderTime: DateTime(2026, 11, 18));

    expect(await store.addTable(TableModel(id: '1')), isFalse);
    expect(store.errorMessage, 'Table "1" already exists.');

    expect(store.tables.where((t) => t.id == '1'), hasLength(1));
    final saved = box().get('1')!;
    expect(saved.status, 'Running');
    expect(saved.currentOrderId, 'order-7');
    expect(saved.currentOrderTotal, 250);
  });

  test('same name with other spacing or case is refused too', () async {
    expect(await store.addTable(TableModel(id: 'T1')), isTrue);
    expect(await store.addTable(TableModel(id: 't1')), isFalse);
    expect(await store.addTable(TableModel(id: ' T1 ')), isFalse);
    expect(store.tables, hasLength(1));
    expect(box().length, 1);
  });

  test('different names still work', () async {
    expect(await store.addTable(TableModel(id: '1')), isTrue);
    expect(await store.addTable(TableModel(id: '2')), isTrue);
    expect(store.tables.map((t) => t.id), ['1', '2']);
  });

  test('nameTaken ignores the table being renamed', () async {
    await store.addTable(TableModel(id: 't1'));
    await store.addTable(TableModel(id: '2'));
    expect(store.nameTaken('T1', exceptId: 't1'), isFalse);
    expect(store.nameTaken('T1', exceptId: '2'), isTrue);
  });
}
