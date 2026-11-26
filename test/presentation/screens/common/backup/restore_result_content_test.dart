import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/screens/common/backup/restore_skipped_notice.dart';

/// BKP-9: "Data imported successfully" only when nothing was skipped and
/// every post-restore step finished; otherwise "Import completed with
/// warnings", naming what was skipped or did not finish.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('restoreResultContent', () {
    test('clean: success title and message', () {
      for (final web in [false, true]) {
        final r = restoreResultContent(
            skipped: const [], postRestoreWarnings: const [], web: web);
        expect(r.title, 'Import Completed');
        expect(r.message, startsWith('Data imported successfully!'));
        expect(r.hasWarnings, isFalse);
        expect(r.message,
            contains(web ? 'Close this tab' : 'Please close and restart'));
      }
    });

    test('skipped sections: warning title, sections named, no success', () {
      final r = restoreResultContent(
          skipped: const ['printers', 'secureCreds'],
          postRestoreWarnings: const [],
          web: false);
      expect(r.title, 'Import completed with warnings');
      expect(r.hasWarnings, isTrue);
      expect(r.message, contains('printers, secureCreds'));
      expect(r.message, isNot(contains('successfully')));
      expect(r.message, contains('Please close and restart the app.'));
    });

    test('a failed post-restore step alone is a warning too', () {
      final r = restoreResultContent(
          skipped: const [],
          postRestoreWarnings: const [UnifiedBackupService.postStepItemImages],
          web: true);
      expect(r.title, 'Import completed with warnings');
      expect(r.message, contains('did not finish: reloading item images'));
      expect(r.message, isNot(contains('successfully')));
      expect(r.message, isNot(contains('These sections')));
    });

    test('both are listed', () {
      final r = restoreResultContent(
          skipped: const ['bundles'],
          postRestoreWarnings: const [
            UnifiedBackupService.postStepProductList,
            UnifiedBackupService.postStepStoreDetails,
          ],
          web: false);
      expect(r.message, contains('bundles'));
      expect(r.message, contains(
          'refreshing the product list, copying store details for receipts'));
    });
  });

  test('the restore dialog takes its content from the last restore result', () {
    final source =
        File('lib/domain/services/common/unified_backup_service.dart')
            .readAsStringSync();
    final start = source.indexOf('static Future<void> promptRestartAfterRestore');
    final end = source.indexOf('static Future<void> promptRestartAfterFailedRestore');
    expect(start, isNonNegative);
    final body = source.substring(start, end);
    expect(
        body,
        matches(RegExp(r'restoreResultContent\(\s*'
            r'skipped: lastRestoreSkippedSections,\s*'
            r'postRestoreWarnings: lastRestorePostRestoreWarnings,\s*'
            r'web: kIsWeb,')));
    expect(body, contains('title: content.title'));
    expect(body, contains('message: content.message'));
    expect(body,
        contains('content.hasWarnings ? AppColors.warning : AppColors.success'),
        reason: 'a warning result is not shown in the success colour');
    expect(body, isNot(contains("'Data imported successfully")),
        reason: 'the success text comes only from restoreResultContent');
  });

  group('onboarding notice', () {
    Future<void> show(WidgetTester tester, List<String> sections,
        {List<String>? post}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRestoreSkippedNotice(context, sections,
                  postRestoreWarnings: post),
              child: const Text('restored'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('restored'));
      await tester.pumpAndSettle();
    }

    tearDown(() {
      UnifiedBackupService.lastRestorePostRestoreWarnings = const [];
    });

    testWidgets('shows a failed post-restore step even with no skipped section',
        (tester) async {
      await show(tester, const [],
          post: const [UnifiedBackupService.postStepProductList]);
      expect(find.text('Import completed with warnings'), findsOneWidget);
      expect(find.textContaining('refreshing the product list'),
          findsOneWidget);
    });

    testWidgets('by default reads the last restore\'s post-restore warnings',
        (tester) async {
      UnifiedBackupService.lastRestorePostRestoreWarnings =
          const [UnifiedBackupService.postStepItemImages];
      await show(tester, const []);
      expect(find.text('Import completed with warnings'), findsOneWidget);
      expect(find.textContaining('reloading item images'), findsOneWidget);
    });

    testWidgets('nothing to report: no dialog', (tester) async {
      await show(tester, const []);
      expect(find.text('Import completed with warnings'), findsNothing);
    });
  });
}
