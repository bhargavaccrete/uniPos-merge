import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../presentation/widget/componets/restaurant/componets/import/import.dart';

class AutoBackupService {
  static const String _lastBackupDateKey = 'last_backup_date';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';

  static Timer? _timer;

  /// Initialize auto backup service
  static Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing Auto Backup Service...');

      // Start daily check timer (checks every hour)
      _timer = Timer.periodic(Duration(hours: 1), (timer) {
        _checkAndBackup();
      });

      // Also check immediately on startup
      await _checkAndBackup();

      debugPrint('✅ Auto Backup Service initialized');
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

  /// Check if backup is needed and perform it
  static Future<void> _checkAndBackup() async {
    try {
      // Check if auto backup is enabled
      final isEnabled = await isAutoBackupEnabled();
      if (!isEnabled) {
        debugPrint('⏭️ Auto backup is disabled, skipping check');
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

  /// Perform the actual backup
  static Future<void> _performBackup() async {
    try {
      debugPrint('📦 Starting automatic backup...');

      // Perform backup to Downloads folder
      final filePath = await CategoryImportExport.exportToDownloads();

      if (filePath != null) {
        // Update last backup date
        final appBox = Hive.box('app_state');
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await appBox.put(_lastBackupDateKey, today);

        debugPrint('✅ Automatic backup successful: $filePath');
        debugPrint('📅 Last backup date updated to: $today');
      } else {
        debugPrint('❌ Automatic backup failed: null file path');
      }
    } catch (e) {
      debugPrint('❌ Automatic backup error: $e');
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