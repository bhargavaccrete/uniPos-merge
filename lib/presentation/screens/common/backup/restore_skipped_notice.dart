import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/color.dart';

const String restoreSkippedNoticeTitle = 'Some data was not restored';

/// The message for [sections] the restore could not read and skipped.
String restoreSkippedNoticeMessage(List<String> sections) =>
    'These sections of the backup could not be read and were not restored: '
    '${sections.join(', ')}.\n\nEverything else was restored. You can enter '
    'this data again, or try a newer backup file.';

/// Tells the user which backup sections a successful restore skipped, so a
/// restore that "succeeded" is never mistaken for a complete one. Does
/// nothing when [sections] is empty.
Future<void> showRestoreSkippedNotice(
    BuildContext context, List<String> sections) async {
  if (sections.isEmpty) return;
  await showAppInfoDialog(
    context: context,
    title: restoreSkippedNoticeTitle,
    message: restoreSkippedNoticeMessage(sections),
    buttonLabel: 'OK',
    accent: AppColors.warning,
    icon: Icons.warning_amber_rounded,
  );
}
