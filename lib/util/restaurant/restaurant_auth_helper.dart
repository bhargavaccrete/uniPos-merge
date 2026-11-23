import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/common/staffModel_310.dart';

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

  static const String reloginToChangePinMessage =
      'Please log in again to change your PIN.';

  /// The staff record a logged-in staff member may change their own PIN on.
  ///
  /// Only the record with [staffId] (the logged-in staff member) is checked —
  /// never every staff member, or a current PIN that matched a colleague would
  /// change the colleague's PIN.
  static ({StaffModel? staff, String? error}) staffForOwnPinChange({
    required String? staffId,
    required Iterable<StaffModel> staff,
    required String currentPin,
  }) {
    if (staffId == null || staffId.isEmpty) {
      return (staff: null, error: reloginToChangePinMessage);
    }
    final me = staff.where((s) => s.id == staffId).firstOrNull;
    if (me == null || !me.isActive) {
      return (staff: null, error: reloginToChangePinMessage);
    }
    if (!verifyPassword(currentPin.trim(), me.pinNo.trim())) {
      return (staff: null, error: 'Current PIN is incorrect');
    }
    return (staff: me, error: null);
  }

  /// First-run admin PIN, used when nothing has been stored yet.
  static const String defaultAdminPin = '123456';

  /// Change the admin PIN in both modes. Returns an error message, or null on
  /// success.
  ///
  /// A missing key verifies against [defaultAdminPin] (restaurant never seeds
  /// it before first login; retail does via `AuthService.ensureDefaultAdmin`),
  /// and a pre-migration plaintext value still verifies via [verifyPassword].
  static Future<String?> changeAdminPin({
    required String oldPin,
    required String newPin,
    required String confirmPin,
  }) async {
    final oldValue = oldPin.trim();
    final newValue = newPin.trim();
    if (oldValue.isEmpty) return 'Current PIN is required';
    if (newValue.isEmpty) return 'New PIN is required';
    if (!RegExp(r'^\d{4,6}$').hasMatch(newValue)) {
      return 'PIN must be 4–6 digits';
    }
    if (newValue != confirmPin.trim()) return 'New PINs do not match';
    if (oldValue == newValue) {
      return 'New PIN must be different from current PIN';
    }

    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getString(adminPinKey) ?? hashPassword(defaultAdminPin);
    if (!verifyPassword(oldValue, stored)) return 'Current PIN is incorrect';

    await prefs.setString(adminPinKey, hashPassword(newValue));
    return null;
  }
}