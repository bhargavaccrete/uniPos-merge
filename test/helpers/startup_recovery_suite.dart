import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/core/init/recovery_journal.dart';
import 'package:billberrylite/core/init/startup_recovery.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/screens/common/recovery/startup_recovery_screen.dart';

import 'backup_box_registry.dart';

class FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakeDocuments(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

/// Writes [data] in the backup file format (encrypted data.json, AES zip,
/// encrypted outer blob) — used to build a backup missing a section.
void writeBackupFile(Map<String, dynamic> data, String password, String path) {
  final inner = utf8.encode(
      jsonEncode(BackupEncryptionService.encryptData(jsonEncode(data), password)));
  final archive = Archive()
    ..addFile(ArchiveFile('data.json', inner.length, inner));
  final zip = ZipEncoder(password: password).encode(archive)!;
  File(path).writeAsBytesSync(
      BackupEncryptionService.encryptBytes(Uint8List.fromList(zip), password));
}

/// M4 startup recovery, end to end on real files, a real backup and the real
/// restore, for one business mode.
void startupRecoverySuite({
  required String mode,
  required String damagedBox,
  required String criticalSectionToDrop,
  required Future<void> Function() seedBackupData,
  required Future<void> Function() changeDeviceData,
  required void Function() expectBackupData,
  required void Function() expectDeviceData,
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = '246810';
  late Directory root;
  late String docs;
  late String backupPath;
  late Uint8List damagedBytes;
  late File live;

  String hashOf(List<int> b) => sha256.convert(b).toString();
  Directory preservedRoot() =>
      Directory(p.join(docs, HivePreservation.folderName));
  List<File> filesUnder(Directory d) => d.existsSync()
      ? (d.listSync(recursive: true).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  Future<bool> realRestore(String path) async {
    // The existing restore (the one importFromFilePath runs after its
    // password prompt): BKP-9 validation, snapshot, journal transaction,
    // rollback and verification.
    await UnifiedBackupService.restoreDecodedBackupForTesting(
        await UnifiedBackupService.readBackupFileForTesting(path, password));
    return true;
  }

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('startup_recovery_$mode');
    docs = (Directory(p.join(root.path, 'documents'))..createSync()).path;
    PathProviderPlatform.instance = FakeDocuments(docs);
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor(mode, Directory(docs));
    await AppConfig.box.put('isSetupComplete', true);
    await BackupEncryptionService.setPassword(password);
    HivePreservation.appVersionLookup = () async => 'test';

    await seedBackupData();
    final out = Directory(p.join(root.path, 'backups'))..createSync();
    backupPath = (await UnifiedBackupService.createBackupFileForTesting(out))!;
    await changeDeviceData();
    await Hive.close();

    live = File(p.join(docs, '${damagedBox.toLowerCase()}.hive'));
    final b = live.readAsBytesSync();
    final second = ByteData.sublistView(b).getUint32(0, Endian.little);
    b[second + 12] ^= 0xFF; // inside the 2nd record: middle damage
    live.writeAsBytesSync(b);
    damagedBytes = live.readAsBytesSync();
  });

  setUp(() async {
    await Hive.close();
    if (locator.isRegistered<BusinessTypeRepository>()) {
      await resetServiceLocator();
    }
    UnifiedBackupService.failWritingKeyForTesting = null;
    StartupRecovery.afterExportWriteForTesting = null;
    HiveSafeOpen.resetForTesting();
    HivePreservation.resetForTesting();
    HivePreservation.appVersionLookup = () async => 'test';
    expect(RecoveryJournal.hasPending(docs), isFalse);
    live.writeAsBytesSync(damagedBytes);
    HiveInit.forgetOpenedGroups();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await Hive.close();
    await locator.reset();
    for (var i = 0; root.existsSync(); i++) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        if (i > 50) break;
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test('$mode: startup is blocked; Retry keeps blocking while the box is '
      'still damaged; nothing is copied twice', () async {
    final first = await StartupRecovery.retry();
    expect(first, isNotNull);
    final failure = first!.failures.single;
    expect(failure.boxName, damagedBox);
    expect(failure.kind, HiveBoxFailureKind.corrupted);
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes));
    expect(hashOf(File(failure.preserved!.path).readAsBytesSync()),
        hashOf(damagedBytes));
    expect(locator.isRegistered<BusinessTypeRepository>(), isFalse,
        reason: 'no service may start while blocked');

    final second = await StartupRecovery.retry();
    expect(second!.failures.single.boxName, damagedBox);
    expect(second.failures.single.preserved!.path, failure.preserved!.path,
        reason: 'the identical bytes reuse the verified copy');
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes));
  });

  test('$mode: the full backup passes the checks; a wrong password is '
      'rejected', () async {
    await StartupRecovery.retry();
    expect(
        await StartupRecovery.checkBackup(
            path: backupPath, password: password, deviceMode: mode),
        mode);
    await expectLater(
      StartupRecovery.checkBackup(
          path: backupPath, password: '000000', deviceMode: mode),
      throwsA(predicate((e) => '$e'.contains('Wrong password'))),
    );
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes));
    expect(RecoveryJournal.hasPending(docs), isFalse);
  });

  test('$mode: a damaged backup is rejected', () async {
    final bad = File(p.join(root.path, 'damaged_backup.zip'));
    final b = File(backupPath).readAsBytesSync();
    b[b.length ~/ 2] ^= 0xFF;
    bad.writeAsBytesSync(b);
    await expectLater(
      StartupRecovery.checkBackup(
          path: bad.path, password: password, deviceMode: mode),
      throwsA(anything),
    );
    final cut = File(p.join(root.path, 'cut_backup.zip'))
      ..writeAsBytesSync(File(backupPath).readAsBytesSync().sublist(0, 101));
    await expectLater(
      StartupRecovery.checkBackup(
          path: cut.path, password: password, deviceMode: mode),
      throwsA(predicate((e) => '$e'.contains('damaged or incomplete'))),
    );
  });

  test('$mode: a backup of the other business type is rejected', () async {
    final other = mode == 'retail' ? 'restaurant' : 'retail';
    await expectLater(
      StartupRecovery.checkBackup(
          path: backupPath, password: password, deviceMode: other),
      throwsA(isA<RecoveryRefused>().having(
          (e) => e.message, 'message', contains('this device is set up for'))),
    );
  });

  test('$mode: a backup missing a critical section is rejected', () async {
    final data =
        await UnifiedBackupService.readBackupFileForTesting(backupPath, password);
    (data['data'] as Map<String, dynamic>).remove(criticalSectionToDrop);
    final partial = p.join(root.path, 'partial_backup.zip');
    writeBackupFile(data, password, partial);
    await expectLater(
      StartupRecovery.checkBackup(
          path: partial, password: password, deviceMode: mode),
      throwsA(isA<RecoveryRefused>().having(
          (e) => e.message, 'message', contains(criticalSectionToDrop))),
    );
  });

  test('$mode: no restore while a box is merely in use', () async {
    var ran = false;
    final outcome = await StartupRecovery.restore(
      failures: [
        HiveBoxFailure(
            boxName: damagedBox,
            kind: HiveBoxFailureKind.inaccessible,
            error: 'lock failed'),
      ],
      runRestore: () async => ran = true,
    );
    expect(outcome.result, RecoveryRestoreResult.notStarted);
    expect(ran, isFalse);
    expect(RecoveryJournal.hasPending(docs), isFalse);
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes));
  });

  test('$mode: a failed restore rolls back, puts the damaged original back '
      'and keeps startup blocked', () async {
    final blocked = await StartupRecovery.retry();
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

    final outcome = await StartupRecovery.restore(
      failures: blocked!.failures,
      runRestore: () => realRestore(backupPath),
      prepareServices: prepareServicesForRecovery,
    );
    UnifiedBackupService.failWritingKeyForTesting = null;

    expect(outcome.result, RecoveryRestoreResult.failed);
    expect(outcome.error, isA<RestoreFailedException>()
        .having((e) => e.rolledBack, 'rolledBack', isTrue));
    expect(outcome.blocked!.failures.single.boxName, damagedBox,
        reason: 'no normal POS use after an unsuccessful restore');
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes),
        reason: 'the original damaged file is back, unchanged');
    expect(RecoveryJournal.hasPending(docs), isFalse);
    final names = filesUnder(preservedRoot()).map((f) => p.basename(f.path));
    expect(names.where((n) => n.contains('replaced-during-recovery')),
        hasLength(1), reason: 'the stand-in box is kept, not deleted');
    expect(names.where((n) => n.startsWith('recovery_reverted_')), hasLength(1));
    expectDeviceData();
  });

  test('$mode: a restore interrupted by the app closing puts the original '
      'back at the next start', () async {
    final blocked = await StartupRecovery.retry();
    await RecoveryJournal.moveAside(
        docs, blocked!.failures.map((f) => f.boxName).toList());
    expect(live.existsSync(), isFalse);
    expect(await StartupRecovery.retry(), isNull,
        reason: 'the empty stand-in opens: exactly what must not survive');

    // The process dies here (power cut, force close, or importFromFilePath
    // exiting after a failed write). Next start:
    await Hive.close();
    expect(await RecoveryJournal.resolvePendingAtStartup(docs), 1);
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes));
    final again = await StartupRecovery.retry();
    expect(again!.failures.single.boxName, damagedBox);
  });

  test('$mode: the encrypted export holds every preserved file and manifest',
      () async {
    await StartupRecovery.retry();
    final out = Directory(p.join(root.path, 'export_ok'))..createSync();
    final saved = await StartupRecovery.exportPreserved(
        password: password, targetDirectory: out.path);
    final bytes = File(saved).readAsBytesSync();
    expect(BackupEncryptionService.isEncryptedBlob(bytes), isTrue);
    expect(hashOf(bytes), isNot(contains(hashOf(damagedBytes))));

    final entries = StartupRecovery.readExport(bytes, password);
    final preserved = StartupRecovery.preservedFiles();
    expect(entries.length, preserved.length);
    for (final f in preserved) {
      final name = p.posix.joinAll(
          p.split(p.relative(f.path, from: preservedRoot().path)));
      expect(entries[name], f.readAsBytesSync(), reason: name);
    }
    expect(entries.keys.where((k) => k.endsWith('.manifest.json')), isNotEmpty);
    expect(entries.values.any((v) => hashOf(v) == hashOf(damagedBytes)), isTrue,
        reason: 'the damaged original itself is inside');
    expect(() => StartupRecovery.readExport(bytes, '135791'), throwsA(anything));
  });

  test('$mode: a failed export leaves the preserved files untouched',
      () async {
    await StartupRecovery.retry();
    final before = {
      for (final f in filesUnder(preservedRoot()))
        f.path: hashOf(f.readAsBytesSync())
    };
    final out = Directory(p.join(root.path, 'export_fail'))..createSync();
    StartupRecovery.afterExportWriteForTesting =
        (_) async => throw const FileSystemException('disk full');
    await expectLater(
      StartupRecovery.exportPreserved(
          password: password, targetDirectory: out.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(out.listSync(), isEmpty, reason: 'no partial export left behind');
    expect({
      for (final f in filesUnder(preservedRoot()))
        f.path: hashOf(f.readAsBytesSync())
    }, before);
  });

  test('$mode: a restore that reports failure (returns false, e.g. BKP-9 '
      'refused it) puts the original back and keeps startup blocked',
      () async {
    final blocked = await StartupRecovery.retry();
    final outcome = await StartupRecovery.restore(
      failures: blocked!.failures,
      runRestore: () async => false,
      prepareServices: prepareServicesForRecovery,
    );
    expect(outcome.result, RecoveryRestoreResult.failed);
    expect(outcome.blocked!.failures.single.boxName, damagedBox);
    expect(hashOf(live.readAsBytesSync()), hashOf(damagedBytes));
    expect(RecoveryJournal.hasPending(docs), isFalse);
  });

  test('$mode: an export that decrypts but does not match the preserved '
      'files is not kept', () async {
    await StartupRecovery.retry();
    final out = Directory(p.join(root.path, 'export_mismatch'))..createSync();
    StartupRecovery.afterExportWriteForTesting = (part) async {
      final one = utf8.encode('only one file');
      final zip = ZipEncoder(password: password)
          .encode(Archive()..addFile(ArchiveFile('x.txt', one.length, one)))!;
      part.writeAsBytesSync(BackupEncryptionService.encryptBytes(
          Uint8List.fromList(zip), password));
    };
    await expectLater(
      StartupRecovery.exportPreserved(
          password: password, targetDirectory: out.path),
      throwsA(predicate((e) => '$e'.contains('does not match'))),
    );
    expect(out.listSync(), isEmpty);
  });

  test('$mode: an export whose saved bytes do not verify is not kept',
      () async {
    await StartupRecovery.retry();
    final out = Directory(p.join(root.path, 'export_bad'))..createSync();
    StartupRecovery.afterExportWriteForTesting = (part) async {
      final b = part.readAsBytesSync();
      b[b.length - 20] ^= 0xFF;
      part.writeAsBytesSync(b);
    };
    await expectLater(
      StartupRecovery.exportPreserved(
          password: password, targetDirectory: out.path),
      throwsA(anything),
    );
    expect(out.listSync(), isEmpty);
  });

  // Last: it replaces this device's data with the backup.
  test('$mode: a successful restore uses the existing restore and unblocks '
      'startup; the damaged original stays preserved', () async {
    final blocked = await StartupRecovery.retry();
    final outcome = await StartupRecovery.restore(
      failures: blocked!.failures,
      runRestore: () => realRestore(backupPath),
      prepareServices: prepareServicesForRecovery,
    );
    expect(outcome.result, RecoveryRestoreResult.restored, reason: '${outcome.error}');
    expect(RecoveryJournal.hasPending(docs), isFalse);
    final files = filesUnder(preservedRoot());
    expect(files.map((f) => p.basename(f.path))
        .where((n) => n.startsWith('recovery_completed_')), hasLength(1));
    final moved = files.where((f) => f.path.endsWith('.moved-original'));
    expect(moved, hasLength(1));
    expect(hashOf(moved.single.readAsBytesSync()), hashOf(damagedBytes));
    expectBackupData();

    // The next start opens everything (normal startup may continue).
    await Hive.close();
    expect(await RecoveryJournal.resolvePendingAtStartup(docs), 0);
    expect(await StartupRecovery.retry(), isNull);
    expectBackupData();
  });
}
