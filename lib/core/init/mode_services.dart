import 'package:flutter/foundation.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/init/retail_startup.dart';
import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/firebase_messaging_service.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';
import 'package:billberrylite/domain/services/common/notification_sync.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/server/server.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/restaurant/order_settings.dart';
import 'package:billberrylite/util/restaurant/print_settings.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// The per-mode startup steps, one function each, so tests can record them
/// instead of binding a port or touching platform plugins.
class ModeStartupSteps {
  final Future<void> Function() loadRestaurantSettings;
  final void Function() initRestaurantLifecycle;
  final void Function() startAutoBackup;
  final void Function() startLanServer;
  final Future<void> Function() loadRetailSettings;

  /// WF-3: restores the saved shift ID and inactivity timeout. Retail login
  /// (`authService.initialize()` at the splash) still re-saves the session.
  final Future<void> Function() loadRetailSession;

  /// WF-3: clears a restored shift ID whose shift is closed or gone.
  final Future<void> Function() validateRestoredShift;
  final void Function() initRetailLifecycle;
  final Future<void> Function() startLocalNotifications;
  final Future<void> Function() startPushNotifications;

  const ModeStartupSteps({
    this.loadRestaurantSettings = _loadRestaurantSettings,
    this.initRestaurantLifecycle = RestaurantSession.initLifecycle,
    this.startAutoBackup = _startAutoBackup,
    this.startLanServer = _startLanServer,
    this.loadRetailSettings = loadRetailStartupSettings,
    this.loadRetailSession = RestaurantSession.load,
    this.validateRestoredShift = clearClosedRestoredShift,
    this.initRetailLifecycle = RestaurantSession.initLifecycle,
    this.startLocalNotifications = _startLocalNotifications,
    this.startPushNotifications = _startPushNotifications,
  });

  /// WF-3 (R2): the shift ID restored from storage is kept only while that
  /// shift still exists and is open; otherwise it is cleared, so no sale is
  /// stamped with a closed or unknown shift. Uses the existing repository.
  static Future<void> clearClosedRestoredShift() async {
    final id = RestaurantSession.currentShiftId;
    if (id == null) return;
    final shift = await shiftRepository.getShiftById(id);
    if (shift == null || !shift.isOpen) {
      debugPrint('   ℹ️  Restored shift $id is no longer open — cleared');
      await RestaurantSession.clearShiftSession();
    }
  }

  static Future<void> _loadRestaurantSettings() async {
    await Future.wait([
      AppSettings.load(),
      PrintSettings.load(),
      DecimalSettings.load(),
      OrderSettings.load(),
      CurrencyHelper.load(),
      RestaurantSession.load(),
    ]);
  }

  // Runs hourly, triggers daily backups.
  static void _startAutoBackup() => AutoBackupService.initialize();

  // Captain/KDS clients connect to :9090 on launch, so it binds before
  // anything slower (notifications) runs. Fire-and-forget.
  static void _startLanServer() {
    debugPrint('🌐 Starting local server (background)...');
    startServer().then((_) {
      debugPrint('   ✅ Bill Berry Lite Local Server Started Successfully');
    }).catchError((Object e) {
      debugPrint('   ⚠️  Failed to start Bill Berry Lite Local Server: $e');
    });
  }

  static Future<void> _startLocalNotifications() async {
    await LocalNotificationService.instance.init();
    await notificationStore.load();
    await NotificationSync.runStartupChecks();
  }

  static Future<void> _startPushNotifications() =>
      FirebaseMessagingService.instance.init();
}

/// WF-6: everything startup does for the business mode, after the data is
/// open and the service locator is built — settings, the Restaurant session
/// lifecycle, auto-backup, the LAN server, notifications.
///
/// Called by `main.dart` at startup and when the setup wizard finishes (the
/// mode was not set when the app started, so startup skipped all of it).
/// Runs at most once per process: a second call never adds a timer, a server
/// bind or a lifecycle observer. Does nothing while no mode is set.
class ModeServices {
  ModeServices._();

  static BusinessMode? _startedFor;

  /// The mode the services were started for in this process, or null.
  static BusinessMode? get startedFor => _startedFor;

  @visibleForTesting
  static ModeStartupSteps steps = const ModeStartupSteps();

  @visibleForTesting
  static void resetForTesting() {
    _startedFor = null;
    steps = const ModeStartupSteps();
  }

  static Future<void> start() async {
    final mode = AppConfig.businessMode;
    if (mode == BusinessMode.none) {
      debugPrint('   ⚠️  No business mode set - running in setup mode');
      return;
    }
    if (_startedFor != null) {
      debugPrint('   ℹ️  Mode services already started for ${_startedFor!.name}');
      return;
    }
    _startedFor = mode;

    // Same order as startup always used (settings, lifecycle, auto-backup,
    // LAN server; then notifications, deliberately last).
    debugPrint('⚙️  Step 6/7: Loading app settings...');
    if (mode == BusinessMode.restaurant) {
      await steps.loadRestaurantSettings();
      steps.initRestaurantLifecycle(); // pause/resume handling for auto-logout
      debugPrint('   ✅ Restaurant settings loaded');
      steps.startAutoBackup();
      debugPrint('   ✅ Auto-backup service initialized');
      steps.startLanServer();
    } else {
      // WF-3: the session file too, before the first sale can read the shift.
      await Future.wait([steps.loadRetailSettings(), steps.loadRetailSession()]);
      await steps.validateRestoredShift();
      steps.initRetailLifecycle(); // pause/resume handling for auto-logout
      debugPrint('   ✅ Retail settings loaded');
      // M6a: the same hourly check Restaurant runs (at most one backup a day,
      // only when the user switched it on — off by default).
      steps.startAutoBackup();
      debugPrint('   ✅ Auto-backup service initialized');
    }

    // Shared by restaurant and retail. Both wrapped so a failure (exact-alarm
    // permission denied on Android 13/14, a missing Firebase config) can
    // never break or block startup. Permission is requested after the first
    // frame (see main()), because the Android 13+ prompt needs a resumed
    // activity.
    try {
      await steps.startLocalNotifications();
      debugPrint('   ✅ Local notifications ready');
    } catch (e) {
      debugPrint('   ⚠️  Local notifications init failed (non-fatal): $e');
    }
    // Firebase Cloud Messaging (push). After local notifications: foreground
    // pushes are rendered through that plugin's channels. No-op on
    // desktop/web (no google-services config there).
    try {
      await steps.startPushNotifications();
      debugPrint('   ✅ Firebase push notifications ready');
    } catch (e) {
      debugPrint('   ⚠️  Firebase messaging init failed (non-fatal): $e');
    }
  }
}
