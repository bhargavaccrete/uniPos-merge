import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Where a restore was started.
enum RestoreSource {
  /// Settings or onboarding: the snapshot holds this device's real data.
  normal,

  /// The M4 Recovery screen: the snapshot was taken after damaged boxes were
  /// replaced by empty stand-ins, so it must never be put back.
  recovery,
}

/// Which PIN locks the snapshot file.
enum SnapshotPin {
  /// This device's backup PIN as it was when the restore started.
  deviceBackupPin,

  /// No device PIN was stored: the PIN of the backup being restored.
  restoredBackupPin,
}

/// Test aid: stands for the process dying at a precise point of a restore.
/// The restore lets it through without rolling back, as a killed app would.
/// Thrown only by the `kill…ForTesting` hooks (always null in production).
class SimulatedProcessKill implements Exception {
  final String where;
  SimulatedProcessKill(this.where);
  @override
  String toString() => 'SimulatedProcessKill($where)';
}

/// BKP-5: `restore_snapshots/restore_in_progress.json`, written and verified
/// before a restore's first business-data write, closed (renamed, kept) only
/// after the restore succeeded or its rollback was verified. While it is
/// open, normal startup is blocked: the data may be partly restored.
class RestoreRecord {
  final String snapshotPath;
  final String snapshotSha256;
  final String mode;
  final DateTime startedAt;
  final RestoreSource source;
  final SnapshotPin pin;

  /// The pending-work journal as it was before the restore: key → entry.
  final List<MapEntry<Object, Object?>> journal;

  /// False when the record file exists but cannot be read. Startup is still
  /// blocked; Undo is not offered.
  final bool readable;

  const RestoreRecord({
    required this.snapshotPath,
    required this.snapshotSha256,
    required this.mode,
    required this.startedAt,
    required this.source,
    required this.pin,
    required this.journal,
    this.readable = true,
  });

  RestoreRecord.unreadable()
      : snapshotPath = '',
        snapshotSha256 = '',
        mode = 'unknown',
        startedAt = DateTime.fromMillisecondsSinceEpoch(0),
        source = RestoreSource.recovery,
        pin = SnapshotPin.deviceBackupPin,
        journal = const [],
        readable = false;

  /// Undo puts the snapshot back: only for a readable record of a normal
  /// restore (a Recovery-screen snapshot holds empty stand-in boxes).
  bool get canUndo => readable && source == RestoreSource.normal;

  Map<String, Object?> toJson() => {
        'v': 1,
        'snapshotPath': snapshotPath,
        'snapshotSha256': snapshotSha256,
        'mode': mode,
        'startedAt': startedAt.toIso8601String(),
        'source': source.name,
        'pin': pin.name,
        'journal': [
          for (final e in journal) {'key': e.key, 'value': e.value},
        ],
      };

  static RestoreRecord fromJson(Map<String, dynamic> m) => RestoreRecord(
        snapshotPath: m['snapshotPath'] as String,
        snapshotSha256: m['snapshotSha256'] as String,
        mode: m['mode'] as String,
        startedAt: DateTime.parse(m['startedAt'] as String),
        source: RestoreSource.values.byName(m['source'] as String),
        pin: SnapshotPin.values.byName(m['pin'] as String),
        journal: [
          for (final e in m['journal'] as List)
            MapEntry((e as Map)['key'] as Object, e['value']),
        ],
      );
}

class RestoreRecordStore {
  RestoreRecordStore._();

  static const String folderName = 'restore_snapshots';
  static const String fileName = 'restore_in_progress.json';

  static File file(String documentsDir) =>
      File(p.join(documentsDir, folderName, fileName));

  /// The open record, or null. A record that cannot be read still counts as
  /// open ([RestoreRecord.readable] false).
  static RestoreRecord? read(String documentsDir) {
    final f = file(documentsDir);
    if (!f.existsSync()) return null;
    try {
      return RestoreRecord.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('⚠️ Restore record unreadable: $e');
      return RestoreRecord.unreadable();
    }
  }

  /// Writes [record] and checks it reads back identically (journal included)
  /// before it counts. Never replaces an open record.
  static Future<void> write(String documentsDir, RestoreRecord record) async {
    final target = file(documentsDir);
    if (target.existsSync()) {
      throw StateError('a restore record is already open');
    }
    await target.parent.create(recursive: true);
    final text = const JsonEncoder.withIndent('  ').convert(record.toJson());
    final temp = File('${target.path}.copying');
    final raf = await temp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(utf8.encode(text));
      await raf.flush();
    } finally {
      await raf.close();
    }
    final back = jsonDecode(await temp.readAsString()) as Map<String, dynamic>;
    if (jsonEncode(back) != jsonEncode(jsonDecode(text))) {
      throw StateError('the restore record did not read back correctly');
    }
    await temp.rename(target.path);
  }

  /// Closes the open record: renamed to `restore_<status>_<time>.json` and
  /// kept. No-op when none is open.
  static Future<void> close(String documentsDir, String status) async {
    final f = file(documentsDir);
    if (!f.existsSync()) return;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    var closed = File(p.join(f.parent.path, 'restore_${status}_$stamp.json'));
    for (var i = 1; closed.existsSync(); i++) {
      closed = File(p.join(f.parent.path, 'restore_${status}_$stamp-$i.json'));
    }
    await f.rename(closed.path);
  }

  /// The snapshot file is still there with the SHA-256 the record holds.
  static bool snapshotIntact(RestoreRecord record) {
    if (!record.readable) return false;
    final f = File(record.snapshotPath);
    return f.existsSync() &&
        sha256.convert(f.readAsBytesSync()).toString() == record.snapshotSha256;
  }
}
