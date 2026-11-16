import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// BKP-6 retention for AUTOMATIC backups only.
///
/// Automatic backups are named `BillBerryLite_auto_<yyyy-MM-ddTHH-mm-ss>.zip`
/// (optionally `-<n>` when two land in the same second). A file that does not
/// match that pattern exactly — every manual backup, anything renamed, any
/// other file — is never touched.
///
/// Kept, all others pruned:
/// * the newest automatic backup of each of the 14 most recent days that
///   have one ("daily");
/// * the newest automatic backup of each of the 8 most recent weeks
///   (Monday-based) OLDER than those days ("weekly" recovery points, so a
///   backup taken before a silent problem survives for about 10 weeks);
/// * the newest verified backup and any path in `protected`, always.
///
/// Pruning runs only after a new automatic backup was written AND verified.
class AutoBackupRetention {
  AutoBackupRetention._();

  static const int dailyToKeep = 14;
  static const int weeklyToKeep = 8;
  static const String prefix = 'BillBerryLite_auto_';

  static final RegExp _name = RegExp(
      r'^BillBerryLite_auto_(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})(?:-(\d+))?\.zip$');

  /// The time in an automatic backup's name, or null when [fileName] is not
  /// exactly an automatic backup's name.
  static DateTime? stampOf(String fileName) {
    final m = _name.firstMatch(fileName);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    try {
      final t = DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
      // Rejects impossible dates DateTime would silently roll over.
      if (t.year != g(1) || t.month != g(2) || t.day != g(3)) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  /// The `-n` a second file written in the same second gets (0 when none).
  static int _sameSecondIndex(String fileName) =>
      int.tryParse(_name.firstMatch(fileName)?.group(7) ?? '') ?? 0;

  /// Pure policy: of [fileNames], the automatic backups to delete.
  static Set<String> toDelete(List<String> fileNames,
      {Set<String> keep = const {}}) {
    final autos = <String, DateTime>{};
    for (final n in fileNames) {
      final t = stampOf(n);
      if (t != null) autos[n] = t;
    }
    // Newest first; within one second the higher `-n` was written later.
    final ordered = autos.keys.toList()
      ..sort((a, b) {
        final c = autos[b]!.compareTo(autos[a]!);
        return c != 0 ? c : _sameSecondIndex(b).compareTo(_sameSecondIndex(a));
      });

    final kept = <String>{...keep.where(autos.containsKey)};
    final days = <DateTime>{};
    DateTime? oldestKeptDay;
    for (final n in ordered) {
      final d = _day(autos[n]!);
      if (days.contains(d)) continue;
      if (days.length >= dailyToKeep) break;
      days.add(d);
      kept.add(n);
      oldestKeptDay = d;
    }

    final weeks = <DateTime>{};
    for (final n in ordered) {
      final d = _day(autos[n]!);
      if (oldestKeptDay != null && !d.isBefore(oldestKeptDay)) continue;
      final w = _monday(d);
      if (weeks.contains(w)) continue;
      if (weeks.length >= weeklyToKeep) break;
      weeks.add(w);
      kept.add(n);
    }
    return autos.keys.toSet().difference(kept);
  }

  /// Deletes the automatic backups in [dir] the policy no longer keeps.
  /// [newest] (the backup just verified) and [protected] are never deleted.
  /// A file that cannot be deleted is left; returns the names deleted.
  static Future<List<String>> prune(
    Directory dir, {
    required String newest,
    Set<String> protected = const {},
  }) async {
    if (!dir.existsSync()) return const [];
    final files = dir.listSync().whereType<File>().toList();
    final protectedNames = {
      p.basename(newest),
      for (final f in files)
        if (protected.any((x) => p.equals(x, f.path))) p.basename(f.path),
    };
    final drop = toDelete(
      files.map((f) => p.basename(f.path)).toList(),
      keep: protectedNames,
    );
    final deleted = <String>[];
    for (final f in files) {
      final name = p.basename(f.path);
      if (!drop.contains(name)) continue;
      try {
        f.deleteSync();
        deleted.add(name);
      } catch (e) {
        debugPrint('⚠️ Could not remove old automatic backup $name: $e');
      }
    }
    if (deleted.isNotEmpty) {
      debugPrint('🧹 Removed ${deleted.length} old automatic backup(s)');
    }
    return deleted;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
  static DateTime _monday(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}
