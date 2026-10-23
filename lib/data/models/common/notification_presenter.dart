import 'package:flutter/material.dart';
import 'package:billberrylite/core/routes/notification_routes.dart';
import 'package:billberrylite/data/models/common/dashboard_alert.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';

/// Android notification channel ids (created in LocalNotificationService).
class NotificationChannels {
  NotificationChannels._();
  static const String lowStock = 'low_stock';
  static const String appAlerts = 'app_alerts';
  static const String orders = 'orders'; // captain orders / KOT — high + sound
  static const String expiry = 'expiry'; // retail expiry alerts — high
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
          route: NotificationRoutes.lowStock,
          channelId: NotificationChannels.lowStock,
        );

      case 'pending_eod':
        return NotificationView(
          title: 'End of Day Pending',
          body: 'Previous day session is still open. Please complete EOD.',
          severity: AlertSeverity.critical,
          icon: Icons.warning_amber_rounded,
          route: NotificationRoutes.endDay,
          channelId: NotificationChannels.appAlerts,
        );

      case 'license_expired':
        return NotificationView(
          title: 'License Expired',
          body: 'License expired! Renew now to avoid service interruption.',
          severity: AlertSeverity.critical,
          icon: Icons.error_outline_rounded,
          route: NotificationRoutes.licensing,
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
          route: NotificationRoutes.licensing,
          channelId: NotificationChannels.appAlerts,
        );

      // Retail expiry. One event per variant; severity follows the CURRENT
      // status in `data`, which the sync service refreshes in place — so a
      // date pushed further out downgrades the same row instead of leaving a
      // stale "Expired" behind.
      case 'expiry_alert':
        final name = d['name'] ?? 'A product';
        final status = d['status'] as String?;
        final days = d['daysUntil'];
        final isExpired = status == 'expired';
        final String body;
        if (isExpired) {
          body = '$name has expired.';
        } else if (days == null || days == 0) {
          body = '$name expires today.';
        } else {
          body = '$name expires in $days day${days == 1 ? '' : 's'}.';
        }
        return NotificationView(
          title: isExpired ? 'Product Expired' : 'Expiring Soon',
          body: body,
          severity: isExpired ? AlertSeverity.critical : AlertSeverity.warning,
          icon: Icons.event_busy_rounded,
          route: NotificationRoutes.expiry,
          channelId: NotificationChannels.expiry,
        );

      // A Settle stock deduction the journal could not confirm after a crash
      // (StockJournal `review`): never auto-applied, so a person checks it.
      case 'stock_check_needed':
        final name = d['name'] ?? 'An item';
        final qty = d['qty'];
        final unit = d['unit'] ?? '';
        final amount = qty == null ? '' : ' by $qty $unit';
        return NotificationView(
          title: 'Stock Check Needed',
          body: '$name may be off$amount after an interrupted sale. '
              'Count it and adjust stock.',
          severity: AlertSeverity.warning,
          icon: Icons.fact_check_outlined,
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
