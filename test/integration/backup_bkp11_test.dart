import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

class _FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDocuments(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

/// BKP-11: a backup is written to a temporary file, read back and opened the
/// way a restore does, and only then given its name, so a bad write is found
/// when it happens, not when the backup is needed. On import, a file whose
/// bytes show it is incomplete is called damaged, not a wrong password.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory out;
  const password = 'bkp11-pass';

  List<String> filesIn(Directory d) =>
      (d.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
        ..sort());

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_bkp11_');
    PathProviderPlatform.instance = _FakeDocuments(
        (Directory(p.join(tempDir.path, 'documents'))..createSync()).path);
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await BackupEncryptionService.setPassword(password);

    await Hive.box<Category>(HiveBoxNames.category)
        .put('cat-1', Category(id: 'cat-1', name: 'Starters'));
    // An item image travels as its own zip entry: the read-back checks it.
    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'i1',
        Items(
            id: 'i1',
            name: 'Soup',
            imageBytes: Uint8List.fromList(List.generate(300, (i) => i % 251))));
  });

  setUp(() {
    UnifiedBackupService.afterBackupWriteForTesting = null;
    UnifiedBackupService.beforeArchiveForTesting = null;
    out = Directory(p.join(tempDir.path, 'out_${DateTime.now().microsecondsSinceEpoch}'))
      ..createSync();
  });

  tearDownAll(() async {
    UnifiedBackupService.afterBackupWriteForTesting = null;
    UnifiedBackupService.beforeArchiveForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ==========================================================================
  group('writing a backup', () {
    test('a good backup is verified, named, and opens with its data', () async {
      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(path, isNotNull);
      expect(filesIn(out), [p.basename(path!)]);
      expect(path, endsWith('.zip'), reason: 'no temporary file is left');
      expect(UnifiedBackupService.lastExportError, isNull);

      final data = await UnifiedBackupService.readBackupFileForTesting(
          path, password);
      expect((data['data'] as Map)['categories'], hasLength(1));
    });

    test('a file cut short while saving: no backup kept, error reported',
        () async {
      UnifiedBackupService.afterBackupWriteForTesting = (f) async {
        final bytes = f.readAsBytesSync();
        f.writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2), flush: true);
      };

      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(path, isNull);
      expect(filesIn(out), isEmpty,
          reason: 'neither the backup name nor the temporary file remains');
      expect(UnifiedBackupService.lastExportError,
          allOf(startsWith('Backup not saved'), contains('bytes were saved'),
              contains('No backup file was kept')));
    });

    test('a file changed while saving (same length): no backup kept',
        () async {
      UnifiedBackupService.afterBackupWriteForTesting = (f) async {
        final bytes = f.readAsBytesSync();
        bytes[bytes.length - 5] ^= 0xFF;
        f.writeAsBytesSync(bytes, flush: true);
      };

      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(path, isNull);
      expect(filesIn(out), isEmpty);
      expect(UnifiedBackupService.lastExportError, contains('differs'));
    });

    test('a write that fails: no backup kept, error reported', () async {
      UnifiedBackupService.afterBackupWriteForTesting =
          (f) async => throw const FileSystemException('No space left on device');

      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(path, isNull);
      expect(filesIn(out), isEmpty);
      expect(UnifiedBackupService.lastExportError,
          allOf(startsWith('Backup not saved'), contains('No space left')));
    });

    test('temporary files of an interrupted earlier backup are removed; other '
        'files are left alone', () async {
      File(p.join(out.path, 'BillBerryLite_encrypted_2026-11-01T10-00-00.zip.part'))
          .writeAsBytesSync([1, 2, 3]);
      File(p.join(out.path, 'BillBerryLite_encrypted_2026-11-01T09-00-00.zip'))
          .writeAsBytesSync([4]);
      File(p.join(out.path, 'notes.zip.part')).writeAsBytesSync([5]);

      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(filesIn(out), [
        'BillBerryLite_encrypted_2026-11-01T09-00-00.zip',
        p.basename(path!),
        'notes.zip.part',
      ]..sort());
    });

    test('the restore safety snapshot is verified the same way', () async {
      UnifiedBackupService.afterBackupWriteForTesting = (f) async {
        final bytes = f.readAsBytesSync();
        f.writeAsBytesSync(bytes.sublist(0, bytes.length - 3), flush: true);
      };
      final snapshotDir =
          Directory(p.join(tempDir.path, 'documents', 'restore_snapshots'));
      if (snapshotDir.existsSync()) snapshotDir.deleteSync(recursive: true);

      final path = await UnifiedBackupService.takeSnapshotFileForTesting();

      expect(path, isNull, reason: 'an unverified copy is not offered');
      expect(
          snapshotDir.existsSync() ? filesIn(snapshotDir) : const <String>[],
          isEmpty);
    });
  });

  // ==========================================================================
  // K08 / K12: a file that is validly zipped and encrypted, so the byte
  // read-back and decryption both pass, but whose contents differ from what
  // was meant to be saved.
  group('a self-consistent file with the wrong contents', () {
    test('different data: caught by the decoded-data check', () async {
      var changed = false;
      UnifiedBackupService.beforeArchiveForTesting = (entries) {
        final data = entries.firstWhere((e) => e['name'] == 'data.json');
        data['bytes'] = utf8.encode(jsonEncode(BackupEncryptionService.encryptData(
            jsonEncode({'version': '2.0.0', 'data': <String, dynamic>{}}),
            password)));
        changed = true;
      };
      var readBackPassed = false;
      UnifiedBackupService.afterBackupWriteForTesting = (f) async {
        // The bytes on disk are exactly the bytes written, and they decrypt.
        readBackPassed = BackupEncryptionService.decryptBytes(
                f.readAsBytesSync(), password) !=
            null;
      };

      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(changed, isTrue);
      expect(readBackPassed, isTrue,
          reason: 'only the data comparison can see the difference');
      expect(path, isNull);
      expect(filesIn(out), isEmpty);
      expect(UnifiedBackupService.lastExportError,
          contains('its data does not match'));
    });

    test('a missing entry: caught by the entry-count check', () async {
      UnifiedBackupService.beforeArchiveForTesting = (entries) =>
          entries.removeWhere((e) => (e['name'] as String).startsWith('item_img_'));

      final path = await UnifiedBackupService.createBackupFileForTesting(out);

      expect(path, isNull);
      expect(filesIn(out), isEmpty);
      expect(UnifiedBackupService.lastExportError,
          contains('it holds 1 of 2 entries'));
    });
  });

  // ==========================================================================
  // 4e-1: the inner WinZip-AES layer authenticates each entry. A failure
  // there, with the right password, is reported as damage.
  group('inner integrity check (v1 format unchanged)', () {
    late Uint8List zip;

    /// [z] with one byte flipped inside data.json's encrypted contents (past
    /// the WinZip-AES salt and password check, before its MAC).
    Uint8List flipInsideDataJson(Uint8List z) {
      final name = utf8.encode('data.json');
      var at = -1;
      for (var i = 30; i < z.length - name.length && at < 0; i++) {
        var hit = true;
        for (var j = 0; j < name.length && hit; j++) {
          hit = z[i + j] == name[j];
        }
        if (hit) at = i;
      }
      final header = at - 30;
      final nameLen = z[header + 26] | (z[header + 27] << 8);
      final extraLen = z[header + 28] | (z[header + 29] << 8);
      final dataStart = header + 30 + nameLen + extraLen;
      final copy = Uint8List.fromList(z);
      copy[dataStart + 16 + 2 + 4] ^= 0xFF;
      return copy;
    }

    setUp(() async {
      final good = (await UnifiedBackupService.createBackupFileForTesting(out))!;
      zip = BackupEncryptionService.decryptBytes(
          File(good).readAsBytesSync(), password)!;
    });

    test('pin: archive reports a changed AES entry as "macs don\'t match"', () {
      final bad = flipInsideDataJson(zip);
      expect(
        () => ZipDecoder()
            .decodeBytes(bad, password: password)
            .firstWhere((f) => f.name == 'data.json')
            .content,
        throwsA(predicate((e) => '$e'.contains(archiveMacMismatchError))),
      );
    });

    test('pin: archive reports a wrong password as "password error", not a '
        'MAC mismatch', () {
      Object? error;
      try {
        ZipDecoder()
            .decodeBytes(zip, password: 'not-it')
            .firstWhere((f) => f.name == 'data.json')
            .content;
      } catch (e) {
        error = e;
      }
      expect('$error', contains('password error'));
      expect('$error', isNot(contains(archiveMacMismatchError)));
    });

    Future<Object?> importBytes(List<int> bytes, String pw) async {
      final f = File(p.join(out.path, 'tampered.zip'))..writeAsBytesSync(bytes);
      try {
        await UnifiedBackupService.readBackupFileForTesting(f.path, pw);
        return null;
      } catch (e) {
        return e;
      }
    }

    test('an encrypted backup with damaged contents says damaged, not '
        'wrong password', () async {
      final tampered = BackupEncryptionService.encryptBytes(
          flipInsideDataJson(zip), password);

      final e = await importBytes(tampered, password);

      expect('$e', contains(UnifiedBackupService.backupIntegrityFailedMessage));
      expect('$e', isNot(contains('Wrong password')));
    });

    test('an older plain-zip backup with damaged contents says damaged',
        () async {
      final e = await importBytes(flipInsideDataJson(zip), password);
      expect('$e', contains(UnifiedBackupService.backupIntegrityFailedMessage));
    });

    test('an older plain-zip backup with a wrong password still says wrong '
        'password', () async {
      final e = await importBytes(zip, 'not-it');
      expect('$e', contains(UnifiedBackupService.backupWrongPasswordMessage));
      expect('$e',
          isNot(contains(UnifiedBackupService.backupIntegrityFailedMessage)));
    });

    test('an undamaged backup still opens', () async {
      expect(
          await importBytes(BackupEncryptionService.encryptBytes(zip, password),
              password),
          isNull);
    });
  });

  // ==========================================================================
  group('opening a backup', () {
    late String good;
    late Uint8List goodBytes;

    setUp(() async {
      UnifiedBackupService.afterBackupWriteForTesting = null;
      good = (await UnifiedBackupService.createBackupFileForTesting(out))!;
      goodBytes = File(good).readAsBytesSync();
    });

    Future<Object?> open(List<int> bytes, String pw,
        {List<String>? asked}) async {
      final f = File(p.join(out.path, 'candidate.zip'))..writeAsBytesSync(bytes);
      try {
        await UnifiedBackupService.readBackupFileForTesting(f.path, pw,
            onPasswordAsked: () => asked?.add('asked'));
        return null;
      } catch (e) {
        return e;
      }
    }

    test('the right password opens a complete file', () async {
      expect(await open(goodBytes, password), isNull);
    });

    test('a wrong password on a complete file says wrong password or damaged',
        () async {
      final e = await open(goodBytes, 'not-it');
      expect(e.toString(), contains(UnifiedBackupService.backupWrongPasswordMessage));
    });

    for (final cut in [1, 7, 15, 17]) {
      test('a file missing its last $cut bytes is damaged, and no password is '
          'asked', () async {
        final asked = <String>[];
        final e = await open(
            goodBytes.sublist(0, goodBytes.length - cut), password,
            asked: asked);
        expect(e.toString(), contains(UnifiedBackupService.backupDamagedMessage));
        expect(e.toString(), isNot(contains('Wrong password')));
        expect(asked, isEmpty);
      });
    }

    test('a file cut inside its header is damaged', () async {
      for (final keep in [9, 12, 30]) {
        final e = await open(goodBytes.sublist(0, keep), password);
        expect(e.toString(), contains(UnifiedBackupService.backupDamagedMessage),
            reason: 'kept $keep bytes');
      }
    });

    test('a cut exactly on a 16-byte block cannot be told from a wrong '
        'password, and says both', () async {
      final e = await open(
          goodBytes.sublist(0, goodBytes.length - 16), password);
      expect(e.toString(), contains(UnifiedBackupService.backupWrongPasswordMessage));
      expect(e.toString(), contains('damaged'));
    });
  });

  // ==========================================================================
  group('BackupEncryptionService.isTruncatedBlob', () {
    final blob = BackupEncryptionService.encryptBytes(
        Uint8List.fromList(List.generate(100, (i) => i)), 'pw');

    test('a complete blob is not truncated', () {
      expect(BackupEncryptionService.isTruncatedBlob(blob), isFalse);
    });

    test('anything that is not an encrypted blob is not judged', () {
      expect(BackupEncryptionService.isTruncatedBlob([1, 2, 3]), isFalse);
      expect(BackupEncryptionService.isTruncatedBlob(const []), isFalse);
    });

    test('every cut that is not a whole number of blocks is truncated', () {
      for (var len = 8; len < blob.length; len++) {
        final headerEnd = 8 + 1 + blob[8] + 1 + blob[8 + 1 + blob[8]];
        final cipher = len - headerEnd;
        final expected = cipher <= 0 || cipher % 16 != 0;
        expect(BackupEncryptionService.isTruncatedBlob(blob.sublist(0, len)),
            expected, reason: 'length $len');
      }
    });
  });
}
