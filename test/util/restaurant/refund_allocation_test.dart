import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/util/restaurant/payment_mode_summary.dart';
import 'package:billberrylite/util/restaurant/refund_allocation.dart';

import '../../helpers/test_helpers.dart';

/// One refund calculation for End of Day, the cash drawer and the payment
/// report: a refund comes off the method it was ACTUALLY paid out by; only
/// refunds recorded before the method was asked for are spread in proportion.
void main() {
  final day = DateTime(2026, 11, 8, 12);

  String legs(Map<String, double> m) =>
      jsonEncode([for (final e in m.entries) {'method': e.key, 'amount': e.value}]);

  String events(List<RefundEvent> list) => RefundEvent.encodeAll(list);

  PastOrderModel order({
    double total = 300,
    String paymentmode = 'Cash',
    String status = 'COMPLETED',
    Map<String, double>? paid,
    double? totalPaid,
    List<RefundEvent> refunds = const [],
    String? sessionId = 'S1',
  }) =>
      PastOrderModel(
        id: 'o-${paymentmode.hashCode}-$total-$status',
        customerName: '',
        totalPrice: total,
        items: [makeCartItem(price: total, quantity: 1)],
        orderAt: day,
        orderType: 'Dine In',
        paymentmode: paymentmode,
        orderStatus: status,
        paymentListJson: paid == null ? null : legs(paid),
        isSplitPayment: paid != null && paid.length > 1,
        totalPaid: totalPaid,
        refundAmount: refunds.fold<double>(0, (s, e) => s + e.amount),
        refundedAt: refunds.isEmpty ? null : refunds.last.at,
        refundEventsJson: refunds.isEmpty ? null : events(refunds),
        sessionId: sessionId,
        kotNumbers: [1],
        kotBoundaries: [1],
      );

  RefundEvent refund(double amount, {Map<String, double>? by, String? session = 'S1'}) =>
      RefundEvent(
        amount: amount,
        at: day,
        sessionId: session,
        legs: by == null
            ? null
            : [for (final e in by.entries) (method: e.key, amount: e.value)],
      );

  group('refunds come off the method they were paid out by', () {
    test('cash sale, cash refund', () {
      final o = order(refunds: [refund(100, by: {'cash': 100})]);
      expect(RefundAllocation.netLegsOf(o), {'Cash': 200});
    });

    test('UPI sale, UPI refund', () {
      final o = order(paymentmode: 'upi', refunds: [refund(100, by: {'upi': 100})]);
      expect(RefundAllocation.netLegsOf(o), {'UPI': 200});
    });

    test('UPI sale refunded in CASH: cash goes negative, UPI stays whole', () {
      final o = order(paymentmode: 'upi', refunds: [refund(100, by: {'cash': 100})]);
      expect(RefundAllocation.netLegsOf(o), {'UPI': 300, 'Cash': -100});
    });

    test('split refund: cash 30 + UPI 20 on a cash 100 / UPI 100 bill', () {
      final o = order(
        total: 200,
        paid: {'cash': 100, 'upi': 100},
        refunds: [refund(50, by: {'cash': 30, 'upi': 20})],
      );
      expect(RefundAllocation.netLegsOf(o), {'Cash': 70, 'UPI': 80});
    });

    test('several partial refunds add up per method', () {
      final o = order(refunds: [
        refund(50, by: {'cash': 50}),
        refund(25, by: {'upi': 25}),
        refund(25, by: {'cash': 25}),
      ]);
      expect(RefundAllocation.refundedByMethod(o), {'Cash': 75, 'UPI': 25});
      expect(RefundAllocation.netLegsOf(o), {'Cash': 225, 'UPI': -25});
    });
  });

  group('legacy refunds (no method recorded): proportional fallback', () {
    test('spread over what was collected, in proportion', () {
      final o = order(
        total: 150,
        paid: {'cash': 100, 'upi': 50},
        refunds: [refund(30)],
      );
      final net = RefundAllocation.netLegsOf(o);
      expect(net['Cash'], closeTo(80, 1e-9));
      expect(net['UPI'], closeTo(40, 1e-9));
    });

    test('refunded before refund history existed (refundAmount only)', () {
      final o = PastOrderModel(
        id: 'legacy',
        customerName: '',
        totalPrice: 300,
        items: [makeCartItem(price: 300, quantity: 1)],
        orderAt: day,
        orderType: 'Dine In',
        paymentmode: 'cash',
        refundAmount: 120,
        refundedAt: day,
        kotNumbers: [1],
        kotBoundaries: [1],
      );
      expect(RefundAllocation.netLegsOf(o), {'Cash': 180});
    });

    test('legacy and recorded refunds on one order', () {
      final o = order(
        total: 200,
        paid: {'cash': 100, 'upi': 100},
        refunds: [refund(40), refund(30, by: {'cash': 30})],
      );
      final net = RefundAllocation.netLegsOf(o);
      expect(net['Cash'], closeTo(100 - 20 - 30, 1e-9));
      expect(net['UPI'], closeTo(100 - 20, 1e-9));
    });
  });

  group('what an order collected', () {
    test('a paid void written before part-paid voids: the bill total', () {
      final o = order(status: 'VOIDED', total: 250);
      expect(RefundAllocation.paidLegsOf(o), {'Cash': 250});
    });

    test('a PART-paid void: only what was collected, never the bill', () {
      final o = order(status: 'VOIDED', total: 500, totalPaid: 200);
      expect(RefundAllocation.collectedOf(o), 200);
    });

    test('a part-paid void with recorded legs uses the legs', () {
      final o = order(status: 'VOIDED', total: 500, totalPaid: 200, paid: {'upi': 200});
      expect(RefundAllocation.paidLegsOf(o), {'UPI': 200});
    });

    test('an unpaid order collected nothing', () {
      final o = order(status: 'VOID', paymentmode: 'N/A');
      expect(RefundAllocation.paidLegsOf(o), isEmpty);
    });

    test('a normal order still counts its bill total (unchanged)', () {
      final o = order(total: 300, totalPaid: 100);
      expect(RefundAllocation.collectedOf(o), 300);
    });
  });

  group('one session figure for the drawer', () {
    bool inS1(PastOrderModel o) => o.sessionId == 'S1';
    bool refundInS1(RefundEvent e) => e.sessionId == 'S1';

    test('own orders net of refunds, a paid void held, an unpaid void ignored, '
        'and earlier orders refunded today come off by method', () {
      final collections = RefundAllocation.sessionCollections(
        orders: [
          order(total: 300, refunds: [refund(50, by: {'upi': 50})]),
          order(status: 'VOIDED', total: 120, paymentmode: 'upi'),
          order(status: 'VOID', paymentmode: 'N/A', total: 999),
          order(
            total: 400,
            paymentmode: 'card',
            sessionId: 'S0',
            refunds: [refund(80, by: {'cash': 80}), refund(10, by: {'cash': 10}, session: 'S0')],
          ),
        ],
        inSession: inS1,
        refundInSession: refundInS1,
      );
      expect(collections['Cash'], closeTo(300 - 80, 1e-9));
      expect(collections['UPI'], closeTo(-50 + 120, 1e-9));
      expect(collections.containsKey('Card'), isFalse,
          reason: "an earlier session's sale is not today's money");
    });
  });

  group('payment report and End of Day summary', () {
    test('no refunds: the same figures as before, split and single', () {
      final rows = PaymentModeSummary.summarize([
        order(total: 120, paid: {'cash': 70, 'upi': 50}),
        order(total: 200, paymentmode: 'card'),
      ]);
      final by = {for (final r in rows) r.paymentType: r.totalAmount};
      expect(by, {'Cash': 70, 'UPI': 50, 'Card': 200});
    });

    test('a refund recorded by method comes off that method', () {
      final rows = PaymentModeSummary.summarize([
        order(total: 300, paymentmode: 'upi', refunds: [refund(100, by: {'cash': 100})]),
      ]);
      final by = {for (final r in rows) r.paymentType: r.totalAmount};
      expect(by, {'UPI': 300, 'Cash': -100});
    });

    test('a FULLY refunded UPI bill paid back in cash still moves the money', () {
      final rows = PaymentModeSummary.summarize([
        order(
          total: 300,
          paymentmode: 'upi',
          status: 'FULLY_REFUNDED',
          refunds: [refund(300, by: {'cash': 300})],
        ),
      ]);
      final by = {for (final r in rows) r.paymentType: r.totalAmount};
      expect(by, {'UPI': 300, 'Cash': -300});
    });

    test('a legacy fully refunded bill stays excluded, as before', () {
      final rows = PaymentModeSummary.summarize([
        order(total: 300, status: 'FULLY_REFUNDED', refunds: [refund(300)]),
      ]);
      expect(rows, isEmpty);
    });
  });

  test('refund events: legs round-trip; old events decode with no method', () {
    final e = refund(50, by: {'cash': 30, 'upi': 20});
    final back = RefundEvent.fromMap(e.toMap());
    expect(back.legs, [(method: 'cash', amount: 30.0), (method: 'upi', amount: 20.0)]);
    final old = RefundEvent.fromMap({'amount': 50, 'at': day.toIso8601String(), 'sessionId': 'S1'});
    expect(old.legs, isNull);
    expect(refund(50).toMap().containsKey('legs'), isFalse,
        reason: 'a method-less event is written exactly as before');
  });
}
