import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_choice.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_extra.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_variante.dart';
import 'package:uuid/uuid.dart';

class RestaurantBulkImportService {
  // No need for store instances - using Hive directly

  // Template Headers
  static const List<String> headers = [
    'Name', // 0
    'Category', // 1
    'Description', // 2
    'Price', // 3
    'Is Veg (Yes/No)', // 4
    'Unit', // 5
    'Track Inventory (Yes/No)', // 6
    'Stock', // 7
    'Has Variants (Yes/No)', // 8
    'Variant Name', // 9
    'Variant Price', // 10
    'Extra Groups', // 11 (Comma separated)
    'Choice Groups' // 12 (Comma separated)
  ];

  Future<String> downloadTemplate() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];

      // Add Headers
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
      }

      // Add Sample Data
      _addSampleRow(sheet, 1, 'Chicken Burger', 'Burgers', 'Delicious chicken burger', 150, 'No', 'pcs', 'Yes', 50, 'No', '', 0, 'Toppings', 'Sauces');
      _addSampleRow(sheet, 2, 'Veg Pizza', 'Pizza', 'Cheese pizza', 0, 'Yes', 'pcs', 'Yes', 0, 'Yes', 'Small', 200, 'Cheese', '');
      _addSampleRow(sheet, 3, 'Veg Pizza', 'Pizza', 'Cheese pizza', 0, 'Yes', 'pcs', 'Yes', 0, 'Yes', 'Medium', 300, 'Cheese', '');
      _addSampleRow(sheet, 4, 'Veg Pizza', 'Pizza', 'Cheese pizza', 0, 'Yes', 'pcs', 'Yes', 0, 'Yes', 'Large', 400, 'Cheese', '');

      // Save file
      if (Platform.isAndroid || Platform.isIOS) {
        if (await Permission.storage.request().isGranted ||
            await Permission.manageExternalStorage.request().isGranted) {
          final directory = await getDownloadsDirectory();
          if (directory == null) return 'Could not access downloads directory';
          final path = '${directory.path}/unipos_restaurant_template.xlsx';
          final file = File(path);
          await file.writeAsBytes(excel.encode()!);
          return 'Template saved to $path';
        } else {
          return 'Permission denied';
        }
      } else {
        // Desktop
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: 'unipos_restaurant_template.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsBytes(excel.encode()!);
          return 'Template saved successfully';
        }
      }
      return 'Download cancelled';
    } catch (e) {
      return 'Error downloading template: $e';
    }
  }

  void _addSampleRow(Sheet sheet, int rowIndex, String name, String category, String desc, double price, String isVeg, String unit, String trackStock, double stock, String hasVariants, String vName, double vPrice, String extras, String choices) {
    List<dynamic> values = [
      name, category, desc, price, isVeg, unit, trackStock, stock, hasVariants, vName, vPrice, extras, choices
    ];
    for (int i = 0; i < values.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      if (values[i] is String) {
        cell.value = TextCellValue(values[i]);
      } else if (values[i] is double || values[i] is int) {
        cell.value = DoubleCellValue(values[i].toDouble());
      }
    }
  }

  Future<List<List<dynamic>>> pickAndParseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);

        final sheet = excel.tables[excel.tables.keys.first];
        if (sheet == null) return [];

        List<List<dynamic>> rows = [];
        for (var row in sheet.rows) {
          rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
        }
        return rows;
      }
    } catch (e) {
      print('Error parsing file: $e');
      throw Exception('Failed to parse file: $e');
    }
    return [];
  }

  Future<void> importData(List<List<dynamic>> rows) async {
    if (rows.length < 2) return; // Only headers

    // Data is available directly from Hive - no need to load
    final categories = await HiveBoxes.getAllCategories();
    final choices = await HiveChoice.getAllChoice();
    final extras = await HiveExtra.getAllExtra();
    final items = await itemsBoxes.getAllItems();

    // Skip headers
    final dataRows = rows.skip(1).toList();

    // Group rows by Item Name to handle variants
    Map<String, List<List<dynamic>>> itemGroups = {};
    for (var row in dataRows) {
      if (row.isEmpty) continue;
      String name = row[0].toString().trim();
      if (name.isEmpty) continue;

      if (!itemGroups.containsKey(name)) {
        itemGroups[name] = [];
      }
      itemGroups[name]!.add(row);
    }

    for (var entry in itemGroups.entries) {
      await _processItemGroup(entry.key, entry.value);
    }
  }

  Future<void> _processItemGroup(String itemName, List<List<dynamic>> rows) async {
    // Take the first row as the main item definition
    final mainRow = rows.first;

    // 1. Category
    String categoryName = _getValue(mainRow, 1);
    String categoryId = await _getOrCreateCategory(categoryName);

    // 2. Basic Details
    String description = _getValue(mainRow, 2);
    double price = _getDouble(mainRow, 3);
    String isVegStr = _getValue(mainRow, 4);
    String isVeg = isVegStr.toLowerCase() == 'yes' ? 'veg' : 'non-veg';
    String unit = _getValue(mainRow, 5);
    bool trackInventory = _getValue(mainRow, 6).toLowerCase() == 'yes';
    double stock = _getDouble(mainRow, 7);
    bool hasVariants = _getValue(mainRow, 8).toLowerCase() == 'yes';

    // 3. Extras & Choices
    String extraGroupNames = _getValue(mainRow, 11);
    String choiceGroupNames = _getValue(mainRow, 12);
    List<String> extraIds = await _mapGroupNamesToIds(extraGroupNames, isExtra: true);
    List<String> choiceIds = await _mapGroupNamesToIds(choiceGroupNames, isExtra: false);

    // 4. Variants
    List<ItemVariante> variants = [];
    if (hasVariants) {
      for (var row in rows) {
        String variantName = _getValue(row, 9);
        double variantPrice = _getDouble(row, 10);
        
        if (variantName.isEmpty) continue;

        String variantId = await _getOrCreateVariantModel(variantName);

        ItemVariante variant = ItemVariante(
          variantId: variantId,
          price: variantPrice,
          trackInventory: trackInventory,
          stockQuantity: trackInventory ? _getDouble(row, 7) : 0,
        );
        variants.add(variant);
      }
    }

    // 5. Create Item
    String itemId = const Uuid().v4();
    Items newItem = Items(
      id: itemId,
      name: itemName,
      description: description,
      categoryOfItem: categoryId,
      price: hasVariants ? 0 : price,
      isVeg: isVeg,
      unit: unit,
      trackInventory: trackInventory,
      stockQuantity: hasVariants ? 0 : stock,
      extraId: extraIds,
      choiceIds: choiceIds,
      variant: hasVariants ? variants : [],
      isEnabled: true,
      lastEditedTime: DateTime.now(),
      isSoldByWeight: false,
      allowOrderWhenOutOfStock: false,
      taxRate: 0,
    );

    await itemsBoxes.addItem(newItem);
  }

  String _getValue(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return row[index].toString().trim();
  }

  double _getDouble(List<dynamic> row, int index) {
    if (index >= row.length) return 0.0;
    String val = row[index].toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(val) ?? 0.0;
  }

  Future<String> _getOrCreateCategory(String name) async {
    if (name.isEmpty) return 'Uncategorized';

    try {
      final allCategories = await HiveBoxes.getAllCategories();
      var existing = allCategories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
        orElse: () => Category(id: '', name: ''),
      );

      if (existing.id.isNotEmpty) {
        return existing.id;
      }

      String newId = const Uuid().v4();
      Category newCat = Category(
        id: newId,
        name: name,
      );
      await HiveBoxes.addCategory(newCat);
      return newId;
    } catch (e) {
      print('Error finding/creating category: $e');
      return '';
    }
  }

  Future<String> _getOrCreateVariantModel(String name) async {
    if (name.isEmpty) return const Uuid().v4(); // Fallback

    try {
      List<VariantModel> allVariants = await HiveVariante.getAllVariante();
      var existing = allVariants.firstWhere(
        (v) => v.name.toLowerCase() == name.toLowerCase(),
        orElse: () => VariantModel(id: '', name: ''),
      );

      if (existing.id.isNotEmpty) {
        return existing.id;
      }

      // Create new VariantModel
      String newId = const Uuid().v4();
      VariantModel newVariant = VariantModel(
        id: newId,
        name: name,
        createdTime: DateTime.now(),
      );
      await HiveVariante.addVariante(newVariant);
      return newId;
    } catch (e) {
      print('Error finding/creating variant: $e');
      return const Uuid().v4();
    }
  }

  Future<List<String>> _mapGroupNamesToIds(String commaSeparatedNames, {required bool isExtra}) async {
    if (commaSeparatedNames.isEmpty) return [];
    
    List<String> names = commaSeparatedNames.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    List<String> ids = [];

    if (isExtra) {
      final allExtras = await HiveExtra.getAllExtra();
      for (String name in names) {
        try {
          var extra = allExtras.firstWhere(
            (e) => e.Ename.toLowerCase() == name.toLowerCase(),
            orElse: () => null as dynamic,
          );
          if (extra != null) ids.add(extra.Id);
        } catch (e) { /* ignore */ }
      }
    } else {
      final allChoices = await HiveChoice.getAllChoice();
      for (String name in names) {
        try {
          var choice = allChoices.firstWhere(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
            orElse: () => null as dynamic,
          );
          if (choice != null) ids.add(choice.id);
        } catch (e) { /* ignore */ }
      }
    }
    return ids;
  }
}