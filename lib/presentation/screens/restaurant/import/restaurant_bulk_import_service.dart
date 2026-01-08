import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_choice.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_extra.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_variante.dart';
import 'package:uuid/uuid.dart';

/// Improved Restaurant Bulk Import Service
/// Supports multi-sheet Excel import with full model coverage
class RestaurantBulkImportService {
  // No need for store instances - using Hive directly

  // Sheet names
  static const String SHEET_CATEGORIES = 'Categories';
  static const String SHEET_VARIANTS = 'Variants';
  static const String SHEET_EXTRAS = 'Extras';
  static const String SHEET_TOPPINGS = 'Toppings';
  static const String SHEET_CHOICES = 'Choices';
  static const String SHEET_CHOICE_OPTIONS = 'ChoiceOptions';
  static const String SHEET_ITEMS = 'Items';
  static const String SHEET_ITEM_VARIANTS = 'ItemVariants';

  /// Download template with all sheets and sample data
  Future<String> downloadTemplate() async {
    try {
      var excel = Excel.createExcel();

      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      _createCategoriesSheet(excel);
      _createVariantsSheet(excel);
      _createExtrasSheet(excel);
      _createToppingsSheet(excel);
      _createChoicesSheet(excel);
      _createChoiceOptionsSheet(excel);
      _createItemsSheet(excel);
      _createItemVariantsSheet(excel);

      // Save file
      return await _saveExcelFile(excel, 'unipos_restaurant_import_template.xlsx');
    } catch (e) {
      return 'Error downloading template: $e';
    }
  }

  void _createCategoriesSheet(Excel excel) {
    var sheet = excel[SHEET_CATEGORIES];

    // Headers
    _addHeader(sheet, 0, ['id', 'name', 'imagePath']);

    // Sample data
    _addRow(sheet, 1, ['cat_burgers', 'Burgers', '']);
    _addRow(sheet, 2, ['cat_pizza', 'Pizza', '']);
    _addRow(sheet, 3, ['cat_drinks', 'Drinks', '']);
  }

  void _createVariantsSheet(Excel excel) {
    var sheet = excel[SHEET_VARIANTS];

    // Headers
    _addHeader(sheet, 0, ['id', 'name']);

    // Sample data
    _addRow(sheet, 1, ['var_small', 'Small']);
    _addRow(sheet, 2, ['var_medium', 'Medium']);
    _addRow(sheet, 3, ['var_large', 'Large']);
  }

  void _createExtrasSheet(Excel excel) {
    var sheet = excel[SHEET_EXTRAS];

    // Headers
    _addHeader(sheet, 0, ['id', 'name', 'isEnabled', 'minimum', 'maximum']);

    // Sample data
    _addRow(sheet, 1, ['extra_toppings', 'Toppings', 'Yes', 0, 5]);
    _addRow(sheet, 2, ['extra_sauces', 'Sauces', 'Yes', 1, 2]);
    _addRow(sheet, 3, ['extra_cheese', 'Cheese Options', 'Yes', 0, 3]);
  }

  void _createToppingsSheet(Excel excel) {
    var sheet = excel[SHEET_TOPPINGS];

    // Headers
    _addHeader(sheet, 0, ['extraId', 'name', 'isveg', 'price', 'isContainSize', 'variantId', 'variantPrice']);

    // Sample data - regular topping (no variant pricing)
    _addRow(sheet, 1, ['extra_toppings', 'Olives', 'Yes', 15, 'No', '', '']);
    _addRow(sheet, 2, ['extra_toppings', 'Pepperoni', 'No', 25, 'No', '', '']);

    // Sample data - topping with variant pricing
    _addRow(sheet, 3, ['extra_cheese', 'Extra Cheese', 'Yes', 0, 'Yes', 'var_small', 15]);
    _addRow(sheet, 4, ['extra_cheese', 'Extra Cheese', 'Yes', 0, 'Yes', 'var_medium', 20]);
    _addRow(sheet, 5, ['extra_cheese', 'Extra Cheese', 'Yes', 0, 'Yes', 'var_large', 25]);

    _addRow(sheet, 6, ['extra_sauces', 'BBQ Sauce', 'Yes', 10, 'No', '', '']);
    _addRow(sheet, 7, ['extra_sauces', 'Hot Sauce', 'Yes', 10, 'No', '', '']);
  }

  void _createChoicesSheet(Excel excel) {
    var sheet = excel[SHEET_CHOICES];

    // Headers
    _addHeader(sheet, 0, ['id', 'name']);

    // Sample data
    _addRow(sheet, 1, ['choice_crust', 'Crust Type']);
    _addRow(sheet, 2, ['choice_spice', 'Spice Level']);
  }

  void _createChoiceOptionsSheet(Excel excel) {
    var sheet = excel[SHEET_CHOICE_OPTIONS];

    // Headers
    _addHeader(sheet, 0, ['choiceId', 'id', 'name']);

    // Sample data
    _addRow(sheet, 1, ['choice_crust', 'opt_thin', 'Thin Crust']);
    _addRow(sheet, 2, ['choice_crust', 'opt_thick', 'Thick Crust']);
    _addRow(sheet, 3, ['choice_crust', 'opt_stuffed', 'Stuffed Crust']);
    _addRow(sheet, 4, ['choice_spice', 'opt_mild', 'Mild']);
    _addRow(sheet, 5, ['choice_spice', 'opt_medium', 'Medium']);
    _addRow(sheet, 6, ['choice_spice', 'opt_hot', 'Hot']);
  }

  void _createItemsSheet(Excel excel) {
    var sheet = excel[SHEET_ITEMS];

    // Headers
    _addHeader(sheet, 0, [
      'id', 'name', 'categoryOfItem', 'description', 'price', 'isVeg', 'unit',
      'isSoldByWeight', 'trackInventory', 'stockQuantity', 'allowOrderWhenOutOfStock',
      'taxRate', 'isEnabled', 'hasVariants', 'choiceIds', 'extraIds', 'imagePath'
    ]);

    // Sample data - item without variants
    _addRow(sheet, 1, [
      'item_burger', 'Chicken Burger', 'cat_burgers', 'Delicious chicken burger',
      150, 'non-veg', 'pcs', 'No', 'Yes', 50, 'Yes', 0.05, 'Yes', 'No',
      '', 'extra_sauces', ''
    ]);

    // Sample data - item with variants
    _addRow(sheet, 2, [
      'item_veg_pizza', 'Veg Pizza', 'cat_pizza', 'Fresh vegetable pizza',
      0, 'veg', 'pcs', 'No', 'No', 0, 'Yes', 0.05, 'Yes', 'Yes',
      'choice_crust,choice_spice', 'extra_toppings,extra_cheese,extra_sauces', ''
    ]);
  }

  void _createItemVariantsSheet(Excel excel) {
    var sheet = excel[SHEET_ITEM_VARIANTS];

    // Headers
    _addHeader(sheet, 0, ['itemId', 'variantId', 'price', 'trackInventory', 'stockQuantity']);

    // Sample data - variants for veg pizza
    _addRow(sheet, 1, ['item_veg_pizza', 'var_small', 200, 'Yes', 10]);
    _addRow(sheet, 2, ['item_veg_pizza', 'var_medium', 300, 'Yes', 15]);
    _addRow(sheet, 3, ['item_veg_pizza', 'var_large', 400, 'Yes', 20]);
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
      } else if (values[i] == null || values[i] == '') {
        cell.value = TextCellValue('');
      }
    }
  }

  Future<String> _saveExcelFile(Excel excel, String fileName) async {
    try {
      final bytes = excel.encode();
      if (bytes == null) return 'Failed to encode Excel file';

      if (kIsWeb) {
        // Web platform - use FilePicker with bytes (convert List<int> to Uint8List)
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );

        if (result != null) {
          return 'Template downloaded successfully';
        }
        return 'Download cancelled';
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms
        if (await Permission.storage.request().isGranted ||
            await Permission.manageExternalStorage.request().isGranted) {
          final directory = await getDownloadsDirectory();
          if (directory == null) return 'Could not access downloads directory';
          final path = '${directory.path}/$fileName';
          final file = File(path);
          await file.writeAsBytes(bytes);
          return 'Template saved to $path';
        } else {
          return 'Permission denied';
        }
      } else {
        // Desktop platforms (Windows, macOS, Linux)
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsBytes(bytes);
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
        withData: kIsWeb, // On web, we need the bytes directly
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

  /// Helper method to extract value from Excel cell
  String _getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';

    final cellValue = cell.value;

    // Handle different cell value types
    if (cellValue is TextCellValue) {
      // TextCellValue.value returns a TextSpan, we need to get the text property
      return cellValue.value.text ?? '';
    } else if (cellValue is IntCellValue) {
      return cellValue.value.toString();
    } else if (cellValue is DoubleCellValue) {
      return cellValue.value.toString();
    } else if (cellValue is BoolCellValue) {
      return cellValue.value ? 'Yes' : 'No';
    } else if (cellValue is DateCellValue) {
      return cellValue.year.toString();
    } else if (cellValue is TimeCellValue) {
      return cellValue.hour.toString();
    } else if (cellValue is DateTimeCellValue) {
      return cellValue.year.toString();
    } else if (cellValue is FormulaCellValue) {
      return cellValue.formula;
    }

    return '';
  }

  /// Import data from all sheets
  Future<ImportResult> importData(Map<String, List<List<dynamic>>> allSheets) async {
    ImportResult result = ImportResult();

    try {
      print('🔄 Starting import process...');

      // Ensure all data is loaded with individual try-catch
      try {
        print('📂 Loading categories...');
        final categories = await HiveBoxes.getAllCategories();
        print('✅ Categories loaded: ${categories.length}');
      } catch (e) {
        print('⚠️ Error loading categories: $e');
        result.warnings.add('Could not load existing categories: $e');
      }

      try {
        print('📂 Loading choices...');
        final choices = await HiveChoice.getAllChoice();
        print('✅ Choices loaded: ${choices.length}');
      } catch (e) {
        print('⚠️ Error loading choices: $e');
        result.warnings.add('Could not load existing choices: $e');
      }

      try {
        print('📂 Loading extras...');
        final extras = await HiveExtra.getAllExtra();
        print('✅ Extras loaded: ${extras.length}');
      } catch (e) {
        print('⚠️ Error loading extras: $e');
        result.warnings.add('Could not load existing extras: $e');
      }

      try {
        print('📂 Loading items...');
        final items = await itemsBoxes.getAllItems();
        print('✅ Items loaded: ${items.length}');
      } catch (e) {
        print('⚠️ Error loading items: $e');
        result.warnings.add('Could not load existing items: $e');
      }

      print('📥 Starting import operations...');

      // Import in order (dependencies first)
      print('1️⃣ Importing categories...');
      await _importCategories(allSheets[SHEET_CATEGORIES], result);
      print('✅ Categories imported: ${result.categoriesImported}');

      print('2️⃣ Importing variants...');
      await _importVariants(allSheets[SHEET_VARIANTS], result);
      print('✅ Variants imported: ${result.variantsImported}');

      print('3️⃣ Importing extras...');
      await _importExtras(allSheets[SHEET_EXTRAS], result);
      print('✅ Extras imported: ${result.extrasImported}');

      print('4️⃣ Importing toppings...');
      await _importToppings(allSheets[SHEET_TOPPINGS], result);
      print('✅ Toppings imported: ${result.toppingsImported}');

      print('5️⃣ Importing choices...');
      await _importChoices(allSheets[SHEET_CHOICES], result);
      print('✅ Choices imported: ${result.choicesImported}');

      print('6️⃣ Importing choice options...');
      await _importChoiceOptions(allSheets[SHEET_CHOICE_OPTIONS], result);
      print('✅ Choice options imported: ${result.choiceOptionsImported}');

      print('7️⃣ Importing items...');
      await _importItems(allSheets[SHEET_ITEMS], result);
      print('✅ Items imported: ${result.itemsImported}');

      print('8️⃣ Importing item variants...');
      await _importItemVariants(allSheets[SHEET_ITEM_VARIANTS], result);
      print('✅ Item variants imported: ${result.itemVariantsImported}');

      // 🔄 Force Hive to notify listeners by flushing all boxes
      print('🔄 Flushing Hive boxes to trigger UI updates...');
      await _flushAllBoxes();

      // Add a delay to ensure all listeners process the changes
      await Future.delayed(const Duration(milliseconds: 300));
      print('✅ Hive boxes flushed and listeners notified');

      result.success = result.errors.isEmpty;
      print('✅ Import process complete! Success: ${result.success}');
      return result;
    } catch (e, stackTrace) {
      print('❌ Fatal error during import: $e');
      print('Stack trace: $stackTrace');
      result.errors.add('Fatal error during import: $e');
      result.success = false;
      return result;
    }
  }

  Future<void> _importCategories(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);
        String imagePath = _getValue(row, 2);

        // Check if already exists
        final allCategories = await HiveBoxes.getAllCategories();
        var existing = allCategories.where((c) => c.id == id).firstOrNull;
        if (existing != null) {
          result.warnings.add('Category $id already exists, skipping');
          continue;
        }

        Category category = Category(
          id: id,
          name: name,
          imagePath: imagePath.isEmpty ? null : imagePath,
          createdTime: DateTime.now(),
        );

        await HiveBoxes.addCategory(category);
        imported++;
      } catch (e) {
        result.errors.add('Row ${i + 1} in Categories: $e');
      }
    }
    result.categoriesImported = imported;
  }

  Future<void> _importVariants(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);

        // Check if already exists
        final allVariants = await HiveVariante.getAllVariante();
        var existing = allVariants.where((v) => v.id == id).firstOrNull;
        if (existing != null) {
          result.warnings.add('Variant $id already exists, skipping');
          continue;
        }

        VariantModel variant = VariantModel(
          id: id,
          name: name,
          createdTime: DateTime.now(),
        );

        await HiveVariante.addVariante(variant);
        imported++;
      } catch (e) {
        result.errors.add('Row ${i + 1} in Variants: $e');
      }
    }
    result.variantsImported = imported;
  }

  Future<void> _importExtras(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);
        bool isEnabled = _parseBool(_getValue(row, 2), true);
        int? minimum = _getInt(row, 3);
        int? maximum = _getInt(row, 4);

        // Check if already exists
        final allExtras = await HiveExtra.getAllExtra();
        var existing = allExtras.where((e) => e.Id == id).firstOrNull;
        if (existing != null) {
          result.warnings.add('Extra $id already exists, skipping');
          continue;
        }

        Extramodel extra = Extramodel(
          Id: id,
          Ename: name,
          isEnabled: isEnabled,
          minimum: minimum,
          maximum: maximum,
          topping: [],
          createdTime: DateTime.now(),
        );

        await HiveExtra.addextra(extra);
        imported++;
      } catch (e) {
        result.errors.add('Row ${i + 1} in Extras: $e');
      }
    }
    result.extrasImported = imported;
  }

  Future<void> _importToppings(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    // Group toppings by extraId and name to handle variant pricing
    Map<String, Map<String, List<List<dynamic>>>> toppingGroups = {};

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;

      String extraId = _getValue(row, 0);
      String toppingName = _getValue(row, 1);

      if (extraId.isEmpty || toppingName.isEmpty) continue;

      if (!toppingGroups.containsKey(extraId)) {
        toppingGroups[extraId] = {};
      }
      if (!toppingGroups[extraId]!.containsKey(toppingName)) {
        toppingGroups[extraId]![toppingName] = [];
      }
      toppingGroups[extraId]![toppingName]!.add(row);
    }

    int imported = 0;
    for (var extraId in toppingGroups.keys) {
      try {
        // Find the extra
        final allExtras = await HiveExtra.getAllExtra();
        var extra = allExtras.where((e) => e.Id == extraId).firstOrNull;
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

                // Get variant model
                final allVariants = await HiveVariante.getAllVariante();
                var variantModel = allVariants
                    .where((v) => v.id == variantId)
                    .firstOrNull;
                if (variantModel != null && !variantModels.any((v) => v.id == variantId)) {
                  variantModels.add(variantModel);
                }
              }
            }
          }

          Topping topping = Topping(
            name: toppingName,
            isveg: isveg,
            price: price,
            isContainSize: isContainSize,
            variantion: variantModels,
            variantPrices: variantPrices,
            createdTime: DateTime.now(),
          );

          toppings.add(topping);
          imported++;
        }

        // Update extra with new toppings
        var updatedExtra = extra.copyWith(topping: toppings);
        await HiveExtra.updateExtra(updatedExtra);

      } catch (e) {
        result.errors.add('Error importing toppings for extra $extraId: $e');
      }
    }
    result.toppingsImported = imported;
  }

  Future<void> _importChoices(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);

        // Check if already exists
        final allChoices = await HiveChoice.getAllChoice();
        var existing = allChoices.where((c) => c.id == id).firstOrNull;
        if (existing != null) {
          result.warnings.add('Choice $id already exists, skipping');
          continue;
        }

        ChoicesModel choice = ChoicesModel(
          id: id,
          name: name,
          choiceOption: [],
          createdTime: DateTime.now(),
        );

        await HiveChoice.addChoice(choice);
        imported++;
      } catch (e) {
        result.errors.add('Row ${i + 1} in Choices: $e');
      }
    }
    result.choicesImported = imported;
  }

  Future<void> _importChoiceOptions(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    // Group options by choiceId
    Map<String, List<List<dynamic>>> optionGroups = {};

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;

      String choiceId = _getValue(row, 0);
      if (choiceId.isEmpty) continue;

      if (!optionGroups.containsKey(choiceId)) {
        optionGroups[choiceId] = [];
      }
      optionGroups[choiceId]!.add(row);
    }

    int imported = 0;
    for (var choiceId in optionGroups.keys) {
      try {
        // Find the choice
        final allChoices = await HiveChoice.getAllChoice();
        var choice = allChoices.where((c) => c.id == choiceId).firstOrNull;
        if (choice == null) {
          result.errors.add('Choice $choiceId not found for options');
          continue;
        }

        List<ChoiceOption> options = choice.choiceOption.toList();

        for (var row in optionGroups[choiceId]!) {
          String optionId = _getValue(row, 1);
          String optionName = _getValue(row, 2);

          if (optionId.isEmpty || optionName.isEmpty) continue;

          ChoiceOption option = ChoiceOption(
            id: optionId,
            name: optionName,
          );

          options.add(option);
          imported++;
        }

        // Update choice with new options
        var updatedChoice = choice.copyWith(option: options);
        await HiveChoice.updateChoice(updatedChoice);

      } catch (e) {
        result.errors.add('Error importing options for choice $choiceId: $e');
      }
    }
    result.choiceOptionsImported = imported;
  }

  Future<void> _importItems(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);
        String categoryOfItem = _getValue(row, 2);
        String description = _getValue(row, 3);
        double price = _getDouble(row, 4);
        String isVeg = _getValue(row, 5);
        String unit = _getValue(row, 6);
        bool isSoldByWeight = _parseBool(_getValue(row, 7), false);
        bool trackInventory = _parseBool(_getValue(row, 8), false);
        double stockQuantity = _getDouble(row, 9);
        bool allowOrderWhenOutOfStock = _parseBool(_getValue(row, 10), true);
        double taxRate = _getDouble(row, 11);
        bool isEnabled = _parseBool(_getValue(row, 12), true);
        bool hasVariants = _parseBool(_getValue(row, 13), false);
        String choiceIdsStr = _getValue(row, 14);
        String extraIdsStr = _getValue(row, 15);
        String imagePath = _getValue(row, 16);

        // Check if already exists
        final allItems = await itemsBoxes.getAllItems();
        var existing = allItems.where((item) => item.id == id).firstOrNull;
        if (existing != null) {
          result.warnings.add('Item $id already exists, skipping');
          continue;
        }

        // Parse comma-separated IDs
        List<String> choiceIds = choiceIdsStr.isEmpty
            ? []
            : choiceIdsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        List<String> extraIds = extraIdsStr.isEmpty
            ? []
            : extraIdsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        // Convert image path to bytes if present
        Uint8List? imageBytes;
        if (imagePath.isNotEmpty) {
          try {
            final file = File(imagePath);
            if (file.existsSync()) {
              imageBytes = await file.readAsBytes();
            }
          } catch (e) {
            print('⚠️ Failed to read image for item $id: $e');
          }
        }

        Items item = Items(
          id: id,
          name: name,
          categoryOfItem: categoryOfItem.isEmpty ? null : categoryOfItem,
          description: description.isEmpty ? null : description,
          price: hasVariants ? null : price,
          isVeg: isVeg.isEmpty ? null : isVeg,
          unit: unit.isEmpty ? null : unit,
          isSoldByWeight: isSoldByWeight,
          trackInventory: trackInventory,
          stockQuantity: hasVariants ? 0 : stockQuantity,
          allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
          taxRate: taxRate,
          isEnabled: isEnabled,
          variant: [], // Will be populated by ItemVariants sheet
          choiceIds: choiceIds,
          extraId: extraIds,
          imageBytes: imageBytes,
          createdTime: DateTime.now(),
          lastEditedTime: DateTime.now(),
        );

        await itemsBoxes.addItem(item);
        imported++;
      } catch (e) {
        result.errors.add('Row ${i + 1} in Items: $e');
      }
    }
    result.itemsImported = imported;
  }

  Future<void> _importItemVariants(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 2) return;

    // Group variants by itemId
    Map<String, List<List<dynamic>>> variantGroups = {};

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;

      String itemId = _getValue(row, 0);
      if (itemId.isEmpty) continue;

      if (!variantGroups.containsKey(itemId)) {
        variantGroups[itemId] = [];
      }
      variantGroups[itemId]!.add(row);
    }

    int imported = 0;
    for (var itemId in variantGroups.keys) {
      try {
        // Find the item
        final allItems = await itemsBoxes.getAllItems();
        var item = allItems.where((i) => i.id == itemId).firstOrNull;
        if (item == null) {
          result.errors.add('Item $itemId not found for variants');
          continue;
        }

        List<ItemVariante> variants = [];

        for (var row in variantGroups[itemId]!) {
          String variantId = _getValue(row, 1);
          double price = _getDouble(row, 2);
          bool trackInventory = _parseBool(_getValue(row, 3), false);
          double stockQuantity = _getDouble(row, 4);

          if (variantId.isEmpty) continue;

          ItemVariante variant = ItemVariante(
            variantId: variantId,
            price: price,
            trackInventory: trackInventory,
            stockQuantity: stockQuantity,
          );

          variants.add(variant);
          imported++;
        }

        // Update item with variants
        var updatedItem = item.copyWith(variant: variants);
        await itemsBoxes.updateItem(updatedItem);

      } catch (e) {
        result.errors.add('Error importing variants for item $itemId: $e');
      }
    }
    result.itemVariantsImported = imported;
  }

  // Helper methods
  String _getValue(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    var value = row[index];
    if (value == null) return '';
    return value.toString().trim();
  }

  double _getDouble(List<dynamic> row, int index) {
    if (index >= row.length) return 0.0;
    String val = row[index].toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(val) ?? 0.0;
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

  /// Flush and compact all Hive boxes to ensure listeners are notified
  Future<void> _flushAllBoxes() async {
    try {
      print('📦 Opening and compacting boxes to trigger UI updates...');

      // Get all boxes
      final categoryBox = await HiveBoxes.getCategory();
      final itemBox = await itemsBoxes.getItemBox();
      final variantBox = await HiveVariante.getVariante();
      final extraBox = await HiveExtra.getextra();
      final choiceBox = await HiveChoice.getchoice();

      // Flush all boxes to write to disk
      await categoryBox.flush();
      await itemBox.flush();
      await variantBox.flush();
      await extraBox.flush();
      await choiceBox.flush();

      // Compact boxes to reorganize and trigger deep listeners
      await categoryBox.compact();
      await itemBox.compact();
      await variantBox.compact();
      await extraBox.compact();
      await choiceBox.compact();

      // Final flush after compact
      await categoryBox.flush();
      await itemBox.flush();
      await variantBox.flush();
      await extraBox.flush();
      await choiceBox.flush();

      print('✅ All boxes flushed and compacted');
    } catch (e) {
      print('⚠️ Error flushing boxes: $e');
      // Don't throw - this is just to ensure UI updates
    }
  }
}

/// Result class for import operation
class ImportResult {
  bool success = false;
  List<String> errors = [];
  List<String> warnings = [];

  int categoriesImported = 0;
  int variantsImported = 0;
  int extrasImported = 0;
  int toppingsImported = 0;
  int choicesImported = 0;
  int choiceOptionsImported = 0;
  int itemsImported = 0;
  int itemVariantsImported = 0;

  String getSummary() {
    StringBuffer sb = StringBuffer();

    if (success) {
      sb.writeln('✅ Import completed successfully!');
    } else {
      sb.writeln('❌ Import completed with errors');
    }

    sb.writeln('\nImported:');
    sb.writeln('  Categories: $categoriesImported');
    sb.writeln('  Variants: $variantsImported');
    sb.writeln('  Extras: $extrasImported');
    sb.writeln('  Toppings: $toppingsImported');
    sb.writeln('  Choices: $choicesImported');
    sb.writeln('  Choice Options: $choiceOptionsImported');
    sb.writeln('  Items: $itemsImported');
    sb.writeln('  Item Variants: $itemVariantsImported');

    if (warnings.isNotEmpty) {
      sb.writeln('\nWarnings (${warnings.length}):');
      for (var warning in warnings.take(10)) {
        sb.writeln('  ⚠️ $warning');
      }
      if (warnings.length > 10) {
        sb.writeln('  ... and ${warnings.length - 10} more warnings');
      }
    }

    if (errors.isNotEmpty) {
      sb.writeln('\nErrors (${errors.length}):');
      for (var error in errors.take(10)) {
        sb.writeln('  ❌ $error');
      }
      if (errors.length > 10) {
        sb.writeln('  ... and ${errors.length - 10} more errors');
      }
    }

    return sb.toString();
  }
}