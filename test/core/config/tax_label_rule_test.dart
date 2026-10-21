import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';

/// Pure tests — only the `*For(country)` forms are exercised, the same split
/// `food_license_rule_test.dart` uses. The zero-arg getters read Hive through
/// the service locator; they are covered by `gst_report_country_test.dart`.
///
/// What this rule protects: the retail tax screens were written India-first and
/// hard-coded "GST", "CGST" and "SGST". A UK shop selling at 20% VAT was shown
/// two invented sub-taxes of 10% each under Indian names.
void main() {
  group('TaxLabelRule.nameFor', () {
    test('India is GST', () {
      expect(TaxLabelRule.nameFor('India'), 'GST');
    });

    test('United States is Sales Tax', () {
      expect(TaxLabelRule.nameFor('United States'), 'Sales Tax');
    });

    test('United Kingdom and every EU-27 member are VAT', () {
      const vatCountries = [
        'United Kingdom',
        'Austria',
        'Belgium',
        'Bulgaria',
        'Croatia (Hrvatska)',
        'Cyprus',
        'Czech Republic',
        'Denmark',
        'Estonia',
        'Finland',
        'France',
        'Germany',
        'Greece',
        'Hungary',
        'Ireland',
        'Italy',
        'Latvia',
        'Lithuania',
        'Luxembourg',
        'Malta',
        'Netherlands The',
        'Poland',
        'Romania',
        'Slovakia',
        'Slovenia',
        'Spain',
        'Sweden',
      ];
      for (final country in vatCountries) {
        expect(TaxLabelRule.nameFor(country), 'VAT', reason: country);
      }
    });

    test('an unlisted country gets the generic name', () {
      // A wrong-but-specific name is worse than a correct-but-plain one.
      for (final country in ['Brazil', 'Japan', 'Nepal', 'Kenya']) {
        expect(TaxLabelRule.nameFor(country), 'Tax', reason: country);
      }
    });

    test('an UNSET country reads as India', () {
      // India-first, matching PhoneRule and TariffCodeRule: a shop still in
      // setup keeps the behaviour it has always had.
      expect(TaxLabelRule.nameFor(null), 'GST');
      expect(TaxLabelRule.nameFor(''), 'GST');
      expect(TaxLabelRule.nameFor('   '), 'GST');
    });

    test('case and surrounding whitespace are ignored', () {
      expect(TaxLabelRule.nameFor('  india  '), 'GST');
      expect(TaxLabelRule.nameFor('INDIA'), 'GST');
      expect(TaxLabelRule.nameFor('united KINGDOM'), 'VAT');
      expect(TaxLabelRule.nameFor(' United States '), 'Sales Tax');
    });
  });

  group('TaxLabelRule lookup is exact-match, never substring', () {
    test('United States Minor Outlying Islands is NOT the United States', () {
      // country.json carries both. A `contains` test would give this territory
      // the USA's "Sales Tax" label.
      expect(
        TaxLabelRule.nameFor('United States Minor Outlying Islands'),
        'Tax',
      );
    });

    test('Netherlands Antilles is NOT the Netherlands', () {
      expect(TaxLabelRule.nameFor('Netherlands Antilles'), 'Tax');
    });

    test('a country whose name merely contains "india" is not India', () {
      // British Indian Ocean Territory — a substring test would make it India,
      // which would wrongly switch the CGST/SGST split back on.
      expect(TaxLabelRule.nameFor('British Indian Ocean Territory'), 'Tax');
      expect(
        TaxLabelRule.isIndiaFor('British Indian Ocean Territory'),
        isFalse,
      );
      expect(
        TaxLabelRule.splitsIntoComponentsFor('British Indian Ocean Territory'),
        isFalse,
      );
    });
  });

  group('TaxLabelRule.splitsIntoComponentsFor', () {
    test('only India splits', () {
      expect(TaxLabelRule.splitsIntoComponentsFor('India'), isTrue);
      for (final country in [
        'United Kingdom',
        'United States',
        'Germany',
        'Brazil',
      ]) {
        expect(
          TaxLabelRule.splitsIntoComponentsFor(country),
          isFalse,
          reason: country,
        );
      }
    });

    test('an unset country splits, following the India-first default', () {
      expect(TaxLabelRule.splitsIntoComponentsFor(null), isTrue);
      expect(TaxLabelRule.splitsIntoComponentsFor(''), isTrue);
    });
  });

  group('TaxLabelRule.componentsFor', () {
    test('India is CGST + SGST', () {
      final parts = TaxLabelRule.componentsFor('India');
      expect(parts, isNotNull);
      expect(parts!.first, 'CGST');
      expect(parts.second, 'SGST');
    });

    test('an unset country gets India components', () {
      expect(TaxLabelRule.componentsFor(null)?.first, 'CGST');
    });

    test('everywhere else is NULL, not an empty pair', () {
      // Null is what stops a caller rendering the halves by accident — there is
      // no pair to print, so there is nothing to print it with.
      for (final country in ['United Kingdom', 'United States', 'Brazil']) {
        expect(TaxLabelRule.componentsFor(country), isNull, reason: country);
      }
    });
  });

  group('TaxLabelRule.reportTitleFor', () {
    test('title carries the country tax name', () {
      expect(TaxLabelRule.reportTitleFor('India'), 'GST Report');
      expect(TaxLabelRule.reportTitleFor('United Kingdom'), 'VAT Report');
      expect(TaxLabelRule.reportTitleFor('United States'), 'Sales Tax Report');
      expect(TaxLabelRule.reportTitleFor('Brazil'), 'Tax Report');
      expect(TaxLabelRule.reportTitleFor(null), 'GST Report');
    });
  });
}
