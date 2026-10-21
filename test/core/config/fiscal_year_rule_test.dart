import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/config/fiscal_year_rule.dart';

/// Pure date arithmetic over a country name — no Hive, no DI.
void main() {
  group('India — 1 April', () {
    test('31 March still belongs to the year that began last April', () {
      expect(FiscalYearRule.keyFor('India', DateTime(2027, 3, 31)), '2026-27');
      expect(
        FiscalYearRule.startOfFor('India', DateTime(2027, 3, 31)),
        DateTime(2026, 4, 1),
      );
    });

    test('1 April starts the new year — the moment the series resets', () {
      expect(FiscalYearRule.keyFor('India', DateTime(2027, 4, 1)), '2027-28');
      expect(
        FiscalYearRule.startOfFor('India', DateTime(2027, 4, 1)),
        DateTime(2027, 4, 1),
      );
    });

    test('a date mid-year reads as its own span', () {
      expect(FiscalYearRule.keyFor('India', DateTime(2026, 9, 7)), '2026-27');
    });

    test('the reset is worded for the settings screen', () {
      expect(FiscalYearRule.resetLabelFor('India'), '1 April');
    });
  });

  group('other countries', () {
    test('a calendar-year country gets a plain year, not a span', () {
      // A hyphenated span would imply a straddle that never happens there.
      expect(FiscalYearRule.keyFor('Germany', DateTime(2026, 9, 7)), '2026');
      expect(FiscalYearRule.startMonthFor('Germany'), 1);
      expect(FiscalYearRule.resetLabelFor('United States'), '1 January');
    });

    test('Australia turns over on 1 July', () {
      expect(FiscalYearRule.keyFor('Australia', DateTime(2026, 6, 30)), '2025-26');
      expect(FiscalYearRule.keyFor('Australia', DateTime(2026, 7, 1)), '2026-27');
    });

    test('an unrecognised country falls back to the calendar year', () {
      expect(FiscalYearRule.startMonthFor('Narnia'), 1);
    });
  });

  group('unset country', () {
    test('reads as India, matching the app default', () {
      for (final unset in <String?>[null, '', '   ']) {
        expect(FiscalYearRule.startMonthFor(unset), 4, reason: 'for "$unset"');
        expect(FiscalYearRule.keyFor(unset, DateTime(2026, 9, 7)), '2026-27');
      }
    });
  });

  group('the year token', () {
    test('pads a single-digit end year', () {
      // 2009-10, never 2009-1.
      expect(FiscalYearRule.keyFor('India', DateTime(2009, 5, 1)), '2009-10');
      expect(FiscalYearRule.keyFor('India', DateTime(2099, 5, 1)), '2099-00');
    });
  });
}
