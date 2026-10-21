import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/config/food_license_rule.dart';

/// Pure tests — only the `*For(country)` forms are exercised. The zero-arg
/// getters read Hive via the service locator and belong to an integration test.
void main() {
  group('FoodLicenseRule.labelFor', () {
    const expected = <String, String>{
      'India': 'FSSAI License No.',
      'United Kingdom': 'Food Business Registration Ref. No.',
      'United States': 'Food Establishment Permit No.',
      'Canada': 'SFC Licence No.',
      'Australia': 'Food Business Registration No.',
      'New Zealand': 'Food Business Registration No.',
      'Singapore': 'SFA Food Licence No.',
      'United Arab Emirates': 'Food Establishment Permit No.',
    };

    expected.forEach((country, label) {
      test('$country -> $label', () {
        expect(FoodLicenseRule.labelFor(country), label);
      });
    });

    test('unlisted country falls back to the generic label', () {
      for (final c in ['Germany', 'Japan', 'Brazil', 'Nepal']) {
        expect(FoodLicenseRule.labelFor(c), 'Food Licence No.');
      }
    });

    test('null / empty country falls back to the generic label', () {
      expect(FoodLicenseRule.labelFor(null), 'Food Licence No.');
      expect(FoodLicenseRule.labelFor(''), 'Food Licence No.');
      expect(FoodLicenseRule.labelFor('   '), 'Food Licence No.');
    });

    test('lookup is exact-match, not substring', () {
      // The bundled country.json carries this alongside "United States"; a
      // `contains` check would wrongly give it the USA label.
      expect(
        FoodLicenseRule.labelFor('United States Minor Outlying Islands'),
        'Food Licence No.',
      );
    });

    test('case and surrounding whitespace are ignored', () {
      expect(FoodLicenseRule.labelFor('  india  '), 'FSSAI License No.');
      expect(FoodLicenseRule.labelFor('INDIA'), 'FSSAI License No.');
      expect(FoodLicenseRule.labelFor('United KINGDOM'),
          'Food Business Registration Ref. No.');
    });
  });

  group('FoodLicenseRule field shape', () {
    test('India is 14 digits, numeric-only', () {
      expect(FoodLicenseRule.isIndia('India'), isTrue);
      expect(FoodLicenseRule.maxLengthFor('India'), 14);
      expect(FoodLicenseRule.digitsOnlyFor('India'), isTrue);
    });

    test('elsewhere is free-form and longer', () {
      expect(FoodLicenseRule.isIndia('Singapore'), isFalse);
      expect(FoodLicenseRule.maxLengthFor('Singapore'), 30);
      expect(FoodLicenseRule.digitsOnlyFor('Singapore'), isFalse);
    });

    test('unset country is NOT treated as India', () {
      // Unlike PhoneRule, which defaults to India, an unknown country here just
      // gets the generic free-form treatment — nothing is rejected.
      expect(FoodLicenseRule.isIndia(null), isFalse);
      expect(FoodLicenseRule.digitsOnlyFor(null), isFalse);
    });
  });

  group('FoodLicenseRule.validateFor', () {
    test('empty is always valid — the field is optional everywhere', () {
      for (final c in ['India', 'United Kingdom', null, '']) {
        expect(FoodLicenseRule.validateFor(c, ''), isNull);
        expect(FoodLicenseRule.validateFor(c, '   '), isNull);
        expect(FoodLicenseRule.validateFor(c, null), isNull);
      }
    });

    test('India accepts exactly 14 digits', () {
      expect(FoodLicenseRule.validateFor('India', '12345678901234'), isNull);
      expect(FoodLicenseRule.validateFor('India', ' 12345678901234 '), isNull);
    });

    test('India rejects the wrong length', () {
      expect(FoodLicenseRule.validateFor('India', '1234567890123'), isNotNull);
      expect(FoodLicenseRule.validateFor('India', '123456789012345'), isNotNull);
    });

    test('India rejects non-numeric characters', () {
      expect(FoodLicenseRule.validateFor('India', '1234567890123A'), isNotNull);
      expect(FoodLicenseRule.validateFor('India', 'ABCDEFGHIJKLMN'), isNotNull);
    });

    test('every other country accepts any non-empty value', () {
      for (final c in ['United Kingdom', 'United States', 'Singapore', 'Chad']) {
        expect(FoodLicenseRule.validateFor(c, 'AB-123/XY'), isNull);
        expect(FoodLicenseRule.validateFor(c, '7'), isNull);
      }
    });
  });
}
