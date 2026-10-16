import 'package:syncfusion_flutter_xlsio/xlsio.dart';

import '../../../../core/config/tariff_code_rule.dart';
import '../../../../core/config/tax_label_rule.dart';
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

  /// First data row on every sheet — row 1 is headers, row 2 the yellow
  /// instruction row.
  static const int _firstDataRow = 3;

  /// Blank rows the Category/Tax dropdowns reach BEYOND the seeded ones, so a
  /// category or rate typed onto the reference sheet shows up in the Products
  /// dropdown without regenerating the template.
  ///
  /// It has to be a fixed pad. Excel resolves a list validation against a
  /// static A1 range and xlsio cannot emit anything else — its `list` branch
  /// (`serialize_workbook.dart`) writes `dataRangeVal.addressGlobal` and
  /// ignores `firstFormula`, so the usual self-expanding tricks (a defined name
  /// over `OFFSET`/`COUNTA`, or a Table column) have no way in.
  ///
  /// The cost is that Excel lists every cell of the source, so the spare rows
  /// show as blank entries at the END of the dropdown. Twenty is the trade:
  /// room for real additions without burying the seeded values.
  static const int _spareListRows = 20;

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
    final categoryNames = _buildCategories(categories, header, instr);
    final taxLabels = _buildTaxes(taxes, header, instr);
    _buildProducts(
      products,
      header,
      instr,
      categorySource: categories,
      categoryNames: categoryNames,
      taxSource: taxes,
      taxLabels: taxLabels,
    );

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

  /// A dropdown that reads its options from a column on another sheet.
  ///
  /// [rowCount] is the number of rows seeded on that sheet; the range reaches
  /// [_spareListRows] past them so rows the owner types later are included.
  ///
  /// "Allow other" behaviour is implicit: the error style is a warning, so
  /// owners can still type a value that is not in the list and it is picked up
  /// on import.
  void _dropdownFromRange(
    Worksheet s,
    RetailImportColumn column,
    Worksheet source,
    int sourceColumn,
    int rowCount, {
    required String prompt,
    required String errorText,
    int fromRow = _firstDataRow,
  }) {
    final int lastSourceRow = _firstDataRow + rowCount + _spareListRows - 1;
    if (lastSourceRow < _firstDataRow) return;

    final Range r = s.getRangeByIndex(
      fromRow,
      _col(column),
      _validationLastRow,
      _col(column),
    );
    final dv = r.dataValidation;
    dv.allowType = ExcelDataValidationType.user;
    dv.dataRange = source.getRangeByIndex(
      _firstDataRow,
      sourceColumn,
      lastSourceRow,
      sourceColumn,
    );
    dv.promptBoxText = prompt;
    dv.showPromptBox = true;
    dv.errorStyle = ExcelDataValidationErrorStyle.warning;
    dv.errorBoxTitle = 'Not in list';
    dv.errorBoxText = errorText;
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

    final taxName = TaxLabelRule.name;

    line('QUICK START', style: section);
    line(
      '1. Fill the "Products" sheet — it is the ONLY sheet that gets imported.',
    );
    line(
      '2. Use the dropdowns for Category, $taxName Rate and Unit where you can.',
    );
    line(
      '3. One row per variant. Give every variant of the same product the same Handle.',
    );
    line('4. Save this file and import it back into Bill Berry Lite.');
    r++;
    line('NEW CATEGORIES AND $taxName RATES', style: section);
    line(
      '• To add a category: type its name in the first empty row of the "Categories" sheet.',
    );
    line(
      '  It appears in the Products sheet dropdown straight away. Room for $_spareListRows more.',
    );
    line(
      '• To add a $taxName rate: type it in the first empty row of the "Taxes" sheet, written',
    );
    line(
      '  the same way as the ones already there — e.g. "$taxName (12%)".',
    );
    line(
      '• The blank entries at the END of those dropdowns are the spare rows waiting to be filled.',
    );
    line(
      '• You can also just TYPE a category or rate straight into the Products sheet. Excel warns',
    );
    line(
      '  that it is not in the list — choose Yes. It is created when you import.',
    );
    line(
      '• Only the "Products" sheet is imported. The other two feed the dropdowns and keep your',
    );
    line('  spelling consistent.');
    r++;
    line('TIPS', style: section);
    line(
      '• Do NOT delete or rename row 1 — the header row is how columns are recognised.',
    );
    line(
      '• Cells with a dropdown show a small arrow — click it to pick a value.',
    );
    line('• Click any header cell to read its tooltip (what to enter).');
    line('• Required columns are marked with * in the header row.');
    line(
      '• Price and Stock must be numbers only (no currency symbols, no 1,000 separators).',
    );
    r++;
    line('OPTIONS AND VARIANTS', style: section);
    line(
      '• Option columns are the option TYPES — Size, Color, Material. Up to 5 per product.',
    );
    line(
      '• More option VALUES (S, M, L, XL, XXL) means more ROWS, never more columns.',
    );
    line(
      '  e.g. Size S/M/L in Red and Blue = 6 rows, all sharing one Handle, using 2 option columns.',
    );
    line(
      '• Every row of a product must have a DIFFERENT combination of option values.',
    );
    line(
      '• A product with no variants leaves every Option column blank and uses a single row.',
    );
    r++;
    line('UNIT, STOCK AND EXPIRY', style: section);
    line(
      '• Unit, $taxName Rate, ${TariffCodeRule.label} and Expiry Date belong to the PRODUCT — fill them on the first row of each Handle only.',
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
    // This sheet feeds the Products dropdown but is never imported itself; a
    // category only reaches the app by being used on a Products row.
    _setInstruction(s, [
      'Leave blank — filled in automatically',
      'Add a category in the first empty row and it appears in the Products '
          'dropdown. Room for $_spareListRows more.',
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

  /// India's official GST slabs — the only rates in the app that are safe to
  /// pre-fill. Mirrors `taxSetupStep.dart`'s preset chips deliberately: that
  /// screen offers no presets outside India because VAT and sales-tax rates
  /// vary far too much per country to guess, and a wrong pre-filled rate is
  /// worse than an empty sheet the owner has to fill in.
  static const List<int> _indiaGstSlabs = [5, 12, 18, 28];

  /// 1-based column on the Taxes sheet the Products dropdown reads.
  static const int _taxLabelColumn = 1;

  /// ONE literal column, exactly like Categories — deliberately not a
  /// name + rate pair with a computed label beside it.
  ///
  /// That earlier shape needed a formula so a hand-added row could build its
  /// own label, and formulas cannot survive this writer: xlsio emits the string
  /// verbatim into `<f>`, leading `=` included, which OOXML forbids, and never
  /// writes a cached `<v>`. Excel could not resolve those cells, and a list
  /// validation whose source it cannot resolve renders ENTIRELY blank — taking
  /// the perfectly good literal rows above them down too.
  ///
  /// So the column the owner types into is the column the dropdown reads, and
  /// nothing in this workbook computes anything.
  List<String> _buildTaxes(Worksheet s, Style header, Style instr) {
    final taxName = TaxLabelRule.name;
    _setHeaders(s, ['$taxName rate*'], header);
    _setInstruction(s, [
      'These fill the Products dropdown. Add one in the first empty row, '
          'written the same way — e.g. "$taxName (12%)".',
    ], instr);

    final labels = <String>[];
    void seed(String label) {
      labels.add(label);
      _setRow(s, _firstDataRow + labels.length - 1, [label]);
    }

    final existingTaxes = taxStore.taxes;
    if (existingTaxes.isNotEmpty) {
      for (final tax in existingTaxes) {
        seed(retailTaxLabel(tax.taxname, tax.taxperecentage ?? 0));
      }
    } else if (TaxLabelRule.isIndia) {
      // Everywhere else the sheet is left empty on purpose — the owner types
      // their own rates. The Instructions sheet says so.
      for (final rate in _indiaGstSlabs) {
        seed(retailTaxLabel(taxName, rate));
      }
    }

    s.getRangeByIndex(1, 1, 1, _taxLabelColumn).columnWidth = 24;
    return labels;
  }

  // ── Products (the actual data-entry sheet) ─────────────────────────────────

  /// Builds one Products row from named values, so a 25-column sample stays
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
    String opt4Name = '',
    String opt4Value = '',
    String opt5Name = '',
    String opt5Value = '',
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
    put(RetailImportColumn.unit, unit);
    put(RetailImportColumn.taxRate, tax);
    put(RetailImportColumn.hsnCode, hsn);
    put(RetailImportColumn.expiryDate, expiry);
    put(RetailImportColumn.option1Name, opt1Name);
    put(RetailImportColumn.option1Value, opt1Value);
    put(RetailImportColumn.option2Name, opt2Name);
    put(RetailImportColumn.option2Value, opt2Value);
    put(RetailImportColumn.option3Name, opt3Name);
    put(RetailImportColumn.option3Value, opt3Value);
    put(RetailImportColumn.option4Name, opt4Name);
    put(RetailImportColumn.option4Value, opt4Value);
    put(RetailImportColumn.option5Name, opt5Name);
    put(RetailImportColumn.option5Value, opt5Value);
    put(RetailImportColumn.sku, sku);
    put(RetailImportColumn.barcode, barcode);
    put(RetailImportColumn.costPrice, cost);
    put(RetailImportColumn.sellingPrice, price);
    put(RetailImportColumn.mrp, mrp);
    put(RetailImportColumn.stock, stock);
    put(RetailImportColumn.minStock, minStock);
    return values;
  }

  void _buildProducts(
    Worksheet s,
    Style header,
    Style instr, {
    required Worksheet categorySource,
    required List<String> categoryNames,
    required Worksheet taxSource,
    required List<String> taxLabels,
  }) {
    // Headers come from the parser's own list — one source of truth.
    _setHeaders(s, kRetailImportHeaderRow, header);

    const hints = {
      RetailImportColumn.handle: 'Groups variants — same Handle = same product',
      RetailImportColumn.name: 'Product name (on the first row of each group)',
      RetailImportColumn.category: 'Pick a category',
      RetailImportColumn.description: 'Optional, first row only',
      RetailImportColumn.unit:
          'piece = whole numbers. kg/gm/liter/ml allow decimals. First row only',
      RetailImportColumn.taxRate:
          'Pick a rate (first row of each group only)',
      RetailImportColumn.hsnCode: 'Optional, first row only',
      RetailImportColumn.expiryDate: 'Optional, YYYY-MM-DD. First row only',
      RetailImportColumn.option1Name: 'e.g. Size',
      RetailImportColumn.option1Value: 'e.g. Small',
      RetailImportColumn.option2Name: 'e.g. Color',
      RetailImportColumn.option2Value: 'e.g. Red',
      RetailImportColumn.option3Name: 'e.g. Material',
      RetailImportColumn.option3Value: 'e.g. Cotton',
      RetailImportColumn.option4Name: 'Optional 4th option type',
      RetailImportColumn.option4Value: '',
      RetailImportColumn.option5Name: 'Optional 5th option type',
      RetailImportColumn.option5Value: '',
      RetailImportColumn.sku: 'Optional — generated if blank',
      RetailImportColumn.barcode:
          'Optional — generated if blank, must be unique',
      RetailImportColumn.costPrice: 'Optional',
      RetailImportColumn.sellingPrice: 'Required: number only',
      RetailImportColumn.mrp: 'Optional',
      RetailImportColumn.stock: 'Optional, defaults to 0',
      RetailImportColumn.minStock: 'Optional, blank uses the shop low-stock level',
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

    // 7. THREE option types on one product, so the wider Option block is not
    //    left unexplained. Option4/5 exist for the same reason and need no
    //    sample of their own — they behave identically.
    for (final variant in const [
      ('M', 'Black', 'Leather', 45.00, 90.00, 8, 'BELT-M-BLK-L'),
      ('L', 'Brown', 'Canvas', 30.00, 65.00, 6, 'BELT-L-BRN-C'),
    ]) {
      final isFirst = variant.$1 == 'M';
      sample(
        _productRow(
          handle: 'belt_classic',
          name: 'Classic Belt',
          category: 'Clothing',
          description: 'Adjustable belt',
          opt1Name: 'Size',
          opt1Value: variant.$1,
          opt2Name: 'Color',
          opt2Value: variant.$2,
          opt3Name: 'Material',
          opt3Value: variant.$3,
          cost: variant.$4,
          price: variant.$5,
          stock: variant.$6,
          barcode: variant.$7,
          minStock: 3,
          unit: isFirst ? 'piece' : '',
        ),
      );
    }

    // Category dropdown — the Categories sheet's name column (B), sized to the
    // rows actually seeded.
    _dropdownFromRange(
      s,
      RetailImportColumn.category,
      categorySource,
      2,
      categoryNames.length,
      prompt: 'Pick a category, or type a new one — it is created on import.',
      errorText:
          'Not one of your existing categories. You can still use it — a new '
          'category is created when the file is imported.',
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

    // Tax dropdown — the Taxes sheet's ready-made "Name (Rate%)" label column,
    // written there as literal text by [_buildTaxes]. Skipped entirely when the
    // shop has no rates seeded: an empty dropdown reads as a broken one.
    final taxName = TaxLabelRule.name;
    _dropdownFromRange(
      s,
      RetailImportColumn.taxRate,
      taxSource,
      _taxLabelColumn,
      taxLabels.length,
      prompt: 'Pick a $taxName rate. First row of each Handle only.',
      errorText:
          'Not one of your saved $taxName rates. You can still type your own, '
          'written like "$taxName (12%)" or just 12.',
    );
  }
}
