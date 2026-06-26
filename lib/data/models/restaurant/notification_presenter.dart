import 'package:flutter/material.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/data/models/restaurant/dashboard_alert.dart';
import 'package:billberrylite/data/models/restaurant/db/app_notification_model.dart';

/// Android notification channel ids (created in LocalNotificationService).
class NotificationChannels {
  NotificationChannels._();
  static const String lowStock = 'low_stock';
  static const String appAlerts = 'app_alerts';
  static const String orders = 'orders'; // captain orders / KOT — high + sound
}

class NotificationView {
  final String title;
  final String body;
  final AlertSeverity severity;
  final IconData icon;
  final String? route;
  final String channelId;

  const NotificationView({
    required this.title,
    required this.body,
    required this.severity,
    required this.icon,
    required this.channelId,
    this.route,
  });
}

/// Derives how an event looks from its stable [eventCode] (+ context).
/// Single source of presentation for the screen and the OS dispatcher.
class NotificationPresenter {
  NotificationPresenter._();

  static NotificationView present(AppNotificationModel n) {
    final d = n.dataMap;
    switch (n.eventCode) {
      case 'low_stock':
        final name = d['name'] ?? 'An item';
        final remaining = d['remaining'];
        final unit = d['unit'] ?? '';
        final body = remaining == null
            ? '$name is running low on inventory.'
            : '$name: $remaining $unit left.';
        return NotificationView(
          title: 'Low Stock',
          body: body,
          severity: AlertSeverity.warning,
          icon: Icons.inventory_2_outlined,
          route: RouteNames.restaurantInventory,
          channelId: NotificationChannels.lowStock,
        );

      case 'pending_eod':
        return const NotificationView(
          title: 'End of Day Pending',
          body: 'Previous day session is still open. Please complete EOD.',
          severity: AlertSeverity.critical,
          icon: Icons.warning_amber_rounded,
          route: RouteNames.restaurantEndDay,
          channelId: NotificationChannels.appAlerts,
        );

      case 'license_expired':
        return const NotificationView(
          title: 'License Expired',
          body: 'License expired! Renew now to avoid service interruption.',
          severity: AlertSeverity.critical,
          icon: Icons.error_outline_rounded,
          route: RouteNames.restaurantLicensing,
          channelId: NotificationChannels.appAlerts,
        );

      case 'license_expiring':
        final days = d['daysRemaining'];
        final dayText = days == null
            ? 'soon'
            : 'in $days day${days == 1 ? '' : 's'}';
        return NotificationView(
          title: 'License Expiring Soon',
          body: 'Your license expires $dayText. Renew to avoid interruption.',
          severity: AlertSeverity.warning,
          icon: Icons.timer_outlined,
          route: RouteNames.restaurantLicensing,
          channelId: NotificationChannels.appAlerts,
        );

      case 'backup_due':
        return const NotificationView(
          title: 'Database Backup Needed',
          body: 'No backup in the last 7 days. Back up to secure your data.',
          severity: AlertSeverity.warning,
          icon: Icons.backup_rounded,
          channelId: NotificationChannels.appAlerts,
        );

      case 'app_update':
        return NotificationView(
          title: 'App Update Available',
          body: d['message'] ?? 'A new version of Bill Berry Lite is available.',
          severity: AlertSeverity.info,
          icon: Icons.system_update_rounded,
          channelId: NotificationChannels.appAlerts,
        );

      case 'announcement':
      default:
        return NotificationView(
          title: d['title'] ?? 'Notification',
          body: d['message'] ?? '',
          severity: AlertSeverity.info,
          icon: Icons.campaign_outlined,
          channelId: NotificationChannels.appAlerts,
        );
    }
  }
}
