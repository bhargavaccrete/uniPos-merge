import 'package:syncfusion_flutter_xlsio/xlsio.dart';

import '../../../../core/di/service_locator.dart';

/// Builds the retail bulk-import Excel template using Syncfusion xlsio so we
/// can add real Data Validation dropdowns (the `excel` package used for
/// *reading* the file back on import cannot write these) — same technique as
/// the restaurant side's `ImportTemplateBuilder`.
///
/// Row layout must match what `BulkImportStore` expects: header (row 1),
/// yellow instruction (row 2), data (row 3+). xlsio is 1-based.
class RetailImportTemplateBuilder {
  static const List<String> _fallbackCategories = [
    'Clothing',
    'Electronics',
    'Grocery',
    'Footwear',
    'General',
  ];

  /// Last data row dropdowns/validation are applied to.
  static const int _validationLastRow = 500;

  /// Last row the Categories/Taxes reference lists span. A fixed range is
  /// required for a range-based dropdown; existing categories/taxes are
  /// seeded live below, so this only matters for room to add more by hand.
  static const int _listSourceLastRow = 60;

  List<int> build() {
    final Workbook wb = Workbook();

    final Style header = wb.styles.add('hdr')
      ..bold = true
      ..backColor = '#1E4FA3'
      ..fontColor = '#FFFFFF';
    final Style instr = wb.styles.add('instr')
      ..italic = true
      ..backColor = '#FFF2CC'
      ..fontColor = '#7F6000'
      ..fontSize = 9;
    final Style titleStyle = wb.styles.add('title')
      ..bold = true
      ..fontSize = 14
      ..fontColor = '#1E4FA3';
    final Style sectionStyle = wb.styles.add('section')
      ..bold = true
      ..backColor = '#E8EEF7';

    // Create sheets first so Products can reference the Categories/Taxes
    // ranges for live dropdowns.
    final Worksheet instructions = wb.worksheets[0]..name = 'Instructions';
    final Worksheet categories = wb.worksheets.addWithName('Categories');
    final Worksheet taxes = wb.worksheets.addWithName('Taxes');
    final Worksheet products = wb.worksheets.addWithName('Products');

    _buildInstructions(instructions, titleStyle, sectionStyle);
    _buildCategories(categories, header, instr);
    final taxLabels = _buildTaxes(taxes, header, instr);
    _buildProducts(products, header, instr, categories, taxes, taxLabels);

    final List<int> bytes = wb.saveAsStream();
    wb.dispose();
    return bytes;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setHeaders(Worksheet s, List<String> headers, Style style) {
    for (int i = 0; i < headers.length; i++) {
      s.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    s.getRangeByIndex(1, 1, 1, headers.length).cellStyle = style;
  }

  void _setInstruction(Worksheet s, List<String> hints, Style style) {
    for (int i = 0; i < hints.length; i++) {
      s.getRangeByIndex(2, i + 1).setText(hints[i]);
    }
    s.getRangeByIndex(2, 1, 2, hints.length).cellStyle = style;
  }

  void _setRow(Worksheet s, int row, List<dynamic> values) {
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final range = s.getRangeByIndex(row, i + 1);
      if (v is num) {
        range.setNumber(v.toDouble());
      } else {
        range.setText(v?.toString() ?? '');
      }
    }
  }

  /// A LIVE dropdown that reads its options from a column on another sheet.
  /// [allowOther] keeps the dropdown a soft suggestion — owners can still type
  /// a brand-new value (e.g. a new category) and it gets picked up on import.
  void _dropdownFromRange(
    Worksheet s,
    int col,
    Range source, {
    required String prompt,
    required String addSheet,
    int fromRow = 3,
  }) {
    final Range r = s.getRangeByIndex(fromRow, col, _validationLastRow, col);
    final dv = r.dataValidation;
    dv.allowType = ExcelDataValidationType.user;
    dv.dataRange = source;
    dv.promptBoxText = prompt;
    dv.showPromptBox = true;
    dv.errorStyle = ExcelDataValidationErrorStyle.warning;
    dv.errorBoxTitle = 'Not in list';
    dv.errorBoxText =
        'Pick from the list, or add it to the $addSheet sheet first.';
  }

  // ── Instructions ───────────────────────────────────────────────────────────

  void _buildInstructions(Worksheet s, Style title, Style section) {
    s.getRangeByIndex(1, 1).setText('Bill Berry Lite Retail Bulk Import');
    s.getRangeByIndex(1, 1).cellStyle = title;

    int r = 3;
    void line(String t, {Style? style}) {
      s.getRangeByIndex(r, 1).setText(t);
      if (style != null) s.getRangeByIndex(r, 1).cellStyle = style;
      r++;
    }

    line('QUICK START', style: section);
    line(
      '1. Check the "Categories" and "Taxes" sheets — add more rows there if you need new ones.',
    );
    line(
      '2. Fill the "Products" sheet — use the dropdowns for Category and Tax Rate.',
    );
    line(
      '3. One row per variant. Give every variant of the same product the same Handle.',
    );
    line('4. Save this file and import it back into Bill Berry Lite.');
    r++;
    line('TIPS', style: section);
    line(
      '• Cells with a dropdown show a small arrow — click it to pick a value.',
    );
    line('• Click any header cell to read its tooltip (what to enter).');
    line('• Required columns are marked with * in the header row.');
    line(
      '• You can still type a value that isn\'t in the dropdown — it will be added automatically.',
    );
    line('• Price must be a number only (no currency symbols).');

    s.getRangeByIndex(1, 1).columnWidth = 90;
  }

  // ── Categories (seeded with the shop's real categories if any exist) ───────

  List<String> _buildCategories(Worksheet s, Style header, Style instr) {
    _setHeaders(s, ['id', 'name*'], header);
    _setInstruction(s, [
      'Leave blank — filled in automatically',
      'Category name (e.g., Clothing)',
    ], instr);

    final existing = categoryStore.categories.map((c) => c.name).toList();
    final names = existing.isNotEmpty ? existing : _fallbackCategories;

    for (int i = 0; i < names.length; i++) {
      _setRow(s, 3 + i, ['', names[i]]);
    }
    s.getRangeByIndex(1, 1, 1, 2).autoFitColumns();
    return names;
  }

  // ── Taxes (seeded with the shop's real named tax rates if any exist) ──────

  List<String> _buildTaxes(Worksheet s, Style header, Style instr) {
    _setHeaders(s, ['name*', 'rate%*'], header);
    _setInstruction(s, [
      'Tax name (e.g., GST)',
      'Rate as a number, e.g. 5',
    ], instr);

    final existingTaxes = taxStore.taxes;
    final labels = <String>[];
    if (existingTaxes.isNotEmpty) {
      for (int i = 0; i < existingTaxes.length; i++) {
        final tax = existingTaxes[i];
        final rate = tax.taxperecentage ?? 0;
        _setRow(s, 3 + i, [tax.taxname, rate]);
        labels.add('${tax.taxname} ($rate%)');
      }
    } else {
      const defaults = [
        {'name': 'GST', 'rate': 5.0},
        {'name': 'GST', 'rate': 12.0},
        {'name': 'GST', 'rate': 18.0},
      ];
      for (int i = 0; i < defaults.length; i++) {
        final name = defaults[i]['name'] as String;
        final rate = defaults[i]['rate'] as double;
        _setRow(s, 3 + i, [name, rate]);
        labels.add('$name ($rate%)');
      }
    }
    s.getRangeByIndex(1, 1, 1, 2).autoFitColumns();
    return labels;
  }

  // ── Products (the actual data-entry sheet) ─────────────────────────────────

  void _buildProducts(
    Worksheet s,
    Style header,
    Style instr,
    Worksheet categorySource,
    Worksheet taxSource,
    List<String> taxLabels,
  ) {
    _setHeaders(s, [
      'Handle*',
      'Name*',
      'Category*',
      'Description',
      'Option1 Name',
      'Option1 Value',
      'Option2 Name',
      'Option2 Value',
      'Option3 Name',
      'Option3 Value',
      'Cost Price',
      'Selling Price*',
      'MRP',
      'Stock',
      'Barcode',
      'Min Stock',
      'Tax Rate',
      'HSN Code',
    ], header);
    _setInstruction(s, [
      'Groups variants — same Handle = same product',
      'Product name (on the first row of each group)',
      'Pick a category',
      'Optional, first row only',
      'e.g. Size',
      'e.g. Small',
      'e.g. Color',
      'e.g. Red',
      '',
      '',
      'Optional',
      'Required: number only',
      'Optional',
      'Optional, defaults to 0',
      'Optional, must be unique',
      'Optional, defaults to 5',
      'Pick a tax rate (first row of each group only)',
      'Optional, first row only',
    ], instr);

    final sampleTax = taxLabels.isNotEmpty ? taxLabels.first : '';

    // Sample 1: Simple product, no variants, no tax.
    _setRow(s, 3, [
      'coke_can',
      'Coca Cola 330ml',
      'Grocery',
      'Refreshing drink',
      '',
      '',
      '',
      '',
      '',
      '',
      0.50,
      1.00,
      1.20,
      100,
      '1234567890',
      10,
      '',
      '',
    ]);

    // Sample 2: Simple product, no variants, WITH tax and HSN Code.
    _setRow(s, 4, [
      'bt_earbuds',
      'Bluetooth Earbuds',
      'Electronics',
      'Wireless earbuds with charging case',
      '',
      '',
      '',
      '',
      '',
      '',
      15.00,
      25.00,
      30.00,
      40,
      'BT-EARBUDS-01',
      5,
      sampleTax,
      '85183000',
    ]);

    // Sample 3: Single-option variant product (Size only), no tax.
    _setRow(s, 5, [
      'cotton_socks',
      'Cotton Socks',
      'Clothing',
      'Comfortable cotton socks',
      'Size',
      'S',
      '',
      '',
      '',
      '',
      2.00,
      6.00,
      7.00,
      30,
      'SOCK-S',
      5,
      '',
      '',
    ]);
    _setRow(s, 6, [
      'cotton_socks',
      'Cotton Socks',
      'Clothing',
      'Comfortable cotton socks',
      'Size',
      'M',
      '',
      '',
      '',
      '',
      2.00,
      6.00,
      7.00,
      25,
      'SOCK-M',
      5,
      '',
      '',
    ]);
    _setRow(s, 7, [
      'cotton_socks',
      'Cotton Socks',
      'Clothing',
      'Comfortable cotton socks',
      'Size',
      'L',
      '',
      '',
      '',
      '',
      2.20,
      6.50,
      7.50,
      20,
      'SOCK-L',
      5,
      '',
      '',
    ]);

    // Sample 4: Two-option variant product (Size + Color), tax + HSN Code set
    // on the first/parent row only. Note Size "S" repeats on rows 8 and 9 with
    // a different Color each time — more values for an option means more
    // ROWS, never a new column. Columns are the option *types* (Size, Color).
    _setRow(s, 8, [
      'tshirt_vneck',
      'V-Neck T-Shirt',
      'Clothing',
      'Cotton T-Shirt',
      'Size',
      'S',
      'Color',
      'Red',
      '',
      '',
      5.00,
      15.00,
      18.00,
      20,
      'TS-RED-S',
      5,
      sampleTax,
      '6109',
    ]);
    _setRow(s, 9, [
      'tshirt_vneck',
      'V-Neck T-Shirt',
      'Clothing',
      'Cotton T-Shirt',
      'Size',
      'S',
      'Color',
      'Blue',
      '',
      '',
      5.00,
      15.00,
      18.00,
      12,
      'TS-BLU-S',
      5,
      '',
      '',
    ]);
    _setRow(s, 10, [
      'tshirt_vneck',
      'V-Neck T-Shirt',
      'Clothing',
      'Cotton T-Shirt',
      'Size',
      'M',
      'Color',
      'Red',
      '',
      '',
      5.00,
      15.00,
      18.00,
      15,
      'TS-RED-M',
      5,
      '',
      '',
    ]);
    _setRow(s, 11, [
      'tshirt_vneck',
      'V-Neck T-Shirt',
      'Clothing',
      'Cotton T-Shirt',
      'Size',
      'L',
      'Color',
      'Blue',
      '',
      '',
      6.00,
      16.00,
      19.00,
      10,
      'TS-BLU-L',
      5,
      '',
      '',
    ]);

    // Category dropdown — live from the Categories sheet (column B, data row 3+).
    _dropdownFromRange(
      s,
      3,
      categorySource.getRangeByName('B3:B$_listSourceLastRow'),
      prompt: 'Pick a category (add new ones in the Categories sheet).',
      addSheet: 'Categories',
    );

    // Tax Rate dropdown — no single-column source matches "Name (Rate%)", so
    // build a helper column on the Taxes sheet that concatenates name+rate for
    // every row in the dropdown's range (not just currently-populated ones),
    // so taxes added later by hand also get a computed label automatically.
    // Labelled so it doesn't look like unexplained stray data on that sheet.
    taxSource.getRangeByIndex(1, 3).setText('Label (auto)');
    taxSource.getRangeByIndex(1, 3).cellStyle = header;
    taxSource.getRangeByIndex(2, 3).setText('Auto-generated — do not edit');
    taxSource.getRangeByIndex(2, 3).cellStyle = instr;
    for (int row = 3; row <= _listSourceLastRow; row++) {
      taxSource
          .getRangeByIndex(row, 3)
          .setFormula('=IF(A$row="","",A$row&" ("&B$row&"%)")');
    }
    taxSource.getRangeByIndex(1, 3).columnWidth = 20;
    _dropdownFromRange(
      s,
      17,
      taxSource.getRangeByName('C3:C$_listSourceLastRow'),
      prompt: 'Pick a tax rate (add new ones in the Taxes sheet).',
      addSheet: 'Taxes',
    );
  }
}
