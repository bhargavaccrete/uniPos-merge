import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:billberrylite/domain/services/common/windows_spooler/windows_pdf_output.dart';

/// The page size handed to Windows decides whether doPDF emits a true 58/80mm
/// receipt or drops it onto A4.
///
/// The hard rule: `double.infinity` must never get through. The thermal receipt
/// is authored as `80mm x double.infinity` so it can grow with its content, but
/// `printing`'s Windows backend does
/// `static_cast<short>(round(height * 254 / 72))` — and casting infinity to a
/// C `short` is undefined behaviour.
///
/// Driver limits measured on a real machine (2026-09-15):
///   doPDF 11               10 x 10 mm  →  3276 x 3276 mm
///   Microsoft Print to PDF 50.8 x 85 mm → 917 x 1297 mm
void main() {
  double mmOf(double points) => points / PdfPageFormat.mm;

  group('paper width', () {
    test('80mm receipt falls back to an 80mm page', () {
      final f = resolveThermalPageFormat(paperWidth: 80);
      expect(mmOf(f.width), closeTo(80, 0.01));
    });

    test('58mm receipt falls back to a 58mm page', () {
      final f = resolveThermalPageFormat(paperWidth: 58);
      expect(mmOf(f.width), closeTo(58, 0.01));
    });

    test('a measured width from the document wins over the nominal width', () {
      final f = resolveThermalPageFormat(
        pageWidthPt: 80 * PdfPageFormat.mm,
        pageHeightPt: 200 * PdfPageFormat.mm,
        paperWidth: 58,
      );
      expect(mmOf(f.width), closeTo(80, 0.01));
      expect(mmOf(f.height), closeTo(200, 0.01));
    });
  });

  group('infinity never reaches Windows', () {
    test('an infinite height is replaced with a finite one', () {
      final f = resolveThermalPageFormat(
        pageWidthPt: 80 * PdfPageFormat.mm,
        pageHeightPt: double.infinity,
        paperWidth: 80,
      );
      expect(f.height.isFinite, isTrue);
      expect(f.height, greaterThan(0));
    });

    test('an infinite width is replaced with the nominal paper width', () {
      final f = resolveThermalPageFormat(
        pageWidthPt: double.infinity,
        paperWidth: 58,
      );
      expect(f.width.isFinite, isTrue);
      expect(mmOf(f.width), closeTo(58, 0.01));
    });

    test('NaN and non-positive sizes are rejected too', () {
      for (final bad in [double.nan, 0.0, -10.0]) {
        final f = resolveThermalPageFormat(
          pageWidthPt: bad,
          pageHeightPt: bad,
          paperWidth: 80,
        );
        expect(f.width.isFinite && f.width > 0, isTrue, reason: 'width for $bad');
        expect(f.height.isFinite && f.height > 0, isTrue,
            reason: 'height for $bad');
      }
    });

    test('an unmeasurable document still yields a usable page', () {
      final f = resolveThermalPageFormat(paperWidth: 80);
      expect(f.width.isFinite, isTrue);
      expect(f.height.isFinite, isTrue);
    });
  });

  group("Windows' short-typed page limit", () {
    test('an over-long receipt is clamped to the 3276.7mm ceiling', () {
      // dmPaperLength is a C short: 32767 tenths of a mm. Anything larger would
      // overflow into a nonsense page size.
      final f = resolveThermalPageFormat(
        pageWidthPt: 80 * PdfPageFormat.mm,
        pageHeightPt: 5000 * PdfPageFormat.mm,
        paperWidth: 80,
      );
      expect(mmOf(f.height), lessThanOrEqualTo(maxWindowsPageMm));
    });

    test('a realistic receipt height passes through untouched', () {
      final f = resolveThermalPageFormat(
        pageWidthPt: 80 * PdfPageFormat.mm,
        pageHeightPt: 300 * PdfPageFormat.mm,
        paperWidth: 80,
      );
      expect(mmOf(f.height), closeTo(300, 0.01));
    });
  });

  group('fits the probed driver ranges', () {
    test('58mm and 80mm sit inside doPDF and Print-to-PDF custom ranges', () {
      for (final paper in [58, 80]) {
        final w = mmOf(resolveThermalPageFormat(paperWidth: paper).width);
        // doPDF: 10..3276mm — Microsoft Print to PDF: 50.8..917mm
        expect(w, greaterThanOrEqualTo(50.8),
            reason: '${paper}mm must clear the Print-to-PDF minimum');
        expect(w, lessThanOrEqualTo(917));
      }
    });
  });
}
