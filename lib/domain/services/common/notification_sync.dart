import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/domain/services/restaurant/notification_sync_service.dart';
import 'package:billberrylite/domain/services/retail/retail_notification_sync_service.dart';

/// Runs whichever vertical's startup notification checks apply.
///
/// The event *pipeline* is shared (one store, one box, one screen), but what
/// gets checked is not: restaurant reconciles pending EOD, backup age and
/// license expiry; retail reconciles low stock and product expiry. Neither
/// service knows the other exists — this is the single place that chooses,
/// so `main.dart` and the shared notifications screen both stay mode-neutral.
class NotificationSync {
  NotificationSync._();

  static Future<void> runStartupChecks() async {
    if (AppConfig.isRetail) {
      await RetailNotificationSyncService.runStartupChecks();
    } else if (AppConfig.isRestaurant) {
      await NotificationSyncService.runStartupChecks();
    }
    // No business mode yet (setup wizard) — nothing to reconcile.
  }
}
