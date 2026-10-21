import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/config/postal_code_rule.dart';

/// Pure tests — only the `*For(country, …)` forms are exercised. The zero-arg
/// getters read Hive via the service locator and belong to an integration test.
void main() {
  group('PostalCodeRule.labelFor', () {
    const expected = <String, String>{
      'India': 'PIN Code',
      'United States': 'ZIP Code',
      'United Kingdom': 'Postcode',
      'Australia': 'Postcode',
      'Singapore': 'Postal Code',
      'Canada': 'Postal Code',
      'Ireland': 'Eircode',
    };

    expected.forEach((country, label) {
      test('$country -> $label', () {
        expect(PostalCodeRule.labelFor(country), label);
      });
    });

    test('unlisted country falls back to the generic label', () {
      for (final c in ['Germany', 'Japan', 'Brazil']) {
        expect(PostalCodeRule.labelFor(c), 'Postal Code');
      }
    });

    test('null / empty falls back to the generic label', () {
      expect(PostalCodeRule.labelFor(null), 'Postal Code');
      expect(PostalCodeRule.labelFor(''), 'Postal Code');
    });

    test('lookup is exact-match, not substring', () {
      // country.json carries this alongside "United States"; a `contains`
      // check would wrongly give it the ZIP Code label.
      expect(
        PostalCodeRule.labelFor('United States Minor Outlying Islands'),
        'Postal Code',
      );
    });
  });

  group('PostalCodeRule.digitsOnlyFor', () {
    test('numeric-code countries keep the digits-only filter', () {
      for (final c in ['India', 'United States', 'Germany', 'Singapore']) {
        expect(PostalCodeRule.digitsOnlyFor(c), isTrue, reason: c);
      }
    });

    // The bug this whole rule exists to fix: a digits-only formatter makes
    // "SW1A 1AA" untypeable, which reads as a broken keyboard.
    test('alphanumeric-code countries must NOT get a digits-only filter', () {
      for (final c in ['United Kingdom', 'Canada', 'Ireland', 'Netherlands']) {
        expect(PostalCodeRule.digitsOnlyFor(c), isFalse, reason: c);
      }
    });

    test('unknown country defaults to allowing letters (the safe side)', () {
      expect(PostalCodeRule.digitsOnlyFor(''), isFalse);
      expect(PostalCodeRule.digitsOnlyFor(null), isFalse);
      expect(PostalCodeRule.digitsOnlyFor('Ruritania'), isFalse);
    });
  });

  group('PostalCodeRule.isRequiredFor', () {
    test('required for countries that have postal codes', () {
      for (final c in ['India', 'United Kingdom', 'Germany', '']) {
        expect(PostalCodeRule.isRequiredFor(c), isTrue, reason: c);
      }
    });

    test('optional where no postal-code system exists', () {
      for (final c in ['United Arab Emirates', 'Qatar', 'Hong Kong', 'Macau']) {
        expect(PostalCodeRule.isRequiredFor(c), isFalse, reason: c);
      }
    });
  });

  group('PostalCodeRule.validateFor — India', () {
    test('exactly 6 digits passes', () {
      expect(PostalCodeRule.validateFor('India', '382355'), isNull);
    });

    test('5 or 7 digits is rejected', () {
      expect(PostalCodeRule.validateFor('India', '38235'), isNotNull);
      expect(PostalCodeRule.validateFor('India', '3823556'), isNotNull);
    });

    test('letters are rejected even at the right length', () {
      expect(PostalCodeRule.validateFor('India', '38A355'), isNotNull);
    });
  });

  group('PostalCodeRule.validateFor — rest of world', () {
    test('real non-numeric codes are accepted', () {
      expect(PostalCodeRule.validateFor('United Kingdom', 'SW1A 1AA'), isNull);
      expect(PostalCodeRule.validateFor('Canada', 'K1A 0B1'), isNull);
      expect(PostalCodeRule.validateFor('Ireland', 'D02 AF30'), isNull);
    });

    test('lengths India would reject are fine elsewhere', () {
      expect(PostalCodeRule.validateFor('United States', '90210'), isNull);
      expect(PostalCodeRule.validateFor('United States', '90210-1234'), isNull);
      expect(PostalCodeRule.validateFor('Australia', '2000'), isNull);
    });

    test('only the cap is enforced', () {
      expect(
        PostalCodeRule.validateFor('Germany', 'A' * 13),
        'Postal Code looks too long',
      );
    });
  });

  group('PostalCodeRule.validateFor — empty value', () {
    test('required countries reject blank, naming their own label', () {
      expect(PostalCodeRule.validateFor('India', ''), 'PIN Code is required');
      expect(
        PostalCodeRule.validateFor('United Kingdom', '  '),
        'Postcode is required',
      );
    });

    // Without this a UAE merchant could never finish onboarding — there is no
    // postal code for them to type.
    test('blank is valid where the country has no postal code', () {
      expect(PostalCodeRule.validateFor('United Arab Emirates', ''), isNull);
      expect(PostalCodeRule.validateFor('Hong Kong', null), isNull);
    });
  });

  group('PostalCodeRule.maxLengthFor', () {
    test('India caps at 6', () {
      expect(PostalCodeRule.maxLengthFor('India'), 6);
    });

    test('elsewhere caps at 12 — fits ZIP+4, UK and Eircode formats', () {
      expect(PostalCodeRule.maxLengthFor('United Kingdom'), 12);
      expect(PostalCodeRule.maxLengthFor(''), 12);
      expect('90210-1234'.length, lessThanOrEqualTo(12));
      expect('SW1A 1AA'.length, lessThanOrEqualTo(12));
    });
  });
}
