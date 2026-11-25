import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';

/// Date-only and 24-hour typed cells: genuine date cells in Excel, and the
/// PDF prints exactly the text each report printed before. Plus the
/// exportOf path (rows + summary built together from the selection) and a
/// guard that no Retail report opted into the ranged scaffold export.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final when = DateTime(2026, 11, 24, 14, 35);

  List<List<Data?>> read(List<int> bytes) =>
      Excel.decodeBytes(bytes).tables.values.first.rows;
  int header(List<List<Data?>> rows, String first) => rows.indexWhere(
      (r) => r.isNotEmpty && r.first?.value.toString() == first);

  group('Excel', () {
    final rows = read(ReportExportService.buildExcelBytesForTesting(
      headers: ['Date', 'Time24', 'Time12'],
      data: [
        [
          ExportDate(when),
          ExportDateTime(when, hour24: true),
          ExportDateTime(when),
        ]
      ],
    ));
    final h = header(rows, 'Date');

    test('ExportDate is a genuine date cell (no time)', () {
      final v = rows[h + 1][0]!.value;
      expect(v, isA<DateCellValue>());
      final d = v as DateCellValue;
      expect([d.year, d.month, d.day], [2026, 11, 24]);
      expect(rows[h + 1][0]!.cellStyle?.numberFormat.formatCode, 'dd mmm yyyy');
    });

    test('24-hour date-time: genuine date-time cell, 24-hour format code', () {
      expect(rows[h + 1][1]!.value, isA<DateTimeCellValue>());
      expect(rows[h + 1][1]!.cellStyle?.numberFormat.formatCode,
          'dd mmm yyyy hh:mm');
    });

    test('12-hour date-time keeps its AM/PM format (unchanged default)', () {
      expect(rows[h + 1][2]!.cellStyle?.numberFormat.formatCode,
          'dd mmm yyyy hh:mm AM/PM');
    });
  });

  group('PDF text is preserved', () {
    test('date-only defaults to formatDate (dd MMM yyyy)', () {
      expect(ReportExportService.pdfRows([
        [ExportDate(when)]
      ]).single.single, ReportExportService.formatDate(when));
    });

    test('24-hour defaults to dd MMM yyyy, HH:mm (stock adjustment style)', () {
      expect(
          ReportExportService.pdfRows([
            [ExportDateTime(when, hour24: true)]
          ]).single.single,
          DateFormat('dd MMM yyyy, HH:mm').format(when));
    });

    test('an explicit pattern is printed as-is (cash drawer style)', () {
      expect(
          ReportExportService.pdfRows([
            [ExportDateTime(when, hour24: true, pdfPattern: 'dd MMM yyyy  HH:mm')]
          ]).single.single,
          '24 Nov 2026  14:35');
    });

    test('12-hour default is still formatDateTime', () {
      expect(ReportExportService.pdfRows([
        [ExportDateTime(when)]
      ]).single.single, ReportExportService.formatDateTime(when));
    });
  });

  group('isoDateCell (purchase reports): same rules as their old _date', () {
    test('missing → empty text', () {
      expect(ReportExportService.isoDateCell(null), '');
      expect(ReportExportService.isoDateCell(''), '');
    });

    test('unreadable → the stored text itself', () {
      expect(ReportExportService.isoDateCell('not-a-date'), 'not-a-date');
    });

    test('date → a date cell printing dd MMM yyyy', () {
      final cell = ReportExportService.isoDateCell('2026-11-24T14:35:00.000');
      expect(cell, isA<ExportDate>());
      expect(ReportExportService.pdfRows([
        [cell]
      ]).single.single, '24 Nov 2026');
    });

    test('hour24 → a date-time cell printing dd MMM yyyy, HH:mm', () {
      final cell = ReportExportService.isoDateCell('2026-11-24T14:35:00.000',
          hour24: true);
      expect(cell, isA<ExportDateTime>());
      expect(ReportExportService.pdfRows([
        [cell]
      ]).single.single, '24 Nov 2026, 14:35');
    });
  });

  test('money columns never touch quantities: exportQty values stay plain '
      'numbers (no currency format)', () {
    final rows = read(ReportExportService.buildExcelBytesForTesting(
      headers: ['Qty', 'Value'],
      data: [
        [12.5, const ExportMoney(99.75)]
      ],
    ));
    final h = header(rows, 'Qty');
    expect(rows[h + 1][0]!.cellStyle?.numberFormat.formatCode ?? '',
        isNot(contains('"')),
        reason: 'no currency symbol on a quantity');
    expect(rows[h + 1][1]!.cellStyle?.numberFormat.formatCode, contains('#,##0'));
  });

  group('buildExportFor', () {
    test('exportOf: rows and summary come from exactly the selection', () {
      final built = ReportExportService.buildExportFor<int>(
        [10, 20],
        label: 'Page 2 (rows 51–52)',
        unit: 'rows',
        exportOf: (sel) => (
          data: sel.map((v) => [ExportMoney(v.toDouble())]).toList(),
          summary: {'Total': sel.fold<int>(0, (a, b) => a + b).toString()},
        ),
      );
      expect(built.data.length, 2);
      expect(built.summary.keys.first, 'Exported');
      expect(built.summary['Exported'], 'Page 2 (rows 51–52) (2 rows)');
      expect(built.summary['Total'], '30');
    });

    test('rowOf + summaryOf path; All adds no Exported line', () {
      final built = ReportExportService.buildExportFor<int>(
        [1, 2, 3],
        label: null,
        unit: 'rows',
        rowOf: (v) => [v],
        summaryOf: (sel) => {'Count': sel.length.toString()},
      );
      expect(built.data, [
        [1],
        [2],
        [3]
      ]);
      expect(built.summary.containsKey('Exported'), isFalse);
      expect(built.summary['Count'], '3');
    });
  });

  group('Retail ranged scaffold export: exactly the approved R2 reports', () {
    // Per-record reports: All / Current page / Date range.
    const withRange = {
      'grn_report_screen.dart',
      'damaged_items_report_screen.dart',
      'purchase_return_report_screen.dart',
      'stock_adjustment_report_screen.dart',
      'purchase_order_status_report_screen.dart',
      'sales_refund_report_screen.dart',
      'discount_report_screen.dart',
      'cash_drawer_history_report_screen.dart',
    };
    // Grouped reports: All / Current page only — never a row date.
    const pageOnly = {
      'supplier_wise_purchase_report_screen.dart',
      'product_wise_sales_report_screen.dart',
      'variant_wise_sales_report_screen.dart',
      'category_wise_sales_report_screen.dart',
      'quick_items_report_screen.dart',
    };

    final files = Directory('lib/presentation/screens/retail')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    String name(File f) => f.uri.pathSegments.last;

    test('only approved reports opt in', () {
      final optedIn = files
          .where((f) => f.readAsStringSync().contains('rangedExport'))
          .map(name)
          .toSet();
      expect(optedIn, {...withRange, ...pageOnly});
    });

    test('only per-record reports offer a date range', () {
      final withRowDate = files
          .where((f) => f.readAsStringSync().contains('exportRowDate'))
          .map(name)
          .toSet();
      expect(withRowDate, withRange);
    });
  });
}
