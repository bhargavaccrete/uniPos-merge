/// Vertical allocation for ONE barcode/price label.
///
/// A 38.1 x 21.2 mm sticker is about 108 x 60 PDF points. At that size a
/// flow layout (`Column` + `Expanded`) cannot be trusted: a name one word longer
/// silently steals the barcode's height, and the price ends up sitting on the
/// bars. So the label is planned before it is drawn — every section is given an
/// explicit height here, and the renderer only fills the boxes it is handed.
///
/// Two consequences worth knowing:
/// * **Sections cannot collide.** The renderer never sizes anything itself, so
///   the only way two sections can overlap is if the arithmetic below is wrong,
///   and that is unit-testable without a PDF.
/// * **The barcode is protected.** When content grows, the secondary text
///   shrinks and the name wraps; the bars keep at least [LabelMetrics.minBars].
///
/// Pure Dart on purpose — no `pdf`, no Flutter — so the whole layout can be
/// asserted in tests. Text width comes in through [LabelTextMeasurer], which
/// production wires to the real font metrics and tests wire to a stub.
library;

import 'dart:math' as math;

/// How much room one line of text needs, in points.
class LabelTextSize {
  final double width;

  /// The **ink box** — what the PDF writer actually advances a line by, not the
  /// font's nominal line height. Measured, because for Poppins it runs from
  /// ~0.71 em (`SKU: 6109`) to ~1.25 em (bold, with accents and descenders); a
  /// single assumed factor is simultaneously too tight for one and wasteful for
  /// the other.
  final double height;

  const LabelTextSize(this.width, this.height);

  static const LabelTextSize zero = LabelTextSize(0, 0);
}

/// Measures [text] as it would be drawn, in points.
typedef LabelTextMeasurer = LabelTextSize Function(
  String text, {
  required double fontSize,
  required bool bold,
});

const double kPtPerMm = 72.0 / 25.4;

/// Padding inside the die-cut edge. The horizontal value doubles as the start
/// of the barcode's quiet zone.
const double kLabelPadH = 3.0;
const double kLabelPadV = 1.8;

/// White space each side of the bars, on top of [kLabelPadH]. Code 128 wants
/// ~10 module widths; 3 + 4 pt gets close on a label this narrow, and the
/// 2.5 mm gutter between columns adds more on the sheet.
const double kBarcodeQuietH = 4.0;

/// Breathing room added to a measured line, as a multiple of font size.
///
/// The measurement is the ink box, which touches the glyphs. This is what keeps
/// consecutive lines from looking welded together.
const double kLineLeading = 0.22;

/// Floor for a line box, as a multiple of font size, so a line of short glyphs
/// (`SKU: 12`) still gets a sensible slot instead of a cramped one.
const double kMinLineFactor = 0.95;

/// A font size that shrinks as the label fills up.
class LabelFontRange {
  /// Used when there is room to spare.
  final double max;

  /// Never smaller than this, however tight the label gets.
  final double min;

  const LabelFontRange(this.max, this.min);

  /// [t] 0 = roomy, 1 = fully compressed.
  double at(double t) {
    final c = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    return max - (max - min) * c;
  }
}

/// Every tunable number for the label, in one place.
///
/// Sizes are PDF points. They are small because the label is small: 5.8 pt is
/// legible in print, and the alternative to small type is a clipped name.
class LabelMetrics {
  /// Product name. Shrinks first because it is the section most likely to be
  /// long, and a slightly smaller name beats a wrapped one.
  static const LabelFontRange name = LabelFontRange(5.8, 4.6);

  /// Brand — secondary, sits with the product it belongs to.
  static const LabelFontRange brand = LabelFontRange(4.2, 3.6);

  /// Variant descriptor. Ranked above brand visually: it is what the staff
  /// member is looking for on the shelf.
  static const LabelFontRange variant = LabelFontRange(4.8, 4.1);

  /// What the shop charges. The loudest thing on the label after the bars.
  static const LabelFontRange price = LabelFontRange(6.4, 5.2);

  /// Struck-through MRP beside it.
  static const LabelFontRange mrp = LabelFontRange(4.7, 4.1);

  /// Human-readable barcode, keyed in by hand when a scanner gives up, so it
  /// has a high floor.
  static const LabelFontRange value = LabelFontRange(5.0, 4.4);

  /// Shop-internal code, printed under the barcode value. Reference data, so
  /// it sits at the quietest weight on the label — it must never be mistaken
  /// for the barcode itself.
  static const LabelFontRange sku = LabelFontRange(3.9, 3.4);

  /// Protected whitespace between the price row and the bars. The reason the
  /// price can no longer touch the barcode.
  static const double gapAboveMax = 3.2;
  static const double gapAboveMin = 1.8;

  /// Quiet zone under the bars, before the human-readable value.
  static const double quietGap = 1.5;

  /// The barcode floor: ~6.0 mm of bars. Below this a phone camera starts to
  /// struggle, so content shrinks instead.
  static const double minBars = 17.0;

  /// The ceiling. Slack beyond this is better spent as whitespace than on
  /// bars tall enough to look like a mistake.
  static const double maxBars = 26.0;

  /// A long name may take a second line. Never a third — that is a price tag,
  /// not a paragraph.
  static const int maxNameLines = 2;

  /// Absolute floor for a one-line field that still will not fit its width.
  static const double hardFloor = 3.2;

  /// Steps in the shrink cascade. Ten is finer than the eye can see at this
  /// size and keeps the search cheap.
  static const int compressionSteps = 10;
}

/// The text a label has to show. Empty string means "this label has none",
/// which is how a section gets zero height rather than an empty gap.
class LabelContent {
  final String name;
  final String brand;
  final String variant;

  /// e.g. `MRP ₹2000.00` — empty when there is no MRP to print.
  final String mrpText;

  /// e.g. `PRICE ₹1500.00` — empty when the shop charges the MRP.
  final String priceText;

  /// The human-readable barcode: the ENCODED value and nothing else.
  ///
  /// An SKU never stands in for it — an unlabelled code under the bars reads as
  /// the barcode. Empty for a variant that has none.
  final String barcodeValue;

  /// Shown in the barcode's place when [barcodeValue] is empty.
  final String barcodeFallback;

  /// e.g. `SKU: TS-BLU-L` — the shop's own code, always labelled so it cannot
  /// be read as the barcode value above it.
  final String skuText;

  const LabelContent({
    required this.name,
    this.brand = '',
    this.variant = '',
    this.mrpText = '',
    this.priceText = '',
    this.barcodeValue = '',
    this.barcodeFallback = '',
    this.skuText = '',
  });
}

/// One line of text, the size it fits at, and the box height it needs.
class FittedLine {
  final String text;
  final double fontSize;

  /// Reserved height, measured rather than assumed. Zero when there is nothing
  /// to draw, which is how an absent field costs no space at all.
  final double height;

  const FittedLine(this.text, this.fontSize, this.height);

  /// An absent field.
  static const FittedLine none = FittedLine('', 0, 0);

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => text.isNotEmpty;
}

/// A fully resolved label: what to draw, at what size, in a box of what height.
///
/// The renderer reads this and makes no layout decisions of its own.
class LabelPlan {
  /// One or two lines, already wrapped to the label width.
  final List<FittedLine> nameLines;

  final FittedLine brand;
  final FittedLine variant;

  /// Left of the price row. Struck through when [priceText] is present.
  final FittedLine mrp;

  /// Right of the price row, or the only entry when there is no MRP.
  final FittedLine price;

  /// Whitespace between the price row and the bars.
  final double gapAbove;

  /// Height of the bars themselves — never the bars plus their text.
  final double barsHeight;

  /// Quiet zone under the bars.
  final double quietGap;

  final FittedLine value;
  final FittedLine sku;

  /// Slack pushed to the bottom so a sparse label reads as balanced rather
  /// than top-heavy.
  final double padBottom;

  /// The box the sections were allocated in, inside the label's padding.
  final double contentWidth;
  final double contentHeight;

  /// True when this label had no barcode and [LabelContent.barcodeFallback]
  /// fills the reserved area instead.
  final bool barcodeMissing;

  const LabelPlan({
    required this.nameLines,
    required this.brand,
    required this.variant,
    required this.mrp,
    required this.price,
    required this.gapAbove,
    required this.barsHeight,
    required this.quietGap,
    required this.value,
    required this.sku,
    required this.padBottom,
    required this.contentWidth,
    required this.contentHeight,
    required this.barcodeMissing,
  });

  double get nameHeight =>
      nameLines.fold(0.0, (sum, line) => sum + line.height);

  double get priceHeight => math.max(mrp.height, price.height);

  /// Everything the plan asks for, top to bottom.
  double get usedHeight =>
      nameHeight +
      brand.height +
      variant.height +
      priceHeight +
      gapAbove +
      barsHeight +
      quietGap +
      value.height +
      sku.height +
      padBottom;

  /// The single invariant worth testing: the label fits its own sticker.
  bool get fits => usedHeight <= contentHeight + 0.01;

  /// Width available to the bars, after the quiet zone.
  double get barsWidth => contentWidth - 2 * kBarcodeQuietH;

  /// Both prices side by side, as opposed to one centred figure.
  bool get hasPriceRow => mrp.isNotEmpty && price.isNotEmpty;

  bool get hasPrice => mrp.isNotEmpty || price.isNotEmpty;
}

/// Turns [LabelContent] into a [LabelPlan] for a label of a given size.
class LabelPlanner {
  const LabelPlanner._();

  /// Plan one label.
  ///
  /// [widthPt] / [heightPt] are the label's full size; the padding is taken off
  /// here so callers deal in sticker dimensions.
  ///
  /// The search is deliberately simple: try the roomiest set of sizes, and if
  /// the bars come out under [LabelMetrics.minBars], compress the type a notch
  /// and try again. That ordering is the policy — **text yields to the
  /// barcode**, never the other way round.
  static LabelPlan plan({
    required LabelContent content,
    required double widthPt,
    required double heightPt,
    required LabelTextMeasurer measure,
  }) {
    final contentWidth = widthPt - 2 * kLabelPadH;
    final contentHeight = heightPt - 2 * kLabelPadV;

    for (var step = 0; step <= LabelMetrics.compressionSteps; step++) {
      final t = step / LabelMetrics.compressionSteps;
      final attempt = _attempt(
        content: content,
        contentWidth: contentWidth,
        contentHeight: contentHeight,
        t: t,
        maxNameLines: LabelMetrics.maxNameLines,
        measure: measure,
      );
      if (attempt.barsHeight >= LabelMetrics.minBars) return _balance(attempt);
    }

    // Fully compressed and still short: give the name a single line. Only
    // reachable on a label far smaller than the one V1 supports, but it means
    // the method has no failure mode that overflows the sticker.
    return _balance(_attempt(
      content: content,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      t: 1.0,
      maxNameLines: 1,
      measure: measure,
    ));
  }

  static LabelPlan _attempt({
    required LabelContent content,
    required double contentWidth,
    required double contentHeight,
    required double t,
    required int maxNameLines,
    required LabelTextMeasurer measure,
  }) {
    final nameSize = LabelMetrics.name.at(t);
    final nameLines = _wrap(
      content.name,
      maxWidth: contentWidth,
      fontSize: nameSize,
      bold: true,
      maxLines: maxNameLines,
      measure: measure,
    )
        .map((line) => _measured(line, nameSize, true, measure))
        .toList(growable: false);

    final brand = _fitOneLine(
      content.brand,
      maxWidth: contentWidth,
      fontSize: LabelMetrics.brand.at(t),
      floor: LabelMetrics.brand.min,
      bold: false,
      measure: measure,
    );
    final variant = _fitOneLine(
      content.variant,
      maxWidth: contentWidth,
      fontSize: LabelMetrics.variant.at(t),
      floor: LabelMetrics.variant.min,
      bold: true,
      measure: measure,
    );

    final (mrp, price) = _fitPriceRow(
      mrpText: content.mrpText,
      priceText: content.priceText,
      maxWidth: contentWidth,
      t: t,
      measure: measure,
    );

    final value = _fitOneLine(
      content.barcodeValue,
      maxWidth: contentWidth,
      fontSize: LabelMetrics.value.at(t),
      floor: LabelMetrics.value.min,
      bold: false,
      measure: measure,
    );
    final sku = _fitOneLine(
      content.skuText,
      maxWidth: contentWidth,
      fontSize: LabelMetrics.sku.at(t),
      floor: LabelMetrics.sku.min,
      bold: false,
      measure: measure,
    );

    final gapAbove = LabelMetrics.gapAboveMax -
        (LabelMetrics.gapAboveMax - LabelMetrics.gapAboveMin) * t;

    final nameHeight = nameLines.fold(0.0, (sum, line) => sum + line.height);
    final priceHeight = math.max(mrp.height, price.height);
    final quietGap = value.isEmpty ? 0.0 : LabelMetrics.quietGap;

    final fixed = nameHeight +
        brand.height +
        variant.height +
        priceHeight +
        gapAbove +
        quietGap +
        value.height +
        sku.height;

    return LabelPlan(
      nameLines: nameLines,
      brand: brand,
      variant: variant,
      mrp: mrp,
      price: price,
      gapAbove: gapAbove,
      barsHeight: math.max(0.0, contentHeight - fixed),
      quietGap: quietGap,
      value: value,
      sku: sku,
      padBottom: 0,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      barcodeMissing: content.barcodeValue.isEmpty,
    );
  }

  /// Cap the bars and spend the leftover as whitespace: a little more above the
  /// barcode, the rest at the foot of the label.
  static LabelPlan _balance(LabelPlan plan) {
    if (plan.barsHeight <= LabelMetrics.maxBars) return plan;

    final slack = plan.barsHeight - LabelMetrics.maxBars;
    return LabelPlan(
      nameLines: plan.nameLines,
      brand: plan.brand,
      variant: plan.variant,
      mrp: plan.mrp,
      price: plan.price,
      gapAbove: plan.gapAbove + slack * 0.55,
      barsHeight: LabelMetrics.maxBars,
      quietGap: plan.quietGap,
      value: plan.value,
      sku: plan.sku,
      padBottom: slack * 0.45,
      contentWidth: plan.contentWidth,
      contentHeight: plan.contentHeight,
      barcodeMissing: plan.barcodeMissing,
    );
  }

  /// MRP and selling price on one row, shrunk together until they fit.
  ///
  /// Shrinking both by the same factor keeps the price dominant — the point of
  /// the row is that the two figures are comparable at a glance.
  static (FittedLine, FittedLine) _fitPriceRow({
    required String mrpText,
    required String priceText,
    required double maxWidth,
    required double t,
    required LabelTextMeasurer measure,
  }) {
    final mrpBase = LabelMetrics.mrp.at(t);
    final priceBase = LabelMetrics.price.at(t);

    if (mrpText.isEmpty && priceText.isEmpty) {
      return (FittedLine.none, FittedLine.none);
    }
    if (mrpText.isEmpty) {
      return (
        FittedLine.none,
        _fitOneLine(priceText,
            maxWidth: maxWidth,
            fontSize: priceBase,
            floor: LabelMetrics.price.min,
            bold: true,
            measure: measure),
      );
    }
    if (priceText.isEmpty) {
      // MRP only: it is the price, so it gets the price treatment.
      return (
        _fitOneLine(mrpText,
            maxWidth: maxWidth,
            fontSize: priceBase,
            floor: LabelMetrics.price.min,
            bold: true,
            measure: measure),
        FittedLine.none,
      );
    }

    // Both present. 4 pt keeps them from reading as one number.
    const double gap = 4.0;
    final mrpWidth = measure(mrpText, fontSize: mrpBase, bold: false).width;
    final priceWidth =
        measure(priceText, fontSize: priceBase, bold: true).width;
    final total = mrpWidth + gap + priceWidth;

    var scale = 1.0;
    if (total > maxWidth && total > 0) {
      scale = (maxWidth - gap) / (mrpWidth + priceWidth);
      final floorScale = LabelMetrics.price.min / priceBase;
      if (scale < floorScale) scale = floorScale;
      if (scale > 1) scale = 1.0;
    }

    return (
      _fitOneLine(mrpText,
          maxWidth: maxWidth,
          fontSize: mrpBase * scale,
          floor: LabelMetrics.hardFloor,
          bold: false,
          measure: measure),
      _fitOneLine(priceText,
          maxWidth: maxWidth,
          fontSize: priceBase * scale,
          floor: LabelMetrics.hardFloor,
          bold: true,
          measure: measure),
    );
  }

  /// Fit [text] on one line: shrink to [floor], then trim with an ellipsis.
  ///
  /// Trimming is the last resort and, at these widths, effectively unreachable
  /// for real product data — but it is what guarantees no text ever crosses the
  /// die-cut edge.
  static FittedLine _fitOneLine(
    String text, {
    required double maxWidth,
    required double fontSize,
    required double floor,
    required bool bold,
    required LabelTextMeasurer measure,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return FittedLine.none;

    var size = fontSize;
    final width = measure(trimmed, fontSize: size, bold: bold).width;
    if (width > maxWidth && width > 0) {
      size = size * (maxWidth / width);
      if (size < floor) size = floor;
      if (size > fontSize) size = fontSize;
    }

    if (measure(trimmed, fontSize: size, bold: bold).width <= maxWidth) {
      return _measured(trimmed, size, bold, measure);
    }
    return _measured(
      _ellipsize(trimmed,
          maxWidth: maxWidth, fontSize: size, bold: bold, measure: measure),
      size,
      bold,
      measure,
    );
  }

  /// Wrap a measured line in its box height: the ink box plus leading, and
  /// never less than [kMinLineFactor] of the font size.
  static FittedLine _measured(
    String text,
    double fontSize,
    bool bold,
    LabelTextMeasurer measure,
  ) {
    if (text.isEmpty) return FittedLine.none;
    final ink = measure(text, fontSize: fontSize, bold: bold).height;
    final height = math.max(
      ink + fontSize * kLineLeading,
      fontSize * kMinLineFactor,
    );
    return FittedLine(text, fontSize, height);
  }

  /// Greedy word wrap, up to [maxLines].
  ///
  /// A word longer than the line is broken by character rather than allowed to
  /// run off the sticker — the case that produced the clipped names.
  static List<String> _wrap(
    String text, {
    required double maxWidth,
    required double fontSize,
    required bool bold,
    required int maxLines,
    required LabelTextMeasurer measure,
  }) {
    final source = text.trim();
    if (source.isEmpty) return const [''];

    double widthOf(String s) =>
        measure(s, fontSize: fontSize, bold: bold).width;

    final words = source.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    void flush() {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
    }

    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      if (word.isEmpty) continue;

      final candidate = current.isEmpty ? word : '$current $word';
      if (widthOf(candidate) <= maxWidth) {
        current = candidate;
        continue;
      }

      // Does not fit beside what we have. Start a new line if we can.
      if (current.isNotEmpty && lines.length + 1 < maxLines) {
        flush();
      } else if (current.isNotEmpty) {
        // Last allowed line is already busy: everything left has to be
        // squeezed onto it.
        final rest = words.sublist(i).join(' ');
        lines.add(_ellipsize('$current $rest',
            maxWidth: maxWidth,
            fontSize: fontSize,
            bold: bold,
            measure: measure));
        current = '';
        return lines;
      }

      // The word alone may still be too wide.
      if (widthOf(word) <= maxWidth) {
        current = word;
        continue;
      }

      // Break the oversized word by character across the lines left to us.
      while (word.isNotEmpty) {
        final isLastLine = lines.length + 1 >= maxLines;
        final head = _longestPrefix(word,
            maxWidth: maxWidth,
            fontSize: fontSize,
            bold: bold,
            measure: measure);
        if (head.isEmpty) break; // Nothing fits at all; stop rather than spin.
        final tail = word.substring(head.length);
        if (isLastLine) {
          final rest = [tail, ...words.sublist(i + 1)].join(' ').trim();
          lines.add(rest.isEmpty
              ? head
              : _ellipsize(head,
                  maxWidth: maxWidth,
                  fontSize: fontSize,
                  bold: bold,
                  measure: measure,
                  forceEllipsis: true));
          return lines;
        }
        lines.add(head);
        word = tail;
      }
      current = '';
    }

    flush();
    return lines.isEmpty ? const [''] : lines;
  }

  /// Longest prefix of [text] that fits [maxWidth].
  static String _longestPrefix(
    String text, {
    required double maxWidth,
    required double fontSize,
    required bool bold,
    required LabelTextMeasurer measure,
  }) {
    var lo = 0;
    var hi = text.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (measure(text.substring(0, mid), fontSize: fontSize, bold: bold)
              .width <=
          maxWidth) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return text.substring(0, lo);
  }

  /// Trim [text] until it fits, ending in `...`.
  ///
  /// ASCII dots, not U+2026: the built-in Helvetica fallback cannot draw the
  /// single-glyph ellipsis and would leave a hollow box.
  static String _ellipsize(
    String text, {
    required double maxWidth,
    required double fontSize,
    required bool bold,
    required LabelTextMeasurer measure,
    bool forceEllipsis = false,
  }) {
    const suffix = '...';
    if (!forceEllipsis &&
        measure(text, fontSize: fontSize, bold: bold).width <= maxWidth) {
      return text;
    }
    for (var end = text.length; end > 0; end--) {
      final candidate = '${text.substring(0, end).trimRight()}$suffix';
      if (measure(candidate, fontSize: fontSize, bold: bold).width <=
          maxWidth) {
        return candidate;
      }
    }
    return suffix;
  }
}
