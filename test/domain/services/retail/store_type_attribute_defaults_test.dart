import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/core/constants/retail_store_types.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/retail/store_type_attribute_defaults_service.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';

/// Store-type-driven default product attributes.
///
/// The contract under test, in one table:
///
/// | store type on record | seeds                    | marker |
/// |----------------------|--------------------------|--------|
/// | known (garment, …)   | its mapped names, ONCE   | yes    |
/// | `other`              | nothing                  | no     |
/// | absent / unknown     | nothing (feature is off) | no     |
///
/// The last two rows are the ones worth guarding: neither may fall through to
/// `kBaseAttributeNames`, and neither may write a marker that would later
/// suppress seeding for a real store type.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StoreTypeAttributeDefaultsService service;

  setUp(() async {
    await locator.reset();

    SharedPreferences.setMockInitialValues({});
    // setMockInitialValues leaves any instance cached by a previous test in
    // place, so clear explicitly — otherwise a seed marker leaks between tests
    // and every "seeds once" assertion passes for the wrong reason.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    tempDir = await Directory.systemTemp.createTemp('store_type_attr_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(HiveTypeIds.businessDetails)) {
      Hive.registerAdapter(BusinessDetailsAdapter());
    }
    await HiveInit.registerRetailAdapters();

    await Hive.openBox<BusinessDetails>('businessDetailsBox');
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);

    locator.registerLazySingleton<BusinessDetailsRepository>(
        () => BusinessDetailsRepository());
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());

    service = StoreTypeAttributeDefaultsService();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    await locator.reset();
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> setStoreType(String? key) async {
    await businessDetailsRepository.save(
      BusinessDetails(businessTypeId: 'retail', retailStoreType: key),
    );
  }

  /// Attribute names currently in the box, read fresh.
  Future<List<String>> currentNames() async {
    await attributeStore.loadAttributes();
    return attributeStore.attributes.map((a) => a.name).toList();
  }

  /// Wipe attributes + the seed marker so a single test can exercise several
  /// store types from a clean slate.
  Future<void> resetSeedState() async {
    await Hive.box<AttributeModel>(HiveBoxNames.attributes).clear();
    await Hive.box<AttributeValueModel>(HiveBoxNames.attributeValues).clear();
    await service.clearSeedMarker();
    await attributeStore.loadAttributes();
  }

  // ── the mapping, per store type ────────────────────────────────────────────

  group('a known store type seeds its mapped names', () {
    test('all seven types seed exactly what the catalogue declares', () async {
      for (final type in RetailStoreTypes.all) {
        await resetSeedState();
        await setStoreType(type.key);

        await service.ensureStoreTypeDefaults();

        expect(await currentNames(), equals(type.defaultAttributeNames),
            reason: 'store type ${type.key}');
      }
    });

    test('garment seeds Size, Color, Material, Pattern', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(),
          equals(['Size', 'Color', 'Material', 'Pattern']));
    });

    test('every seeded attribute arrives with its starter values', () async {
      await setStoreType('stationery');
      await service.ensureStoreTypeDefaults();
      await attributeStore.loadAttributes();

      for (final attribute in attributeStore.attributes) {
        final values = attributeStore
            .getValues(attribute.attributeId)
            .map((v) => v.value)
            .toList();
        expect(values, equals(kSeedAttributeValues[attribute.name]),
            reason: attribute.name);
      }
    });
  });

  // ── the two "seed nothing" cases, which must stay distinct ─────────────────

  group('Other / General seeds nothing', () {
    test('leaves the attribute box completely empty', () async {
      await setStoreType('other');

      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), isEmpty);
    });

    test('never falls back to Size / Color / Weight', () async {
      await setStoreType('other');

      await service.ensureStoreTypeDefaults();

      final names = await currentNames();
      for (final fallback in kBaseAttributeNames) {
        expect(names, isNot(contains(fallback)));
      }
    });

    test('writes no marker, so picking a real type later still seeds it',
        () async {
      await setStoreType('other');
      await service.ensureStoreTypeDefaults();

      await setStoreType('footwear');
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(),
          equals(['Size', 'Color', 'Material', 'Sole Type']));
    });
  });

  group('no store type on record — the feature does not apply', () {
    test('a null store type seeds nothing at all', () async {
      await setStoreType(null);

      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), isEmpty);
    });

    test('no business record at all seeds nothing and does not throw',
        () async {
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), isEmpty);
    });

    test('an unknown / retired key behaves like absent', () async {
      await setStoreType('grocery');

      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), isEmpty);
    });

    test('writes no marker, so a later real selection still seeds', () async {
      await setStoreType(null);
      await service.ensureStoreTypeDefaults();

      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(),
          equals(['Size', 'Color', 'Material', 'Pattern']));
    });
  });

  // ── seeded ONCE: the promise that makes these defaults, not locks ──────────

  group('seeds once per store type', () {
    test('a second call adds nothing', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();
      final first = await currentNames();

      await service.ensureStoreTypeDefaults();
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), equals(first));
    });

    test('a deleted default is NOT recreated', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();
      await attributeStore.loadAttributes();

      final pattern = attributeStore.getAttributeByName('Pattern')!;
      expect(await attributeStore.deleteAttribute(pattern.attributeId), isTrue);

      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), isNot(contains('Pattern')));
      expect(await currentNames(), equals(['Size', 'Color', 'Material']));
    });

    test('deleting every default leaves the merchant with none', () async {
      await setStoreType('footwear');
      await service.ensureStoreTypeDefaults();
      await attributeStore.loadAttributes();

      for (final attribute in attributeStore.attributes.toList()) {
        await attributeStore.deleteAttribute(attribute.attributeId);
      }

      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), isEmpty);
    });

    test('an explicit Reset (clearSeedMarker) does restore them', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();
      await attributeStore.loadAttributes();
      await attributeStore.deleteAttribute(
          attributeStore.getAttributeByName('Pattern')!.attributeId);

      await service.clearSeedMarker();
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), contains('Pattern'));
    });
  });

  // ── changing store type is additive, never destructive ────────────────────

  group('changing the store type', () {
    test('adds the new names without removing the old ones', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();

      await setStoreType('cosmetics_beauty');
      await service.ensureStoreTypeDefaults();

      final names = await currentNames();
      // Old set survives...
      expect(names, containsAll(['Size', 'Color', 'Material', 'Pattern']));
      // ...and the new one is added alongside.
      expect(names, containsAll(['Shade', 'Skin Type', 'Finish', 'Volume']));
    });

    test('does not duplicate a name the two types share', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();

      await setStoreType('footwear');
      await service.ensureStoreTypeDefaults();

      final names = await currentNames();
      expect(names.where((n) => n == 'Size').length, equals(1));
      expect(names.where((n) => n == 'Color').length, equals(1));
      expect(names, contains('Sole Type'));
    });

    test('keeps an attribute the merchant added themselves', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();
      await attributeStore.addAttribute('Fit');

      await setStoreType('sports');
      await service.ensureStoreTypeDefaults();

      expect(await currentNames(), contains('Fit'));
    });

    test('keeps a value the merchant added to a seeded attribute', () async {
      await setStoreType('garment');
      await service.ensureStoreTypeDefaults();
      await attributeStore.loadAttributes();
      final size = attributeStore.getAttributeByName('Size')!;
      await attributeStore.addValue(size.attributeId, 'XXL');

      await setStoreType('footwear');
      await service.ensureStoreTypeDefaults();
      await attributeStore.loadAttributes();

      final values = attributeStore
          .getValues(attributeStore.getAttributeByName('Size')!.attributeId)
          .map((v) => v.value);
      expect(values, contains('XXL'));
    });
  });

  // ── existing data is never touched ────────────────────────────────────────

  test('seeding leaves existing products and variants alone', () async {
    final products = Hive.box<ProductModel>(HiveBoxNames.products);
    final variants = Hive.box<VarianteModel>(HiveBoxNames.variants);
    final now = DateTime.now().toIso8601String();

    await products.put(
      'p1',
      ProductModel(
        productId: 'p1',
        productName: 'Existing Shirt',
        category: 'Apparel',
        hasVariants: true,
        createdAt: now,
        updateAt: now,
      ),
    );
    await variants.put(
      'v1',
      VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        createdAt: now,
        customAttributes: const {'Size': 'M'},
      ),
    );

    await setStoreType('garment');
    await service.ensureStoreTypeDefaults();

    expect(products.length, equals(1));
    expect(products.get('p1')!.productName, equals('Existing Shirt'));
    expect(variants.length, equals(1));
    expect(variants.get('v1')!.customAttributes, equals({'Size': 'M'}));
  });

  test('an attribute that already exists is reused, not duplicated', () async {
    // Simulates an install that already had Size before this feature existed.
    await attributeStore.addAttribute('Size');

    await setStoreType('garment');
    await service.ensureStoreTypeDefaults();

    final names = await currentNames();
    expect(names.where((n) => n == 'Size').length, equals(1));
    expect(names, containsAll(['Color', 'Material', 'Pattern']));
  });
}
