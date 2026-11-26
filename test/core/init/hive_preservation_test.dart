import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/init/hive_file_inspector.dart';
import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';

/// M4-PERSIST: a damaged box is preserved (verified copy) before anything
/// may repair it; only a confirmed unfinished last write is repaired; every
/// other failure leaves the original byte-for-byte unchanged and the box
/// closed.
class _Thing {
  final String v;
  _Thing(this.v);
}

class _ThingAdapter extends TypeAdapter<_Thing> {
  @override
  final int typeId = 99;
  @override
  _Thing read(BinaryReader r) => _Thing(r.readString());
  @override
  void write(BinaryWriter w, _Thing t) => w.writeString(t.v);
}

class _BrokenThingAdapter extends TypeAdapter<_Thing> {
  @override
  final int typeId = 99;
  @override
  _Thing read(BinaryReader r) => throw StateError('adapter read failed');
  @override
  void write(BinaryWriter w, _Thing t) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  String hashOf(File f) => sha256.convert(f.readAsBytesSync()).toString();
  File hiveFile(String box) => File(p.join(dir.path, '$box.hive'));
  Directory damagedRoot() => Directory(p.join(dir.path, HivePreservation.folderName));
  List<File> preservedFiles() => damagedRoot().existsSync()
      ? damagedRoot()
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.hive') || f.path.endsWith('.hivec'))
          .toList()
      : <File>[];
  Map<String, dynamic> manifestFor(PreservedFile f) =>
      jsonDecode(File(f.manifestPath).readAsStringSync()) as Map<String, dynamic>;

  /// Record start offsets of a healthy Hive file.
  List<int> recordOffsets(Uint8List b) {
    final data = ByteData.sublistView(b);
    final out = <int>[];
    var o = 0;
    while (o < b.length) {
      out.add(o);
      o += data.getUint32(o, Endian.little);
    }
    return out;
  }

  Future<File> makeBox(String name, int records) async {
    final box = await Hive.openBox(name);
    for (var i = 0; i < records; i++) {
      await box.put('k$i', 'value-$i-${'x' * 24}');
    }
    await box.close();
    return hiveFile(name);
  }

  /// Flips one byte inside record [index] (in its value, not its header).
  void damageRecord(File f, int index) {
    final b = f.readAsBytesSync();
    final offsets = recordOffsets(b);
    b[offsets[index] + 12] ^= 0xFF;
    f.writeAsBytesSync(b);
  }

  /// Cuts the last record short, as a write interrupted by a power cut.
  void tearLastRecord(File f) {
    final b = f.readAsBytesSync();
    f.writeAsBytesSync(b.sublist(0, b.length - 9));
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_preserve_');
    Hive.init(dir.path);
    HiveSafeOpen.resetForTesting();
    HiveSafeOpen.hiveDirectory = dir.path;
    HiveSafeOpen.accessAttempts = 2;
    HiveSafeOpen.accessRetryDelay = const Duration(milliseconds: 10);
    HivePreservation.resetForTesting();
    HivePreservation.appVersionLookup = () async => '9.9.9+1';
  });

  tearDown(() async {
    await Hive.close();
    Hive.resetAdapters();
    // A failed open closes its files without waiting; retry until released.
    for (var i = 0; dir.existsSync(); i++) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        if (i > 50) rethrow;
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  group('HiveFileInspector (read-only scan)', () {
    test('intact file', () async {
      final f = await makeBox('clean', 5);
      final s = HiveFileInspector.scan(f.readAsBytesSync());
      expect(s.kind, HiveDamageKind.none);
      expect(s.damageOffset, isNull);
      expect(s.validRecordsBefore, 5);
    });

    test('record cut short at the end → torn final record', () async {
      final f = await makeBox('torn', 5);
      final last = recordOffsets(f.readAsBytesSync()).last;
      tearLastRecord(f);
      final s = HiveFileInspector.scan(f.readAsBytesSync());
      expect(s.kind, HiveDamageKind.tornFinalRecord);
      expect(s.damageOffset, last);
      expect([s.validRecordsBefore, s.validRecordsAfter], [4, 0]);
    });

    test('only part of the length header written → torn', () async {
      final f = await makeBox('hdr', 3);
      final b = f.readAsBytesSync();
      f.writeAsBytesSync([...b, 0x21, 0x00]);
      expect(HiveFileInspector.scan(f.readAsBytesSync()).kind,
          HiveDamageKind.tornFinalRecord);
    });

    test('zero-filled tail (data never reached the disk) → torn', () async {
      final f = await makeBox('zero', 3);
      final b = f.readAsBytesSync();
      f.writeAsBytesSync([...b, ...List.filled(64, 0)]);
      final s = HiveFileInspector.scan(f.readAsBytesSync());
      expect(s.kind, HiveDamageKind.tornFinalRecord);
      expect(s.validRecordsBefore, 3);
    });

    test('whole last record with a bad checksum → bad final record',
        () async {
      final f = await makeBox('badlast', 5);
      damageRecord(f, 4);
      final s = HiveFileInspector.scan(f.readAsBytesSync());
      expect(s.kind, HiveDamageKind.badFinalRecord);
      expect([s.validRecordsBefore, s.validRecordsAfter], [4, 0]);
    });

    test('damage in the middle with whole records after it', () async {
      final f = await makeBox('mid', 10);
      final offsets = recordOffsets(f.readAsBytesSync());
      damageRecord(f, 3);
      final s = HiveFileInspector.scan(f.readAsBytesSync());
      expect(s.kind, HiveDamageKind.middleCorruption);
      expect(s.damageOffset, offsets[3]);
      expect([s.validRecordsBefore, s.validRecordsAfter], [3, 6]);
      expect(s.scanComplete, isTrue);
    });

    test('a damaged LENGTH field in the middle is not mistaken for a torn '
        'write', () async {
      final f = await makeBox('len', 8);
      final b = f.readAsBytesSync();
      final o = recordOffsets(b)[2];
      ByteData.sublistView(b).setUint32(o, 0x7FFFFFFF, Endian.little);
      f.writeAsBytesSync(b);
      final s = HiveFileInspector.scan(f.readAsBytesSync());
      expect(s.kind, HiveDamageKind.middleCorruption);
      expect(s.validRecordsAfter, greaterThan(0));
    });

    test('CRC-32 matches the standard check value', () {
      expect(HiveFileInspector.crc32(
              Uint8List.fromList(utf8.encode('123456789')), 0, 9),
          0xCBF43926);
    });
  });

  group('Hive 2.2.3 contract (pinned)', () {
    test('crashRecovery:false throws "Wrong checksum" and leaves the file '
        'byte-identical; crashRecovery:true truncates it', () async {
      final f = await makeBox('pin', 10);
      damageRecord(f, 3);
      final before = hashOf(f);
      final size = f.lengthSync();
      Object? error;
      final strays = <Object>[];
      await runZonedGuarded(() async {
        try {
          await Hive.openBox('pin', crashRecovery: false);
        } catch (e) {
          error = e;
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }, (e, _) => strays.add(e));
      expect(error, isA<HiveError>());
      expect((error as HiveError).message, contains('Wrong checksum'));
      expect(hashOf(f), before);
      // Hive also fails its internal "opening" future, unawaited: the same
      // error reaches the zone as uncaught. HiveSafeOpen._guarded drops it.
      expect(strays.where((e) => identical(e, error)), hasLength(1));
      await Future.delayed(const Duration(milliseconds: 100));
      final box = await Hive.openBox('pin');
      expect(box.length, 3);
      expect(f.lengthSync(), lessThan(size), reason: 'why preservation is needed');
    });
  });

  group('HiveSafeOpen', () {
    test('1. a healthy box opens normally and nothing is copied', () async {
      await makeBox('healthy', 5);
      final box = await HiveSafeOpen.openBox('healthy');
      expect(box, isNotNull);
      expect(box!.length, 5);
      expect(HiveSafeOpen.failures, isEmpty);
      expect(HiveSafeOpen.repairs, isEmpty);
      expect(damagedRoot().existsSync(), isFalse);
      expect(HiveSafeOpen.throwIfBlocked, returnsNormally);
    });

    test('2. torn final write: the original is preserved BEFORE Hive repairs',
        () async {
      final f = await makeBox('torn', 10);
      final cut = recordOffsets(f.readAsBytesSync()).last;
      tearLastRecord(f);
      final originalHash = hashOf(f);
      final originalSize = f.lengthSync();

      final box = await HiveSafeOpen.openBox('torn');
      expect(box, isNotNull);
      expect(box!.length, 9, reason: 'only the unfinished write was dropped');
      expect(HiveSafeOpen.failures, isEmpty);
      final repair = HiveSafeOpen.repairs.single;
      expect(repair.preserved.sha256, originalHash);
      expect(hashOf(File(repair.preserved.path)), originalHash);
      expect(repair.preserved.size, originalSize);
      expect(f.lengthSync(), cut, reason: 'Hive cut exactly at the torn write');
      final m = manifestFor(repair.preserved);
      expect(m['box'], 'torn');
      expect(m['damageKind'], 'tornFinalRecord');
      expect(m['originalSize'], originalSize);
      expect(m['sha256'], originalHash);
      expect(m['corruptionOffset'], cut);
      expect([m['validRecordsBefore'], m['validRecordsAfter']], [9, 0]);
      expect(m['appVersion'], '9.9.9+1');
      expect(m['preservedAt'], isNotNull);
    });

    test('3. middle corruption: preserved, NOT repaired, box closed, start '
        'blocked', () async {
      final f = await makeBox('orders', 10);
      damageRecord(f, 3);
      final originalHash = hashOf(f);

      final box = await HiveSafeOpen.openBox('orders');
      expect(box, isNull);
      expect(Hive.isBoxOpen('orders'), isFalse);
      expect(hashOf(f), originalHash, reason: 'original left byte-identical');
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.corrupted);
      expect(failure.scan!.kind, HiveDamageKind.middleCorruption);
      expect(hashOf(File(failure.preserved!.path)), originalHash);
      final m = manifestFor(failure.preserved!);
      expect(m['validRecordsAfter'], 6);
      expect(m['validRecordsBefore'], 3);
      expect(m['corruptionOffset'], isA<int>());

      expect(
        HiveSafeOpen.throwIfBlocked,
        throwsA(isA<HiveStartupBlocked>().having(
            (e) => e.message,
            'message',
            allOf(contains('orders'), contains('NOT repaired'),
                contains(failure.preserved!.path),
                contains('6 saved record(s)')))),
      );
    });

    test('4. a whole last record with a bad CRC is not repaired', () async {
      final f = await makeBox('lastbad', 6);
      damageRecord(f, 5);
      final originalHash = hashOf(f);

      expect(await HiveSafeOpen.openBox('lastbad'), isNull);
      expect(hashOf(f), originalHash);
      expect(f.lengthSync(), greaterThan(0));
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.corrupted);
      expect(failure.scan!.kind, HiveDamageKind.badFinalRecord);
      expect(HiveSafeOpen.repairs, isEmpty);
      expect(hashOf(File(failure.preserved!.path)), originalHash);
    });

    test('5. unknown typeId: preserved, unchanged, box closed', () async {
      Hive.registerAdapter(_ThingAdapter());
      final box = await Hive.openBox('typed');
      await box.put('a', _Thing('one'));
      await box.close();
      await Hive.close();
      Hive.resetAdapters();
      Hive.init(dir.path);
      final f = hiveFile('typed');
      final originalHash = hashOf(f);

      expect(await HiveSafeOpen.openBox('typed'), isNull);
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.unreadable);
      expect(failure.error, contains('unknown typeId'));
      expect(hashOf(f), originalHash);
      expect(hashOf(File(failure.preserved!.path)), originalHash);
      expect(manifestFor(failure.preserved!)['reason'], 'unreadable');
    });

    test('6. adapter error: preserved, unchanged, box closed', () async {
      Hive.registerAdapter(_ThingAdapter());
      final box = await Hive.openBox('adapter');
      await box.put('a', _Thing('one'));
      await box.close();
      await Hive.close();
      Hive.resetAdapters();
      Hive.init(dir.path);
      Hive.registerAdapter(_BrokenThingAdapter());
      final f = hiveFile('adapter');
      final originalHash = hashOf(f);

      expect(await HiveSafeOpen.openBox('adapter'), isNull);
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.unreadable);
      expect(failure.error, contains('adapter read failed'));
      expect(hashOf(f), originalHash);
      expect(hashOf(File(failure.preserved!.path)), originalHash);
    });

    test('7. a lock error is not treated as corruption', () async {
      final f = await makeBox('locked', 3);
      final originalHash = hashOf(f);
      final holder = await File(p.join(dir.path, 'locked.lock'))
          .open(mode: FileMode.append);
      await holder.lock(FileLock.exclusive);
      try {
        expect(await HiveSafeOpen.openBox('locked'), isNull);
      } finally {
        await holder.unlock();
        await holder.close();
      }
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.inaccessible);
      expect(failure.preserved, isNull);
      expect(damagedRoot().existsSync(), isFalse, reason: 'nothing copied');
      expect(hashOf(f), originalHash);
      expect(failure.describe(), contains('This is not damage'));
      expect(HiveStartupBlocked(HiveSafeOpen.failures).message,
          isNot(contains('Contact support')));

      // Retry once the other holder is gone: opens normally.
      HiveSafeOpen.failures.clear();
      await Future.delayed(const Duration(milliseconds: 50));
      final box = await HiveSafeOpen.openBox('locked');
      expect(box!.length, 3);
    }, skip: Platform.isWindows ? false : 'same-process lock conflict is Windows-only');

    test('8. copy failure: no repair, original untouched, box closed',
        () async {
      final f = await makeBox('tornfail', 6);
      tearLastRecord(f);
      final originalHash = hashOf(f);
      HivePreservation.afterCopyWriteForTesting =
          (_) async => throw const FileSystemException('disk full');

      expect(await HiveSafeOpen.openBox('tornfail'), isNull);
      expect(hashOf(f), originalHash, reason: 'Hive was not allowed to repair');
      expect(HiveSafeOpen.repairs, isEmpty);
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.preservationFailed);
      expect(failure.preservationError, contains('disk full'));
      expect(failure.describe(), contains('NOT repaired'));
      expect(preservedFiles(), isEmpty);
    });

    test('9. SHA-256 mismatch of the copy: no repair, original untouched',
        () async {
      final f = await makeBox('tornsha', 6);
      tearLastRecord(f);
      final originalHash = hashOf(f);
      HivePreservation.afterCopyWriteForTesting = (copy) async {
        final b = copy.readAsBytesSync();
        b[0] ^= 0x01;
        copy.writeAsBytesSync(b);
      };

      expect(await HiveSafeOpen.openBox('tornsha'), isNull);
      expect(hashOf(f), originalHash);
      expect(HiveSafeOpen.repairs, isEmpty);
      final failure = HiveSafeOpen.failures.single;
      expect(failure.kind, HiveBoxFailureKind.preservationFailed);
      expect(failure.preservationError, contains('SHA-256'));
      expect(preservedFiles(), isEmpty, reason: 'an unverified copy never '
          'gets a final name');
    });

    test('9b. an original that changes while being copied is not accepted',
        () async {
      final f = await makeBox('moving', 4);
      HivePreservation.afterCopyWriteForTesting = (_) async {
        f.writeAsBytesSync([...f.readAsBytesSync(), 1, 2, 3]);
      };
      await expectLater(
        HivePreservation.preserve(
            source: f, hiveDirectory: dir.path, boxName: 'moving', reason: 't'),
        throwsA(isA<PreservationException>().having(
            (e) => e.message, 'message', contains('changed while'))),
      );
      expect(preservedFiles(), isEmpty);
    });

    test('10. existing preserved copies are never overwritten', () async {
      final f = await makeBox('dup', 4);
      final first = await HivePreservation.preserve(
          source: f, hiveDirectory: dir.path, boxName: 'dup', reason: 'test');
      final firstHash = hashOf(File(first.path));
      final firstManifest = File(first.manifestPath).readAsStringSync();

      // Same run, same box, different content.
      final b = await Hive.openBox('dup');
      await b.put('more', 'data');
      await b.close();
      final second = await HivePreservation.preserve(
          source: f, hiveDirectory: dir.path, boxName: 'dup', reason: 'test');
      expect(second.path, isNot(first.path));
      expect(second.manifestPath, isNot(first.manifestPath));
      expect(hashOf(File(first.path)), firstHash);
      expect(File(first.manifestPath).readAsStringSync(), firstManifest);

      // A new run whose timestamp folder already exists.
      final fixed = DateTime(2026, 11, 16, 10, 0, 0, 5);
      HivePreservation.resetForTesting();
      HivePreservation.now = () => fixed;
      final third = await HivePreservation.preserve(
          source: f, hiveDirectory: dir.path, boxName: 'dup', reason: 'test');
      HivePreservation.resetForTesting();
      HivePreservation.now = () => fixed;
      final fourth = await HivePreservation.preserve(
          source: f, hiveDirectory: dir.path, boxName: 'dup', reason: 'test');
      expect(p.dirname(fourth.path), isNot(p.dirname(third.path)));
      expect(hashOf(File(third.path)), hashOf(File(fourth.path)));
      expect(File(third.path).existsSync(), isTrue);
      expect(hashOf(File(first.path)), firstHash);
    });

    test('13. a .hivec leftover is preserved before Hive deletes it',
        () async {
      final f = await makeBox('compact', 5);
      final leftover = File(p.join(dir.path, 'compact.hivec'));
      leftover.writeAsBytesSync([...f.readAsBytesSync().sublist(0, 40), 7, 7]);
      final leftoverHash = hashOf(leftover);

      final box = await HiveSafeOpen.openBox('compact');
      expect(box!.length, 5);
      expect(leftover.existsSync(), isFalse,
          reason: 'Hive 2.2.3 deletes a .hivec when the .hive exists');
      final kept = preservedFiles().where((x) => x.path.endsWith('.hivec'));
      expect(kept, hasLength(1));
      expect(hashOf(kept.single), leftoverHash);
    });

    test('13b. if the .hivec cannot be preserved, Hive is never run on it',
        () async {
      final f = await makeBox('compact2', 5);
      final leftover = File(p.join(dir.path, 'compact2.hivec'));
      leftover.writeAsBytesSync(f.readAsBytesSync());
      HivePreservation.afterCopyWriteForTesting =
          (_) async => throw const FileSystemException('no space');

      expect(await HiveSafeOpen.openBox('compact2'), isNull);
      expect(leftover.existsSync(), isTrue);
      expect(HiveSafeOpen.failures.single.kind,
          HiveBoxFailureKind.preservationFailed);
    });

    test('unknown data folder: nothing can be preserved, so nothing is '
        'repaired', () async {
      final f = await makeBox('nodir', 6);
      tearLastRecord(f);
      final originalHash = hashOf(f);
      HiveSafeOpen.hiveDirectory = null;
      expect(await HiveSafeOpen.openBox('nodir'), isNull);
      expect(hashOf(f), originalHash);
      expect(HiveSafeOpen.failures.single.kind,
          HiveBoxFailureKind.preservationFailed);
    });
  });
}
