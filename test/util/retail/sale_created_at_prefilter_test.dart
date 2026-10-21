import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/util/retail/sale_created_at_prefilter.dart';

/// The pre-filter may only ever say "definitely outside" about a string that
/// `DateTime.tryParse` parses and the existing `[start, end)` comparison rejects.
///
/// Timezone-independent by construction; run it under other offsets too, e.g.
/// `TZ=EST+5EDT+4` / `TZ=WST-13` (the Windows Dart VM honours fixed whole-hour
/// offsets only — DST rules cannot be exercised there).

/// The existing rule, as `_inWindow` / `getSalesByDateRange` apply it.
bool legacyInWindow(String s, DateTime? start, DateTime? end) {
  final at = DateTime.tryParse(s);
  if (at == null) return false;
  if (start != null && at.isBefore(start)) return false;
  if (end != null && !at.isBefore(end)) return false;
  return true;
}

void main() {
  final start = DateTime(2026, 6, 1);
  final end = DateTime(2026, 7, 1);
  final window = SaleCreatedAtPrefilter.forWindow(start, end);

  String iso(DateTime d) => d.toIso8601String();

  group('canonical writer strings', () {
    test('both lengths are recognised', () {
      expect(iso(DateTime(2020, 1, 1, 10)).length, 23);
      expect(iso(DateTime(2020, 1, 1, 10, 0, 0, 0, 1)).length, 26);
      expect(window.isDefinitelyOutside(iso(DateTime(2020, 1, 1, 10))), isTrue);
      expect(window.isDefinitelyOutside(iso(DateTime(2020, 1, 1, 10, 0, 0, 0, 1))), isTrue);
    });

    test('at and around the start: never pre-filtered within the margin', () {
      for (final s in [
        start,
        start.subtract(const Duration(microseconds: 1)),
        start.add(const Duration(microseconds: 1)),
        DateTime(2026, 5, 31, 12),
        DateTime(2026, 5, 30, 0),
        DateTime(2026, 5, 29, 0), // exactly 3 days before: still parsed
        DateTime(2026, 5, 29, 23, 59, 59, 999, 999),
      ]) {
        expect(window.isDefinitelyOutside(iso(s)), isFalse, reason: iso(s));
      }
      // More than 3 days before.
      expect(window.isDefinitelyOutside(iso(DateTime(2026, 5, 28, 23, 59, 59, 999, 999))), isTrue);
      expect(window.isDefinitelyOutside(iso(DateTime(2026, 5, 28))), isTrue);
    });

    test('at and around the end: never pre-filtered within the margin', () {
      for (final s in [
        end,
        end.subtract(const Duration(microseconds: 1)),
        end.add(const Duration(microseconds: 1)),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 3, 12),
        DateTime(2026, 7, 4, 23, 59, 59, 999, 999), // 3 days after: still parsed
      ]) {
        expect(window.isDefinitelyOutside(iso(s)), isFalse, reason: iso(s));
      }
      expect(window.isDefinitelyOutside(iso(DateTime(2026, 7, 5))), isTrue);
      expect(window.isDefinitelyOutside(iso(DateTime(2027, 1, 1))), isTrue);
    });

    test('inside the window is never pre-filtered', () {
      for (var d = 1; d <= 30; d++) {
        expect(window.isDefinitelyOutside(iso(DateTime(2026, 6, d, 13, 7))), isFalse);
      }
    });
  });

  group('everything else goes to tryParse', () {
    test('canonical shape with invalid fields is never pre-filtered', () {
      for (final s in [
        '2020-02-30T10:00:00.000',
        '2020-13-01T10:00:00.000',
        '2020-00-01T10:00:00.000',
        '2020-01-00T10:00:00.000',
        '2020-01-01T24:00:00.000',
        '2020-01-01T00:60:00.000',
        '2020-01-01T00:00:60.000',
        '2021-02-29T10:00:00.000', // not a leap year
        '2026-05-32T10:00:00.000', // tryParse → 1 June, inside
        '2026-07-00T10:00:00.000', // tryParse → 30 June, inside
      ]) {
        expect(window.isDefinitelyOutside(s), isFalse, reason: s);
      }
      expect(window.isDefinitelyOutside('2020-02-29T10:00:00.000'), isTrue); // leap year: valid
    });

    test('non-canonical shapes are never pre-filtered, however far away', () {
      for (final s in [
        '2020-01-01T10:00:00.000Z',
        '2020-01-01T10:00:00+05:30',
        '2020-01-01',
        '2020-01-01 10:00:00.000',
        '2020-01-01T10:00:00,000',
        '2020-01-01T10:00',
        '2020-01-01T10:00:00',
        '2020-01-01T10:00:00.1234567',
        '2020-01-01T10:00:00.12',
        '2020-01-01t10:00:00.000',
        ' 2020-01-01T10:00:00.000',
        '2020-01-01T10:00:00.000 ',
        '20200101T100000',
        '+02020-01-01T10:00:00.000',
        '2020/01/01T10:00:00.000',
        'abcd-ef-ghTij:kl:mn.opq',
        '2020-01-01T10:00:00.00a',
        'not-a-date',
        '',
      ]) {
        expect(window.isDefinitelyOutside(s), isFalse, reason: s);
      }
    });

    test('an unbounded window pre-filters nothing', () {
      final all = SaleCreatedAtPrefilter.forWindow(null, null);
      expect(all.isDefinitelyOutside('1990-01-01T00:00:00.000'), isFalse);
      expect(all.isDefinitelyOutside('2999-01-01T00:00:00.000'), isFalse);
    });

    test('half-bounded windows only filter on their own side', () {
      final startOnly = SaleCreatedAtPrefilter.forWindow(start, null);
      expect(startOnly.isDefinitelyOutside('2020-01-01T00:00:00.000'), isTrue);
      expect(startOnly.isDefinitelyOutside('2999-01-01T00:00:00.000'), isFalse);
      final endOnly = SaleCreatedAtPrefilter.forWindow(null, end);
      expect(endOnly.isDefinitelyOutside('2020-01-01T00:00:00.000'), isFalse);
      expect(endOnly.isDefinitelyOutside('2999-01-01T00:00:00.000'), isTrue);
    });

    test('UTC bounds are compared by their LOCAL calendar date', () {
      final utcStart = DateTime.utc(2026, 6, 1);
      final local = utcStart.toLocal();
      final filter = SaleCreatedAtPrefilter.forWindow(utcStart, null);
      final threeBefore = DateTime(local.year, local.month, local.day - 3, 0);
      final fourBefore = DateTime(local.year, local.month, local.day - 4, 23, 59, 59);
      expect(filter.isDefinitelyOutside(iso(threeBefore)), isFalse);
      expect(filter.isDefinitelyOutside(iso(fourBefore)), isTrue);
    });
  });

  test('property: "definitely outside" always agrees with tryParse + [start, end)', () {
    final rnd = Random(4606);
    // Bounds on real timezone-transition dates (US and Lord Howe DST in 2026,
    // Samoa's skipped 30 Dec 2011, Kwajalein's skipped 21 Aug 1993), plus
    // random ones and odd times of day.
    final anchors = <DateTime>[
      DateTime(2026, 3, 8), DateTime(2026, 3, 8, 2, 30), DateTime(2026, 11, 1, 1, 30),
      DateTime(2026, 4, 5, 1, 45), DateTime(2026, 10, 4, 2, 15),
      DateTime(2011, 12, 30), DateTime(2011, 12, 31), DateTime(2011, 12, 29, 23, 59),
      DateTime(1993, 8, 21), DateTime(2000, 2, 29), DateTime(1970, 1, 1),
      DateTime.utc(2026, 6, 1), DateTime.utc(2026, 6, 30, 23, 59, 59),
      for (var i = 0; i < 40; i++)
        DateTime(1950 + rnd.nextInt(120), 1 + rnd.nextInt(12), 1 + rnd.nextInt(28),
            rnd.nextInt(24), rnd.nextInt(60), rnd.nextInt(60), rnd.nextInt(1000), rnd.nextInt(1000)),
    ];

    final stamps = <String>[];
    for (final a in anchors) {
      final local = a.toLocal();
      for (var d = -8; d <= 8; d++) {
        for (final (h, m, s, us) in [(0, 0, 0, 0), (0, 0, 0, 1), (23, 59, 59, 999999), (2, 30, 0, 0), (12, 0, 0, 500)]) {
          stamps.add(DateTime(local.year, local.month, local.day + d, h, m, s, 0, us).toIso8601String());
        }
      }
    }
    for (var i = 0; i < 6000; i++) {
      stamps.add(DateTime(1950 + rnd.nextInt(120), 1 + rnd.nextInt(12), 1 + rnd.nextInt(31),
              rnd.nextInt(24), rnd.nextInt(60), rnd.nextInt(60), rnd.nextInt(1000),
              rnd.nextBool() ? 0 : rnd.nextInt(1000))
          .toIso8601String());
    }
    // Canonical-shaped but out of range, and corrupted variants.
    for (var i = 0; i < 3000; i++) {
      final y = (1950 + rnd.nextInt(120)).toString().padLeft(4, '0');
      String two(int max) => rnd.nextInt(max).toString().padLeft(2, '0');
      stamps.add('$y-${two(15)}-${two(40)}T${two(30)}:${two(70)}:${two(70)}.${rnd.nextInt(1000).toString().padLeft(3, '0')}');
    }

    final windows = <(DateTime?, DateTime?)>[
      (null, null),
      for (var i = 0; i < anchors.length; i++) ...[
        (anchors[i], anchors[(i + 1) % anchors.length].isAfter(anchors[i]) ? anchors[(i + 1) % anchors.length] : anchors[i].add(const Duration(days: 30))),
        (anchors[i], null),
        (null, anchors[i]),
        (anchors[i], anchors[i].add(const Duration(days: 1))),
      ],
    ];

    // Parse once; the legacy rule below is `legacyInWindow` on the cached value.
    final parsed = [for (final stamp in stamps) DateTime.tryParse(stamp)];
    bool legacyIn(int i, DateTime? s, DateTime? e) {
      final at = parsed[i];
      if (at == null) return false;
      if (s != null && at.isBefore(s)) return false;
      if (e != null && !at.isBefore(e)) return false;
      return true;
    }

    expect(legacyIn(0, windows[1].$1, windows[1].$2),
        legacyInWindow(stamps[0], windows[1].$1, windows[1].$2));

    var excluded = 0;
    var checks = 0;
    final violations = <String>[];
    for (final (s, e) in windows) {
      final filter = SaleCreatedAtPrefilter.forWindow(s, e);
      for (var i = 0; i < stamps.length; i++) {
        checks++;
        if (!filter.isDefinitelyOutside(stamps[i])) continue;
        excluded++;
        if (parsed[i] == null || legacyIn(i, s, e)) {
          violations.add('${stamps[i]} vs [$s, $e) parsed=${parsed[i]}');
        }
      }
    }
    expect(violations, isEmpty);
    // The property must actually have been exercised.
    expect(excluded, greaterThan(checks ~/ 2));
    // ignore: avoid_print
    print('PREFILTER property checks=$checks excluded=$excluded');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
