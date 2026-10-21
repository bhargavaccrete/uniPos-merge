import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/label_layouts.dart';
import '../../../util/common/currency_helper.dart';
import '../../../util/common/decimal_settings.dart';
import 'label_layout_plan.dart';

/// Cut-guide ink.
///
/// Dark grey, and **solid**. The first attempt was a light dashed hairline,
/// which is the conventional "crop mark" look and was effectively invisible:
/// at preview resolution a 0.4 pt grey500 dash is about one anti-aliased pixel
/// and disappears into the paper. A guide you cannot see is worse than none.
const PdfColor kCutGuideColor = PdfColors.grey700;

/// Thin enough to cut down the middle of without leaving grey on either piece,
/// thick enough to survive rasterisation at any preview or printer DPI.
const double kCutGuideWidth = 0.5;

/// One label's worth of resolved text.
///
/// Deliberately a plain value class rather than a `VarianteModel`: the layout
/// arithmetic and the content rules are then unit-testable without Hive, and the
/// caller owns the decision of what each field should say.
class LabelSpec {
  /// Product name. Always printed.
  final String productName;

  /// "L / Blue", "50ml", "Pack of 12" — empty when the variant has no
  /// descriptors (a single-variant Gift & General product, say).
  final String variantDescriptor;

  /// The barcode VALUE. Empty means this variant has none, in which case the
  /// label prints without a barcode block rather than failing.
  final String barcode;

  /// Printed maximum price. Always shown when present.
  final double? mrp;

  /// What the shop actually charges. Shown ONLY when lower than [mrp] — equal or
  /// higher is noise, and higher should not exist.
  final double? sellingPrice;

  final String? brand;
  final String? sku;

  const LabelSpec({
    required this.productName,
    this.variantDescriptor = '',
    this.barcode = '',
    this.mrp,
    this.sellingPrice,
    this.brand,
    this.sku,
  });

  bool get hasBarcode => barcode.trim().isNotEmpty;

  /// Show the selling price only when it undercuts the MRP.
  bool get showsSellingPrice {
    final m = mrp;
    final s = sellingPrice;
    return m != null && s != null && m > 0 && s > 0 && s < m;
  }
}

/// Builds the A4 sticker sheet of barcode/price labels.
///
/// Kept separate from `ReceiptPdfService` on purpose: receipt layout is dense,
/// heavily conditional and already long, and a label shares nothing with it
/// beyond the `pdf` package.
///
/// **Read-only.** Nothing here touches a variant. A label is a rendering of what
/// the catalogue already says — if printing could write a barcode, reprinting a
/// sheet would mint a new value and orphan every label already on the stock.
///
/// Layout is decided by [LabelPlanner] before anything is drawn; see
/// `label_layout_plan.dart` for why. This class only fills the boxes the plan
/// hands it, which is what keeps the price off the barcode.
class LabelPdfService {
  /// The single supported layout. See [LabelLayout] for why there is only one.
  final LabelLayout layout;

  const LabelPdfService({this.layout = kLabelLayout65Up});

  /// Poppins, cached across sheets. Same family as receipts and invoices, and —
  /// unlike the built-in Helvetica — it can actually draw the rupee sign, which
  /// the Latin-1-only Type 1 fonts render as a hollow box.
  static pw.Font? _baseFont;
  static pw.Font? _boldFont;

  /// Expand per-variant copy counts into a flat list of labels to print.
  ///
  /// Order is preserved and copies are contiguous, so a sheet reads
  /// variant-by-variant rather than interleaved. A count of zero or less
  /// contributes nothing.
  static List<LabelSpec> expand(List<(LabelSpec, int)> requests) {
    final out = <LabelSpec>[];
    for (final (spec, copies) in requests) {
      for (var i = 0; i < copies; i++) {
        out.add(spec);
      }
    }
    return out;
  }

  /// Sheets needed for [labelCount] labels, so the UI can warn before a
  /// part-used sheet is wasted.
  int pagesFor(int labelCount) => layout.pagesFor(labelCount);

  /// Render [labels] onto as many A4 sheets as needed.
  ///
  /// Every label is positioned absolutely from the layout's margins and pitch
  /// rather than by flow layout, because a die-cut sheet is unforgiving: a
  /// fraction of a millimetre of drift compounds across 13 rows.
  ///
  /// [cutGuides] draws the cut grid described in [_cutGuides]. On by default
  /// because most shops print onto plain A4 and cut; it is turned OFF for a
  /// real die-cut sticker sheet, where the lines would print across the
  /// stickers themselves.
  Future<pw.Document> build(
    List<LabelSpec> labels, {
    bool cutGuides = true,
  }) async {
    final doc = pw.Document();
    if (labels.isEmpty) return doc;

    final (baseFont, boldFont) = await _fonts();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

    final perPage = layout.perPage;
    for (var start = 0; start < labels.length; start += perPage) {
      final end =
          (start + perPage) < labels.length ? start + perPage : labels.length;
      final pageLabels = labels.sublist(start, end);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          // Margins live in the layout and are applied per label below.
          margin: pw.EdgeInsets.zero,
          build: (context) {
            // Text width has to come from the font actually being used, so the
            // measurer is built here where a PDF context exists.
            final measure = _measurer(context, baseFont, boldFont);
            return pw.Stack(
              children: [
                // First, so the labels always draw over the guides.
                if (cutGuides) _cutGuides(pageLabels.length),
                for (var i = 0; i < pageLabels.length; i++)
                  _positioned(pageLabels[i], i, measure),
              ],
            );
          },
        ),
      );
    }
    return doc;
  }

  /// Poppins if the asset loads, the built-in Helvetica if it does not. A
  /// missing font must degrade to a plainer sheet, never to no sheet.
  Future<(pw.Font, pw.Font)> _fonts() async {
    final cachedBase = _baseFont;
    final cachedBold = _boldFont;
    if (cachedBase != null && cachedBold != null) {
      return (cachedBase, cachedBold);
    }
    try {
      final base =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
      final bold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
      _baseFont = base;
      _boldFont = bold;
      return (base, bold);
    } catch (e) {
      print('Label fonts unavailable, falling back to Helvetica: $e');
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  /// Measures text with the real font metrics of the sheet's own fonts.
  ///
  /// Falls back to a per-character estimate if the font cannot report on a
  /// glyph — the Type 1 fallback throws on anything outside Latin-1, and a
  /// currency symbol must not be able to break the layout.
  LabelTextMeasurer _measurer(
    pw.Context context,
    pw.Font baseFont,
    pw.Font boldFont,
  ) {
    final pdfBase = baseFont.getFont(context);
    final pdfBold = boldFont.getFont(context);

    return (String text, {required double fontSize, required bool bold}) {
      if (text.isEmpty) return LabelTextSize.zero;
      final font = bold ? pdfBold : pdfBase;
      try {
        final metrics = font.stringMetrics(text);
        return LabelTextSize(
          math.max(metrics.advanceWidth, metrics.right) * fontSize,
          // The ink box, which is exactly what the writer advances a line by.
          metrics.height * fontSize,
        );
      } catch (_) {
        // 0.62 em per character is wider than Poppins' real average, and 1.25 em
        // is its tallest measured line, so an estimate errs towards wrapping
        // early and over-reserving rather than overflowing.
        return LabelTextSize(text.length * 0.62 * fontSize, 1.25 * fontSize);
      }
    };
  }

  /// The grid the shop cuts along: a solid vertical line between every column
  /// and a solid horizontal line between every row, drawn under the labels.
  ///
  /// One layer per page rather than a border per label, for two reasons:
  /// * **One cut per boundary.** The lines sit in the middle of the 2.5 mm
  ///   gutter, so a trimmer separates two columns in a single pass. Per-label
  ///   borders would put two lines 2.5 mm apart and leave a sliver between them.
  /// * **It ends where the labels end.** Only the rows actually used are ruled,
  ///   so a sheet of three labels is three boxes, not a grid of 65.
  ///
  /// No line can ever cross a barcode: every one of them lands on a gutter
  /// midpoint or a shared row edge, both of which are outside the label's own
  /// padding.
  ///
  /// Drawn straight onto the canvas rather than as widgets: one path of ~19
  /// segments replaces the several hundred boxes a widget grid would need.
  pw.Widget _cutGuides(int labelsOnPage) {
    final rowsUsed = layout.rowsUsedFor(labelsOnPage);
    if (rowsUsed <= 0) return pw.SizedBox();

    final xs = layout.cutXsMm();
    final ys = layout.cutYsMm(rowsUsed);
    final pageWidth = kA4WidthMm * PdfPageFormat.mm;
    final pageHeight = kA4HeightMm * PdfPageFormat.mm;

    return pw.Positioned(
      left: 0,
      top: 0,
      child: pw.SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: pw.CustomPaint(
          size: PdfPoint(pageWidth, pageHeight),
          painter: (canvas, size) {
            // The canvas origin is the box's BOTTOM-left; the layout measures
            // from the top, as the rest of this file does.
            double x(double mm) => mm * PdfPageFormat.mm;
            double y(double mm) => size.y - mm * PdfPageFormat.mm;

            canvas
              ..setStrokeColor(kCutGuideColor)
              ..setLineWidth(kCutGuideWidth);

            for (final vx in xs) {
              canvas
                ..moveTo(x(vx), y(ys.first))
                ..lineTo(x(vx), y(ys.last));
            }
            for (final hy in ys) {
              canvas
                ..moveTo(x(xs.first), y(hy))
                ..lineTo(x(xs.last), y(hy));
            }
            canvas.strokePath();
          },
        ),
      ),
    );
  }

  /// One label placed at grid slot [index], filling left-to-right then down.
  pw.Widget _positioned(LabelSpec spec, int index, LabelTextMeasurer measure) {
    final col = index % layout.columns;
    final row = index ~/ layout.columns;

    return pw.Positioned(
      left:
          (layout.marginLeftMm + col * layout.columnPitchMm) * PdfPageFormat.mm,
      top: (layout.marginTopMm + row * layout.rowPitchMm) * PdfPageFormat.mm,
      child: pw.SizedBox(
        width: layout.labelWidthMm * PdfPageFormat.mm,
        height: layout.labelHeightMm * PdfPageFormat.mm,
        child: _label(spec, measure),
      ),
    );
  }

  /// A single 38 x 21 mm label, drawn from its plan.
  ///
  /// Reading order top to bottom: product, brand, variant, price, protected
  /// whitespace, bars, the human-readable value, SKU. Every one of those is a
  /// fixed-height box, so none of them can grow into its neighbour.
  pw.Widget _label(LabelSpec spec, LabelTextMeasurer measure) {
    final plan = LabelPlanner.plan(
      content: contentFor(spec),
      widthPt: layout.labelWidthMm * PdfPageFormat.mm,
      heightPt: layout.labelHeightMm * PdfPageFormat.mm,
      measure: measure,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: kLabelPadH,
        vertical: kLabelPadV,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          for (final line in plan.nameLines)
            _textBox(line, bold: true, color: PdfColors.black),
          _textBox(plan.brand, bold: false, color: PdfColors.grey700),
          _textBox(plan.variant, bold: true, color: PdfColors.grey800),
          _priceRow(plan),
          pw.SizedBox(height: plan.gapAbove),
          _barcodeBox(spec, plan),
          pw.SizedBox(height: plan.quietGap),
          _textBox(plan.value, bold: false, color: PdfColors.black),
          _textBox(plan.sku, bold: false, color: PdfColors.grey700),
          pw.SizedBox(height: plan.padBottom),
        ],
      ),
    );
  }

  /// One planned line in a box of exactly its planned height.
  pw.Widget _textBox(
    FittedLine line, {
    required bool bold,
    required PdfColor color,
    bool strikeThrough = false,
  }) {
    if (line.isEmpty) return pw.SizedBox(height: 0);
    return pw.SizedBox(
      height: line.height,
      child: pw.Center(
        child: pw.Text(
          line.text,
          maxLines: 1,
          softWrap: false,
          overflow: pw.TextOverflow.clip,
          textAlign: pw.TextAlign.center,
          // The planner allocates the INK box. Without this the widget sizes
          // itself by the font's own ascent/descent (1.40 em for Poppins) and
          // gets clipped inside its own allocation.
          tightBounds: true,
          style: pw.TextStyle(
            fontSize: line.fontSize,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            decoration:
                strikeThrough ? pw.TextDecoration.lineThrough : pw.TextDecoration.none,
          ),
        ),
      ),
    );
  }

  /// MRP and selling price side by side, or one figure on its own.
  ///
  /// Never a cost price, a supplier price, or a transaction-specific override —
  /// those must not leave the building on a sticker.
  pw.Widget _priceRow(LabelPlan plan) {
    if (!plan.hasPrice) return pw.SizedBox(height: 0);

    if (!plan.hasPriceRow) {
      final only = plan.mrp.isNotEmpty ? plan.mrp : plan.price;
      return _textBox(only, bold: true, color: PdfColors.black);
    }

    return pw.SizedBox(
      height: plan.priceHeight,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            plan.mrp.text,
            maxLines: 1,
            softWrap: false,
            tightBounds: true,
            style: pw.TextStyle(
              fontSize: plan.mrp.fontSize,
              color: PdfColors.grey700,
              decoration: pw.TextDecoration.lineThrough,
            ),
          ),
          // Matches the 4 pt the planner budgeted between the two figures.
          pw.SizedBox(width: 4),
          pw.Text(
            plan.price.text,
            maxLines: 1,
            softWrap: false,
            tightBounds: true,
            style: pw.TextStyle(
              fontSize: plan.price.fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// The bars, in the height the plan reserved for them and nothing else.
  ///
  /// [kBarcodeQuietH] each side is the quiet zone; without it the first bar
  /// starts at the sticker's own text margin and a scanner can miss the start
  /// pattern.
  pw.Widget _barcodeBox(LabelSpec spec, LabelPlan plan) {
    if (plan.barcodeMissing) {
      final fallback = contentFor(spec).barcodeFallback;
      return pw.SizedBox(
        height: plan.barsHeight,
        child: pw.Center(
          child: pw.Text(
            fallback,
            maxLines: 1,
            tightBounds: true,
            style: const pw.TextStyle(
              fontSize: 4.6,
              color: PdfColors.grey600,
            ),
          ),
        ),
      );
    }

    return pw.SizedBox(
      height: plan.barsHeight,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: kBarcodeQuietH),
        child: pw.BarcodeWidget(
          // Code 128: alphanumeric, no check digit, no GS1 prefix, and it
          // cannot collide with a manufacturer EAN.
          barcode: pw.Barcode.code128(),
          data: spec.barcode.trim(),
          // The value is drawn by the label itself, below the quiet zone, so
          // the height reserved here is bars only.
          drawText: false,
          width: plan.barsWidth,
          height: plan.barsHeight,
        ),
      ),
    );
  }

  /// What each section of a label should say.
  ///
  /// Public for tests: the content rules (which fields appear, and the MRP /
  /// selling-price relationship) are worth asserting without building a PDF.
  static LabelContent contentFor(LabelSpec spec) {
    final mrp = spec.mrp;
    final selling = spec.sellingPrice;

    var mrpText = '';
    var priceText = '';
    if (mrp != null && mrp > 0) {
      mrpText = 'MRP ${money(mrp)}';
      if (spec.showsSellingPrice) {
        priceText = 'PRICE ${money(selling!)}';
      }
    } else if (selling != null && selling > 0) {
      priceText = 'PRICE ${money(selling)}';
    }

    final sku = spec.sku?.trim() ?? '';

    return LabelContent(
      name: spec.productName.trim(),
      brand: spec.brand?.trim() ?? '',
      variant: spec.variantDescriptor.trim(),
      mrpText: mrpText,
      priceText: priceText,
      // The human-readable line under the bars is the ENCODED VALUE and
      // nothing else. The SKU has its own labelled line below it; a shop code
      // sitting unlabelled under a barcode reads as the barcode.
      barcodeValue: spec.hasBarcode ? spec.barcode.trim() : '',
      barcodeFallback: 'no barcode',
      skuText: sku.isEmpty ? '' : 'SKU: $sku',
    );
  }

  /// Currency using the store's own symbol and decimal precision, matching every
  /// other printed figure.
  static String money(double amount) {
    final precision = DecimalSettings.precision;
    return '${CurrencyHelper.currentSymbol}${amount.toStringAsFixed(precision)}';
  }
}
