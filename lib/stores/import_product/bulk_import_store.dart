import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/data/repositories/retail/attribute_repository.dart';
import 'package:unipos/data/repositories/retail/category_repository.dart';
import 'package:unipos/data/repositories/retail/product_repository.dart';
import 'package:unipos/data/repositories/retail/variant_repository.dart';
import 'package:uuid/uuid.dart';

part 'bulk_import_store.g.dart';

class BulkImportStore = _BulkImportStore with _$BulkImportStore;

abstract class _BulkImportStore with Store {
  // Repositories
  late final ProductRepository _productRepository;
  late final VariantRepository _variantRepository;
  late final CategoryRepository _categoryRepository;
  late final AttributeRepository _attributeRepository;

  _BulkImportStore() {
    // Lazy initialization to prevent early Hive access
    _productRepository = ProductRepository();
    _variantRepository = VariantRepository();
    _categoryRepository = CategoryRepository();
    _attributeRepository = AttributeRepository();
  }

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
      // 1. Request Storage Permission (Mobile only)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            errorMessage = 'Storage permission required to save template.';
            return null;
          }
        }
      }

      // 2. Define Headers
      List<String> headers = [
        'Handle', // 0. Group ID (Required)
        'Name', // 1. Product Name (Required for Parent)
        'Category', // 2. Category Name
        'Description', // 3. Product Description
        'Option1 Name', // 4. Attribute 1 Name (e.g. Size)
        'Option1 Value', // 5. Attribute 1 Value (e.g. Small)
        'Option2 Name', // 6. Attribute 2 Name (e.g. Color)
        'Option2 Value', // 7. Attribute 2 Value (e.g. Red)
        'Option3 Name', // 8. Attribute 3 Name
        'Option3 Value', // 9. Attribute 3 Value
        'Cost Price', // 10. Cost Price
        'Selling Price', // 11. Selling Price (Required)
        'Stock', // 12. Stock Quantity
        'Barcode', // 13. Barcode/SKU (Unique)
        'Min Stock', // 14. Low Stock Alert Level
      ];

      // 3. Create Excel Object
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      
      // Add Header Row
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      // Add Sample Data
      // Sample 1: Simple Product
      sheetObject.appendRow([
        'coke_can', 'Coca Cola 330ml', 'Drinks', 'Refreshing drink',
        '', '', '', '', '', '',
        '0.50', '1.00', '100', '1234567890', '10'
      ].map((e) => TextCellValue(e)).toList());

      // Sample 2: Variable Product (T-Shirt)
      // Parent Row
      sheetObject.appendRow([
        'tshirt_vneck', 'V-Neck T-Shirt', 'Clothing', 'Cotton T-Shirt',
        'Size', 'S', 'Color', 'Red', '', '',
        '5.00', '15.00', '20', 'TS-RED-S', '5'
      ].map((e) => TextCellValue(e)).toList());
      
      // Child Rows
      sheetObject.appendRow([
        'tshirt_vneck', 'V-Neck T-Shirt', 'Clothing', 'Cotton T-Shirt',
        'Size', 'M', 'Color', 'Red', '', '',
        '5.00', '15.00', '15', 'TS-RED-M', '5'
      ].map((e) => TextCellValue(e)).toList());
      
      sheetObject.appendRow([
        'tshirt_vneck', 'V-Neck T-Shirt', 'Clothing', 'Cotton T-Shirt',
        'Size', 'L', 'Color', 'Blue', '', '',
        '6.00', '16.00', '10', 'TS-BLU-L', '5'
      ].map((e) => TextCellValue(e)).toList());

      // 4. Encode
      var fileBytes = excel.encode();

      // 5. Save File
      if (kIsWeb) {
        // For web, we can't save files easily, so just show a message
        successMessage = 'Template format:\n'
            'Create a CSV or Excel file with these columns:\n'
            'Handle, Name, Category, Description, Option1 Name, Option1 Value, '
            'Option2 Name, Option2 Value, Option3 Name, Option3 Value, '
            'Cost Price, Selling Price, Stock, Barcode, Min Stock\n\n'
            'Example row:\n'
            'product1, Test Product, Electronics, Sample product, , , , , , , 10, 20, 100, BARCODE123, 5';
        return null;
      } else {
        final directory = await getExternalStorageDirectory();
        final path = directory?.path ?? (await getApplicationDocumentsDirectory()).path;
        
        final file = File('$path/product_import_template.xlsx');
        await file.create(recursive: true);
        await file.writeAsBytes(fileBytes!);
        
        successMessage = 'Template saved to: ${file.path}';
        return file.path;
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
          print('CSV file content length: ${fileContent.length} bytes');
          print('CSV first 200 chars: ${fileContent.substring(0, fileContent.length > 200 ? 200 : fileContent.length)}');

          // Normalize line endings - replace \r\n with \n, then split by \n
          fileContent = fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

          // Check if file has proper line breaks
          int lineBreaks = '\n'.allMatches(fileContent).length;
          print('CSV has $lineBreaks line breaks');

          List<List<dynamic>> csvTable = const CsvToListConverter(
            eol: '\n',
            shouldParseNumbers: false, // Keep all as strings to preserve formatting
          ).convert(fileContent);
          print('CSV parsed into ${csvTable.length} rows');

          // Filter out completely empty rows
          for (var row in csvTable) {
            // Skip rows that are completely empty
            if (row.every((cell) => cell.toString().trim().isEmpty)) {
              print('Skipping completely empty row');
              continue;
            }
            parsedRows.add(row);
          }

          print('After filtering: ${parsedRows.length} rows');

        } else if (extension == 'xlsx' || extension == 'xls') {
          // --- Excel Parsing ---
          var excel = Excel.decodeBytes(fileBytes);
          // Assume data is in the first sheet or 'Sheet1'
          if (excel.tables.isNotEmpty) {
            var table = excel.tables[excel.tables.keys.first];

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
        print('Parsed ${parsedRows.length} rows (including header)');
        if (parsedRows.isNotEmpty) {
          print('Header row: ${parsedRows.first}');
          if (parsedRows.length > 1) {
            print('First data row: ${parsedRows[1]}');
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

    try {
      // 1. Group rows by 'Handle' (Column 0)
      final dataRows = parsedRows.skip(1).toList();
      print('importData: Processing ${dataRows.length} data rows (excluding header)');

      Map<String, List<List<dynamic>>> groups = {};

      for (var row in dataRows) {
        if (row.isEmpty) {
          print('importData: Skipping empty row');
          continue;
        }

        // Ensure row has enough columns (pad if needed)
        if (row.length < 15) {
           while (row.length < 15) {
             row.add('');
           }
        }

        String handle = row[0].toString().trim();
        print('importData: Processing row with handle: "$handle"');

        if (handle.isEmpty) {
          print('importData: Skipping row with empty handle');
          continue;
        }

        if (!groups.containsKey(handle)) {
          groups[handle] = [];
        }
        groups[handle]!.add(row);
      }

      print('importData: Grouped into ${groups.length} product groups');

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

      if (errorCount == 0) {
        successMessage = "Import completed! Successfully imported $successCount products.";
      } else {
        successMessage = "Import completed with errors. Success: $successCount, Failed: $errorCount";
      }
    } catch (e) {
      errorMessage = "Import failed: $e";
    } finally {
      isProcessing = false;
    }
  }

  Future<void> _processGroup(String handle, List<List<dynamic>> rows) async {
    var parentRow = rows[0];

    String name = parentRow[1].toString().trim();
    String categoryName = parentRow[2].toString().trim();
    String description = parentRow[3].toString().trim();

    if (name.isEmpty) throw Exception("Product Name is required");

    if (categoryName.isNotEmpty) {
      await _categoryRepository.addCategory(categoryName);
    } else {
      categoryName = "Uncategorized";
    }

    bool hasVariants = rows.length > 1 || _rowHasVariants(parentRow);
    String productId = const Uuid().v4();

    ProductModel product = ProductModel(
      productId: productId,
      productName: name,
      description: description.isNotEmpty ? description : null,
      category: categoryName,
      hasVariants: hasVariants,
      brandName: '',
      gstRate: 0.0,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
      productType: hasVariants ? 'variable' : 'simple',
    );

    // Debug: Print product details
    print('Creating product: ${product.productName} (ID: $productId, Category: $categoryName, HasVariants: $hasVariants)');

    await _productRepository.addProduct(product);
    print('Product saved to repository');

    for (var row in rows) {
      await _createVariant(productId, row);
    }
    print('Created ${rows.length} variant(s) for $name');
  }

  bool _rowHasVariants(List<dynamic> row) {
    return row[4].toString().isNotEmpty;
  }

  Future<void> _createVariant(String productId, List<dynamic> row) async {
    double cost = double.tryParse(row[10].toString()) ?? 0.0;
    double price = double.tryParse(row[11].toString()) ?? 0.0;
    int stock = int.tryParse(row[12].toString()) ?? 0;
    String barcode = row[13].toString().trim();
    int minStock = int.tryParse(row[14].toString()) ?? 5;

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
      stockQty: stock,
      minStock: minStock,
      barcode: barcode,
      sku: barcode,
      customAttributes: attributes, 
      status: 'active',
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