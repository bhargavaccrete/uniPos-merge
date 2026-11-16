import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/notification_presenter.dart';
import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';

/// "Database Backup Needed": raised at startup when automatic backup is on and
/// the last backup is 7 or more days old (or never happened); resolved
/// otherwise. One implementation for both modes (BKP-6 K2) — Restaurant's
/// original logic, moved here unchanged.
class BackupDueSync {
  BackupDueSync._();

  static const String eventCode = 'backup_due';
  static const String _seed = 'backup_due:system';

  /// [remindAt]: when the OS reminder fires (each mode's "next morning").
  static Future<void> sync({required DateTime remindAt}) async {
    final enabled = await AutoBackupService.isAutoBackupEnabled();
    final overdue = enabled && await backupOverdue();
    if (overdue) {
      await notificationStore.raiseEvent(
        eventCode: eventCode,
        subjectType: 'system',
        fireOs: false,
      );
      await LocalNotificationService.instance.schedule(
        idSeed: _seed,
        when: remindAt,
        title: 'Database Backup Needed',
        body: 'No backup in the last 7 days. Back up to secure your data.',
        channelId: NotificationChannels.appAlerts,
      );
    } else {
      await notificationStore.resolve(eventCode, 'system', null);
      await LocalNotificationService.instance.cancelBySeed(_seed);
    }
  }

  static Future<bool> backupOverdue() async {
    final last = await AutoBackupService.getLastBackupDate();
    if (last == null || last.isEmpty) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed).inDays >= 7;
  }
}
