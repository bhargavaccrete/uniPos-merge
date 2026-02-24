import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/restaurant/db/staffModel_310.dart';

/// Tracks who is currently logged in to the restaurant POS.
/// Persists across hot-restarts via SharedPreferences.
class RestaurantSession {
  RestaurantSession._();

  static const _loginTypeKey  = 'restaurant_login_type'; // 'admin' | 'staff'
  static const _staffRoleKey  = 'restaurant_staff_role';
  static const _staffNameKey  = 'restaurant_staff_name';
  static const _isLoggedInKey = 'restaurant_is_logged_in';

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

  static Future<void> clearSession() async {
    _inactivityTimer?.cancel();
    sessionExpiredNotifier.value = false;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginTypeKey);
    await prefs.remove(_staffRoleKey);
    await prefs.remove(_staffNameKey);
    await prefs.setBool(_isLoggedInKey, false);
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
    if (_isLoggedIn) resetInactivityTimer();
  }

  // ── Permission check ─────────────────────────────────────────────────────
  /// Returns true if the current session can access the given feature key.
  /// Feature keys: 'startOrder', 'manageMenu', 'manageStaff', 'customers',
  ///               'reports', 'taxSettings', 'expenses', 'inventory', 'settings'
  static bool canAccess(String feature) {
    if (isAdmin || staffRole == 'Manager') return true;
    if (staffRole == 'Cashier') {
      // Cashier cannot access reports or staff management
      if (feature == 'reports' || feature == 'manageStaff') return false;
      return true; // endDay and everything else allowed
    }
    // Other staff roles: orders only
    return feature == 'startOrder';
  }
}