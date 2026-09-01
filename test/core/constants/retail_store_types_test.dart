import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/constants/retail_store_types.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';

void main() {
  group('RetailStoreTypes catalogue', () {
    test('offers the six approved store types plus Other, in order', () {
      expect(
        RetailStoreTypes.all.map((t) => t.key).toList(),
        equals([
          'garment',
          'footwear',
          'sports',
          'cosmetics_beauty',
          'stationery',
          'gift_general',
          // Last on purpose: the answer for a shop that recognised itself in
          // none of the above.
          'other',
        ]),
      );
    });

    test('display names match the agreed wording', () {
      expect(
        RetailStoreTypes.all.map((t) => t.name).toList(),
        equals([
          'Garment Store',
          'Footwear Store',
          'Sports Store',
          'Cosmetics & Beauty Store',
          'Stationery Store',
          'Gift & General Store',
          'Other / General Store',
        ]),
      );
    });

    // Grocery needs decimal quantity, UOM, weight selling and batch/expiry —
    // none of which the POS has. It must stay out until those exist.
    test('does not offer grocery', () {
      expect(RetailStoreTypes.isKnown('grocery'), isFalse);
      expect(
        RetailStoreTypes.all.any((t) => t.key.contains('grocer')),
        isFalse,
      );
    });

    test('keys are unique', () {
      final keys = RetailStoreTypes.all.map((t) => t.key).toList();
      expect(keys.toSet().length, equals(keys.length));
    });

    test('every entry carries a description and an icon name', () {
      for (final type in RetailStoreTypes.all) {
        expect(type.description, isNotEmpty, reason: type.key);
        expect(type.iconName, isNotEmpty, reason: type.key);
      }
    });

    group('byKey / isKnown / nameFor', () {
      test('resolve a known key', () {
        expect(RetailStoreTypes.byKey('cosmetics_beauty'),
            same(RetailStoreTypes.cosmeticsBeauty));
        expect(RetailStoreTypes.isKnown('gift_general'), isTrue);
        expect(RetailStoreTypes.nameFor('garment'), equals('Garment Store'));
      });

      test('tolerate null, empty and retired keys instead of throwing', () {
        for (final bad in [null, '', 'Garment Store', 'GARMENT', 'hardware']) {
          expect(RetailStoreTypes.byKey(bad), isNull, reason: '$bad');
          expect(RetailStoreTypes.isKnown(bad), isFalse, reason: '$bad');
          expect(RetailStoreTypes.nameFor(bad), isNull, reason: '$bad');
        }
      });
    });
  });

  group('store-type default attributes', () {
    test('each store type seeds the agreed attribute names', () {
      expect(RetailStoreTypes.garment.defaultAttributeNames,
          equals(['Size', 'Color', 'Material', 'Pattern']));
      expect(RetailStoreTypes.footwear.defaultAttributeNames,
          equals(['Size', 'Color', 'Material', 'Sole Type']));
      expect(RetailStoreTypes.sports.defaultAttributeNames,
          equals(['Size', 'Color', 'Material', 'Sport Type']));
      expect(RetailStoreTypes.cosmeticsBeauty.defaultAttributeNames,
          equals(['Shade', 'Color', 'Skin Type', 'Finish', 'Volume']));
      expect(RetailStoreTypes.stationery.defaultAttributeNames,
          equals(['Color', 'Size', 'Paper Type', 'GSM', 'Binding Type']));
      expect(RetailStoreTypes.giftGeneral.defaultAttributeNames,
          equals(['Color', 'Size', 'Material', 'Pattern']));

      // The ONLY type with no store-type defaults.
      expect(RetailStoreTypes.other.defaultAttributeNames, isEmpty);
    });

    // Brand and Expiry Date are first-class fields already (ProductModel
    // .brandName, VarianteModel.expiryDate); Gender does not exist at all.
    // Seeding any of them as an attribute would duplicate an existing field.
    test('no store type duplicates an existing first-class product field', () {
      for (final type in RetailStoreTypes.all) {
        for (final banned in const ['Brand', 'Gender', 'Expiry Date']) {
          expect(type.defaultAttributeNames, isNot(contains(banned)),
              reason: '${type.key} must not redeclare $banned');
        }
      }
    });

    // The whole point of the Other type: it must seed NOTHING. Declaring its
    // defaults as `null` instead of `const []` would compile, pass analysis, and
    // silently seed kBaseAttributeNames (Size/Color/Weight) onto every product.
    test('Other seeds nothing, and is deliberately empty rather than unknown',
        () {
      expect(RetailStoreTypes.isKnown('other'), isTrue);
      expect(RetailStoreTypes.defaultAttributeNamesFor('other'), isEmpty);
      expect(RetailStoreTypes.defaultAttributeNamesFor('other'), isNotNull);
    });

    // Gift & General used to share Other's empty contract. It no longer does —
    // it is a normal mapped type, and Other stands alone as "no defaults".
    test('Other is the only type with no defaults', () {
      final empty = RetailStoreTypes.all
          .where((t) => t.defaultAttributeNames.isEmpty)
          .map((t) => t.key)
          .toList();
      expect(empty, equals(['other']));
    });

    // The distinction the whole feature depends on: an unknown key means "no
    // store type — this feature does not apply, leave the legacy fallback
    // alone"; `other` means "genuinely none, seed nothing".
    test('defaultAttributeNamesFor separates unknown from deliberately empty',
        () {
      expect(RetailStoreTypes.defaultAttributeNamesFor('other'), isEmpty);
      expect(RetailStoreTypes.defaultAttributeNamesFor(null), isNull);
      expect(RetailStoreTypes.defaultAttributeNamesFor('grocery'), isNull);
      expect(RetailStoreTypes.defaultAttributeNamesFor('garment'),
          equals(['Size', 'Color', 'Material', 'Pattern']));
    });

    // Contract: a default name misspelled here would create an attribute with
    // no starter values and no error anywhere.
    test('every default name has starter values in kSeedAttributeValues', () {
      for (final type in RetailStoreTypes.all) {
        for (final name in type.defaultAttributeNames) {
          expect(
            kSeedAttributeValues.containsKey(name),
            isTrue,
            reason: '${type.key} defaults to "$name", '
                'which has no entry in kSeedAttributeValues',
          );
          expect(kSeedAttributeValues[name], isNotEmpty, reason: name);
        }
      }
    });

    test('the app-wide fallback names are also seedable', () {
      for (final name in kBaseAttributeNames) {
        expect(kSeedAttributeValues.containsKey(name), isTrue, reason: name);
      }
    });

    test('colour swatch lists align with their value lists', () {
      for (final entry in kSeedAttributeColorCodes.entries) {
        final values = kSeedAttributeValues[entry.key];
        expect(values, isNotNull, reason: entry.key);
        expect(
          entry.value.length,
          equals(values!.length),
          reason: '${entry.key}: ${entry.value.length} swatches for '
              '${values.length} values',
        );
      }
    });

    test('no store type defaults to a duplicate attribute', () {
      for (final type in RetailStoreTypes.all) {
        final names = type.defaultAttributeNames;
        expect(names.toSet().length, equals(names.length), reason: type.key);
      }
    });
  });
}
