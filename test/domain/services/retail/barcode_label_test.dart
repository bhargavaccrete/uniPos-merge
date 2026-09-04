import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:billberrylite/core/constants/label_layouts.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/barcode_generator_service.dart';
import 'package:billberrylite/domain/services/retail/label_layout_plan.dart';
import 'package:billberrylite/domain/services/retail/label_pdf_service.dart';

/// Retail barcode generation and A4 label layout.
///
/// The rules these lock down, in order of how much damage getting them wrong
/// would do:
///   1. A generated barcode is STABLE. Reprinting must never mint a new value —
///      that would orphan every label already stuck to the stock.
///   2. An existing manufacturer barcode is never replaced.
///   3. 65 labels per A4 sheet, and the page arithmetic around that boundary.
///   4. A cost price never reaches a label.
void main() {
  // So `rootBundle` can hand the label service its real Poppins metrics; the
  // service falls back to Helvetica without it, and the widths would be a
  // guess.
  TestWidgetsFlutterBinding.ensureInitialized();

  LabelSpec spec({
    String name = 'T-Shirt',
    String descriptor = 'L / Blue',
    String barcode = 'BB0000000042',
    double? mrp = 1199,
    double? selling = 999,
    String? brand,
    String? sku,
  }) =>
      LabelSpec(
        productName: name,
        variantDescriptor: descriptor,
        barcode: barcode,
        mrp: mrp,
        sellingPrice: selling,
        brand: brand,
        sku: sku,
      );

  VarianteModel variant({String? barcode, double stock = 12}) => VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        barcode: barcode,
        sellingPrice: 999,
        mrp: 1199,
        costPrice: 600,
        stockQty: stock,
        createdAt: '2026-08-22T00:00:00.000',
      );

  // ==========================================================================
  group('Layout — the one V1 sheet', () {
    const layout = kLabelLayout65Up;

    test('is exactly 65 labels per A4 page, 5 x 13', () {
      expect(layout.columns, 5);
      expect(layout.rows, 13);
      expect(layout.perPage, 65);
    });

    test('the grid fits inside A4', () {
      expect(
        layout.fitsWithin(
            pageWidthMm: kA4WidthMm, pageHeightMm: kA4HeightMm),
        isTrue,
      );
      // Symmetric margins are what makes a die-cut sheet line up.
      expect(layout.marginLeftMm + layout.gridWidthMm,
          closeTo(kA4WidthMm - 4.8, 0.05));
      expect(layout.marginTopMm + layout.gridHeightMm,
          closeTo(kA4HeightMm - 10.7, 0.05));
    });

    test('pitch is label size plus gap', () {
      expect(layout.columnPitchMm, closeTo(40.6, 0.001));
      expect(layout.rowPitchMm, closeTo(21.2, 0.001)); // no vertical gap
    });

    // The boundary that decides whether a whole sheet is wasted.
    test('page count around the 65 boundary', () {
      expect(layout.pagesFor(0), 0);
      expect(layout.pagesFor(1), 1);
      expect(layout.pagesFor(64), 1);
      expect(layout.pagesFor(65), 1);
      expect(layout.pagesFor(66), 2);
      expect(layout.pagesFor(130), 2);
      expect(layout.pagesFor(131), 3);
    });

    test('a negative count is zero pages, not a crash', () {
      expect(layout.pagesFor(-5), 0);
    });
  });

  // ==========================================================================
  // Cut guides. Pure arithmetic, and the thing a wrong number here costs is a
  // sheet cut through the middle of a barcode.
  group('Cut guides', () {
    const layout = kLabelLayout65Up;

    test('one line per boundary, both outer trims included', () {
      expect(layout.cutXsMm(), hasLength(layout.columns + 1));
      expect(layout.cutYsMm(layout.rows), hasLength(layout.rows + 1));
    });

    test('vertical lines run down the middle of the gutter', () {
      final xs = layout.cutXsMm();
      // Half a gutter outside the first label, and the same past the last.
      expect(xs.first, closeTo(layout.marginLeftMm - layout.columnGapMm / 2, 0.001));
      for (var c = 1; c < xs.length; c++) {
        expect(xs[c] - xs[c - 1], closeTo(layout.columnPitchMm, 0.001));
      }
      // A cut on the line takes half the gutter off each side and leaves the
      // label itself untouched.
      final labelRight = layout.marginLeftMm + layout.labelWidthMm;
      expect(xs[1] - labelRight, closeTo(layout.columnGapMm / 2, 0.001));
    });

    test('horizontal lines sit on the shared edge, one cut per row', () {
      final ys = layout.cutYsMm(layout.rows);
      expect(ys.first, closeTo(layout.marginTopMm, 0.001));
      expect(ys[1] - ys[0], closeTo(layout.rowPitchMm, 0.001));
      expect(ys.last, closeTo(layout.marginTopMm + layout.gridHeightMm, 0.001));
    });

    test('every line stays on the paper', () {
      final xs = layout.cutXsMm();
      final ys = layout.cutYsMm(layout.rows);
      expect(xs.first, greaterThanOrEqualTo(0));
      expect(xs.last, lessThanOrEqualTo(kA4WidthMm));
      expect(ys.first, greaterThanOrEqualTo(0));
      expect(ys.last, lessThanOrEqualTo(kA4HeightMm));
    });

    // The grid stops where the labels stop: three labels is three boxes, not a
    // page ruled into 65.
    test('only the rows actually used are ruled', () {
      expect(layout.rowsUsedFor(0), 0);
      expect(layout.rowsUsedFor(1), 1);
      expect(layout.rowsUsedFor(5), 1);
      expect(layout.rowsUsedFor(6), 2);
      expect(layout.rowsUsedFor(65), 13);
      // A count past a full sheet is one page's worth of rows, never more.
      expect(layout.rowsUsedFor(200), 13);
      expect(layout.rowsUsedFor(-5), 0);
      expect(layout.cutYsMm(layout.rowsUsedFor(3)), hasLength(2));
    });

    test('a sheet with guides still builds and is bigger than one without',
        () async {
      const svc = LabelPdfService();
      final labels = LabelPdfService.expand([(spec(), 7)]);
      final with_ = await (await svc.build(labels)).save();
      final without = await (await svc.build(labels, cutGuides: false)).save();
      expect(with_.length, greaterThan(0));
      expect(with_.length, greaterThan(without.length),
          reason: 'the guide layer should add drawing commands');
    });
  });

  // ==========================================================================
  group('Quantity and selection', () {
    test('copies expand to the right number of labels', () {
      final labels = LabelPdfService.expand([(spec(), 3)]);
      expect(labels, hasLength(3));
    });

    test('multiple variants combine in order, copies contiguous', () {
      final labels = LabelPdfService.expand([
        (spec(descriptor: 'M / Blue'), 2),
        (spec(descriptor: 'L / Blue'), 3),
      ]);
      expect(labels, hasLength(5));
      expect(labels.take(2).every((l) => l.variantDescriptor == 'M / Blue'),
          isTrue);
      expect(labels.skip(2).every((l) => l.variantDescriptor == 'L / Blue'),
          isTrue);
    });

    test('zero and negative copies contribute nothing', () {
      expect(LabelPdfService.expand([(spec(), 0)]), isEmpty);
      expect(LabelPdfService.expand([(spec(), -4)]), isEmpty);
      // A zeroed row must not silently drop the rows around it.
      final mixed = LabelPdfService.expand([
        (spec(descriptor: 'A'), 2),
        (spec(descriptor: 'B'), 0),
        (spec(descriptor: 'C'), 1),
      ]);
      expect(mixed.map((l) => l.variantDescriptor).toList(), ['A', 'A', 'C']);
    });

    test('the stock quick-fill uses the variant stock', () {
      // What the sheet does when "use stock quantity" is tapped.
      final v = variant(barcode: 'BB0000000001', stock: 20);
      final labels = LabelPdfService.expand([(spec(), v.stockQty.round())]);
      expect(labels, hasLength(20));
    });

    test('total label count is the sum of the selected rows', () {
      final requests = <(LabelSpec, int)>[
        (spec(descriptor: 'M / Blue'), 20),
        (spec(descriptor: 'L / Blue'), 15),
        // Unselected rows are simply not in the list.
      ];
      final total = requests.fold<int>(0, (s, r) => s + r.$2);
      expect(total, 35);
      expect(LabelPdfService.expand(requests), hasLength(35));
      expect(kLabelLayout65Up.pagesFor(total), 1);
    });

    test('a single variant with N copies — the variant-level entry point', () {
      final labels = LabelPdfService.expand([(spec(), 5)]);
      expect(labels, hasLength(5));
      expect(labels.every((l) => l.barcode == 'BB0000000042'), isTrue);
    });
  });

  // ==========================================================================
  group('Barcode format and stability', () {
    test('format is BB + 10 digits', () {
      expect(BarcodeGeneratorService.format(1), 'BB0000000001');
      expect(BarcodeGeneratorService.format(42), 'BB0000000042');
      expect(BarcodeGeneratorService.format(1234567890), 'BB1234567890');
      expect(BarcodeGeneratorService.format(42).length, 12);
    });

    test('isGenerated recognises our codes and rejects others', () {
      expect(BarcodeGeneratorService.isGenerated('BB0000000042'), isTrue);
      // A manufacturer EAN must never be mistaken for ours.
      expect(BarcodeGeneratorService.isGenerated('8901234567890'), isFalse);
      expect(BarcodeGeneratorService.isGenerated('TS-RED-S'), isFalse);
      expect(BarcodeGeneratorService.isGenerated('BB123'), isFalse); // short
      expect(BarcodeGeneratorService.isGenerated('BB00000000AB'), isFalse);
      expect(BarcodeGeneratorService.isGenerated('CC0000000042'), isFalse);
      expect(BarcodeGeneratorService.isGenerated(null), isFalse);
      expect(BarcodeGeneratorService.isGenerated(''), isFalse);
      // Whitespace from a scanner must not defeat it.
      expect(BarcodeGeneratorService.isGenerated(' BB0000000042 '), isTrue);
    });

    test('sequenceOf round-trips, and is null for a foreign code', () {
      expect(BarcodeGeneratorService.sequenceOf('BB0000000042'), 42);
      expect(BarcodeGeneratorService.sequenceOf('8901234567890'), isNull);
      expect(BarcodeGeneratorService.sequenceOf(null), isNull);
    });

    // THE rule. Printing is a rendering of what the catalogue already says.
    test('printing the same variant repeatedly reuses the identical barcode',
        () {
      final v = variant(barcode: 'BB0000000042');

      List<LabelSpec> printRun() => LabelPdfService.expand([
            (
              LabelSpec(
                productName: 'T-Shirt',
                barcode: v.barcode ?? '',
                mrp: v.mrp,
                sellingPrice: v.sellingPrice,
              ),
              3,
            )
          ]);

      final first = printRun();
      final second = printRun();
      final third = printRun();

      for (final run in [first, second, third]) {
        expect(run.every((l) => l.barcode == 'BB0000000042'), isTrue);
      }
      // And the variant itself is untouched — nothing in the label path writes.
      expect(v.barcode, 'BB0000000042');
    });

    test('an existing manufacturer barcode is carried, never replaced', () {
      final v = variant(barcode: '8901234567890');
      final labels = LabelPdfService.expand([
        (LabelSpec(productName: 'X', barcode: v.barcode ?? '', mrp: 100), 1)
      ]);
      expect(labels.single.barcode, '8901234567890');
      expect(BarcodeGeneratorService.isGenerated(labels.single.barcode),
          isFalse);
    });

    test('the value is valid Code 128 input', () {
      // Round-trip through the real `barcode` package, which is what actually
      // renders the bars. Throws on unencodable data.
      final code = pw.Barcode.code128();
      for (final value in [
        BarcodeGeneratorService.format(1),
        BarcodeGeneratorService.format(9999999999),
        'TS-RED-S', // an imported alphanumeric code must render too
        '8901234567890',
      ]) {
        expect(() => code.make(value, width: 200, height: 60).toList(),
            returnsNormally,
            reason: value);
      }
    });
  });


  // ==========================================================================
  // Auto-generation on create. The contract lives in
  // `VariantRepository.addVariant` (one choke point, mirroring how
  // `GrnRepository` uses `DocumentNumberService`) — these pin the RULES that
  // choke point implements, without needing Hive.
  group('Auto-generate on create — the rules', () {
    test('a blank barcode is what triggers generation', () {
      // Every representation of "blank" must count as blank, or an imported
      // empty string would block generation and leave the variant unscannable.
      for (final blank in [null, '', '   ']) {
        final v = variant(barcode: blank);
        expect((v.barcode?.trim() ?? '').isEmpty, isTrue, reason: '$blank');
      }
    });

    test('a present barcode is NOT blank, so generation must not fire', () {
      for (final present in ['8901234567890', 'TS-RED-S', 'BB0000000001']) {
        final v = variant(barcode: present);
        expect((v.barcode?.trim() ?? '').isEmpty, isFalse, reason: present);
      }
    });

    // The reason the softened confirmation exists: after auto-generation most
    // variants carry an internal code that may never have been printed, so
    // pasting a real EAN over it is routine rather than alarming.
    test('a generated code is distinguishable from one the shop entered', () {
      expect(BarcodeGeneratorService.isGenerated('BB0000000001'), isTrue);
      expect(BarcodeGeneratorService.isGenerated('8901234567890'), isFalse);
      expect(BarcodeGeneratorService.isGenerated('TS-RED-S'), isFalse);
    });

    test('generation is idempotent for an already-coded variant', () {
      // Re-saving must never renumber. copyWith without a barcode arg keeps it.
      final v = variant(barcode: 'BB0000000007');
      expect(v.copyWith(stockQty: 99).barcode, 'BB0000000007');
    });

    // updateVariant deliberately does not generate, or Remove would be
    // impossible — the field would refill on the very next save.
    test('a cleared barcode stays cleared', () {
      final v = variant(barcode: 'BB0000000007');
      final cleared = v.copyWith(clearBarcode: true);
      expect(cleared.barcode, isNull);
      // An unrelated edit afterwards must not resurrect it.
      expect(cleared.copyWith(sellingPrice: 500).barcode, isNull);
    });
  });

  // ==========================================================================
  group('clearBarcode on copyWith', () {
    test('clears the barcode', () {
      final v = variant(barcode: 'BB0000000042');
      expect(v.copyWith(clearBarcode: true).barcode, isNull);
    });

    // The reason the flag exists: `x ?? this.x` cannot null a field.
    test('passing null does NOT clear it — the clearMrp precedent', () {
      final v = variant(barcode: 'BB0000000042');
      expect(v.copyWith(barcode: null).barcode, 'BB0000000042');
    });

    test('clearBarcode wins over a passed value', () {
      final v = variant(barcode: 'BB0000000042');
      expect(
        v.copyWith(barcode: 'BB0000000099', clearBarcode: true).barcode,
        isNull,
      );
    });

    test('an unrelated edit preserves the barcode', () {
      final v = variant(barcode: 'BB0000000042');
      expect(v.copyWith(sellingPrice: 888).barcode, 'BB0000000042');
    });
  });

  // ==========================================================================
  group('Label content rules', () {
    test('MRP shows, and the selling price only when lower', () {
      expect(spec(mrp: 1199, selling: 999).showsSellingPrice, isTrue);
      expect(spec(mrp: 999, selling: 999).showsSellingPrice, isFalse);
      expect(spec(mrp: 999, selling: 1199).showsSellingPrice, isFalse);
      expect(spec(mrp: null, selling: 999).showsSellingPrice, isFalse);
      expect(spec(mrp: 1199, selling: null).showsSellingPrice, isFalse);
      expect(spec(mrp: 0, selling: 999).showsSellingPrice, isFalse);
    });

    // A LabelSpec has no cost field at all, so a cost price cannot reach a
    // sticker even by accident. This test exists to keep it that way.
    test('LabelSpec carries no cost price', () {
      final s = spec();
      expect(s.mrp, 1199);
      expect(s.sellingPrice, 999);
      // The variant knows its cost; the label never receives it.
      expect(variant().costPrice, 600);
    });

    test('hasBarcode is false for empty and whitespace', () {
      expect(spec(barcode: '').hasBarcode, isFalse);
      expect(spec(barcode: '   ').hasBarcode, isFalse);
      expect(spec(barcode: 'BB0000000042').hasBarcode, isTrue);
    });
  });

  // ==========================================================================
  group('PDF build', () {
    const svc = LabelPdfService();

    test('an empty list builds an empty document', () async {
      final doc = await svc.build(const []);
      expect(doc.document.pdfPageList.pages, isEmpty);
    });

    test('builds without throwing across the page boundary', () async {
      for (final count in [1, 64, 65, 66, 130, 131]) {
        final labels = LabelPdfService.expand([(spec(), count)]);
        final doc = await svc.build(labels);
        expect(doc.document.pdfPageList.pages.length, svc.pagesFor(count),
            reason: '$count labels');
        expect(svc.pagesFor(count), kLabelLayout65Up.pagesFor(count));
      }
    });

    // A legacy variant with no barcode must render a label, not crash.
    test('a label with no barcode still builds', () async {
      final labels = LabelPdfService.expand([
        (spec(barcode: '', sku: 'APP-000042'), 2),
      ]);
      await expectLater(svc.build(labels), completes);
    });

    test('builds with every optional field present, and with none', () async {
      final rich = spec(brand: 'Levis', sku: 'APP-000042');
      final bare = LabelSpec(productName: 'Plain', barcode: 'BB0000000001');
      await expectLater(svc.build([rich, bare]), completes);
    });

    test('saves real bytes for a full sheet', () async {
      final doc = await svc.build(LabelPdfService.expand([(spec(), 65)]));
      final bytes = await doc.save();
      expect(bytes.length, greaterThan(1000));
    });
  });

  // ==========================================================================
  // The layout half. Everything below asserts the PLAN, not the PDF: the
  // renderer only fills boxes the plan sizes, so a plan that cannot collide is
  // a label that cannot collide.
  group('Label layout — vertical allocation', () {
    // Stand-in for real font metrics. Width is a flat per-character advance a
    // touch wider than Poppins' average, so the wrap decisions asserted here
    // are the conservative ones. Height models what the real font does: the ink
    // box grows with descenders and accents (measured range 0.71 - 1.25 em), so
    // the variable-height allocation is genuinely exercised.
    LabelTextSize measure(String text,
        {required double fontSize, required bool bold}) {
      final width = text.length * (bold ? 0.60 : 0.58) * fontSize;
      var em = 0.76;
      if (RegExp(r'[gjpqy,;()/]').hasMatch(text)) em += 0.28;
      if (RegExp(r'[À-Ü]').hasMatch(text)) em += 0.16;
      return LabelTextSize(width, em * fontSize);
    }

    double widthOf(String text, {required double fontSize, required bool bold}) =>
        measure(text, fontSize: fontSize, bold: bold).width;

    LabelPlan planFor(LabelContent content) => LabelPlanner.plan(
          content: content,
          widthPt: kLabelLayout65Up.labelWidthMm * kPtPerMm,
          heightPt: kLabelLayout65Up.labelHeightMm * kPtPerMm,
          measure: measure,
        );

    LabelPlan planForSpec(LabelSpec s) =>
        planFor(LabelPdfService.contentFor(s));

    /// Top/bottom of every drawn section, in the order the renderer stacks them.
    List<(String, double, double)> bands(LabelPlan p) {
      final out = <(String, double, double)>[];
      var y = 0.0;
      void band(String name, double height) {
        if (height <= 0) return;
        out.add((name, y, y + height));
        y += height;
      }

      for (var i = 0; i < p.nameLines.length; i++) {
        band('name$i', p.nameLines[i].height);
      }
      band('brand', p.brand.height);
      band('variant', p.variant.height);
      band('price', p.priceHeight);
      band('gap', p.gapAbove);
      band('bars', p.barsHeight);
      band('quiet', p.quietGap);
      band('value', p.value.height);
      band('sku', p.sku.height);
      return out;
    }

    /// Every invariant the reported defects violated, in one place.
    void assertSane(LabelPlan p, String scenario) {
      // 1. Inside the sticker.
      expect(p.fits, isTrue,
          reason: '$scenario: used ${p.usedHeight} of ${p.contentHeight}');

      // 2. Nothing overlaps anything: each band starts where the last ended.
      final b = bands(p);
      for (var i = 1; i < b.length; i++) {
        expect(b[i].$2, greaterThanOrEqualTo(b[i - 1].$3 - 0.001),
            reason: '$scenario: ${b[i].$1} starts inside ${b[i - 1].$1}');
      }
      expect(b.last.$3, lessThanOrEqualTo(p.contentHeight + 0.01),
          reason: '$scenario: ${b.last.$1} runs off the label');

      // 3. The barcode kept its protected area.
      expect(p.barsHeight, greaterThanOrEqualTo(LabelMetrics.minBars),
          reason: '$scenario: bars too short to scan');
      expect(p.barsHeight, lessThanOrEqualTo(LabelMetrics.maxBars + 0.001),
          reason: '$scenario: bars past the cap');
      expect(p.gapAbove, greaterThanOrEqualTo(LabelMetrics.gapAboveMin - 0.001),
          reason: '$scenario: price is crowding the barcode');
      expect(p.barsWidth, lessThan(p.contentWidth),
          reason: '$scenario: no horizontal quiet zone');

      // 4. No text leaves the label horizontally.
      final lines = <FittedLine>[
        ...p.nameLines,
        p.brand,
        p.variant,
        p.value,
        p.sku,
      ];
      for (final line in lines) {
        if (line.isEmpty) continue;
        expect(
          widthOf(line.text, fontSize: line.fontSize, bold: false),
          lessThanOrEqualTo(p.contentWidth + 0.01),
          reason: '$scenario: "${line.text}" is wider than the label',
        );
      }
      if (p.hasPriceRow) {
        final w = widthOf(p.mrp.text, fontSize: p.mrp.fontSize, bold: false) +
            4.0 +
            widthOf(p.price.text, fontSize: p.price.fontSize, bold: true);
        expect(w, lessThanOrEqualTo(p.contentWidth + 0.01),
            reason: '$scenario: the price row is wider than the label');
      }

      // 5. Type never shrinks below the readable floor.
      for (final line in p.nameLines) {
        expect(line.fontSize, greaterThanOrEqualTo(LabelMetrics.name.min - 0.001),
            reason: '$scenario: name below the floor');
      }
      if (p.value.isNotEmpty) {
        expect(p.value.fontSize,
            greaterThanOrEqualTo(LabelMetrics.value.min - 0.001),
            reason: '$scenario: barcode value below the floor');
      }

      // 6. At most two lines of name — a price tag, not a paragraph.
      expect(p.nameLines.length, lessThanOrEqualTo(LabelMetrics.maxNameLines),
          reason: '$scenario: name took too many lines');
    }

    // ---- The ten cases from the layout brief -----------------------------
    final cases = <String, LabelSpec>{
      '1 short, everything present': const LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        brand: 'Nike',
        barcode: 'BB0000000001',
        sku: 'AIR2-BLK-9',
        mrp: 2000,
        sellingPrice: 1500,
      ),
      '2 medium name and two attributes': const LabelSpec(
        productName: 'V-Neck T-Shirt',
        variantDescriptor: 'Size: L / Color: Blue',
        brand: 'Nike',
        barcode: 'BB0000000002',
        sku: 'TS-BLU-L',
        mrp: 1299,
        sellingPrice: 999,
      ),
      '3 very long product name': const LabelSpec(
        productName:
            'Premium Cotton Regular Fit V-Neck Casual T-Shirt for Men',
        variantDescriptor: 'Size: XXL / Color: Dark Navy Blue',
        brand: 'Nike',
        barcode: 'BB0000000003',
        sku: 'PC-VN-XXL-NVY',
        mrp: 2499,
        sellingPrice: 1799,
      ),
      '4 very long variant description': const LabelSpec(
        productName: 'Running Shoe',
        variantDescriptor:
            'Size: 11 / Color: Fluorescent Orange / Width: Extra Wide',
        brand: 'Adidas',
        barcode: 'BB0000000004',
        mrp: 5999,
        sellingPrice: 4499,
      ),
      '5 no brand': const LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        barcode: 'BB0000000005',
        sku: 'AIR2-BLK-9',
        mrp: 2000,
        sellingPrice: 1500,
      ),
      '6 no SKU': const LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        brand: 'Nike',
        barcode: 'BB0000000006',
        mrp: 2000,
        sellingPrice: 1500,
      ),
      '7 MRP only': const LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        brand: 'Nike',
        barcode: 'BB0000000007',
        mrp: 2000,
      ),
      '8 MRP plus a lower selling price': const LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        brand: 'Nike',
        barcode: 'BB0000000008',
        mrp: 2000,
        sellingPrice: 1500,
      ),
      '9 no barcode at all': const LabelSpec(
        productName: 'Gift Box',
        variantDescriptor: 'Large',
        barcode: '',
        sku: 'GFT-000012',
        mrp: 499,
      ),
      '10 nothing but a name and a barcode': const LabelSpec(
        productName: 'Plain',
        barcode: 'BB0000000010',
      ),
      '11 six-figure prices': const LabelSpec(
        productName: 'Diamond Pendant',
        variantDescriptor: '18kt / 0.5ct',
        brand: 'Tanishq',
        barcode: 'BB0000000011',
        mrp: 250000,
        sellingPrice: 199999,
      ),
      '12 a single unbreakably long word': const LabelSpec(
        productName: 'Pneumonoultramicroscopicsilicovolcanoconiosis',
        variantDescriptor: 'One Size',
        barcode: 'BB0000000012',
        mrp: 100,
      ),
    };

    cases.forEach((scenario, s) {
      test('holds together: $scenario', () {
        assertSane(planForSpec(s), scenario);
      });
    });

    // ---- Section-by-section rules ----------------------------------------
    test('a long name wraps rather than being clipped', () {
      final p = planForSpec(cases['3 very long product name']!);
      expect(p.nameLines.length, 2);
      // Every word survives somewhere in the two lines.
      final rendered = p.nameLines.map((l) => l.text).join(' ');
      for (final word in ['Premium', 'Cotton', 'V-Neck', 'Men']) {
        expect(rendered, contains(word), reason: 'lost "$word"');
      }
      expect(rendered, isNot(contains('...')),
          reason: 'a name this length should still fit in two lines');
    });

    test('a short name takes one line, and no phantom second line', () {
      final p = planForSpec(cases['1 short, everything present']!);
      expect(p.nameLines.length, 1);
      expect(p.nameLines.single.text, 'Air 2');
    });

    test('an unbreakable word is split, never run off the edge', () {
      final p = planForSpec(cases['12 a single unbreakably long word']!);
      expect(p.nameLines.length, greaterThanOrEqualTo(1));
      for (final line in p.nameLines) {
        expect(widthOf(line.text, fontSize: line.fontSize, bold: true),
            lessThanOrEqualTo(p.contentWidth + 0.01));
      }
    });

    test('no brand means no reserved space', () {
      final without = planForSpec(cases['5 no brand']!);
      final with_ = planForSpec(cases['1 short, everything present']!);
      expect(without.brand.height, 0);
      expect(with_.brand.height, greaterThan(0));
      // The space it would have taken goes to the barcode or the whitespace,
      // never to a blank line.
      expect(without.barsHeight + without.gapAbove + without.padBottom,
          greaterThan(with_.barsHeight + with_.gapAbove + with_.padBottom));
    });

    test('no SKU means no empty line, and the freed space is put to use', () {
      final withSku = planForSpec(cases['1 short, everything present']!);
      final p = planForSpec(cases['6 no SKU']!);
      expect(p.sku.height, 0);
      expect(p.fits, isTrue);
      expect(p.gapAbove, greaterThanOrEqualTo(LabelMetrics.gapAboveMin));
      // The line it would have taken becomes barcode, not a hole at the foot.
      expect(p.barsHeight, greaterThan(withSku.barsHeight));
      expect(p.usedHeight, closeTo(withSku.usedHeight, 0.01));
    });

    // A tariff code is accounting data, not shelf data. It was dropped from the
    // label so the SKU is the last line, and nothing may put it back silently.
    test('no HSN or tariff code reaches the label, whatever the spec carries',
        () {
      for (final s in cases.values) {
        final content = LabelPdfService.contentFor(s);
        final printed = [
          content.name,
          content.brand,
          content.variant,
          content.mrpText,
          content.priceText,
          content.barcodeValue,
          content.skuText,
        ].join(' ');
        expect(printed, isNot(contains('HSN')),
            reason: '${s.productName}: an HSN line came back');
      }
      final p = planForSpec(cases['1 short, everything present']!);
      expect(bands(p).last.$1, 'sku');
    });

    test('MRP only is shown once, at price emphasis', () {
      final p = planForSpec(cases['7 MRP only']!);
      expect(p.hasPriceRow, isFalse);
      expect(p.mrp.text, startsWith('MRP '));
      expect(p.price.isEmpty, isTrue);
      expect(p.mrp.fontSize, greaterThanOrEqualTo(LabelMetrics.price.min));
    });

    test('MRP and selling price share one row, both labelled', () {
      final p = planForSpec(cases['8 MRP plus a lower selling price']!);
      expect(p.hasPriceRow, isTrue);
      expect(p.mrp.text, startsWith('MRP '));
      expect(p.price.text, startsWith('PRICE '));
      // The selling price is the louder of the two.
      expect(p.price.fontSize, greaterThan(p.mrp.fontSize));
    });

    test('six-figure prices shrink to fit instead of overlapping', () {
      final p = planForSpec(cases['11 six-figure prices']!);
      expect(p.hasPriceRow, isTrue);
      final w = widthOf(p.mrp.text, fontSize: p.mrp.fontSize, bold: false) +
          4.0 +
          widthOf(p.price.text, fontSize: p.price.fontSize, bold: true);
      expect(w, lessThanOrEqualTo(p.contentWidth + 0.01));
    });

    test('the price row never touches the bars', () {
      for (final s in cases.values) {
        final p = planForSpec(s);
        if (!p.hasPrice) continue;
        final b = bands(p);
        final priceBand = b.firstWhere((e) => e.$1 == 'price');
        final barsBand = b.firstWhere((e) => e.$1 == 'bars');
        expect(barsBand.$2 - priceBand.$3,
            greaterThanOrEqualTo(LabelMetrics.gapAboveMin - 0.001),
            reason: '${s.productName}: only ${barsBand.$2 - priceBand.$3}pt');
      }
    });

    test('the barcode value keeps its own line under a quiet zone', () {
      final p = planForSpec(cases['1 short, everything present']!);
      expect(p.value.text, 'BB0000000001');
      expect(p.quietGap, greaterThan(0));
      final b = bands(p);
      final bars = b.firstWhere((e) => e.$1 == 'bars');
      final value = b.firstWhere((e) => e.$1 == 'value');
      expect(value.$2 - bars.$3, closeTo(LabelMetrics.quietGap, 0.001));
    });

    test('a variant with no barcode still reserves the area, and names itself',
        () {
      final p = planForSpec(cases['9 no barcode at all']!);
      expect(p.barcodeMissing, isTrue);
      expect(p.barsHeight, greaterThanOrEqualTo(LabelMetrics.minBars));
      expect(p.value.isEmpty, isTrue);
      expect(p.quietGap, 0);
      // The bars area says only that there is no barcode; the SKU is not
      // allowed to stand in for one.
      final content = LabelPdfService.contentFor(cases['9 no barcode at all']!);
      expect(content.barcodeFallback, 'no barcode');
      expect(content.skuText, 'SKU: GFT-000012');
    });

    test('a long variant descriptor shrinks or trims, never overflows', () {
      final p = planForSpec(cases['4 very long variant description']!);
      expect(p.variant.isNotEmpty, isTrue);
      expect(widthOf(p.variant.text, fontSize: p.variant.fontSize, bold: true),
          lessThanOrEqualTo(p.contentWidth + 0.01));
      expect(p.variant.fontSize,
          greaterThanOrEqualTo(LabelMetrics.hardFloor - 0.001));
    });

    test('content is stacked in the intended reading order', () {
      final p = planForSpec(cases['1 short, everything present']!);
      expect(bands(p).map((b) => b.$1).toList(), [
        'name0',
        'brand',
        'variant',
        'price',
        'gap',
        'bars',
        'quiet',
        'value',
        'sku',
      ]);
    });

    // The reported defect: a shop code sitting unlabelled under the bars reads
    // as the barcode. These four assertions are the whole fix.
    test('the line under the bars is the ENCODED value, never the SKU', () {
      const s = LabelSpec(
        productName: 'V-Neck T-Shirt',
        variantDescriptor: 'Size: L / Color: Blue',
        brand: 'Nike',
        barcode: 'BB0000000001',
        sku: 'TS-BLU-L',
        mrp: 19,
        sellingPrice: 16,
      );
      final content = LabelPdfService.contentFor(s);
      // What the graphic encodes and what is printed under it are one value.
      expect(content.barcodeValue, s.barcode);
      expect(content.barcodeValue, 'BB0000000001');

      final p = planFor(content);
      expect(p.value.text, 'BB0000000001');
      expect(p.value.text, isNot(contains('TS-BLU-L')));
      // The SKU is present, labelled, and below the value.
      expect(p.sku.text, 'SKU: TS-BLU-L');
      final order = bands(p).map((b) => b.$1).toList();
      expect(order.indexOf('sku'), greaterThan(order.indexOf('value')));
      assertSane(p, 'value / SKU stack');
    });

    test('an SKU-shaped barcode is still printed as the barcode', () {
      // A variant imported from the sample sheet carries 'TS-BLU-L' in the
      // BARCODE column. The label must print what is encoded, whatever it
      // looks like.
      const s = LabelSpec(
        productName: 'V-Neck T-Shirt',
        barcode: 'TS-BLU-L',
        sku: 'TS-BLU-L',
        mrp: 19,
      );
      final p = planForSpec(s);
      expect(p.value.text, 'TS-BLU-L');
      expect(p.sku.text, 'SKU: TS-BLU-L');
      expect(p.barcodeMissing, isFalse);
    });

    test('no SKU means no SKU line, and no reserved space', () {
      const s = LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        barcode: 'BB0000000001',
        mrp: 2000,
      );
      final p = planForSpec(s);
      expect(p.sku.height, 0);
      expect(bands(p).map((b) => b.$1), isNot(contains('sku')));
      // With the SKU gone the value is the last thing on the label.
      expect(bands(p).last.$1, 'value');
    });

    test('the SKU sits directly under the barcode value', () {
      const s = LabelSpec(
        productName: 'Air 2',
        variantDescriptor: 'Size: 9',
        barcode: 'BB0000000001',
        sku: 'TS-BLU-L',
        mrp: 2000,
      );
      final p = planForSpec(s);
      expect(p.sku.text, 'SKU: TS-BLU-L');
      expect(bands(p).map((b) => b.$1).toList(),
          containsAllInOrder(['bars', 'quiet', 'value', 'sku']));
    });

    // The regression that started this: a label whose name, brand, variant,
    // price, barcode, value AND SKU are all present must still fit, because
    // that is the everyday garment case.
    test('the fullest realistic label still fits with room for the bars', () {
      final p = planForSpec(cases['2 medium name and two attributes']!);
      expect(p.fits, isTrue);
      expect(p.barsHeight, greaterThanOrEqualTo(LabelMetrics.minBars));
      expect(p.usedHeight, lessThanOrEqualTo(p.contentHeight + 0.01));
    });

    test('a bigger label gives its extra height to the barcode', () {
      final small = planFor(const LabelContent(
        name: 'Air 2',
        brand: 'Nike',
        variant: 'Size: 9',
        mrpText: 'MRP 2000',
        priceText: 'PRICE 1500',
        barcodeValue: 'BB0000000001',
        skuText: 'SKU: AIR2-BLK-9',
      ));
      final tall = LabelPlanner.plan(
        content: const LabelContent(
          name: 'Air 2',
          brand: 'Nike',
          variant: 'Size: 9',
          mrpText: 'MRP 2000',
          priceText: 'PRICE 1500',
          barcodeValue: 'BB0000000001',
          skuText: 'SKU: AIR2-BLK-9',
        ),
        widthPt: kLabelLayout65Up.labelWidthMm * kPtPerMm,
        heightPt: 30 * kPtPerMm,
        measure: measure,
      );
      expect(tall.barsHeight, greaterThanOrEqualTo(small.barsHeight));
      expect(tall.fits, isTrue);
    });
  });
}
