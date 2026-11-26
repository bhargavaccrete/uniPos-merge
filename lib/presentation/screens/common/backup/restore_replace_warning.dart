import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/color.dart';

const String restoreReplaceWarningTitle = 'Replace all current data?';

const String restoreReplaceWarningMessage =
    'Restoring this backup replaces the data on this device with the data in '
    'the backup — orders and sales, items and stock, customers, staff, '
    'suppliers, day-end records and settings. It does not merge them: '
    'anything recorded on this device after the backup was made will be '
    'lost. If you might need the current data, export a backup of it first.';

/// The one confirmation every restore on a set-up device goes through: a
/// restore clears each box and writes the backup's records in its place, so
/// the user must know nothing is merged. Resolves to `true` only when the
/// user taps "Replace data".
Future<bool> confirmRestoreReplacesData(BuildContext context) {
  return showAppConfirmDialog(
    context: context,
    title: restoreReplaceWarningTitle,
    message: restoreReplaceWarningMessage,
    confirmLabel: 'Replace data',
    cancelLabel: 'Cancel',
    accent: AppColors.danger,
    icon: Icons.warning_amber_rounded,
  );
}
