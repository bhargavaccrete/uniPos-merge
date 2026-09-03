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
  // WHICH identity the session belongs to. Absent = the admin; set = that
  // staff member's `StaffModel.id`. A display name alone can't tell the two
  // apart (and staff names are editable and can collide), which is exactly
  // how restore used to elevate every staff member to admin.
  static const String _staffIdKey = 'admin_staff_id';

  static const String _defaultPin = '123456';

  String? _currentUsername;

  /// Currently logged-in identity's display name ("Admin" or a staff name),
  /// or null if not logged in.
  String? get currentUsername => _currentUsername;

  bool get isLoggedIn => _currentUsername != null;

  /// Restore a saved session, re-establishing the SAME identity that logged
  /// in — admin as admin, staff as staff.
  ///
  /// This used to call `saveAdminSession()` unconditionally, so after any app
  /// restart a cashier came back as the admin: `RestaurantSession.staffName`
  /// went null, Attendance stopped excluding the logged-in user, the
  /// attendance detail screen's admin-only edit/delete opened up, and their
  /// shift was attributed to 'admin'.
  ///
  /// Every path that cannot positively identify a staff member clears the
  /// session and returns false (→ LoginScreen) rather than falling back to
  /// admin. Failing closed is the only safe direction for a privilege check.
  Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = prefs.getBool(_sessionKey) ?? false;
    if (!hasSession) return false;

    final username = prefs.getString(_usernameKey);
    if (username == null) return false;

    final staffId = prefs.getString(_staffIdKey);

    if (staffId == null) {
      // No staff id recorded. Either a genuine admin session, or one saved
      // before this field existed — and a legacy session under a non-admin
      // name is precisely the case that used to be silently elevated, so it
      // must re-authenticate instead.
      if (username != 'Admin') {
        await _clearSession();
        return false;
      }
      _currentUsername = username;
      await RestaurantSession.saveAdminSession();
      return true;
    }

    // Staff session — re-resolve the record so the restored session carries
    // the live role and name, not a stale copy of them.
    await staffStore.loadStaff();
    final match =
        staffStore.staff.where((s) => s.id == staffId && s.isActive).firstOrNull;
    if (match == null) {
      // Deleted or deactivated since login: the session identifies nobody.
      await _clearSession();
      return false;
    }

    _currentUsername = '${match.firstName} ${match.lastName}'.trim();
    await RestaurantSession.saveStaffSession(match);
    return true;
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
      await _saveSession('Admin', staffId: null);
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
      await _saveSession(name, staffId: match.id);
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
  Future<void> _saveSession(String username, {required String? staffId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_usernameKey, username);
    // Explicitly removed on an admin login — otherwise a previous staff
    // session's id would linger and the next restore would resolve the admin
    // as that staff member.
    if (staffId == null) {
      await prefs.remove(_staffIdKey);
    } else {
      await prefs.setString(_staffIdKey, staffId);
    }
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
    await prefs.remove(_staffIdKey);
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
