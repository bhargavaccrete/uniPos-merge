import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../util/restaurant/restaurant_auth_helper.dart';
import '../../../util/restaurant/restaurant_session.dart';

/// Authentication result
class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? username;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.username,
  });

  factory AuthResult.success(String username) => AuthResult(
        success: true,
        username: username,
      );

  factory AuthResult.failure(String message) => AuthResult(
        success: false,
        errorMessage: message,
      );
}

/// Authentication Service — PIN-only login, same mechanism restaurant uses
/// (see `restaurant_login.dart`): the entered PIN is checked against the
/// stored admin PIN first, then against every active staff member's PIN
/// (staff already have PINs via the shared/unified Staff model). Session
/// tracking stays local to this service so `splashScreen.dart`,
/// `home_screen.dart`, and `existingUserRestoreScreen.dart` keep working
/// unchanged — they only ever call `initialize()`/`logout()`/`isLoggedIn`.
class AuthService {
  static const String _sessionKey = 'admin_session';
  static const String _sessionTimestampKey = 'admin_session_timestamp';
  // Display name shown after login — "Admin" or a staff member's name.
  static const String _usernameKey = 'admin_username';

  static const String _defaultPin = '123456';

  String? _currentUsername;

  /// Currently logged-in identity's display name ("Admin" or a staff name),
  /// or null if not logged in.
  String? get currentUsername => _currentUsername;

  bool get isLoggedIn => _currentUsername != null;

  /// Initialize auth service - check for existing session
  Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = prefs.getBool(_sessionKey) ?? false;

    if (hasSession) {
      _currentUsername = prefs.getString(_usernameKey);
      if (_currentUsername != null) {
        await RestaurantSession.saveAdminSession();
        return true;
      }
    }

    return false;
  }

  /// Ensure a default admin PIN exists (first run only — never overwrites an
  /// already-set PIN).
  Future<void> ensureDefaultAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(RestaurantAuthHelper.adminPinKey)) {
      await prefs.setString(
        RestaurantAuthHelper.adminPinKey,
        RestaurantAuthHelper.hashPassword(_defaultPin),
      );
    }
  }

  /// True only while the admin PIN is still the un-changed default — used to
  /// show the "default PIN" hint on first run and hide it the moment the PIN
  /// is actually changed, instead of disclosing it permanently.
  Future<bool> isUsingDefaultCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(RestaurantAuthHelper.adminPinKey);
    if (storedHash == null) return true;
    return RestaurantAuthHelper.verifyPassword(_defaultPin, storedHash);
  }

  /// PIN-only login. The PIN identifies whoever it is — admin first, then
  /// staff (mirrors restaurant's login exactly).
  Future<AuthResult> login(String pin) async {
    final trimmedPin = pin.trim();
    if (trimmedPin.isEmpty) {
      return AuthResult.failure('PIN is required');
    }

    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(RestaurantAuthHelper.adminPinKey);

    // 1. Admin (PIN = stored admin PIN)
    if (storedHash != null &&
        RestaurantAuthHelper.verifyPassword(trimmedPin, storedHash)) {
      await _saveSession('Admin');
      _currentUsername = 'Admin';
      await RestaurantSession.saveAdminSession();
      return AuthResult.success('Admin');
    }

    // 2. Staff (match PIN against active staff)
    await staffStore.loadStaff();
    final match = staffStore.staff
        .where((s) =>
            s.isActive &&
            RestaurantAuthHelper.verifyPassword(trimmedPin, s.pinNo.trim()))
        .firstOrNull;

    if (match != null) {
      final name = '${match.firstName} ${match.lastName}'.trim();
      await _saveSession(name);
      _currentUsername = name;
      await RestaurantSession.saveStaffSession(match);
      return AuthResult.success(name);
    }

    // 3. No match
    return AuthResult.failure('Invalid PIN');
  }

  /// Logout
  Future<void> logout() async {
    await _clearSession();
    _currentUsername = null;
    await RestaurantSession.clearSession();
  }

  /// Change the admin PIN (requires proving the current one first).
  Future<AuthResult> changePin({
    required String oldPin,
    required String newPin,
    required String confirmPin,
  }) async {
    if (oldPin.isEmpty) {
      return AuthResult.failure('Current PIN is required');
    }

    if (newPin.isEmpty) {
      return AuthResult.failure('New PIN is required');
    }

    if (!RegExp(r'^\d{4,6}$').hasMatch(newPin)) {
      return AuthResult.failure('PIN must be 4–6 digits');
    }

    if (newPin != confirmPin) {
      return AuthResult.failure('New PINs do not match');
    }

    if (oldPin == newPin) {
      return AuthResult.failure('New PIN must be different from current PIN');
    }

    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(RestaurantAuthHelper.adminPinKey);

    if (storedHash == null || !RestaurantAuthHelper.verifyPassword(oldPin, storedHash)) {
      return AuthResult.failure('Current PIN is incorrect');
    }

    await prefs.setString(
        RestaurantAuthHelper.adminPinKey, RestaurantAuthHelper.hashPassword(newPin));

    return AuthResult.success('Admin');
  }

  /// Sets the admin PIN directly, without requiring the old one — used
  /// during onboarding to replace the first-run default.
  Future<AuthResult> setInitialPin(String pin) async {
    final trimmedPin = pin.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(trimmedPin)) {
      return AuthResult.failure('PIN must be 4–6 digits');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        RestaurantAuthHelper.adminPinKey, RestaurantAuthHelper.hashPassword(trimmedPin));

    return AuthResult.success('Admin');
  }

  /// Save session to SharedPreferences
  Future<void> _saveSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(
      _sessionTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Clear session from SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_sessionTimestampKey);
  }

  /// Get session info
  Future<Map<String, dynamic>> getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hasSession': prefs.getBool(_sessionKey) ?? false,
      'username': prefs.getString(_usernameKey),
      'loginTime': prefs.getString(_sessionTimestampKey),
    };
  }
}
