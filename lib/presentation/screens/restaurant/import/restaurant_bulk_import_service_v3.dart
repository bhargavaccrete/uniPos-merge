import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:uuid/uuid.dart';

/// 🚀 Enhanced Restaurant Bulk Import Service V3
/// Phase 1 Critical Improvements:
/// - ✅ Row-level validation before save
/// - ✅ Auto-category creation from names
/// - ✅ In-memory caching for performance
/// - ✅ Image URL download support
/// - ✅ Progress callback support
/// - ✅ Uses store pattern for reactive state management
class RestaurantBulkImportServiceV3 {
  // Progress callback
  final void Function(int current, int total, String message)? onProgress;

  // In-memory caches (loaded once, reused)
  Map<String, Category> _categoryCache = {};
  Map<String, Category> _categoryByNameCache = {};
  Map<String, ChoicesModel> _choiceCache = {};
  Map<String, Extramodel> _extraCache = {};
  Map<String, VariantModel> _variantCache = {};
  Map<double, Tax> _taxByRateCache = {}; // Cache taxes by percentage rate

  RestaurantBulkImportServiceV3({this.onProgress});

  // Sheet names
  static const String SHEET_CATEGORIES = 'Categories';
  static const String SHEET_VARIANTS = 'Variants';
  static const String SHEET_EXTRAS = 'Extras';
  static const String SHEET_TOPPINGS = 'Toppings';
  static const String SHEET_CHOICES = 'Choices';
  static const String SHEET_CHOICE_OPTIONS = 'ChoiceOptions';
  static const String SHEET_ITEMS = 'Items';
  static const String SHEET_ITEM_VARIANTS = 'ItemVariants';

  /// Enhanced template with CategoryName support and user-friendly instructions
  Future<String> downloadTemplate() async {
    try {
      var excel = Excel.createExcel();

      // Add sheets in logical order (Instructions first!)
      _createInstructionsSheet(excel);
      _createCategoriesSheet(excel);
      _createEnhancedItemsSheet(excel);
      _createItemVariantsSheet(excel);
      _createVariantsSheet(excel);
      _createExtrasSheet(excel);
      _createToppingsSheet(excel);
      _createChoicesSheet(excel);
      _createChoiceOptionsSheet(excel);

      // ✅ FIX: Delete default Sheet1 AFTER creating all custom sheets
      // This ensures Sheet1 doesn't appear in the final file
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
        print('🗑️ Removed default Sheet1');
      }

      return await _saveExcelFile(excel, 'unipos_restaurant_import_template_v3.xlsx');
    } catch (e) {
      return 'Error downloading template: $e';
    }
  }

  /// Create comprehensive Instructions sheet
  void _createInstructionsSheet(Excel excel) {
    var sheet = excel['📖 Instructions'];

    // Title
    var titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value =  TextCellValue('UniPOS Restaurant Bulk Import Guide');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      backgroundColorHex: ExcelColor.green,
    );

    int row = 2;

    // Quick Start
    _addBoldRow(sheet, row++, ['QUICK START GUIDE']);
    _addTextRow(sheet, row++, ['1. Start with "Categories" sheet - Add your food categories (Burgers, Pizza, etc.)']);
    _addTextRow(sheet, row++, ['2. Fill "Items" sheet - Add your menu items (Name, Price, Category are REQUIRED)']);
    _addTextRow(sheet, row++, ['3. Optional: Fill other sheets for variants, extras, toppings, choices']);
    _addTextRow(sheet, row++, ['4. Save the file and import it back into UniPOS']);
    row++;

    // Important Notes
    _addBoldRow(sheet, row++, ['⚠️ IMPORTANT NOTES']);
    _addTextRow(sheet, row++, ['• Fields marked with * are REQUIRED']);
    _addTextRow(sheet, row++, ['• Row 2 in each sheet contains helpful instructions (yellow background)']);
    _addTextRow(sheet, row++, ['• Sample data is provided in rows 3-5 - You can delete these and add your own']);
    _addTextRow(sheet, row++, ['• For Yes/No fields: Type exactly "Yes" or "No" (case sensitive)']);
    _addTextRow(sheet, row++, ['• CategoryName in Items sheet must match a name from Categories sheet']);
    row++;

    // Sheet Descriptions
    _addBoldRow(sheet, row++, ['SHEET DESCRIPTIONS']);
    _addTextRow(sheet, row++, ['📁 Categories: Your food categories (Burgers, Pizza, Drinks, etc.)']);
    _addTextRow(sheet, row++, ['🍕 Items: Your menu items - START HERE! (Required: Name, Price, Category, VegType)']);
    _addTextRow(sheet, row++, ['📏 ItemVariants: Size-based pricing (Small: ₹200, Medium: ₹300, Large: ₹400)']);
    _addTextRow(sheet, row++, ['🔧 Variants: Available sizes (Small, Medium, Large)']);
    _addTextRow(sheet, row++, ['➕ Extras: Customization groups (Toppings, Sauces)']);
    _addTextRow(sheet, row++, ['🧀 Toppings: Individual toppings with prices']);
    _addTextRow(sheet, row++, ['🎯 Choices: Selection options (Crust Type, Spice Level)']);
    _addTextRow(sheet, row++, ['✅ ChoiceOptions: Available choices (Thin Crust, Thick Crust)']);
    row++;

    // Tips
    _addBoldRow(sheet, row++, ['💡 TIPS FOR SUCCESS']);
    _addTextRow(sheet, row++, ['• Start simple: Just fill Categories and Items sheets']);
    _addTextRow(sheet, row++, ['• Test with 2-3 items first before doing all your menu']);
    _addTextRow(sheet, row++, ['• Keep category names simple and consistent']);
    _addTextRow(sheet, row++, ['• For images: Use direct image URLs or leave blank to add later']);
    _addTextRow(sheet, row++, ['• Price should be numbers only (no currency symbols)']);
  }

  void _addBoldRow(Sheet sheet, int rowIndex, List<String> values) {
    for (int i = 0; i < values.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(values[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: ExcelColor.grey,
      );
    }
  }

  void _addTextRow(Sheet sheet, int rowIndex, List<String> values) {
    for (int i = 0; i < values.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(values[i]);
    }
  }

  void _createCategoriesSheet(Excel excel) {
    var sheet = excel[SHEET_CATEGORIES];

    // Headers
    _addHeader(sheet, 0, ['id*', 'name*', 'imagePath']);

    // Instructions row
    _addInstructionRow(sheet, 1, [
      'Unique ID (e.g., cat_burgers)',
      'Category Name (e.g., Burgers)',
      'Optional: Image path/URL'
    ]);

    // Sample data
    _addRow(sheet, 2, ['cat_burgers', 'Burgers', '']);
    _addRow(sheet, 3, ['cat_pizza', 'Pizza', '']);
    _addRow(sheet, 4, ['cat_drinks', 'Drinks', '']);
    _addRow(sheet, 5, ['cat_appetizers', 'Appetizers', '']);
    _addRow(sheet, 6, ['cat_desserts', 'Desserts', '']);
  }

  void _createVariantsSheet(Excel excel) {
    var sheet = excel[SHEET_VARIANTS];

    // Headers
    _addHeader(sheet, 0, ['id*', 'name*']);

    // Instructions row
    _addInstructionRow(sheet, 1, [
      'Unique ID (e.g., var_small)',
      'Variant name (e.g., Small, Medium, Large)'
    ]);

    // Sample data
    _addRow(sheet, 2, ['var_small', 'Small']);
    _addRow(sheet, 3, ['var_medium', 'Medium']);
    _addRow(sheet, 4, ['var_large', 'Large']);
    _addRow(sheet, 5, ['var_regular', 'Regular']);
    _addRow(sheet, 6, ['var_family', 'Family Size']);
  }

  void _createExtrasSheet(Excel excel) {
    var sheet = excel[SHEET_EXTRAS];
    _addHeader(sheet, 0, ['id', 'name', 'isEnabled', 'minimum', 'maximum']);
    _addRow(sheet, 1, ['extra_toppings', 'Toppings', 'Yes', 0, 5]);
    _addRow(sheet, 2, ['extra_sauces', 'Sauces', 'Yes', 1, 2]);
  }

  void _createToppingsSheet(Excel excel) {
    var sheet = excel[SHEET_TOPPINGS];
    _addHeader(sheet, 0, ['extraId', 'name', 'isveg', 'price', 'isContainSize', 'variantId', 'variantPrice']);
    _addRow(sheet, 1, ['extra_toppings', 'Olives', 'Yes', 15, 'No', '', '']);
    _addRow(sheet, 2, ['extra_toppings', 'Pepperoni', 'No', 25, 'No', '', '']);
  }

  void _createChoicesSheet(Excel excel) {
    var sheet = excel[SHEET_CHOICES];
    _addHeader(sheet, 0, ['id', 'name']);
    _addRow(sheet, 1, ['choice_crust', 'Crust Type']);
    _addRow(sheet, 2, ['choice_spice', 'Spice Level']);
  }

  void _createChoiceOptionsSheet(Excel excel) {
    var sheet = excel[SHEET_CHOICE_OPTIONS];
    _addHeader(sheet, 0, ['choiceId', 'id', 'name']);
    _addRow(sheet, 1, ['choice_crust', 'opt_thin', 'Thin Crust']);
    _addRow(sheet, 2, ['choice_crust', 'opt_thick', 'Thick Crust']);
  }

  /// Enhanced Items sheet with CategoryName and ImageURL - USER FRIENDLY VERSION
  void _createEnhancedItemsSheet(Excel excel) {
    print('📝 Creating Enhanced Items sheet...');
    var sheet = excel[SHEET_ITEMS];

    // Row 0: Enhanced headers
    _addHeader(sheet, 0, [
      'ItemName*', 'Price*', 'CategoryName*', 'VegType*', 'Description',
      'ImageURL', 'IsSoldByWeight', 'Unit', 'TrackInventory',
      'StockQuantity', 'AllowOutOfStock', 'TaxRate', 'IsEnabled',
      'HasVariants', 'ChoiceIds', 'ExtraIds'
    ]);
    print('   ✅ Added headers (16 columns)');

    // Row 1: Instructions row (colored differently)
    _addInstructionRow(sheet, 1, [
      'Required: Item name',
      'Required: Number only',
      'Required: Must match Categories sheet',
      'Required: Veg or Non-Veg',
      'Optional: Short description',
      'Optional: Image URL',
      'Yes or No',
      'kg, gm, pcs',
      'Yes or No',
      'Number (0 if not tracking)',
      'Yes or No',
      'Number (0-100)',
      'Yes or No',
      'Yes or No',
      'Comma separated IDs',
      'Comma separated IDs'
    ]);

    // Row 2-4: Sample data with better examples
    print('   📝 Adding sample row 2: Chicken Burger');
    _addRow(sheet, 2, [
      'Chicken Burger', 150, 'Burgers', 'Non-Veg', 'Delicious chicken burger with lettuce',
      '', 'No', 'pcs', 'Yes', 50, 'No', 5, 'Yes', 'No', '', 'extra_sauces'
    ]);

    print('   📝 Adding sample row 3: Veg Pizza');
    _addRow(sheet, 3, [
      'Veg Pizza', 200, 'Pizza', 'Veg', 'Fresh vegetable pizza',
      '', 'No', 'pcs', 'Yes', 30, 'Yes', 5, 'Yes', 'Yes', 'choice_crust', 'extra_toppings'
    ]);

    print('   📝 Adding sample row 4: Cold Drink');
    _addRow(sheet, 4, [
      'Cold Drink', 50, 'Drinks', 'Veg', 'Chilled soft drink',
      '', 'No', 'pcs', 'No', 0, 'Yes', 0, 'Yes', 'No', '', ''
    ]);
    print('✅ Enhanced Items sheet created successfully');
  }

  /// Add instruction row with different styling
  void _addInstructionRow(Sheet sheet, int rowIndex, List<String> values) {
    for (int i = 0; i < values.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(values[i]);
      cell.cellStyle = CellStyle(
        italic: true,
        backgroundColorHex: ExcelColor.yellow100,
        fontSize: 9,
      );
    }
  }

  void _createItemVariantsSheet(Excel excel) {
    var sheet = excel[SHEET_ITEM_VARIANTS];

    // Headers
    _addHeader(sheet, 0, ['itemName*', 'variantName*', 'price*', 'trackInventory', 'stockQuantity']);

    // Instructions row
    _addInstructionRow(sheet, 1, [
      'Must match item name from Items sheet',
      'Must match variant from Variants sheet',
      'Price for this variant (number only)',
      'Yes or No',
      'Number (0 if not tracking)'
    ]);

    // Sample data - Pizza with 3 sizes
    _addRow(sheet, 2, ['Veg Pizza', 'Small', 200, 'Yes', 10]);
    _addRow(sheet, 3, ['Veg Pizza', 'Medium', 300, 'Yes', 15]);
    _addRow(sheet, 4, ['Veg Pizza', 'Large', 400, 'Yes', 20]);

    // Sample data - Another item
    _addRow(sheet, 5, ['Chicken Burger', 'Regular', 150, 'No', 0]);
    _addRow(sheet, 6, ['Chicken Burger', 'Large', 200, 'No', 0]);
  }

  void _addHeader(Sheet sheet, int rowIndex, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue200,
      );
    }
  }

  void _addRow(Sheet sheet, int rowIndex, List<dynamic> values) {
    for (int i = 0; i < values.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      if (values[i] is String) {
        cell.value = TextCellValue(values[i]);
      } else if (values[i] is num) {
        cell.value = DoubleCellValue(values[i].toDouble());
      } else {
        cell.value = TextCellValue('');
      }
    }
  }

  Future<String> _saveExcelFile(Excel excel, String fileName) async {
    try {
      final bytes = excel.encode();
      if (bytes == null) return 'Failed to encode Excel file';

      if (kIsWeb) {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        return result != null ? 'Template downloaded successfully' : 'Download cancelled';
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For Android 10+ (API 29+), use app's external storage directory (no permission needed)
        // This directory is accessible and won't be deleted on app uninstall
        try {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            // Navigate to public Downloads folder
            // From: /storage/emulated/0/Android/data/com.app/files
            // To: /storage/emulated/0/Download/
            final pathParts = directory.path.split('/');
            final publicPath = pathParts.sublist(0, 4).join('/'); // Get /storage/emulated/0

            // Try to save in Downloads folder
            final downloadsDir = Directory('$publicPath/Download');
            if (await downloadsDir.exists()) {
              final filePath = '${downloadsDir.path}/$fileName';
              await File(filePath).writeAsBytes(bytes);
              return 'Template saved to Downloads/$fileName';
            }

            // Fallback: save in Documents folder
            final documentsDir = Directory('$publicPath/Documents');
            try {
              if (!await documentsDir.exists()) {
                await documentsDir.create(recursive: true);
              }
              final filePath = '${documentsDir.path}/$fileName';
              await File(filePath).writeAsBytes(bytes);
              return 'Template saved to Documents/$fileName';
            } catch (e) {
              // If Documents fails, use app's directory
            }
          }

          // Final fallback: use app's directory (always works, no permission needed)
          final appDir = await getApplicationDocumentsDirectory();
          final filePath = '${appDir.path}/$fileName';
          await File(filePath).writeAsBytes(bytes);
          return 'Template saved to: $filePath\nYou can find it in your file manager.';
        } catch (e) {
          return 'Error saving file: $e';
        }
      } else {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        if (result != null) {
          await File(result).writeAsBytes(bytes);
          return 'Template saved successfully';
        }
        return 'Download cancelled';
      }
    } catch (e) {
      return 'Error saving file: $e';
    }
  }

  /// Pick and parse Excel file
  Future<Map<String, List<List<dynamic>>>> pickAndParseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        final bytes = kIsWeb
            ? result.files.single.bytes!
            : await File(result.files.single.path!).readAsBytes();

        final excel = Excel.decodeBytes(bytes);
        Map<String, List<List<dynamic>>> allSheets = {};

        for (var sheetName in excel.tables.keys) {
          final sheet = excel.tables[sheetName];
          if (sheet == null) continue;

          List<List<dynamic>> rows = [];
          for (var row in sheet.rows) {
            rows.add(row.map((cell) => _getCellValue(cell)).toList());
          }
          allSheets[sheetName] = rows;
        }

        return allSheets;
      }
    } catch (e) {
      print('Error parsing file: $e');
      throw Exception('Failed to parse file: $e');
    }
    return {};
  }

  String _getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final cellValue = cell.value;

    if (cellValue is TextCellValue) {
      return cellValue.value.text ?? '';
    } else if (cellValue is IntCellValue) {
      return cellValue.value.toString();
    } else if (cellValue is DoubleCellValue) {
      return cellValue.value.toString();
    } else if (cellValue is BoolCellValue) {
      return cellValue.value ? 'Yes' : 'No';
    }
    return '';
  }

  /// 🚀 Main import with Phase 1 improvements
  Future<ImportResultV3> importData(Map<String, List<List<dynamic>>> allSheets) async {
    ImportResultV3 result = ImportResultV3();

    try {
      print('🔄 Starting enhanced import process...');

      // Step 1: Load all data into memory caches (ONE TIME)
      onProgress?.call(0, 100, 'Loading existing data...');
      await _loadAllCaches();

      int totalSteps = 8;
      int currentStep = 0;

      // Step 2: Import dependencies first
      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing categories...');
      await _importCategories(allSheets[SHEET_CATEGORIES], result);

      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing variants...');
      await _importVariants(allSheets[SHEET_VARIANTS], result);

      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing extras...');
      await _importExtras(allSheets[SHEET_EXTRAS], result);

      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing toppings...');
      await _importToppings(allSheets[SHEET_TOPPINGS], result);

      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing choices...');
      await _importChoices(allSheets[SHEET_CHOICES], result);

      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing choice options...');
      await _importChoiceOptions(allSheets[SHEET_CHOICE_OPTIONS], result);

      // Step 3: Import items with validation and auto-category creation
      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing items...');
      await _importEnhancedItems(allSheets[SHEET_ITEMS], result);

      currentStep++;
      onProgress?.call((currentStep / totalSteps * 100).toInt(), 100, 'Importing item variants...');
      await _importItemVariants(allSheets[SHEET_ITEM_VARIANTS], result);

      // Step 4: Refresh all stores
      onProgress?.call(95, 100, 'Refreshing stores...');
      await refreshAllRestaurantStores();

      result.success = result.errors.isEmpty;
      onProgress?.call(100, 100, 'Import complete!');

      print('✅ Enhanced import complete! Success: ${result.success}');
      return result;
    } catch (e, stackTrace) {
      print('❌ Fatal error: $e');
      print('Stack trace: $stackTrace');
      result.errors.add('Fatal error: $e');
      result.success = false;
      return result;
    }
  }

  /// Load all data into in-memory caches using stores
  Future<void> _loadAllCaches() async {
    print('📂 Loading caches...');

    try {
      // Load categories with case-insensitive name matching
      await categoryStore.loadCategories();
      final categories = categoryStore.categories;
      _categoryCache = {for (var cat in categories) cat.id: cat};
      // ✅ IMPROVED: Trim and lowercase for consistent matching (Pizza, pizza, " Pizza " all match)
      _categoryByNameCache = {for (var cat in categories) cat.name.toLowerCase().trim(): cat};
      print('✅ Cached ${categories.length} categories (case-insensitive matching enabled)');
    } catch (e) {
      print('⚠️ Error loading categories: $e');
      // Continue with empty cache
    }

    try {
      // Load choices
      await choiceStore.loadChoices();
      final choices = choiceStore.choices;
      _choiceCache = {for (var choice in choices) choice.id: choice};
      print('✅ Cached ${choices.length} choices');
    } catch (e) {
      print('⚠️ Error loading choices: $e');
    }

    try {
      // Load extras
      await extraStore.loadExtras();
      final extras = extraStore.extras;
      _extraCache = {for (var extra in extras) extra.Id: extra};
      print('✅ Cached ${extras.length} extras');
    } catch (e) {
      print('⚠️ Error loading extras: $e');
    }

    try {
      // Load variants
      await variantStore.loadVariants();
      final variants = variantStore.variants;
      _variantCache = {for (var variant in variants) variant.id: variant};
      print('✅ Cached ${variants.length} variants');
    } catch (e) {
      print('⚠️ Error loading variants: $e');
    }

    try {
      // Load taxes
      await taxStore.loadTaxes();
      final taxes = taxStore.taxes;
      // Cache by tax percentage rate for easy lookup
      _taxByRateCache = {
        for (var tax in taxes)
          if (tax.taxperecentage != null) tax.taxperecentage!: tax
      };
      print('✅ Cached ${taxes.length} taxes');
    } catch (e) {
      print('⚠️ Error loading taxes: $e');
    }
  }

  /// ✅ CRITICAL: Row-level validation
  ValidationResult _validateItemRow(Map<String, dynamic> row, int rowNumber) {
    List<String> errors = [];

    // 1. ItemName required
    final itemName = row['ItemName']?.toString().trim() ?? '';
    if (itemName.isEmpty) {
      errors.add('Row $rowNumber: ItemName is required');
    }

    // 2. Price validation
    final priceStr = row['Price']?.toString() ?? '';
    final price = double.tryParse(priceStr);
    final hasVariants = _parseBool(row['HasVariants']?.toString() ?? '', false);

    if (!hasVariants) {
      if (price == null) {
        errors.add('Row $rowNumber: Invalid price value "$priceStr"');
      } else if (price <= 0) {
        errors.add('Row $rowNumber: Price must be greater than 0');
      }
    }

    // 3. CategoryName required
    final categoryName = row['CategoryName']?.toString().trim() ?? '';
    if (categoryName.isEmpty) {
      errors.add('Row $rowNumber: CategoryName is required');
    }

    // 4. VegType validation
    final vegType = row['VegType']?.toString().trim().toLowerCase() ?? '';
    if (vegType.isNotEmpty && vegType != 'veg' && vegType != 'non-veg') {
      errors.add('Row $rowNumber: VegType must be "Veg" or "Non-Veg" (got "$vegType")');
    }

    // 5. Weight + Unit validation
    final isSoldByWeight = _parseBool(row['IsSoldByWeight']?.toString() ?? '', false);
    final unit = row['Unit']?.toString().trim() ?? '';
    if (isSoldByWeight && unit.isEmpty) {
      errors.add('Row $rowNumber: Unit required when IsSoldByWeight is YES');
    }

    // 6. Inventory validation
    final trackInventory = _parseBool(row['TrackInventory']?.toString() ?? '', false);
    final allowOutOfStock = row['AllowOutOfStock']?.toString().trim() ?? '';
    if (trackInventory && allowOutOfStock.isEmpty) {
      errors.add('Row $rowNumber: AllowOutOfStock required when TrackInventory is YES');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// ✅ CRITICAL: Auto-create category from name (case-insensitive, duplicate-safe)
  /// Prevents duplicates: "Pizza", "pizza", " Pizza " all map to the same category
  Future<String> _getOrCreateCategory(String categoryName, ImportResultV3 result) async {
    final nameLower = categoryName.toLowerCase().trim();

    // Check cache first (O(1) lookup) - prevents duplicates
    if (_categoryByNameCache.containsKey(nameLower)) {
      final existingCategory = _categoryByNameCache[nameLower]!;
      print('✅ Reusing existing category: "${existingCategory.name}" for input "$categoryName"');
      return existingCategory.id;
    }

    // Category doesn't exist - create it
    print('📝 Auto-creating new category: $categoryName');

    final newCategory = Category(
      id: const Uuid().v4(),
      name: categoryName.trim(), // Use trimmed name for consistency
      imagePath: null,
      createdTime: DateTime.now(),
      editCount: 0,
    );

    await categoryStore.addCategory(newCategory);

    // Update caches with lowercase key for future lookups
    _categoryCache[newCategory.id] = newCategory;
    _categoryByNameCache[nameLower] = newCategory;

    result.categoriesAutoCreated++;
    result.warnings.add('✨ Auto-created category: ${newCategory.name}');

    return newCategory.id;
  }

  /// ✅ CRITICAL: Auto-create tax from rate (duplicate-safe)
  /// Prevents duplicates: same tax rate will reuse existing tax
  Future<String> _getOrCreateTax(double taxRate, ImportResultV3 result) async {
    // Check cache first (O(1) lookup) - prevents duplicates
    if (_taxByRateCache.containsKey(taxRate)) {
      final existingTax = _taxByRateCache[taxRate]!;
      print('✅ Reusing existing tax: "${existingTax.taxname}" (${existingTax.taxperecentage}%) for rate $taxRate%');
      return existingTax.id;
    }

    // Tax doesn't exist - create it
    print('📝 Auto-creating new tax: $taxRate%');

    final newTax = Tax(
      id: const Uuid().v4(),
      taxname: 'Tax ${taxRate.toStringAsFixed(2)}%',
      taxperecentage: taxRate,
    );

    await taxStore.addTax(newTax);

    // Update cache for future lookups
    _taxByRateCache[taxRate] = newTax;

    result.taxesAutoCreated++;
    result.warnings.add('✨ Auto-created tax: ${newTax.taxname} (${newTax.taxperecentage}%)');

    return newTax.id;
  }

  /// ✅ CRITICAL: Download image from URL
  Future<String?> _downloadImage(String imageUrl, String itemId, ImportResultV3 result) async {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return null;
    }

    try {
      print('⬇️ Downloading image: $imageUrl');

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        result.warnings.add('Image download failed (${response.statusCode}): $imageUrl');
        return null;
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageUrl.split('.').last.split('?').first;
      final fileName = 'img_${timestamp}_$itemId.$extension';

      // Save to product_images folder
      final directory = await getApplicationDocumentsDirectory();
      final productImagesDir = Directory('${directory.path}/product_images');

      if (!await productImagesDir.exists()) {
        await productImagesDir.create(recursive: true);
      }

      final file = File('${productImagesDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      print('✅ Image saved: $fileName');
      result.imagesDownloaded++;

      return file.path;
    } catch (e) {
      print('⚠️ Image download error: $e');
      result.warnings.add('Failed to download image: $imageUrl ($e)');
      return null;
    }
  }

  Future<void> _importCategories(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);

        // Check cache instead of DB
        if (_categoryCache.containsKey(id)) {
          result.warnings.add('Category $id already exists, skipping');
          continue;
        }

        Category category = Category(
          id: id,
          name: name,
          imagePath: _getValue(row, 2).isEmpty ? null : _getValue(row, 2),
          createdTime: DateTime.now(),
          editCount: 0,
        );

        final success = await categoryStore.addCategory(category);
        if (success) {
          _categoryCache[id] = category;
          _categoryByNameCache[name.toLowerCase()] = category;
          result.categoriesImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Categories: $e');
      }
    }
  }

  Future<void> _importVariants(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);

        if (_variantCache.containsKey(id)) {
          result.warnings.add('Variant $id already exists, skipping');
          continue;
        }

        VariantModel variant = VariantModel(
          id: id,
          name: name,
          createdTime: DateTime.now(),
        );

        final success = await variantStore.addVariant(variant);
        if (success) {
          _variantCache[id] = variant;
          result.variantsImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Variants: $e');
      }
    }
  }

  Future<void> _importExtras(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 2) return;

    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);

        if (_extraCache.containsKey(id)) {
          result.warnings.add('Extra $id already exists, skipping');
          continue;
        }

        Extramodel extra = Extramodel(
          Id: id,
          Ename: _getValue(row, 1),
          isEnabled: _parseBool(_getValue(row, 2), true),
          minimum: _getInt(row, 3),
          maximum: _getInt(row, 4),
          topping: [],
          createdTime: DateTime.now(),
        );

        final success = await extraStore.addExtra(extra);
        if (success) {
          _extraCache[id] = extra;
          result.extrasImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Extras: $e');
      }
    }
  }

  Future<void> _importToppings(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 2) return;

    Map<String, Map<String, List<List<dynamic>>>> toppingGroups = {};

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;

      String extraId = _getValue(row, 0);
      String toppingName = _getValue(row, 1);

      if (extraId.isEmpty || toppingName.isEmpty) continue;

      toppingGroups.putIfAbsent(extraId, () => {});
      toppingGroups[extraId]!.putIfAbsent(toppingName, () => []);
      toppingGroups[extraId]![toppingName]!.add(row);
    }

    for (var extraId in toppingGroups.keys) {
      try {
        var extra = _extraCache[extraId];
        if (extra == null) {
          result.errors.add('Extra $extraId not found for toppings');
          continue;
        }

        List<Topping> toppings = extra.topping?.toList() ?? [];

        for (var toppingName in toppingGroups[extraId]!.keys) {
          var toppingRows = toppingGroups[extraId]![toppingName]!;
          var firstRow = toppingRows.first;

          bool isveg = _parseBool(_getValue(firstRow, 2), true);
          double price = _getDouble(firstRow, 3);
          bool isContainSize = _parseBool(_getValue(firstRow, 4), false);

          Map<String, double>? variantPrices;
          List<VariantModel>? variantModels;

          if (isContainSize && toppingRows.length > 1) {
            variantPrices = {};
            variantModels = [];

            for (var row in toppingRows) {
              String variantId = _getValue(row, 5);
              double variantPrice = _getDouble(row, 6);

              if (variantId.isNotEmpty) {
                variantPrices[variantId] = variantPrice;

                var variantModel = _variantCache[variantId];
                if (variantModel != null && !variantModels.any((v) => v.id == variantId)) {
                  variantModels.add(variantModel);
                }
              }
            }
          }

          toppings.add(Topping(
            name: toppingName,
            isveg: isveg,
            price: price,
            isContainSize: isContainSize,
            variantion: variantModels,
            variantPrices: variantPrices,
            createdTime: DateTime.now(),
          ));
          result.toppingsImported++;
        }

        var updatedExtra = extra.copyWith(topping: toppings);
        await extraStore.updateExtra(updatedExtra);
        _extraCache[extraId] = updatedExtra;
      } catch (e) {
        result.errors.add('Error importing toppings for extra $extraId: $e');
      }
    }
  }

  Future<void> _importChoices(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 2) return;

    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);

        if (_choiceCache.containsKey(id)) {
          result.warnings.add('Choice $id already exists, skipping');
          continue;
        }

        ChoicesModel choice = ChoicesModel(
          id: id,
          name: _getValue(row, 1),
          choiceOption: [],
          createdTime: DateTime.now(),
        );

        final success = await choiceStore.addChoice(choice);
        if (success) {
          _choiceCache[id] = choice;
          result.choicesImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Choices: $e');
      }
    }
  }

  Future<void> _importChoiceOptions(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 2) return;

    Map<String, List<List<dynamic>>> optionGroups = {};

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;

      String choiceId = _getValue(row, 0);
      if (choiceId.isEmpty) continue;

      optionGroups.putIfAbsent(choiceId, () => []);
      optionGroups[choiceId]!.add(row);
    }

    for (var choiceId in optionGroups.keys) {
      try {
        var choice = _choiceCache[choiceId];
        if (choice == null) {
          result.errors.add('Choice $choiceId not found for options');
          continue;
        }

        List<ChoiceOption> options = choice.choiceOption.toList();

        for (var row in optionGroups[choiceId]!) {
          String optionId = _getValue(row, 1);
          String optionName = _getValue(row, 2);

          if (optionId.isEmpty || optionName.isEmpty) continue;

          options.add(ChoiceOption(
            id: optionId,
            name: optionName,
          ));
          result.choiceOptionsImported++;
        }

        var updatedChoice = choice.copyWith(option: options);
        await choiceStore.updateChoice(updatedChoice);
        _choiceCache[choiceId] = updatedChoice;
      } catch (e) {
        result.errors.add('Error importing options for choice $choiceId: $e');
      }
    }
  }

  /// ✅ ENHANCED: Items import with validation, auto-category, and image download
  Future<void> _importEnhancedItems(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    // Get header row to map columns - STRIP ASTERISKS from required field markers
    final headers = rows[0].map((e) => e.toString().trim().replaceAll('*', '')).toList();
    print('📋 Headers from Excel (cleaned): ${headers.take(5).join(", ")}');
    print('   Will map to: ItemName, Price, CategoryName, VegType, Description');

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      try {
        var row = rows[i];

        // Debug: Print raw row data
        if (i <= 4) {
          print('🔍 Row $i RAW: length=${row.length}, isEmpty=${row.isEmpty}');
          if (row.isNotEmpty) {
            print('   First 3 cells: [${row.length > 0 ? row[0] : "N/A"}, ${row.length > 1 ? row[1] : "N/A"}, ${row.length > 2 ? row[2] : "N/A"}]');
          }
        }

        if (row.isEmpty) continue;

        // Map row to dictionary
        Map<String, dynamic> rowData = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          rowData[headers[j]] = row[j];
        }

        // Debug: Print mapped data
        if (i <= 4) {
          print('📋 Row $i MAPPED: ItemName="${rowData['ItemName']}", Price="${rowData['Price']}", Category="${rowData['CategoryName']}"');
        }

        // Step 1: Validate row
        final validation = _validateItemRow(rowData, i + 1);
        if (!validation.isValid) {
          result.failedRows.add(FailedRow(
            rowNumber: i + 1,
            errors: validation.errors,
          ));
          result.errors.addAll(validation.errors);
          continue;
        }

        // Step 2: Get or create category
        final categoryName = rowData['CategoryName']?.toString().trim() ?? '';
        final categoryId = await _getOrCreateCategory(categoryName, result);

        // Step 3: Download image if URL provided and convert to bytes
        Uint8List? imageBytes;
        final imageUrl = rowData['ImageURL']?.toString().trim() ?? '';
        if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
          final itemId = const Uuid().v4();
          final imagePath = await _downloadImage(imageUrl, itemId, result);
          if (imagePath != null && imagePath.isNotEmpty) {
            try {
              final file = File(imagePath);
              if (file.existsSync()) {
                imageBytes = await file.readAsBytes();
              }
            } catch (e) {
              print('⚠️ Failed to read downloaded image: $e');
            }
          }
        }

        // Step 4: Parse comma-separated IDs and validate
        final choiceIdsStr = rowData['ChoiceIds']?.toString().trim() ?? '';
        List<String> choiceIds = choiceIdsStr.isEmpty
            ? []
            : choiceIdsStr.split(',').map((e) => e.trim()).where((id) {
                if (id.isEmpty) return false;
                if (!_choiceCache.containsKey(id)) {
                  result.warnings.add('Row ${i + 1}: Choice ID "$id" not found, skipped');
                  return false;
                }
                return true;
              }).toList();

        final extraIdsStr = rowData['ExtraIds']?.toString().trim() ?? '';
        List<String> extraIds = extraIdsStr.isEmpty
            ? []
            : extraIdsStr.split(',').map((e) => e.trim()).where((id) {
                if (id.isEmpty) return false;
                if (!_extraCache.containsKey(id)) {
                  result.warnings.add('Row ${i + 1}: Extra ID "$id" not found, skipped');
                  return false;
                }
                return true;
              }).toList();

        // Step 5: Auto-create tax if tax rate is specified
        final rawTaxRate = _getDoubleFromValue(rowData['TaxRate']);
        final taxRateValue = _normalizeTaxRate(rawTaxRate);
        String? taxId;
        if (rawTaxRate != null && rawTaxRate > 0) {
          // Use raw value (5) for Tax creation, normalized value (0.05) for Item
          taxId = await _getOrCreateTax(rawTaxRate, result);
        }

        // Step 6: Create item
        final hasVariants = _parseBool(rowData['HasVariants']?.toString() ?? '', false);

        Items item = Items(
          id: const Uuid().v4(),
          name: rowData['ItemName']?.toString().trim() ?? '',
          categoryOfItem: categoryId,
          description: rowData['Description']?.toString().trim(),
          price: hasVariants ? null : _getDoubleFromValue(rowData['Price']),
          isVeg: rowData['VegType']?.toString().trim(),
          unit: rowData['Unit']?.toString().trim(),
          isSoldByWeight: _parseBool(rowData['IsSoldByWeight']?.toString() ?? '', false),
          trackInventory: _parseBool(rowData['TrackInventory']?.toString() ?? '', false),
          stockQuantity: hasVariants ? 0 : _getDoubleFromValue(rowData['StockQuantity']),
          allowOrderWhenOutOfStock: _parseBool(rowData['AllowOutOfStock']?.toString() ?? '', true),
          taxRate: taxRateValue,
          taxIds: taxId != null ? [taxId] : null,
          isEnabled: _parseBool(rowData['IsEnabled']?.toString() ?? '', true),
          variant: [],
          choiceIds: choiceIds,
          extraId: extraIds,
          imageBytes: imageBytes,
          createdTime: DateTime.now(),
          lastEditedTime: DateTime.now(),
          editedBy: 'BulkImport',
          editCount: 0,
        );

        final success = await itemStore.addItem(item);
        if (success) {
          result.itemsImported++;
        }

        // Progress update
        if (i % 10 == 0) {
          onProgress?.call(i, rows.length, 'Imported ${result.itemsImported} items...');
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Items: $e');
      }
    }
  }

  Future<void> _importItemVariants(List<List<dynamic>>? rows, ImportResultV3 result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    Map<String, List<List<dynamic>>> variantGroups = {};

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;

      String itemName = _getValue(row, 0);
      if (itemName.isEmpty) continue;

      variantGroups.putIfAbsent(itemName, () => []);
      variantGroups[itemName]!.add(row);
    }

    await itemStore.loadItems();
    final allItems = itemStore.items;

    for (var itemName in variantGroups.keys) {
      try {
        var item = allItems.where((i) => i.name == itemName).firstOrNull;
        if (item == null) {
          result.errors.add('Item "$itemName" not found for variants');
          continue;
        }

        List<ItemVariante> variants = [];

        for (var row in variantGroups[itemName]!) {
          String variantName = _getValue(row, 1);
          double price = _getDouble(row, 2);
          bool trackInventory = _parseBool(_getValue(row, 3), false);
          double stockQuantity = _getDouble(row, 4);

          // Find variant by name
          var variant = _variantCache.values.where((v) => v.name == variantName).firstOrNull;
          if (variant == null) {
            result.warnings.add('Variant "$variantName" not found, skipping');
            continue;
          }

          variants.add(ItemVariante(
            variantId: variant.id,
            price: price,
            trackInventory: trackInventory,
            stockQuantity: stockQuantity,
          ));
          result.itemVariantsImported++;
        }

        var updatedItem = item.copyWith(variant: variants);
        await itemStore.updateItem(updatedItem);
      } catch (e) {
        result.errors.add('Error importing variants for item $itemName: $e');
      }
    }
  }

  // Helper methods
  String _getValue(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    var value = row[index];
    return value?.toString().trim() ?? '';
  }

  double _getDouble(List<dynamic> row, int index) {
    if (index >= row.length) return 0.0;
    String val = row[index].toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(val) ?? 0.0;
  }

  double _getDoubleFromValue(dynamic value) {
    if (value == null) return 0.0;
    String val = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(val) ?? 0.0;
  }

  /// Normalize tax rate to decimal format (0-1 range)
  /// If value > 1, assumes it's a percentage and divides by 100
  /// Examples: 5 -> 0.05, 18 -> 0.18, 0.05 -> 0.05
  double _normalizeTaxRate(double value) {
    if (value > 1) {
      return value / 100; // Convert percentage to decimal
    }
    return value; // Already in decimal format
  }

  int? _getInt(List<dynamic> row, int index) {
    if (index >= row.length) return null;
    String val = row[index].toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (val.isEmpty) return null;
    return int.tryParse(val);
  }

  bool _parseBool(String value, bool defaultValue) {
    if (value.isEmpty) return defaultValue;
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == 'yes' || lower == '1') return true;
    if (lower == 'false' || lower == 'no' || lower == '0') return false;
    return defaultValue;
  }
}

/// Validation result class
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({required this.isValid, required this.errors});
}

/// Failed row details
class FailedRow {
  final int rowNumber;
  final List<String> errors;

  FailedRow({required this.rowNumber, required this.errors});

  @override
  String toString() => 'Row $rowNumber: ${errors.join(", ")}';
}

/// Enhanced import result with Phase 1 metrics
class ImportResultV3 {
  bool success = false;
  List<String> errors = [];
  List<String> warnings = [];
  List<FailedRow> failedRows = [];

  int categoriesImported = 0;
  int categoriesAutoCreated = 0;
  int taxesAutoCreated = 0;
  int variantsImported = 0;
  int extrasImported = 0;
  int toppingsImported = 0;
  int choicesImported = 0;
  int choiceOptionsImported = 0;
  int itemsImported = 0;
  int itemVariantsImported = 0;
  int imagesDownloaded = 0;

  String getSummary() {
    StringBuffer sb = StringBuffer();

    sb.writeln(success ? '✅ Import completed successfully!' : '❌ Import completed with errors');
    sb.writeln('\n📊 Import Statistics:');
    sb.writeln('  Total Items: $itemsImported');
    sb.writeln('  Categories: $categoriesImported (+ $categoriesAutoCreated auto-created)');
    sb.writeln('  Taxes: $taxesAutoCreated auto-created');
    sb.writeln('  Variants: $variantsImported');
    sb.writeln('  Item Variants: $itemVariantsImported');
    sb.writeln('  Extras: $extrasImported');
    sb.writeln('  Toppings: $toppingsImported');
    sb.writeln('  Choices: $choicesImported');
    sb.writeln('  Choice Options: $choiceOptionsImported');
    sb.writeln('  Images Downloaded: $imagesDownloaded');

    if (failedRows.isNotEmpty) {
      sb.writeln('\n❌ Failed Rows (${failedRows.length}):');
      for (var failed in failedRows.take(10)) {
        sb.writeln('  - $failed');
      }
      if (failedRows.length > 10) {
        sb.writeln('  ... and ${failedRows.length - 10} more');
      }
    }

    if (warnings.isNotEmpty) {
      sb.writeln('\n⚠️ Warnings (${warnings.length}):');
      for (var warning in warnings.take(5)) {
        sb.writeln('  - $warning');
      }
      if (warnings.length > 5) {
        sb.writeln('  ... and ${warnings.length - 5} more');
      }
    }

    if (errors.isNotEmpty && errors.length > failedRows.length) {
      sb.writeln('\n❌ Other Errors (${errors.length - failedRows.length}):');
      final otherErrors = errors.where((e) => !failedRows.any((f) => f.errors.contains(e))).toList();
      for (var error in otherErrors.take(5)) {
        sb.writeln('  - $error');
      }
    }

    return sb.toString();
  }
}
