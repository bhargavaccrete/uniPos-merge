import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/notification_presenter.dart';
import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';

/// "Database Backup Needed": raised at startup when the daily backup prompt
/// is on and there has been no backup for 7 or more days (counted from the
/// last backup, or from when the prompt was switched on); resolved otherwise. One implementation for both modes (BKP-6 K2) — Restaurant's
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

  /// Overdue exactly when the start-of-day prompt would insist (7+ days
  /// since the last backup or since the prompt was switched on), so a fresh
  /// install is not told "no backup in 7 days" on its first morning.
  static Future<bool> backupOverdue() async =>
      await AutoBackupService.currentPrompt() == DailyBackupPrompt.required;
}
