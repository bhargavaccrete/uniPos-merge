import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Compact Download / Share / Import dialog.
///
/// The Web fallback for [BackupScreen] in both modes — that screen lists local
/// backup files with `dart:io`, which Web does not have. Extracted unchanged
/// from the restaurant Settings screen; the caller applies the entitlement
/// gate.
void showBackupRestoreDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AppDialogShell(
      title: 'Backup & Restore',
      subtitle: 'Export your data, or restore from a backup file',
      accent: AppColors.primary,
      icon: Icons.backup_rounded,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(
            dialogContext,
            label: 'Download Backup',
            icon: Icons.download,
            color: Colors.green,
            onPressed: () => _export(dialogContext, share: false),
          ),
          AppResponsive.verticalSpace(dialogContext, size: SpacingSize.medium),
          _actionButton(
            dialogContext,
            label: 'Share Backup',
            icon: Icons.share,
            color: Colors.blue,
            onPressed: () => _export(dialogContext, share: true),
          ),
          AppResponsive.verticalSpace(dialogContext, size: SpacingSize.medium),
          const Divider(),
          AppResponsive.verticalSpace(dialogContext, size: SpacingSize.small),
          _actionButton(
            dialogContext,
            label: 'Import Backup',
            icon: Icons.restore,
            color: Colors.orange,
            onPressed: () => _import(dialogContext),
          ),
        ],
      ),
      actions: [appDialogCancelButton(dialogContext, label: 'Close')],
    ),
  );
}

Widget _actionButton(
  BuildContext context, {
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onPressed,
}) {
  return ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      minimumSize: Size(double.infinity, AppResponsive.buttonHeight(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: Icon(icon, color: Colors.white),
    label: Text(
      label,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: AppResponsive.buttonFontSize(context),
      ),
    ),
    onPressed: onPressed,
  );
}

Future<void> _export(BuildContext dialogContext, {required bool share}) async {
  if (!await UnifiedBackupService.ensureBackupPassword(dialogContext)) return;
  if (!dialogContext.mounted) return;
  final navigator = Navigator.of(dialogContext, rootNavigator: true);
  Navigator.pop(dialogContext);

  _showProgress(navigator.context);
  String? filePath;
  try {
    filePath = share
        ? await UnifiedBackupService.exportToShare()
        : await UnifiedBackupService.exportToDownloads();
  } catch (e) {
    debugPrint('❌ Backup error: $e');
  } finally {
    try {
      navigator.pop();
    } catch (e) {
      debugPrint('❌ Error closing dialog: $e');
    }
  }

  await Future.delayed(const Duration(milliseconds: 300));

  // NotificationService is global — no context needed; the dialog context
  // above is already gone.
  if (filePath == null) {
    NotificationService.instance.showError(
      share ? 'Backup creation failed' : 'Backup failed. Please try again.',
      duration: const Duration(seconds: 5),
    );
    return;
  }
  if (share) {
    await Share.shareXFiles([XFile(filePath)], subject: 'Bill Berry Lite Backup');
  } else {
    NotificationService.instance.showSuccess(
      'Backup saved successfully\n$filePath',
      duration: const Duration(seconds: 5),
    );
  }
}

Future<void> _import(BuildContext dialogContext) async {
  Navigator.pop(dialogContext); // close the backup menu
  bool success = false;
  try {
    success = await UnifiedBackupService.importData(dialogContext);
  } catch (e) {
    debugPrint('Import error: $e');
  }
  if (success) await UnifiedBackupService.promptRestartAfterRestore();
}

void _showProgress(BuildContext context) {
  final hInset = !AppResponsive.isMobile(context)
      ? ((AppResponsive.screenWidth(context) -
                    AppResponsive.dialogWidth(context)) /
                2)
            .clamp(40.0, double.infinity)
      : 24.0;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            AppResponsive.verticalSpace(ctx, size: SpacingSize.medium),
            Text(
              'Creating backup...\nPlease wait',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(ctx),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
