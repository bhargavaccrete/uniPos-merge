import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';

/// The rows an export covers are always a subset of the screen's filtered
/// list: All (same list, no copy), the current page, or whole days.
void main() {
  // 120 records, newest first, one every 6 hours from 30 Nov 2026 18:00 back.
  final rows = List.generate(
      120, (i) => DateTime(2026, 11, 30, 18).subtract(Duration(hours: 6 * i)));
  DateTime? dateOf(DateTime d) => d;

  List<DateTime> select(ExportScope scope,
          {int page = 0, DateTime? from, DateTime? to}) =>
      ReportExportService.selectForExport(rows,
          scope: scope,
          page: page,
          rowsPerPage: 50,
          from: from,
          to: to,
          dateOf: dateOf);

  group('All filtered', () {
    test('returns the same list instance — no copy of a large dataset', () {
      expect(identical(select(ExportScope.all), rows), isTrue);
    });
  });

  group('Current page', () {
    test('first page = rows 1–50', () {
      expect(select(ExportScope.page, page: 0), rows.sublist(0, 50));
    });
    test('middle page = rows 51–100', () {
      expect(select(ExportScope.page, page: 1), rows.sublist(50, 100));
    });
    test('last partial page = rows 101–120', () {
      expect(select(ExportScope.page, page: 2), rows.sublist(100, 120));
    });
  });

  group('Custom date range', () {
    test('includes the whole end day and the whole start day', () {
      final picked =
          select(ExportScope.dateRange, from: DateTime(2026, 11, 20), to: DateTime(2026, 11, 22));
      expect(picked, isNotEmpty);
      expect(picked.every((d) => !d.isBefore(DateTime(2026, 11, 20))), isTrue);
      expect(picked.every((d) => d.isBefore(DateTime(2026, 11, 23))), isTrue);
      expect(picked.length, 12, reason: '3 days × 4 records a day');
      expect(picked, contains(DateTime(2026, 11, 22, 18)), reason: 'end day evening');
      expect(picked, contains(DateTime(2026, 11, 20)), reason: 'start day midnight');
    });

    test('end-of-day boundary: 23:59:59 in, next day 00:00 out', () {
      final edge = [
        DateTime(2026, 11, 22, 23, 59, 59),
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 21, 23, 59, 59),
      ];
      final picked = ReportExportService.selectForExport(edge,
          scope: ExportScope.dateRange,
          from: DateTime(2026, 11, 22),
          to: DateTime(2026, 11, 22),
          dateOf: dateOf);
      expect(picked, [DateTime(2026, 11, 22, 23, 59, 59)]);
    });

    test('a picked time of day does not shorten the range', () {
      final picked = select(ExportScope.dateRange,
          from: DateTime(2026, 11, 22, 15), to: DateTime(2026, 11, 22, 9));
      expect(picked.length, 4, reason: 'whole day 22 Nov');
    });

    test('a range with no records is empty', () {
      expect(
          select(ExportScope.dateRange,
              from: DateTime(2025, 1, 1), to: DateTime(2025, 1, 31)),
          isEmpty);
    });

    test('records without a date are left out', () {
      final mixed = <DateTime?>[DateTime(2026, 11, 22, 10), null];
      final picked = ReportExportService.selectForExport<DateTime?>(mixed,
          scope: ExportScope.dateRange,
          from: DateTime(2026, 11, 22),
          to: DateTime(2026, 11, 22),
          dateOf: (d) => d);
      expect(picked, [DateTime(2026, 11, 22, 10)]);
    });

    test('only narrows: every picked record comes from the filtered list', () {
      final picked = select(ExportScope.dateRange,
          from: DateTime(2020), to: DateTime(2030));
      expect(picked, rows, reason: 'a wide range never adds records');
    });
  });
}
