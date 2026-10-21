import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

/// Pure map lookup — no prefs, no Hive.
void main() {
  group('CurrencyHelper.currencyCodeForCountry', () {
    const expected = <String, String>{
      'India': 'INR',
      'United Kingdom': 'GBP',
      'United States': 'USD',
      'Canada': 'CAD',
      'Australia': 'AUD',
      'Singapore': 'SGD',
      'United Arab Emirates': 'AED',
    };

    expected.forEach((country, code) {
      test('$country -> $code', () {
        expect(CurrencyHelper.currencyCodeForCountry(country), code);
      });
    });

    test('every mapped code exists in the currencies table', () {
      for (final code in expected.values) {
        expect(CurrencyHelper.currencies.containsKey(code), isTrue,
            reason: '$code is mapped but has no CurrencyInfo');
      }
    });

    test('lookup is exact-match, not substring', () {
      // country.json carries this alongside "United States"; a `contains`
      // check would wrongly resolve it to USD.
      expect(
        CurrencyHelper.currencyCodeForCountry(
            'United States Minor Outlying Islands'),
        isNull,
      );
    });

    test('unknown country returns null rather than guessing', () {
      for (final c in ['Nepal', 'Portugal', 'Fiji']) {
        expect(CurrencyHelper.currencyCodeForCountry(c), isNull);
      }
    });

    test('null / empty / whitespace return null', () {
      expect(CurrencyHelper.currencyCodeForCountry(null), isNull);
      expect(CurrencyHelper.currencyCodeForCountry(''), isNull);
      expect(CurrencyHelper.currencyCodeForCountry('   '), isNull);
    });

    test('case and surrounding whitespace are ignored', () {
      expect(CurrencyHelper.currencyCodeForCountry('  india  '), 'INR');
      expect(CurrencyHelper.currencyCodeForCountry('UNITED KINGDOM'), 'GBP');
    });
  });
}
