import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:universal_html/html.dart' as html;
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

// ═══════════════════════════════════════════════════════════════════════
// TYPED EXPORT CELLS (opt-in)
// ═══════════════════════════════════════════════════════════════════════
// A report that wants real spreadsheet values passes these instead of
// formatted strings. Excel stores a genuine number / date-time (full
// precision; the format only changes how it looks). PDF prints exactly the
// text formatCurrency / formatDateTime produced before. Callers that keep
// passing strings and plain numbers get exactly the output they always got.

/// A money amount: a numeric Excel cell with the currency format.
class ExportMoney {
  final double value;
  const ExportMoney(this.value);
}

/// A date and time: a date-time Excel cell.
///
/// PDF text: [pdfPattern] when given, else `formatDateTime` (12-hour). Set
/// [hour24] for reports that show 24-hour times, so Excel shows them the
/// same way.
class ExportDateTime {
  final DateTime value;
  final bool hour24;
  final String? pdfPattern;
  const ExportDateTime(this.value, {this.hour24 = false, this.pdfPattern});

  String get excelFormat =>
      hour24 ? 'dd mmm yyyy hh:mm' : 'dd mmm yyyy hh:mm AM/PM';
}

/// A date without a time: a date Excel cell. PDF text uses [pdfPattern]
/// (default `dd MMM yyyy`, the same as `formatDate`).
class ExportDate {
  final DateTime value;
  final String pdfPattern;
  const ExportDate(this.value, {this.pdfPattern = 'dd MMM yyyy'});
}

/// A plain (non-money) number shown to [decimals] places, e.g. decimal hours.
/// Excel keeps the full value with a `0.00`-style display format; the PDF
/// prints it rounded to [decimals].
class ExportNumber {
  final double value;
  final int decimals;
  const ExportNumber(this.value, {this.decimals = 2});

  String get excelFormat => decimals > 0 ? '0.${'0' * decimals}' : '0';
}

/// Which records an export covers.
enum ExportScope { all, page, dateRange }

// ═══════════════════════════════════════════════════════════════════════
// TOP-LEVEL ISOLATE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════
// These MUST be top-level (not closures, not instance methods) so that
// compute() can send them to a fresh isolate without serializing any
// captured state from the calling scope.
// ═══════════════════════════════════════════════════════════════════════

/// Builds the complete PDF document in a background isolate.
///
/// Receives a plain Map with only primitive/transferable types:
///   - Uint8List for font bytes (zero-copy transfer)
///   - `List<List<String>>` for table data
///   - `Map<String, String>` for summary
///
/// Returns the encoded PDF bytes.
Future<Uint8List> _buildPdfBytes(Map<String, dynamic> params) async {
  final fontBytes = params['fontBytes'] as Uint8List;
  final fontBoldBytes = params['fontBoldBytes'] as Uint8List;
  final title = params['title'] as String;
  final headers = (params['headers'] as List).cast<String>();
  final data = (params['data'] as List)
      .map((row) => (row as List).cast<String>())
      .toList();
  final summaryMap = params['summary'] as Map<String, String>?;
  final pageWidth = params['pageWidth'] as double;
  final pageHeight = params['pageHeight'] as double;
  final wasTruncated = params['wasTruncated'] as bool;
  final totalRows = params['totalRows'] as int;
  final maxPdfRows = params['maxPdfRows'] as int;
  final generatedAt = params['generatedAt'] as String;

  // Reconstruct pw.Font from raw bytes inside the isolate.
  // pw.Font.ttf() just wraps a ByteData — very cheap.
  final font = pw.Font.ttf(ByteData.sublistView(fontBytes));
  final fontBold = pw.Font.ttf(ByteData.sublistView(fontBoldBytes));
  final format = PdfPageFormat(pageWidth, pageHeight);

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: format,
      maxPages: 100,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        // Title
        pw.Header(
          level: 0,
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 10),

        // Generated timestamp
        pw.Text(
          'Generated: $generatedAt',
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey),
        ),

        // Truncation notice
        if (wasTruncated) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'Showing first $maxPdfRows of $totalRows rows. Use Excel export for full data.',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.orange,
            ),
          ),
        ],
        pw.SizedBox(height: 20),

        // Summary section
        if (summaryMap != null) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: summaryMap.entries.map((entry) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        entry.key,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(entry.value, style: pw.TextStyle(font: font)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 20),
        ],

        // Data table
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            font: fontBold,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          cellStyle: pw.TextStyle(font: font, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
          // NO fixed cellHeight. It used to be 25, which is a hard height, not
          // a minimum — so the moment a value wrapped to a second line it
          // overflowed its box and printed down over the row beneath it.
          // Padding gives the same breathing room while letting a row grow to
          // fit whatever it holds.
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          headerPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
          cellAlignments: {
            for (int i = 0; i < headers.length; i++)
              i: i == headers.length - 1
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft,
          },
        ),
      ],
    ),
  );

  return pdf.save();
}

/// Builds the complete Excel workbook in a background isolate.
///
/// Receives a plain Map with only primitive types.
/// Returns the encoded xlsx bytes.
List<int> _buildExcelBytes(Map<String, dynamic> params) {
  final sheetName = params['sheetName'] as String;
  final title = params['title'] as String?;
  final headers = (params['headers'] as List).cast<String>();
  final colCount = headers.length;

  // data rows: each row is a list of {value, isNum} maps for type fidelity
  final rawRows = params['rows'] as List;
  final summaryEntries = params['summary'] as List?; // [{key, value}]
  final colLetterForMerge = params['colLetter'] as String;

  final excel = Excel.createExcel();
  final sheet = excel[sheetName];

  if (excel.tables.containsKey('Sheet1') && sheetName != 'Sheet1') {
    excel.delete('Sheet1');
  }

  int currentRow = 0;

  // Title
  if (title != null) {
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('${colLetterForMerge}1'),
    );
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(title);
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
    );
    currentRow = 2;
  }

  // Summary
  if (summaryEntries != null) {
    currentRow++;
    for (final entry in summaryEntries) {
      final m = entry as Map;
      final keyCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      );
      keyCell.value = TextCellValue(m['key'] as String);
      keyCell.cellStyle = CellStyle(bold: true);

      final valueCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
      );
      valueCell.value = TextCellValue(m['value'] as String);
      currentRow++;
    }
    currentRow++;
  }

  // Headers
  for (int i = 0; i < colCount; i++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow),
    );
    cell.value = TextCellValue(headers[i]);
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
  }
  currentRow++;

  // Typed-cell formats (only used when a caller sends ExportMoney /
  // ExportDateTime). Value first, then style: excel swaps a mismatched
  // number format on write, and a mismatch would throw at save.
  final moneyStyle = CellStyle(
    numberFormat: CustomNumericNumFormat(
      formatCode: params['moneyFormat'] as String? ?? '#,##0.00',
    ),
  );
  // One style per date/date-time format code (12-hour, 24-hour, date-only).
  final dateStyles = <String, CellStyle>{};
  CellStyle dateStyle(String code) => dateStyles.putIfAbsent(
    code,
    () => CellStyle(numberFormat: CustomDateTimeNumFormat(formatCode: code)),
  );
  final numberStyles = <String, CellStyle>{};
  CellStyle numberStyle(String code) => numberStyles.putIfAbsent(
    code,
    () => CellStyle(numberFormat: CustomNumericNumFormat(formatCode: code)),
  );

  // Data rows
  for (final rawRow in rawRows) {
    final row = rawRow as List;
    for (int i = 0; i < row.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow),
      );
      final item = row[i] as Map;
      final kind = item['kind'];
      if (kind == 'money') {
        cell.value = DoubleCellValue((item['value'] as num).toDouble());
        cell.cellStyle = moneyStyle;
      } else if (kind == 'datetime') {
        cell.value = DateTimeCellValue.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(item['value'] as int),
        );
        cell.cellStyle = dateStyle(item['fmt'] as String);
      } else if (kind == 'date') {
        cell.value = DateCellValue.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(item['value'] as int),
        );
        cell.cellStyle = dateStyle('dd mmm yyyy');
      } else if (kind == 'number') {
        cell.value = DoubleCellValue((item['value'] as num).toDouble());
        cell.cellStyle = numberStyle(item['fmt'] as String);
      } else if (item['isNum'] == true) {
        cell.value = DoubleCellValue((item['value'] as num).toDouble());
      } else {
        cell.value = TextCellValue(item['value'] as String);
      }
    }
    currentRow++;
  }

  // Column widths
  for (int i = 0; i < colCount; i++) {
    sheet.setColumnWidth(i, 20);
  }

  return excel.encode()!;
}

// ═══════════════════════════════════════════════════════════════════════
// REPORT EXPORT SERVICE
// ═══════════════════════════════════════════════════════════════════════

/// Comprehensive Report Export Service
///
/// Performance strategy:
/// - Heavy Excel/PDF generation runs in a background isolate via compute()
/// - Font bytes cached as Uint8List for efficient zero-copy isolate transfer
/// - PDF capped at 500 rows; Excel handles unlimited rows
/// - Loading overlay stays on the UI thread (always responsive)
/// - On web, compute() runs inline (no real isolate in JS)
class ReportExportService {
  // ── Loading overlay ─────────────────────────────────────────────────
  static OverlayEntry? _loadingOverlay;

  static void _showLoading(BuildContext context, String message) {
    _loadingOverlay?.remove();
    _loadingOverlay = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_loadingOverlay!);
  }

  static void _hideLoading() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  /// A truncated PDF holds incomplete data — warn rather than report success.
  static void _notifyPdfExported(bool wasTruncated, String successMessage) {
    if (wasTruncated) {
      NotificationService.instance.showWarning(
        'PDF exported — first $_maxPdfRows rows only. Use Excel for all data.',
      );
    } else {
      NotificationService.instance.showSuccess(successMessage);
    }
  }

  // ── Font byte cache ─────────────────────────────────────────────────
  // Loaded once from bundled assets (no network). Stored as raw Uint8List
  // so they can be passed efficiently to compute() isolates.
  static Uint8List? _fontBytes;
  static Uint8List? _fontBoldBytes;

  static Future<Uint8List> loadFontBytes() async {
    if (_fontBytes == null) {
      final data = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
      _fontBytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }
    return _fontBytes!;
  }

  static Future<Uint8List> loadBoldFontBytes() async {
    if (_fontBoldBytes == null) {
      final data = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
      _fontBoldBytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }
    return _fontBoldBytes!;
  }

  // ── Excel Export ────────────────────────────────────────────────────

  /// Export data to Excel format.
  ///
  /// Heavy workbook creation and encoding runs in a background isolate
  /// via [compute], keeping the UI thread free for the loading spinner.
  static Future<void> exportToExcel({
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> data,
    required BuildContext context,
    String? title,
    Map<String, dynamic>? summary,
  }) async {
    if (!context.mounted) return;
    _showLoading(context, 'Generating Excel...');

    try {
      // ── Pre-process on main thread (fast — just type conversion) ────
      final params = _excelParams(
        sheetName: sheetName,
        title: title,
        headers: headers,
        data: data,
        summary: summary,
      );

      // ── Run heavy work in isolate ────────────────────────────────────
      final fileBytes = await compute(_buildExcelBytes, params);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFileName = '${fileName}_$timestamp.xlsx';

      _hideLoading();

      if (kIsWeb) {
        final blob = html.Blob([
          fileBytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fullFileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        NotificationService.instance.showSuccess('Excel exported');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fullFileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        final result = await Share.shareXFiles(
          [XFile(filePath)],
          subject: fileName,
          text: 'Exported report: $fileName',
        );

        // The file is saved either way; only the SHARE can be dismissed.
        switch (result.status) {
          case ShareResultStatus.success:
            NotificationService.instance.showSuccess(
              'Excel exported and shared',
            );
            break;
          case ShareResultStatus.dismissed:
            NotificationService.instance.showSuccess('Excel exported');
            break;
          case ShareResultStatus.unavailable:
            NotificationService.instance.showSuccess(
              'Excel exported — sharing unavailable',
            );
            break;
        }
      }
    } catch (e, stackTrace) {
      _hideLoading();
      debugPrint('Error exporting to Excel: $e\n$stackTrace');
      NotificationService.instance.showError(
        'Could not export Excel. Please try again.',
      );
    }
  }

  /// Converts every cell to an isolate-safe map. Plain numbers and strings
  /// keep their original `{value, isNum}` shape; ExportMoney / ExportDateTime
  /// add a `kind`, so only callers that opt in get typed cells.
  static Map<String, dynamic> _excelParams({
    required String sheetName,
    required String? title,
    required List<String> headers,
    required List<List<dynamic>> data,
    required Map<String, dynamic>? summary,
  }) {
    final rows = data.map((row) {
      return row.map((cell) {
        if (cell is ExportMoney) {
          return <String, dynamic>{
            'value': cell.value,
            'isNum': false,
            'kind': 'money',
          };
        }
        if (cell is ExportDateTime) {
          return <String, dynamic>{
            'value': cell.value.millisecondsSinceEpoch,
            'isNum': false,
            'kind': 'datetime',
            'fmt': cell.excelFormat,
          };
        }
        if (cell is ExportDate) {
          return <String, dynamic>{
            'value': cell.value.millisecondsSinceEpoch,
            'isNum': false,
            'kind': 'date',
          };
        }
        if (cell is ExportNumber) {
          return <String, dynamic>{
            'value': cell.value,
            'isNum': false,
            'kind': 'number',
            'fmt': cell.excelFormat,
          };
        }
        if (cell is num) {
          return <String, dynamic>{'value': cell, 'isNum': true};
        }
        return <String, dynamic>{
          'value': cell?.toString() ?? '',
          'isNum': false,
        };
      }).toList();
    }).toList();

    List<Map<String, String>>? summaryList;
    if (summary != null) {
      summaryList = summary.entries
          .map((e) => {'key': e.key, 'value': e.value.toString()})
          .toList();
    }

    return <String, dynamic>{
      'sheetName': sheetName,
      'title': title,
      'headers': headers,
      'rows': rows,
      'summary': summaryList,
      'colLetter': _columnLetter(headers.length),
      'moneyFormat': excelMoneyFormat(),
    };
  }

  /// The Excel number format for money: the app's currency symbol and its
  /// decimal places (e.g. `"₹"#,##0.00`). Display only — the cell keeps the
  /// full value.
  static String excelMoneyFormat({String? symbol, int? decimals}) {
    final s = (symbol ?? CurrencyHelper.currentSymbol).replaceAll('"', '');
    final d = decimals ?? DecimalSettings.precision;
    final fraction = d > 0 ? '.${'0' * d}' : '';
    return s.isEmpty ? '#,##0$fraction' : '"$s"#,##0$fraction';
  }

  /// The xlsx bytes [exportToExcel] would produce, built synchronously.
  @visibleForTesting
  static List<int> buildExcelBytesForTesting({
    required List<String> headers,
    required List<List<dynamic>> data,
    String sheetName = 'Report',
    String? title,
    Map<String, dynamic>? summary,
  }) => _buildExcelBytes(
    _excelParams(
      sheetName: sheetName,
      title: title,
      headers: headers,
      data: data,
      summary: summary,
    ),
  );

  // ── PDF Export ──────────────────────────────────────────────────────

  /// Maximum rows in a PDF export. PDF is for printing/sharing —
  /// use Excel for full data dumps.
  static const int _maxPdfRows = 500;

  /// A date cell from stored ISO text, with the purchase reports' exact
  /// rules: missing → '', unreadable → the text itself, otherwise a real
  /// date ([hour24]: date-time) printing `dd MMM yyyy` (`dd MMM yyyy, HH:mm`).
  static Object isoDateCell(String? iso, {bool hour24 = false}) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return hour24 ? ExportDateTime(d, hour24: true) : ExportDate(d);
  }

  /// Maximum PDF rows (read-only, for callers and tests).
  static int get maxPdfRows => _maxPdfRows;

  /// The PDF table text: the first [_maxPdfRows] rows, every cell as the
  /// string the PDF prints. ExportMoney / ExportDateTime print exactly what
  /// formatCurrency / formatDateTime did before.
  static List<List<String>> pdfRows(List<List<dynamic>> data) {
    final rows = data.length > _maxPdfRows
        ? data.sublist(0, _maxPdfRows)
        : data;
    return rows.map((row) => row.map(_pdfText).toList()).toList();
  }

  static String _pdfText(dynamic cell) {
    if (cell is ExportMoney) return formatCurrency(cell.value);
    if (cell is ExportDateTime) {
      final p = cell.pdfPattern ?? (cell.hour24 ? 'dd MMM yyyy, HH:mm' : null);
      return p == null
          ? formatDateTime(cell.value)
          : DateFormat(p).format(cell.value);
    }
    if (cell is ExportDate) return DateFormat(cell.pdfPattern).format(cell.value);
    if (cell is ExportNumber) return cell.value.toStringAsFixed(cell.decimals);
    return cell?.toString() ?? '';
  }

  /// The PDF bytes for already-prepared rows, built synchronously (tests).
  @visibleForTesting
  static Future<Uint8List> buildPdfBytesForTesting({
    required List<String> headers,
    required List<List<dynamic>> data,
    required Uint8List fontBytes,
    required Uint8List fontBoldBytes,
    Map<String, String>? summary,
  }) {
    final format = headers.length > 6
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;
    return _buildPdfBytes(<String, dynamic>{
      'fontBytes': fontBytes,
      'fontBoldBytes': fontBoldBytes,
      'title': 'Test',
      'headers': headers,
      'data': pdfRows(data),
      'summary': summary,
      'pageWidth': format.width,
      'pageHeight': format.height,
      'wasTruncated': data.length > _maxPdfRows,
      'totalRows': data.length,
      'maxPdfRows': _maxPdfRows,
      'generatedAt': 'now',
    });
  }

  /// Export data to PDF format.
  ///
  /// Caps data at [_maxPdfRows] rows to keep generation fast.
  /// All PDF construction (MultiPage, TableHelper, save) runs in a
  /// background isolate via [compute].
  static Future<void> exportToPDF({
    required String fileName,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> data,
    required BuildContext context,
    Map<String, dynamic>? summary,
    PdfPageFormat? pageFormat,
  }) async {
    if (!context.mounted) return;
    _showLoading(context, 'Generating PDF...');

    try {
      final bool wasTruncated = data.length > _maxPdfRows;

      // ── Pre-process on main thread (fast) ────────────────────────────
      // Convert all cells to strings and load font bytes.
      final stringData = pdfRows(data);

      final fontBytes = await loadFontBytes();
      final fontBoldBytes = await loadBoldFontBytes();

      Map<String, String>? summaryMap;
      if (summary != null) {
        summaryMap = summary.map((k, v) => MapEntry(k, v.toString()));
      }

      // A4 portrait leaves 531pt between the margins. Split across the 7-11
      // columns the purchasing reports carry, that is ~50pt a column — about
      // eight characters at 9pt — so supplier names, dates and money all
      // wrapped, and the table read as broken. Landscape gives 778pt, which
      // is the difference between wrapping every row and wrapping none.
      //
      // Only a default: a caller that names its own format (a thermal roll,
      // say) still wins.
      final format =
          pageFormat ??
          (headers.length > 6 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4);

      // ── Run heavy work in isolate ────────────────────────────────────
      final bytes = await compute(_buildPdfBytes, <String, dynamic>{
        'fontBytes': fontBytes,
        'fontBoldBytes': fontBoldBytes,
        'title': title,
        'headers': headers,
        'data': stringData,
        'summary': summaryMap,
        'pageWidth': format.width,
        'pageHeight': format.height,
        'wasTruncated': wasTruncated,
        'totalRows': data.length,
        'maxPdfRows': _maxPdfRows,
        'generatedAt': DateFormat(
          'dd MMM yyyy, hh:mm a',
        ).format(DateTime.now()),
      });

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFileName = '${fileName}_$timestamp.pdf';

      _hideLoading();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fullFileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        _notifyPdfExported(wasTruncated, 'PDF exported');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fullFileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        final result = await Share.shareXFiles(
          [XFile(filePath)],
          subject: fileName,
          text: 'Exported report: $fileName',
        );

        // The file is saved either way; only the SHARE can be dismissed.
        switch (result.status) {
          case ShareResultStatus.success:
            _notifyPdfExported(wasTruncated, 'PDF exported and shared');
            break;
          case ShareResultStatus.dismissed:
            _notifyPdfExported(wasTruncated, 'PDF exported');
            break;
          case ShareResultStatus.unavailable:
            _notifyPdfExported(
              wasTruncated,
              'PDF exported — sharing unavailable',
            );
            break;
        }
      }
    } catch (e, stackTrace) {
      _hideLoading();
      debugPrint('Error exporting to PDF: $e\n$stackTrace');
      NotificationService.instance.showError(
        'Could not export PDF. Please try again.',
      );
    }
  }

  // ── Export Dialog ───────────────────────────────────────────────────

  /// Show export options dialog.
  ///
  /// Uses the parent [context] (not the dialog's builder context)
  /// for export operations, so the context remains valid after the
  /// dialog closes.
  static Future<void> showExportDialog({
    required BuildContext context,
    required String fileName,
    required String reportTitle,
    required List<String> headers,
    required List<List<dynamic>> data,
    Map<String, dynamic>? summary,
  }) async {
    final parentContext = context;

    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                      AppResponsive.dialogWidth(context)) /
                  2)
              .clamp(40.0, double.infinity)
        : 24.0;

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.white,
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — accent badge + title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.file_download_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export Report',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body — format option cards
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose export format',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _exportOptionTile(
                    color: const Color(0xFF1D6F42),
                    icon: Icons.table_chart_rounded,
                    title: 'Export to Excel',
                    subtitle: 'Best for data analysis',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await exportToExcel(
                        fileName: fileName,
                        sheetName: reportTitle,
                        headers: headers,
                        data: data,
                        context: parentContext,
                        title: reportTitle,
                        summary: summary,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _exportOptionTile(
                    color: const Color(0xFFD32F2F),
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Export to PDF',
                    subtitle: 'Best for printing & sharing',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await exportToPDF(
                        fileName: fileName,
                        title: reportTitle,
                        headers: headers,
                        data: data,
                        context: parentContext,
                        summary: summary,
                      );
                    },
                  ),
                ],
              ),
            ),
            // Cancel — full-width outlined
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ranged export (All / Current page / Date range) ────────────────

  /// The records an export covers, always a subset of [items] — the screen's
  /// already-filtered list, so no screen filter is ever bypassed.
  ///
  /// * all — [items] itself (no copy).
  /// * page — the [page]th block of [rowsPerPage] (zero-based), as on screen.
  /// * dateRange — whole days [from]..[to] inclusive, by [dateOf]; records
  ///   without a date are left out.
  static List<T> selectForExport<T>(
    List<T> items, {
    required ExportScope scope,
    int page = 0,
    int rowsPerPage = 50,
    DateTime? from,
    DateTime? to,
    DateTime? Function(T item)? dateOf,
  }) {
    switch (scope) {
      case ExportScope.all:
        return items;
      case ExportScope.page:
        return items.skip(page * rowsPerPage).take(rowsPerPage).toList();
      case ExportScope.dateRange:
        if (from == null || to == null || dateOf == null) return items;
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day + 1);
        return items.where((item) {
          final d = dateOf(item);
          return d != null && !d.isBefore(start) && d.isBefore(end);
        }).toList();
    }
  }

  /// Export dialog for the transaction-level reports: All filtered records
  /// (default), Current page only, or a Custom date range inside the current
  /// filter, then Excel or PDF.
  ///
  /// The same selected list feeds the count shown, [summaryOf], the Excel
  /// rows and the PDF rows, so the file's summary always matches its rows.
  static Future<void> showRangedExportDialog<T>({
    required BuildContext context,
    required String fileName,
    required String reportTitle,
    required List<String> headers,
    required List<T> items,
    List<dynamic> Function(T item)? rowOf,
    required DateTime? Function(T item) dateOf,
    Map<String, dynamic> Function(List<T> rows)? summaryOf,
    // Alternative to rowOf + summaryOf, for reports that already build their
    // rows and summary together from a list (ReportPageScaffold.exportData).
    ({List<List<dynamic>> data, Map<String, dynamic> summary}) Function(
            List<T> rows)?
        exportOf,
    required int currentPage,
    required int rowsPerPage,
    String unit = 'records',
    String dateLabel = 'Date',
  }) async {
    assert(
      exportOf != null || (rowOf != null && summaryOf != null),
      'Pass exportOf, or both rowOf and summaryOf',
    );
    final parentContext = context;
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                      AppResponsive.dialogWidth(context)) /
                  2)
              .clamp(40.0, double.infinity)
        : 24.0;

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.white,
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: RangedExportPanel<T>(
          items: items,
          dateOf: dateOf,
          currentPage: currentPage,
          rowsPerPage: rowsPerPage,
          unit: unit,
          dateLabel: dateLabel,
          onCancel: () => Navigator.pop(dialogContext),
          onExport: (selection, excel) async {
            Navigator.pop(dialogContext);
            final rows = selection.rows;
            final label = selection.label;
            final title = label == null ? reportTitle : '$reportTitle ($label)';
            final built = buildExportFor(
              rows,
              label: label,
              unit: unit,
              rowOf: rowOf,
              summaryOf: summaryOf,
              exportOf: exportOf,
            );
            final summary = built.summary;
            final data = built.data;
            final name = '$fileName${selection.fileSuffix}';
            if (excel) {
              await exportToExcel(
                fileName: name,
                sheetName: reportTitle,
                headers: headers,
                data: data,
                context: parentContext,
                title: title,
                summary: summary,
              );
            } else {
              await exportToPDF(
                fileName: name,
                title: title,
                headers: headers,
                data: data,
                context: parentContext,
                summary: summary,
              );
            }
          },
        ),
      ),
    );
  }

  /// The file's rows and summary for the selected records: one list feeds
  /// both, so the summary always describes exactly the rows exported. A
  /// non-All selection adds an "Exported" line first.
  static ({List<List<dynamic>> data, Map<String, dynamic> summary})
      buildExportFor<T>(
    List<T> rows, {
    required String? label,
    required String unit,
    List<dynamic> Function(T item)? rowOf,
    Map<String, dynamic> Function(List<T> rows)? summaryOf,
    ({List<List<dynamic>> data, Map<String, dynamic> summary}) Function(
            List<T> rows)?
        exportOf,
  }) {
    final built = exportOf != null
        ? exportOf(rows)
        : (data: rows.map(rowOf!).toList(), summary: summaryOf!(rows));
    return (
      data: built.data,
      summary: <String, dynamic>{
        if (label != null) 'Exported': '$label (${rows.length} $unit)',
        ...built.summary,
      },
    );
  }

  /// A tappable export-format card (Excel / PDF). Disabled when [onTap] is
  /// null.
  static Widget _exportOptionTile({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Convert column index to Excel column letter (0=A, 1=B, etc.)
  static String _columnLetter(int index) {
    String result = '';
    while (index >= 0) {
      result = String.fromCharCode(65 + (index % 26)) + result;
      index = (index ~/ 26) - 1;
    }
    return result;
  }

  /// Format currency value for export
  static String formatCurrency(num value) {
    return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(value.toDouble())}';
  }

  /// Format date for export
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// Format date with time for export
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RANGED EXPORT PANEL
// ═══════════════════════════════════════════════════════════════════════

/// What the user chose in [RangedExportPanel]: the records to export, a
/// label for the title/summary (null for "All"), and a file-name suffix.
class ExportSelection<T> {
  final List<T> rows;
  final String? label;
  final String fileSuffix;
  const ExportSelection(this.rows, this.label, this.fileSuffix);
}

/// Body of [ReportExportService.showRangedExportDialog]: scope choice, live
/// count, then the Excel / PDF cards (disabled when nothing is selected).
class RangedExportPanel<T> extends StatefulWidget {
  final List<T> items;
  final DateTime? Function(T item) dateOf;
  final int currentPage;
  final int rowsPerPage;
  final String unit;
  final String dateLabel;
  final VoidCallback onCancel;
  final void Function(ExportSelection<T> selection, bool excel) onExport;

  const RangedExportPanel({
    super.key,
    required this.items,
    required this.dateOf,
    required this.currentPage,
    required this.rowsPerPage,
    required this.unit,
    required this.dateLabel,
    required this.onCancel,
    required this.onExport,
  });

  @override
  State<RangedExportPanel<T>> createState() => _RangedExportPanelState<T>();
}

class _RangedExportPanelState<T> extends State<RangedExportPanel<T>> {
  ExportScope _scope = ExportScope.all;
  DateTime? _firstDay;
  DateTime? _lastDay;
  DateTimeRange? _range;

  static final _dayFormat = DateFormat('dd MMM yyyy');
  static final _fileDayFormat = DateFormat('ddMMMyyyy');

  @override
  void initState() {
    super.initState();
    // One pass for the picker bounds: the dates present in the filtered list.
    for (final item in widget.items) {
      final d = widget.dateOf(item);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (_firstDay == null || day.isBefore(_firstDay!)) _firstDay = day;
      if (_lastDay == null || day.isAfter(_lastDay!)) _lastDay = day;
    }
  }

  bool get _hasPages => widget.items.length > widget.rowsPerPage;

  ({int start, int end}) get _pageRows {
    final start = widget.currentPage * widget.rowsPerPage;
    final end = (start + widget.rowsPerPage).clamp(0, widget.items.length);
    return (start: start + 1, end: end);
  }

  ExportSelection<T> get _selection {
    switch (_scope) {
      case ExportScope.all:
        return ExportSelection(widget.items, null, '');
      case ExportScope.page:
        final r = _pageRows;
        final page = widget.currentPage + 1;
        return ExportSelection(
          ReportExportService.selectForExport(
            widget.items,
            scope: ExportScope.page,
            page: widget.currentPage,
            rowsPerPage: widget.rowsPerPage,
          ),
          'Page $page (rows ${r.start}–${r.end})',
          '_page$page',
        );
      case ExportScope.dateRange:
        final range = _range;
        if (range == null) return ExportSelection(<T>[], null, '');
        final from = _dayFormat.format(range.start);
        final to = _dayFormat.format(range.end);
        return ExportSelection(
          ReportExportService.selectForExport(
            widget.items,
            scope: ExportScope.dateRange,
            from: range.start,
            to: range.end,
            dateOf: widget.dateOf,
          ),
          from == to ? from : '$from – $to',
          '_${_fileDayFormat.format(range.start)}-${_fileDayFormat.format(range.end)}',
        );
    }
  }

  Future<void> _pickRange() async {
    if (_firstDay == null || _lastDay == null) return;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _firstDay!,
      lastDate: _lastDay!,
      initialDateRange:
          _range ?? DateTimeRange(start: _firstDay!, end: _lastDay!),
    );
    if (picked != null && mounted) {
      setState(() {
        _range = picked;
        _scope = ExportScope.dateRange;
      });
    }
  }

  void _choose(ExportScope? scope) {
    if (scope == null) return;
    setState(() {
      _scope = scope;
      // First time: start with the whole filtered span, then let them narrow.
      if (scope == ExportScope.dateRange && _range == null) {
        _range = DateTimeRange(start: _firstDay!, end: _lastDay!);
      }
    });
    if (scope == ExportScope.dateRange) _pickRange();
  }

  /// One choice: radio + label, with [below] (e.g. the date range) on its
  /// own line under the label, so neither gets squeezed on a phone.
  Widget _option(ExportScope scope, String title, {Widget? below}) {
    return InkWell(
      onTap: () => _choose(scope),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<ExportScope>(value: scope, activeColor: AppColors.primary),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (below != null)
            Padding(
              // Lines up with the label text (radio width).
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: below,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    final count = selection.rows.length;
    final r = _pageRows;
    final canExport = count > 0;
    final rangeText = _range == null
        ? 'Pick dates'
        : '${_dayFormat.format(_range!.start)} – ${_dayFormat.format(_range!.end)}';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Report',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
            child: RadioGroup<ExportScope>(
              groupValue: _scope,
              onChanged: _choose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      'What to export',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _option(
                    ExportScope.all,
                    'All filtered ${widget.unit} (${widget.items.length})',
                  ),
                  if (_hasPages)
                    _option(
                      ExportScope.page,
                      'Current page only (rows ${r.start}–${r.end})',
                    ),
                  if (_firstDay != null)
                    _option(
                      ExportScope.dateRange,
                      'Custom ${widget.dateLabel.toLowerCase()} range',
                      below: OutlinedButton.icon(
                        key: const Key('exportRangeButton'),
                        onPressed: _pickRange,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          rangeText,
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                    child: Text(
                      canExport
                          ? 'Exporting $count ${widget.unit}'
                          : 'No ${widget.unit} in this range',
                      key: const Key('exportCount'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: canExport ? AppColors.primary : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              children: [
                ReportExportService._exportOptionTile(
                  color: const Color(0xFF1D6F42),
                  icon: Icons.table_chart_rounded,
                  title: 'Export to Excel',
                  subtitle: 'Best for data analysis',
                  onTap: canExport
                      ? () => widget.onExport(selection, true)
                      : null,
                ),
                const SizedBox(height: 12),
                ReportExportService._exportOptionTile(
                  color: const Color(0xFFD32F2F),
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Export to PDF',
                  subtitle: count > ReportExportService.maxPdfRows
                      ? 'First ${ReportExportService.maxPdfRows} rows · use Excel for all'
                      : 'Best for printing & sharing',
                  onTap: canExport
                      ? () => widget.onExport(selection, false)
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
