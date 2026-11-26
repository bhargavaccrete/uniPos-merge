import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/split_payment_widget.dart';

/// R7 (split amounts cannot exceed the bill) and R8 (the points cap is what
/// points can actually take off) as pure rules.
void main() {
  group('R7: payment amounts never add up to more than the bill', () {
    PaymentEntry entry(String method, double amount, {double received = 0}) =>
        PaymentEntry(method: method, amount: amount, cashReceived: received);

    test('cash 100 + UPI 50 on a 120 bill is refused', () {
      expect(PaymentAllocation.exceedsBill(
          [entry('cash', 100), entry('upi', 50)], 120), isTrue);
    });

    test('cash 70 + UPI 50 on a 120 bill is fine', () {
      expect(PaymentAllocation.exceedsBill(
          [entry('cash', 70), entry('upi', 50)], 120), isFalse);
    });

    test('one cash payment with change is fine: change is cash received', () {
      final e = entry('cash', 120, received: 200);
      expect(PaymentAllocation.exceedsBill([e], 120), isFalse);
      expect(e.toMap()['amount'], 120, reason: 'the leg is the bill, not the 200');
      expect(e.toMap()['change'], 80);
    });

    test('a paisa of rounding is tolerated', () {
      expect(PaymentAllocation.exceedsBill(
          [entry('cash', 60.005), entry('upi', 60)], 120), isFalse);
    });

    test('a zero bill (fully covered by points) is never over-allocated', () {
      expect(PaymentAllocation.exceedsBill([entry('cash', 0)], 0), isFalse);
    });
  });

  group('R8: points capped at what they can take off', () {
    RetailBill bill({required double taxable, required double gst, required bool inclusive}) =>
        RetailBill(
          itemTotal: inclusive ? taxable + gst : taxable,
          discountAmount: 0,
          taxableAmount: taxable,
          totalGst: gst,
          cgstAmount: gst / 2,
          sgstAmount: gst / 2,
          loyaltyRedemption: 0,
          roundOff: 0,
          grandTotal: taxable + gst,
          gstBreakdown: const {},
          lines: const [],
          isTaxInclusive: inclusive,
        );

    test('₹100 + 18% exclusive with 118 points: only 100 redeemable', () {
      expect(RetailBillingService.redeemablePoints(
          billBefore: bill(taxable: 100, gst: 18, inclusive: false), available: 118), 100);
    });

    test('inclusive mode: the whole gross can be redeemed', () {
      expect(RetailBillingService.redeemablePoints(
          billBefore: bill(taxable: 100, gst: 18, inclusive: true), available: 118), 118);
    });

    test('fewer points than the bill: all of them', () {
      expect(RetailBillingService.redeemablePoints(
          billBefore: bill(taxable: 100, gst: 18, inclusive: false), available: 40), 40);
    });

    test('a fractional base rounds DOWN, never above its value', () {
      expect(RetailBillingService.redeemablePoints(
          billBefore: bill(taxable: 99.5, gst: 17.91, inclusive: false), available: 500), 99);
    });
  });
}
