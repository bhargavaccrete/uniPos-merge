/// Sending a rendered receipt PDF to a Windows PDF/document printer.
///
/// This is the counterpart to the RAW ESC/POS spooler path, NOT a replacement
/// for it. A thermal printer wants raw control codes; a PDF writer (doPDF,
/// Microsoft Print to PDF) wants a rendered document and silently discards
/// control codes. Which one is used is decided by the printer's `type`
/// (`'windows'` vs `'windows_pdf'`) — never by inspecting the printer's name.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Sends a pre-rendered PDF to a named Windows print queue.
typedef WindowsPdfSender = Future<bool> Function({
  required String queueName,
  required List<int> pdfBytes,
  required PdfPageFormat format,
  required String jobName,
});

/// `printing`'s Windows backend writes the page size into
/// `DEVMODE.dmPaperWidth/dmPaperLength`, which are C `short`s holding TENTHS of
/// a millimetre — so 32767 tenths = 3276.7 mm is the hard ceiling.
const double maxWindowsPageMm = 3276.7;

/// Height used only when the generated document cannot be measured. Anything
/// finite is better than the `double.infinity` the thermal page format carries:
/// `static_cast<short>(round(inf))` is undefined behaviour in the plugin.
const double _fallbackHeightMm = 297.0;

/// Resolve the concrete page size to hand the Windows printer configuration.
///
/// The thermal page format is authored as `80mm x double.infinity` so the
/// receipt can grow with its content. That value must never reach Windows, so
/// this takes the measured page size where available and falls back to the
/// nominal paper width otherwise. Pure, so every edge is unit-testable.
PdfPageFormat resolveThermalPageFormat({
  double? pageWidthPt,
  double? pageHeightPt,
  required int paperWidth,
}) {
  final fallbackWidth = (paperWidth <= 58 ? 58.0 : 80.0) * PdfPageFormat.mm;
  final maxPt = maxWindowsPageMm * PdfPageFormat.mm;

  bool usable(double? v) => v != null && v.isFinite && v > 0;

  var width = usable(pageWidthPt) ? pageWidthPt! : fallbackWidth;
  var height =
      usable(pageHeightPt) ? pageHeightPt! : _fallbackHeightMm * PdfPageFormat.mm;

  if (width > maxPt) width = maxPt;
  if (height > maxPt) height = maxPt;

  return PdfPageFormat(width, height, marginAll: 0);
}

/// Measure the first page of an already-built document.
///
/// Page sizes are only concrete after `save()` has laid the document out, so
/// call this afterwards. Any failure falls back to the nominal paper width.
PdfPageFormat thermalPageFormatOf(pw.Document pdf, int paperWidth) {
  double? width;
  double? height;
  try {
    final pages = pdf.document.pdfPageList.pages;
    if (pages.isNotEmpty) {
      width = pages.first.pageFormat.width;
      height = pages.first.pageFormat.height;
    }
  } catch (_) {
    // Measurement is best-effort; resolve* handles nulls.
  }
  return resolveThermalPageFormat(
    pageWidthPt: width,
    pageHeightPt: height,
    paperWidth: paperWidth,
  );
}

/// Real sender: hands the PDF to the Windows printing API for [queueName].
///
/// [queueName] is passed through whole — Windows queue names may contain a
/// colon ('Printer on SERVER:2').
Future<bool> platformWindowsPdfSend({
  required String queueName,
  required List<int> pdfBytes,
  required PdfPageFormat format,
  required String jobName,
}) async {
  final bytes = Uint8List.fromList(pdfBytes);
  return await Printing.directPrintPdf(
    printer: Printer(url: queueName, name: queueName),
    onLayout: (_) async => bytes,
    name: jobName,
    format: format,
    // false → use the custom page size above rather than the driver's default
    // (which would be A4 on most PDF writers).
    usePrinterSettings: false,
  );
}
