import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Set or change the backup password.
///
/// Extracted from the restaurant settings screen so retail gets the same
/// dialog rather than a second implementation — backups are always encrypted
/// and the password is the only way to read one back, so the two verticals
/// must not diverge on how it is set or validated.
///
/// Returns true when a password was saved.
Future<bool> showBackupPasswordDialog(
  BuildContext context, {
  bool isChange = false,
}) async {
  final pwdController = TextEditingController();
  final confirmController = TextEditingController();
  final pwdFocus = FocusNode();
  final confirmFocus = FocusNode();
  bool obscure = true;
  String? error;

  final saved = await showDialog<bool>(
    context: context,
    // Controllers disposed by the scope, never in a .then() — see
    // DialogDisposeScope for why disposing on dismiss crashes.
    builder: (ctx) => DialogDisposeScope(
      disposables: [pwdController, confirmController, pwdFocus, confirmFocus],
      child: StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> submit() async {
            final pwd = pwdController.text.trim();
            final err = BackupEncryptionService.validatePassword(
                pwd, confirmController.text.trim());
            if (err != null) {
              setDlgState(() => error = err);
              return;
            }
            await BackupEncryptionService.setPassword(pwd);
            if (ctx.mounted) Navigator.pop(ctx, true);
          }

          return AppDialogShell(
            title: isChange ? 'Change Backup Password' : 'Set Backup Password',
            subtitle: 'Encrypts and protects your backups',
            accent: AppColors.primary,
            icon: Icons.lock_outline_rounded,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: pwdController,
                  focusNode: pwdFocus,
                  autofocus: true,
                  label: 'Password (6 digits)',
                  hint: 'Enter 6-digit password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => confirmFocus.requestFocus(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: AppResponsive.smallIconSize(ctx),
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: confirmController,
                  focusNode: confirmFocus,
                  label: 'Confirm Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 14),
                _callout(
                  ctx,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  message: "Backups can't be recovered without this password. "
                      'Keep it safe.',
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  _callout(
                    ctx,
                    icon: Icons.error_outline_rounded,
                    color: AppColors.danger,
                    message: error!,
                  ),
                ],
              ],
            ),
            actions: [
              appDialogCancelButton(ctx),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: isChange ? 'Update' : 'Save',
                color: AppColors.primary,
                onPressed: submit,
              ),
            ],
          );
        },
      ),
    ),
  );

  return saved ?? false;
}

/// Confirm-and-clear the backup password.
///
/// Returns true when it was removed.
Future<bool> confirmRemoveBackupPassword(BuildContext context) async {
  final confirm = await showAppConfirmDialog(
    context: context,
    title: 'Remove Backup Password?',
    message: 'Backups will no longer be password-protected. Existing '
        'encrypted backups still need their original password to restore.',
    confirmLabel: 'Remove',
    accent: AppColors.danger,
    icon: Icons.lock_open_rounded,
  );
  if (!confirm) return false;
  await BackupEncryptionService.clearPassword();
  return true;
}

Widget _callout(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String message,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: color,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
