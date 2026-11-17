import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/domain/services/retail/loyalty_redemption_check.dart';

/// LOY-1: points come off a bill only for the attached customer, and never
/// more than that customer holds as saved now.
void main() {
  Customer asha(int points) => Customer(
        customerId: 'C1',
        name: 'Asha',
        loyaltyPoints: points,
        createdAt: '2026-01-01T00:00:00.000',
      );

  group('problem', () {
    test('no redemption is always fine, with or without a customer', () {
      expect(
        LoyaltyRedemptionCheck.problem(points: 0, customerId: null, saved: null),
        isNull,
      );
      expect(
        LoyaltyRedemptionCheck.problem(
            points: 0, customerId: 'C1', saved: asha(0)),
        isNull,
      );
    });

    test('walk-in (no customer) cannot redeem', () {
      expect(
        LoyaltyRedemptionCheck.problem(
            points: 50, customerId: null, saved: null),
        'Loyalty points need a customer on the bill.',
      );
    });

    test('a customer that no longer exists cannot redeem', () {
      expect(
        LoyaltyRedemptionCheck.problem(
            points: 50, customerId: 'C1', saved: null),
        'The customer on this bill could not be found.',
      );
    });

    test('more points than the customer holds is refused', () {
      expect(
        LoyaltyRedemptionCheck.problem(
            points: 150, customerId: 'C1', saved: asha(149)),
        'Asha has 149 points, but 150 were applied.',
      );
    });

    test('exactly the balance, or less, is allowed', () {
      expect(
        LoyaltyRedemptionCheck.problem(
            points: 150, customerId: 'C1', saved: asha(150)),
        isNull,
      );
      expect(
        LoyaltyRedemptionCheck.problem(
            points: 100, customerId: 'C1', saved: asha(300)),
        isNull,
      );
    });
  });

  group('atCommit reads the saved customer', () {
    test('uses the looked-up balance, not a stale copy', () async {
      final looked = <String>[];
      final problem = await LoyaltyRedemptionCheck.atCommit(
        points: 150,
        customerId: 'C1',
        lookup: (id) async {
          looked.add(id);
          return asha(40);
        },
      );
      expect(looked, ['C1']);
      expect(problem, 'Asha has 40 points, but 150 were applied.');
    });

    test('no redemption needs no lookup', () async {
      var called = false;
      final problem = await LoyaltyRedemptionCheck.atCommit(
        points: 0,
        customerId: 'C1',
        lookup: (_) async {
          called = true;
          return null;
        },
      );
      expect(problem, isNull);
      expect(called, isFalse);
    });

    test('walk-in with a redemption is refused without a lookup', () async {
      final problem = await LoyaltyRedemptionCheck.atCommit(
        points: 10,
        customerId: null,
        lookup: (_) async => fail('no customer to look up'),
      );
      expect(problem, 'Loyalty points need a customer on the bill.');
    });
  });
}
