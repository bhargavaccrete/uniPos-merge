import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/screens/common/backup/restore_skipped_notice.dart';

/// SB-1e E5: after a successful restore that skipped unreadable backup
/// sections, the user is told which ones before setup moves on.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Runs the notice for [sections] and reports when it has finished.
  Future<List<String>> runNotice(
      WidgetTester tester, List<String> sections) async {
    final done = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showRestoreSkippedNotice(context, sections);
                done.add('next step');
              },
              child: const Text('restored'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('restored'));
    await tester.pumpAndSettle();
    return done;
  }

  testWidgets('lists the skipped sections and waits for the user',
      (tester) async {
    final done = await runNotice(tester, ['categories', 'shifts']);

    expect(find.text(restoreSkippedNoticeTitle), findsOneWidget);
    expect(find.textContaining('categories, shifts'), findsOneWidget);
    expect(done, isEmpty, reason: 'setup does not move on underneath it');

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(done, ['next step']);
  });

  testWidgets('shows nothing when no section was skipped', (tester) async {
    final done = await runNotice(tester, const []);

    expect(find.text(restoreSkippedNoticeTitle), findsNothing);
    expect(done, ['next step'], reason: 'setup continues straight away');
  });

  test('onboarding restore shows the notice before the next setup step', () {
    final source = File(
            'lib/presentation/screens/onboarding/existingUserRestoreScreen.dart')
        .readAsStringSync();
    final notice = source.indexOf(RegExp(
        r'showRestoreSkippedNotice\(\s*context,\s*UnifiedBackupService\.lastRestoreSkippedSections\)'));
    final advance = source.indexOf('// Advance to license activation step');

    expect(notice, isNonNegative,
        reason: 'the setup restore passes the skipped sections to the notice');
    expect(advance, greaterThan(notice));
  });
}
