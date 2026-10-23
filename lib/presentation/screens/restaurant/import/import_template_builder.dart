import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:billberrylite/core/constants/item_units.dart';

/// Builds the bulk-import Excel template using Syncfusion xlsio so we can add
/// real Data Validation dropdowns + input-prompt tooltips (the `excel` package
/// used for *reading* the file cannot write these).
///
/// IMPORTANT — row layout must match what the importer expects (the importer
/// uses the `excel` package which is 0-based):
///   • Most sheets: header (row 1), yellow instruction (row 2), data (row 3+)
///   • Extras / Toppings: header (row 1), data (row 2+) — NO instruction row
/// xlsio is 1-based, so those numbers are the literal xlsio row indices.
class ImportTemplateBuilder {
  // Seed values — also power the dropdowns so the lists always match the data.
  static const List<String> categories = [
    'Starters', 'Soups', 'Salads', 'Main Course', 'Breads',
    'Rice & Biryani', 'Chinese', 'Tandoori', 'Rolls & Wraps',
    'Burgers', 'Sandwiches', 'Pizza', 'Desserts', 'Ice Creams', 'Beverages',
  ];
  static const List<String> variantNames = [
    'Half', 'Full', 'Small', 'Medium', 'Large', 'Regular', 'Family Size',
  ];
  static const List<String> vegTypes = ['Veg', 'Non-Veg', 'Egg'];
  static const List<String> yesNo = ['Yes', 'No'];
  // Shared with the Add/Edit Item dropdowns so picked units are always editable.
  static const List<String> units = kItemUnits;

  /// Last data row dropdowns/validation are applied to.
  static const int _validationLastRow = 500;

  /// Last row the Category/Variant *source* lists span. The dropdowns read this
  /// range live, so categories/variants added up to this row reflect instantly.
  /// (A fixed range is required for a range-based dropdown; trailing blanks are
  /// the unavoidable cost of reflecting new entries.)
  static const int _listSourceLastRow = 40;

  /// Items can be numerous, so the ItemName dropdown (used by ItemVariants)
  /// reads a wider range than the small reference lists.
  static const int _itemSourceLastRow = 200;

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

    // Create all sheets first (fixes tab order AND lets Items/ItemVariants
    // reference the Categories/Variants ranges for live dropdowns).
    final Worksheet instructions = wb.worksheets[0]..name = 'Instructions';
    final Worksheet cat = wb.worksheets.addWithName('Categories');
    final Worksheet items = wb.worksheets.addWithName('Items');
    final Worksheet itemVariants = wb.worksheets.addWithName('ItemVariants');
    final Worksheet variants = wb.worksheets.addWithName('Variants');
    final Worksheet extras = wb.worksheets.addWithName('Extras');
    final Worksheet toppings = wb.worksheets.addWithName('Toppings');
    final Worksheet choices = wb.worksheets.addWithName('Choices');
    final Worksheet choiceOptions = wb.worksheets.addWithName('ChoiceOptions');

    _buildInstructions(instructions, titleStyle, sectionStyle);
    _buildCategories(cat, header, instr);
    _buildVariants(variants, header, instr);
    _buildItems(items, header, instr, cat, choices, extras);
    _buildItemVariants(itemVariants, header, instr, variants, items);
    _buildExtras(extras, header);
    _buildToppings(toppings, header, extras, variants);
    _buildChoices(choices, header, instr);
    _buildChoiceOptions(choiceOptions, header, instr, choices);

    final List<int> bytes = wb.saveAsStream();
    wb.dispose();
    return bytes;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  /// One data row. xlsio row index is 1-based; pass the literal row.
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

  /// Apply a dropdown to a column for the data rows.
  /// [allowOther] = true keeps the dropdown but lets users type values not in
  /// the list (used for Category/Variant where owners add their own).
  void _dropdown(
    Worksheet s,
    int col,
    List<String> values, {
    required String prompt,
    bool allowOther = false,
    int fromRow = 3,
  }) {
    final Range r = s.getRangeByIndex(fromRow, col, _validationLastRow, col);
    final dv = r.dataValidation;
    dv.listOfValues = values;
    dv.promptBoxText = prompt;
    dv.showPromptBox = true;
    dv.errorBoxText = allowOther
        ? 'Tip: pick from the list, or type your own value.'
        : 'Please pick a value from the dropdown list.';
    dv.errorBoxTitle = 'Invalid value';
    // allowOther → warning style so custom entries are still accepted.
    dv.errorStyle =
        allowOther ? ExcelDataValidationErrorStyle.warning : ExcelDataValidationErrorStyle.stop;
  }

  /// A LIVE dropdown that reads its options from [source] (a column on another
  /// sheet). Unlike [_dropdown], values added to that sheet later show up here.
  /// Leaving listOfValues empty makes xlsio serialize the dataRange reference.
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
    // Warning (not block) so owners can still type a brand-new value; adding it
    // to the $addSheet sheet makes it appear in this dropdown next time.
    dv.errorStyle = ExcelDataValidationErrorStyle.warning;
    dv.errorBoxTitle = 'Not in list';
    dv.errorBoxText = 'Pick from the list, or add it to the $addSheet sheet first.';
  }

  // ── Instructions ─────────────────────────────────────────────────────────────

  void _buildInstructions(Worksheet s, Style title, Style section) {
    s.getRangeByIndex(1, 1).setText('Bill Berry Lite Restaurant Bulk Import');
    s.getRangeByIndex(1, 1).cellStyle = title;

    int r = 3;
    void line(String t, {Style? style}) {
      s.getRangeByIndex(r, 1).setText(t);
      if (style != null) s.getRangeByIndex(r, 1).cellStyle = style;
      r++;
    }

    line('QUICK START', style: section);
    line('1. Add your categories in the "Categories" sheet.');
    line('2. Fill the "Items" sheet — use the dropdowns for Category, Veg Type, Unit and Yes/No fields.');
    line('3. (Optional) Add sizes in "ItemVariants", and extras/choices in their sheets.');
    line('4. Save this file and import it back into Bill Berry Lite.');
    r++;
    line('TIPS', style: section);
    line('• Cells with a dropdown show a small arrow — click it to pick a value.');
    line('• Click any header cell to read its tooltip (what to enter).');
    line('• Required columns are marked with * in the header row.');
    line('• Sample rows are provided — edit or delete them and add your own.');
    line('• Price must be a number only (no currency symbols).');

    s.getRangeByIndex(1, 1).columnWidth = 90;
  }

  // ── Categories ───────────────────────────────────────────────────────────────

  void _buildCategories(Worksheet s, Style header, Style instr) {
    _setHeaders(s, ['id*', 'name*', 'imagePath'], header);
    _setInstruction(s, [
      'Unique ID (e.g., cat_pizza)',
      'Category name (e.g., Pizza)',
      'Optional image URL',
    ], instr);
    for (int i = 0; i < categories.length; i++) {
      final name = categories[i];
      _setRow(s, 3 + i, ['cat_${name.toLowerCase().replaceAll(' ', '_')}', name, '']);
    }
    s.getRangeByIndex(1, 1, 1, 3).autoFitColumns();
  }

  // ── Items ────────────────────────────────────────────────────────────────────

  void _buildItems(Worksheet s, Style header, Style instr, Worksheet categorySource,
      Worksheet choiceSource, Worksheet extraSource) {
    _setHeaders(s, [
      'ItemName*', 'ItemCode', 'Price*', 'CategoryName*', 'VegType*', 'Description',
      'ImageURL', 'IsSoldByWeight', 'Unit', 'TrackInventory',
      'StockQuantity', 'AllowOutOfStock', 'LowStockThreshold', 'LowStockAlertEnabled',
      'TaxRate', 'IsEnabled', 'IsFavorite',
      'HasVariants', 'Choice1', 'Choice2', 'Choice3', 'Extra1', 'Extra2', 'Extra3',
    ], header);
    _setInstruction(s, [
      'Required: item name', 'Optional: unique 4-5 digit code', 'Required: number only', 'Required: pick a category',
      'Required: Veg / Non-Veg / Egg', 'Optional', 'Optional image URL',
      'Yes/No', 'By weight: kg/gm/liter/ml · otherwise piece or blank', 'Yes/No', 'Number (0 if not tracked)',
      'Yes/No', 'Low-stock alert level (blank = default)', 'Yes/No',
      'Number 0-100', 'Yes/No', 'Yes/No (pin to Favorites)',
      'Yes/No',
      'Pick a choice', 'Pick a choice', 'Pick a choice',
      'Pick an extra', 'Pick an extra', 'Pick an extra',
    ], instr);

    // ItemCode uses the 2xxx range so the samples never collide with the app's
    // auto-assigner (which starts at 1001). Codes are passed as strings so Excel
    // stores them as "2001", not "2001.0" (the importer validates 4-5 digits).
    // Columns: Name, Code, Price, Category, Veg, Desc, Img, ByWeight, Unit,
    // Track, Stock, AllowOOS, LowThresh, LowAlert, Tax, Enabled, Fav, HasVar,
    // Choice1-3, Extra1-3.
    _setRow(s, 3,  ['Margherita Pizza', '2001', 0, 'Pizza', 'Veg', 'Classic tomato & mozzarella', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'Yes', 'Yes', 'Crust Type', 'Spice Level', '', 'Toppings', 'Cheese Options', '']);
    _setRow(s, 4,  ['Farmhouse Pizza', '2002', 0, 'Pizza', 'Veg', 'Onion, capsicum, tomato & mushroom', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'Yes', 'Crust Type', '', '', 'Toppings', 'Cheese Options', '']);
    _setRow(s, 5,  ['Paneer Butter Masala', '2003', 220, 'Main Course', 'Veg', 'Cottage cheese in tomato cream', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'Yes', 'No', '', '', '', '', '', '']);
    _setRow(s, 6,  ['Butter Chicken', '2004', 260, 'Main Course', 'Non-Veg', 'Chicken in rich buttery gravy', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'No', 'Spice Level', '', '', '', '', '']);
    _setRow(s, 7,  ['Veg Hakka Noodles', '2005', 150, 'Chinese', 'Veg', 'Stir-fried noodles with vegetables', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'No', 'Spice Level', '', '', '', '', '']);
    _setRow(s, 8,  ['Chicken Biryani', '2006', 240, 'Rice & Biryani', 'Non-Veg', 'Aromatic basmati rice with chicken', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'Yes', 'No', 'Spice Level', '', '', '', '', '']);
    _setRow(s, 9,  ['Butter Naan', '2007', 40, 'Breads', 'Veg', 'Soft tandoori bread with butter', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    _setRow(s, 10, ['Tandoori Chicken', '2008', 0, 'Tandoori', 'Non-Veg', 'Char-grilled marinated chicken', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'Yes', 'Spice Level', '', '', '', '', '']);
    _setRow(s, 11, ['Veg Spring Roll', '2009', 120, 'Starters', 'Veg', 'Crispy rolls with veg filling', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    _setRow(s, 12, ['Masala Chai', '2010', 40, 'Beverages', 'Veg', 'Spiced Indian tea', '', 'No', '', 'No', 0, 'Yes', '', 'No', 0, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    // Inventory example — tracks stock and fires a low-stock alert at 10 units.
    _setRow(s, 13, ['Cold Coffee', '2011', 90, 'Beverages', 'Veg', 'Chilled coffee with ice cream', '', 'No', '', 'Yes', 50, 'Yes', 10, 'Yes', 5, 'Yes', 'Yes', 'No', '', '', '', '', '', '']);
    _setRow(s, 14, ['Gulab Jamun', '2012', 80, 'Desserts', 'Veg', 'Warm milk-solid dumplings in syrup', '', 'No', '', 'No', 0, 'Yes', '', 'No', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    // By-weight example — shows how Unit is used (Yes + kg) plus low-stock alert.
    _setRow(s, 15, ['Kaju Katli (per kg)', '2013', 700, 'Desserts', 'Veg', 'Cashew fudge sold by weight', '', 'Yes', 'kg', 'Yes', 5, 'Yes', 1, 'Yes', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);

    // ── Inventory test set — each row demonstrates a different stock state ──
    // Healthy: stock (100) well above the alert threshold (15).
    _setRow(s, 16, ['Fresh Lime Soda', '2014', 50, 'Beverages', 'Veg', 'Refreshing lime soda', '', 'No', '', 'Yes', 100, 'Yes', 15, 'Yes', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    // Low stock: on-hand (8) is at/below the threshold (10) → low-stock alert fires.
    _setRow(s, 17, ['Bottled Water', '2015', 20, 'Beverages', 'Veg', 'Packaged drinking water 1L', '', 'No', '', 'Yes', 8, 'Yes', 10, 'Yes', 0, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    // Out of stock + AllowOutOfStock No → item is BLOCKED from ordering.
    _setRow(s, 18, ['Chocolate Brownie', '2016', 110, 'Desserts', 'Veg', 'Rich fudgy brownie', '', 'No', '', 'Yes', 0, 'No', 5, 'Yes', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    // Out of stock + AllowOutOfStock Yes → still sellable (backorder-style).
    _setRow(s, 19, ['Mango Lassi', '2017', 70, 'Beverages', 'Veg', 'Sweet yogurt mango drink', '', 'No', '', 'Yes', 0, 'Yes', 5, 'Yes', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);
    // Healthy non-veg starter — decrement its stock as you sell to watch it drop.
    _setRow(s, 20, ['Chicken Wings', '2018', 180, 'Starters', 'Non-Veg', 'Spicy fried chicken wings', '', 'No', '', 'Yes', 25, 'Yes', 8, 'Yes', 5, 'Yes', 'No', 'No', '', '', '', '', '', '']);

    // Single-value dropdowns (columns are 1-based: A=1 … X=24)
    _dropdownFromRange(
      s,
      4,
      categorySource.getRangeByName('B3:B$_listSourceLastRow'),
      prompt: 'Pick a category (add new ones in the Categories sheet).',
      addSheet: 'Categories',
    );
    _dropdown(s, 5, vegTypes, prompt: 'Choose Veg, Non-Veg or Egg.');
    _dropdown(s, 8, yesNo, prompt: 'Is this item sold by weight?');
    _dropdown(s, 9, units, prompt: 'Unit of measure.');
    _dropdown(s, 10, yesNo, prompt: 'Track stock for this item?');
    _dropdown(s, 12, yesNo, prompt: 'Allow selling when out of stock?');
    _dropdown(s, 14, yesNo, prompt: 'Alert when stock is low?');
    _dropdown(s, 16, yesNo, prompt: 'Is this item enabled/visible?');
    _dropdown(s, 17, yesNo, prompt: 'Pin this item to the Favorites tab?');
    _dropdown(s, 18, yesNo, prompt: 'Does this item have sizes (variants)?');

    // Choice columns (19-21) read LIVE from the Choices sheet name column.
    // Choices has an instruction row, so its data starts at row 3.
    for (final col in [19, 20, 21]) {
      _dropdownFromRange(
        s,
        col,
        choiceSource.getRangeByName('B3:B$_listSourceLastRow'),
        prompt: 'Pick a choice group (add new ones in the Choices sheet).',
        addSheet: 'Choices',
      );
    }
    // Extra columns (22-24) read LIVE from the Extras sheet name column.
    // Extras has NO instruction row, so its data starts at row 2.
    for (final col in [22, 23, 24]) {
      _dropdownFromRange(
        s,
        col,
        extraSource.getRangeByName('B2:B$_listSourceLastRow'),
        prompt: 'Pick an extra group (add new ones in the Extras sheet).',
        addSheet: 'Extras',
      );
    }
  }

  // ── ItemVariants ─────────────────────────────────────────────────────────────

  void _buildItemVariants(Worksheet s, Style header, Style instr, Worksheet variantSource,
      Worksheet itemSource) {
    _setHeaders(s, ['itemName*', 'variantName*', 'price*', 'trackInventory', 'stockQuantity'], header);
    _setInstruction(s, [
      'Must match an item name', 'Pick a size', 'Price for this size',
      'Yes/No', 'Number (0 if not tracked)',
    ], instr);

    _setRow(s, 3, ['Margherita Pizza', 'Small', 199, 'No', 0]);
    _setRow(s, 4, ['Margherita Pizza', 'Medium', 299, 'No', 0]);
    _setRow(s, 5, ['Margherita Pizza', 'Large', 399, 'No', 0]);
    _setRow(s, 6, ['Farmhouse Pizza', 'Small', 249, 'No', 0]);
    _setRow(s, 7, ['Farmhouse Pizza', 'Medium', 349, 'No', 0]);
    _setRow(s, 8, ['Farmhouse Pizza', 'Large', 449, 'No', 0]);
    _setRow(s, 9, ['Tandoori Chicken', 'Half', 180, 'No', 0]);
    _setRow(s, 10, ['Tandoori Chicken', 'Full', 320, 'No', 0]);

    // itemName reads LIVE from the Items sheet (column A, data from row 3).
    _dropdownFromRange(
      s,
      1,
      itemSource.getRangeByName('A3:A$_itemSourceLastRow'),
      prompt: 'Pick an item (must match the Items sheet).',
      addSheet: 'Items',
    );
    // Variant reads LIVE from the Variants sheet, so new sizes appear.
    _dropdownFromRange(
      s,
      2,
      variantSource.getRangeByName('B3:B$_listSourceLastRow'),
      prompt: 'Pick a size (add new ones in the Variants sheet).',
      addSheet: 'Variants',
    );
    _dropdown(s, 4, yesNo, prompt: 'Track stock for this size?');
  }

  // ── Variants ─────────────────────────────────────────────────────────────────

  void _buildVariants(Worksheet s, Style header, Style instr) {
    _setHeaders(s, ['id*', 'name*'], header);
    _setInstruction(s, ['Unique ID (e.g., var_small)', 'Size name (e.g., Small)'], instr);
    for (int i = 0; i < variantNames.length; i++) {
      final name = variantNames[i];
      _setRow(s, 3 + i, ['var_${name.toLowerCase().replaceAll(' ', '_')}', name]);
    }
  }

  // ── Extras (no instruction row) ──────────────────────────────────────────────

  void _buildExtras(Worksheet s, Style header) {
    _setHeaders(s, ['id', 'name', 'isEnabled', 'minimum', 'maximum'], header);
    _setRow(s, 2, ['extra_toppings', 'Toppings', 'Yes', 0, 5]);
    _setRow(s, 3, ['extra_cheese', 'Cheese Options', 'Yes', 0, 3]);
    // Yes/No dropdown for isEnabled — data starts row 2 here.
    _dropdown(s, 3, yesNo, prompt: 'Is this extra group enabled?', fromRow: 2);
  }

  // ── Toppings (no instruction row) ────────────────────────────────────────────

  void _buildToppings(Worksheet s, Style header, Worksheet extraSource, Worksheet variantSource) {
    _setHeaders(s, ['extraId', 'name', 'isveg', 'price', 'isContainSize', 'variantId', 'variantPrice'], header);
    _setRow(s, 2, ['extra_toppings', 'Olives', 'Yes', 15, 'No', '', '']);
    _setRow(s, 3, ['extra_toppings', 'Mushrooms', 'Yes', 20, 'No', '', '']);
    _setRow(s, 4, ['extra_cheese', 'Mozzarella', 'Yes', 30, 'No', '', '']);
    // extraId picks an Extra group by its id (Extras column A, data from row 2).
    _dropdownFromRange(
      s,
      1,
      extraSource.getRangeByName('A2:A$_listSourceLastRow'),
      prompt: 'Pick the extra group this topping belongs to.',
      addSheet: 'Extras',
      fromRow: 2,
    );
    _dropdown(s, 3, vegTypes, prompt: 'Veg / Non-Veg / Egg', fromRow: 2);
    _dropdown(s, 5, yesNo, prompt: 'Does this topping have per-size prices?', fromRow: 2);
    // variantId (only for per-size toppings) picks a Variant by id.
    _dropdownFromRange(
      s,
      6,
      variantSource.getRangeByName('A3:A$_listSourceLastRow'),
      prompt: 'Only for per-size toppings: pick the size (Variant id).',
      addSheet: 'Variants',
      fromRow: 2,
    );
  }

  // ── Choices ──────────────────────────────────────────────────────────────────

  void _buildChoices(Worksheet s, Style header, Style instr) {
    _setHeaders(s, ['id', 'name', 'allowMultiple', 'options'], header);
    _setInstruction(s, [
      'Unique ID (e.g., choice_crust)', 'Choice name', 'Yes = multiple, No = single',
      'Available options (comma sep)',
    ], instr);
    _setRow(s, 3, ['choice_crust', 'Crust Type', 'No', 'Thin, Thick, Stuffed']);
    _setRow(s, 4, ['choice_spice', 'Spice Level', 'No', 'Mild, Medium, Hot']);
    _dropdown(s, 3, yesNo, prompt: 'Allow selecting multiple options?');
  }

  // ── ChoiceOptions ────────────────────────────────────────────────────────────

  void _buildChoiceOptions(Worksheet s, Style header, Style instr, Worksheet choiceSource) {
    _setHeaders(s, ['choiceId', 'id', 'name'], header);
    _setInstruction(s, [
      'Pick the choice group', 'Unique option ID', 'Display name',
    ], instr);
    // choiceId picks a Choice group by its id (Choices column A, data from row 3).
    _dropdownFromRange(
      s,
      1,
      choiceSource.getRangeByName('A3:A$_listSourceLastRow'),
      prompt: 'Pick the choice group this option belongs to.',
      addSheet: 'Choices',
    );
    _setRow(s, 3, ['choice_crust', 'opt_thin', 'Thin']);
    _setRow(s, 4, ['choice_crust', 'opt_thick', 'Thick']);
    _setRow(s, 5, ['choice_spice', 'opt_mild', 'Mild']);
    _setRow(s, 6, ['choice_spice', 'opt_hot', 'Hot']);
  }
}
