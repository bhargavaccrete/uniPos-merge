import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../data/models/common/staffModel_310.dart';

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
  static const String _timeoutMinutesKey = 'restaurant_inactivity_timeout_minutes';
  static const int _defaultTimeoutMinutes = 15;

  static final ValueNotifier<int> timeoutMinutesNotifier =
      ValueNotifier(_defaultTimeoutMinutes);

  static int get timeoutMinutes => timeoutMinutesNotifier.value;
  static Duration get _timeoutDuration =>
      Duration(minutes: timeoutMinutesNotifier.value);

  static Future<void> setTimeoutMinutes(int minutes) async {
    timeoutMinutesNotifier.value = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeoutMinutesKey, minutes);
    // Restart timer with the new duration immediately
    if (_isLoggedIn) resetInactivityTimer();
  }

  static Timer? _inactivityTimer;

  /// When the app was last backgrounded — lets resume count time spent away.
  static DateTime? _backgroundedAt;

  /// Fires true when the session expires due to inactivity.
  static final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier(false);

  /// Resets the inactivity timer. Called on every user touch via RestaurantGuard.
  /// When the timer fires, sessionExpiredNotifier triggers a forced logout.
  static void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_timeoutDuration, () {
      sessionExpiredNotifier.value = true;
    });
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  // Background time does NOT count toward auto-logout. Without this, a plain
  // Timer keeps its deadline across a suspend and FIRES IMMEDIATELY on resume,
  // logging the user out the instant they reopen the app.
  static final _SessionLifecycleObserver _lifecycleObserver =
      _SessionLifecycleObserver();
  static bool _lifecycleRegistered = false;

  /// Registers app pause/resume handling. Call once after the binding is ready.
  static void initLifecycle() {
    if (_lifecycleRegistered) return;
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _lifecycleRegistered = true;
  }

  /// App went to the background → stop the timer and stamp the time so resume
  /// can count how long we were away.
  static void _onAppBackgrounded() {
    _inactivityTimer?.cancel();
    if (_isLoggedIn) _backgroundedAt = DateTime.now();
  }

  /// App returned to the foreground. Background time DOES count toward the
  /// timeout: if we were away at least the full window, expire now; otherwise
  /// restart a fresh window. (Checking elapsed explicitly avoids the old bug
  /// where a stale timer fired the instant the app reopened.)
  static void _onAppResumed() {
    if (!_isLoggedIn) return;
    final bgAt = _backgroundedAt;
    _backgroundedAt = null;
    if (bgAt != null && DateTime.now().difference(bgAt) >= _timeoutDuration) {
      sessionExpiredNotifier.value = true;
    } else {
      resetInactivityTimer();
    }
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
  static Future<void> Function(String staffName)? onAttendanceAutoClockOut;

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
    sessionExpiredNotifier.value = false; // clear any stale expiry flag
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
    sessionExpiredNotifier.value = false; // clear any stale expiry flag
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
    // Auto clock-out attendance if still open
    final currentName = staffName ?? (isAdmin ? 'Admin' : null);
    if (currentName != null && onAttendanceAutoClockOut != null) {
      await onAttendanceAutoClockOut!(currentName);
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
    // SECURITY: load() runs only on a COLD START (fresh process launch). A full
    // close / swipe-from-recents kills the process WITHOUT a graceful logout, so
    // the persisted "logged in" flag is stale. Never auto-login from it — force
    // re-authentication so a killed-and-relaunched app asks for the PIN again.
    // (A background→resume does NOT re-run load(), so simply minimizing keeps the
    // session alive, subject to the inactivity timeout.)
    _isLoggedIn = false;
    await prefs.setBool(_isLoggedInKey, false);
    loginTypeNotifier.value = prefs.getString(_loginTypeKey) ?? 'admin';
    staffRoleNotifier.value = prefs.getString(_staffRoleKey);
    staffNameNotifier.value = prefs.getString(_staffNameKey);
    _currentShiftId = prefs.getString(_currentShiftIdKey);
    timeoutMinutesNotifier.value =
        prefs.getInt(_timeoutMinutesKey) ?? _defaultTimeoutMinutes;
    // Not logged in on cold start → no inactivity timer until the PIN is entered
    // (saveAdminSession / saveStaffSession start it on successful login).
  }

  // ── Permission check ─────────────────────────────────────────────────────

  /// What a RESTAURANT Cashier may NOT do.
  ///
  /// 'settings' covers the whole store/admin config cluster — Settings and its
  /// sub-screens, Licensing, Payment Methods, admin password, Order Settings,
  /// Data Generator — so one rule locks them all.
  static const Set<String> _restaurantCashierBlocked = {
    'reports',
    'manageStaff',
    'cashDrawer',
    'settings',
    'taxSettings',
  };

  /// What a RETAIL Cashier may NOT do.
  ///
  /// Deliberately NOT the restaurant set:
  /// * `cashDrawer` is absent — a retail cashier records their own cash in/out.
  /// * The catalogue, procurement and backup keys have no restaurant analogue.
  ///
  /// Note the view/modify split: `catalog` and `inventory` stay OPEN so a
  /// cashier can look up a price or check stock at the counter; `catalogEdit`
  /// and `inventoryAdjust` are the gates that stop them changing anything.
  ///
  /// `settings` is blocked, but retail's Settings *hub* is deliberately not
  /// gated on it — Start Day, End of Day and Logout live inside that hub, so
  /// locking the door would leave a cashier unable to close the day or log out.
  /// The sensitive tiles inside carry the gate instead.
  static const Set<String> _retailCashierBlocked = {
    'reports',
    'manageStaff',
    'settings',
    'taxSettings',
    'catalogEdit',
    'inventoryAdjust',
    'suppliers',
    'purchase',
    'dataBackup',
    // Money-sensitive POS actions. Each is read through a named service getter
    // (PriceOverrideService.canOverride and friends) whose callers HIDE the
    // control rather than showing it and refusing.
    'billingOverride',
    'billingDiscount',
    'billingExchange',
  };

  /// Returns true if the current session can access the given feature key.
  ///
  /// **Admin and Manager get everything, in both business modes.** Only the
  /// Cashier rule differs, and it is a DENYLIST: anything not named is allowed.
  /// That means a feature key added later is Cashier-accessible until someone
  /// adds it to the relevant set — check this when adding a sensitive screen.
  ///
  /// Restaurant keys: 'startOrder', 'manageMenu', 'manageStaff', 'customers',
  ///   'reports', 'taxSettings', 'expenses', 'inventory', 'settings',
  ///   'cashDrawer', 'endDay'.
  /// Retail keys: 'billing', 'customers', 'catalog', 'catalogEdit',
  ///   'inventory', 'inventoryAdjust', 'suppliers', 'purchase', 'reports',
  ///   'manageStaff', 'settings', 'taxSettings', 'dataBackup', 'cashDrawer',
  ///   'endDay', 'attendance', 'billingOverride', 'billingDiscount',
  ///   'billingExchange'.
  static bool canAccess(String feature) {
    // Fail CLOSED when nobody is signed in. `clearSession` resets loginType to
    // 'admin' (its default), so `isAdmin` reads TRUE after a logout — without
    // this line every permission would be granted to a logged-out session.
    // RestaurantGuard checks isLoggedIn before calling here, but the service
    // getters (PriceOverrideService.canOverride and friends) do not, and
    // RetailGuard has no login check at all.
    if (!isLoggedIn) return false;
    if (isAdmin || staffRole == 'Manager') return true;
    if (staffRole == 'Cashier') {
      final blocked =
          AppConfig.isRetail ? _retailCashierBlocked : _restaurantCashierBlocked;
      return !blocked.contains(feature);
    }
    // Other staff roles (restaurant's Waiter): orders only. Retail has no third
    // role — StaffRoles.retail stops at Manager/Cashier.
    return feature == 'startOrder';
  }
}

/// Observes app pause/resume so background time isn't counted as inactivity.
class _SessionLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        RestaurantSession._onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        RestaurantSession._onAppResumed();
        break;
      case AppLifecycleState.inactive:
        break; // transient (app switcher / dialog) — ignore
    }
  }
}