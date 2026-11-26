import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/domain/services/common/auto_backup_retention.dart';

/// BKP-6 K4: 14 daily + 8 weekly DAILY (start-of-day prompt) backups are
/// kept; manual backups and anything not exactly a daily backup's name are
/// never touched. Files of the former automatic backup age out the same way.
void main() {
  String auto(DateTime t, [int? n]) {
    final s = t.toIso8601String().replaceAll(':', '-').substring(0, 19);
    return 'BillBerryLite_daily_$s${n == null ? '' : '-$n'}.zip';
  }

  String legacy(DateTime t) =>
      'BillBerryLite_auto_${t.toIso8601String().replaceAll(':', '-').substring(0, 19)}.zip';

  /// One automatic backup a day at 09:00 for [days] days ending [end].
  List<String> daily(DateTime end, int days) => [
        for (var i = 0; i < days; i++)
          auto(DateTime(end.year, end.month, end.day - i, 9)),
      ];

  final end = DateTime(2026, 11, 16); // a Monday

  group('names', () {
    test('only exact automatic names are recognised', () {
      expect(AutoBackupRetention.stampOf(auto(DateTime(2026, 11, 16, 9))),
          DateTime(2026, 11, 16, 9));
      expect(AutoBackupRetention.stampOf(auto(DateTime(2026, 11, 16, 9), 2)),
          isNotNull);
      for (final other in [
        'BillBerryLite_encrypted_2026-11-16T09-00-00.zip', // manual
        'BillBerryLite_daily_2026-11-16T09-00-00.zip.part',
        'BillBerryLite_daily_2026-11-16.zip',
        'Copy of BillBerryLite_daily_2026-11-16T09-00-00.zip',
        'BillBerryLite_daily_2026-02-31T09-00-00.zip', // impossible date
        'BillBerryLite_auto_2026-11-16T09-00-00.zip.part',
        'notes.txt',
      ]) {
        expect(AutoBackupRetention.stampOf(other), isNull, reason: other);
      }
    });

    test('former automatic backups are recognised, so they age out too', () {
      expect(AutoBackupRetention.stampOf(legacy(DateTime(2026, 11, 16, 9))),
          DateTime(2026, 11, 16, 9));
      final names = [
        ...daily(end, 14),
        for (var i = 1; i <= 70; i++) // 10 weeks
          legacy(DateTime(2026, 11, 2 - i, 9)), // older than the 14 days
      ];
      final drop = AutoBackupRetention.toDelete(names);
      expect(names.toSet().difference(drop), hasLength(14 + 8));
      expect(drop.every((n) => n.startsWith(AutoBackupRetention.legacyPrefix)),
          isTrue);
    });
  });

  group('policy', () {
    test('100 daily backups → the 14 newest days + 8 older weekly points',
        () {
      final names = daily(end, 100);
      final drop = AutoBackupRetention.toDelete(names);
      final kept = names.toSet().difference(drop);
      expect(kept, hasLength(14 + 8));
      for (final n in daily(end, 14)) {
        expect(kept, contains(n), reason: 'daily $n');
      }
      // Weekly points are older than the 14 days, newest of their week.
      final weekly = kept.difference(daily(end, 14).toSet());
      final stamps = weekly.map(AutoBackupRetention.stampOf).toList()..sort();
      expect(stamps.last!.isBefore(DateTime(2026, 11, 3)), isTrue);
      final weeks = stamps
          .map((t) => DateTime(t!.year, t.month, t.day - (t.weekday - 1)))
          .toSet();
      expect(weeks, hasLength(8), reason: 'one per week');
      for (final t in stamps) {
        // Newest of its week: Sunday, or the day just before the daily window.
        expect(t!.weekday == DateTime.sunday || t == DateTime(2026, 11, 2, 9),
            isTrue, reason: '$t');
      }
    });

    test('fewer than 14 days of backups: nothing is pruned', () {
      expect(AutoBackupRetention.toDelete(daily(end, 10)), isEmpty);
    });

    test('several automatic backups on one day: the newest of the day counts',
        () {
      final names = [
        auto(DateTime(2026, 11, 16, 9)),
        auto(DateTime(2026, 11, 16, 15)),
        auto(DateTime(2026, 11, 16, 15), 1),
      ];
      expect(AutoBackupRetention.toDelete(names), {
        auto(DateTime(2026, 11, 16, 9)),
        auto(DateTime(2026, 11, 16, 15)),
      });
    });

    test('manual backups and unknown files are never selected', () {
      final names = [
        ...daily(end, 60),
        'BillBerryLite_encrypted_2025-01-01T09-00-00.zip',
        'BillBerryLite_backup_2025-01-01T09-00-00.zip',
        'family photo.jpg',
      ];
      final drop = AutoBackupRetention.toDelete(names);
      expect(drop.where((n) => !n.startsWith(AutoBackupRetention.prefix)),
          isEmpty);
    });

    test('a protected name is kept even when the policy would drop it', () {
      final names = daily(end, 100);
      final old = names.last;
      expect(AutoBackupRetention.toDelete(names), contains(old));
      expect(AutoBackupRetention.toDelete(names, keep: {old}),
          isNot(contains(old)));
    });
  });

  group('prune on disk', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('retention_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('deletes only what the policy drops; keeps the newest, manual, '
        'unknown and protected files', () async {
      final names = daily(end, 60);
      for (final n in [
        ...names,
        'BillBerryLite_encrypted_2025-01-01T09-00-00.zip',
        'readme.txt',
      ]) {
        File(p.join(dir.path, n)).writeAsBytesSync([1]);
      }
      final protectedFile = p.join(dir.path, names.last);
      final deleted = await AutoBackupRetention.prune(dir,
          newest: p.join(dir.path, names.first), protected: {protectedFile});

      final left = dir.listSync().map((f) => p.basename(f.path)).toSet();
      expect(left, contains(names.first), reason: 'newest verified');
      expect(left, contains('BillBerryLite_encrypted_2025-01-01T09-00-00.zip'));
      expect(left, contains('readme.txt'));
      expect(left, contains(names.last), reason: 'protected');
      expect(deleted, isNotEmpty);
      expect(left.where((n) => n.startsWith(AutoBackupRetention.prefix)),
          hasLength(14 + 8 + 1), reason: 'policy + the protected one');
    });
  });
}
