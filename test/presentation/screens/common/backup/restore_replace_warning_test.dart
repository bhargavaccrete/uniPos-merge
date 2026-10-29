import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/screens/common/backup/restore_replace_warning.dart';

/// SB-1w: a restore replaces this device's data, it never merges. Every
/// restore on a set-up device confirms that through one shared warning.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Opens the warning from a button and records what it resolved to.
  Future<List<bool>> openWarning(WidgetTester tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  results.add(await confirmRestoreReplacesData(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('shows the replace-not-merge warning', (tester) async {
    await openWarning(tester);

    expect(find.text('Replace all current data?'), findsOneWidget);
    expect(find.text(restoreReplaceWarningMessage), findsOneWidget);
    expect(restoreReplaceWarningMessage,
        contains('replaces the data on this device with the data in the backup'));
    expect(restoreReplaceWarningMessage, contains('It does not merge them'));
    expect(restoreReplaceWarningMessage,
        contains('anything recorded on this device after the backup was made will be lost'));
    expect(restoreReplaceWarningMessage,
        contains('export a backup of it first'));
    expect(find.text('Replace data'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Cancel resolves to false', (tester) async {
    final results = await openWarning(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(find.text('Replace all current data?'), findsNothing);
  });

  testWidgets('Replace data resolves to true', (tester) async {
    final results = await openWarning(tester);

    await tester.tap(find.text('Replace data'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  test('no backup screen still says a restore "adds" data', () {
    final dir = Directory('lib/presentation/screens/common/backup');
    expect(dir.existsSync(), isTrue);

    final offenders = <String>[
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            f.readAsStringSync().toLowerCase().contains('add data'))
          f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'a restore replaces data; "add data" wording misleads users');
  });
}
