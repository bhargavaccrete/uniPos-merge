import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/choicemodel_306.dart';
import 'package:billberrylite/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:billberrylite/data/models/restaurant/db/extramodel_303.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/models/restaurant/db/taxmodel_314.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import 'import_template_builder.dart';

/// Restaurant bulk import service.
///
/// Imports a multi-sheet Excel workbook (categories, variants, extras,
/// toppings, choices, items, item-variants) into the menu. Features:
/// row-level validation, auto-category creation from names, in-memory
/// caching, image-URL download, and optional progress callbacks.
class RestaurantBulkImportService {
  // Progress callback
  final void Function(int current, int total, String message)? onProgress;

  // In-memory caches (loaded once, reused)
  Map<String, Category> _categoryCache = {};
  Map<String, Category> _categoryByNameCache = {};
  Map<String, ChoicesModel> _choiceCache = {};
  Map<String, ChoicesModel> _choiceByNameCache = {}; // lowercased name → choice
  Map<String, Extramodel> _extraCache = {};
  Map<String, Extramodel> _extraByNameCache = {}; // lowercased name → extra
  Map<String, VariantModel> _variantCache = {};
  Map<String, VariantModel> _variantByNameCache = {}; // For auto-create by name
  Map<double, Tax> _taxByRateCache = {}; // Cache taxes by percentage rate
  Map<String, Items> _itemByNameCache = {}; // For duplicate detection (name → item)

  RestaurantBulkImportService({this.onProgress});

  // Sheet names
  static const String SHEET_CATEGORIES = 'Categories';
  static const String SHEET_VARIANTS = 'Variants';
  static const String SHEET_EXTRAS = 'Extras';
  static const String SHEET_TOPPINGS = 'Toppings';
  static const String SHEET_CHOICES = 'Choices';
  static const String SHEET_CHOICE_OPTIONS = 'ChoiceOptions';
  static const String SHEET_ITEMS = 'Items';
  static const String SHEET_ITEM_VARIANTS = 'ItemVariants';

  /// Enhanced template with dropdowns + input tooltips (built with Syncfusion
  /// xlsio so we can write Data Validation, which the `excel` package cannot).
  Future<String> downloadTemplate() async {
    try {
      final bytes = ImportTemplateBuilder().build();
      return await _saveBytes(bytes, 'billberrylite_restaurant_import_template_v4.xlsx');
    } catch (e) {
      return 'Error downloading template: $e';
    }
  }

  Future<String> _saveBytes(List<int> bytes, String fileName) async {
    try {
      if (kIsWeb) {
        // Web platform: Use FilePicker with bytes
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        return result != null ? 'Template downloaded successfully' : 'Download cancelled';
      } else if (Platform.isAndroid || Platform.isIOS) {
        // ✅ FIXED: Use FilePicker for Android/iOS to handle permissions automatically
        // This shows a native file picker dialog and handles all storage permissions
        // On Android/iOS, bytes parameter is REQUIRED and FilePicker handles the write
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes), // Required on Android/iOS
        );

        if (result != null) {
          // FilePicker automatically writes the bytes on Android/iOS
          return 'Template saved successfully to Downloads';
        } else {
          // saveFile returns null when the user backs out of the save dialog.
          return 'Download cancelled';
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
  Future<ImportResult> importData(Map<String, List<List<dynamic>>> allSheets) async {
    ImportResult result = ImportResult();

    try {

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

      return result;
    } catch (e, stackTrace) {
      result.errors.add('Fatal error: $e');
      result.success = false;
      return result;
    }
  }

  /// Load all data into in-memory caches using stores
  Future<void> _loadAllCaches() async {

    try {
      // Load categories with case-insensitive name matching
      await categoryStore.loadCategories();
      final categories = categoryStore.categories;
      _categoryCache = {for (var cat in categories) cat.id: cat};
      // ✅ IMPROVED: Trim and lowercase for consistent matching (Pizza, pizza, " Pizza " all match)
      _categoryByNameCache = {for (var cat in categories) cat.name.toLowerCase().trim(): cat};
    } catch (e) {
      // Continue with empty cache
    }

    try {
      // Load choices
      await choiceStore.loadChoices();
      final choices = choiceStore.choices;
      _choiceCache = {for (var choice in choices) choice.id: choice};
      _choiceByNameCache = {
        for (var choice in choices) choice.name.toLowerCase().trim(): choice
      };
    } catch (e) {
    }

    try {
      // Load extras
      await extraStore.loadExtras();
      final extras = extraStore.extras;
      _extraCache = {for (var extra in extras) extra.Id: extra};
      _extraByNameCache = {
        for (var extra in extras) extra.Ename.toLowerCase().trim(): extra
      };
    } catch (e) {
    }

    try {
      // Load existing items for duplicate detection
      await itemStore.loadItems();
      final existingItems = itemStore.items;
      _itemByNameCache = {for (var item in existingItems) item.name.toLowerCase().trim(): item};
    } catch (e) {
    }

    try {
      // Load variants
      await variantStore.loadVariants();
      final variants = variantStore.variants;
      _variantCache = {for (var variant in variants) variant.id: variant};
      _variantByNameCache = {for (var variant in variants) variant.name.toLowerCase().trim(): variant};
    } catch (e) {
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
    } catch (e) {
    }
  }

  /// ✅ CRITICAL: Row-level validation
  ValidationResult _validateItemRow(
    Map<String, dynamic> row,
    int rowNumber,
    Set<String> existingCodes,
    Set<String> batchCodes,
  ) {
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
    if (vegType.isNotEmpty && vegType != 'veg' && vegType != 'non-veg' && vegType != 'egg') {
      errors.add('Row $rowNumber: VegType must be "Veg", "Non-Veg" or "Egg" (got "$vegType")');
    }

    // 5. Weight + Unit validation
    final isSoldByWeight = _parseBool(row['IsSoldByWeight']?.toString() ?? '', false);
    final unit = row['Unit']?.toString().trim() ?? '';
    // Unit is required for by-weight items; any provided unit must be one the
    // app supports (aliases like 'litre'/'pcs' are accepted and normalized).
    if (isSoldByWeight && unit.isEmpty) {
      errors.add('Row $rowNumber: Unit required when IsSoldByWeight is YES');
    }
    if (unit.isNotEmpty && normalizeItemUnit(unit) == null) {
      errors.add('Row $rowNumber: Unrecognized Unit "$unit" (use kg, gm, liter, ml or piece)');
    }

    // 6. Inventory validation
    final trackInventory = _parseBool(row['TrackInventory']?.toString() ?? '', false);
    final allowOutOfStock = row['AllowOutOfStock']?.toString().trim() ?? '';
    if (trackInventory && allowOutOfStock.isEmpty) {
      errors.add('Row $rowNumber: AllowOutOfStock required when TrackInventory is YES');
    }

    // 7. ItemCode validation — format only. A duplicate code is NOT a hard
    // error here; the import loop skips it with a warning, consistent with how
    // a duplicate item name is handled.
    final itemCode = row['ItemCode']?.toString().trim() ?? '';
    if (itemCode.isNotEmpty && !RegExp(r'^\d{4,5}$').hasMatch(itemCode)) {
      errors.add('Row $rowNumber: Item code must be 4-5 digits');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// ✅ CRITICAL: Auto-create category from name (case-insensitive, duplicate-safe)
  /// Prevents duplicates: "Pizza", "pizza", " Pizza " all map to the same category
  Future<String> _getOrCreateCategory(String categoryName, ImportResult result) async {
    final nameLower = categoryName.toLowerCase().trim();

    // Check cache first (O(1) lookup) - prevents duplicates
    if (_categoryByNameCache.containsKey(nameLower)) {
      final existingCategory = _categoryByNameCache[nameLower]!;
      return existingCategory.id;
    }

    // Near-miss detection: a very similar category already existing usually
    // means a typo ("Pizzza" vs "Pizza"). We still create it as-is — never
    // silently merge into a guessed category — but flag it loudly.
    final similar = _findSimilarCategoryName(nameLower);
    if (similar != null) {
      result.warnings.add(
        '⚠️ Category "${categoryName.trim()}" looks similar to existing "$similar" — created as new; check for duplicates.',
      );
    }

    // Category doesn't exist - create it
    final newCategory = Category(
      id: const Uuid().v4(),
      name: categoryName.trim(), // Use trimmed name for consistency
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

  /// Returns an existing category name within edit-distance 1 of [nameLower]
  /// (a likely typo), or null.
  String? _findSimilarCategoryName(String nameLower) {
    for (final existing in _categoryByNameCache.values) {
      final other = existing.name.toLowerCase().trim();
      if (other == nameLower) continue;
      if ((other.length - nameLower.length).abs() > 1) continue;
      if (_within1Edit(nameLower, other)) return existing.name;
    }
    return null;
  }

  /// True if [a] and [b] differ by at most one insert/delete/substitution.
  bool _within1Edit(String a, String b) {
    final int la = a.length, lb = b.length;
    if ((la - lb).abs() > 1) return false;
    int i = 0, j = 0, edits = 0;
    while (i < la && j < lb) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (la > lb) {
        i++; // deletion from a
      } else if (lb > la) {
        j++; // insertion into a
      } else {
        i++;
        j++; // substitution
      }
    }
    if (i < la || j < lb) edits++; // leftover trailing char
    return edits <= 1;
  }

  /// Resolve choice/extra references from one or more columns into a
  /// de-duplicated list of IDs. Each cell may hold a name (from the dropdown)
  /// or, for legacy files, comma-separated IDs. Unmatched values are warned.
  List<String> _resolveRefs(
    Map<String, dynamic> rowData, {
    required List<String> columns,
    required Map<String, String> byName, // lowercased name → id
    required Map<String, dynamic> byId, // id → model (membership check only)
    required String kind,
    required int rowNumber,
    required ImportResult result,
  }) {
    final List<String> ids = [];
    for (final col in columns) {
      final raw = rowData[col]?.toString().trim() ?? '';
      if (raw.isEmpty) continue;
      for (final token in raw.split(',')) {
        final t = token.trim();
        if (t.isEmpty) continue;
        final resolved = byName[t.toLowerCase()] ?? (byId.containsKey(t) ? t : null);
        if (resolved == null) {
          result.warnings.add('Row $rowNumber: $kind "$t" not found, skipped');
          continue;
        }
        if (!ids.contains(resolved)) ids.add(resolved);
      }
    }
    return ids;
  }

  /// ✅ CRITICAL: Auto-create tax from rate (duplicate-safe)
  /// Prevents duplicates: same tax rate will reuse existing tax
  Future<String> _getOrCreateTax(double taxRate, ImportResult result) async {
    // Check cache first (O(1) lookup) - prevents duplicates
    if (_taxByRateCache.containsKey(taxRate)) {
      final existingTax = _taxByRateCache[taxRate]!;
      return existingTax.id;
    }

    // Tax doesn't exist - create it

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

  /// ✅ Auto-create variant by name (case-insensitive, duplicate-safe)
  /// Allows ItemVariants sheet to reference names like "Half" or "Full"
  /// without requiring them to be pre-defined in the Variants sheet.
  Future<VariantModel> _getOrCreateVariant(String variantName, ImportResult result) async {
    final nameLower = variantName.toLowerCase().trim();

    // Check by-name cache first
    if (_variantByNameCache.containsKey(nameLower)) {
      return _variantByNameCache[nameLower]!;
    }

    // Not found — auto-create
    final newVariant = VariantModel(
      id: const Uuid().v4(),
      name: variantName.trim(),
      createdTime: DateTime.now(),
    );

    await variantStore.addVariant(newVariant);
    _variantCache[newVariant.id] = newVariant;
    _variantByNameCache[nameLower] = newVariant;
    result.variantsImported++;
    result.warnings.add('✨ Auto-created variant: ${newVariant.name}');
    return newVariant;
  }

  /// ✅ CRITICAL: Download image from URL
  Future<String?> _downloadImage(String imageUrl, String itemId, ImportResult result) async {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return null;
    }

    try {

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

      result.imagesDownloaded++;

      return file.path;
    } catch (e) {
      result.warnings.add('Failed to download image: $imageUrl ($e)');
      return null;
    }
  }

  Future<void> _importCategories(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);
        String name = _getValue(row, 1);
        final nameKey = name.toLowerCase().trim();

        // Skip duplicates by ID...
        if (_categoryCache.containsKey(id)) {
          result.warnings.add('Category $id already exists, skipping');
          continue;
        }
        // ...and by name (case-insensitive) so "Pizza"/"pizza" don't both get
        // created when one already exists (manually or from another row).
        if (_categoryByNameCache.containsKey(nameKey)) {
          result.warnings.add(
              'Category "${name.trim()}" already exists — skipped duplicate');
          continue;
        }

        Category category = Category(
          id: id,
          name: name.trim(),
          createdTime: DateTime.now(),
          editCount: 0,
        );

        final success = await categoryStore.addCategory(category);
        if (success) {
          _categoryCache[id] = category;
          _categoryByNameCache[nameKey] = category;
          result.categoriesImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Categories: $e');
      }
    }
  }

  Future<void> _importVariants(List<List<dynamic>>? rows, ImportResult result) async {
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

  Future<void> _importExtras(List<List<dynamic>>? rows, ImportResult result) async {
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
          _extraByNameCache[extra.Ename.toLowerCase().trim()] = extra;
          result.extrasImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Extras: $e');
      }
    }
  }

  Future<void> _importToppings(List<List<dynamic>>? rows, ImportResult result) async {
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
        int addedToppings = 0;

        for (var toppingName in toppingGroups[extraId]!.keys) {
          // Skip toppings this extra already has — prevents duplicates when the
          // same file is re-imported (the group dedupes by id, children must too).
          if (toppings.any((t) =>
              t.name.toLowerCase().trim() == toppingName.toLowerCase().trim())) {
            result.warnings.add('Topping "$toppingName" already in extra $extraId, skipping');
            continue;
          }

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
          addedToppings++;
        }

        // Only persist when something new was actually added.
        if (addedToppings > 0) {
          var updatedExtra = extra.copyWith(topping: toppings);
          await extraStore.updateExtra(updatedExtra);
          _extraCache[extraId] = updatedExtra;
        }
      } catch (e) {
        result.errors.add('Error importing toppings for extra $extraId: $e');
      }
    }
  }

  Future<void> _importChoices(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      try {
        var row = rows[i];
        if (row.isEmpty || _getValue(row, 0).isEmpty) continue;

        String id = _getValue(row, 0);

        if (_choiceCache.containsKey(id)) {
          result.warnings.add('Choice $id already exists, skipping');
          continue;
        }

        // Read allowMultiple field (column 2)
        final allowMultipleStr = _getValue(row, 2);
        final allowMultiple = _parseBool(allowMultipleStr, false);

        ChoicesModel choice = ChoicesModel(
          id: id,
          name: _getValue(row, 1),
          choiceOption: [],
          createdTime: DateTime.now(),
          allowMultipleSelection: allowMultiple,
        );

        final success = await choiceStore.addChoice(choice);
        if (success) {
          _choiceCache[id] = choice;
          _choiceByNameCache[choice.name.toLowerCase().trim()] = choice;
          result.choicesImported++;
        }
      } catch (e) {
        result.errors.add('Row ${i + 1} in Choices: $e');
      }
    }
  }

  Future<void> _importChoiceOptions(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    Map<String, List<List<dynamic>>> optionGroups = {};

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
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
          result.errors.add('Choice "$choiceId" not found for options. Make sure the choice ID exists in Choices sheet.');
          continue;
        }


        List<ChoiceOption> options = choice.choiceOption.toList();
        int addedOptions = 0;

        for (var row in optionGroups[choiceId]!) {
          String optionId = _getValue(row, 1);
          String optionName = _getValue(row, 2);

          if (optionId.isEmpty || optionName.isEmpty) continue;

          // Skip options this choice already has — prevents duplicates on
          // re-import (match by id or by name).
          if (options.any((o) =>
              o.id == optionId ||
              o.name.toLowerCase().trim() == optionName.toLowerCase().trim())) {
            result.warnings.add('Option "$optionName" already in choice $choiceId, skipping');
            continue;
          }

          options.add(ChoiceOption(
            id: optionId,
            name: optionName,
          ));
          result.choiceOptionsImported++;
          addedOptions++;
        }

        // Only persist (and bump editCount) when new options were added.
        if (addedOptions > 0) {
          var updatedChoice = ChoicesModel(
            id: choice.id,
            name: choice.name,
            choiceOption: options,
            createdTime: choice.createdTime,
            lastEditedTime: DateTime.now(),
            editedBy: 'BulkImport',
            editCount: choice.editCount + 1,
            allowMultipleSelection: choice.allowMultipleSelection, // Preserve the selection type
          );
          await choiceStore.updateChoice(updatedChoice);
          _choiceCache[choiceId] = updatedChoice;
        }
      } catch (e) {
        result.errors.add('Error importing options for choice $choiceId: $e');
      }
    }
  }

  /// ✅ ENHANCED: Items import with validation, auto-category, and image download
  Future<void> _importEnhancedItems(List<List<dynamic>>? rows, ImportResult result) async {
    if (rows == null || rows.length < 3) return; // Need at least: header + instruction + 1 data row

    // Get header row to map columns - STRIP ASTERISKS from required field markers
    final headers = rows[0].map((e) => e.toString().trim().replaceAll('*', '')).toList();

    final Set<String> existingCodes = {
      for (var item in itemStore.items)
        if (item.itemCode != null && item.itemCode!.isNotEmpty) item.itemCode!
    };
    final Set<String> batchCodes = {};

    // Start from row 2 to skip the instruction row (row 1)
    for (int i = 2; i < rows.length; i++) {
      try {
        var row = rows[i];

        // Debug: Print raw row data
        if (i <= 4) {
          if (row.isNotEmpty) {
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
        }

        // Step 1: Validate row
        final validation = _validateItemRow(rowData, i + 1, existingCodes, batchCodes);
        if (!validation.isValid) {
          result.failedRows.add(FailedRow(
            rowNumber: i + 1,
            errors: validation.errors,
          ));
          result.errors.addAll(validation.errors);
          continue;
        }

        // Step 2: If an item with this name already exists, UPDATE it from the
        // imported row (price, category, choices, extras, variants…) instead of
        // skipping — so re-imports enrich items added manually or earlier.
        final itemNameLower = (rowData['ItemName']?.toString().trim() ?? '').toLowerCase();
        final Items? existingItem = _itemByNameCache[itemNameLower];

        // Item code: when updating keep the existing item's code; otherwise
        // honour a provided code (skipping clashes) or auto-generate one.
        final providedCode = rowData['ItemCode']?.toString().trim() ?? '';
        String finalItemCode;
        if (existingItem != null) {
          finalItemCode = existingItem.itemCode ?? providedCode;
        } else {
          // Skip rows whose explicit ItemCode is already taken — a warning, not
          // a failure. Blank codes fall through to auto-generation below.
          if (providedCode.isNotEmpty &&
              (existingCodes.contains(providedCode) || batchCodes.contains(providedCode))) {
            result.warnings.add('Row ${i + 1}: Item code "$providedCode" already exists, skipping');
            continue;
          }
          if (providedCode.isEmpty) {
            int maxCode = 1000;
            for (final code in existingCodes) {
              final val = int.tryParse(code);
              if (val != null && val >= 1000 && val <= 99999) {
                if (val > maxCode) maxCode = val;
              }
            }
            for (final code in batchCodes) {
              final val = int.tryParse(code);
              if (val != null && val >= 1000 && val <= 99999) {
                if (val > maxCode) maxCode = val;
              }
            }
            finalItemCode = (maxCode + 1).toString();
            batchCodes.add(finalItemCode);
          } else {
            finalItemCode = providedCode;
            batchCodes.add(finalItemCode);
          }
        }

        // Step 3: Get or create category
        final categoryName = rowData['CategoryName']?.toString().trim() ?? '';
        final categoryId = await _getOrCreateCategory(categoryName, result);

        // Step 4: Download image if URL provided and convert to bytes
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
            }
          }
        }

        // Step 5: Resolve Choice/Extra references (names → IDs).
        // New template uses Choice1..3 / Extra1..3 dropdown names; legacy files
        // with comma-separated ChoiceIds / ExtraIds (raw IDs) still work.
        final List<String> choiceIds = _resolveRefs(
          rowData,
          columns: const ['Choice1', 'Choice2', 'Choice3', 'ChoiceIds'],
          byName: _choiceByNameCache.map((k, v) => MapEntry(k, v.id)),
          byId: _choiceCache,
          kind: 'Choice',
          rowNumber: i + 1,
          result: result,
        );
        final List<String> extraIds = _resolveRefs(
          rowData,
          columns: const ['Extra1', 'Extra2', 'Extra3', 'ExtraIds'],
          byName: _extraByNameCache.map((k, v) => MapEntry(k, v.Id)),
          byId: _extraCache,
          kind: 'Extra',
          rowNumber: i + 1,
          result: result,
        );

        // Step 6: Auto-create tax if tax rate is specified
        final rawTaxRate = _getDoubleFromValue(rowData['TaxRate']);
        final taxRateValue = _normalizeTaxRate(rawTaxRate);
        String? taxId;
        if (rawTaxRate != null && rawTaxRate > 0) {
          // Use raw value (5) for Tax creation, normalized value (0.05) for Item
          taxId = await _getOrCreateTax(rawTaxRate, result);
        }

        // Step 7: Create item
        final hasVariants = _parseBool(rowData['HasVariants']?.toString() ?? '', false);
        final soldByWeight = _parseBool(rowData['IsSoldByWeight']?.toString() ?? '', false);

        Items item = Items(
          id: existingItem?.id ?? const Uuid().v4(),
          name: rowData['ItemName']?.toString().trim() ?? '',
          categoryOfItem: categoryId,
          description: rowData['Description']?.toString().trim(),
          price: hasVariants ? null : _getDoubleFromValue(rowData['Price']),
          isVeg: rowData['VegType']?.toString().trim(),
          // Normalize to a canonical unit so the Edit screen's dropdown always
          // has a matching option (null when blank/unrecognized).
          unit: normalizeItemUnit(rowData['Unit']?.toString()),
          isSoldByWeight: soldByWeight,
          trackInventory: _parseBool(rowData['TrackInventory']?.toString() ?? '', false),
          stockQuantity: _getDoubleFromValue(rowData['StockQuantity']),
          allowOrderWhenOutOfStock: _parseBool(rowData['AllowOutOfStock']?.toString() ?? '', true),
          taxRate: taxRateValue,
          isEnabled: _parseBool(rowData['IsEnabled']?.toString() ?? '', true),
          // Preserve existing variants; the variant pass overrides them when the
          // import file actually carries variant rows for this item.
          variant: existingItem?.variant ?? [],
          choiceIds: choiceIds,
          extraId: extraIds,
          imageBytes: imageBytes ?? existingItem?.imageBytes,
          itemCode: finalItemCode,
          createdTime: existingItem?.createdTime ?? DateTime.now(),
          lastEditedTime: DateTime.now(),
          editedBy: 'BulkImport',
          editCount: existingItem?.editCount ?? 0,
        );

        final success = existingItem != null
            ? await itemStore.updateItem(item)
            : await itemStore.addItem(item);
        if (success) {
          if (existingItem != null) {
            result.warnings.add(
                'Row ${i + 1}: Item "${item.name}" already existed — updated from import');
          }
          result.itemsImported++;
          // Keep cache fresh so later rows in this batch see the latest version
          _itemByNameCache[item.name.toLowerCase().trim()] = item;
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

  Future<void> _importItemVariants(List<List<dynamic>>? rows, ImportResult result) async {
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

          // Inherit trackInventory from item when not specified in variant row
          final variantTrackRaw = _getValue(row, 3);
          bool trackInventory = variantTrackRaw.isEmpty
              ? item.trackInventory
              : _parseBool(variantTrackRaw, false);

          // Inherit stockQuantity from item when variant has no stock specified
          final variantStock = _getDouble(row, 4);
          double stockQuantity = (variantStock == 0 && item.stockQuantity > 0)
              ? item.stockQuantity
              : variantStock;

          // Find or auto-create variant by name
          final variant = await _getOrCreateVariant(variantName, result);

          variants.add(ItemVariante(
            variantId: variant.id,
            price: price,
            trackInventory: trackInventory,
            stockQuantity: stockQuantity,
          ));
          result.itemVariantsImported++;
        }

        // Set base price = minimum variant price so menu always shows a display price
        final minVariantPrice = variants.isNotEmpty
            ? variants.map((v) => v.price).reduce((a, b) => a < b ? a : b)
            : null;

        var updatedItem = item.copyWith(
          variant: variants,
          price: minVariantPrice,
        );
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
class ImportResult {
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
