import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Unified app dialogs — one consistent look for every alert/confirmation/error
/// across the app. Replaces ad-hoc `AlertDialog`/`Dialog` blocks so styling
/// never drifts between screens.
///
/// - [showAppConfirmDialog] → two-button confirmation, returns `true` if the
///   user confirmed, `false`/`null` otherwise.
/// - [showAppInfoDialog]    → single-button acknowledgement.
/// - [showAppErrorDialog]   → single-button error (danger accent), takes a
///   plain message OR a bulleted list of errors (e.g. missing fields).
///
/// All share an accent-tinted header (icon badge + title), a body, and
/// balanced full-width buttons (radius 10, rectangular).

/// Two-button confirmation dialog. Resolves to `true` when the user taps the
/// confirm button, otherwise `false`.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  Color? accent,
  IconData icon = Icons.help_outline_rounded,
  bool barrierDismissible = true,
}) async {
  final accentColor = accent ?? AppColors.primary;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AppDialogShell(
      title: title,
      body: _bodyText(message),
      accent: accentColor,
      icon: icon,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              cancelLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              confirmLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
  return result == true;
}

/// Single-button acknowledgement dialog (e.g. help/info messages).
Future<void> showAppInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String buttonLabel = 'Got it',
  Color? accent,
  IconData icon = Icons.info_outline_rounded,
}) {
  final accentColor = accent ?? AppColors.primary;
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialogShell(
      title: title,
      body: _bodyText(message),
      accent: accentColor,
      icon: icon,
      actions: [_singleButton(context, buttonLabel, accentColor)],
    ),
  );
}

/// Single-button error dialog (danger accent). Pass [errors] to render a
/// bulleted list (e.g. missing required fields), or [message] for plain text.
Future<void> showAppErrorDialog({
  required BuildContext context,
  String title = 'Missing Required Fields',
  String? message,
  List<String>? errors,
  String buttonLabel = 'OK',
  IconData icon = Icons.error_outline_rounded,
}) {
  final hasList = errors != null && errors.isNotEmpty;
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialogShell(
      title: title,
      accent: AppColors.danger,
      icon: icon,
      body: hasList ? _errorList(errors) : _bodyText(message ?? ''),
      actions: [_singleButton(context, buttonLabel, AppColors.danger)],
    ),
  );
}

// ── Shared body/action builders ──────────────────────────────────────────────

Widget _bodyText(String message) => Text(
      message,
      style: GoogleFonts.poppins(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
    );

Widget _errorList(List<String> errors) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: errors
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );

Widget _singleButton(BuildContext context, String label, Color color) =>
    Expanded(
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );

/// Standard cancel (outlined) button for app dialogs — drop into
/// [AppDialogShell.actions] alongside [appDialogPrimaryButton].
Widget appDialogCancelButton(BuildContext context, {String label = 'Cancel'}) =>
    Expanded(
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );

/// Standard primary (filled) button for app dialogs — drop into
/// [AppDialogShell.actions]. Forms own [onPressed] (validate, save, pop).
Widget appDialogPrimaryButton({
  required String label,
  required VoidCallback onPressed,
  Color? color,
}) =>
    Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );

/// Shared visual shell: rounded card, accent header (icon badge + title),
/// a body widget, and a full-width action row.
class AppDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Color accent;
  final IconData icon;
  final List<Widget> actions;

  const AppDialogShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    required this.accent,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                    AppResponsive.dialogWidth(context)) /
                2)
            .clamp(40.0, 200.0)
        : 24.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon badge + title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body — scrollable so a long error list never overflows
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: body,
            ),
          ),
          // Actions — IntrinsicHeight + stretch keeps buttons equal height
          // even when one label wraps to two lines.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
