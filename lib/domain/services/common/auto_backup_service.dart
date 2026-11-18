import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/restore_record.dart';
import 'package:billberrylite/domain/services/common/auto_backup_retention.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';

// Unified backup service (works for both modes)
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/backup_storage_permission.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/mode_keys.dart';

// Legacy backup implementations (kept for backward compatibility, not actively used)
// import 'package:billberrylite/domain/services/retail/backup_service.dart';
// import 'package:billberrylite/presentation/widget/componets/restaurant/componets/import/import.dart';

/// Auto Backup Service - Mode-Aware
/// Works with both Restaurant and Retail modes
/// Performs automatic daily backups
class AutoBackupService {
  static const String _lastBackupDateKey = 'last_backup_date';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';

  static Timer? _timer;

  /// Observable backup state — UI can listen to show a small indicator.
  static final ValueNotifier<bool> isBackingUp = ValueNotifier(false);

  /// Initialize auto backup service
  static Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing Auto Backup Service...');

      // Start daily check timer (checks every hour). Never two timers, even
      // if initialize is called again (WF-6).
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(hours: 1), (timer) {
        _checkAndBackup();
      });

      // Delay the startup check so the app renders first
      Future.delayed(const Duration(seconds: 10), _checkAndBackup);

      debugPrint('✅ Auto Backup Service initialized for ${AppConfig.businessMode.name} mode');
    } catch (e) {
      debugPrint('❌ Auto Backup Service initialization failed: $e');
    }
  }

  /// Stop the auto backup service
  static void dispose() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 Auto Backup Service stopped');
  }

  /// Check if auto backup is enabled
  static Future<bool> isAutoBackupEnabled() async {
    try {
      final appBox = Hive.box('app_state');
      return appBox.get(_autoBackupEnabledKey, defaultValue: false);
    } catch (e) {
      debugPrint('Error checking auto backup status: $e');
      return false;
    }
  }

  /// Enable or disable auto backup
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    try {
      final appBox = Hive.box('app_state');
      await appBox.put(_autoBackupEnabledKey, enabled);
      debugPrint('✅ Auto backup ${enabled ? "enabled" : "disabled"}');

      if (enabled) {
        // Trigger immediate backup when enabled
        await _performBackup();
      }
    } catch (e) {
      debugPrint('Error setting auto backup: $e');
    }
  }

  /// Mark today's date as backed up (without running a backup).
  /// Call this after a successful manual/start-of-day backup.
  static Future<void> markTodayAsBackedUp() async {
    try {
      final appBox = Hive.box('app_state');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await appBox.put(_lastBackupDateKey, today);
      debugPrint('📅 Backup date marked as: $today');
    } catch (e) {
      debugPrint('❌ Failed to mark backup date: $e');
    }
  }

  /// Get last backup date
  static Future<String?> getLastBackupDate() async {
    try {
      final appBox = Hive.box('app_state');
      return appBox.get(_lastBackupDateKey);
    } catch (e) {
      debugPrint('Error getting last backup date: $e');
      return null;
    }
  }

  /// Runs one hourly check now (the timer's own path, plan gate included).
  @visibleForTesting
  static Future<void> checkAndBackupForTesting() => _checkAndBackup();

  /// Check if backup is needed and perform it
  static Future<void> _checkAndBackup() async {
    try {
      // Plan gate — backup (incl. auto-backup) requires the data_backup module.
      if (!PlanEnforce.allows(ModeKeys.dataBackup)) {
        debugPrint('⏭️  data_backup not licensed, skipping auto backup');
        return;
      }
      // Check if auto backup is enabled
      final isEnabled = await isAutoBackupEnabled();
      if (!isEnabled) {
        debugPrint('⏭️  Auto backup is disabled, skipping check');
        return;
      }

      final appBox = Hive.box('app_state');
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      final lastBackupDate = appBox.get(_lastBackupDateKey);

      debugPrint('📅 Today: $today, Last backup: $lastBackupDate');

      // If no backup today, create one
      if (lastBackupDate != today) {
        debugPrint('🔔 Date changed! Triggering automatic backup...');
        await _performBackup();
      } else {
        debugPrint('✅ Backup already done today');
      }
    } catch (e) {
      debugPrint('❌ Auto backup check failed: $e');
    }
  }

  // ── BKP-6: result of the last automatic attempt (app_state) ──────────────
  static const String _lastAttemptKey = 'last_auto_backup_attempt';
  static const String _lastSuccessKey = 'last_auto_backup_success';
  static const String _lastErrorKey = 'last_auto_backup_error';

  /// In-app notification raised when an automatic backup fails; resolved by
  /// the next success. One active event at most (the store updates it in
  /// place), so hourly retries never pile up notifications.
  static const String failedEvent = 'backup_failed';

  static const String noPasswordMessage =
      'No backup password is set, so automatic backups cannot be encrypted '
      'and are not being made. Set a backup password in Backup & Restore.';

  /// Last automatic attempt (any outcome), last success, and the reason the
  /// last attempt failed (null after a success).
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
    debugPrint('❌ Automatic backup failed: $reason');
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

  static Future<void> _recordSuccess(String filePath) async {
    final now = DateTime.now();
    try {
      final box = Hive.box('app_state');
      await box.put(_lastAttemptKey, now.toIso8601String());
      await box.put(_lastSuccessKey, now.toIso8601String());
      await box.delete(_lastErrorKey);
    } catch (_) {}
    if (locator.isRegistered<NotificationStore>()) {
      await notificationStore.resolve(failedEvent, 'system', null);
    }
  }

  /// Perform the actual backup (mode-aware)
  static Future<void> _performBackup() async {
    // Backups are always encrypted. With no password set there is no way to
    // encrypt (and no UI to prompt here), so no backup is made — and the user
    // is told (BKP-6), instead of believing it runs.
    if (!await BackupEncryptionService.hasPassword()) {
      await _recordFailure(noPasswordMessage);
      return;
    }

    // Android 7–10 need storage permission for Downloads. A timer cannot ask,
    // so the user is told instead (asked from the toggle / manual backup).
    if (!await BackupStoragePermission.isGranted()) {
      await _recordFailure(BackupStoragePermission.deniedMessage);
      return;
    }

    isBackingUp.value = true;
    try {
      debugPrint('📦 Starting automatic backup for ${AppConfig.businessMode.name} mode...');

      // Auto-backup skips images to keep file size small (~1-5 MB vs 100+ MB).
      // Images are included only in manual "Download Backup" from the drawer.
      // Its own file name (BillBerryLite_auto_…) lets retention tell it from
      // a manual backup; the content and format are the same.
      String? filePath;
      try {
        filePath = await UnifiedBackupService.exportToDownloads(
            includeImages: false, automatic: true);
      } catch (e) {
        await _recordFailure('The automatic backup could not be created: $e');
        return;
      }

      if (filePath != null) {
        // Update last backup date
        final appBox = Hive.box('app_state');
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await appBox.put(_lastBackupDateKey, today);
        await _recordSuccess(filePath);

        debugPrint('✅ Automatic backup successful: $filePath');
        debugPrint('📅 Last backup date updated to: $today');

        // Retention (BKP-6 K4): only now, after the new backup was written
        // and verified; never on a failed attempt.
        await _pruneOldAutomaticBackups(filePath);
      } else {
        // Not marked as backed up, so it is retried on the next run.
        await _recordFailure(UnifiedBackupService.lastExportError ??
            'The automatic backup could not be saved.');
      }
    } catch (e) {
      await _recordFailure('The automatic backup could not be created: $e');
    } finally {
      isBackingUp.value = false;
    }
  }

  static Future<void> _pruneOldAutomaticBackups(String newest) async {
    if (kIsWeb) return;
    try {
      final protected = <String>{};
      // Belt and braces: a snapshot an open restore record still needs is
      // never deleted (snapshots live elsewhere, but never rely on that).
      final docs = (await getApplicationDocumentsDirectory()).path;
      final open = RestoreRecordStore.read(docs);
      if (open != null && open.readable) protected.add(open.snapshotPath);
      await AutoBackupRetention.prune(File(newest).parent,
          newest: newest, protected: protected);
    } catch (e) {
      debugPrint('⚠️ Old automatic backups were not pruned: $e');
    }
  }

  /// Manually trigger backup (for testing or user action)
  static Future<String?> triggerBackupNow() async {
    try {
      debugPrint('🔔 Manual backup triggered');
      await _performBackup();
      return await getLastBackupDate();
    } catch (e) {
      debugPrint('❌ Manual backup failed: $e');
      return null;
    }
  }
}