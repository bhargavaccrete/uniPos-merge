import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';

/// PHASE 2 — RESTAURANT SUPPLIER LEDGER (pure/model layer)
///
/// Covers the accounting contract itself: the sign convention, the running
/// balance, and the reconciliation identity
/// `opening + purchases + returnCredits + claimCredits + payments + adjustments
/// == closing`.
///
/// `RestaurantSupplierStore.recordBalanceMovement` reads `itemStore`-style
/// GetIt singletons and needs a Hive harness, so the store-level behaviour is
/// exercised in `test/integration/restaurant_supplier_ledger_test.dart`. What
/// lives here is the arithmetic that has to add up, driven through the same
/// `summariseRestaurantLedger` the Overview tab calls.
void main() {
  RestaurantSupplierLedgerEntryModel entry({
    required RestaurantSupplierLedgerType type,
    required double amount,
    required double balanceAfter,
    String date = '2026-01-01T00:00:00.000',
    String supplierId = 'sup-1',
    String description = 'x',
    String? docNumber,
    String? paymentMode,
  }) {
    return RestaurantSupplierLedgerEntryModel(
      entryId: 'e-${type.name}-$amount-$date',
      supplierId: supplierId,
      date: date,
      type: type.name,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description,
      docNumber: docNumber,
      paymentMode: paymentMode,
      createdAt: date,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUPPLIER MODEL + OPENING BALANCE
  // ══════════════════════════════════════════════════════════════════════════

  group('RestaurantSupplierModel', () {
    test('round-trips through toMap/fromMap with every field intact', () {
      final original = RestaurantSupplierModel(
        supplierId: 'sup-1',
        name: 'Fresh Farms',
        phone: '9876543210',
        address: '12 Market Road',
        gstNumber: '29ABCDE1234F1Z5',
        currentBalance: 1250.50,
        openingBalance: 500,
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-02T00:00:00.000',
      );

      final restored = RestaurantSupplierModel.fromMap(original.toMap());

      expect(restored.supplierId, 'sup-1');
      expect(restored.name, 'Fresh Farms');
      expect(restored.phone, '9876543210');
      expect(restored.address, '12 Market Road');
      expect(restored.gstNumber, '29ABCDE1234F1Z5');
      expect(restored.currentBalance, 1250.50);
      expect(restored.openingBalance, 500);
      expect(restored.createdAt, '2026-01-01T00:00:00.000');
      expect(restored.updatedAt, '2026-01-02T00:00:00.000');
    });

    test('a map without openingBalance (pre-upgrade backup) reads as 0', () {
      final map = RestaurantSupplierModel(
        supplierId: 'sup-1',
        name: 'Old Supplier',
        currentBalance: 900,
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      ).toMap()
        ..remove('openingBalance');

      final restored = RestaurantSupplierModel.fromMap(map);

      expect(restored.openingBalance, 0);
      expect(restored.currentBalance, 900,
          reason: 'the standing balance must survive untouched');
    });

    test('.create() with an opening balance starts currentBalance equal to it', () {
      final s = RestaurantSupplierModel.create(
          name: 'Fresh Farms', openingBalance: 750);

      expect(s.openingBalance, 750);
      expect(s.currentBalance, 750,
          reason: 'a supplier owes exactly what they walked in owing');
    });

    test('.create() with no opening balance starts at zero', () {
      final s = RestaurantSupplierModel.create(name: 'New Supplier');

      expect(s.openingBalance, 0);
      expect(s.currentBalance, 0);
    });

    test('copyWith carries openingBalance forward untouched', () {
      final s = RestaurantSupplierModel.create(
          name: 'Fresh Farms', openingBalance: 400);
      final moved = s.copyWith(currentBalance: 1000);

      expect(moved.openingBalance, 400);
      expect(moved.currentBalance, 1000);
    });

    test('clear flags null out optional contact fields', () {
      final s = RestaurantSupplierModel.create(
        name: 'Fresh Farms',
        phone: '999',
        address: 'Somewhere',
        gstNumber: 'GST1',
      );

      final cleared = s.copyWith(
        clearPhone: true,
        clearAddress: true,
        clearGstNumber: true,
      );

      expect(cleared.phone, isNull);
      expect(cleared.address, isNull);
      expect(cleared.gstNumber, isNull);
      expect(cleared.name, 'Fresh Farms');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LEDGER ENTRY
  // ══════════════════════════════════════════════════════════════════════════

  group('RestaurantSupplierLedgerEntryModel', () {
    test('round-trips through toMap/fromMap with every field intact', () {
      final original = RestaurantSupplierLedgerEntryModel(
        entryId: 'e-1',
        supplierId: 'sup-1',
        date: '2026-02-01T10:00:00.000',
        type: RestaurantSupplierLedgerType.payment.name,
        amount: -500,
        balanceAfter: 750,
        description: 'Payment to supplier',
        docNumber: 'GRN-001',
        docId: 'grn-1',
        paymentMode: 'UPI',
        referenceNo: 'UTR12345',
        note: 'Part settlement',
        createdAt: '2026-02-01T10:05:00.000',
      );

      final restored =
          RestaurantSupplierLedgerEntryModel.fromMap(original.toMap());

      expect(restored.entryId, 'e-1');
      expect(restored.supplierId, 'sup-1');
      expect(restored.date, '2026-02-01T10:00:00.000');
      expect(restored.typeEnum, RestaurantSupplierLedgerType.payment);
      expect(restored.amount, -500);
      expect(restored.balanceAfter, 750);
      expect(restored.description, 'Payment to supplier');
      expect(restored.docNumber, 'GRN-001');
      expect(restored.docId, 'grn-1');
      expect(restored.paymentMode, 'UPI');
      expect(restored.referenceNo, 'UTR12345');
      expect(restored.note, 'Part settlement');
      expect(restored.createdAt, '2026-02-01T10:05:00.000');
    });

    test('every movement type survives the round-trip', () {
      for (final type in RestaurantSupplierLedgerType.values) {
        final e = RestaurantSupplierLedgerEntryModel.create(
          supplierId: 'sup-1',
          type: type,
          amount: 100,
          balanceAfter: 100,
          description: type.name,
        );
        final restored =
            RestaurantSupplierLedgerEntryModel.fromMap(e.toMap());
        expect(restored.typeEnum, type, reason: '${type.name} must survive');
      }
    });

    test('an unknown type string degrades to adjustment rather than throwing', () {
      final e = entry(
        type: RestaurantSupplierLedgerType.payment,
        amount: -10,
        balanceAfter: 0,
      );
      final weird = RestaurantSupplierLedgerEntryModel.fromMap(
          e.toMap()..['type'] = 'someFutureType');

      expect(weird.typeEnum, RestaurantSupplierLedgerType.adjustment);
    });

    test('isDebit marks what increased the payable', () {
      expect(
          entry(
                  type: RestaurantSupplierLedgerType.purchase,
                  amount: 1000,
                  balanceAfter: 1000)
              .isDebit,
          isTrue);
      expect(
          entry(
                  type: RestaurantSupplierLedgerType.payment,
                  amount: -1000,
                  balanceAfter: 0)
              .isDebit,
          isFalse);
    });

    test('typeDisplay is set for every movement type', () {
      for (final type in RestaurantSupplierLedgerType.values) {
        final label =
            entry(type: type, amount: 1, balanceAfter: 1).typeDisplay;
        expect(label, isNotEmpty);
        expect(label, isNot(type.name),
            reason: '$type should have a human label');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // SIGN CONVENTION
  //
  // Positive balance = money owed TO the supplier.
  // ══════════════════════════════════════════════════════════════════════════

  group('sign convention', () {
    test('a GRN increases the payable', () {
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 5000,
            balanceAfter: 5000),
      ]);

      expect(summary.purchases, 5000);
      expect(summary.closing, 5000);
    });

    test('a return credit reduces the payable', () {
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 5000,
            balanceAfter: 5000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.returnCredit,
            amount: -800,
            balanceAfter: 4200,
            date: '2026-01-02T00:00:00.000'),
      ]);

      expect(summary.returnCredits, -800);
      expect(summary.closing, 4200);
    });

    test('a claim credit reduces the payable', () {
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 5000,
            balanceAfter: 5000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.claimCredit,
            amount: -300,
            balanceAfter: 4700,
            date: '2026-01-02T00:00:00.000'),
      ]);

      expect(summary.claimCredits, -300);
      expect(summary.closing, 4700);
    });

    test('a payment reduces the payable', () {
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 5000,
            balanceAfter: 5000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.payment,
            amount: -2000,
            balanceAfter: 3000,
            date: '2026-01-03T00:00:00.000'),
      ]);

      expect(summary.payments, -2000);
      expect(summary.closing, 3000);
    });

    test('an adjustment moves in either direction', () {
      final down = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.adjustment,
            amount: -250,
            balanceAfter: -250),
      ]);
      final up = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.adjustment,
            amount: 250,
            balanceAfter: 250),
      ]);

      expect(down.adjustments, -250);
      expect(down.closing, -250);
      expect(up.adjustments, 250);
      expect(up.closing, 250);
    });

    test('overpaying flips the account into an advance', () {
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 1000,
            balanceAfter: 1000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.payment,
            amount: -1500,
            balanceAfter: -500,
            date: '2026-01-02T00:00:00.000'),
      ]);

      expect(summary.closing, -500);
      expect(summary.isAdvance, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // RUNNING BALANCE & RECONCILIATION
  // ══════════════════════════════════════════════════════════════════════════

  group('summariseRestaurantLedger', () {
    test('an empty ledger summarises to all-zero and isEmpty', () {
      final summary = summariseRestaurantLedger([]);

      expect(summary.isEmpty, isTrue);
      expect(summary.closing, 0);
    });

    test('the full PO → GRN → return → claim → payment cycle reconciles', () {
      // Opening 1,000 · GRN +10,000 · return −1,200 · claim −800 · pay −5,000
      final ledger = [
        entry(
            type: RestaurantSupplierLedgerType.opening,
            amount: 1000,
            balanceAfter: 1000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 10000,
            balanceAfter: 11000,
            date: '2026-01-05T00:00:00.000',
            docNumber: 'GRN-001'),
        entry(
            type: RestaurantSupplierLedgerType.returnCredit,
            amount: -1200,
            balanceAfter: 9800,
            date: '2026-01-07T00:00:00.000',
            docNumber: 'PR-001'),
        entry(
            type: RestaurantSupplierLedgerType.claimCredit,
            amount: -800,
            balanceAfter: 9000,
            date: '2026-01-09T00:00:00.000',
            docNumber: 'CLM-001'),
        entry(
            type: RestaurantSupplierLedgerType.payment,
            amount: -5000,
            balanceAfter: 4000,
            date: '2026-01-11T00:00:00.000',
            paymentMode: 'Bank'),
      ];

      final summary = summariseRestaurantLedger(ledger);

      expect(summary.opening, 1000);
      expect(summary.purchases, 10000);
      expect(summary.returnCredits, -1200);
      expect(summary.claimCredits, -800);
      expect(summary.payments, -5000);
      expect(summary.adjustments, 0);
      expect(summary.closing, 4000);
      expect(summary.totalCredits, -2000);

      // The identity that makes the Outstanding figure trustworthy.
      expect(summary.impliedClosing, closeTo(summary.closing, 1e-9));
    });

    test('closing comes from the newest entry regardless of input order', () {
      final shuffled = [
        entry(
            type: RestaurantSupplierLedgerType.payment,
            amount: -5000,
            balanceAfter: 4000,
            date: '2026-01-11T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.opening,
            amount: 1000,
            balanceAfter: 1000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 8000,
            balanceAfter: 9000,
            date: '2026-01-05T00:00:00.000'),
      ];

      expect(summariseRestaurantLedger(shuffled).closing, 4000);
    });

    test('closing reports the stored balance, exposing drift rather than hiding it', () {
      // A row whose balanceAfter does not follow from the amounts — what a
      // movement that bypassed the choke point would look like.
      final broken = [
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 1000,
            balanceAfter: 1000,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.payment,
            amount: -400,
            balanceAfter: 999, // should be 600
            date: '2026-01-02T00:00:00.000'),
      ];

      final summary = summariseRestaurantLedger(broken);

      expect(summary.closing, 999, reason: 'reports what was stored');
      expect(summary.impliedClosing, 600, reason: 'what the buckets imply');
      expect((summary.impliedClosing - summary.closing).abs(), greaterThan(0.01),
          reason: 'the Overview tab must be able to flag this');
    });

    test('a brought-forward-only ledger reconciles to the standing balance', () {
      // What a supplier that predates the journal looks like after backfill:
      // exactly one opening row, no invented history.
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.opening,
            amount: 3400,
            balanceAfter: 3400,
            description: 'Balance brought forward'),
      ]);

      expect(summary.opening, 3400);
      expect(summary.closing, 3400);
      expect(summary.purchases, 0);
      expect(summary.payments, 0);
      expect(summary.impliedClosing, closeTo(3400, 1e-9));
    });

    test('settling in full leaves a zero closing balance', () {
      final summary = summariseRestaurantLedger([
        entry(
            type: RestaurantSupplierLedgerType.purchase,
            amount: 2500,
            balanceAfter: 2500,
            date: '2026-01-01T00:00:00.000'),
        entry(
            type: RestaurantSupplierLedgerType.payment,
            amount: -2500,
            balanceAfter: 0,
            date: '2026-01-02T00:00:00.000'),
      ]);

      expect(summary.closing, 0);
      expect(summary.isAdvance, isFalse);
      expect(summary.impliedClosing, closeTo(0, 1e-9));
    });
  });
}
