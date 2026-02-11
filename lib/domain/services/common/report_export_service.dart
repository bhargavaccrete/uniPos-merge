import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:universal_html/html.dart' as html;

/// Comprehensive Report Export Service
///
/// Supports:
/// - Excel export (works on all platforms including web)
/// - PDF export (works on all platforms including web)
/// - CSV export (works on all platforms including web)
///
/// Usage:
/// ```dart
/// await ReportExportService.exportToExcel(
///   fileName: 'sales_report',
///   sheetName: 'Sales Data',
///   headers: ['Date', 'Order #', 'Amount'],
///   data: [
///     ['2024-01-01', '001', '₹500.00'],
///     ['2024-01-02', '002', '₹750.00'],
///   ],
///   context: context,
/// );
/// ```
class ReportExportService {
  /// Export data to Excel format
  ///
  /// Works on mobile, tablet, and web platforms
  static Future<void> exportToExcel({
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> data,
    required BuildContext context,
    String? title,
    Map<String, dynamic>? summary,
  }) async {
    try {
      // Create Excel workbook
      final excel = Excel.createExcel();

      // Create our custom sheet (if it doesn't exist, it will be created)
      final sheet = excel[sheetName];

      // Delete the default "Sheet1" that comes with new workbooks
      if (excel.tables.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      int currentRow = 0;

      // Add title if provided
      if (title != null) {
        sheet.merge(
          CellIndex.indexByString('A1'),
          CellIndex.indexByString('${_columnLetter(headers.length)}1'),
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

      // Add summary if provided
      if (summary != null) {
        currentRow++;
        for (var entry in summary.entries) {
          final keyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
          keyCell.value = TextCellValue(entry.key);
          keyCell.cellStyle = CellStyle(bold: true);

          final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
          valueCell.value = TextCellValue(entry.value.toString());

          currentRow++;
        }
        currentRow++;
      }

      // Add headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.blue,
          fontColorHex: ExcelColor.white,
        );
      }
      currentRow++;

      // Add data rows
      for (var row in data) {
        for (int i = 0; i < row.length; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
          final value = row[i];

          if (value is num) {
            cell.value = DoubleCellValue(value.toDouble());
          } else {
            cell.value = TextCellValue(value?.toString() ?? '');
          }
        }
        currentRow++;
      }

      // Auto-fit columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // Save and download
      final fileBytes = excel.encode()!;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFileName = '${fileName}_$timestamp.xlsx';

      if (kIsWeb) {
        // Web platform - download file
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fullFileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel file downloaded: $fullFileName')),
          );
        }
      } else {
        // Mobile/Desktop platform - save to downloads and share
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fullFileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Share the file
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
      print('❌ Error exporting to Excel: $e');
      print('Stack trace: $stackTrace');

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

  /// Export data to PDF format
  ///
  /// Works on mobile, tablet, and web platforms
  static Future<void> exportToPDF({
    required String fileName,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> data,
    required BuildContext context,
    Map<String, dynamic>? summary,
    PdfPageFormat? pageFormat,
  }) async {
    try {
      final pdf = pw.Document();
      final format = pageFormat ?? PdfPageFormat.a4;

      // Load a font that supports currency symbols
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
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

              // Generated date
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 20),

              // Summary section
              if (summary != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: summary.entries.map((entry) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              entry.key,
                              style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(entry.value.toString(), style: pw.TextStyle(font: font)),
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
                data: data.map((row) => row.map((cell) => cell?.toString() ?? '').toList()).toList(),
                headerStyle: pw.TextStyle(
                  font: fontBold,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue,
                ),
                cellHeight: 30,
                cellAlignments: {
                  for (int i = 0; i < headers.length; i++)
                    i: i == headers.length - 1
                        ? pw.Alignment.centerRight
                        : pw.Alignment.centerLeft,
                },
              ),
            ];
          },
        ),
      );

      // Save and download
      final bytes = await pdf.save();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFileName = '${fileName}_$timestamp.pdf';

      if (kIsWeb) {
        // Web platform - download file
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fullFileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF downloaded: $fullFileName')),
          );
        }
      } else {
        // Mobile/Desktop - show print preview and share
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: fullFileName,
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error exporting to PDF: $e');
      print('Stack trace: $stackTrace');

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

  /// Show export options dialog
  ///
  /// Presents user with choice between Excel and PDF export
  static Future<void> showExportDialog({
    required BuildContext context,
    required String fileName,
    required String reportTitle,
    required List<String> headers,
    required List<List<dynamic>> data,
    Map<String, dynamic>? summary,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export to Excel'),
              subtitle: const Text('Best for data analysis'),
              onTap: () async {
                Navigator.pop(context);
                await exportToExcel(
                  fileName: fileName,
                  sheetName: reportTitle,
                  headers: headers,
                  data: data,
                  context: context,
                  title: reportTitle,
                  summary: summary,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export to PDF'),
              subtitle: const Text('Best for printing & sharing'),
              onTap: () async {
                Navigator.pop(context);
                await exportToPDF(
                  fileName: fileName,
                  title: reportTitle,
                  headers: headers,
                  data: data,
                  context: context,
                  summary: summary,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Helper: Convert column index to Excel column letter (0=A, 1=B, etc.)
  static String _columnLetter(int index) {
    String result = '';
    while (index >= 0) {
      result = String.fromCharCode(65 + (index % 26)) + result;
      index = (index ~/ 26) - 1;
    }
    return result;
  }

  /// Helper: Format currency value for export
  static String formatCurrency(num value) {
    return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(value.toDouble())}';
  }

  /// Helper: Format date for export
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// Helper: Format date with time for export
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }
}