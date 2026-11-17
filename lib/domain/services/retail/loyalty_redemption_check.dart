import '../../../data/models/common/customer_model_125.dart';

/// LOY-1: loyalty points may only come off a bill for the customer attached
/// to it, and never more than that customer holds right now.
///
/// The posting step (`CheckoutCustomerPosting`, step `redeem`) skips a short
/// balance without failing, so a bill that still carried a redemption after
/// the customer changed gave the discount and deducted nothing. This runs
/// before the sale is written, against the customer's SAVED balance — not the
/// copy picked earlier, which another sale or an edit may have overtaken.
class LoyaltyRedemptionCheck {
  LoyaltyRedemptionCheck._();

  /// Why [points] may not be redeemed, or null when they may.
  ///
  /// [customerId] is the attached customer (null = walk-in); [saved] is that
  /// customer as stored now (null = not found).
  static String? problem({
    required int points,
    required String? customerId,
    required Customer? saved,
  }) {
    if (points <= 0) return null;
    if (customerId == null) {
      return 'Loyalty points need a customer on the bill.';
    }
    if (saved == null) {
      return 'The customer on this bill could not be found.';
    }
    if (saved.loyaltyPoints < points) {
      return '${saved.name ?? 'The customer'} has ${saved.loyaltyPoints} '
          'points, but $points were applied.';
    }
    return null;
  }

  /// [problem] with the customer read fresh through [lookup].
  static Future<String?> atCommit({
    required int points,
    required String? customerId,
    required Future<Customer?> Function(String customerId) lookup,
  }) async {
    if (points <= 0) return null;
    final saved = customerId == null ? null : await lookup(customerId);
    return problem(points: points, customerId: customerId, saved: saved);
  }
}
