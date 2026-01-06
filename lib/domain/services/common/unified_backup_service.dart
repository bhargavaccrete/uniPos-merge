import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/data/models/common/business_type.dart';
import 'package:unipos/data/models/common/business_details.dart';
import 'package:unipos/models/tax_details.dart';
import 'package:unipos/models/payment_method.dart' as pm;

// Restaurant models
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/companymodel_301.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';
import 'package:unipos/data/models/restaurant/db/table_Model_311.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';

import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/testbillmodel_318.dart';

// Shared models
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';

// Helper classes
import 'package:unipos/data/models/restaurant/db/database/hive_expensecategory.dart';

// Retail models
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/data/models/retail/hive_model/cart_model_202.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_model_207.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_Item_model_206.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:unipos/data/models/retail/hive_model/grn_model_213.dart';
import 'package:unipos/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:unipos/data/models/retail/hive_model/category_model_215.dart';
import 'package:unipos/data/models/retail/hive_model/payment_entry_model_216.dart';
import 'package:unipos/data/models/retail/hive_model/admin_model_217.dart';
import 'package:unipos/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:unipos/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:unipos/data/models/retail/hive_model/staff_model_222.dart';
import 'package:unipos/data/models/retail/hive_model/billing_tab_model_173.dart';

/// Unified Backup Service - Works for both Restaurant and Retail modes
///
/// Features:
/// - Mode-aware data export (automatically detects Restaurant/Retail)
/// - ZIP format with images (if available)
/// - Auto-save to Downloads or custom folder
/// - Import with automatic mode detection
/// - Complete data backup including EOD and Expenses
class UnifiedBackupService {
  static const String _backupDirectoryName = 'UniPOS_Backups';

  /// ---------------------------
  /// 🔧 HELPER: Deep clean map for JSON serialization
  /// ---------------------------
  /// Recursively cleans a map to ensure all values are JSON serializable
  /// Handles nested maps, lists, and converts non-serializable objects
  static dynamic _deepCleanMap(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Map) {
      final cleanedMap = <String, dynamic>{};
      value.forEach((key, val) {
        cleanedMap[key.toString()] = _deepCleanMap(val);
      });
      return cleanedMap;
    } else if (value is List) {
      return value.map((item) => _deepCleanMap(item)).toList();
    } else if (value is String || value is num || value is bool) {
      return value;
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else {
      // For any other type, try to convert to string
      return value.toString();
    }
  }

  /// ---------------------------
  /// ✅ EXPORT TO DOWNLOADS (AUTO-SAVE)
  /// ---------------------------
  /// Automatically saves backup to Downloads folder
  /// Returns the file path or null if failed
  static Future<String?> exportToDownloads() async {
    if (kIsWeb) {
      debugPrint("⚠️ Web platform detected - downloads not supported");
      return null;
    }

    try {
      debugPrint("📦 Starting auto-save backup to Downloads...");

      // Collect all data
      final data = await _collectAllData();

      // Create ZIP backup
      return await _createZipBackup(data, saveToDownloads: true);
    } catch (e, stackTrace) {
      debugPrint("❌ Auto-save backup failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// ---------------------------
  /// ✅ EXPORT TO CUSTOM FOLDER
  /// ---------------------------
  /// Saves backup to user-selected folder
  /// Returns the file path or null if failed
  static Future<String?> exportToCustomFolder(String folderPath) async {
    if (kIsWeb) {
      debugPrint("⚠️ Web platform detected - custom folder not supported");
      return null;
    }

    try {
      debugPrint("📦 Starting backup to custom folder: $folderPath");

      // Collect all data
      final data = await _collectAllData();

      // Create ZIP backup
      return await _createZipBackup(data, customPath: folderPath);
    } catch (e, stackTrace) {
      debugPrint("❌ Custom folder backup failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// ---------------------------
  /// ✅ IMPORT/RESTORE FROM BACKUP
  /// ---------------------------
  /// Imports backup file and automatically detects mode
  /// Returns true if successful
  static Future<bool> importData(BuildContext context) async {
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
      return await importFromFilePath(context, file.path);
    } catch (e, stackTrace) {
      debugPrint("❌ Import failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return false;
    }
  }

  /// ---------------------------
  /// ✅ IMPORT FROM FILE PATH
  /// ---------------------------
  /// Imports backup from a specific file path (for pre-selected files)
  /// Returns true if successful
  static Future<bool> importFromFilePath(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      debugPrint("📦 Importing from file: $filePath");

      if (!await file.exists()) {
        debugPrint("❌ File does not exist: $filePath");
        return false;
      }

      // Check file extension
      final extension = p.extension(file.path).toLowerCase();
      debugPrint("📦 File extension: $extension");

      Map<String, dynamic> data;

      if (extension == '.json') {
        // JSON backup
        debugPrint("📦 Reading JSON file...");
        final jsonString = await file.readAsString();
        data = jsonDecode(jsonString);
      } else {
        // ZIP backup
        debugPrint("📦 Extracting ZIP file...");
        data = await _extractZipBackup(file);
      }

      // Detect mode from backup
      final backupMode = _detectModeFromBackup(data);
      debugPrint("📦 Detected backup mode: $backupMode");

      // Open necessary boxes for the detected mode BEFORE restoring
      await _ensureBoxesOpened(backupMode);

      // Restore data
      await _restoreAllData(data, backupMode);

      debugPrint("✅ Import completed successfully!");
      return true;
    } catch (e, stackTrace) {
      debugPrint("❌ Import from file path failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return false;
    }
  }

  /// ---------------------------
  /// 🔧 ENSURE BOXES ARE OPENED FOR RESTORE
  /// ---------------------------
  /// Ensures all necessary Hive boxes are opened for the detected mode
  /// If boxes aren't open, initializes them using HiveInit
  static Future<void> _ensureBoxesOpened(String mode) async {
    debugPrint("📦 Ensuring boxes are opened for mode: $mode");

    try {
      // ✅ ALWAYS ensure common boxes are opened first (required for both modes)
      final bool commonBoxesOpen = Hive.isBoxOpen(HiveBoxNames.appConfig) &&
          Hive.isBoxOpen(HiveBoxNames.appState) &&
          Hive.isBoxOpen(HiveBoxNames.storeBox) &&
          Hive.isBoxOpen(HiveBoxNames.businessDetailsBox) &&
          Hive.isBoxOpen(HiveBoxNames.businessTypeBox) &&
          Hive.isBoxOpen(HiveBoxNames.taxBox) &&
          Hive.isBoxOpen(HiveBoxNames.paymentMethods);

      if (!commonBoxesOpen) {
        debugPrint("📦 Common boxes not open yet - opening via HiveInit...");
        // Note: Common adapters are already registered during HiveInit.init()
        await HiveInit.openCommonBoxes();
        debugPrint("✅ Common boxes opened successfully");
      } else {
        debugPrint("📦 Common boxes already open");
      }

      // ✅ Open mode-specific boxes
      if (mode == 'retail') {
        // Check if retail boxes are already open
        final bool boxesAlreadyOpen = Hive.isBoxOpen(HiveBoxNames.products) &&
            Hive.isBoxOpen(HiveBoxNames.variants);

        if (!boxesAlreadyOpen) {
          debugPrint("📦 Retail boxes not open yet - initializing via HiveInit...");
          // Register adapters and open boxes for retail mode
          await HiveInit.registerRetailAdapters();
          await HiveInit.openRetailBoxes();
          debugPrint("✅ Retail boxes initialized successfully");
        } else {
          debugPrint("📦 Retail boxes already open");
        }
      } else if (mode == 'restaurant') {
        // Check if restaurant boxes are already open
        final bool boxesAlreadyOpen = Hive.isBoxOpen(HiveBoxNames.restaurantCategories) &&
            Hive.isBoxOpen(HiveBoxNames.restaurantItems);

        if (!boxesAlreadyOpen) {
          debugPrint("📦 Restaurant boxes not open yet - initializing via HiveInit...");
          // Register adapters and open boxes for restaurant mode
          await HiveInit.registerRestaurantAdapters();
          await HiveInit.openRestaurantBoxes();
          debugPrint("✅ Restaurant boxes initialized successfully");
        } else {
          debugPrint("📦 Restaurant boxes already open");
        }
      }

      debugPrint("✅ All necessary boxes (common + $mode) are ready for restore");
    } catch (e, stackTrace) {
      debugPrint("❌ Error ensuring boxes are open: $e");
      debugPrint("Stack trace: $stackTrace");
      throw Exception("Failed to initialize Hive boxes for restore. Error: $e");
    }
  }

  /// ---------------------------
  /// 🔧 COLLECT ALL DATA (MODE-AWARE)
  /// ---------------------------
  static Future<Map<String, dynamic>> _collectAllData() async {
    final exportMap = <String, List<Map<String, dynamic>>>{};

    if (AppConfig.isRestaurant) {
      debugPrint("📦 Collecting RESTAURANT data...");

      // Categories
      exportMap["categories"] = Hive.box<Category>("categories").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Items
      exportMap["items"] = Hive.box<Items>("itemBoxs").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Variants
      exportMap["variants"] = Hive.box<VariantModel>("variante").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Choices
      exportMap["choices"] = Hive.box<ChoicesModel>("choice").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Extras
      exportMap["extras"] = Hive.box<Extramodel>("extra").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Company
      exportMap["companyBox"] = Hive.box<Company>("companyBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Staff
      exportMap["staffBox"] = Hive.box<StaffModel>("staffBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Taxes (using helper - mode aware)
      try {
        exportMap["taxes"] = Hive.box<Tax>("restaurant_taxes").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Tax box not found: $e");
        exportMap["taxes"] = [];
      }

      // Expense Categories (using helper - mode aware)
      try {
        final expenseCatBox = HiveExpenseCat.getECategory();
        exportMap["expenseCategories"] = expenseCatBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Expense category box error: $e");
        exportMap["expenseCategories"] = [];
      }

      // Expenses (using helper - mode aware)
      try {
        final expenseBox = HiveExpenceL.getexpenseBox();
        exportMap["expenses"] = expenseBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Expense box error: $e");
        exportMap["expenses"] = [];
      }

      // Tables
      try {
        exportMap["tables"] = Hive.box<TableModel>("tablesBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Tables box not found: $e");
        exportMap["tables"] = [];
      }

      // EOD Reports (using mode-aware box name)
      try {
        final eodBoxName = AppConfig.isRetail ? 'eodBox' : 'restaurant_eodBox';
        final eodBox = Hive.box<EndOfDayReport>(eodBoxName);
        exportMap["eodReports"] = eodBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ EOD box error: $e");
        exportMap["eodReports"] = [];
      }

      // Current Orders
      try {
        exportMap["orders"] = Hive.box<OrderModel>("orderBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Orders box not found: $e");
        exportMap["orders"] = [];
      }

      // ✅ Restaurant Cart
      try {
        exportMap["restaurantCart"] = Hive.box<CartItem>(HiveBoxNames.restaurantCart).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Restaurant Cart exported: ${exportMap["restaurantCart"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Cart box not found: $e");
        exportMap["restaurantCart"] = [];
      }

      // ✅ App Counters
      try {
        final countersBox = Hive.box(HiveBoxNames.appCounters);
        final Map<String, dynamic> countersMap = {};
        for (var key in countersBox.keys) {
          countersMap[key.toString()] = countersBox.get(key);
        }
        exportMap["appCounters"] = [countersMap];
        debugPrint("📦 App Counters exported: ${countersMap.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ App Counters box error: $e");
        exportMap["appCounters"] = [];
      }

      // ✅ Test Bill Box
      try {
        final box = Hive.box<TestBillModel>(HiveBoxNames.testBillBox);
        exportMap["testBillBox"] = box.values.map((TestBillModel e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Test Bill Box exported: ${exportMap["testBillBox"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Test Bill Box error: $e");
        exportMap["testBillBox"] = [];
      }

      // Past Orders (batched processing with safe serialization)
      try {
        final pastOrderBox = Hive.box<pastOrderModel>("pastorderBox");
        final List<Map<String, dynamic>> pastOrdersList = [];
        final allOrders = pastOrderBox.values.toList();

        const batchSize = 500;
        for (int i = 0; i < allOrders.length; i += batchSize) {
          final end = (i + batchSize < allOrders.length) ? i + batchSize : allOrders.length;
          final batch = allOrders.sublist(i, end);

          // Convert each order with error handling
          for (var order in batch) {
            try {
              final orderMap = order.toMap();
              // Deep clean the map to ensure all values are JSON serializable
              final cleanedMap = _deepCleanMap(orderMap) as Map<String, dynamic>;
              pastOrdersList.add(cleanedMap);
            } catch (e) {
              debugPrint("⚠️ Error converting order ${order.id}: $e");
              // Skip this order and continue
            }
          }
          await Future.delayed(Duration(milliseconds: 10));
        }
        exportMap["pastOrders"] = pastOrdersList;
        debugPrint("📦 Past Orders exported: ${pastOrdersList.length}");
      } catch (e) {
        debugPrint("❌ Error exporting past orders: $e");
        exportMap["pastOrders"] = [];
      }

    } else if (AppConfig.isRetail) {
      debugPrint("📦 Collecting RETAIL data...");

      // Products
      try {
        exportMap["products"] = Hive.box<ProductModel>(HiveBoxNames.products).values.map((e) => e.toProduct()).toList();
      } catch (e) {
        debugPrint("⚠️ Products box error: $e");
        exportMap["products"] = [];
      }

      // Variants
      try {
        exportMap["variants"] = Hive.box<VarianteModel>(HiveBoxNames.variants).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Variants box error: $e");
        exportMap["variants"] = [];
      }

      // Sales
      try {
        exportMap["sales"] = Hive.box<SaleModel>(HiveBoxNames.sales).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Sales box error: $e");
        exportMap["sales"] = [];
      }

      // Sale Items
      try {
        exportMap["saleItems"] = Hive.box<SaleItemModel>(HiveBoxNames.saleItems).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Sale Items box error: $e");
        exportMap["saleItems"] = [];
      }

      // Customers
      try {
        exportMap["customers"] = Hive.box<CustomerModel>(HiveBoxNames.customers).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Customers box error: $e");
        exportMap["customers"] = [];
      }

      // Suppliers
      try {
        exportMap["suppliers"] = Hive.box<SupplierModel>(HiveBoxNames.suppliers).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Suppliers box error: $e");
        exportMap["suppliers"] = [];
      }

      // Purchases
      try {
        exportMap["purchases"] = Hive.box<PurchaseModel>(HiveBoxNames.purchases).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Purchases box error: $e");
        exportMap["purchases"] = [];
      }

      // Purchase Items
      try {
        exportMap["purchaseItems"] = Hive.box<PurchaseItemModel>(HiveBoxNames.purchaseItems).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Purchase Items box error: $e");
        exportMap["purchaseItems"] = [];
      }

      // Categories (String list)
      try {
        final catBox = Hive.box<String>(HiveBoxNames.retailCategories);
        exportMap["categories"] = catBox.values.map((c) => {'name': c}).toList();
      } catch (e) {
        debugPrint("⚠️ Retail Categories box error: $e");
        exportMap["categories"] = [];
      }

      // ✅ Cart Items
      try {
        exportMap["cartItems"] = Hive.box<CartItemModel>(HiveBoxNames.cartItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Cart Items exported: ${exportMap["cartItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Cart Items box error: $e");
        exportMap["cartItems"] = [];
      }

      // ✅ NEW: Add EOD Reports for Retail
      try {
        final eodBoxName = AppConfig.isRetail ? 'eodBox' : 'restaurant_eodBox';
        final eodBox = Hive.box<EndOfDayReport>(eodBoxName);
        exportMap["eodReports"] = eodBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail EOD Reports exported: ${exportMap["eodReports"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail EOD box error: $e");
        exportMap["eodReports"] = [];
      }

      // ✅ NEW: Add Expense Categories for Retail
      try {
        final expenseCatBox = HiveExpenseCat.getECategory();
        exportMap["expenseCategories"] = expenseCatBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Expense Categories exported: ${exportMap["expenseCategories"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Expense category box error: $e");
        exportMap["expenseCategories"] = [];
      }

      // ✅ NEW: Add Expenses for Retail
      try {
        final expenseBox = HiveExpenceL.getexpenseBox();
        exportMap["expenses"] = expenseBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Expenses exported: ${exportMap["expenses"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Expense box error: $e");
        exportMap["expenses"] = [];
      }

      // ✅ Hold Sales & Hold Sale Items
      try {
        exportMap["holdSales"] = Hive.box<HoldSaleModel>(HiveBoxNames.holdSales).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Hold Sales exported: ${exportMap["holdSales"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Hold Sales box error: $e");
        exportMap["holdSales"] = [];
      }

      try {
        exportMap["holdSaleItems"] = Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Hold Sale Items exported: ${exportMap["holdSaleItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Hold Sale Items box error: $e");
        exportMap["holdSaleItems"] = [];
      }

      // ✅ Purchase Orders & Purchase Order Items
      try {
        exportMap["purchaseOrders"] = Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Purchase Orders exported: ${exportMap["purchaseOrders"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Purchase Orders box error: $e");
        exportMap["purchaseOrders"] = [];
      }

      try {
        exportMap["purchaseOrderItems"] = Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Purchase Order Items exported: ${exportMap["purchaseOrderItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Purchase Order Items box error: $e");
        exportMap["purchaseOrderItems"] = [];
      }

      // ✅ GRNs & GRN Items
      try {
        exportMap["grns"] = Hive.box<GRNModel>(HiveBoxNames.grns).values.map((e) => e.toMap()).toList();
        debugPrint("📦 GRNs exported: ${exportMap["grns"]!.length}");
      } catch (e) {
        debugPrint("⚠️ GRNs box error: $e");
        exportMap["grns"] = [];
      }

      try {
        exportMap["grnItems"] = Hive.box<GRNItemModel>(HiveBoxNames.grnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 GRN Items exported: ${exportMap["grnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ GRN Items box error: $e");
        exportMap["grnItems"] = [];
      }

      // ✅ Category Models (with GST)
      try {
        exportMap["categoryModels"] = Hive.box<CategoryModel>(HiveBoxNames.categoryModels).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Category Models exported: ${exportMap["categoryModels"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Category Models box error: $e");
        exportMap["categoryModels"] = [];
      }

      // ✅ Payment Entries
      try {
        exportMap["paymentEntries"] = Hive.box<PaymentEntryModel>(HiveBoxNames.paymentEntries).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Payment Entries exported: ${exportMap["paymentEntries"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Payment Entries box error: $e");
        exportMap["paymentEntries"] = [];
      }

      // ✅ Credit Payments
      try {
        exportMap["creditPayments"] = Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Credit Payments exported: ${exportMap["creditPayments"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Credit Payments box error: $e");
        exportMap["creditPayments"] = [];
      }

      // ✅ Attributes, Attribute Values, Product Attributes
      try {
        exportMap["attributes"] = Hive.box<AttributeModel>(HiveBoxNames.attributes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Attributes exported: ${exportMap["attributes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attributes box error: $e");
        exportMap["attributes"] = [];
      }

      try {
        exportMap["attributeValues"] = Hive.box<AttributeValueModel>(HiveBoxNames.attributeValues).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Attribute Values exported: ${exportMap["attributeValues"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attribute Values box error: $e");
        exportMap["attributeValues"] = [];
      }

      try {
        exportMap["productAttributes"] = Hive.box<ProductAttributeModel>(HiveBoxNames.productAttributes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Product Attributes exported: ${exportMap["productAttributes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Product Attributes box error: $e");
        exportMap["productAttributes"] = [];
      }

      // ✅ Retail Staff
      try {
        exportMap["retailStaff"] = Hive.box<RetailStaffModel>(HiveBoxNames.retailStaff).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Staff exported: ${exportMap["retailStaff"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Staff box error: $e");
        exportMap["retailStaff"] = [];
      }

      // ✅ Billing Tabs
      try {
        exportMap["billingTabs"] = Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Billing Tabs exported: ${exportMap["billingTabs"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Billing Tabs box error: $e");
        exportMap["billingTabs"] = [];
      }

      // ✅ Day Management Box (opening balance)
      try {
        final dayMgmtBox = Hive.box(HiveBoxNames.dayManagementBox);
        final Map<String, dynamic> dayMgmtMap = {};
        for (var key in dayMgmtBox.keys) {
          dayMgmtMap[key.toString()] = dayMgmtBox.get(key);
        }
        exportMap["dayManagement"] = [dayMgmtMap];
        debugPrint("📦 Day Management exported: ${dayMgmtMap.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ Day Management box error: $e");
        exportMap["dayManagement"] = [];
      }

      // ✅ Admin Box
      try {
        exportMap["adminBox"] = Hive.box<AdminModel>(HiveBoxNames.adminBox).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Admin Box exported: ${exportMap["adminBox"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Admin Box error: $e");
        exportMap["adminBox"] = [];
      }
    }

    // ==================== COMMON BOXES (both retail and restaurant) ====================

    // ✅ App Config Box (CRITICAL - stores business mode and setup completion status)
    try {
      final appConfigBox = Hive.box(HiveBoxNames.appConfig);
      final Map<String, dynamic> appConfigMap = {};
      for (var key in appConfigBox.keys) {
        appConfigMap[key.toString()] = appConfigBox.get(key);
      }
      exportMap["appConfig"] = [appConfigMap];
      debugPrint("📦 App config exported: ${appConfigMap.keys.length} entries");
    } catch (e) {
      debugPrint("⚠️ App config box error: $e");
      exportMap["appConfig"] = [];
    }

    // App State
    try {
      final appStateBox = Hive.box("app_state");
      final Map<String, dynamic> appStateMap = {};
      for (var key in appStateBox.keys) {
        appStateMap[key.toString()] = appStateBox.get(key);
      }
      exportMap["appState"] = [appStateMap];
      debugPrint("📦 App state exported: ${appStateMap.keys.length} settings");
    } catch (e) {
      debugPrint("⚠️ App state box error: $e");
      exportMap["appState"] = [];
    }

    // Store Box (legacy store info)
    try {
      final storeBox = Hive.box(HiveBoxNames.storeBox);
      final Map<String, dynamic> storeMap = {};
      for (var key in storeBox.keys) {
        storeMap[key.toString()] = storeBox.get(key);
      }
      exportMap["storeBox"] = [storeMap];
      debugPrint("📦 Store box exported: ${storeMap.keys.length} entries");
    } catch (e) {
      debugPrint("⚠️ Store box error: $e");
      exportMap["storeBox"] = [];
    }

    // Business Details Box
    try {
      final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
      exportMap["businessDetails"] = businessDetailsBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Business details exported: ${exportMap["businessDetails"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Business details box error: $e");
      exportMap["businessDetails"] = [];
    }

    // Business Type Box
    try {
      final businessTypeBox = Hive.box<BusinessType>(HiveBoxNames.businessTypeBox);
      exportMap["businessTypes"] = businessTypeBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Business types exported: ${exportMap["businessTypes"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Business type box error: $e");
      exportMap["businessTypes"] = [];
    }

    // Tax Details Box
    try {
      final taxBox = Hive.box<TaxDetails>(HiveBoxNames.taxBox);
      exportMap["taxDetails"] = taxBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Tax details exported: ${exportMap["taxDetails"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Tax details box error: $e");
      exportMap["taxDetails"] = [];
    }

    // Payment Methods Box (shared)
    try {
      final paymentMethodsBox = Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods);
      exportMap["paymentMethods"] = paymentMethodsBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Payment methods exported: ${exportMap["paymentMethods"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Payment methods box error: $e");
      exportMap["paymentMethods"] = [];
    }

    debugPrint("📦 Total items exported: ${exportMap.values.fold(0, (sum, list) => sum + list.length)}");

    return {
      'version': '2.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'appMode': AppConfig.businessMode.name,
      'data': exportMap,
    };
  }

  /// ---------------------------
  /// 🔧 CREATE ZIP BACKUP
  /// ---------------------------
  static Future<String?> _createZipBackup(
      Map<String, dynamic> data, {
        bool saveToDownloads = false,
        String? customPath,
      }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/temp_backup');
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

      // 1️⃣ Write JSON data
      final jsonString = jsonEncode(data);
      final dataFile = File('${backupDir.path}/data.json');
      await dataFile.writeAsString(jsonString);
      debugPrint("📦 JSON data written: ${await dataFile.length()} bytes");

      // 2️⃣ Collect images (if available)
      final productDir = Directory('${appDir.path}/product_images');
      final imageFiles = productDir.existsSync()
          ? productDir.listSync().whereType<File>().toList()
          : [];

      debugPrint("📦 Found ${imageFiles.length} images");

      // 3️⃣ Build ZIP archive
      final archive = Archive();

      // Add JSON
      final dataBytes = await dataFile.readAsBytes();
      archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));

      // Add images (if any)

      if (imageFiles.isNotEmpty) {
        for (final img in imageFiles) {
          final bytes = await img.readAsBytes();
          archive.addFile(ArchiveFile(p.basename(img.path), bytes.length, bytes));
        }
        debugPrint("📦 Added ${imageFiles.length} images to ZIP");
      }

      // Encode ZIP

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData == null || zipData.isEmpty) {

        throw Exception("ZIP creation failed");
      }

      debugPrint("📦 ZIP created: ${zipData.length} bytes (${(zipData.length / 1024 / 1024).toStringAsFixed(2)} MB)");

      // Clean up temp file
      await dataFile.delete();

      // 4️⃣ Save ZIP to destination
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = 'UniPOS_backup_$timestamp.zip';

      File outputFile;

      if (saveToDownloads) {
        // Save to Downloads
        final downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }
        outputFile = File('$downloadsPath/$fileName');
      } else if (customPath != null) {
        // Save to custom folder
        outputFile = File('$customPath/$fileName');
      } else {
        throw Exception("No save location specified");
      }

      await outputFile.writeAsBytes(zipData);

      debugPrint("✅ Backup saved: ${outputFile.path}");
      debugPrint("✅ File size: ${await outputFile.length()} bytes");

      return outputFile.path;
    } catch (e, stackTrace) {
      debugPrint("❌ ZIP backup creation failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// ---------------------------
  /// 🔧 EXTRACT ZIP BACKUP
  /// ---------------------------
  static Future<Map<String, dynamic>> _extractZipBackup(File file) async {
    final zipBytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    debugPrint("📦 Extracted ZIP: ${archive.length} files");

    // Find data.json
    File? jsonFile;
    final appDir = await getApplicationDocumentsDirectory();
    final restoreDir = Directory('${appDir.path}/restored_backup');

    if (restoreDir.existsSync()) {
      await restoreDir.delete(recursive: true);
    }
    restoreDir.createSync(recursive: true);

    for (final f in archive) {
      if (f.content == null) continue;

      final outFile = File(p.join(restoreDir.path, f.name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(f.content!);

      if (f.name.toLowerCase() == 'data.json') {
        jsonFile = outFile;
      }
    }

    if (jsonFile == null) {
      throw Exception("Backup data file missing in ZIP");
    }

    // Parse JSON
    final jsonString = await jsonFile.readAsString();
    return jsonDecode(jsonString);
  }

  /// ---------------------------
  /// 🔧 DETECT MODE FROM BACKUP
  /// ---------------------------
  static String _detectModeFromBackup(Map<String, dynamic> data) {
    debugPrint("📦 Backup file structure: ${data.keys.toList()}");

    // Check if backup has mode specified
    if (data.containsKey('appMode')) {
      debugPrint("📦 Found appMode: ${data['appMode']}");
      return data['appMode'];
    }

    // Auto-detect from data structure
    final backupData = data['data'] as Map<String, dynamic>?;
    if (backupData == null) {
      debugPrint("⚠️ No 'data' key found in backup. Available keys: ${data.keys.toList()}");
      return 'unknown';
    }

    debugPrint("📦 Backup data keys: ${backupData.keys.toList()}");

    // Restaurant has: items, tables, pastOrders
    // Retail has: products, sales, suppliers
    if (backupData.containsKey('products') && backupData.containsKey('suppliers')) {
      debugPrint("📦 Detected retail backup (has products & suppliers)");
      return 'retail';
    } else if (backupData.containsKey('itemBoxs') || backupData.containsKey('items') || backupData.containsKey('tables')) {
      debugPrint("📦 Detected restaurant backup (has items/tables)");
      return 'restaurant';
    }

    debugPrint("⚠️ Could not determine backup type from data structure");
    return 'unknown';
  }

  /// ---------------------------
  /// 🔧 RESTORE ALL DATA
  /// ---------------------------
  static Future<void> _restoreAllData(Map<String, dynamic> data, String backupMode) async {
    debugPrint("📦 Restoring data for mode: $backupMode");

    // Validate backup data structure
    if (!data.containsKey('data') || data['data'] == null) {
      debugPrint("❌ Invalid backup format: Missing 'data' key");
      debugPrint("📦 Backup structure: ${data.keys.toList()}");

      // Check if this is a legacy format (direct data without wrapper)
      if (data.containsKey('products') || data.containsKey('items') || data.containsKey('categories')) {
        debugPrint("📦 Detected legacy backup format (unwrapped data)");
        // Treat the entire data object as the backup data
        await _handleLegacyRestore(data, backupMode);
        return;
      }

      throw Exception("Invalid backup file format. The backup file doesn't contain the expected 'data' key. Available keys: ${data.keys.toList()}");
    }

    final backupData = data['data'] as Map<String, dynamic>;

    // Validate mode is known
    if (backupMode == 'unknown') {
      debugPrint("❌ Cannot restore: Unknown backup mode");
      debugPrint("📦 Backup data keys: ${backupData.keys.toList()}");
      throw Exception("Cannot determine backup type. The backup file format is not recognized. Available data keys: ${backupData.keys.toList()}");
    }

    // Restore based on detected mode
    if (backupMode == 'restaurant') {
      await _restoreRestaurantData(backupData);
    } else if (backupMode == 'retail') {
      await _restoreRetailData(backupData);
    } else {
      throw Exception("Unsupported backup mode: $backupMode");
    }

    // ==================== RESTORE COMMON BOXES (both retail and restaurant) ====================

    // ✅ Restore app config FIRST (CRITICAL - contains business mode and setup status)
    if (backupData["appConfig"] != null && backupData["appConfig"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring app config...");
        final appConfigBox = Hive.box(HiveBoxNames.appConfig);
        await appConfigBox.clear();
        final appConfigData = backupData["appConfig"][0] as Map<String, dynamic>;
        for (var entry in appConfigData.entries) {
          await appConfigBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App config restored: ${appConfigData.keys.length} entries");
        debugPrint("📦 Business mode: ${appConfigBox.get('businessMode')}");
        debugPrint("📦 Setup complete: ${appConfigBox.get('isSetupComplete')}");
      } catch (e) {
        debugPrint("⚠️ Error restoring app config: $e");
      }
    }

    // Restore app state
    if (backupData["appState"] != null && backupData["appState"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring app state...");
        final appStateBox = Hive.box("app_state");
        await appStateBox.clear();
        final appStateData = backupData["appState"][0] as Map<String, dynamic>;
        for (var entry in appStateData.entries) {
          await appStateBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App state restored: ${appStateData.keys.length} settings");
      } catch (e) {
        debugPrint("⚠️ Error restoring app state: $e");
      }
    }

    // Restore store box (legacy store info)
    if (backupData["storeBox"] != null && backupData["storeBox"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring store box...");
        final storeBox = Hive.box(HiveBoxNames.storeBox);
        await storeBox.clear();
        final storeData = backupData["storeBox"][0] as Map<String, dynamic>;
        for (var entry in storeData.entries) {
          await storeBox.put(entry.key, entry.value);
        }
        debugPrint("📦 Store box restored: ${storeData.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ Error restoring store box: $e");
      }
    }

    // Restore business details
    if (backupData["businessDetails"] != null && backupData["businessDetails"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring business details...");
        final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
        await businessDetailsBox.clear();
        for (var item in backupData["businessDetails"]) {
          final map = Map<String, dynamic>.from(item);
          await businessDetailsBox.add(BusinessDetails.fromMap(map));
        }
        debugPrint("📦 Business details restored: ${backupData["businessDetails"].length} items");

        // ✅ CRITICAL: Sync SharedPreferences from BusinessDetails for retail
        // Retail side uses SharedPreferences for store info, not Hive
        // This must happen AFTER BusinessDetails is restored
        if (backupMode == 'retail') {
          await _syncSharedPreferencesFromBusinessDetails();
        }
      } catch (e) {
        debugPrint("⚠️ Error restoring business details: $e");
      }
    }

    // Restore business types
    if (backupData["businessTypes"] != null && backupData["businessTypes"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring business types...");
        final businessTypeBox = Hive.box<BusinessType>(HiveBoxNames.businessTypeBox);
        await businessTypeBox.clear();
        for (var item in backupData["businessTypes"]) {
          final map = Map<String, dynamic>.from(item);
          await businessTypeBox.add(BusinessType.fromMap(map));
        }
        debugPrint("📦 Business types restored: ${backupData["businessTypes"].length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring business types: $e");
      }
    }

    // Restore tax details
    if (backupData["taxDetails"] != null && backupData["taxDetails"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring tax details...");
        final taxBox = Hive.box<TaxDetails>(HiveBoxNames.taxBox);
        await taxBox.clear();
        for (var item in backupData["taxDetails"]) {
          final map = Map<String, dynamic>.from(item);
          await taxBox.add(TaxDetails.fromMap(map));
        }
        debugPrint("📦 Tax details restored: ${backupData["taxDetails"].length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring tax details: $e");
      }
    }

    // Restore payment methods
    if (backupData["paymentMethods"] != null && backupData["paymentMethods"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring payment methods...");
        final paymentMethodsBox = Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods);
        await paymentMethodsBox.clear();
        for (var item in backupData["paymentMethods"]) {
          final map = Map<String, dynamic>.from(item);
          await paymentMethodsBox.add(pm.PaymentMethod.fromMap(map));
        }
        debugPrint("📦 Payment methods restored: ${backupData["paymentMethods"].length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring payment methods: $e");
      }
    }

    // ✅ CRITICAL: Update AppConfig with the correct business mode
    // Note: Only update if appConfig wasn't in the backup (for legacy backups)
    if (backupData["appConfig"] == null || backupData["appConfig"].isEmpty) {
      debugPrint("📦 AppConfig not found in backup - updating from detected mode: $backupMode");
      await _updateAppConfigFromBackup(backupMode);
    } else {
      debugPrint("📦 AppConfig already restored from backup - skipping manual update");
    }

    debugPrint("✅ Data restoration completed!");
  }

  /// ---------------------------
  /// 🔧 UPDATE APP CONFIG FROM BACKUP
  /// ---------------------------
  /// Updates AppConfig box to match the restored backup's business mode
  static Future<void> _updateAppConfigFromBackup(String backupMode) async {
    try {
      // Force update the business mode in AppConfig
      final appConfigBox = Hive.box('appConfigBox');

      debugPrint("📦 Current AppConfig business mode: ${appConfigBox.get('businessMode')}");
      debugPrint("📦 Setting business mode to: $backupMode");

      // Force set the business mode (bypassing the one-time restriction)
      await appConfigBox.put('businessMode', backupMode);

      // Mark setup as complete
      await appConfigBox.put('isSetupComplete', true);

      debugPrint("✅ AppConfig updated successfully");
      debugPrint("📦 New business mode: ${appConfigBox.get('businessMode')}");
      debugPrint("📦 Setup complete: ${appConfigBox.get('isSetupComplete')}");
    } catch (e, stackTrace) {
      debugPrint("❌ Failed to update AppConfig: $e");
      debugPrint("Stack trace: $stackTrace");
      // Don't throw - let the restore continue even if this fails
    }
  }

  /// ---------------------------
  /// 🔧 HANDLE LEGACY BACKUP RESTORE
  /// ---------------------------
  /// Handles restoration of legacy backup formats that don't have the wrapper structure
  static Future<void> _handleLegacyRestore(Map<String, dynamic> data, String backupMode) async {
    debugPrint("📦 Attempting legacy restore...");

    // Re-detect mode if unknown
    String mode = backupMode;
    if (mode == 'unknown') {
      if (data.containsKey('products') && data.containsKey('suppliers')) {
        mode = 'retail';
        debugPrint("📦 Detected retail mode from legacy backup");
      } else if (data.containsKey('items') || data.containsKey('tables')) {
        mode = 'restaurant';
        debugPrint("📦 Detected restaurant mode from legacy backup");
      } else {
        throw Exception("Cannot determine mode from legacy backup. Keys: ${data.keys.toList()}");
      }
    }

    // Ensure boxes are opened
    await _ensureBoxesOpened(mode);

    // Restore based on mode
    if (mode == 'restaurant') {
      await _restoreRestaurantData(data);
    } else if (mode == 'retail') {
      await _restoreRetailData(data);
    }

    // Update AppConfig with the correct business mode
    await _updateAppConfigFromBackup(mode);

    debugPrint("✅ Legacy backup restored successfully!");
  }

  /// ---------------------------
  /// 🔧 RESTORE RESTAURANT DATA
  /// ---------------------------
  static Future<void> _restoreRestaurantData(Map<String, dynamic> data) async {
    debugPrint("📦 Restoring restaurant data...");

    // Helper function to restore a box
    // ⚠️ WARNING: This uses box.add() which generates auto-increment keys
    // Use restoreBoxWithId() for models that need their ID as the key
    Future<void> restoreBox<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        ) async {
      if (data[keyName] == null) return;

      debugPrint("📦 Restoring $keyName...");
      await box.clear();

      final items = data[keyName] as List;
      for (var item in items) {
        final map = Map<String, dynamic>.from(item);
        await box.add(fromMap(map));
      }

      debugPrint("📦 $keyName: ${items.length} items restored");
    }

    // ✅ Helper function to restore boxes WITH ID as key
    // This preserves the original ID from the model as the Hive box key
    // Use this for models that are looked up by their ID
    Future<void> restoreBoxWithId<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        String Function(T) getIdFunc,
        ) async {
      if (data[keyName] == null) return;

      debugPrint("📦 Restoring $keyName (with ID keys)...");
      await box.clear();

      final items = data[keyName] as List;
      for (var item in items) {
        final map = Map<String, dynamic>.from(item);
        final model = fromMap(map);
        final id = getIdFunc(model);
        await box.put(id, model);  // ✅ Use ID as key, not auto-increment
      }

      debugPrint("📦 $keyName: ${items.length} items restored with ID keys");
    }

    await restoreBoxWithId("categories", Hive.box<Category>("categories"), (m) => Category.fromMap(m), (c) => c.id);
    await restoreBoxWithId("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m), (i) => i.id);
    await restoreBoxWithId("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m), (v) => v.id);
    await restoreBoxWithId("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m), (ch) => ch.id);
    await restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m));
    await restoreBox("companyBox", Hive.box<Company>("companyBox"), (m) => Company.fromMap(m));
    await restoreBoxWithId("staffBox", Hive.box<StaffModel>("staffBox"), (m) => StaffModel.fromMap(m), (s) => s.id);
    await restoreBoxWithId("taxes", Hive.box<Tax>("restaurant_taxes"), (m) => Tax.fromMap(m), (t) => t.id);
    await restoreBoxWithId("expenseCategories", HiveExpenseCat.getECategory(), (m) => ExpenseCategory.fromMap(m), (ec) => ec.id);
    await restoreBoxWithId("expenses", HiveExpenceL.getexpenseBox(), (m) => Expense.fromMap(m), (e) => e.id);
    await restoreBoxWithId("tables", Hive.box<TableModel>("tablesBox"), (m) => TableModel.fromMap(m), (tb) => tb.id);

    // ✅ EOD Reports - hardcoded for restaurant mode (AppConfig not restored yet)
    await restoreBox("eodReports", Hive.box<EndOfDayReport>('restaurant_eodBox'), (m) => EndOfDayReport.fromMap(m));

    await restoreBoxWithId("pastOrders", Hive.box<pastOrderModel>("pastorderBox"), (m) => pastOrderModel.fromMap(m), (po) => po.id);
    await restoreBoxWithId("orders", Hive.box<OrderModel>("orderBox"), (m) => OrderModel.fromMap(m), (o) => o.id);

    // ✅ Restore Restaurant Cart
    try {
      await restoreBox("restaurantCart", Hive.box<CartItem>(HiveBoxNames.restaurantCart), (m) => CartItem.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant cart: $e");
    }

    // ✅ Restore App Counters
    try {
      if (data["appCounters"] != null && data["appCounters"].isNotEmpty) {
        debugPrint("📦 Restoring app counters...");
        final countersBox = Hive.box(HiveBoxNames.appCounters);
        await countersBox.clear();
        final countersData = data["appCounters"][0] as Map<String, dynamic>;
        for (var entry in countersData.entries) {
          await countersBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App counters restored: ${countersData.keys.length} entries");
      }
    } catch (e) {
      debugPrint("⚠️ Error restoring app counters: $e");
    }

    // ✅ Restore Test Bill Box
    try {
      await restoreBox("testBillBox", Hive.box<TestBillModel>(HiveBoxNames.testBillBox), (m) => TestBillModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring test bill box: $e");
    }
  }

  /// ---------------------------
  /// 🔧 RESTORE RETAIL DATA
  /// ---------------------------
  static Future<void> _restoreRetailData(Map<String, dynamic> data) async {
    debugPrint("📦 Restoring retail data...");

    // Helper function to restore typed boxes (converts Maps to model objects)
    // ⚠️ WARNING: This uses box.add() which generates auto-increment keys
    // Use restoreBoxTypedWithId() for models that need their ID as the key
    Future<void> restoreBoxTyped<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        ) async {
      if (data[keyName] == null) return;

      debugPrint("📦 Restoring $keyName...");
      await box.clear();

      final items = data[keyName] as List;
      for (var item in items) {
        final map = Map<String, dynamic>.from(item);
        await box.add(fromMap(map));
      }

      debugPrint("📦 $keyName: ${items.length} items restored");
    }

    // ✅ Helper function to restore typed boxes WITH ID as key
    // This preserves the original ID from the model as the Hive box key
    // Use this for models that are looked up by their ID (sales, customers, etc.)
    Future<void> restoreBoxTypedWithId<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        String Function(T) getIdFunc,
        ) async {
      if (data[keyName] == null) return;

      debugPrint("📦 Restoring $keyName (with ID keys)...");
      await box.clear();

      final items = data[keyName] as List;
      for (var item in items) {
        final map = Map<String, dynamic>.from(item);
        final model = fromMap(map);
        final id = getIdFunc(model);
        await box.put(id, model);  // ✅ Use ID as key, not auto-increment
      }

      debugPrint("📦 $keyName: ${items.length} items restored with ID keys");
    }

    // ✅ Restore Products (as ProductModel objects with ID keys)
    await restoreBoxTypedWithId(
      "products",
      Hive.box<ProductModel>(HiveBoxNames.products),
          (m) => ProductModel.fromMap(m),
          (p) => p.productId,  // Use productId as key
    );

    // ✅ Restore Variants (as VarianteModel objects with ID keys)
    await restoreBoxTypedWithId(
      "variants",
      Hive.box<VarianteModel>(HiveBoxNames.variants),
          (m) => VarianteModel.fromMap(m),
          (v) => v.varianteId,  // Use varianteId as key
    );

    // ✅ Restore Cart Items
    await restoreBoxTyped(
      "cartItems",
      Hive.box<CartItemModel>(HiveBoxNames.cartItems),
          (m) => CartItemModel.fromMap(m),
    );

    // ✅ Restore Retail Categories
    if (data["categories"] != null) {
      try {
        debugPrint("📦 Restoring retail categories...");
        final catBox = Hive.box<String>(HiveBoxNames.retailCategories);
        await catBox.clear();
        final items = data["categories"] as List;
        for (var item in items) {
          if (item is Map && item.containsKey('name')) {
            await catBox.add(item['name'] as String);
          }
        }
        debugPrint("📦 Retail categories restored: ${items.length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring retail categories: $e");
      }
    }

    // ✅ Restore Sales (as SaleModel objects with ID keys) - CRITICAL FIX
    await restoreBoxTypedWithId(
      "sales",
      Hive.box<SaleModel>(HiveBoxNames.sales),
          (m) => SaleModel.fromMap(m),
          (s) => s.saleId,  // Use saleId as key for proper lookup
    );

    // ✅ Restore Sale Items (as SaleItemModel objects with ID keys) - CRITICAL FIX
    await restoreBoxTypedWithId(
      "saleItems",
      Hive.box<SaleItemModel>(HiveBoxNames.saleItems),
          (m) => SaleItemModel.fromMap(m),
          (si) => si.saleItemId,  // Use saleItemId as key
    );

    // ✅ Restore Customers (as CustomerModel objects with ID keys)
    await restoreBoxTypedWithId(
      "customers",
      Hive.box<CustomerModel>(HiveBoxNames.customers),
          (m) => CustomerModel.fromMap(m),
          (c) => c.customerId,  // Use customerId as key
    );

    // ✅ Restore Suppliers (as SupplierModel objects with ID keys)
    await restoreBoxTypedWithId(
      "suppliers",
      Hive.box<SupplierModel>(HiveBoxNames.suppliers),
          (m) => SupplierModel.fromMap(m),
          (s) => s.supplierId,  // Use supplierId as key
    );

    // ✅ Restore Purchases (as PurchaseModel objects with ID keys)
    await restoreBoxTypedWithId(
      "purchases",
      Hive.box<PurchaseModel>(HiveBoxNames.purchases),
          (m) => PurchaseModel.fromMap(m),
          (p) => p.purchaseId,  // Use purchaseId as key
    );

    // ✅ Restore Purchase Items (as PurchaseItemModel objects with ID keys)
    await restoreBoxTypedWithId(
      "purchaseItems",
      Hive.box<PurchaseItemModel>(HiveBoxNames.purchaseItems),
          (m) => PurchaseItemModel.fromMap(m),
          (pi) => pi.purchaseItemId,  // Use purchaseItemId as key
    );

    // ✅ Restore EOD Reports - hardcoded for retail mode (we're inside _restoreRetailData)
    try {
      final eodBox = Hive.box<EndOfDayReport>('eodBox');
      await restoreBoxTyped("eodReports", eodBox, (m) => EndOfDayReport.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring EOD reports: $e");
    }

    // ✅ Restore Expense Categories (uses typed box with registered adapter)
    try {
      final expenseCatBox = Hive.box<ExpenseCategory>('expenseCategory');
      await restoreBoxTyped("expenseCategories", expenseCatBox, (m) => ExpenseCategory.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring expense categories: $e");
    }

    // ✅ Restore Expenses (uses typed box with registered adapter)
    try {
      final expenseBox = Hive.box<Expense>('expenseBox');
      await restoreBoxTyped("expenses", expenseBox, (m) => Expense.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring expenses: $e");
    }

    // ✅ Restore Hold Sales & Hold Sale Items
    try {
      await restoreBoxTyped("holdSales", Hive.box<HoldSaleModel>(HiveBoxNames.holdSales), (m) => HoldSaleModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring hold sales: $e");
    }

    try {
      await restoreBoxTyped("holdSaleItems", Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems), (m) => HoldSaleItemModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring hold sale items: $e");
    }

    // ✅ Restore Purchase Orders & Purchase Order Items (with ID keys)
    try {
      await restoreBoxTypedWithId("purchaseOrders", Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders), (m) => PurchaseOrderModel.fromMap(m), (po) => po.poId);
    } catch (e) {
      debugPrint("⚠️ Error restoring purchase orders: $e");
    }

    try {
      await restoreBoxTypedWithId("purchaseOrderItems", Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems), (m) => PurchaseOrderItemModel.fromMap(m), (poi) => poi.poItemId);
    } catch (e) {
      debugPrint("⚠️ Error restoring purchase order items: $e");
    }

    // ✅ Restore GRNs & GRN Items (with ID keys)
    try {
      await restoreBoxTypedWithId("grns", Hive.box<GRNModel>(HiveBoxNames.grns), (m) => GRNModel.fromMap(m), (g) => g.grnId);
    } catch (e) {
      debugPrint("⚠️ Error restoring GRNs: $e");
    }

    try {
      await restoreBoxTypedWithId("grnItems", Hive.box<GRNItemModel>(HiveBoxNames.grnItems), (m) => GRNItemModel.fromMap(m), (gi) => gi.grnItemId);
    } catch (e) {
      debugPrint("⚠️ Error restoring GRN items: $e");
    }

    // ✅ Restore Category Models (with GST) (with ID keys)
    try {
      await restoreBoxTypedWithId("categoryModels", Hive.box<CategoryModel>(HiveBoxNames.categoryModels), (m) => CategoryModel.fromMap(m), (c) => c.categoryId);
    } catch (e) {
      debugPrint("⚠️ Error restoring category models: $e");
    }

    // ✅ Restore Payment Entries
    try {
      await restoreBoxTyped("paymentEntries", Hive.box<PaymentEntryModel>(HiveBoxNames.paymentEntries), (m) => PaymentEntryModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring payment entries: $e");
    }

    // ✅ Restore Credit Payments
    try {
      await restoreBoxTyped("creditPayments", Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments), (m) => CreditPaymentModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring credit payments: $e");
    }

    // ✅ Restore Attributes, Attribute Values, Product Attributes (with ID keys)
    try {
      await restoreBoxTypedWithId("attributes", Hive.box<AttributeModel>(HiveBoxNames.attributes), (m) => AttributeModel.fromMap(m), (a) => a.attributeId);
    } catch (e) {
      debugPrint("⚠️ Error restoring attributes: $e");
    }

    try {
      await restoreBoxTypedWithId("attributeValues", Hive.box<AttributeValueModel>(HiveBoxNames.attributeValues), (m) => AttributeValueModel.fromMap(m), (av) => av.valueId);
    } catch (e) {
      debugPrint("⚠️ Error restoring attribute values: $e");
    }

    try {
      await restoreBoxTyped("productAttributes", Hive.box<ProductAttributeModel>(HiveBoxNames.productAttributes), (m) => ProductAttributeModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring product attributes: $e");
    }

    // ✅ Restore Retail Staff
    try {
      await restoreBoxTyped("retailStaff", Hive.box<RetailStaffModel>(HiveBoxNames.retailStaff), (m) => RetailStaffModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring retail staff: $e");
    }

    // ✅ Restore Billing Tabs
    try {
      await restoreBoxTyped("billingTabs", Hive.box<BillingTabModel>(HiveBoxNames.billingTabs), (m) => BillingTabModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring billing tabs: $e");
    }

    // ✅ Restore Day Management Box (opening balance)
    try {
      if (data["dayManagement"] != null && data["dayManagement"].isNotEmpty) {
        debugPrint("📦 Restoring day management...");
        final dayMgmtBox = Hive.box(HiveBoxNames.dayManagementBox);
        await dayMgmtBox.clear();
        final dayMgmtData = data["dayManagement"][0] as Map<String, dynamic>;
        for (var entry in dayMgmtData.entries) {
          await dayMgmtBox.put(entry.key, entry.value);
        }
        debugPrint("📦 Day management restored: ${dayMgmtData.keys.length} entries");
      }
    } catch (e) {
      debugPrint("⚠️ Error restoring day management: $e");
    }

    // ✅ Restore Admin Box
    try {
      await restoreBoxTyped("adminBox", Hive.box<AdminModel>(HiveBoxNames.adminBox), (m) => AdminModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring admin box: $e");
    }

    debugPrint("✅ Full retail data restored successfully!");
  }

  /// ---------------------------
  /// 🔧 SYNC SHAREDPREFERENCES FROM BUSINESS DETAILS
  /// ---------------------------
  /// Retail side uses SharedPreferences for store information
  /// This method syncs SharedPreferences from BusinessDetails after restore
  static Future<void> _syncSharedPreferencesFromBusinessDetails() async {
    try {
      debugPrint("📦 Syncing SharedPreferences from BusinessDetails...");

      // Get BusinessDetails from Hive
      final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
      if (businessDetailsBox.isEmpty) {
        debugPrint("⚠️ BusinessDetails box is empty - nothing to sync");
        return;
      }

      final businessDetails = businessDetailsBox.values.first;
      final prefs = await SharedPreferences.getInstance();

      // Sync all store information fields
      if (businessDetails.storeName != null && businessDetails.storeName!.isNotEmpty) {
        await prefs.setString('store_name', businessDetails.storeName!);
        debugPrint("📦 Synced store name: ${businessDetails.storeName}");
      }

      if (businessDetails.ownerName != null && businessDetails.ownerName!.isNotEmpty) {
        await prefs.setString('store_owner_name', businessDetails.ownerName!);
        debugPrint("📦 Synced owner name: ${businessDetails.ownerName}");
      }

      if (businessDetails.address != null && businessDetails.address!.isNotEmpty) {
        await prefs.setString('store_address', businessDetails.address!);
        debugPrint("📦 Synced address: ${businessDetails.address}");
      }

      if (businessDetails.city != null && businessDetails.city!.isNotEmpty) {
        await prefs.setString('store_city', businessDetails.city!);
        debugPrint("📦 Synced city: ${businessDetails.city}");
      }

      if (businessDetails.state != null && businessDetails.state!.isNotEmpty) {
        await prefs.setString('store_state', businessDetails.state!);
        debugPrint("📦 Synced state: ${businessDetails.state}");
      }

      if (businessDetails.pincode != null && businessDetails.pincode!.isNotEmpty) {
        await prefs.setString('store_pincode', businessDetails.pincode!);
        debugPrint("📦 Synced pincode: ${businessDetails.pincode}");
      }

      if (businessDetails.phone != null && businessDetails.phone!.isNotEmpty) {
        await prefs.setString('store_phone', businessDetails.phone!);
        debugPrint("📦 Synced phone: ${businessDetails.phone}");
      }

      if (businessDetails.email != null && businessDetails.email!.isNotEmpty) {
        await prefs.setString('store_email', businessDetails.email!);
        debugPrint("📦 Synced email: ${businessDetails.email}");
      }

      if (businessDetails.gstin != null && businessDetails.gstin!.isNotEmpty) {
        await prefs.setString('store_gst_number', businessDetails.gstin!);
        debugPrint("📦 Synced GST number: ${businessDetails.gstin}");
      }

      debugPrint("✅ SharedPreferences synced successfully from BusinessDetails");
    } catch (e, stackTrace) {
      debugPrint("⚠️ Error syncing SharedPreferences: $e");
      debugPrint("Stack trace: $stackTrace");
      // Don't throw - let the restore continue even if this fails
    }
  }
}