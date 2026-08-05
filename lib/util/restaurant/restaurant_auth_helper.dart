import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Shared password hashing utility for restaurant auth.
/// Uses SHA-256 + a fixed salt (matches retail pattern).
class RestaurantAuthHelper {
  static const _salt = 'unipos_restaurant_salt_2024';

  /// The one shared SharedPreferences key both modes store the admin PIN
  /// hash under. Retail and restaurant are never active in the same install,
  /// so a single canonical key (rather than a per-mode one) keeps admin PIN
  /// storage/login logic identical across both.
  static const String adminPinKey = 'restaurant_admin_password';

  /// Hash a plaintext password.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password + _salt);
    return sha256.convert(bytes).toString();
  }

  /// SHA-256 always produces a 64-char hex string.
  /// If the stored value is not 64 chars, it is still plaintext (pre-migration).
  static bool isHashed(String value) => value.length == 64;

  /// Verify entered password against stored value.
  /// Handles both hashed (post-migration) and plaintext (pre-migration) stored values.
  static bool verifyPassword(String entered, String stored) {
    if (isHashed(stored)) {
      return hashPassword(entered) == stored;
    }
    // Plaintext fallback — migration path
    return entered == stored;
  }
}