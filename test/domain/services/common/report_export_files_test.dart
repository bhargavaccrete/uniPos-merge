import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';

/// Excel: ExportMoney / ExportDateTime become genuine numeric and date-time
/// cells (read back from the real .xlsx bytes); every other caller's cells
/// are unchanged. PDF: typed cells print exactly as before; 500-row cap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<List<Data?>> readRows(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    return excel.tables.values.first.rows;
  }

  /// A numeric cell's value. Whole numbers read back as IntCellValue even
  /// when written as DoubleCellValue — both are genuine numbers in Excel.
  num? numberOf(Data? cell) => switch (cell?.value) {
        DoubleCellValue(:final value) => value,
        IntCellValue(:final value) => value,
        _ => null,
      };

  /// The header row index (first row whose first cell is [firstHeader]).
  int headerRow(List<List<Data?>> rows, String firstHeader) => rows.indexWhere(
      (r) => r.isNotEmpty && r.first?.value.toString() == firstHeader);

  group('Excel typed cells', () {
    final when = DateTime(2026, 11, 24, 14, 35);
    final bytes = ReportExportService.buildExcelBytesForTesting(
      headers: ['Date', 'Invoice', 'Qty', 'Amount'],
      data: [
        [ExportDateTime(when), 'INV 12', 3, const ExportMoney(1234.5678)],
        [ExportDateTime(when), 'INV 13', 1, const ExportMoney(0.1)],
      ],
      title: 'Total Sales',
      summary: {'Total Sales': '₹1,234.67'},
    );
    final rows = readRows(bytes);
    final h = headerRow(rows, 'Date');

    test('amounts are genuine numeric cells with full precision', () {
      final amount = rows[h + 1][3]!.value;
      expect(amount, isA<DoubleCellValue>());
      expect((amount as DoubleCellValue).value, 1234.5678,
          reason: 'not rounded — the format only changes the display');
      expect((rows[h + 2][3]!.value as DoubleCellValue).value, 0.1);
    });

    test('amount cells carry the currency number format', () {
      final style = rows[h + 1][3]!.cellStyle;
      expect(style?.numberFormat.formatCode, contains('#,##0'));
    });

    test('dates are genuine date-time cells', () {
      final date = rows[h + 1][0]!.value;
      expect(date, isA<DateTimeCellValue>());
      final dt = (date as DateTimeCellValue).asDateTimeLocal();
      expect([dt.year, dt.month, dt.day, dt.hour, dt.minute],
          [2026, 11, 24, 14, 35]);
    });

    test('plain numbers and text keep their old cell types', () {
      expect(rows[h + 1][1]!.value, isA<TextCellValue>());
      expect(numberOf(rows[h + 1][2]), 3);
    });

    test('a column of amounts sums in Excel terms', () {
      final sum = [rows[h + 1][3], rows[h + 2][3]]
          .map((c) => (c!.value as DoubleCellValue).value)
          .reduce((a, b) => a + b);
      expect(sum, closeTo(1234.6678, 1e-9));
    });
  });

  group('Excel: callers outside the 8 reports are unchanged', () {
    test('formatted strings stay text, numbers stay numbers, no styles added',
        () {
      final bytes = ReportExportService.buildExcelBytesForTesting(
        headers: ['Name', 'Amount', 'Count'],
        data: [
          ['Tea', '₹10.00', 5]
        ],
      );
      final rows = readRows(bytes);
      final h = headerRow(rows, 'Name');
      expect(rows[h + 1][1]!.value, isA<TextCellValue>());
      expect(rows[h + 1][1]!.value.toString(), '₹10.00');
      expect(numberOf(rows[h + 1][2]), 5);
    });
  });

  group('Excel: several thousand records', () {
    test('5,000 rows are all present and numeric', () {
      final start = DateTime(2026, 1, 1);
      final data = [
        for (var i = 0; i < 5000; i++)
          [
            ExportDateTime(start.add(Duration(minutes: i))),
            'INV $i',
            ExportMoney(i + 0.25),
          ]
      ];
      final rows = readRows(ReportExportService.buildExcelBytesForTesting(
          headers: ['Date', 'Invoice', 'Amount'], data: data));
      final h = headerRow(rows, 'Date');
      final dataRows = rows.sublist(h + 1);
      expect(dataRows.length, 5000, reason: 'no 500-row limit in Excel');
      expect((dataRows.last[2]!.value as DoubleCellValue).value, 4999.25);
      expect(dataRows.last[0]!.value, isA<DateTimeCellValue>());
    });
  });

  group('Money format', () {
    test('symbol and decimal places from settings, display only', () {
      expect(ReportExportService.excelMoneyFormat(symbol: '₹', decimals: 2),
          '"₹"#,##0.00');
      expect(ReportExportService.excelMoneyFormat(symbol: '\$', decimals: 0),
          '"\$"#,##0');
      expect(ReportExportService.excelMoneyFormat(symbol: 'KD', decimals: 3),
          '"KD"#,##0.000');
      expect(ReportExportService.excelMoneyFormat(symbol: '', decimals: 2),
          '#,##0.00');
    });
  });

  group('PDF', () {
    test('typed cells print exactly the old formatted text', () {
      final when = DateTime(2026, 11, 24, 14, 35);
      final out = ReportExportService.pdfRows([
        [ExportDateTime(when), 'INV 1', const ExportMoney(1234.5)],
      ]);
      expect(out.single, [
        ReportExportService.formatDateTime(when),
        'INV 1',
        ReportExportService.formatCurrency(1234.5),
      ]);
    });

    test('more than 500 records: only the first 500 go in', () {
      final data = [
        for (var i = 0; i < 650; i++) ['Row $i', ExportMoney(i.toDouble())]
      ];
      final out = ReportExportService.pdfRows(data);
      expect(ReportExportService.maxPdfRows, 500);
      expect(out.length, 500);
      expect(out.first.first, 'Row 0');
      expect(out.last.first, 'Row 499');
    });

    test('a 650-record PDF builds within the 100-page limit', () async {
      final font = Uint8List.fromList(
          File('assets/fonts/Poppins-Regular.ttf').readAsBytesSync());
      final bold = Uint8List.fromList(
          File('assets/fonts/Poppins-Bold.ttf').readAsBytesSync());
      final data = [
        for (var i = 0; i < 650; i++)
          [
            ExportDateTime(DateTime(2026, 11, 1).add(Duration(hours: i))),
            'INV $i',
            'Customer $i',
            ExportMoney(i * 1.5),
          ]
      ];
      final bytes = await ReportExportService.buildPdfBytesForTesting(
        headers: ['Date', 'Invoice', 'Customer', 'Amount'],
        data: data,
        fontBytes: font,
        fontBoldBytes: bold,
        summary: {'Total': '650'},
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
