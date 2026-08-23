import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';

/// The supplier balance journal.
///
/// `SupplierModel.currentBalance` used to be a running total with nothing
/// behind it. Four of the five things that moved it left a document; the fifth
/// — the old "Update Balance" dialog, through which every payment went — left
/// nothing. Any ledger rebuilt from documents would therefore have disagreed
/// with the Outstanding figure printed above it.
///
/// The assertion that matters here is the **reconciliation identity**: the
/// Overview tab's buckets must sum to the closing balance. That is what makes
/// the number trustworthy, so it is checked in every scenario.
void main() {
  /// Build a journal the way `recordBalanceMovement` does — each row carries
  /// the balance as it stood immediately after that movement.
  List<SupplierLedgerEntryModel> journal(
    List<(SupplierLedgerType, double, String)> movements,
  ) {
    var balance = 0.0;
    var day = 0;
    return movements.map((m) {
      final (type, amount, label) = m;
      balance += amount;
      day++;
      return SupplierLedgerEntryModel.create(
        supplierId: 's-1',
        type: type,
        amount: amount,
        balanceAfter: balance,
        description: label,
        // Fixed, ordered dates — the summary sorts by date to find the close.
        date: DateTime(2026, 8, day).toIso8601String(),
      );
    }).toList();
  }

  /// buckets must equal the close, or the Overview tab is lying.
  void expectReconciles(SupplierAccountSummary s) {
    final sum =
        s.opening +
        s.purchases +
        s.returnCredits +
        s.claimCredits +
        s.payments +
        s.adjustments;
    expect(
      sum,
      closeTo(s.closing, 0.001),
      reason: 'buckets must add up to the closing balance',
    );
  }

  group('Running balance', () {
    test('opening → purchase → credits → payment chains correctly', () {
      final entries = journal([
        (SupplierLedgerType.opening, 5000, 'Opening balance'),
        (SupplierLedgerType.purchase, 20000, 'GRN-002'),
        (SupplierLedgerType.returnCredit, -3000, 'PR-001'),
        (SupplierLedgerType.claimCredit, -1000, 'CLM-001'),
        (SupplierLedgerType.payment, -10000, 'Payment (UPI)'),
      ]);

      expect(
        entries.map((e) => e.balanceAfter).toList(),
        [5000.0, 25000.0, 22000.0, 21000.0, 11000.0],
      );
    });

    test('signs: purchases owe more, credits and payments owe less', () {
      final entries = journal([
        (SupplierLedgerType.purchase, 20000, 'GRN-002'),
        (SupplierLedgerType.returnCredit, -3000, 'PR-001'),
        (SupplierLedgerType.claimCredit, -1000, 'CLM-001'),
        (SupplierLedgerType.payment, -10000, 'Payment'),
      ]);

      expect(entries[0].isDebit, isTrue);
      expect(entries.skip(1).every((e) => e.isDebit), isFalse);
    });
  });

  group('summariseLedger', () {
    test('buckets each type and reconciles to the close', () {
      final s = summariseLedger(
        journal([
          (SupplierLedgerType.opening, 5000, 'Opening'),
          (SupplierLedgerType.purchase, 20000, 'GRN-002'),
          (SupplierLedgerType.purchase, 10000, 'GRN-003'),
          (SupplierLedgerType.returnCredit, -3000, 'PR-001'),
          (SupplierLedgerType.claimCredit, -1000, 'CLM-001'),
          (SupplierLedgerType.payment, -20000, 'Payment'),
        ]),
      );

      expect(s.opening, 5000);
      expect(s.purchases, 30000);
      expect(s.returnCredits, -3000);
      expect(s.claimCredits, -1000);
      expect(s.payments, -20000);
      expect(s.adjustments, 0);
      expect(s.closing, 11000);
      expect(s.totalCredits, -4000);
      expectReconciles(s);
    });

    test('adjustments land in their own bucket, not in payments', () {
      // A correction is not money that left the business. Folding it into
      // payments would overstate what was actually paid.
      final s = summariseLedger(
        journal([
          (SupplierLedgerType.purchase, 10000, 'GRN-001'),
          (SupplierLedgerType.payment, -6000, 'Payment'),
          (SupplierLedgerType.adjustment, -500, 'Correction'),
        ]),
      );

      expect(s.payments, -6000);
      expect(s.adjustments, -500);
      expect(s.closing, 3500);
      expectReconciles(s);
    });

    test('over-payment reports as an advance, not a payable', () {
      final s = summariseLedger(
        journal([
          (SupplierLedgerType.purchase, 10000, 'GRN-001'),
          (SupplierLedgerType.payment, -12000, 'Payment'),
        ]),
      );

      expect(s.closing, -2000);
      expect(s.isAdvance, isTrue);
      expectReconciles(s);
    });

    test('an empty journal summarises to zero', () {
      final s = summariseLedger([]);

      expect(s.isEmpty, isTrue);
      expect(s.closing, 0);
      expectReconciles(s);
    });

    test('buckets are order-independent, the close is not', () {
      // Overview may receive entries newest-first from the display list, so
      // shuffling must not change the totals — and the close must still come
      // from the chronologically last row, not the last in the list.
      final entries = journal([
        (SupplierLedgerType.opening, 5000, 'Opening'),
        (SupplierLedgerType.purchase, 20000, 'GRN-002'),
        (SupplierLedgerType.payment, -14000, 'Payment'),
      ]);

      final forward = summariseLedger(entries);
      final reversed = summariseLedger(entries.reversed.toList());

      expect(reversed.purchases, forward.purchases);
      expect(reversed.payments, forward.payments);
      expect(reversed.closing, 11000);
      expectReconciles(reversed);
    });

    test('a settled claim credit is bucketed apart from a return credit', () {
      // Both reduce the balance, but they came back through different routes
      // and the Overview tab names each one.
      final s = summariseLedger(
        journal([
          (SupplierLedgerType.purchase, 10000, 'GRN-001'),
          (SupplierLedgerType.returnCredit, -1000, 'PR-001'),
          (SupplierLedgerType.claimCredit, -2000, 'CLM-001'),
        ]),
      );

      expect(s.returnCredits, -1000);
      expect(s.claimCredits, -2000);
      expect(s.totalCredits, -3000);
      expectReconciles(s);
    });
  });

  group('Entry display', () {
    test('type survives the round trip through its stored string', () {
      final entry = SupplierLedgerEntryModel.create(
        supplierId: 's-1',
        type: SupplierLedgerType.claimCredit,
        amount: -1000,
        balanceAfter: 9000,
        description: 'Claim settled',
      );

      expect(entry.type, 'claimCredit');
      expect(entry.typeEnum, SupplierLedgerType.claimCredit);
      expect(entry.typeDisplay, 'Claim Credit');
    });

    test('an unknown stored type degrades to adjustment', () {
      // Defensive: a row written by a future version must still render.
      final entry = SupplierLedgerEntryModel.fromMap({
        'entryId': 'e-1',
        'supplierId': 's-1',
        'date': '2026-08-01T00:00:00.000',
        'type': 'somethingNew',
        'amount': -100.0,
        'balanceAfter': 900.0,
        'description': 'Future entry',
        'createdAt': '2026-08-01T00:00:00.000',
      });

      expect(entry.typeEnum, SupplierLedgerType.adjustment);
    });
  });
}
