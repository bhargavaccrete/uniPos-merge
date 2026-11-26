import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'hive_preservation.dart';

/// One damaged box file moved out of the way so a restore can run.
class MovedOriginal {
  final String boxName;
  final String livePath;
  final String movedPath;
  final String sha256;
  const MovedOriginal(this.boxName, this.livePath, this.movedPath, this.sha256);

  Map<String, Object> toJson() => {
        'box': boxName,
        'livePath': livePath,
        'movedPath': movedPath,
        'sha256': sha256,
      };

  static MovedOriginal fromJson(Map<String, dynamic> m) => MovedOriginal(
      m['box'] as String,
      m['livePath'] as String,
      m['movedPath'] as String,
      m['sha256'] as String);
}

/// M4 startup recovery: moves damaged originals aside for a restore and can
/// always put them back.
///
/// A restore needs every box open, so a damaged box's file is moved (renamed,
/// bytes untouched) into this run's preservation folder and an empty box
/// opens in its place. The move is written to `damaged/recovery_pending.json`
/// BEFORE any file moves. Until the restore succeeds and the marker is closed
/// as completed, the next app start puts every original back first
/// ([resolvePendingAtStartup]) — so a failed restore, or a crash or forced
/// close in the middle of one, never leaves an empty box that would let the
/// till sell against missing data. Nothing is ever deleted: a file that took
/// an original's place is moved aside as well.
class RecoveryJournal {
  RecoveryJournal._();

  static const String markerName = 'recovery_pending.json';

  static File _marker(String hiveDir) =>
      File(p.join(hiveDir, HivePreservation.folderName, markerName));

  static bool hasPending(String hiveDir) => _marker(hiveDir).existsSync();

  static List<MovedOriginal> pending(String hiveDir) {
    final f = _marker(hiveDir);
    if (!f.existsSync()) return const [];
    final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
    return list
        .map((e) => MovedOriginal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Moves the live file of each of [boxNames] aside. Records every move
  /// before making it; verifies each moved file still has the original's
  /// SHA-256. Throws (after putting back what moved) on any failure.
  static Future<List<MovedOriginal>> moveAside(
      String hiveDir, List<String> boxNames) async {
    final folder = await HivePreservation.sessionFolder(hiveDir);
    final already = pending(hiveDir);
    final plan = <MovedOriginal>[];
    for (final box in boxNames) {
      final lower = box.toLowerCase();
      final live = File(p.join(hiveDir, '$lower.hive'));
      if (!live.existsSync()) continue;
      if (already.any((m) => p.equals(m.livePath, live.path) &&
          File(m.movedPath).existsSync())) {
        continue;
      }
      final hash = sha256.convert(await live.readAsBytes()).toString();
      final moved = HivePreservation.unusedFile(
          folder, '$lower.hive.moved-original');
      plan.add(MovedOriginal(box, live.path, moved.path, hash));
    }
    if (plan.isEmpty) return const [];
    await _writeMarker(hiveDir, [...already, ...plan]);

    try {
      for (final m in plan) {
        await File(m.livePath).rename(m.movedPath);
        final now = sha256.convert(await File(m.movedPath).readAsBytes());
        if (now.toString() != m.sha256) {
          throw StateError('${m.boxName} changed while it was moved aside');
        }
        debugPrint('🛟 ${m.boxName}: original moved aside → ${m.movedPath}');
      }
    } catch (_) {
      await revert(hiveDir);
      rethrow;
    }
    return plan;
  }

  /// Puts every moved original back in place. Every Hive box must be closed.
  /// A file that took an original's place (the empty or partly restored box)
  /// is moved aside next to it, never deleted. Closes the marker as reverted.
  static Future<int> revert(String hiveDir) async {
    var restored = 0;
    for (final m in pending(hiveDir)) {
      final moved = File(m.movedPath);
      if (!moved.existsSync()) continue;
      final live = File(m.livePath);
      if (live.existsSync()) {
        final aside = HivePreservation.unusedFile(
            moved.parent, '${p.basename(m.livePath)}.replaced-during-recovery');
        await live.rename(aside.path);
      }
      await moved.rename(m.livePath);
      restored++;
      debugPrint('🛟 ${m.boxName}: original put back');
    }
    await _closeMarker(hiveDir, 'reverted');
    return restored;
  }

  /// The restore succeeded: the moved originals stay in the preservation
  /// folder and are never put back.
  static Future<void> complete(String hiveDir) =>
      _closeMarker(hiveDir, 'completed');

  /// Called at app start, before any box opens. Returns how many originals
  /// were put back (a recovery restore that did not finish).
  static Future<int> resolvePendingAtStartup(String hiveDir) async {
    if (!hasPending(hiveDir)) return 0;
    debugPrint('🛟 A recovery restore did not finish: putting the damaged '
        'originals back so the till cannot run on empty data');
    return revert(hiveDir);
  }

  static Future<void> _writeMarker(
      String hiveDir, List<MovedOriginal> entries) async {
    final marker = _marker(hiveDir);
    await marker.parent.create(recursive: true);
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ')
        .convert(entries.map((e) => e.toJson()).toList()));
    final temp = File('${marker.path}.copying');
    final raf = await temp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    if (!listEquals(await temp.readAsBytes(), bytes)) {
      throw StateError('the recovery record could not be written');
    }
    await temp.rename(marker.path);
  }

  static Future<void> _closeMarker(String hiveDir, String status) async {
    final marker = _marker(hiveDir);
    if (!marker.existsSync()) return;
    final t = DateTime.now().toIso8601String().replaceAll(':', '-');
    final closed = HivePreservation.unusedFile(
        marker.parent, 'recovery_${status}_$t.json');
    await marker.rename(closed.path);
  }
}
