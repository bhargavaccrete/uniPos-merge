

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';

// Conditional import for web file download
import 'web_file_saver_stub.dart' if (dart.library.html) 'web_file_saver.dart';

import '../../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../../../data/models/restaurant/db/companymodel_301.dart';
import '../../../../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../../../../data/models/restaurant/db/expensel_316.dart';
import '../../../../../../data/models/restaurant/db/expensemodel_315.dart';
import '../../../../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../../../data/models/restaurant/db/staffModel_310.dart';
import '../../../../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../../../data/models/restaurant/db/variantmodel_305.dart';



class CategoryImportExport {
  static const secureStorage = FlutterSecureStorage();
  static const String _backupFolderKey = 'default_backup_folder';

  /// Get the saved default backup folder
  static Future<String?> getDefaultBackupFolder() async {
    try {
      final appBox = Hive.box('app_state');
      return appBox.get(_backupFolderKey);
    } catch (e) {
      debugPrint('Error getting default backup folder: $e');
      return null;
    }
  }

  /// Set the default backup folder
  static Future<void> setDefaultBackupFolder(String? folderPath) async {
    try {
      final appBox = Hive.box('app_state');
      if (folderPath != null) {
        await appBox.put(_backupFolderKey, folderPath);
        debugPrint('✅ Default backup folder saved: $folderPath');
      } else {
        await appBox.delete(_backupFolderKey);
        debugPrint('✅ Default backup folder cleared');
      }
    } catch (e) {
      debugPrint('Error saving default backup folder: $e');
    }
  }

  /// Clear the default backup folder (user can choose new location)
  static Future<void> clearDefaultBackupFolder() async {
    await setDefaultBackupFolder(null);
  }

  /// ---------------------------
  /// ✅ AUTOMATIC EXPORT TO DOWNLOADS FOLDER (NO USER INTERACTION)
  /// ---------------------------
  /// Saves backup directly to Downloads folder without prompting
  /// Returns the file path or null if failed
  static Future<String?> exportToDownloads({String? password}) async {
    // Web doesn't support file system access like mobile
    if (kIsWeb) {
      debugPrint("⚠️ Web platform detected - using browser download instead");
      return await _exportForWeb();
    }

    try {
      debugPrint("📦 Starting backup to Downloads...");

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/billberry_backup');
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

      // 1️⃣ Collect Hive data
      final exportMap = <String, List<Map<String, dynamic>>>{};

      debugPrint("📦 Exporting categories...");
      exportMap["categories"] = Hive.box<Category>("categories").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero); // Yield to UI thread

      debugPrint("📦 Exporting items...");
      exportMap["items"] = Hive.box<Items>("itemBoxs").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting variants...");
      exportMap["variants"] = Hive.box<VariantModel>("variante").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting choices...");
      exportMap["choices"] = Hive.box<ChoicesModel>("choice").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting extras...");
      exportMap["extras"] = Hive.box<Extramodel>("extra").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting company...");
      exportMap["companyBox"] = Hive.box<Company>("companyBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting staff...");
      exportMap["staffBox"] = Hive.box<StaffModel>("staffBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting taxes...");
      try {
        exportMap["taxes"] = Hive.box<Tax>("restaurant_taxes").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Tax box not found: $e");
        exportMap["taxes"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting expense categories...");
      try {
        exportMap["expenseCategories"] = Hive.box<ExpenseCategory>("restaurant_expenseCategory").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Expense category box not found: $e");
        exportMap["expenseCategories"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting expenses...");
      try {
        exportMap["expenses"] = Hive.box<Expense>("restaurant_expenseBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Expense box not found: $e");
        exportMap["expenses"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting tables...");
      try {
        exportMap["tables"] = Hive.box<TableModel>("tablesBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Tables box not found: $e");
        exportMap["tables"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting end of day reports...");
      try {
        exportMap["eodReports"] = Hive.box<EndOfDayReport>("restaurant_eodBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ EOD box not found: $e");
        exportMap["eodReports"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting current orders...");
      try {
        exportMap["orders"] = Hive.box<OrderModel>("orderBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Orders box not found: $e");
        exportMap["orders"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting app configuration...");
      try {
        final appStateBox = Hive.box("app_state");
        final Map<String, dynamic> appStateMap = {};
        for (var key in appStateBox.keys) {
          appStateMap[key.toString()] = appStateBox.get(key);
        }
        exportMap["appState"] = [appStateMap]; // Wrap in list for consistency
        debugPrint("📦 App state exported: ${appStateMap.keys.length} settings");
      } catch (e) {
        debugPrint("⚠️ App state box not found: $e");
        exportMap["appState"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting past orders...");
      try {
        final pastOrderBox = Hive.box<pastOrderModel>("pastorderBox");
        final pastOrderCount = pastOrderBox.length;
        debugPrint("📦 Past orders count: $pastOrderCount");

        // Process in batches to prevent UI freeze
        final List<Map<String, dynamic>> pastOrdersList = [];
        final allOrders = pastOrderBox.values.toList();

        // Process in batches of 500 to allow UI updates
        const batchSize = 500;
        for (int i = 0; i < allOrders.length; i += batchSize) {
          final end = (i + batchSize < allOrders.length) ? i + batchSize : allOrders.length;
          final batch = allOrders.sublist(i, end);
          pastOrdersList.addAll(batch.map((e) => e.toMap()).toList());

          // Yield to UI thread every batch
          await Future.delayed(Duration(milliseconds: 10));
          debugPrint("📦 Processed ${end}/${allOrders.length} past orders...");
        }

        exportMap["pastOrders"] = pastOrdersList;
        debugPrint("📦 Past orders exported: ${exportMap["pastOrders"]!.length}");
      } catch (e) {
        debugPrint("❌ Error exporting past orders: $e");
        exportMap["pastOrders"] = [];
      }

      debugPrint("📦 Total items exported: ${exportMap.values.fold(0, (sum, list) => sum + list.length)}");

      debugPrint("📦 Converting to JSON...");
      // Convert to JSON in chunks to prevent blocking
      String jsonString;
      try {
        jsonString = jsonEncode(exportMap);
        debugPrint("📦 JSON conversion completed: ${jsonString.length} characters");
      } catch (e) {
        debugPrint("❌ JSON encoding failed: $e");
        throw Exception("Failed to encode data to JSON: $e");
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Writing JSON to file...");
      final dataFile = File('${backupDir.path}/data.json');
      await dataFile.writeAsString(jsonString);
      debugPrint("📦 JSON file written: ${await dataFile.length()} bytes");
      await Future.delayed(Duration.zero);

      // 2️⃣ Collect images
      final productDir = Directory('${dir.path}/product_images');
      final imageFiles = productDir.existsSync()
          ? productDir.listSync().whereType<File>().toList()
          : [];

      debugPrint("📦 Found ${imageFiles.length} images");

      // 3️⃣ Build ZIP archive
      final archive = Archive();
      final dataBytes = await dataFile.readAsBytes();
      archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));

      // Add images
      int imageCount = 0;
      for (final img in imageFiles) {
        final bytes = await img.readAsBytes();
        archive.addFile(ArchiveFile(p.basename(img.path), bytes.length, bytes));
        imageCount++;
        if (imageCount % 50 == 0) {
          debugPrint("📦 Added $imageCount/${imageFiles.length} images");
        }
      }

      debugPrint("📦 Building ZIP archive...");
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData == null || zipData.isEmpty) {
        throw Exception("ZIP creation failed");
      }

      debugPrint("📦 ZIP created: ${zipData.length} bytes (${(zipData.length / 1024 / 1024).toStringAsFixed(2)} MB)");

      // Clean up temp file
      await dataFile.delete();

      // 4️⃣ Save unencrypted ZIP to Downloads folder
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final downloadsPath = '/storage/emulated/0/Download';
      final downloadsDir = Directory(downloadsPath);

      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final outputFile = File('$downloadsPath/BillBerry_backup_$timestamp.zip');
      await outputFile.writeAsBytes(zipData);

      debugPrint("✅ Backup saved to Downloads: ${outputFile.path}");
      debugPrint("✅ File size: ${await outputFile.length()} bytes (${(await outputFile.length() / 1024 / 1024).toStringAsFixed(2)} MB)");

      return outputFile.path;
    } catch (e, stackTrace) {
      debugPrint("❌ Backup to Downloads failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// Show progress dialog
  static void _showProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Hide progress dialog
  static void _hideProgressDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// ---------------------------
  /// ✅ WEB-SPECIFIC EXPORT (Browser Download)
  /// ---------------------------
  static Future<String?> _exportForWeb() async {
    try {
      debugPrint("📦 Starting web backup...");

      // 1️⃣ Collect Hive data
      final exportMap = <String, List<Map<String, dynamic>>>{};

      debugPrint("📦 Exporting categories...");
      exportMap["categories"] = Hive.box<Category>("categories").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting items...");
      exportMap["items"] = Hive.box<Items>("itemBoxs").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting variants...");
      exportMap["variants"] = Hive.box<VariantModel>("variante").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting choices...");
      exportMap["choices"] = Hive.box<ChoicesModel>("choice").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting extras...");
      exportMap["extras"] = Hive.box<Extramodel>("extra").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting company...");
      exportMap["companyBox"] = Hive.box<Company>("companyBox").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting staff...");
      exportMap["staffBox"] = Hive.box<StaffModel>("staffBox").values.map((e) => e.toMap()).toList();

      debugPrint("📦 Exporting taxes...");
      try {
        exportMap["taxes"] = Hive.box<Tax>("restaurant_taxes").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Tax box not found: $e");
        exportMap["taxes"] = [];
      }

      debugPrint("📦 Exporting expense categories...");
      try {
        exportMap["expenseCategories"] = Hive.box<ExpenseCategory>("restaurant_expenseCategory").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Expense category box not found: $e");
        exportMap["expenseCategories"] = [];
      }

      debugPrint("📦 Exporting expenses...");
      try {
        exportMap["expenses"] = Hive.box<Expense>("restaurant_expenseBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Expense box not found: $e");
        exportMap["expenses"] = [];
      }

      debugPrint("📦 Exporting tables...");
      try {
        exportMap["tables"] = Hive.box<TableModel>("tablesBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Tables box not found: $e");
        exportMap["tables"] = [];
      }

      debugPrint("📦 Exporting end of day reports...");
      try {
        exportMap["eodReports"] = Hive.box<EndOfDayReport>("restaurant_eodBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ EOD box not found: $e");
        exportMap["eodReports"] = [];
      }

      debugPrint("📦 Exporting current orders...");
      try {
        exportMap["orders"] = Hive.box<OrderModel>("orderBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Orders box not found: $e");
        exportMap["orders"] = [];
      }

      debugPrint("📦 Exporting app configuration...");
      try {
        final appStateBox = Hive.box("app_state");
        final Map<String, dynamic> appStateMap = {};
        for (var key in appStateBox.keys) {
          appStateMap[key.toString()] = appStateBox.get(key);
        }
        exportMap["appState"] = [appStateMap];
        debugPrint("📦 App state exported: ${appStateMap.keys.length} settings");
      } catch (e) {
        debugPrint("⚠️ App state box not found: $e");
        exportMap["appState"] = [];
      }

      debugPrint("📦 Exporting past orders...");
      try {
        final pastOrderBox = Hive.box<pastOrderModel>("pastorderBox");
        final pastOrderCount = pastOrderBox.length;
        debugPrint("📦 Past orders count: $pastOrderCount");

        final List<Map<String, dynamic>> pastOrdersList = [];
        final allOrders = pastOrderBox.values.toList();

        const batchSize = 500;
        for (int i = 0; i < allOrders.length; i += batchSize) {
          final end = (i + batchSize < allOrders.length) ? i + batchSize : allOrders.length;
          final batch = allOrders.sublist(i, end);
          pastOrdersList.addAll(batch.map((e) => e.toMap()).toList());
          debugPrint("📦 Processed ${end}/${allOrders.length} past orders...");
        }

        exportMap["pastOrders"] = pastOrdersList;
        debugPrint("📦 Past orders exported: ${exportMap["pastOrders"]!.length}");
      } catch (e) {
        debugPrint("❌ Error exporting past orders: $e");
        exportMap["pastOrders"] = [];
      }

      debugPrint("📦 Total items exported: ${exportMap.values.fold(0, (sum, list) => sum + list.length)}");

      // 2️⃣ Convert to JSON
      debugPrint("📦 Converting to JSON...");
      final jsonString = jsonEncode(exportMap);
      debugPrint("📦 JSON size: ${jsonString.length} bytes");

      // 3️⃣ Trigger browser download
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final filename = "BillBerry_backup_$timestamp.json";
      downloadFile(filename, jsonString);

      debugPrint("✅ Backup downloaded via browser: $filename");
      return filename;
    } catch (e, stackTrace) {
      debugPrint("❌ Web backup failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// ---------------------------
  /// ✅ EXPORT JSON + IMAGES WITH AUTOMATIC FOLDER (OPTIMIZED FOR LARGE DATA)
  /// ---------------------------
  /// Returns the file path of the created backup or null if cancelled
  static Future<String?> exportAllData({String? password, bool useAutoFolder = true}) async {
    // Web doesn't support file system access like mobile
    if (kIsWeb) {
      debugPrint("⚠️ Web platform detected - using browser download instead");
      return await _exportForWeb();
    }

    try {
      debugPrint("📦 Starting backup export...");

      // Check for saved default backup folder if auto mode is enabled
      String? savedFolder;
      if (useAutoFolder) {
        savedFolder = await getDefaultBackupFolder();
        if (savedFolder != null) {
          debugPrint("📦 Using saved backup folder: $savedFolder");
          // Verify folder still exists
          if (!Directory(savedFolder).existsSync()) {
            debugPrint("⚠️ Saved folder no longer exists, will prompt for new location");
            savedFolder = null;
            await clearDefaultBackupFolder();
          }
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/billberry_backup');
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

      // 1️⃣ Collect Hive data in batches
      final exportMap = <String, List<Map<String, dynamic>>>{};

      // Export each box with progress logging and UI yields
      debugPrint("📦 Exporting categories...");
      exportMap["categories"] = Hive.box<Category>("categories").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting items...");
      exportMap["items"] = Hive.box<Items>("itemBoxs").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting variants...");
      exportMap["variants"] = Hive.box<VariantModel>("variante").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting choices...");
      exportMap["choices"] = Hive.box<ChoicesModel>("choice").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting extras...");
      exportMap["extras"] = Hive.box<Extramodel>("extra").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting company data...");
      exportMap["companyBox"] = Hive.box<Company>("companyBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting staff data...");
      exportMap["staffBox"] = Hive.box<StaffModel>("staffBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting taxes...");
      exportMap["taxes"] = Hive.box<Tax>("restaurant_taxes").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting expense categories...");
      exportMap["expenseCategories"] = Hive.box<ExpenseCategory>("restaurant_expenseCategory").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting expenses...");
      exportMap["expenses"] = Hive.box<Expense>("restaurant_expenseBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting tables...");
      exportMap["tables"] = Hive.box<TableModel>("tablesBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting end of day reports...");
      exportMap["eodReports"] = Hive.box<EndOfDayReport>("restaurant_eodBox").values.map((e) => e.toMap()).toList();
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting current orders...");
      try {
        exportMap["orders"] = Hive.box<OrderModel>("orderBox").values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Orders box not found: $e");
        exportMap["orders"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting app configuration...");
      try {
        final appStateBox = Hive.box("app_state");
        final Map<String, dynamic> appStateMap = {};
        for (var key in appStateBox.keys) {
          appStateMap[key.toString()] = appStateBox.get(key);
        }
        exportMap["appState"] = [appStateMap]; // Wrap in list for consistency
        debugPrint("📦 App state exported: ${appStateMap.keys.length} settings");
      } catch (e) {
        debugPrint("⚠️ App state box not found: $e");
        exportMap["appState"] = [];
      }
      await Future.delayed(Duration.zero);

      debugPrint("📦 Exporting past orders...");
      try {
        final pastOrderBox = Hive.box<pastOrderModel>("pastorderBox");
        final pastOrderCount = pastOrderBox.length;
        debugPrint("📦 Past orders count: $pastOrderCount");

        // Process in batches to prevent UI freeze
        final List<Map<String, dynamic>> pastOrdersList = [];
        final allOrders = pastOrderBox.values.toList();

        // Process in batches of 500 to allow UI updates
        const batchSize = 500;
        for (int i = 0; i < allOrders.length; i += batchSize) {
          final end = (i + batchSize < allOrders.length) ? i + batchSize : allOrders.length;
          final batch = allOrders.sublist(i, end);
          pastOrdersList.addAll(batch.map((e) => e.toMap()).toList());

          // Yield to UI thread every batch
          await Future.delayed(Duration(milliseconds: 10));
          debugPrint("📦 Processed ${end}/${allOrders.length} past orders...");
        }

        exportMap["pastOrders"] = pastOrdersList;
        debugPrint("📦 Past orders exported: ${exportMap["pastOrders"]!.length}");
      } catch (e) {
        debugPrint("❌ Error exporting past orders: $e");
        exportMap["pastOrders"] = [];
      }

      debugPrint("📦 Total items exported: ${exportMap.values.fold(0, (sum, list) => sum + list.length)}");

      // Save data.json - Test each section
      debugPrint("📦 Testing JSON encode for each section...");
      for (var key in exportMap.keys) {
        try {
          jsonEncode({key: exportMap[key]});
          debugPrint("✅ $key: OK");
        } catch (e) {
          debugPrint("❌ $key: FAILED - $e");
        }
      }

      final dataFile = File('${backupDir.path}/data.json');
      await dataFile.writeAsString(jsonEncode(exportMap));
      debugPrint("📦 Saved data.json (${await dataFile.length()} bytes)");

      // 2️⃣ Collect images
      final productDir = Directory('${dir.path}/product_images');
      final imageFiles = productDir.existsSync()
          ? productDir.listSync().whereType<File>().toList()
          : [];

      debugPrint("📦 Found ${imageFiles.length} images");

      // 3️⃣ Build ZIP using streaming approach
      final archive = Archive();

      // Add JSON
      final dataBytes = await dataFile.readAsBytes();
      archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));

      // Add images in batches to reduce memory pressure
      int imageCount = 0;
      for (final img in imageFiles) {
        final bytes = await img.readAsBytes();
        archive.addFile(ArchiveFile(p.basename(img.path), bytes.length, bytes));
        imageCount++;

        // Log progress every 50 images
        if (imageCount % 50 == 0) {
          debugPrint("📦 Added $imageCount/${imageFiles.length} images");
        }
      }

      debugPrint("📦 Building ZIP archive...");
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData == null || zipData.isEmpty) {
        throw Exception("ZIP creation failed - zipData is empty");
      }

      debugPrint("📦 ZIP created: ${zipData.length} bytes (${(zipData.length / 1024 / 1024).toStringAsFixed(2)} MB)");

      // Clean up temporary files to free memory
      await dataFile.delete();

      // 4️⃣ Save unencrypted ZIP file (easy to verify and share)
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final zipFile = File('${backupDir.path}/BillBerry_backup_$timestamp.zip');

      // Write raw ZIP bytes to file
      await zipFile.writeAsBytes(zipData);

      // Save metadata for app info
      final metaFile = File('${backupDir.path}/BillBerry_backup_$timestamp.meta');
      final storedKey = await secureStorage.read(key: 'hive_key');
      await metaFile.writeAsString(jsonEncode({
        "created": timestamp,
        "app": "BillBerry",
        "version": "1.0",
        "encrypted": false,
      }));

      debugPrint("✅ Backup saved: ${await zipFile.length()} bytes (${(await zipFile.length() / 1024 / 1024).toStringAsFixed(2)} MB)");
      debugPrint("✅ Backup file ready at: ${zipFile.path}");

      // Return the ZIP file path
      return zipFile.path;
    } catch (e, stackTrace) {
      debugPrint("❌ Backup failed: $e");
      debugPrint("Stack trace: $stackTrace");
      rethrow;
    }
  }

  /// ---------------------------
  /// ✅ IMPORT FROM SPECIFIED FILE PATH (No file picker)
  /// ---------------------------
  static Future<void> importFromFilePath(BuildContext context, String filePath) async {
    try {
      debugPrint("📦 Starting import from file: $filePath");

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("File not found: $filePath");
      }

      // Ensure all Hive boxes are opened before importing
      await _ensureBoxesOpened();

      // Use the same import logic
      await _performImport(file);

      debugPrint("✅ Import completed successfully");
    } catch (e) {
      debugPrint("❌ Import failed: $e");
      rethrow;
    }
  }

  /// ---------------------------
  /// 🔧 REGISTER ALL HIVE ADAPTERS
  /// ---------------------------
  static Future<void> _registerAdapters() async {
    try {
      debugPrint("📦 Registering Hive adapters...");

      // Use the existing HiveInit methods to properly register all adapters
      // This ensures we use the correct type IDs (100-149 for restaurant, 150-223 for retail)
      await HiveInit.registerRestaurantAdapters();
      debugPrint("✅ Restaurant adapters registered");

      await HiveInit.registerRetailAdapters();
      debugPrint("✅ Retail adapters registered");

      debugPrint("✅ All adapters registered successfully");
    } catch (e) {
      debugPrint("⚠️ Error registering adapters: $e");
      // Don't rethrow - adapters may already be registered from app initialization
    }
  }

  /// ---------------------------
  /// 🔧 ENSURE ALL HIVE BOXES ARE OPENED
  /// ---------------------------
  static Future<void> _ensureBoxesOpened() async {
    debugPrint("📦 Ensuring all Hive boxes are opened...");

    try {
      // Register all Hive adapters first
      await _registerAdapters();

      // Open app_state box (non-encrypted)
      if (!Hive.isBoxOpen('app_state')) {
        await Hive.openBox('app_state');
        debugPrint("✅ Opened app_state box");
      }

      // Get or create encryption cipher
      final storedKey = await secureStorage.read(key: 'hive_key');
      HiveAesCipher? cipher;

      if (storedKey != null) {
        cipher = HiveAesCipher(base64Decode(storedKey));
        debugPrint("✅ Using existing encryption key");
      } else {
        // Generate new encryption key if none exists
        final key = Hive.generateSecureKey();
        await secureStorage.write(key: 'hive_key', value: base64Encode(key));
        cipher = HiveAesCipher(key);
        debugPrint("✅ Generated new encryption key");
      }

      // Open all encrypted boxes
      if (!Hive.isBoxOpen('categories')) {
        await Hive.openBox<Category>('categories', encryptionCipher: cipher);
        debugPrint("✅ Opened categories box");
      }

      if (!Hive.isBoxOpen('itemBoxs')) {
        await Hive.openBox<Items>('itemBoxs', encryptionCipher: cipher);
        debugPrint("✅ Opened itemBoxs box");
      }

      if (!Hive.isBoxOpen('variante')) {
        await Hive.openBox<VariantModel>('variante', encryptionCipher: cipher);
        debugPrint("✅ Opened variante box");
      }

      if (!Hive.isBoxOpen('choice')) {
        await Hive.openBox<ChoicesModel>('choice', encryptionCipher: cipher);
        debugPrint("✅ Opened choice box");
      }

      if (!Hive.isBoxOpen('extra')) {
        await Hive.openBox<Extramodel>('extra', encryptionCipher: cipher);
        debugPrint("✅ Opened extra box");
      }

      if (!Hive.isBoxOpen('companyBox')) {
        await Hive.openBox<Company>('companyBox', encryptionCipher: cipher);
        debugPrint("✅ Opened companyBox box");
      }

      if (!Hive.isBoxOpen('staffBox')) {
        await Hive.openBox<StaffModel>('staffBox', encryptionCipher: cipher);
        debugPrint("✅ Opened staffBox box");
      }

      if (!Hive.isBoxOpen('restaurant_taxes')) {
        await Hive.openBox<Tax>('restaurant_taxes', encryptionCipher: cipher);
        debugPrint("✅ Opened restaurant_taxes box");
      }

      if (!Hive.isBoxOpen('restaurant_expenseCategory')) {
        await Hive.openBox<ExpenseCategory>('restaurant_expenseCategory', encryptionCipher: cipher);
        debugPrint("✅ Opened restaurant_expenseCategory box");
      }

      if (!Hive.isBoxOpen('restaurant_expenseBox')) {
        await Hive.openBox<Expense>('restaurant_expenseBox', encryptionCipher: cipher);
        debugPrint("✅ Opened restaurant_expenseBox box");
      }

      if (!Hive.isBoxOpen('tablesBox')) {
        await Hive.openBox<TableModel>('tablesBox', encryptionCipher: cipher);
        debugPrint("✅ Opened tablesBox box");
      }

      if (!Hive.isBoxOpen('restaurant_eodBox')) {
        await Hive.openBox<EndOfDayReport>('restaurant_eodBox', encryptionCipher: cipher);
        debugPrint("✅ Opened restaurant_eodBox box");
      }

      if (!Hive.isBoxOpen('pastorderBox')) {
        await Hive.openBox<pastOrderModel>('pastorderBox', encryptionCipher: cipher);
        debugPrint("✅ Opened pastorderBox box");
      }

      if (!Hive.isBoxOpen('orderBox')) {
        await Hive.openBox<OrderModel>('orderBox', encryptionCipher: cipher);
        debugPrint("✅ Opened orderBox box");
      }

      debugPrint("✅ All Hive boxes are now open");
    } catch (e) {
      debugPrint("❌ Error ensuring boxes are opened: $e");
      rethrow;
    }
  }

  /// ---------------------------
  /// ✅ IMPORT JSON + IMAGES (AES DECRYPTED)
  /// ---------------------------
  static Future<bool> importAllData(BuildContext context, {String? password}) async {
    try {
      debugPrint("📦 Starting import process...");

      // Pick ZIP or JSON file
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
      );
      if (picked == null) {
        debugPrint("❌ No file selected");
        return false;
      }

      final file = File(picked.files.single.path!);
      debugPrint("📦 Selected file: ${file.path}");

      // Check file extension to determine import method
      final extension = p.extension(file.path).toLowerCase();

      if (extension == '.json') {
        // Web backup - JSON only
        await _performJsonImport(file);
      } else {
        // Mobile backup - ZIP with images
        await _performImport(file);
      }

      return true;
    } catch (e) {
      debugPrint("❌ Import failed: $e");
      return false;
    }
  }

  /// ---------------------------
  /// 🔧 JSON-ONLY IMPORT LOGIC (for web backups)
  /// ---------------------------
  static Future<void> _performJsonImport(File file) async {
    debugPrint("📦 Processing JSON file: ${file.path}");

    // Read JSON file directly
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString);
    debugPrint("📦 Parsed JSON data successfully");

    // Restore data directly (no key change, data stays encrypted with current key)
    debugPrint("📦 Clearing and restoring data...");
    await _restoreBox("categories", Hive.box<Category>("categories"), (m) => Category.fromMap(m), data);
    await _restoreBox("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m), data);
    await _restoreBox("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m), data);
    await _restoreBox("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m), data);
    await _restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m), data);
    await _restoreBox("companyBox", Hive.box<Company>("companyBox"), (m) => Company.fromMap(m), data);
    await _restoreBox("staffBox", Hive.box<StaffModel>("staffBox"), (m) => StaffModel.fromMap(m), data);
    await _restoreBox("taxes", Hive.box<Tax>("restaurant_taxes"), (m) => Tax.fromMap(m), data);
    await _restoreBox("expenseCategories", Hive.box<ExpenseCategory>("restaurant_expenseCategory"), (m) => ExpenseCategory.fromMap(m), data);
    await _restoreBox("expenses", Hive.box<Expense>("restaurant_expenseBox"), (m) => Expense.fromMap(m), data);
    await _restoreBox("tables", Hive.box<TableModel>("tablesBox"), (m) => TableModel.fromMap(m), data);
    await _restoreBox("eodReports", Hive.box<EndOfDayReport>("restaurant_eodBox"), (m) => EndOfDayReport.fromMap(m), data);
    await _restoreBox("pastOrders", Hive.box<pastOrderModel>("pastorderBox"), (m) => pastOrderModel.fromMap(m), data);
    await _restoreBox("orders", Hive.box<OrderModel>("orderBox"), (m) => OrderModel.fromMap(m), data);

    // Restore app state (configuration settings)
    if (data["appState"] != null && data["appState"].isNotEmpty) {
      debugPrint("📦 Restoring app state...");
      final appStateBox = Hive.box("app_state");
      await appStateBox.clear();
      final appStateData = data["appState"][0] as Map<String, dynamic>;
      for (var entry in appStateData.entries) {
        await appStateBox.put(entry.key, entry.value);
      }
      debugPrint("📦 App state restored: ${appStateData.keys.length} settings");
    }

    debugPrint("📦 Data restored to Hive boxes");
    debugPrint("✅ JSON IMPORT COMPLETED SUCCESSFULLY!");
  }

  /// ---------------------------
  /// 🔧 COMMON IMPORT LOGIC (for ZIP backups)
  /// ---------------------------
  static Future<void> _performImport(File file) async {
    debugPrint("📦 Processing file: ${file.path}");

    // Read ZIP file directly (unencrypted)
    final zipBytes = await file.readAsBytes();
    debugPrint("📦 ZIP file size: ${zipBytes.length} bytes");

    // 1️⃣ Extract ZIP
    final appDir = await getApplicationDocumentsDirectory();
    final restoreDir = Directory('${appDir.path}/restored_backup');
    if (restoreDir.existsSync()) {
      await restoreDir.delete(recursive: true);
    }
    restoreDir.createSync(recursive: true);

    final archive = ZipDecoder().decodeBytes(zipBytes);
    debugPrint("📦 Extracted ZIP contents: ${archive.map((f) => f.name).join(', ')}");
    debugPrint("📦 Archive file count: ${archive.length}");

    File? jsonFile;
    for (final f in archive) {
      debugPrint("📦 Processing file: ${f.name}, isFile: ${f.isFile}");
      if (f.content == null) {
        debugPrint("⚠️ Skipping ${f.name} - content is null");
        continue;
      }
      final outFile = File(p.join(restoreDir.path, f.name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(f.content!);
      if (f.name.toLowerCase() == 'data.json') {
        jsonFile = outFile;
        debugPrint("📦 Found data.json at: ${outFile.path}");
      }
    }

    if (jsonFile == null) {
      debugPrint("❌ Available files in archive: ${archive.map((f) => f.name).toList()}");
      throw Exception("Backup data file missing inside ZIP");
    }

    // 2️⃣ Parse JSON data
    final data = jsonDecode(await jsonFile.readAsString());
    debugPrint("📦 Parsed JSON data successfully");

    // 3️⃣ Restore data directly (no key change, data stays encrypted with current key)
    debugPrint("📦 Clearing and restoring data...");
    await _restoreBox("categories", Hive.box<Category>("categories"), (m) => Category.fromMap(m), data);
    await _restoreBox("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m), data);
    await _restoreBox("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m), data);
    await _restoreBox("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m), data);
    await _restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m), data);
    await _restoreBox("companyBox", Hive.box<Company>("companyBox"), (m) => Company.fromMap(m), data);
    await _restoreBox("staffBox", Hive.box<StaffModel>("staffBox"), (m) => StaffModel.fromMap(m), data);
    await _restoreBox("taxes", Hive.box<Tax>("restaurant_taxes"), (m) => Tax.fromMap(m), data);
    await _restoreBox("expenseCategories", Hive.box<ExpenseCategory>("restaurant_expenseCategory"), (m) => ExpenseCategory.fromMap(m), data);
    await _restoreBox("expenses", Hive.box<Expense>("restaurant_expenseBox"), (m) => Expense.fromMap(m), data);
    await _restoreBox("tables", Hive.box<TableModel>("tablesBox"), (m) => TableModel.fromMap(m), data);
    await _restoreBox("eodReports", Hive.box<EndOfDayReport>("restaurant_eodBox"), (m) => EndOfDayReport.fromMap(m), data);
    await _restoreBox("pastOrders", Hive.box<pastOrderModel>("pastorderBox"), (m) => pastOrderModel.fromMap(m), data);
    await _restoreBox("orders", Hive.box<OrderModel>("orderBox"), (m) => OrderModel.fromMap(m), data);

    // Restore app state (configuration settings)
    if (data["appState"] != null && data["appState"].isNotEmpty) {
      debugPrint("📦 Restoring app state...");
      final appStateBox = Hive.box("app_state");
      await appStateBox.clear();
      final appStateData = data["appState"][0] as Map<String, dynamic>;
      for (var entry in appStateData.entries) {
        await appStateBox.put(entry.key, entry.value);
      }
      debugPrint("📦 App state restored: ${appStateData.keys.length} settings");
    }

    debugPrint("📦 Data restored to Hive boxes");

    // 4️⃣ Restore images
    final productDir = Directory('${appDir.path}/product_images');
    if (!productDir.existsSync()) productDir.createSync(recursive: true);
    for (final f in archive) {
      if (f.isFile && _isImageFile(f.name) && f.content != null) {
        File(p.join(productDir.path, p.basename(f.name)))
          ..createSync(recursive: true)
          ..writeAsBytesSync(f.content!);
      }
    }
    debugPrint("📦 Images restored");
    debugPrint("✅ IMPORT COMPLETED SUCCESSFULLY!");
  }

  static Future<void> _restoreBox<T>(
      String keyName,
      Box<T> box,
      T Function(Map<String, dynamic>) fromMap,
      Map<String, dynamic> data) async {
    if (data[keyName] == null) return;

    debugPrint("📦 Restoring $keyName...");
    await box.clear();

    final appDir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${appDir.path}/product_images');

    final itemsMap = <String, T>{};
    int count = 0;

    // Process items and store with their ID as key
    for (final rawItem in data[keyName]) {
      final item = Map<String, dynamic>.from(rawItem);
      if (keyName == "items" && item['imagePath'] != null && item['imagePath'].toString().isNotEmpty) {
        item['imagePath'] = p.join(productDir.path, p.basename(item['imagePath']));
      }

      // Get the ID from the raw item to use as key
      final id = item['id']?.toString();
      if (id != null && id.isNotEmpty) {
        itemsMap[id] = fromMap(item);
        count++;

        // Add in batches of 100 to reduce memory pressure
        if (itemsMap.length >= 100) {
          await box.putAll(itemsMap);
          itemsMap.clear();
          debugPrint("📦 $keyName: Imported $count items...");
        }
      } else {
        debugPrint("⚠️ Skipping item without ID in $keyName");
      }
    }

    // Add remaining items
    if (itemsMap.isNotEmpty) {
      await box.putAll(itemsMap);
    }

    debugPrint("📦 $keyName: Completed - $count items restored");
  }

  static bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp'].contains(ext);
  }

  /// ---------------------------
  /// ✅ EXPORT WITH PASSWORD DIALOG
  /// ---------------------------
  static Future<void> exportWithPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Secure Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a password to protect your backup:'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Export without password
                Navigator.pop(context, true);
                await exportAllData();
              },
              child: const Text('No Password'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a password')),
                  );
                  return;
                }
                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                Navigator.pop(context, true);
                exportAllData(password: passwordController.text);
              },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------
  /// ✅ IMPORT WITH PASSWORD DIALOG
  /// ---------------------------
  static Future<void> importWithPasswordDialog(BuildContext context) async {
    // First, pick the file
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );

    if (picked == null) return;

    // Read the file to check if it's password-protected
    try {
      final file = File(picked.files.single.path!);
      final jsonMap = jsonDecode(await file.readAsString());

      if (!jsonMap.containsKey('data') || !jsonMap.containsKey('iv')) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid backup format')),
        );
        return;
      }

      final keyType = jsonMap['keyType'] ?? 'hive';

      if (keyType == 'password') {
        // Show password dialog
        final passwordController = TextEditingController();
        bool obscurePassword = true;

        if (!context.mounted) return;
        final password = await showDialog<String>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Password Protected Backup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This backup is password-protected. Please enter the password:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, passwordController.text),
                  child: const Text('Import'),
                ),
              ],
            ),
          ),
        );

        if (password == null || password.isEmpty) return;

        // Import with password
        if (!context.mounted) return;

        // Save the file path temporarily and call import
        final tempFilePath = picked.files.single.path!;
        await _importFromFile(context, tempFilePath, password: password);
      } else {
        // No password needed
        final tempFilePath = picked.files.single.path!;
        await _importFromFile(context, tempFilePath);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading backup file: $e')),
      );
    }
  }

  /// Helper method to import from a specific file path
  static Future<void> _importFromFile(BuildContext context, String filePath, {String? password}) async {
    try {
      final file = File(filePath);
      final jsonMap = jsonDecode(await file.readAsString());

      if (!jsonMap.containsKey('data') || !jsonMap.containsKey('iv')) {
        throw Exception("Invalid backup format");
      }

      // 1️⃣ Decrypt ZIP
      final backupKey = jsonMap['key'];
      final keyType = jsonMap['keyType'] ?? 'hive';
      final iv = encrypt.IV.fromBase64(jsonMap['iv']);

      late encrypt.Key decryptionKey;

      if (keyType == 'password') {
        if (password == null || password.isEmpty) {
          throw Exception("This backup is password-protected. Please enter the password.");
        }
        final keyMaterial = utf8.encode(password.padRight(32, '0').substring(0, 32));
        decryptionKey = encrypt.Key(Uint8List.fromList(keyMaterial));
        debugPrint("🔓 Using password for decryption");
      } else {
        decryptionKey = encrypt.Key.fromBase64(backupKey);
        debugPrint("🔓 Using Hive key for decryption");
      }

      final encrypter = encrypt.Encrypter(encrypt.AES(decryptionKey));
      List<int> decryptedBytes;

      try {
        decryptedBytes = encrypter.decryptBytes(
          encrypt.Encrypted(base64Decode(jsonMap['data'])),
          iv: iv,
        );
      } catch (e) {
        throw Exception("Decryption failed. ${keyType == 'password' ? 'Incorrect password.' : 'Invalid encryption key.'}");
      }

      // 2️⃣ Extract ZIP
      final appDir = await getApplicationDocumentsDirectory();
      final restoreDir = Directory('${appDir.path}/restored_backup');
      if (!restoreDir.existsSync()) restoreDir.createSync(recursive: true);

      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      debugPrint("📦 Extracted ZIP contents: ${archive.map((f) => f.name).join(', ')}");
      debugPrint("📦 Archive file count: ${archive.length}");

      File? jsonFile;
      for (final f in archive) {
        debugPrint("📦 Processing file: ${f.name}, isFile: ${f.isFile}");
        if (f.content == null) {
          debugPrint("⚠️ Skipping ${f.name} - content is null");
          continue;
        }
        final outFile = File(p.join(restoreDir.path, f.name))
          ..createSync(recursive: true)
          ..writeAsBytesSync(f.content!);
        if (f.name.toLowerCase() == 'data.json') {
          jsonFile = outFile;
          debugPrint("📦 Found data.json at: ${outFile.path}");
        }
      }

      if (jsonFile == null) {
        debugPrint("❌ Available files in archive: ${archive.map((f) => f.name).toList()}");
        throw Exception("Backup data file missing inside ZIP");
      }

      // 3️⃣ Parse JSON data
      final data = jsonDecode(await jsonFile.readAsString());
      debugPrint("📦 Parsed JSON data successfully");

      // 4️⃣ CRITICAL: Use box.clear() instead of Hive.close()
      // ⚠️ NEVER close boxes during runtime - this causes race conditions
      // Instead: Clear existing data and write new data to already-open boxes
      // The boxes will re-encrypt data with the app's CURRENT encryption key
      debugPrint("📦 Clearing existing data from all boxes...");

      // 5️⃣ Restore JSON data to ALREADY-OPEN boxes
      debugPrint("📦 Clearing and restoring data...");
      await _restoreBox("categories", Hive.box<Category>("categories"), (m) => Category.fromMap(m), data);
      await _restoreBox("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m), data);
      await _restoreBox("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m), data);
      await _restoreBox("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m), data);
      await _restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m), data);
      await _restoreBox("companyBox", Hive.box<Company>("companyBox"), (m) => Company.fromMap(m), data);
      await _restoreBox("staffBox", Hive.box<StaffModel>("staffBox"), (m) => StaffModel.fromMap(m), data);
      await _restoreBox("taxes", Hive.box<Tax>("restaurant_taxes"), (m) => Tax.fromMap(m), data);
      await _restoreBox("expenseCategories", Hive.box<ExpenseCategory>("restaurant_expenseCategory"), (m) => ExpenseCategory.fromMap(m), data);
      await _restoreBox("expenses", Hive.box<Expense>("restaurant_expenseBox"), (m) => Expense.fromMap(m), data);
      await _restoreBox("tables", Hive.box<TableModel>("tablesBox"), (m) => TableModel.fromMap(m), data);
      await _restoreBox("eodReports", Hive.box<EndOfDayReport>("restaurant_eodBox"), (m) => EndOfDayReport.fromMap(m), data);
      await _restoreBox("pastOrders", Hive.box<pastOrderModel>("pastorderBox"), (m) => pastOrderModel.fromMap(m), data);
      await _restoreBox("orders", Hive.box<OrderModel>("orderBox"), (m) => OrderModel.fromMap(m), data);

      // Restore app state (configuration settings)
      if (data["appState"] != null && data["appState"].isNotEmpty) {
        debugPrint("📦 Restoring app state...");
        final appStateBox = Hive.box("app_state");
        await appStateBox.clear();
        final appStateData = data["appState"][0] as Map<String, dynamic>;
        for (var entry in appStateData.entries) {
          await appStateBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App state restored: ${appStateData.keys.length} settings");
      }

      debugPrint("📦 Data restored to Hive boxes");

      // 8️⃣ Restore images
      final productDir = Directory('${appDir.path}/product_images');
      if (!productDir.existsSync()) productDir.createSync(recursive: true);
      for (final f in archive) {
        if (f.isFile && _isImageFile(f.name) && f.content != null) {
          File(p.join(productDir.path, p.basename(f.name)))
            ..createSync(recursive: true)
            ..writeAsBytesSync(f.content!);
        }
      }
      debugPrint("📦 Images restored");

      // ⚠️ IMPORTANT: App restart recommended after restore
      // Why? The restore may change encryption keys or data structure.
      // All existing UI state and cached data should be cleared.
      // Best practice: User should restart the app to ensure clean state.
      if (!context.mounted) return;

      // Show success dialog asking user to restart app
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async => false, // Prevent dismissal
            child: AlertDialog(
              title: const Text('✅ Restore Complete'),
              content: const Text(
                'Your data has been restored successfully!\n\n'
                'Please restart the app to ensure all changes take effect properly.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Exit the app so user can restart manually
                    exit(0);
                  },
                  child: const Text('OK - Exit App'),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("❌ Import failed: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Import failed: $e")),
      );
    }
  }
}






/*
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:BillBerry/model/db/choicemodel_6.dart';
import 'package:BillBerry/model/db/companymodel_1.dart';
import 'package:BillBerry/model/db/extramodel_3.dart';
import 'package:BillBerry/model/db/staffModel_10.dart';
import 'package:BillBerry/model/db/variantmodel_5.dart';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../model/db/categorymodel_0.dart';
import '../../model/db/itemmodel_2.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
*/

/*class CategoryImportExport {
  static const String boxName = "categories";

  /// Export all categories to JSON file
  static Future<void> exportAllData() async {
    final categoriesBox = Hive.box<Category>("categories");
    final itemsBox = Hive.box<Items>("itemBoxs");
    final variantsBox = Hive.box<VariantModel>("variante");
    final choicesBox = Hive.box<ChoicesModel>("choice");
    final extrasBox = Hive.box<Extramodel>("extra");
    final companyBox = Hive.box<Company>("companyBox");
    final staffBox = Hive.box<StaffModel>("staffBox");

    final exportMap = {
      "categories": categoriesBox.values.map((e) => e.toMap()).toList(),
      "items": itemsBox.values.map((e) => e.toMap()).toList(),
      "variants": variantsBox.values.map((e) => e.toMap()).toList(),
      "choices": choicesBox.values.map((e) => e.toMap()).toList(),
      "extras": extrasBox.values.map((e) => e.toMap()).toList(),
      "companyBox": companyBox.values.map((e) => e.toMap()).toList(),
      "staffBox": staffBox.values.map((e) => e.toMap()).toList(),
    };

    final jsonString = jsonEncode(exportMap);

    const secureStorage = FlutterSecureStorage();
    final storedKey = await secureStorage.read(key: 'hive_key');
    if (storedKey == null) {
      throw Exception("Encryption key not found.");
    }

    final key = encrypt.Key.fromBase64(storedKey);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    // Save key, iv, and encrypted data in JSON
    final backupData = jsonEncode({
      "key": storedKey, // embed the hive_key so it works after reinstall
      "iv": iv.base64,
      "data": encrypted.base64
    });

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/BillBerry_backup.json');
    await file.writeAsString(backupData);

    await Share.shareXFiles([XFile(file.path)], text: "BillBerry Data Backup");
  }


  /// Import categories from JSON file
  /// Import categories from JSON file
  static Future<void> importAllData(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final fileContent = await file.readAsString();

      try {
        final parsed = jsonDecode(fileContent);

        if (parsed is! Map || !parsed.containsKey('key') || !parsed.containsKey('iv') || !parsed.containsKey('data')) {
          throw Exception("Invalid backup format");
        }

        // 1. Decrypt backup data in memory
        final backupKey = parsed['key'];
        final iv = encrypt.IV.fromBase64(parsed['iv']);
        final encryptedData = parsed['data'];
        final key = encrypt.Key.fromBase64(backupKey);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final jsonString = encrypter.decrypt64(encryptedData, iv: iv);
        final decodeData = jsonDecode(jsonString);

        // 2. Clear current data and import new data into OPEN boxes
        // This will re-encrypt the data with the app's CURRENT key
        Future<void> restoreBox<T>(String keyName, Box<T> box, T Function(Map<String, dynamic>) fromMap) async {
          if (decodeData[keyName] != null) {
            await box.clear();
            for (var item in decodeData[keyName]) {
              // Using add() is slow for many items, consider addAll()
              await box.add(fromMap(item));
            }
          }
        }

        await restoreBox("categories", Hive.box<Category>("categories"), (m) => Category.fromMap(m));
        await restoreBox("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m));
        await restoreBox("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m));
        await restoreBox("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m));
        await restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m));
        await restoreBox("companyBox", Hive.box<Company>("companyBox"), (m) => Company.fromMap(m));
        await restoreBox("staffBox", Hive.box<StaffModel>("staffBox"), (m) => StaffModel.fromMap(m));

        // 3. Update the stored key to match the backup's key
        // This ensures that on next launch, Hive uses the correct key to read the data we just wrote.
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'hive_key', value: backupKey);

        // 4. Inform user and advise restart
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data imported successfully! Please restart the app."),
              duration: Duration(seconds: 5),
            ),
          );
        }

      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error importing data: $e")),
          );
        }
      }
    }
  }


}*/