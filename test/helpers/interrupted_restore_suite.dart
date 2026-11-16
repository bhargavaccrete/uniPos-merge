import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/core/init/recovery_journal.dart';
import 'package:billberrylite/core/init/restore_record.dart';
import 'package:billberrylite/core/init/startup_recovery.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/screens/common/recovery/startup_recovery_screen.dart';

import 'backup_box_registry.dart';
import 'startup_recovery_suite.dart' show FakeDocuments;

/// BKP-5 end to end for one business mode, on real files: a restore is
/// killed at a precise point (`SimulatedProcessKill`: no rollback runs, as in
/// a dead process), the app "restarts" (boxes closed, startup run again), and
/// recovery is driven through the real restore path.
void interruptedRestoreSuite({required String mode}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  const devicePin = '246810';
  const backupPin = '975310';
  late Directory root;
  late String docs;
  late Map<String, dynamic> backup;
  late String backupFile;

  final journalBox = mode == 'retail'
      ? HiveBoxNames.retailCheckoutJournal
      : HiveBoxNames.restaurantStockJournal;
  final journalBefore = <String, Map<String, Object?>>{
    'e1': {'v': 1, 'id': 'e1', 'qty': 2, 'price': 12.5, 'lines': ['a', 'b']},
    'e2': {'v': 1, 'id': 'e2', 'qty': 1, 'note': null, 'saved': true},
  };

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box journal() => Hive.box(journalBox);
  String hashOf(File f) => sha256.convert(f.readAsBytesSync()).toString();
  String journalState() => jsonEncode({
        for (final k in (journal().keys.map((k) => '$k').toList()..sort()))
          k: journal().get(k),
      });
  final expectedJournal = jsonEncode(journalBefore);
  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Future<void> usePin(String? pin) async {
    FlutterSecureStorage.setMockInitialValues({});
    if (pin != null) await BackupEncryptionService.setPassword(pin);
  }

  void resetHooks() {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    UnifiedBackupService.killAfterWritingKeyForTesting = null;
    UnifiedBackupService.killDuringRollbackAfterKeyForTesting = null;
    UnifiedBackupService.killDuringWorkJournalClearForTesting = null;
    UnifiedBackupService.afterBackupWriteForTesting = null;
  }

  /// The app process restarts: boxes closed, statics reset, startup run.
  Future<HiveStartupBlocked?> restart() async {
    resetHooks();
    await Hive.close();
    if (locator.isRegistered<BusinessTypeRepository>()) {
      await resetServiceLocator();
    }
    HiveSafeOpen.resetForTesting();
    HivePreservation.resetForTesting();
    await RecoveryJournal.resolvePendingAtStartup(docs);
    return StartupRecovery.retry();
  }

  /// The existing restore of a backup file (what importFromFilePath runs).
  Future<bool> restoreFile(String path, String pin,
      {RestoreSource source = RestoreSource.normal}) async {
    await UnifiedBackupService.restoreDecodedBackupForTesting(
        await UnifiedBackupService.readBackupFileForTesting(path, pin),
        password: pin,
        source: source);
    return true;
  }

  Future<void> killedRestore(
      {String? killKey, int? killJournalAfter, String password = backupPin,
      RestoreSource source = RestoreSource.normal}) async {
    UnifiedBackupService.killAfterWritingKeyForTesting = killKey;
    UnifiedBackupService.killDuringWorkJournalClearForTesting = killJournalAfter;
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          password: password, source: source),
      throwsA(isA<SimulatedProcessKill>()),
    );
  }

  void expectDeviceData() {
    expect(sessions().keys, ['sess-device']);
    expect(journalState(), expectedJournal);
  }

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('interrupted_restore_$mode');
    docs = (Directory(p.join(root.path, 'documents'))..createSync()).path;
    PathProviderPlatform.instance = FakeDocuments(docs);
    await usePin(devicePin);
    HivePreservation.appVersionLookup = () async => 'test';
    await openBoxesFor(mode, Directory(docs));
    await AppConfig.box.put('isSetupComplete', true);
    HiveSafeOpen.hiveDirectory = docs;

    await sessions().clear();
    await sessions().put(
        'sess-backup',
        RestaurantSessionModel(
            sessionId: 'sess-backup',
            startTime: DateTime(2026, 11, 14, 8),
            openingCash: 1000));
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
    // The same data as a real backup file (locked with the device PIN).
    final out = Directory(p.join(root.path, 'backups'))..createSync();
    backupFile = (await UnifiedBackupService.createBackupFileForTesting(out))!;
  });

  setUp(() async {
    await RestoreRecordStore.close(docs, 'test-cleanup');
    expect(await restart(), isNull, reason: 'clean start');
    await prepareServicesForRecovery();
    await usePin(devicePin);
    await sessions().clear();
    await sessions().put(
        'sess-device',
        RestaurantSessionModel(
            sessionId: 'sess-device',
            startTime: DateTime(2026, 11, 16, 8),
            openingCash: 300));
    await journal().clear();
    await journal().putAll(journalBefore);
    expectDeviceData();
  });

  tearDownAll(() async {
    resetHooks();
    await Hive.close();
    await locator.reset();
    for (var i = 0; root.existsSync() && i < 50; i++) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test('$mode: killed during _restoreAllData → the next start is blocked; '
      'the journal is not replayed; a verified snapshot and record exist',
      () async {
    await killedRestore(killKey: 'restaurantSessions');
    expect(sessions().keys, ['sess-backup'], reason: 'partly restored');

    final blocked = await restart();
    expect(blocked, isNotNull, reason: 'no normal start on mixed data');
    final record = blocked!.interruptedRestore!;
    expect(blocked.failures, isEmpty);
    expect([record.mode, record.source, record.pin, record.canUndo],
        [mode, RestoreSource.normal, SnapshotPin.deviceBackupPin, true]);
    expect(RestoreRecordStore.snapshotIntact(record), isTrue);
    expect(jsonEncode({for (final e in record.journal) '${e.key}': e.value}),
        expectedJournal, reason: 'the journal copy survived the kill');
    expect(journalState(), expectedJournal,
        reason: 'nothing consumed or replayed the pending entries');
    expect(StartupRecovery.canRestore(const [], interrupted: record), isTrue,
        reason: 'C2: Restore a backup is available with no damaged box');

    expect(await StartupRecovery.retry(), isNotNull,
        reason: 'Retry can never continue while the record is open');
  });

  test('$mode: Undo puts back the original data AND journal, then startup '
      'continues', () async {
    await killedRestore(killKey: 'restaurantSessions');
    final record = (await restart())!.interruptedRestore!;

    final outcome = await StartupRecovery.undo(
      record: record,
      runRestore: (path) => restoreFile(path, devicePin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(outcome.result, RecoveryRestoreResult.restored,
        reason: '${outcome.error}');
    expectDeviceData();
    expect(RestoreRecordStore.read(docs), isNull);
    expect(await restart(), isNull, reason: 'normal startup allowed again');
    expectDeviceData();
  });

  test('$mode: no device PIN stored → the snapshot is locked with the '
      'restored backup\'s PIN; Undo needs that PIN', () async {
    await usePin(null);
    await killedRestore(killKey: 'restaurantSessions');
    final record = (await restart())!.interruptedRestore!;
    expect(record.pin, SnapshotPin.restoredBackupPin);

    final wrong = await StartupRecovery.undo(
      record: record,
      runRestore: (path) => restoreFile(path, devicePin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(wrong.result, RecoveryRestoreResult.failed);
    expect(wrong.blocked!.interruptedRestore, isNotNull);
    expect(RestoreRecordStore.snapshotIntact(record), isTrue);

    final right = await StartupRecovery.undo(
      record: (await restart())!.interruptedRestore!,
      runRestore: (path) => restoreFile(path, backupPin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(right.result, RecoveryRestoreResult.restored, reason: '${right.error}');
    expectDeviceData();
  });

  test('$mode: killed while clearing the journal → blocked; Undo brings every '
      'entry back', () async {
    await killedRestore(killJournalAfter: 1);
    final blocked = await restart();
    expect(journal().length, 1, reason: 'the clear had started');
    final outcome = await StartupRecovery.undo(
      record: blocked!.interruptedRestore!,
      runRestore: (path) => restoreFile(path, devicePin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(outcome.result, RecoveryRestoreResult.restored);
    expectDeviceData();
  });

  test('$mode: killed during the rollback → the record stays open; Undo '
      'recovers', () async {
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';
    UnifiedBackupService.killDuringRollbackAfterKeyForTesting = 'paymentMethods';
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          password: backupPin),
      throwsA(isA<SimulatedProcessKill>()),
    );
    final blocked = await restart();
    final outcome = await StartupRecovery.undo(
      record: blocked!.interruptedRestore!,
      runRestore: (path) => restoreFile(path, devicePin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(outcome.result, RecoveryRestoreResult.restored);
    expectDeviceData();
  });

  test('$mode: a verified rollback closes the record; an unverified one '
      'keeps it open (R4)', () async {
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          password: backupPin),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );
    expect(RestoreRecordStore.read(docs), isNull);
    expect(await restart(), isNull);

    await prepareServicesForRecovery();
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';
    UnifiedBackupService.failRollbackWritingKeyForTesting = 'paymentMethods';
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          password: backupPin),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.dataRolledBack, 'dataRolledBack', isFalse)),
    );
    final blocked = await restart();
    expect(blocked!.interruptedRestore, isNotNull,
        reason: 'never start on data a rollback could not verify');
  });

  test('$mode: an interrupted Undo keeps the ORIGINAL record and snapshot; '
      'a second Undo succeeds', () async {
    await killedRestore(killKey: 'restaurantSessions');
    final record = (await restart())!.interruptedRestore!;
    final snapshotHash = hashOf(File(record.snapshotPath));
    final recordText = RestoreRecordStore.file(docs).readAsStringSync();

    final first = await StartupRecovery.undo(
      record: record,
      runRestore: (path) {
        UnifiedBackupService.killAfterWritingKeyForTesting = 'restaurantSessions';
        return restoreFile(path, devicePin);
      },
      prepareServices: prepareServicesForRecovery,
    );
    expect(first.result, RecoveryRestoreResult.failed);
    expect(RestoreRecordStore.file(docs).readAsStringSync(), recordText,
        reason: 'R2: the record still points to the true original');
    expect(hashOf(File(record.snapshotPath)), snapshotHash,
        reason: 'R1: the original snapshot was not deleted or replaced');

    final again = (await restart())!.interruptedRestore!;
    expect(again.snapshotPath, record.snapshotPath);
    final second = await StartupRecovery.undo(
      record: again,
      runRestore: (path) => restoreFile(path, devicePin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(second.result, RecoveryRestoreResult.restored);
    expectDeviceData();
  });

  test('$mode: an interrupted "Restore a backup" keeps the original record; '
      'a successful one closes it', () async {
    await killedRestore(killKey: 'restaurantSessions');
    final record = (await restart())!.interruptedRestore!;
    final recordText = RestoreRecordStore.file(docs).readAsStringSync();

    final killed = await StartupRecovery.restore(
      failures: const [],
      interrupted: record,
      runRestore: () {
        UnifiedBackupService.killAfterWritingKeyForTesting = 'restaurantSessions';
        return restoreFile(backupFile, devicePin);
      },
      prepareServices: prepareServicesForRecovery,
    );
    expect(killed.result, RecoveryRestoreResult.failed);
    expect(killed.blocked!.interruptedRestore, isNotNull);
    expect(RestoreRecordStore.file(docs).readAsStringSync(), recordText);
    expect(RestoreRecordStore.snapshotIntact(record), isTrue);

    final ok = await StartupRecovery.restore(
      failures: const [],
      interrupted: (await restart())!.interruptedRestore,
      runRestore: () => restoreFile(backupFile, devicePin),
      prepareServices: prepareServicesForRecovery,
    );
    expect(ok.result, RecoveryRestoreResult.restored, reason: '${ok.error}');
    expect(RestoreRecordStore.read(docs), isNull);
    expect(sessions().keys, ['sess-backup']);
    expect(journal().isEmpty, isTrue,
        reason: 'a restored backup never inherits the old pending work');
    expect(await restart(), isNull);
  });

  test('$mode: a successful normal restore closes its own record; startup '
      'stays normal', () async {
    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
        password: backupPin);
    expect(RestoreRecordStore.read(docs), isNull);
    final closed = Directory(p.join(docs, RestoreRecordStore.folderName))
        .listSync()
        .map((f) => p.basename(f.path))
        .where((n) => n.startsWith('restore_completed_'));
    expect(closed, isNotEmpty, reason: 'closed, renamed, kept');
    expect(await restart(), isNull);
    expect(sessions().keys, ['sess-backup']);
  });

  test('$mode: a missing or changed snapshot is never used for Undo',
      () async {
    await killedRestore(killKey: 'restaurantSessions');
    final record = (await restart())!.interruptedRestore!;
    final snap = File(record.snapshotPath);
    final original = snap.readAsBytesSync();
    final b = Uint8List.fromList(original);
    b[b.length ~/ 2] ^= 0xFF;
    snap.writeAsBytesSync(b);
    var ran = false;
    final outcome = await StartupRecovery.undo(
      record: record,
      runRestore: (_) async => ran = true,
      prepareServices: prepareServicesForRecovery,
    );
    expect(outcome.result, RecoveryRestoreResult.notStarted);
    expect(ran, isFalse);
    expect(RestoreRecordStore.read(docs), isNotNull, reason: 'still blocked');
    snap.writeAsBytesSync(original);
  });

  test('$mode: no verified snapshot → refused before ANY business write',
      () async {
    final sessionsBefore = sessions().keys.toList();
    // The snapshot write reads back wrong (BKP-11 check fails).
    UnifiedBackupService.afterBackupWriteForTesting = (part) async {
      final b = part.readAsBytesSync();
      b[b.length ~/ 2] ^= 0xFF;
      part.writeAsBytesSync(b);
    };
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          password: backupPin),
      throwsA(predicate((e) =>
          '$e'.contains("a safety copy of this device's data could not be "
              'saved and checked'))),
    );
    UnifiedBackupService.afterBackupWriteForTesting = null;
    expect(sessions().keys, sessionsBefore);
    expect(journalState(), expectedJournal);
    expect(RestoreRecordStore.read(docs), isNull);

    // No PIN anywhere: no snapshot can be locked → refused too.
    await usePin(null);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          password: ''),
      throwsA(predicate((e) =>
          '$e'.contains("a safety copy of this device's data could not be "
              'saved and checked'))),
    );
    expectDeviceData();
    expect(RestoreRecordStore.read(docs), isNull);
  });

  test('$mode: a Recovery-screen restore killed mid-write keeps M4 blocking; '
      'no Undo; Restore a backup recovers', () async {
    // A damaged box, as M4 handles it.
    await Hive.close();
    final live = File(p.join(docs,
        '${HiveBoxNames.dayManagementBox.toLowerCase()}.hive'));
    final day = await Hive.openBox(HiveBoxNames.dayManagementBox);
    for (var i = 0; i < 4; i++) {
      await day.put('k$i', 'device-$i-${'x' * 20}');
    }
    await Hive.close();
    final b = live.readAsBytesSync();
    final second = ByteData.sublistView(b).getUint32(0, Endian.little);
    b[second + 12] ^= 0xFF;
    live.writeAsBytesSync(b);
    final damaged = hashOf(live);

    final blocked = await restart();
    expect(blocked!.failures.single.boxName, HiveBoxNames.dayManagementBox);

    // The M4 steps, then the process dies inside the restore itself.
    await RecoveryJournal.moveAside(docs, [HiveBoxNames.dayManagementBox]);
    expect(await StartupRecovery.retry(forRestore: true), isNull);
    await prepareServicesForRecovery();
    await killedRestore(
        killKey: 'restaurantSessions', source: RestoreSource.recovery);

    final after = await restart();
    expect(hashOf(live), damaged, reason: 'M4 put the damaged original back');
    expect(after!.failures.single.boxName, HiveBoxNames.dayManagementBox);
    final record = after.interruptedRestore!;
    expect(record.source, RestoreSource.recovery);
    expect(record.canUndo, isFalse,
        reason: 'C3: its snapshot holds the empty stand-in box');
    final undo = await StartupRecovery.undo(
        record: record, runRestore: (_) async => true);
    expect(undo.result, RecoveryRestoreResult.notStarted);

    final ok = await StartupRecovery.restore(
      failures: after.failures,
      interrupted: record,
      runRestore: () =>
          restoreFile(backupFile, devicePin, source: RestoreSource.recovery),
      prepareServices: prepareServicesForRecovery,
    );
    expect(ok.result, RecoveryRestoreResult.restored, reason: '${ok.error}');
    expect(RestoreRecordStore.read(docs), isNull);
    expect(RecoveryJournal.hasPending(docs), isFalse);
    expect(await restart(), isNull);
    // Leave a healthy day box for any later test.
    await Hive.close();
    if (live.existsSync() && hashOf(live) == damaged) live.deleteSync();
  });
}
