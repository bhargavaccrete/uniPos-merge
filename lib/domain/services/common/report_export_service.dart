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
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:universal_html/html.dart' as html;
import 'package:unipos/util/color.dart';

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
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.orange),
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
                      pw.Text(entry.key,
                          style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold)),
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
          cellHeight: 25,
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
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      keyCell.value = TextCellValue(m['key'] as String);
      keyCell.cellStyle = CellStyle(bold: true);

      final valueCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      valueCell.value = TextCellValue(m['value'] as String);
      currentRow++;
    }
    currentRow++;
  }

  // Headers
  for (int i = 0; i < colCount; i++) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
    cell.value = TextCellValue(headers[i]);
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
  }
  currentRow++;

  // Data rows
  for (final rawRow in rawRows) {
    final row = rawRow as List;
    for (int i = 0; i < row.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
      final item = row[i] as Map;
      if (item['isNum'] == true) {
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

  // ── Font byte cache ─────────────────────────────────────────────────
  // Loaded once from bundled assets (no network). Stored as raw Uint8List
  // so they can be passed efficiently to compute() isolates.
  static Uint8List? _fontBytes;
  static Uint8List? _fontBoldBytes;

  static Future<Uint8List> _loadFontBytes() async {
    if (_fontBytes == null) {
      final data = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
      _fontBytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }
    return _fontBytes!;
  }

  static Future<Uint8List> _loadBoldFontBytes() async {
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
      // Convert every cell to an isolate-safe map {value, isNum}.
      // This avoids sending arbitrary dynamic types across the isolate.
      final rows = data.map((row) {
        return row.map((cell) {
          if (cell is num) {
            return <String, dynamic>{'value': cell, 'isNum': true};
          }
          return <String, dynamic>{'value': cell?.toString() ?? '', 'isNum': false};
        }).toList();
      }).toList();

      List<Map<String, String>>? summaryList;
      if (summary != null) {
        summaryList = summary.entries
            .map((e) => {'key': e.key, 'value': e.value.toString()})
            .toList();
      }

      // ── Run heavy work in isolate ────────────────────────────────────
      final fileBytes = await compute(_buildExcelBytes, <String, dynamic>{
        'sheetName': sheetName,
        'title': title,
        'headers': headers,
        'rows': rows,
        'summary': summaryList,
        'colLetter': _columnLetter(headers.length),
      });

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFileName = '${fileName}_$timestamp.xlsx';

      _hideLoading();

      if (kIsWeb) {
        final blob = html.Blob(
          [fileBytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fullFileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel file downloaded: $fullFileName')),
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fullFileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          subject: fileName,
          text: 'Exported report: $fileName',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel file saved and shared: $fullFileName')),
          );
        }
      }
    } catch (e, stackTrace) {
      _hideLoading();
      debugPrint('Error exporting to Excel: $e\n$stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── PDF Export ──────────────────────────────────────────────────────

  /// Maximum rows in a PDF export. PDF is for printing/sharing —
  /// use Excel for full data dumps.
  static const int _maxPdfRows = 500;

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
      final exportData = wasTruncated ? data.sublist(0, _maxPdfRows) : data;

      // ── Pre-process on main thread (fast) ────────────────────────────
      // Convert all cells to strings and load font bytes.
      final stringData = exportData
          .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
          .toList();

      final fontBytes = await _loadFontBytes();
      final fontBoldBytes = await _loadBoldFontBytes();

      Map<String, String>? summaryMap;
      if (summary != null) {
        summaryMap = summary.map((k, v) => MapEntry(k, v.toString()));
      }

      final format = pageFormat ?? PdfPageFormat.a4;

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
        'generatedAt': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
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

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF downloaded: $fullFileName')),
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fullFileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          subject: fileName,
          text: 'Exported report: $fileName',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(wasTruncated
                  ? 'PDF exported (first $_maxPdfRows rows). Use Excel for full data.'
                  : 'PDF exported: $fullFileName'),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _hideLoading();
      debugPrint('Error exporting to PDF: $e\n$stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.file_download_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Export Report',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose export format:',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: Text('Export to Excel',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Best for data analysis',
                  style: GoogleFonts.poppins(fontSize: 12)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Export to PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Best for printing & sharing',
                  style: GoogleFonts.poppins(fontSize: 12)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
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