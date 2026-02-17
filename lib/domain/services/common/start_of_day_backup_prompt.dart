import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/domain/services/common/auto_backup_service.dart';
import 'package:unipos/domain/services/common/unified_backup_service.dart';
import 'package:unipos/domain/services/common/notification_service.dart';

/// Shows the start-of-day backup prompt if a backup hasn't been done today.
/// Call from the welcome/home screen after the day is started.
///
/// Usage:
///   await StartOfDayBackupPrompt.show(context);
class StartOfDayBackupPrompt {
  /// Returns immediately if today's backup already exists.
  /// Otherwise shows a prompt → if confirmed, runs backup with progress overlay.
  static Future<void> show(BuildContext context) async {
    // Skip if today's backup is already done
    final lastBackup = await AutoBackupService.getLastBackupDate();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastBackup == today) return;

    if (!context.mounted) return;

    final doBackup = await _showPromptDialog(context);
    if (doBackup != true || !context.mounted) return;

    await _runWithOverlay(context);
  }

  // ---------------------------------------------------------------------------
  // Prompt Dialog
  // ---------------------------------------------------------------------------

  static Future<bool?> _showPromptDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.backup_rounded, size: 28, color: AppColors.success),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Back Up Data',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Text(
                "It's a new day! Would you like to back up your data before starting service?",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Skip Today',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  ),
                ),
                Container(width: 1, height: 48, color: Colors.grey.shade200),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Backup Now',
                      style: GoogleFonts.poppins(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress Overlay + Backup
  // ---------------------------------------------------------------------------

  static Future<void> _runWithOverlay(BuildContext context) async {
    // Show full-screen overlay — user cannot dismiss
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Creating Backup...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait, this may take a moment.\nDo not close the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Run the actual backup
    String? filePath;
    try {
      filePath = await UnifiedBackupService.exportToDownloads();
    } catch (_) {}

    if (!context.mounted) return;

    // Dismiss overlay
    Navigator.of(context, rootNavigator: true).pop();

    if (filePath != null) {
      // Mark today as backed up (no second backup run)
      await AutoBackupService.markTodayAsBackedUp();
      NotificationService.instance.showSuccess('Backup saved successfully!');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup failed. You can retry from the drawer menu.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}