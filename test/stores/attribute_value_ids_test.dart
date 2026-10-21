import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';

/// R-09 in docs/modules/retail_inventory.md: Edit Variant wrote only
/// `customAttributes`, while the till reads `attributeValueIds` first — so a
/// corrected "Blue" kept billing as "Red". The dialog now rebuilds the ids
/// from its rows via [AttributeStore.valueIdsFor].
void main() {
  late Directory tempDir;
  late AttributeStore store;
  late String colourId;
  late String redId;
  late String blueId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('attr_value_ids_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox(HiveBoxNames.appCounters);

    await locator.reset();
    store = AttributeStore();
    await store.addAttribute('Colour');
    colourId = store.getAttributeByName('Colour')!.attributeId;
    await store.addValue(colourId, 'Red');
    await store.addValue(colourId, 'Blue');
    await store.loadAttributes();
    redId = store.getValues(colourId).firstWhere((v) => v.value == 'Red').valueId;
    blueId = store.getValues(colourId).firstWhere((v) => v.value == 'Blue').valueId;
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  VarianteModel variant({Map<String, String>? text, Map<String, String>? ids}) =>
      VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        stockQty: 0,
        createdAt: '2026-01-01T00:00:00.000',
        customAttributes: text,
        attributeValueIds: ids,
      );

  test('an edited catalogue value maps to its own id', () {
    expect(store.valueIdsFor({'Colour': 'Blue'}), {colourId: blueId});
  });

  test('matching is case-insensitive on both name and value', () {
    expect(store.valueIdsFor({'colour': ' blue '}), {colourId: blueId});
  });

  test('free text and unknown values carry no id', () {
    expect(store.valueIdsFor({'Colour': 'Teal', 'Material': 'Cotton'}), isEmpty);
  });

  test('the drift itself: after rebuilding, the till reads the edit', () {
    // Generated as Red; the owner edits the row to Blue.
    final before = variant(text: {'Colour': 'Red'}, ids: {colourId: redId});
    expect(store.attributesOf(before), {'Colour': 'Red'});

    // Old behaviour — only the text map changed: ids still win, till says Red.
    final oldSave = before.copyWith(customAttributes: {'Colour': 'Blue'});
    expect(store.attributesOf(oldSave), {'Colour': 'Red'});

    // New behaviour — ids rebuilt from the same rows.
    final descriptors = {'Colour': 'Blue'};
    final newSave = before.copyWith(
      customAttributes: descriptors,
      attributeValueIds: store.valueIdsFor(descriptors),
    );
    expect(store.attributesOf(newSave), {'Colour': 'Blue'});
  });

  test('editing to a value outside the catalogue drops the stale id', () {
    final before = variant(text: {'Colour': 'Red'}, ids: {colourId: redId});
    final descriptors = {'Colour': 'Teal'};
    final saved = before.copyWith(
      customAttributes: descriptors,
      attributeValueIds: store.valueIdsFor(descriptors),
    );
    expect(store.attributesOf(saved), {'Colour': 'Teal'});
  });
}
