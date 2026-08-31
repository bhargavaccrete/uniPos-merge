import 'package:syncfusion_flutter_xlsio/xlsio.dart';

import '../../../../core/config/tariff_code_rule.dart';
import '../../../../core/constants/item_units.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/retail/retail_import_schema.dart';

/// Builds the retail bulk-import Excel template using Syncfusion xlsio so we
/// can add real Data Validation dropdowns (the `excel` package used for
/// *reading* the file back on import cannot write these) — same technique as
/// the restaurant side's `ImportTemplateBuilder`.
///
/// Column names and their order come from [kRetailImportHeaderRow], the same
/// list `RetailImportParser` reads back, so the writer and the reader cannot
/// drift apart.
///
/// Row layout must match what the parser expects: header (row 1), yellow
/// instruction (row 2), data (row 3+). xlsio is 1-based.
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

  /// 1-based worksheet column for [column].
  int _col(RetailImportColumn column) => column.index + 1;

  /// A LIVE dropdown that reads its options from a column on another sheet.
  /// [allowOther] behaviour is implicit: the error style is a warning, so
  /// owners can still type a brand-new value (e.g. a new category) and it gets
  /// picked up on import.
  void _dropdownFromRange(
    Worksheet s,
    RetailImportColumn column,
    Range source, {
    required String prompt,
    required String addSheet,
    int fromRow = 3,
  }) {
    final Range r = s.getRangeByIndex(
      fromRow,
      _col(column),
      _validationLastRow,
      _col(column),
    );
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

  /// A dropdown over a fixed list of values. Used for Unit, whose options are
  /// [kItemUnits] — the app's canonical unit list, shared with the restaurant
  /// side. A unit outside it cannot be stored, so this one is a STOP rather
  /// than a warning.
  void _dropdownFromList(
    Worksheet s,
    RetailImportColumn column,
    List<String> values, {
    required String prompt,
    required String errorText,
    int fromRow = 3,
  }) {
    final Range r = s.getRangeByIndex(
      fromRow,
      _col(column),
      _validationLastRow,
      _col(column),
    );
    final dv = r.dataValidation;
    dv.allowType = ExcelDataValidationType.user;
    dv.listOfValues = values;
    dv.promptBoxText = prompt;
    dv.showPromptBox = true;
    dv.errorStyle = ExcelDataValidationErrorStyle.stop;
    dv.errorBoxTitle = 'Not a supported unit';
    dv.errorBoxText = errorText;
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
      '2. Fill the "Products" sheet — use the dropdowns for Category, Tax Rate and Unit.',
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
      '• You can still type a Category or Tax that isn\'t in the dropdown — it will be added automatically.',
    );
    line(
      '• Price and Stock must be numbers only (no currency symbols, no 1,000 separators).',
    );
    r++;
    line('UNIT, STOCK AND EXPIRY', style: section);
    line(
      '• Unit, Expiry Date, Tax Rate and ${TariffCodeRule.label} belong to the PRODUCT — fill them on the first row of each Handle only.',
    );
    line(
      '• Unit "piece" means the product is counted in whole numbers; Stock must then be a whole number.',
    );
    line(
      '• Any other unit (${kItemUnits.where((u) => u != 'piece').join(', ')}) makes it a loose/weighed product, so Stock may be fractional (e.g. 10.5).',
    );
    line(
      '• Expiry Date must be written as YYYY-MM-DD, e.g. 2026-12-31. Leave blank if it does not expire.',
    );
    r++;
    line('CODES', style: section);
    line(
      '• Barcode: leave blank and one is generated for you when the product is created.',
    );
    line('• SKU: leave blank and one is generated from the category.');
    line(
      '• A barcode must be unique — a duplicate is reported and that product is not imported.',
    );
    r++;
    line('RE-IMPORTING', style: section);
    line(
      '• If a product with the same Name already exists, its NEW variants are added to it — no duplicate product is created.',
    );
    line(
      '• A variant that already exists is skipped and reported, never duplicated.',
    );

    s.getRangeByIndex(1, 1).columnWidth = 110;
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

  /// Builds one Products row from named values, so a 21-column sample stays
  /// readable and a future column cannot silently shift the others.
  List<dynamic> _productRow({
    required String handle,
    required String name,
    String category = '',
    String description = '',
    String opt1Name = '',
    String opt1Value = '',
    String opt2Name = '',
    String opt2Value = '',
    String opt3Name = '',
    String opt3Value = '',
    dynamic cost = '',
    dynamic price = '',
    dynamic mrp = '',
    dynamic stock = '',
    String barcode = '',
    dynamic minStock = '',
    String tax = '',
    String hsn = '',
    String sku = '',
    String unit = '',
    String expiry = '',
  }) {
    final values = List<dynamic>.filled(RetailImportColumn.values.length, '');
    void put(RetailImportColumn c, dynamic v) => values[c.index] = v;

    put(RetailImportColumn.handle, handle);
    put(RetailImportColumn.name, name);
    put(RetailImportColumn.category, category);
    put(RetailImportColumn.description, description);
    put(RetailImportColumn.option1Name, opt1Name);
    put(RetailImportColumn.option1Value, opt1Value);
    put(RetailImportColumn.option2Name, opt2Name);
    put(RetailImportColumn.option2Value, opt2Value);
    put(RetailImportColumn.option3Name, opt3Name);
    put(RetailImportColumn.option3Value, opt3Value);
    put(RetailImportColumn.costPrice, cost);
    put(RetailImportColumn.sellingPrice, price);
    put(RetailImportColumn.mrp, mrp);
    put(RetailImportColumn.stock, stock);
    put(RetailImportColumn.barcode, barcode);
    put(RetailImportColumn.minStock, minStock);
    put(RetailImportColumn.taxRate, tax);
    put(RetailImportColumn.hsnCode, hsn);
    put(RetailImportColumn.sku, sku);
    put(RetailImportColumn.unit, unit);
    put(RetailImportColumn.expiryDate, expiry);
    return values;
  }

  void _buildProducts(
    Worksheet s,
    Style header,
    Style instr,
    Worksheet categorySource,
    Worksheet taxSource,
    List<String> taxLabels,
  ) {
    // Headers come from the parser's own list — one source of truth.
    _setHeaders(s, kRetailImportHeaderRow, header);

    const hints = {
      RetailImportColumn.handle: 'Groups variants — same Handle = same product',
      RetailImportColumn.name: 'Product name (on the first row of each group)',
      RetailImportColumn.category: 'Pick a category',
      RetailImportColumn.description: 'Optional, first row only',
      RetailImportColumn.option1Name: 'e.g. Size',
      RetailImportColumn.option1Value: 'e.g. Small',
      RetailImportColumn.option2Name: 'e.g. Color',
      RetailImportColumn.option2Value: 'e.g. Red',
      RetailImportColumn.option3Name: '',
      RetailImportColumn.option3Value: '',
      RetailImportColumn.costPrice: 'Optional',
      RetailImportColumn.sellingPrice: 'Required: number only',
      RetailImportColumn.mrp: 'Optional',
      RetailImportColumn.stock: 'Optional, defaults to 0',
      RetailImportColumn.barcode:
          'Optional — generated if blank, must be unique',
      RetailImportColumn.minStock: 'Optional, defaults to 5',
      RetailImportColumn.taxRate:
          'Pick a tax rate (first row of each group only)',
      RetailImportColumn.hsnCode: 'Optional, first row only',
      RetailImportColumn.sku: 'Optional — generated if blank',
      RetailImportColumn.unit:
          'piece = whole numbers. kg/gm/liter/ml allow decimals. First row only',
      RetailImportColumn.expiryDate: 'Optional, YYYY-MM-DD. First row only',
    };
    _setInstruction(
      s,
      RetailImportColumn.values.map((c) => hints[c] ?? '').toList(),
      instr,
    );

    final sampleTax = taxLabels.isNotEmpty ? taxLabels.first : '';
    int row = 3;
    void sample(List<dynamic> values) => _setRow(s, row++, values);

    // 1. Simple product, no variants, no tax. Barcode and SKU left blank on
    //    purpose to show they are generated.
    sample(
      _productRow(
        handle: 'coke_can',
        name: 'Coca Cola 330ml',
        category: 'Grocery',
        description: 'Refreshing drink',
        cost: 0.50,
        price: 1.00,
        mrp: 1.20,
        stock: 100,
        minStock: 10,
        unit: 'piece',
      ),
    );

    // 2. Simple product WITH tax, HSN, an explicit barcode and SKU.
    sample(
      _productRow(
        handle: 'bt_earbuds',
        name: 'Bluetooth Earbuds',
        category: 'Electronics',
        description: 'Wireless earbuds with charging case',
        cost: 15.00,
        price: 25.00,
        mrp: 30.00,
        stock: 40,
        barcode: 'BT-EARBUDS-01',
        minStock: 5,
        tax: sampleTax,
        hsn: '85183000',
        sku: 'ELE-000101',
        unit: 'piece',
      ),
    );

    // 3. LOOSE GOODS — sold by weight. Unit "kg" is what makes fractional
    //    Stock legal; a "piece" product with 12.5 in Stock is rejected.
    sample(
      _productRow(
        handle: 'potato',
        name: 'Potato (Loose)',
        category: 'Grocery',
        description: 'Sold by weight',
        cost: 18.00,
        price: 30.00,
        stock: 12.5,
        minStock: 5,
        unit: 'kg',
      ),
    );

    // 4. PERISHABLE — an expiry date on the product row.
    sample(
      _productRow(
        handle: 'milk_1l',
        name: 'Full Cream Milk 1L',
        category: 'Grocery',
        description: 'Keep refrigerated',
        cost: 48.00,
        price: 62.00,
        stock: 24,
        minStock: 6,
        unit: 'piece',
        expiry: '2026-12-31',
      ),
    );

    // 5. Single-option variant product (Size only).
    for (final variant in const [
      ('S', 2.00, 6.00, 7.00, 30, 'SOCK-S'),
      ('M', 2.00, 6.00, 7.00, 25, 'SOCK-M'),
      ('L', 2.20, 6.50, 7.50, 20, 'SOCK-L'),
    ]) {
      sample(
        _productRow(
          handle: 'cotton_socks',
          name: 'Cotton Socks',
          category: 'Clothing',
          description: 'Comfortable cotton socks',
          opt1Name: 'Size',
          opt1Value: variant.$1,
          cost: variant.$2,
          price: variant.$3,
          mrp: variant.$4,
          stock: variant.$5,
          barcode: variant.$6,
          minStock: 5,
          // Unit/expiry/tax on the FIRST row of the group only.
          unit: variant.$1 == 'S' ? 'piece' : '',
        ),
      );
    }

    // 6. Two-option variant product (Size + Color). Tax, HSN and Unit are on
    //    the first/parent row only. Note Size "S" repeats with a different
    //    Color each time — more values for an option means more ROWS, never a
    //    new column. Columns are the option *types* (Size, Color).
    for (final variant in const [
      ('S', 'Red', 5.00, 15.00, 18.00, 20, 'TS-RED-S'),
      ('S', 'Blue', 5.00, 15.00, 18.00, 12, 'TS-BLU-S'),
      ('M', 'Red', 5.00, 15.00, 18.00, 15, 'TS-RED-M'),
      ('L', 'Blue', 6.00, 16.00, 19.00, 10, 'TS-BLU-L'),
    ]) {
      final isFirst = variant.$7 == 'TS-RED-S';
      sample(
        _productRow(
          handle: 'tshirt_vneck',
          name: 'V-Neck T-Shirt',
          category: 'Clothing',
          description: 'Cotton T-Shirt',
          opt1Name: 'Size',
          opt1Value: variant.$1,
          opt2Name: 'Color',
          opt2Value: variant.$2,
          cost: variant.$3,
          price: variant.$4,
          mrp: variant.$5,
          stock: variant.$6,
          barcode: variant.$7,
          minStock: 5,
          tax: isFirst ? sampleTax : '',
          hsn: isFirst ? '6109' : '',
          unit: isFirst ? 'piece' : '',
        ),
      );
    }

    // Category dropdown — live from the Categories sheet (column B, data row 3+).
    _dropdownFromRange(
      s,
      RetailImportColumn.category,
      categorySource.getRangeByName('B3:B$_listSourceLastRow'),
      prompt: 'Pick a category (add new ones in the Categories sheet).',
      addSheet: 'Categories',
    );

    // Unit dropdown — the app's canonical list, so a value that cannot be
    // stored can't be typed in the first place.
    _dropdownFromList(
      s,
      RetailImportColumn.unit,
      kItemUnits,
      prompt:
          'piece = whole numbers only. kg/gm/liter/ml allow decimal '
          'quantities. Fill on the first row of each Handle.',
      errorText: 'Use one of: ${kItemUnits.join(', ')}.',
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
    for (int r = 3; r <= _listSourceLastRow; r++) {
      taxSource
          .getRangeByIndex(r, 3)
          .setFormula('=IF(A$r="","",A$r&" ("&B$r&"%)")');
    }
    taxSource.getRangeByIndex(1, 3).columnWidth = 20;
    _dropdownFromRange(
      s,
      RetailImportColumn.taxRate,
      taxSource.getRangeByName('C3:C$_listSourceLastRow'),
      prompt: 'Pick a tax rate (add new ones in the Taxes sheet).',
      addSheet: 'Taxes',
    );
  }
}
