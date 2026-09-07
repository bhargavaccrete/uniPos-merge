import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/util/retail/cash_drawer_ledger.dart';

/// Pure arithmetic over a SaleModel — no Hive, no prefs.
SaleModel _sale({
  required double total,
  required String paymentType,
  List<Map<String, dynamic>>? legs,
  double? paid,
  double due = 0,
  bool isReturn = false,
}) {
  final now = DateTime.now().toIso8601String();
  return SaleModel(
    saleId: 's1',
    totalItems: 1,
    subtotal: total,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: total,
    paymentType: paymentType,
    date: now,
    createdAt: now,
    updatedAt: now,
    isReturn: isReturn,
    paymentListJson: legs == null ? null : jsonEncode(legs),
    paidAmount: paid,
    dueAmount: due,
    status: due > 0 ? SaleStatus.partiallyPaid : SaleStatus.paid,
  );
}

void main() {
  group('cashComponentOf', () {
    test('full cash sale counts in full', () {
      final s = _sale(
        total: 200,
        paymentType: 'cash',
        legs: [
          {'method': 'cash', 'amount': 200.0},
        ],
        paid: 200,
      );
      expect(CashDrawerLedger.cashComponentOf(s), 200);
    });

    test('partial cash sale counts only what was tendered', () {
      final s = _sale(
        total: 200,
        paymentType: 'cash',
        legs: [
          {'method': 'cash', 'amount': 50.0},
        ],
        paid: 50,
        due: 150,
      );
      expect(CashDrawerLedger.cashComponentOf(s), 50);
    });

    test('legacy partial row whose leg kept the full bill is trimmed', () {
      // Written before the leg stored the tendered amount.
      final s = _sale(
        total: 200,
        paymentType: 'cash',
        legs: [
          {'method': 'cash', 'amount': 200.0},
        ],
        paid: 50,
        due: 150,
      );
      expect(CashDrawerLedger.cashComponentOf(s), 50);
    });

    test('sale predating paidAmount is not trimmed to zero', () {
      // Adapter decodes the missing field as 0; dueAmount is 0 too, which is
      // what keeps the ceiling off.
      final s = _sale(total: 200, paymentType: 'cash', paid: 0);
      expect(CashDrawerLedger.cashComponentOf(s), 200);
    });

    test('card bill contributes nothing', () {
      final s = _sale(
        total: 200,
        paymentType: 'card',
        legs: [
          {'method': 'card', 'amount': 200.0},
        ],
        paid: 200,
      );
      expect(CashDrawerLedger.cashComponentOf(s), 0);
    });

    test('split bill contributes only its cash leg', () {
      final s = _sale(
        total: 200,
        paymentType: 'split',
        legs: [
          {'method': 'cash', 'amount': 120.0},
          {'method': 'card', 'amount': 80.0},
        ],
        paid: 200,
      );
      expect(CashDrawerLedger.cashComponentOf(s), 120);
    });
  });

  group('settledLegsOf', () {
    test('unpaid balance is booked as credit, not as collected money', () {
      final s = _sale(
        total: 200,
        paymentType: 'cash',
        legs: [
          {'method': 'cash', 'amount': 50.0},
        ],
        paid: 50,
        due: 150,
      );
      expect(CashDrawerLedger.settledLegsOf(s), {'cash': 50.0, 'credit': 150.0});
    });

    test('single-method sale without legs still decomposes', () {
      final s = _sale(total: 200, paymentType: 'upi', paid: 200);
      expect(CashDrawerLedger.settledLegsOf(s), {'upi': 200.0});
    });

    test('legacy split partial trims both collected legs proportionally', () {
      final s = _sale(
        total: 200,
        paymentType: 'split',
        legs: [
          {'method': 'cash', 'amount': 120.0},
          {'method': 'card', 'amount': 80.0},
        ],
        paid: 100,
        due: 100,
      );
      expect(CashDrawerLedger.settledLegsOf(s),
          {'cash': 60.0, 'card': 40.0, 'credit': 100.0});
    });
  });
}
