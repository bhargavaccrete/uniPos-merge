import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/init/restore_record.dart';

/// BKP-5: the restore record round-trips exactly, an open record is never
/// replaced, closing keeps it, and an unreadable one still counts as open.
void main() {
  late Directory dir;

  RestoreRecord record(String snapshot) => RestoreRecord(
        snapshotPath: snapshot,
        snapshotSha256: 'abc',
        mode: 'retail',
        startedAt: DateTime(2026, 11, 16, 10, 5),
        source: RestoreSource.normal,
        pin: SnapshotPin.restoredBackupPin,
        journal: const [
          MapEntry('e1', {'qty': 2, 'price': 12.5, 'lines': ['a']}),
          MapEntry(7, null),
        ],
      );

  setUp(() => dir = Directory.systemTemp.createTempSync('restore_record_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('round-trips every field, journal keys and values included', () async {
    await RestoreRecordStore.write(dir.path, record('/s/one.zip'));
    final back = RestoreRecordStore.read(dir.path)!;
    expect(back.readable, isTrue);
    expect(back.toJson(), record('/s/one.zip').toJson());
    expect(back.journal.map((e) => e.key), ['e1', 7]);
  });

  test('an open record is never replaced', () async {
    await RestoreRecordStore.write(dir.path, record('/s/original.zip'));
    await expectLater(
      RestoreRecordStore.write(dir.path, record('/s/other.zip')),
      throwsA(isA<StateError>()),
    );
    expect(RestoreRecordStore.read(dir.path)!.snapshotPath, '/s/original.zip');
  });

  test('closing renames and keeps it; nothing is open afterwards', () async {
    await RestoreRecordStore.write(dir.path, record('/s/one.zip'));
    await RestoreRecordStore.close(dir.path, 'completed');
    expect(RestoreRecordStore.read(dir.path), isNull);
    final kept = Directory(p.join(dir.path, RestoreRecordStore.folderName))
        .listSync()
        .map((f) => p.basename(f.path));
    expect(kept.where((n) => n.startsWith('restore_completed_')), hasLength(1));
  });

  test('an unreadable record still blocks, without Undo', () {
    RestoreRecordStore.file(dir.path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{ not json');
    final r = RestoreRecordStore.read(dir.path)!;
    expect(r.readable, isFalse);
    expect(r.canUndo, isFalse);
  });

  test('a recovery-screen record never offers Undo', () {
    final r = RestoreRecord(
      snapshotPath: '/s/x.zip',
      snapshotSha256: 'abc',
      mode: 'restaurant',
      startedAt: DateTime(2026),
      source: RestoreSource.recovery,
      pin: SnapshotPin.deviceBackupPin,
      journal: const [],
    );
    expect(r.canUndo, isFalse);
  });
}
