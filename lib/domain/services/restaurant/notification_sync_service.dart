import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/data/models/restaurant/notification_presenter.dart';
import 'package:unipos/domain/services/common/auto_backup_service.dart';
import 'package:unipos/domain/services/common/local_notification_service.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/domain/store/restaurant/license_store.dart';

/// Raises app-level notifications and (re)schedules offline reminders so they
/// fire even when the app is fully closed. Reconciled on every launch.
class NotificationSyncService {
  NotificationSyncService._();

  static const int _morningHour = 9;

  static Future<void> runStartupChecks() async {
    await _syncPendingEod();
    await _syncBackupDue();
    await _syncLicense();
  }

  static Future<void> _syncPendingEod() async {
    final sessionId = await DayManagementService.getCurrentSessionId();
    final pending = await DayManagementService.hasPendingEOD();
    const seed = 'pending_eod:session';
    if (pending) {
      await notificationStore.raiseEvent(
        eventCode: 'pending_eod',
        subjectType: 'session',
        subjectId: sessionId,
        fireOs: false,
      );
      await LocalNotificationService.instance.schedule(
        idSeed: seed,
        when: _nextMorning(),
        title: 'End of Day Pending',
        body: 'Previous day session is still open. Please complete EOD.',
        channelId: NotificationChannels.appAlerts,
        payload: RouteNames.restaurantEndDay,
      );
    } else {
      await notificationStore.resolve('pending_eod', 'session', sessionId);
      await LocalNotificationService.instance.cancelBySeed(seed);
    }
  }

  static Future<void> _syncBackupDue() async {
    const seed = 'backup_due:system';
    final enabled = await AutoBackupService.isAutoBackupEnabled();
    final overdue = enabled && await _backupOverdue();
    if (overdue) {
      await notificationStore.raiseEvent(
        eventCode: 'backup_due',
        subjectType: 'system',
        fireOs: false,
      );
      await LocalNotificationService.instance.schedule(
        idSeed: seed,
        when: _nextMorning(),
        title: 'Database Backup Needed',
        body: 'No backup in the last 7 days. Back up to secure your data.',
        channelId: NotificationChannels.appAlerts,
      );
    } else {
      await notificationStore.resolve('backup_due', 'system', null);
      await LocalNotificationService.instance.cancelBySeed(seed);
    }
  }

  static Future<void> _syncLicense() async {
    final lic = locator<LicenseStore>();
    const expiringSeed = 'license_expiring:license:license';
    const expiredSeed = 'license_expired:license:license';

    if (lic.isExpiringSoon && lic.licenseInfo != null) {
      final days = lic.licenseInfo!.daysRemaining;
      if (days <= 0) {
        await notificationStore.resolve('license_expiring', 'license', 'license');
        await LocalNotificationService.instance.cancelBySeed(expiringSeed);
        await notificationStore.raiseEvent(
          eventCode: 'license_expired',
          subjectType: 'license',
          subjectId: 'license',
          fireOs: false,
        );
        await LocalNotificationService.instance.schedule(
          idSeed: expiredSeed,
          when: _nextMorning(),
          title: 'License Expired',
          body: 'License expired! Renew now to avoid service interruption.',
          channelId: NotificationChannels.appAlerts,
          payload: RouteNames.restaurantLicensing,
        );
      } else {
        await notificationStore.resolve('license_expired', 'license', 'license');
        await LocalNotificationService.instance.cancelBySeed(expiredSeed);
        await notificationStore.raiseEvent(
          eventCode: 'license_expiring',
          subjectType: 'license',
          subjectId: 'license',
          data: {'daysRemaining': days},
          fireOs: false,
        );
        await LocalNotificationService.instance.schedule(
          idSeed: expiringSeed,
          when: _nextMorning(),
          title: 'License Expiring Soon',
          body: 'Your license expires in $days day${days == 1 ? '' : 's'}. Renew soon.',
          channelId: NotificationChannels.appAlerts,
          payload: RouteNames.restaurantLicensing,
        );
      }
    } else {
      await notificationStore.resolve('license_expiring', 'license', 'license');
      await notificationStore.resolve('license_expired', 'license', 'license');
      await LocalNotificationService.instance.cancelBySeed(expiringSeed);
      await LocalNotificationService.instance.cancelBySeed(expiredSeed);
    }
  }

  static Future<bool> _backupOverdue() async {
    final last = await AutoBackupService.getLastBackupDate();
    if (last == null || last.isEmpty) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed).inDays >= 7;
  }

  static DateTime _nextMorning() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _morningHour);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
}
