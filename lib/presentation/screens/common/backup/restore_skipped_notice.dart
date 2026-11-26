import 'package:flutter/material.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/color.dart';

const String restoreSkippedNoticeTitle = 'Import completed with warnings';
const String restoreSuccessTitle = 'Import Completed';
const String restoreSuccessMessage = 'Data imported successfully!';

/// The message for [sections] the restore could not restore and left as they
/// were, and for [postRestoreWarnings], steps after the writes that did not
/// finish.
String restoreSkippedNoticeMessage(List<String> sections,
    [List<String> postRestoreWarnings = const []]) {
  return [
    if (sections.isNotEmpty)
      'These sections of the backup could not be restored and were left as '
          'they were on this device: ${sections.join(', ')}.',
    if (postRestoreWarnings.isNotEmpty)
      'These steps after the restore did not finish: '
          '${postRestoreWarnings.join(', ')}.',
    sections.isNotEmpty
        ? 'Everything else was restored. You can enter this data again, or '
            'try a newer backup file.'
        : 'Everything else was restored.',
  ].join('\n\n');
}

/// Title and message of the dialog after a successful restore (BKP-9):
/// "Data imported successfully" only when nothing was skipped and every
/// post-restore step finished; otherwise "Import completed with warnings".
({String title, String message, bool hasWarnings}) restoreResultContent({
  required List<String> skipped,
  required List<String> postRestoreWarnings,
  required bool web,
}) {
  final restart = web
      ? 'Close this tab and open the app again to load the restored data.'
      : 'Please close and restart the app.';
  if (skipped.isEmpty && postRestoreWarnings.isEmpty) {
    return (
      title: restoreSuccessTitle,
      message: '$restoreSuccessMessage\n\n$restart',
      hasWarnings: false,
    );
  }
  return (
    title: restoreSkippedNoticeTitle,
    message:
        '${restoreSkippedNoticeMessage(skipped, postRestoreWarnings)}\n\n$restart',
    hasWarnings: true,
  );
}

/// Tells the user which backup sections a successful restore skipped, and
/// which post-restore steps did not finish (by default those of the last
/// restore), so a restore that "succeeded" is never mistaken for a complete
/// one. Does nothing when there is neither.
Future<void> showRestoreSkippedNotice(
    BuildContext context, List<String> sections,
    {List<String>? postRestoreWarnings}) async {
  final post =
      postRestoreWarnings ?? UnifiedBackupService.lastRestorePostRestoreWarnings;
  if (sections.isEmpty && post.isEmpty) return;
  await showAppInfoDialog(
    context: context,
    title: restoreSkippedNoticeTitle,
    message: restoreSkippedNoticeMessage(sections, post),
    buttonLabel: 'OK',
    accent: AppColors.warning,
    icon: Icons.warning_amber_rounded,
  );
}
