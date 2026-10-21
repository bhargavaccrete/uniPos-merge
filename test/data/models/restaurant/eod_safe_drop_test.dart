import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';

/// The safe-drop contract on the close record.
///
/// Before this, the amount taken out of the till at close was stored nowhere
/// structured — it survived only as free text in a cash-movement note, which is
/// why the settlement reprint printed a withdrawal of 0. These lock the two
/// things the rest of the app now relies on: the figure round-trips, and the
/// amount LEFT is derived from the COUNTED cash rather than the expected cash.
void main() {
  EndOfDayReport report({
    required double counted,
    required double expected,
    double withdrawn = 0,
  }) =>
      EndOfDayReport(
        reportId: 'r1',
        date: DateTime(2026, 9, 7),
        openingBalance: 1000,
        orderSummaries: const [],
        totalDiscount: 0,
        totalTax: 0,
        categorySales: const [],
        paymentSummaries: const [],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: expected,
          actualCash: counted,
          difference: counted - expected,
          reconciliationStatus: 'Balanced',
        ),
        totalSales: 0,
        closingBalance: expected,
        taxSummaries: const [],
        totalOrderCount: 0,
        totalRefunds: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        mode: 'retail',
        cashWithdrawn: withdrawn,
      );

  group('cashKept', () {
    test('is the counted cash minus what was taken to the safe', () {
      final r = report(counted: 9180, expected: 9200, withdrawn: 8180);
      expect(r.cashKept, 1000);
    });

    test('equals the full count when nothing is withdrawn', () {
      final r = report(counted: 9180, expected: 9200);
      expect(r.cashWithdrawn, 0);
      expect(r.cashKept, 9180);
    });

    test('is zero when the whole drawer is taken', () {
      final r = report(counted: 9180, expected: 9200, withdrawn: 9180);
      expect(r.cashKept, 0);
    });

    test('derives from the COUNTED cash, not the expected cash', () {
      // A day that came up 20 short. The float left behind is measured against
      // what is physically there — using closingBalance here would carry money
      // to tomorrow that nobody counted.
      final r = report(counted: 9180, expected: 9200, withdrawn: 8180);
      expect(r.closingBalance, 9200);
      expect(r.cashKept, isNot(r.closingBalance - r.cashWithdrawn));
      expect(r.cashKept, r.cashReconciliation.actualCash - r.cashWithdrawn);
    });
  });

  group('persistence', () {
    test('cashWithdrawn survives a map round-trip', () {
      final restored = EndOfDayReport.fromMap(
        report(counted: 9180, expected: 9200, withdrawn: 8180).toMap(),
      );
      expect(restored.cashWithdrawn, 8180);
      expect(restored.cashKept, 1000);
    });

    test('a record written before safe drop existed reads back as 0', () {
      final map = report(counted: 500, expected: 500).toMap()
        ..remove('cashWithdrawn');
      final restored = EndOfDayReport.fromMap(map);
      expect(restored.cashWithdrawn, 0);
      expect(restored.cashKept, 500);
    });
  });

  group('reconciliation figures agree with each other', () {
    test('actual - expected equals the stored difference', () {
      // The stored `systemExpectedCash` used to be cash SALES only while
      // `difference` was measured against the full expectation, so the two
      // never reconciled on screen once there was a float or an expense.
      final r = report(counted: 9180, expected: 9200);
      final recon = r.cashReconciliation;
      expect(
        recon.actualCash - recon.systemExpectedCash,
        closeTo(recon.difference, 0.001),
      );
    });
  });
}
