import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_item_model_181.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_model_180.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/restaurant/printer_repository.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/store/restaurant/printer_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/stock_take_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// Screens used to reload these lists after an edit or after returning from a
/// child screen. Those reloads were removed because each write already updates
/// the store. Every test compares the live store with a freshly loaded
/// instance, so a write that stops updating the list shows up here.
void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('retail_lists_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await HiveInit.registerRestaurantAdapters();

    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<StockTakeModel>(HiveBoxNames.stockTakes);
    await Hive.openBox<StockTakeItemModel>(HiveBoxNames.stockTakeItems);
    await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
    await Hive.openBox(HiveBoxNames.appCounters);

    locator
      ..registerLazySingleton<ProductStore>(() => ProductStore())
      ..registerLazySingleton<AuthService>(() => AuthService());
    // Stock takes are admin-only.
    await RestaurantSession.saveAdminSession();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // attributes_screen: no reload after rename/delete of attribute or value.
  group('AttributeStore', () {
    // Flattened to strings: records compare List fields by identity.
    Future<List<String>> snapshot(AttributeStore s) async => [
          for (final a in s.attributes)
            '${a.attributeId}:${a.name}='
                '${s.getValues(a.attributeId).map((v) => '${v.valueId}:${v.value}').join(',')}'
        ];

    Future<List<String>> fresh() async {
      final f = AttributeStore();
      await f.loadAttributes();
      return snapshot(f);
    }

    test('rename and delete of attributes and values match a reload',
        () async {
      final store = AttributeStore();
      await store.loadAttributes();
      expect(await store.addAttribute('Size', sortOrder: 0), isTrue);
      expect(await store.addAttribute('Color', sortOrder: 1), isTrue);
      await store.loadAttributes(); // as the screen's init does
      final size = store.attributes.firstWhere((a) => a.name == 'Size');
      final color = store.attributes.firstWhere((a) => a.name == 'Color');
      expect(
          await store.addMultipleValues(size.attributeId, ['S', 'M', 'L']),
          isTrue);
      expect(await store.addMultipleValues(color.attributeId, ['Red', 'Blue']),
          isTrue);
      await store.loadAttributes();

      // attributes_screen.dart: rename attribute (was followed by a reload).
      expect(await store.updateAttribute(size.attributeId, name: 'Sizes'),
          isTrue);
      expect(await snapshot(store), await fresh());

      // Edit a value's text.
      final medium =
          store.getValues(size.attributeId).firstWhere((v) => v.value == 'M');
      expect(await store.updateValue(medium.valueId, value: 'Medium'), isTrue);
      expect(await snapshot(store), await fresh());

      // Delete a value.
      final large =
          store.getValues(size.attributeId).firstWhere((v) => v.value == 'L');
      expect(await store.deleteValue(large.valueId), isTrue);
      expect(await snapshot(store), await fresh());

      // Delete an attribute.
      expect(await store.deleteAttribute(color.attributeId), isTrue);
      expect(await snapshot(store), await fresh());
      expect(store.attributes.map((a) => a.name), ['Sizes']);
    });
  });

  // retail stock_take_list_screen: no reload after returning from a take.
  group('StockTakeStore', () {
    List<(String, String)> rows(StockTakeStore s) =>
        [for (final t in s.takes) (t.takeId, t.status)];

    Future<List<(String, String)>> freshRows() async {
      final f = StockTakeStore();
      await f.loadTakes();
      return rows(f);
    }

    test('start, count and cancel keep takes current', () async {
      final store = StockTakeStore();
      await store.loadTakes();

      final first = await store.startTake();
      expect(first, isNotNull, reason: store.errorMessage);
      expect(rows(store), await freshRows());

      final counted = await store.countVariant(
        variant: VarianteModel(
          varianteId: 'v1',
          productId: 'p1',
          sellingPrice: 100,
          costPrice: 60,
          stockQty: 5,
          createdAt: '2026-09-17T00:00:00.000',
        ),
        countedQty: 4,
      );
      expect(counted, isTrue);
      expect(rows(store), await freshRows());

      final second = await store.startTake();
      expect(store.takes.first.takeId, second!.takeId,
          reason: 'newest first, same as a reload');
      expect(rows(store), await freshRows());

      expect(await store.cancelTake(first!.takeId), isTrue);
      expect(rows(store), await freshRows());
    });
  });

  // printersetting / printer_connection_screen: no reload after Add Printer.
  group('PrinterStore', () {
    Future<String> snapshot(PrinterStore s) async =>
        '${s.savedPrinters.map((p) => '${p.id}:${p.role}').join(',')}'
        '|kot=${s.defaultKotPrinter?.id}|receipt=${s.defaultReceiptPrinter?.id}';

    Future<String> fresh() async {
      final f = PrinterStore(PrinterRepository(), ThermalPrinterService());
      await f.loadSavedPrinters();
      return snapshot(f);
    }

    test('save, set default and delete leave the store current', () async {
      final store = PrinterStore(PrinterRepository(), ThermalPrinterService());
      await store.loadSavedPrinters();

      await store.savePrinter(SavedPrinterModel(
          id: 'p1', name: 'Front', type: 'wifi', address: '10.0.0.5'));
      await store.savePrinter(SavedPrinterModel(
          id: 'p2', name: 'Kitchen', type: 'wifi', address: '10.0.0.6'));
      expect(await snapshot(store), await fresh());
      expect(store.savedPrinters, hasLength(2));

      await store.setDefaultForRole('p2', 'kot');
      expect(await snapshot(store), await fresh());

      await store.deletePrinter('p1');
      expect(await snapshot(store), await fresh());
      expect(store.savedPrinters.map((p) => p.id), ['p2']);
    });
  });
}
