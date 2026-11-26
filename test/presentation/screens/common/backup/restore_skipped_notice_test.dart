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

  // WF-6 (Option R): an onboarding restore no longer moves on to the next
  // setup step in the same session; it ends in the restart prompt every
  // restore uses. That prompt is where the skipped sections are named.
  test('onboarding restore names the skipped sections before the app moves on',
      () {
    final screen = File(
            'lib/presentation/screens/onboarding/existingUserRestoreScreen.dart')
        .readAsStringSync();
    expect(
        RegExp(r'onboardingRestoreFinished\s*=\s*UnifiedBackupService\.promptRestartAfterRestore;')
            .hasMatch(screen),
        isTrue,
        reason: 'the setup restore ends in the restore result prompt');
    expect(screen, contains('await onboardingRestoreFinished();'));

    final service = File(
            'lib/domain/services/common/unified_backup_service.dart')
        .readAsStringSync();
    final prompt = service.indexOf(
        'static Future<void> promptRestartAfterRestore() async {');
    final skipped = service.indexOf(
        'skipped: lastRestoreSkippedSections', prompt);
    final close = service.indexOf('if (!kIsWeb) exit(0);', prompt);
    expect(prompt, isNonNegative);
    expect(skipped, greaterThan(prompt),
        reason: 'the prompt passes the skipped sections to its message');
    expect(close, greaterThan(skipped),
        reason: 'they are shown before the app closes');
  });
}
