import '../../core/config/app_config.dart';

/// Loyalty points — the single source of truth for the earn rate.
///
/// Both the award logic (when an order is settled) and the printed receipt read
/// from here, so the "points earned" number can never drift between them again
/// (it previously did: the restaurant award used ÷100 while the receipt used ÷10).
///
/// The rate differs by business type — restaurant grants 1 point per ₹100,
/// retail 1 point per ₹10 — so the shared receipt renderer stays correct for
/// whichever mode the app is running in.
class LoyaltyPoints {
  LoyaltyPoints._();

  /// Rupees that must be spent to earn 1 point.
  static int get rupeesPerPoint => AppConfig.isRestaurant ? 100 : 10;

  /// Points earned for a bill of [amount] (floored). Non-positive amounts
  /// (e.g. a bill fully covered by redeemed points) earn nothing.
  static int earnedFor(double amount) {
    if (amount <= 0) return 0;
    return (amount / rupeesPerPoint).floor();
  }
}
