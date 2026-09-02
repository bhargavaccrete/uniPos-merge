import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

/// `formatMoney` — the money formatter roughly fifteen report screens print
/// through, and which had no tests at all.
///
/// It is what a screen gets instead of hard-coding
/// `'${CurrencyHelper.currentSymbol}${x.toStringAsFixed(2)}'`: the live symbol
/// AND the store's configured decimal precision, rather than a symbol read once
/// and a fixed two places.
void main() {
  late String originalCurrency;
  late int originalPrecision;

  setUp(() {
    originalCurrency = CurrencyHelper.currencyNotifier.value;
    originalPrecision = DecimalSettings.precisionNotifier.value;
  });

  tearDown(() {
    CurrencyHelper.currencyNotifier.value = originalCurrency;
    DecimalSettings.precisionNotifier.value = originalPrecision;
  });

  group('currency symbol', () {
    test('uses the store\'s configured currency', () {
      CurrencyHelper.currencyNotifier.value = 'INR';
      DecimalSettings.precisionNotifier.value = 2;
      expect(formatMoney(1234.5), '₹1234.50');

      // The whole point of going through the helper: change the setting and
      // every printed amount follows, with no screen edit.
      CurrencyHelper.currencyNotifier.value = 'USD';
      expect(formatMoney(1234.5), '\$1234.50');
    });

    test('an unknown currency code falls back to the rupee', () {
      CurrencyHelper.currencyNotifier.value = 'ZZZ';
      DecimalSettings.precisionNotifier.value = 2;
      expect(formatMoney(10), '₹10.00');
    });
  });

  group('decimal precision', () {
    test('honours a precision of 0', () {
      CurrencyHelper.currencyNotifier.value = 'INR';
      DecimalSettings.precisionNotifier.value = 0;
      // A hard-coded `toStringAsFixed(2)` printed "₹1235.00" here.
      expect(formatMoney(1234.5), '₹1235');
    });

    test('honours a precision of 3', () {
      CurrencyHelper.currencyNotifier.value = 'INR';
      DecimalSettings.precisionNotifier.value = 3;
      expect(formatMoney(1234.5), '₹1234.500');
    });

    test('two places is the ordinary case', () {
      CurrencyHelper.currencyNotifier.value = 'INR';
      DecimalSettings.precisionNotifier.value = 2;
      expect(formatMoney(1234.5), '₹1234.50');
      expect(formatMoney(0), '₹0.00');
    });
  });

  group('values', () {
    setUp(() {
      CurrencyHelper.currencyNotifier.value = 'INR';
      DecimalSettings.precisionNotifier.value = 2;
    });

    test('a negative amount keeps its sign in front of the symbol', () {
      // Worth pinning: screens that want "-₹50" have to build it themselves.
      expect(formatMoney(-50), '₹-50.00');
    });

    test('rounds to the configured precision rather than truncating', () {
      expect(formatMoney(18.056), '₹18.06');
      expect(formatMoney(18.054), '₹18.05');
    });

    test('an exact half rounds by the BINARY value, not the decimal one', () {
      // 18.055 is stored slightly below 18.055, so `toStringAsFixed` gives
      // 18.05 — not 18.06. Pinned because it is surprising, and because any
      // report reconciling to the paisa has to expect it.
      expect(formatMoney(18.055), '₹18.05');
    });

    test('float noise does not leak into the output', () {
      expect(formatMoney(0.1 + 0.2), '₹0.30');
    });

    test('there is NO thousands separator', () {
      // Documented, not endorsed: `formatAmountWithSymbol` is
      // `symbol + toStringAsFixed(n)`. Any screen expecting grouped digits is
      // expecting something this helper does not do.
      expect(formatMoney(1234567.89), '₹1234567.89');
    });
  });
}
