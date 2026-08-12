import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:mobx/mobx.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/repositories/retail/product_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/presentation/screens/retail/import_product/retail_import_template_builder.dart';
import 'package:uuid/uuid.dart';

part 'bulk_import_store.g.dart';

class BulkImportStore = _BulkImportStore with _$BulkImportStore;

abstract class _BulkImportStore with Store {
  // Repositories
  late final ProductRepository _productRepository;
  late final VariantRepository _variantRepository;

  _BulkImportStore() {
    // Lazy initialization to prevent early Hive access
    _productRepository = ProductRepository();
    _variantRepository = VariantRepository();
  }

  // Get AttributeStore from injector (MobX store with observable lists)
  AttributeStore get _attributeStore => locator<AttributeStore>();

  // Observables
  @observable
  bool isLoading = false;

  @observable
  bool isProcessing = false;

  @observable
  String? errorMessage;

  @observable
  String? successMessage;

  @observable
  double progress = 0.0;

  @observable
  ObservableList<List<dynamic>> parsedRows = ObservableList<List<dynamic>>();

  @observable
  ObservableList<String> logMessages = ObservableList<String>();

  // Actions

  /// Generate and save Template (Excel .xlsx by default)
  @action
  Future<String?> downloadTemplate() async {
    isLoading = true;
    errorMessage = null;
    try {
      // Build the template with Syncfusion xlsio so Category/Tax Rate get real
      // Excel dropdowns (live-seeded from the shop's existing categories/taxes)
      // — same technique as the restaurant side's ImportTemplateBuilder.
      final bytes = RetailImportTemplateBuilder().build();

      // 5. Save File via native picker — handles web download, desktop
      //    Save dialog, and Android/iOS Downloads + permissions uniformly.
      const fileName = 'product_import_template.xlsx';

      if (kIsWeb) {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        successMessage = result != null
            ? 'Template downloaded successfully.'
            : 'Download cancelled.';
        return result;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // On Android/iOS bytes are required; FilePicker writes the file itself.
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        successMessage = result != null
            ? 'Template saved to Downloads.'
            : 'Download cancelled.';
        return result;
      } else {
        // Desktop (Windows/macOS/Linux): picker returns a path, we write bytes.
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        if (result != null) {
          await File(result).writeAsBytes(bytes);
          successMessage = 'Template saved successfully.';
        } else {
          successMessage = 'Download cancelled.';
        }
        return result;
      }
    } catch (e) {
      errorMessage = 'Failed to generate template: $e';
      return null;
    } finally {
      isLoading = false;
    }
  }

  /// Pick and Parse File (CSV or Excel)
  @action
  Future<void> pickAndParseFile() async {
    isLoading = true;
    errorMessage = null;
    parsedRows.clear();
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true, // Ensure we get bytes
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String extension = file.extension?.toLowerCase() ?? '';
        
        // 1. Get Bytes (Prioritize memory bytes)
        Uint8List? fileBytes = file.bytes;
        
        // 2. Fallback to reading from path if bytes are missing (Desktop/Native sometimes)
        if (fileBytes == null && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes == null) {
          throw Exception("Could not read file data. Please try again.");
        }

        // 3. Parse based on extension
        if (extension == 'csv') {
          // --- CSV Parsing ---
          String fileContent = utf8.decode(fileBytes);

          // Normalize line endings - replace \r\n with \n, then split by \n
          fileContent = fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

          // Check if file has proper line breaks
          int lineBreaks = '\n'.allMatches(fileContent).length;

          List<List<dynamic>> csvTable = const CsvToListConverter(
            eol: '\n',
            shouldParseNumbers: false, // Keep all as strings to preserve formatting
          ).convert(fileContent);

          // Filter out completely empty rows
          for (var row in csvTable) {
            // Skip rows that are completely empty
            if (row.every((cell) => cell.toString().trim().isEmpty)) {
              continue;
            }
            parsedRows.add(row);
          }


        } else if (extension == 'xlsx' || extension == 'xls') {
          // --- Excel Parsing ---
          var excel = Excel.decodeBytes(fileBytes);
          // The downloaded template has multiple sheets (Instructions,
          // Categories, Taxes, Products) — product data lives specifically in
          // "Products", not whichever sheet happens to come first (that's
          // "Instructions", which silently made every import fail with
          // "Product Name is required" since instruction lines have no name).
          if (excel.tables.isNotEmpty) {
            var table = excel.tables['Products'];
            if (table == null) {
              final match = excel.tables.keys.firstWhere(
                (name) => name.toLowerCase() == 'products',
                orElse: () => excel.tables.keys.first,
              );
              table = excel.tables[match];
            }

            if (table != null) {
              for (var row in table.rows) {
                // Convert Data objects to strings/values
                // Extract the actual value from the CellValue object
                List<dynamic> rowData = row.map((cell) {
                  if (cell == null || cell.value == null) return '';

                  // Get the actual value from the CellValue
                  var value = cell.value;
                  if (value is TextCellValue) {
                    return value.value;
                  } else if (value is IntCellValue) {
                    return value.value.toString();
                  } else if (value is DoubleCellValue) {
                    return value.value.toString();
                  } else if (value is BoolCellValue) {
                    return value.value.toString();
                  } else if (value is DateCellValue) {
                    return value.toString();
                  } else if (value is TimeCellValue) {
                    return value.toString();
                  } else if (value is DateTimeCellValue) {
                    return value.toString();
                  } else {
                    return value.toString();
                  }
                }).toList();
                // Skip empty rows
                if (rowData.any((cell) => cell.toString().isNotEmpty)) {
                  parsedRows.add(rowData);
                }
              }
            }
          }
        } else {
           throw Exception("Unsupported file format: $extension");
        }

        if (parsedRows.isEmpty || parsedRows.length < 2) {
          errorMessage = "File is empty or missing headers.";
          return;
        }

        // Debug: Print parsed data
        if (parsedRows.isNotEmpty) {
          if (parsedRows.length > 1) {
          }
        }

        successMessage = "Loaded ${parsedRows.length - 1} rows. Review and click Import.";
      }
    } catch (e) {
      errorMessage = 'Error parsing file: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Execute Import Process
  @action
  Future<void> importData() async {
    if (parsedRows.isEmpty) {
      errorMessage = "No data to import";
      return;
    }

    isProcessing = true;
    progress = 0.0;
    logMessages.clear();
    errorMessage = null;
    successMessage = null;

    if (!TaxFeature.enabled) {
      logMessages.add(
          'ℹ Tax data in file ignored — tax is disabled for this business.');
    }

    // Ensure AttributeStore has loaded existing attributes before we start importing
    try {
      await _attributeStore.loadAttributes();
    } catch (e) {
      // Continue anyway - attributes will be created as needed
    }

    try {
      // 1. Group rows by 'Handle' (Column 0)
      // The downloaded template has a second "instruction" row (yellow,
      // italic) with per-column hint text instead of real data — e.g. its
      // Selling Price cell literally says "Required: number only". Detect
      // and drop it instead of assuming a fixed single header row, so a
      // hand-typed CSV without an instruction row still imports its first
      // real row correctly.
      final rawRows = parsedRows.skip(1).toList();
      final dataRows = rawRows.isNotEmpty && !_looksLikeRealDataRow(rawRows.first)
          ? rawRows.skip(1).toList()
          : rawRows;

      Map<String, List<List<dynamic>>> groups = {};

      for (var row in dataRows) {
        if (row.isEmpty) {
          continue;
        }

        // Ensure row has enough columns (pad if needed)
        if (row.length < 18) {
           while (row.length < 18) {
             row.add('');
           }
        }

        String handle = row[0].toString().trim();

        if (handle.isEmpty) {
          continue;
        }

        if (!groups.containsKey(handle)) {
          groups[handle] = [];
        }
        groups[handle]!.add(row);
      }


      int totalGroups = groups.length;
      int processedGroups = 0;
      int successCount = 0;
      int errorCount = 0;

      // 2. Process Groups
      for (var entry in groups.entries) {
        String handle = entry.key;
        List<List<dynamic>> groupRows = entry.value;

        try {
          await _processGroup(handle, groupRows);
          logMessages.add('✓ Success: Imported $handle');
          successCount++;
        } catch (e) {
          logMessages.add('✗ Error: Failed to import $handle - $e');
          errorCount++;
        }

        processedGroups++;
        progress = processedGroups / totalGroups;
      }

      // This store writes through its own repositories, so ProductStore's
      // in-memory lists are stale until refreshed.
      await productStore.loadProducts();
      await productStore.loadVariants();

      if (errorCount == 0) {
        successMessage = "Import completed! Successfully imported $successCount products.";
      } else {
        successMessage = "Import completed with errors. Success: $successCount, Failed: $errorCount";
      }
    } catch (e) {
      errorMessage = "Import failed: $e";
    }
    // Note: We keep isProcessing=true so the user stays on the results screen
    // It will be set to false when they click "Done" and clear() is called
  }

  Future<void> _processGroup(String handle, List<List<dynamic>> rows) async {
    var parentRow = rows[0];

    String name = parentRow[1].toString().trim();
    String categoryName = parentRow[2].toString().trim();
    String description = parentRow[3].toString().trim();

    if (name.isEmpty) throw Exception("Product Name is required");

    String categoryId = '';
    if (categoryName.isNotEmpty) {
      Category? category;
      try {
        category = categoryStore.categories.firstWhere(
          (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
        );
      } catch (_) {
        category = null;
      }

      if (category != null) {
        categoryId = category.id;
      } else {
        final newCategory = Category(
          id: const Uuid().v4(),
          name: categoryName,
          createdTime: DateTime.now(),
        );
        final success = await categoryStore.addCategory(newCategory);
        if (success) {
          categoryId = newCategory.id;
        } else {
          try {
            final retry = categoryStore.categories.firstWhere(
              (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
            );
            categoryId = retry.id;
          } catch (_) {
            categoryId = '';
          }
        }
      }
    } else {
      final uncategorizedName = "Uncategorized";
      Category? category;
      try {
        category = categoryStore.categories.firstWhere(
          (c) => c.name.toLowerCase() == uncategorizedName.toLowerCase(),
        );
      } catch (_) {
        category = null;
      }

      if (category != null) {
        categoryId = category.id;
      } else {
        final newCategory = Category(
          id: const Uuid().v4(),
          name: uncategorizedName,
          createdTime: DateTime.now(),
        );
        await categoryStore.addCategory(newCategory);
        categoryId = newCategory.id;
      }
    }

    bool hasVariants = rows.length > 1 || _rowHasVariants(parentRow);
    String productId = const Uuid().v4();

    // Tax Rate and HSN Code are read from the parent row only — apply to the
    // product and every variant in this group, same as Category above.
    final taxLabel = parentRow.length > 16 ? parentRow[16].toString().trim() : '';
    final resolvedTax = _resolveTaxFromLabel(taxLabel);
    final hsnCode = parentRow.length > 17 ? parentRow[17].toString().trim() : '';

    ProductModel product = ProductModel(
      productId: productId,
      productName: name,
      description: description.isNotEmpty ? description : null,
      category: categoryId,
      hasVariants: hasVariants,
      brandName: '',
      hsnCode: hsnCode.isNotEmpty ? hsnCode : null,
      gstRate: resolvedTax.gstRate,
      taxId: resolvedTax.taxId,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
      productType: hasVariants ? 'variable' : 'simple',
    );

    await _productRepository.addProduct(product);

    // Collect all unique attributes from all variants
    Set<String> allAttributeNames = {};
    for (var row in rows) {
      if (row[4].toString().isNotEmpty) allAttributeNames.add(row[4].toString().trim());
      if (row[6].toString().isNotEmpty) allAttributeNames.add(row[6].toString().trim());
      if (row[8].toString().isNotEmpty) allAttributeNames.add(row[8].toString().trim());
    }

    // Link attributes to product in global attribute system
    if (allAttributeNames.isNotEmpty) {
      await _linkAttributesToProduct(productId, allAttributeNames, rows);
    }

    for (var row in rows) {
      await _createVariant(productId, row, resolvedTax.taxId, resolvedTax.gstRate);
    }
  }

  /// Resolves a "Name (Rate%)" dropdown label (from the Tax Rate column) back
  /// to the matching shared Tax entity's id + percentage. Falls back to
  /// parsing just the trailing "(NN%)" as a raw rate if no exact name+rate
  /// match is found (e.g. the owner typed a value not in the dropdown).
  ({String? taxId, double? gstRate}) _resolveTaxFromLabel(String label) {
    if (label.isEmpty || !TaxFeature.enabled) return (taxId: null, gstRate: null);

    for (final tax in taxStore.taxes) {
      final rate = tax.taxperecentage ?? 0;
      if (label == '${tax.taxname} (${rate}%)') {
        return (taxId: tax.id, gstRate: rate);
      }
    }

    final match = RegExp(r'\(([\d.]+)%\)').firstMatch(label);
    final rate = match != null ? double.tryParse(match.group(1)!) : double.tryParse(label);
    return (taxId: null, gstRate: rate);
  }

  bool _rowHasVariants(List<dynamic> row) {
    return row[4].toString().isNotEmpty;
  }

  /// A real product row always has a numeric Selling Price (it's required).
  /// The template's instruction row has hint text there instead — use that
  /// to tell the two apart rather than assuming a fixed header-row count.
  bool _looksLikeRealDataRow(List<dynamic> row) {
    if (row.length <= 11) return false;
    return double.tryParse(row[11].toString().trim()) != null;
  }

  /// Ensure an attribute exists in the global attribute system
  /// Returns the attribute ID (existing or newly created)
  Future<String?> _ensureAttributeExists(String attributeName) async {
    final trimmedName = attributeName.trim();

    try {
      // Check existing attributes from the observable store
      final existingAttr = _attributeStore.attributes.cast<AttributeModel?>().firstWhere(
        (attr) => attr != null && attr.name.toLowerCase() == trimmedName.toLowerCase(),
        orElse: () => null,
      );

      if (existingAttr != null) {
        return existingAttr.attributeId;
      }
    } catch (e) {
    }

    // Create new attribute using AttributeStore (updates both DB and observable list)
    try {
      final success = await _attributeStore.addAttribute(trimmedName);
      if (success) {
        // Find the newly created attribute
        final newAttr = _attributeStore.attributes.cast<AttributeModel?>().firstWhere(
          (attr) => attr != null && attr.name.toLowerCase() == trimmedName.toLowerCase(),
          orElse: () => null,
        );
        if (newAttr != null) {
          return newAttr.attributeId;
        }
      } else {
        // Try to find it again in case it already existed
        final existingAttr = _attributeStore.attributes.cast<AttributeModel?>().firstWhere(
          (attr) => attr != null && attr.name.toLowerCase() == trimmedName.toLowerCase(),
          orElse: () => null,
        );
        return existingAttr?.attributeId;
      }
    } catch (e) {
    }
    return null;
  }

  /// Ensure an attribute value exists in the global attribute system
  /// Returns the value ID (existing or newly created), or null if failed
  Future<String?> _ensureAttributeValueExists(String attributeId, String valueName) async {
    final trimmedValue = valueName.trim();

    try {
      // Get values from AttributeStore's observable list
      final existingValues = _attributeStore.getValuesForAttribute(attributeId);

      // Check if value already exists (case-insensitive)
      for (var value in existingValues) {
        if (value.value.toLowerCase() == trimmedValue.toLowerCase()) {
          return value.valueId;
        }
      }
    } catch (e) {
    }

    // Create new value using AttributeStore (updates both DB and observable list)
    try {
      final success = await _attributeStore.addValue(attributeId, trimmedValue);
      if (success) {
        // Find the newly created value
        final values = _attributeStore.getValuesForAttribute(attributeId);
        for (var value in values) {
          if (value.value.toLowerCase() == trimmedValue.toLowerCase()) {
            return value.valueId;
          }
        }
      } else {
        // Try to find it again
        final values = _attributeStore.getValuesForAttribute(attributeId);
        for (var value in values) {
          if (value.value.toLowerCase() == trimmedValue.toLowerCase()) {
            return value.valueId;
          }
        }
      }
    } catch (e) {
    }
    return null;
  }

  /// Link attributes to product in the global attribute system
  /// Returns true if successful, false if attributes couldn't be synced
  Future<bool> _linkAttributesToProduct(
    String productId,
    Set<String> attributeNames,
    List<List<dynamic>> rows,
  ) async {
    try {
      // Map to store attribute IDs and their value IDs
      Map<String, Set<String>> attributeValueMap = {};

      // Process each row to collect all attribute values
      for (var row in rows) {
        // Process Option1 (columns 4-5)
        if (row[4].toString().isNotEmpty && row[5].toString().isNotEmpty) {
          final attrName = row[4].toString().trim();
          final attrValue = row[5].toString().trim();

          final attrId = await _ensureAttributeExists(attrName);
          if (attrId != null) {
            final valueId = await _ensureAttributeValueExists(attrId, attrValue);
            if (valueId != null) {
              attributeValueMap.putIfAbsent(attrId, () => {});
              attributeValueMap[attrId]!.add(valueId);
            }
          }
        }

        // Process Option2 (columns 6-7)
        if (row[6].toString().isNotEmpty && row[7].toString().isNotEmpty) {
          final attrName = row[6].toString().trim();
          final attrValue = row[7].toString().trim();

          final attrId = await _ensureAttributeExists(attrName);
          if (attrId != null) {
            final valueId = await _ensureAttributeValueExists(attrId, attrValue);
            if (valueId != null) {
              attributeValueMap.putIfAbsent(attrId, () => {});
              attributeValueMap[attrId]!.add(valueId);
            }
          }
        }

        // Process Option3 (columns 8-9)
        if (row[8].toString().isNotEmpty && row[9].toString().isNotEmpty) {
          final attrName = row[8].toString().trim();
          final attrValue = row[9].toString().trim();

          final attrId = await _ensureAttributeExists(attrName);
          if (attrId != null) {
            final valueId = await _ensureAttributeValueExists(attrId, attrValue);
            if (valueId != null) {
              attributeValueMap.putIfAbsent(attrId, () => {});
              attributeValueMap[attrId]!.add(valueId);
            }
          }
        }
      }

      if (attributeValueMap.isEmpty) {
        return false;
      }

      // Create assignment data for AttributeStore
      List<Map<String, dynamic>> attributeAssignments = [];
      for (var entry in attributeValueMap.entries) {
        attributeAssignments.add({
          'attributeId': entry.key,
          'valueIds': entry.value.toList(),
          'usedForVariants': true,
          'isVisible': true,
        });
      }

      // Assign all attributes to the product using AttributeStore
      try {
        final success = await _attributeStore.assignAttributesToProduct(
          productId,
          attributeAssignments,
        );
        if (success) {
          return true;
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Generate URL-friendly slug from name
  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _createVariant(
      String productId, List<dynamic> row, String? taxId, double? gstRate) async {
    double cost = double.tryParse(row[10].toString()) ?? 0.0;
    double price = double.tryParse(row[11].toString()) ?? 0.0;
    double? mrp = double.tryParse(row[12].toString());
    int stock = int.tryParse(row[13].toString()) ?? 0;
    String barcode = row[14].toString().trim();
    int minStock = int.tryParse(row[15].toString()) ?? 5;

    Map<String, String> attributes = {};
    
    if (row[4].toString().isNotEmpty && row[5].toString().isNotEmpty) {
      attributes[row[4].toString()] = row[5].toString();
    }
    if (row[6].toString().isNotEmpty && row[7].toString().isNotEmpty) {
      attributes[row[6].toString()] = row[7].toString();
    }
    if (row[8].toString().isNotEmpty && row[9].toString().isNotEmpty) {
      attributes[row[8].toString()] = row[9].toString();
    }

    if (barcode.isNotEmpty) {
      final existing = await _variantRepository.findByBarcode(barcode);
      if (existing != null) {
        throw Exception("Barcode $barcode already exists");
      }
    }

    VarianteModel variant = VarianteModel(
      varianteId: const Uuid().v4(),
      productId: productId,
      costPrice: cost,
      sellingPrice: price,
      mrp: mrp,
      stockQty: stock,
      minStock: minStock,
      barcode: barcode,
      sku: barcode,
      customAttributes: attributes,
      status: 'active',
      taxId: taxId,
      taxRate: gstRate,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    );

    await _variantRepository.addVariant(variant);
  }
  
  @action
  void clear() {
    parsedRows.clear();
    logMessages.clear();
    errorMessage = null;
    successMessage = null;
    progress = 0.0;
    isProcessing = false;
  }
}