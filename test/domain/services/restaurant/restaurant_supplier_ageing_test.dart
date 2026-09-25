import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';

/// **FIFO AGEING OF A RUNNING-BALANCE LEDGER.**
///
/// The supplier journal records movements, not open items: it knows a supplier
/// is owed 12,400 but not how overdue any of it is. `ageRestaurantSupplierLedger`
/// derives that by treating positive rows as invoices and letting negative rows
/// pay off the **oldest one first**.
///
/// The assertion that matters most is the **invariant**:
///
/// ```
/// b0_30 + b31_60 + b61_90 + b90plus - unappliedCredit  ==  currentBalance
/// ```
///
/// If ageing and the stored balance ever disagree, the ledger has drifted —
/// exactly what the supplier Overview reconciliation banner exists to surface.
/// Ageing must never quietly paper over it, so every scenario below closes the
/// identity explicitly.
void main() {
  final asOf = DateTime(2026, 6, 30);

  /// Days before [asOf].
  DateTime ago(int days) => asOf.subtract(Duration(days: days));

  var seq = 0;
  RestaurantSupplierLedgerEntryModel entry(
    RestaurantSupplierLedgerType type,
    double amount,
    DateTime at, {
    double balanceAfter = 0,
  }) {
    seq++;
    return RestaurantSupplierLedgerEntryModel(
      entryId: 'E$seq',
      supplierId: 'SUP-A',
      date: at.toIso8601String(),
      type: type.name,
      amount: amount,
      balanceAfter: balanceAfter,
      description: type.name,
      createdAt: at.toIso8601String(),
      seq: seq,
    );
  }

  setUp(() => seq = 0);

  /// The invariant, asserted the same way every time.
  void expectReconciles(
    ({
      double b0_30,
      double b31_60,
      double b61_90,
      double b90plus,
      DateTime? oldestOpen,
      double unappliedCredit,
    }) aged,
    double expectedBalance,
  ) {
    final total = aged.b0_30 +
        aged.b31_60 +
        aged.b61_90 +
        aged.b90plus -
        aged.unappliedCredit;
    expect(total, closeTo(expectedBalance, 0.0001),
        reason: 'buckets must reconcile to the stored balance');
  }

  test('an unpaid invoice ages into its bucket', () {
    final aged = ageRestaurantSupplierLedger(
      [entry(RestaurantSupplierLedgerType.purchase, 5000, ago(45))],
      asOf,
    );

    expect(aged.b0_30, 0);
    expect(aged.b31_60, 5000);
    expect(aged.b61_90, 0);
    expect(aged.b90plus, 0);
    expect(aged.oldestOpen, ago(45));
    expectReconciles(aged, 5000);
  });

  test('bucket boundaries land at exactly 30, 60 and 90 days', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.purchase, 10, ago(30)),
        entry(RestaurantSupplierLedgerType.purchase, 20, ago(31)),
        entry(RestaurantSupplierLedgerType.purchase, 30, ago(60)),
        entry(RestaurantSupplierLedgerType.purchase, 40, ago(61)),
        entry(RestaurantSupplierLedgerType.purchase, 50, ago(90)),
        entry(RestaurantSupplierLedgerType.purchase, 60, ago(91)),
      ],
      asOf,
    );

    // 30 days is still "0-30"; 31 tips over.
    expect(aged.b0_30, 10);
    expect(aged.b31_60, 20 + 30);
    expect(aged.b61_90, 40 + 50);
    expect(aged.b90plus, 60);
    expectReconciles(aged, 210);
  });

  test('a payment consumes the OLDEST invoice first', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(100)),
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(10)),
        // Enough to clear the old one exactly.
        entry(RestaurantSupplierLedgerType.payment, -1000, ago(5)),
      ],
      asOf,
    );

    expect(aged.b90plus, 0, reason: 'the oldest invoice was settled');
    expect(aged.b0_30, 1000, reason: 'the recent one is still open');
    expect(aged.oldestOpen, ago(10));
    expectReconciles(aged, 1000);
  });

  test('a payment spanning two invoices part-settles the second', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(100)),
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(45)),
        entry(RestaurantSupplierLedgerType.payment, -1400, ago(2)),
      ],
      asOf,
    );

    expect(aged.b90plus, 0);
    expect(aged.b31_60, 600, reason: '1000 - the 400 that spilled over');
    expectReconciles(aged, 600);
  });

  test('return and claim credits age like payments', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(70)),
        entry(RestaurantSupplierLedgerType.returnCredit, -300, ago(20)),
        entry(RestaurantSupplierLedgerType.claimCredit, -200, ago(10)),
      ],
      asOf,
    );

    expect(aged.b61_90, 500);
    expectReconciles(aged, 500);
  });

  test('the worked example from the module doc reconciles', () {
    // opening +10,000 -> purchase +5,000 -> return -1,000 -> claim -500
    // -> payment -3,000 -> adjustment +200  =  10,700
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.opening, 10000, ago(120)),
        entry(RestaurantSupplierLedgerType.purchase, 5000, ago(50)),
        entry(RestaurantSupplierLedgerType.returnCredit, -1000, ago(40)),
        entry(RestaurantSupplierLedgerType.claimCredit, -500, ago(30)),
        entry(RestaurantSupplierLedgerType.payment, -3000, ago(20)),
        entry(RestaurantSupplierLedgerType.adjustment, 200, ago(5)),
      ],
      asOf,
    );

    expectReconciles(aged, 10700);
    // 4,500 of the opening survives the 4,500 of credits, and it is the
    // oldest thing on the account.
    expect(aged.b90plus, 5500);
    expect(aged.b31_60, 5000);
    expect(aged.b0_30, 200);
    expect(aged.oldestOpen, ago(120));
  });

  test('overpayment becomes an advance, not a negative bucket', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(40)),
        entry(RestaurantSupplierLedgerType.payment, -1500, ago(2)),
      ],
      asOf,
    );

    expect(aged.b0_30, 0);
    expect(aged.b31_60, 0);
    expect(aged.b61_90, 0);
    expect(aged.b90plus, 0);
    expect(aged.unappliedCredit, 500);
    expect(aged.oldestOpen, isNull);
    // A supplier who owes US money.
    expectReconciles(aged, -500);
  });

  test('an advance settles the next invoice before it can age', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.payment, -500, ago(60)),
        entry(RestaurantSupplierLedgerType.purchase, 800, ago(10)),
      ],
      asOf,
    );

    expect(aged.b0_30, 300, reason: '800 less the 500 already on account');
    expect(aged.unappliedCredit, 0);
    expectReconciles(aged, 300);
  });

  test('a negative adjustment is a credit, a positive one an invoice', () {
    final aged = ageRestaurantSupplierLedger(
      [
        entry(RestaurantSupplierLedgerType.purchase, 1000, ago(80)),
        entry(RestaurantSupplierLedgerType.adjustment, -200, ago(70)),
        entry(RestaurantSupplierLedgerType.adjustment, 300, ago(5)),
      ],
      asOf,
    );

    expect(aged.b61_90, 800);
    expect(aged.b0_30, 300);
    expectReconciles(aged, 1100);
  });

  test('an undateable row is skipped rather than crashing', () {
    final broken = RestaurantSupplierLedgerEntryModel(
      entryId: 'BAD',
      supplierId: 'SUP-A',
      date: 'not-a-date',
      type: RestaurantSupplierLedgerType.purchase.name,
      amount: 999,
      balanceAfter: 999,
      description: 'broken',
      createdAt: 'not-a-date',
    );

    final aged = ageRestaurantSupplierLedger(
      [broken, entry(RestaurantSupplierLedgerType.purchase, 100, ago(10))],
      asOf,
    );

    expect(aged.b0_30, 100, reason: 'the good row still ages');
  });

  test('an empty ledger ages to nothing', () {
    final aged = ageRestaurantSupplierLedger([], asOf);
    expect(aged.b0_30, 0);
    expect(aged.unappliedCredit, 0);
    expect(aged.oldestOpen, isNull);
    expectReconciles(aged, 0);
  });
}
