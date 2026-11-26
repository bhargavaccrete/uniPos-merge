import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/restore_record.dart';
import 'package:billberrylite/domain/services/common/auto_backup_retention.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';

/// What the start-of-day prompt shows.
enum DailyBackupPrompt {
  /// No prompt: switched off, or a backup was already made today.
  none,

  /// "Backup Now" / "Skip Today".
  optional,

  /// "Backup Now" only: no backup for [AutoBackupService.requiredAfterDays]
  /// days since the last backup, or since the prompt was switched on.
  required,
}

/// Daily backup — asked, never automatic.
///
/// Nothing runs in the background. When the "Daily Backup Prompt" setting is
/// on, the start-of-day prompt asks for a backup once a day; after
/// [requiredAfterDays] days without one it can no longer be skipped. Every
/// successful backup (prompt, manual, folder or share) counts as that day's
/// backup and clears the last failure.
class AutoBackupService {
  static const String _lastBackupDateKey = 'last_backup_date';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';

  /// Date (`yyyy-MM-dd`) the prompt was switched on (or first checked). The
  /// 7 days are counted from the later of this and the last backup, so a
  /// fresh install is never told "no backup for 7 days" on day one.
  static const String promptSinceKey = 'daily_backup_prompt_since';

  /// Days without a backup after which the prompt has no "Skip Today".
  static const int requiredAfterDays = 7;

  /// True while a daily backup runs — the POS shows a thin progress bar.
  static final ValueNotifier<bool> isBackingUp = ValueNotifier(false);

  /// Whether the "Daily Backup Prompt" setting is on (off by default).
  static Future<bool> isAutoBackupEnabled() async {
    try {
      final appBox = Hive.box('app_state');
      return appBox.get(_autoBackupEnabledKey, defaultValue: false);
    } catch (e) {
      debugPrint('Error checking auto backup status: $e');
      return false;
    }
  }

  /// Saves the setting only. No backup is started. Switching it on starts
  /// the 7-day count today.
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    try {
      final appBox = Hive.box('app_state');
      await appBox.put(_autoBackupEnabledKey, enabled);
      if (enabled) {
        await appBox.put(
            promptSinceKey, DateTime.now().toIso8601String().substring(0, 10));
      }
    } catch (e) {
      debugPrint('Error setting auto backup: $e');
    }
  }

  /// Mark today's date as backed up (without running a backup).
  static Future<void> markTodayAsBackedUp() async {
    try {
      final appBox = Hive.box('app_state');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await appBox.put(_lastBackupDateKey, today);
    } catch (e) {
      debugPrint('❌ Failed to mark backup date: $e');
    }
  }

  /// Get last backup date (`yyyy-MM-dd`).
  static Future<String?> getLastBackupDate() async {
    try {
      final appBox = Hive.box('app_state');
      return appBox.get(_lastBackupDateKey);
    } catch (e) {
      debugPrint('Error getting last backup date: $e');
      return null;
    }
  }

  /// Pure rule for the start-of-day prompt. Days are counted between
  /// calendar dates, so a backup late last night still means "1 day".
  /// [since]: when the prompt was switched on; the 7 days run from the later
  /// of it and [lastBackupDate].
  static DailyBackupPrompt promptFor({
    required bool enabled,
    required String? lastBackupDate,
    String? since,
    required DateTime now,
  }) {
    if (!enabled) return DailyBackupPrompt.none;
    DateTime? day(String? s) {
      final t = s == null ? null : DateTime.tryParse(s);
      // UTC dates: a daylight-saving change never shortens a day to 23 hours.
      return t == null ? null : DateTime.utc(t.year, t.month, t.day);
    }

    final today = DateTime.utc(now.year, now.month, now.day);
    final last = day(lastBackupDate);
    if (last != null && last == today) return DailyBackupPrompt.none;

    final start = day(since);
    final from = [last, start].whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isAfter(a) ? b : a);
    // Never backed up and no start date yet: ask, but do not insist.
    if (from == null) return DailyBackupPrompt.optional;
    final days = today.difference(from).inDays;
    if (days >= requiredAfterDays) return DailyBackupPrompt.required;
    return DailyBackupPrompt.optional; // 0–6 days, or the clock went back
  }

  /// [promptFor] with the stored setting, last backup and start date. A
  /// device that never backed up and has no start date yet starts counting
  /// now (it was switched on before the start date existed).
  static Future<DailyBackupPrompt> currentPrompt({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final enabled = await isAutoBackupEnabled();
    final last = await getLastBackupDate();
    String? since;
    try {
      final box = Hive.box('app_state');
      since = box.get(promptSinceKey) as String?;
      if (enabled && since == null && last == null) {
        since = at.toIso8601String().substring(0, 10);
        await box.put(promptSinceKey, since);
      }
    } catch (_) {}
    return promptFor(
        enabled: enabled, lastBackupDate: last, since: since, now: at);
  }

  // ── BKP-6: result of the last backup attempt (app_state) ─────────────────
  static const String _lastAttemptKey = 'last_auto_backup_attempt';
  static const String _lastSuccessKey = 'last_auto_backup_success';
  static const String _lastErrorKey = 'last_auto_backup_error';

  /// In-app notification raised when a daily backup fails; resolved by the
  /// next successful backup. One active event at most.
  static const String failedEvent = 'backup_failed';

  static const String noPasswordMessage =
      'No backup password is set, so backups cannot be encrypted and are not '
      'being made. Set a backup password in Backup & Restore.';

  /// Last daily backup attempt (any outcome), last successful backup of any
  /// kind, and why the last daily attempt failed (null after a success).
  static ({DateTime? lastAttempt, DateTime? lastSuccess, String? lastError})
      status() {
    try {
      final box = Hive.box('app_state');
      DateTime? at(String key) {
        final v = box.get(key);
        return v is String ? DateTime.tryParse(v) : null;
      }

      final error = box.get(_lastErrorKey);
      return (
        lastAttempt: at(_lastAttemptKey),
        lastSuccess: at(_lastSuccessKey),
        lastError: error is String && error.isNotEmpty ? error : null,
      );
    } catch (_) {
      return (lastAttempt: null, lastSuccess: null, lastError: null);
    }
  }

  static Future<void> _recordFailure(String reason) async {
    debugPrint('❌ Daily backup failed: $reason');
    try {
      final box = Hive.box('app_state');
      await box.put(_lastAttemptKey, DateTime.now().toIso8601String());
      await box.put(_lastErrorKey, reason);
    } catch (_) {}
    if (locator.isRegistered<NotificationStore>()) {
      await notificationStore.raiseEvent(
        eventCode: failedEvent,
        subjectType: 'system',
        data: {'reason': reason},
        fireOs: false,
      );
    }
  }

  /// A backup file was saved and verified (any kind): today counts as backed
  /// up, and the last failure and its notification are cleared.
  static Future<void> recordBackupMade() async {
    final now = DateTime.now();
    try {
      final box = Hive.box('app_state');
      await box.put(_lastBackupDateKey, now.toIso8601String().substring(0, 10));
      await box.put(_lastAttemptKey, now.toIso8601String());
      await box.put(_lastSuccessKey, now.toIso8601String());
      await box.delete(_lastErrorKey);
    } catch (_) {}
    if (locator.isRegistered<NotificationStore>()) {
      await notificationStore.resolve(failedEvent, 'system', null);
    }
  }

  /// The backup the start-of-day prompt asked for: saved to Downloads as a
  /// daily backup, its result recorded, and old daily backups pruned once it
  /// is verified. Returns the file path, or null (reason in [status]).
  static Future<String?> runDailyBackup() async {
    // Backups are always encrypted; the prompt asks for a password first.
    if (!await BackupEncryptionService.hasPassword()) {
      await _recordFailure(noPasswordMessage);
      return null;
    }

    isBackingUp.value = true;
    try {
      final filePath = await UnifiedBackupService.exportToDownloads(daily: true);
      if (filePath == null) {
        await _recordFailure(UnifiedBackupService.lastExportError ??
            'The backup could not be saved.');
        return null;
      }
      // Success was recorded by exportToDownloads. Retention runs only now,
      // after the new backup was written and verified (BKP-6 K4).
      await _pruneOldDailyBackups(filePath);
      return filePath;
    } catch (e) {
      await _recordFailure('The backup could not be created: $e');
      return null;
    } finally {
      isBackingUp.value = false;
    }
  }

  static Future<void> _pruneOldDailyBackups(String newest) async {
    if (kIsWeb) return;
    try {
      final protected = <String>{};
      // A snapshot an open restore record still needs is never deleted.
      final docs = (await getApplicationDocumentsDirectory()).path;
      final open = RestoreRecordStore.read(docs);
      if (open != null && open.readable) protected.add(open.snapshotPath);
      await AutoBackupRetention.prune(File(newest).parent,
          newest: newest, protected: protected);
    } catch (e) {
      debugPrint('⚠️ Old daily backups were not pruned: $e');
    }
  }
}
