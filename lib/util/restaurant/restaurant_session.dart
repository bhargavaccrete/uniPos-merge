import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/restaurant/db/staffModel_310.dart';

/// Tracks who is currently logged in to the restaurant POS.
/// Persists across hot-restarts via SharedPreferences.
class RestaurantSession {
  RestaurantSession._();

  static const _loginTypeKey      = 'restaurant_login_type'; // 'admin' | 'staff'
  static const _staffRoleKey      = 'restaurant_staff_role';
  static const _staffNameKey      = 'restaurant_staff_name';
  static const _isLoggedInKey     = 'restaurant_is_logged_in';
  static const _currentShiftIdKey = 'restaurant_current_shift_id';

  // ── Inactivity timeout ────────────────────────────────────────────────────
  static const _timeoutDuration = Duration(minutes: 15);
  static Timer? _inactivityTimer;

  /// Fires true when the session expires due to inactivity.
  static final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier(false);

  /// Inactivity timeout is currently disabled.
  static void resetInactivityTimer() {
    // Disabled — no auto-logout on inactivity
  }

  static final ValueNotifier<String>  loginTypeNotifier = ValueNotifier('admin');
  static final ValueNotifier<String?> staffRoleNotifier = ValueNotifier(null);
  static final ValueNotifier<String?> staffNameNotifier = ValueNotifier(null);

  // ── In-memory logged-in flag (avoids SharedPreferences hit on every guard) ─
  static bool _isLoggedIn = false;
  static bool get isLoggedIn => _isLoggedIn;

  // ── Shift tracking ───────────────────────────────────────────────────────
  static String? _currentShiftId;
  static String? get currentShiftId => _currentShiftId;
  static bool get hasOpenShift => _currentShiftId != null;

  /// Registered by service_locator — called with the open shiftId before session is cleared.
  /// Allows auto-closing the shift on logout without a circular import.
  static Future<void> Function(String shiftId)? onShiftAutoClose;

  // ── Getters ──────────────────────────────────────────────────────────────
  static String  get loginType => loginTypeNotifier.value;
  static String? get staffRole => staffRoleNotifier.value;
  static String? get staffName => staffNameNotifier.value;
  static bool    get isAdmin   => loginType == 'admin';

  /// Effective role string for display / permission checks.
  /// Admin and Manager both get full access.
  static String get effectiveRole => isAdmin ? 'Admin' : (staffRole ?? 'Staff');

  // ── Session save / clear ─────────────────────────────────────────────────
  static Future<void> saveAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginTypeKey, 'admin');
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.remove(_staffRoleKey);
    await prefs.remove(_staffNameKey);
    _isLoggedIn = true;
    loginTypeNotifier.value = 'admin';
    staffRoleNotifier.value = null;
    staffNameNotifier.value = null;
    resetInactivityTimer();
  }

  static Future<void> saveStaffSession(StaffModel staff) async {
    final prefs = await SharedPreferences.getInstance();
    final name = '${staff.firstName} ${staff.lastName}'.trim();
    await prefs.setString(_loginTypeKey, 'staff');
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_staffRoleKey, staff.isCashier);
    await prefs.setString(_staffNameKey, name);
    _isLoggedIn = true;
    loginTypeNotifier.value = 'staff';
    staffRoleNotifier.value = staff.isCashier;
    staffNameNotifier.value = name;
    resetInactivityTimer();
  }

  static Future<void> saveShiftSession(String shiftId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentShiftIdKey, shiftId);
    _currentShiftId = shiftId;
  }

  static Future<void> clearShiftSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentShiftIdKey);
    _currentShiftId = null;
  }

  static Future<void> clearSession() async {
    _inactivityTimer?.cancel();
    sessionExpiredNotifier.value = false;
    _isLoggedIn = false;
    // Auto-close open shift before clearing session
    if (_currentShiftId != null && onShiftAutoClose != null) {
      await onShiftAutoClose!(_currentShiftId!);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginTypeKey);
    await prefs.remove(_staffRoleKey);
    await prefs.remove(_staffNameKey);
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_currentShiftIdKey);
    _currentShiftId = null;
    loginTypeNotifier.value = 'admin';
    staffRoleNotifier.value = null;
    staffNameNotifier.value = null;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    loginTypeNotifier.value = prefs.getString(_loginTypeKey) ?? 'admin';
    staffRoleNotifier.value = prefs.getString(_staffRoleKey);
    staffNameNotifier.value = prefs.getString(_staffNameKey);
    _currentShiftId = prefs.getString(_currentShiftIdKey);
    if (_isLoggedIn) resetInactivityTimer();
  }

  // ── Permission check ─────────────────────────────────────────────────────
  /// Returns true if the current session can access the given feature key.
  /// Feature keys: 'startOrder', 'manageMenu', 'manageStaff', 'customers',
  ///               'reports', 'taxSettings', 'expenses', 'inventory', 'settings'
  static bool canAccess(String feature) {
    if (isAdmin || staffRole == 'Manager') return true;
    if (staffRole == 'Cashier') {
      // Cashier cannot access reports, staff management, or cash drawer
      if (feature == 'reports' || feature == 'manageStaff' || feature == 'cashDrawer') return false;
      return true;
    }
    // Other staff roles: orders only
    return feature == 'startOrder';
  }
}