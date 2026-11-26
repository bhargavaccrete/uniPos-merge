import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/core/init/restore_record.dart';
import 'package:billberrylite/core/init/startup_recovery.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/screens/common/recovery/startup_recovery_screen.dart';

/// M4 startup recovery screen: shows what failed and how; Retry continues
/// only when every box opens; no way to continue with empty data.
void main() {
  late Directory dir;
  late PreservedFile copy;

  // As main() does: fonts are bundled, never fetched.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  HiveBoxFailure damaged(String box) => HiveBoxFailure(
        boxName: box,
        kind: HiveBoxFailureKind.corrupted,
        error: 'HiveError: Wrong checksum in hive file.',
        preserved: copy,
        detectedAt: DateTime(2026, 11, 16, 9, 30, 15),
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('recovery_screen_');
    final folder = Directory(p.join(dir.path, HivePreservation.folderName, 's'))
      ..createSync(recursive: true);
    final f = File(p.join(folder.path, 'restaurant_orders.hive'))
      ..writeAsBytesSync([1, 2, 3]);
    copy = PreservedFile(f.path, '${f.path}.manifest.json', 3, 'abc');
    HiveSafeOpen.hiveDirectory = dir.path;
  });

  tearDown(() {
    HiveSafeOpen.hiveDirectory = null;
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle briefly; the OS temp folder is fine.
    }
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<HiveBoxFailure> failures,
    required Future<void> Function() onRecovered,
    RecoveryActions actions = const RecoveryActions(),
    // Tall, so the lazily built list shows every card; real phone, tablet
    // and desktop sizes are covered by the layout tests at the end.
    Size size = const Size(420, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(StartupRecoveryApp(
      blocked: HiveStartupBlocked(failures),
      onRecovered: onRecovered,
      actions: actions,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the failed box, reason, preservation, location, time',
      (tester) async {
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')], onRecovered: () async {});
    expect(find.text('Some saved data could not be opened'), findsOneWidget);
    expect(find.text('restaurant_orders'), findsOneWidget);
    expect(find.text('Damaged data'), findsOneWidget);
    expect(find.textContaining('It was NOT repaired'), findsOneWidget);
    expect(find.text('Original kept: Yes — a verified copy was saved.'),
        findsOneWidget);
    expect(find.text(copy.path), findsOneWidget);
    expect(find.text('Detected: 16 Nov 2026, 09:30:15 AM'), findsOneWidget);
    expect(find.textContaining('Wrong checksum'), findsOneWidget);
    expect(find.text('No backup?'), findsOneWidget);
  });

  testWidgets('each failure kind is labelled for the owner', (tester) async {
    await pumpScreen(tester, size: const Size(1280, 2400), failures: [
      damaged('a_box'),
      HiveBoxFailure(boxName: 'b_box', kind: HiveBoxFailureKind.unreadable,
          error: 'unknown typeId', preserved: copy),
      HiveBoxFailure(boxName: 'c_box', kind: HiveBoxFailureKind.inaccessible,
          error: 'lock failed'),
      HiveBoxFailure(boxName: 'd_box',
          kind: HiveBoxFailureKind.preservationFailed,
          error: 'checksum', preservationError: 'disk full'),
    ], onRecovered: () async {});
    expect(find.text('Compatibility – may be from a newer app version'),
        findsOneWidget);
    expect(find.text('Temporarily in use'), findsOneWidget);
    expect(find.text('Damaged – safe copy failed'), findsOneWidget);
    expect(find.text('Original kept: Not needed — nothing was changed.'),
        findsOneWidget);
    expect(find.textContaining('could not be made (disk full)'), findsWidgets);
  });

  testWidgets('Retry continues startup once every box opens', (tester) async {
    var recovered = 0;
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')],
        onRecovered: () async => recovered++,
        actions: RecoveryActions(retry: () async => null));
    await tester.tap(find.byKey(const Key('recoveryRetry')));
    await tester.pumpAndSettle();
    expect(recovered, 1);
  });

  testWidgets('Retry keeps blocking while a box still fails', (tester) async {
    var recovered = 0;
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')],
        onRecovered: () async => recovered++,
        actions: RecoveryActions(
            retry: () async => HiveStartupBlocked([damaged('restaurant_tables')])));
    await tester.tap(find.byKey(const Key('recoveryRetry')));
    await tester.pumpAndSettle();
    expect(recovered, 0, reason: 'no normal startup while blocked');
    expect(find.text('restaurant_tables'), findsOneWidget);
    expect(find.text('Still could not open: restaurant_tables'), findsOneWidget);
  });

  testWidgets('a box that is only in use: Restore disabled, Retry offered',
      (tester) async {
    await pumpScreen(tester, failures: [
      HiveBoxFailure(boxName: 'restaurant_orders',
          kind: HiveBoxFailureKind.inaccessible, error: 'lock failed'),
    ], onRecovered: () async {});
    final restore =
        tester.widget<ButtonStyleButton>(find.byKey(const Key('recoveryRestore')));
    expect(restore.onPressed, isNull);
    expect(find.textContaining('tap Retry before restoring'), findsOneWidget);
    final retry =
        tester.widget<ButtonStyleButton>(find.byKey(const Key('recoveryRetry')));
    expect(retry.onPressed, isNotNull);
  });

  testWidgets('no way to continue with empty data: only Retry, Restore and '
      'Export exist', (tester) async {
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')], onRecovered: () async {});
    final buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton);
    expect(buttons, findsNWidgets(3));
    expect(find.byKey(const Key('recoveryRetry')), findsOneWidget);
    expect(find.byKey(const Key('recoveryRestore')), findsOneWidget);
    expect(find.byKey(const Key('recoveryExport')), findsOneWidget);
    for (final word in ['empty', 'Empty', 'Continue', 'Skip', 'Ignore']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('without a data folder (web) only Retry is offered',
      (tester) async {
    HiveSafeOpen.hiveDirectory = null;
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')], onRecovered: () async {});
    expect(find.byKey(const Key('recoveryRetry')), findsOneWidget);
    expect(find.byKey(const Key('recoveryRestore')), findsNothing);
    expect(find.byKey(const Key('recoveryExport')), findsNothing);
    expect(find.text('Browser version'), findsOneWidget);
  });

  testWidgets('a backup that fails the checks is never restored',
      (tester) async {
    var restoreRan = false;
    var recovered = 0;
    final missing = p.join(dir.path, 'not_a_backup.zip');
    File(missing).writeAsBytesSync(List.filled(64, 7));
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')],
        onRecovered: () async => recovered++,
        actions: RecoveryActions(
          pickBackupFile: () async => missing,
          runRestore: (_, _, _) async => restoreRan = true,
          prepareServices: () async {},
        ));
    await tester.tap(find.byKey(const Key('recoveryRestore')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recoveryPassword')), '123456');
    await tester.tap(find.text('Check Backup'));
    // The check reads the real file: let real time pass between frames (the
    // busy spinner never settles on its own).
    for (var i = 0; i < 100 && find.text('Backup Not Used').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Backup Not Used'), findsOneWidget);
    expect(find.textContaining('Nothing on this device was changed'),
        findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Replace Business Data?'), findsNothing,
        reason: 'a refused backup never reaches the confirmation');
    expect(restoreRan, isFalse);
    expect(recovered, 0);
  });

  testWidgets('importFromFilePath uses the password recovery already checked '
      'instead of asking again', (tester) async {
    // A complete encrypted-backup header whose contents no password opens:
    // the password step is reached (a prompt would show there) and fails.
    final file = p.join(dir.path, 'some_backup.zip');
    File(file).writeAsBytesSync([
      ...'BBLTENC1'.codeUnits,
      4, ...'abcd'.codeUnits,
      16, ...List.filled(16, 0),
      ...List.filled(32, 9),
    ]);
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await UnifiedBackupService
                .importFromFilePath(context, file, password: '123456'),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    for (var i = 0; i < 100 && result == null; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Encrypted Backup'), findsNothing,
          reason: 'no second password prompt');
    }
    expect(result, isFalse, reason: 'not a backup: refused, nothing restored');
  });

  testWidgets('a cancelled export says nothing was saved; the backup PIN is '
      'used without asking', (tester) async {
    String? usedPin;
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')],
        onRecovered: () async {},
        actions: RecoveryActions(
          storedPassword: () async => '654321',
          exportFile: (pin) async {
            usedPin = pin;
            return const ExportOutcome(ExportOutcomeKind.cancelled, null,
                note: 'Export cancelled.');
          },
        ));
    await tester.tap(find.byKey(const Key('recoveryExport')));
    await tester.pumpAndSettle();
    expect(usedPin, '654321');
    expect(find.text('Export Not Saved'), findsOneWidget);
    expect(find.textContaining('preserved files on this device were not '
        'changed'), findsOneWidget);
  });

  testWidgets('a failed export is reported clearly', (tester) async {
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')],
        onRecovered: () async {},
        actions: RecoveryActions(
          storedPassword: () async => '654321',
          exportFile: (_) async => throw ExportFailed(
              'The export could not be saved to Downloads (denied) or '
              'through the Save dialog (cancelled by system).'),
        ));
    await tester.tap(find.byKey(const Key('recoveryExport')));
    await tester.pumpAndSettle();
    expect(find.text('Export Failed'), findsOneWidget);
    expect(find.textContaining('Downloads (denied)'), findsOneWidget);
    expect(find.textContaining('were not changed'), findsOneWidget);
  });

  testWidgets('a saved export shows where it went', (tester) async {
    await pumpScreen(tester,
        failures: [damaged('restaurant_orders')],
        onRecovered: () async {},
        actions: RecoveryActions(
          storedPassword: () async => '654321',
          exportFile: (_) async => const ExportOutcome(
              ExportOutcomeKind.savedViaDialog, 'support.bblsupport'),
        ));
    await tester.tap(find.byKey(const Key('recoveryExport')));
    await tester.pumpAndSettle();
    expect(find.text('Export Saved'), findsOneWidget);
    expect(find.textContaining('the location you chose'), findsOneWidget);
    expect(find.textContaining('support.bblsupport'), findsOneWidget);
  });

  RestoreRecord record(RestoreSource source) => RestoreRecord(
        snapshotPath: copy.path,
        snapshotSha256: 'x',
        mode: 'restaurant',
        startedAt: DateTime(2026, 11, 16, 10, 5),
        source: source,
        pin: SnapshotPin.deviceBackupPin,
        journal: const [],
      );

  Future<void> pumpInterrupted(WidgetTester tester, RestoreRecord rec,
      {List<HiveBoxFailure> failures = const []}) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(StartupRecoveryApp(
      blocked: HiveStartupBlocked(failures, interruptedRestore: rec),
      onRecovered: () async => fail('must not continue normal startup'),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('BKP-5: interrupted normal restore → Undo, Restore, Export; '
      'no Retry, no continue', (tester) async {
    await pumpInterrupted(tester, record(RestoreSource.normal));
    expect(find.text('A restore did not finish'), findsOneWidget);
    expect(find.textContaining('16 Nov 2026, 10:05 AM'), findsOneWidget);
    expect(find.byKey(const Key('recoveryRetry')), findsNothing);
    expect(find.byKey(const Key('recoveryUndo')), findsOneWidget);
    final restore =
        tester.widget<ButtonStyleButton>(find.byKey(const Key('recoveryRestore')));
    expect(restore.onPressed, isNotNull,
        reason: 'C2: available with no damaged box');
    expect(find.byKey(const Key('recoveryExport')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNWidgets(3));
    for (final word in ['Continue', 'Skip', 'Ignore', 'empty']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('BKP-5: interrupted Recovery-screen restore → no Undo (C3)',
      (tester) async {
    await pumpInterrupted(tester, record(RestoreSource.recovery),
        failures: [damaged('restaurant_orders')]);
    expect(find.byKey(const Key('recoveryUndo')), findsNothing);
    expect(find.byKey(const Key('recoveryRetry')), findsNothing);
    expect(find.byKey(const Key('recoveryRestore')), findsOneWidget);
    expect(find.text('restaurant_orders'), findsOneWidget,
        reason: 'the M4 damaged box is still shown');
  });

  testWidgets('BKP-5: an unreadable record → no Undo, Restore offered',
      (tester) async {
    await pumpInterrupted(tester, RestoreRecord.unreadable());
    expect(find.byKey(const Key('recoveryUndo')), findsNothing);
    expect(find.byKey(const Key('recoveryRetry')), findsNothing);
    expect(find.textContaining('details could not be read'), findsOneWidget);
  });

  for (final size in const [Size(360, 740), Size(800, 1280), Size(1440, 900)]) {
    testWidgets('lays out without overflow at ${size.width}x${size.height}',
        (tester) async {
      await pumpScreen(tester,
          size: size,
          failures: [damaged('restaurant_orders'), damaged('restaurant_tables')],
          onRecovered: () async {});
      expect(tester.takeException(), isNull);
    });
  }
}
