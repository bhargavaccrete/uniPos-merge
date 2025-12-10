import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Blob, Url;

import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/customer_model_208.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/purchase_Item_model_206.dart';
import '../../../data/models/retail/hive_model/purchase_model_207.dart';
import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../data/models/retail/hive_model/sale_model_203.dart';
import '../../../data/models/retail/hive_model/supplier_model_205.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';

/// Service for managing database backups
/// Handles export, import, and automatic daily backups
class BackupService {
  static const String _lastBackupKey = 'last_backup_date';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const String _backupDirectoryName = 'rpos_backups';

  /// Export all data to JSON format
  Future<Map<String, dynamic>> exportData() async {
    // Get all data from Hive boxes
    final products = productStore.products.map((p) => p.toProduct()).toList();

    final variants = <Map<String, dynamic>>[];
    for (var product in productStore.products) {
      final productVariants = await productStore.getVariantsForProduct(product.productId);
      variants.addAll(productVariants.map((v) => v.toMap()).toList());
    }

    // Get all sales including returns/refunds
    final sales = (await saleStore.getAllSales()).map((s) => s.toMap()).toList();

    // Get all sale items
    final saleItems = (await saleItemRepository.getAllSaleItems()).map((si) => {
      'saleItemId': si.saleItemId,
      'saleId': si.saleId,
      'varianteId': si.varianteId,
      'productId': si.productId,
      'productName': si.productName,
      'size': si.size,
      'color': si.color,
      'price': si.price,
      'qty': si.qty,
      'total': si.total,
      'discountAmount': si.discountAmount,
      'taxAmount': si.taxAmount,
      'barcode': si.barcode,
    }).toList();

    final customers = customerStore.customers.map((c) => {
      'customerId': c.customerId,
      'name': c.name,
      'email': c.email,
      'phone': c.phone,
      'address': c.address,
      'createdAt': c.createdAt,
      'updatedAt': c.updatedAt,
    }).toList();

    final suppliers = supplierStore.suppliers.map((s) => {
      'supplierId': s.supplierId,
      'name': s.name,
      'phone': s.phone,
      'address': s.address,
      'gstNumber': s.gstNumber,
      'openingBalance': s.openingBalance,
      'currentBalance': s.currentBalance,
      'createdAt': s.createdAt,
      'updatedAt': s.updatedAt,
    }).toList();

    final purchases = purchaseStore.purchases.map((p) => {
      'purchaseId': p.purchaseId,
      'supplierId': p.supplierId,
      'invoiceNumber': p.invoiceNumber,
      'totalItems': p.totalItems,
      'totalAmount': p.totalAmount,
      'purchaseDate': p.purchaseDate,
      'createdAt': p.createdAt,
      'updatedAt': p.updatedAt,
    }).toList();

    final purchaseItems = <Map<String, dynamic>>[];
    for (var purchase in purchaseStore.purchases) {
      await purchaseStore.loadPurchaseItems(purchase.purchaseId);
      purchaseItems.addAll(purchaseStore.currentPurchaseItems.map((pi) => pi.toMap()).toList());
    }

    // Get categories
    final categories = productStore.categories.toList();

    return {
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'appName': 'rPOS',
      'data': {
        'products': products,
        'variants': variants,
        'sales': sales,
        'saleItems': saleItems,

        'customers': customers,
        'suppliers': suppliers,
        'purchases': purchases,
        'purchaseItems': purchaseItems,
        'categories': categories,
      },
      'statistics': {
        'totalProducts': products.length,
        'totalVariants': variants.length,
        'totalSales': sales.length,
        'totalCustomers': customers.length,
        'totalSuppliers': suppliers.length,
        'totalPurchases': purchases.length,
      }
    };
  }

  /// Save backup to a file
  Future<File?> saveBackupToFile(Map<String, dynamic> backupData, {String? customPath}) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

    final fileName = 'rpos_backup_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.json';

    if (kIsWeb) {
      // On web, trigger download directly using HTML anchor element
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      // Clean up the URL after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        html.Url.revokeObjectUrl(url);
      });

      // Update last backup date on web too
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      // Return null since we can't create File objects on web
      return null;
    }

    File backupFile;
    if (customPath != null) {
      backupFile = File('$customPath/$fileName');
    } else {
      // Try to use external storage (Downloads or Documents) that persists after uninstall
      Directory? backupDir;

      // For Android: Use external storage that won't be deleted on uninstall
      if (!kIsWeb && Platform.isAndroid) {
        // Try to get external storage directory (Downloads/Documents)
        final externalDirs = await getExternalStorageDirectory();
        if (externalDirs != null) {
          // Navigate to public storage location
          // From: /storage/emulated/0/Android/data/com.app/files
          // To: /storage/emulated/0/Download/rPOS_Backups or /storage/emulated/0/Documents/rPOS_Backups
          final pathParts = externalDirs.path.split('/');
          final publicPath = pathParts.sublist(0, 4).join('/'); // Get /storage/emulated/0

          // Try Documents folder first, then Downloads as fallback
          backupDir = Directory('$publicPath/Documents/$_backupDirectoryName');
          if (!await backupDir.exists()) {
            try {
              await backupDir.create(recursive: true);
            } catch (e) {
              // If Documents fails, try Downloads
              backupDir = Directory('$publicPath/Download/$_backupDirectoryName');
            }
          }
        }
      }

      // Fallback to app documents directory if external storage is not available
      if (backupDir == null || !await backupDir.exists()) {
        final directory = await getApplicationDocumentsDirectory();
        backupDir = Directory('${directory.path}/$_backupDirectoryName');
      }

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      backupFile = File('${backupDir.path}/$fileName');
    }

    await backupFile.writeAsString(jsonString);

    // Update last backup date
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

    return backupFile;
  }

  /// Export backup and return the file (null on web)
  Future<File?> createBackup({String? customPath}) async {
    final backupData = await exportData();
    return await saveBackupToFile(backupData, customPath: customPath);
  }

  /// Validate backup file format
  Future<Map<String, dynamic>> validateBackupFile(File file) async {
    try {
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup format
      if (!data.containsKey('version') || !data.containsKey('data')) {
        return {
          'valid': false,
          'error': 'Invalid backup format',
        };
      }

      return {
        'valid': true,
        'version': data['version'],
        'exportDate': data['exportDate'],
        'statistics': data['statistics'] ?? {},
      };
    } catch (e) {
      return {
        'valid': false,
        'error': 'Failed to read backup file: $e',
      };
    }
  }

  /// Get backup file info
  Future<Map<String, dynamic>> getBackupInfo(File file) async {
    try {
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return {
        'fileName': file.path.split('/').last,
        'filePath': file.path,
        'fileSize': await file.length(),
        'lastModified': file.lastModifiedSync().toIso8601String(),
        'version': data['version'] ?? 'Unknown',
        'exportDate': data['exportDate'] ?? 'Unknown',
        'statistics': data['statistics'] ?? {},
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Get all local backups
  Future<List<File>> getLocalBackups() async {
    if (kIsWeb) return [];

    try {
      Directory? backupDir;

      // For Android: Check public storage first
      if (!kIsWeb && Platform.isAndroid) {
        final externalDirs = await getExternalStorageDirectory();
        if (externalDirs != null) {
          final pathParts = externalDirs.path.split('/');
          final publicPath = pathParts.sublist(0, 4).join('/');

          // Try Documents folder first
          backupDir = Directory('$publicPath/Documents/$_backupDirectoryName');
          if (!await backupDir.exists()) {
            // Try Downloads folder
            backupDir = Directory('$publicPath/Download/$_backupDirectoryName');
          }
        }
      }

      // Fallback to app documents directory
      if (backupDir == null || !await backupDir.exists()) {
        final directory = await getApplicationDocumentsDirectory();
        backupDir = Directory('${directory.path}/$_backupDirectoryName');
      }

      if (!await backupDir.exists()) {
        return [];
      }

      final files = backupDir.listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();

      // Sort by modified date (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (e) {
      return [];
    }
  }

  /// Delete a backup file
  Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Check if daily backup is needed
  Future<bool> isDailyBackupNeeded() async {
    if (kIsWeb) return false;

    final prefs = await SharedPreferences.getInstance();
    final autoBackupEnabled = prefs.getBool(_autoBackupEnabledKey) ?? true;

    if (!autoBackupEnabled) return false;

    final lastBackupString = prefs.getString(_lastBackupKey);
    if (lastBackupString == null) return true;

    final lastBackup = DateTime.parse(lastBackupString);
    final today = DateTime.now();

    // Check if last backup was on a different day
    return lastBackup.year != today.year ||
        lastBackup.month != today.month ||
        lastBackup.day != today.day;
  }

  /// Perform daily auto backup
  Future<File?> performDailyBackup() async {
    if (await isDailyBackupNeeded()) {
      try {
        return await createBackup();
      } catch (e) {
        // Silently fail daily backup
        return null;
      }
    }
    return null;
  }

  /// Enable/disable auto backup
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  /// Check if auto backup is enabled
  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? true;
  }

  /// Get last backup date
  Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupString = prefs.getString(_lastBackupKey);
    if (lastBackupString == null) return null;
    return DateTime.parse(lastBackupString);
  }

  /// Clean old backups (keep only last N backups)
  Future<void> cleanOldBackups({int keepCount = 30}) async {
    final backups = await getLocalBackups();
    if (backups.length > keepCount) {
      final toDelete = backups.sublist(keepCount);
      for (var file in toDelete) {
        await deleteBackup(file);
      }
    }
  }

  /// Get the backup directory path
  Future<String> getBackupDirectoryPath() async {
    if (kIsWeb) return '';

    // For Android: Return public storage path
    if (!kIsWeb && Platform.isAndroid) {
      final externalDirs = await getExternalStorageDirectory();
      if (externalDirs != null) {
        final pathParts = externalDirs.path.split('/');
        final publicPath = pathParts.sublist(0, 4).join('/');

        // Check if Documents folder exists, else use Downloads
        final documentsDir = Directory('$publicPath/Documents/$_backupDirectoryName');
        if (await documentsDir.exists()) {
          return documentsDir.path;
        }

        final downloadsDir = Directory('$publicPath/Download/$_backupDirectoryName');
        if (await downloadsDir.exists()) {
          return downloadsDir.path;
        }

        // Return the preferred location even if it doesn't exist yet
        return '$publicPath/Documents/$_backupDirectoryName';
      }
    }

    // Fallback to app documents directory
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_backupDirectoryName';
  }

  // ==================== RESTORE/IMPORT FUNCTIONALITY ====================

  /// Restore data from a backup file
  Future<Map<String, dynamic>> restoreFromBackup(File backupFile) async {
    try {
      // Read and validate the backup file
      final jsonString = await backupFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup format
      if (!data.containsKey('version') || !data.containsKey('data')) {
        return {
          'success': false,
          'error': 'Invalid backup format',
        };
      }

      final backupData = data['data'] as Map<String, dynamic>;
      int restoredCount = 0;
      final errors = <String>[];

      // Clear existing data (optional - you might want to ask user first)
      // await _clearAllData();

      // Restore Categories
      if (backupData.containsKey('categories')) {
        try {
          final categories = backupData['categories'] as List;
          for (var category in categories) {
            await productStore.addCategory(category.toString());
            restoredCount++;
          }
        } catch (e) {
          errors.add('Categories restore error: $e');
        }
      }

      // Restore Products
      if (backupData.containsKey('products')) {
        try {
          final products = backupData['products'] as List;
          for (var productData in products) {
            try {
              final productMap = productData as Map<String, dynamic>;
              final product = ProductModel(
                productId: productMap['productId'] ?? const Uuid().v4(),
                productName: productMap['productName'] ?? productMap['name'] ?? '',
                brandName: productMap['brandName'],
                category: productMap['category'] ?? '',
                subCategory: productMap['subCategory'],
                imagePath: productMap['imagePath'],
                description: productMap['description'],
                hasVariants: productMap['hasVariants'] ?? false,
                createdAt: productMap['createdAt'] ?? DateTime.now().toIso8601String(),
                updateAt: productMap['updateAt'] ?? productMap['updatedAt'] ?? DateTime.now().toIso8601String(),
              );
              await productStore.addProduct(product);
              restoredCount++;
            } catch (e) {
              // Skip individual product errors
            }
          }
        } catch (e) {
          errors.add('Products restore error: $e');
        }
      }

      // Restore Variants with stock quantities
      if (backupData.containsKey('variants')) {
        try {
          final variants = backupData['variants'] as List;
          for (var variantData in variants) {
            try {
              final variantMap = variantData as Map<String, dynamic>;
              final variant = VarianteModel(
                varianteId: variantMap['varianteId'] ?? const Uuid().v4(),
                productId: variantMap['productId'] ?? '',
                size: variantMap['size'],
                color: variantMap['color'],
                weight: variantMap['weight'],
                sku: variantMap['sku'],
                barcode: variantMap['barcode'],
                mrp: (variantMap['mrp'] as num?)?.toDouble(),
                costPrice: (variantMap['costPrice'] as num?)?.toDouble(),
                stockQty: (variantMap['stockQty'] as num?)?.toInt() ?? 0,
                minStock: (variantMap['minStock'] as num?)?.toInt(),
                taxRate: (variantMap['taxRate'] as num?)?.toDouble(),
                createdAt: variantMap['createdAt'] ?? DateTime.now().toIso8601String(),
                updateAt: variantMap['updateAt'] ?? variantMap['updatedAt'],
              );
              await productStore.addVariant(variant);
              restoredCount++;
            } catch (e) {
              // Skip individual variant errors
            }
          }
        } catch (e) {
          errors.add('Variants restore error: $e');
        }
      }

      // Restore Customers
      if (backupData.containsKey('customers')) {
        try {
          final customers = backupData['customers'] as List;
          for (var customerData in customers) {
            try {
              final customerMap = customerData as Map<String, dynamic>;
              final customer = CustomerModel(
                customerId: customerMap['customerId'] ?? const Uuid().v4(),
                name: customerMap['name'] ?? '',
                phone: customerMap['phone'] ?? '',
                email: customerMap['email'],
                address: customerMap['address'],
                notes: customerMap['notes'],
                totalPurchaseAmount: (customerMap['totalPurchaseAmount'] as num?)?.toDouble() ?? 0.0,
                lastVisited: customerMap['lastVisited'],
                pointsBalance: (customerMap['pointsBalance'] as num?)?.toInt() ?? 0,
                creditBalance: (customerMap['creditBalance'] as num?)?.toDouble() ?? 0.0,
                createdAt: customerMap['createdAt'] ?? DateTime.now().toIso8601String(),
                updatedAt: customerMap['updatedAt'],
              );
              await customerStore.addCustomer(customer);
              restoredCount++;
            } catch (e) {
              // Skip individual customer errors
            }
          }
        } catch (e) {
          errors.add('Customers restore error: $e');
        }
      }

      // Restore Suppliers
      if (backupData.containsKey('suppliers')) {
        try {
          final suppliers = backupData['suppliers'] as List;
          for (var supplierData in suppliers) {
            try {
              final supplierMap = supplierData as Map<String, dynamic>;
              final supplier = SupplierModel(
                supplierId: supplierMap['supplierId'] ?? const Uuid().v4(),
                name: supplierMap['name'] ?? '',
                phone: supplierMap['phone'],
                address: supplierMap['address'],
                gstNumber: supplierMap['gstNumber'],
                openingBalance: (supplierMap['openingBalance'] as num?)?.toDouble() ?? 0.0,
                currentBalance: (supplierMap['currentBalance'] as num?)?.toDouble() ?? 0.0,
                createdAt: supplierMap['createdAt'] ?? DateTime.now().toIso8601String(),
                updatedAt: supplierMap['updatedAt'],
              );
              await supplierStore.addSupplier(supplier);
              restoredCount++;
            } catch (e) {
              // Skip individual supplier errors
            }
          }
        } catch (e) {
          errors.add('Suppliers restore error: $e');
        }
      }

      // Restore Sales (including returns/refunds)
      if (backupData.containsKey('sales')) {
        try {
          final sales = backupData['sales'] as List;
          for (var saleData in sales) {
            try {
              final saleMap = saleData as Map<String, dynamic>;
              final sale = SaleModel(
                saleId: saleMap['saleId'] ?? const Uuid().v4(),
                customerId: saleMap['customerId'],
                totalItems: (saleMap['totalItems'] as num?)?.toInt() ?? 0,
                subtotal: (saleMap['subtotal'] as num?)?.toDouble() ?? 0.0,
                discountAmount: (saleMap['discountAmount'] as num?)?.toDouble() ?? 0.0,
                taxAmount: (saleMap['taxAmount'] as num?)?.toDouble() ?? 0.0,
                totalAmount: (saleMap['totalAmount'] as num?)?.toDouble() ?? 0.0,
                paymentType: saleMap['paymentType'] ?? 'cash',
                date: saleMap['date'] ?? DateTime.now().toIso8601String(),
                createdAt: saleMap['createdAt'] ?? DateTime.now().toIso8601String(),
                updatedAt: saleMap['updatedAt'] ?? DateTime.now().toIso8601String(),
                isReturn: saleMap['isReturn'] ?? false,
                originalSaleId: saleMap['originalSaleId'],
              );
              await saleStore.addSale(sale);
              restoredCount++;
            } catch (e) {
              // Skip individual sale errors
            }
          }
        } catch (e) {
          errors.add('Sales restore error: $e');
        }
      }

      // Restore Sale Items
      if (backupData.containsKey('saleItems')) {
        try {
          final saleItems = backupData['saleItems'] as List;
          for (var itemData in saleItems) {
            try {
              final itemMap = itemData as Map<String, dynamic>;
              final saleItem = SaleItemModel(
                saleItemId: itemMap['saleItemId'] ?? const Uuid().v4(),
                saleId: itemMap['saleId'] ?? '',
                varianteId: itemMap['varianteId'] ?? '',
                productId: itemMap['productId'] ?? '',
                productName: itemMap['productName'],
                size: itemMap['size'],
                color: itemMap['color'],
                price: (itemMap['price'] as num?)?.toDouble() ?? 0.0,
                qty: (itemMap['qty'] as num?)?.toInt() ?? 0,
                total: (itemMap['total'] as num?)?.toDouble() ?? 0.0,
                discountAmount: (itemMap['discountAmount'] as num?)?.toDouble(),
                taxAmount: (itemMap['taxAmount'] as num?)?.toDouble(),
                barcode: itemMap['barcode'],
              );
              await saleItemRepository.addSaleItem(saleItem);
              restoredCount++;
            } catch (e) {
              // Skip individual sale item errors
            }
          }
        } catch (e) {
          errors.add('Sale Items restore error: $e');
        }
      }

      // Restore Purchases and Purchase Items together
      if (backupData.containsKey('purchases') && backupData.containsKey('purchaseItems')) {
        try {
          final purchases = backupData['purchases'] as List;
          final allPurchaseItems = backupData['purchaseItems'] as List;

          // Group purchase items by purchaseId
          final purchaseItemsMap = <String, List<PurchaseItemModel>>{};
          for (var itemData in allPurchaseItems) {
            try {
              final itemMap = itemData as Map<String, dynamic>;
              final purchaseItem = PurchaseItemModel(
                purchaseItemId: itemMap['purchaseItemId'] ?? const Uuid().v4(),
                purchaseId: itemMap['purchaseId'] ?? '',
                variantId: itemMap['variantId'] ?? '',
                productId: itemMap['productId'] ?? '',
                quantity: (itemMap['quantity'] as num?)?.toInt() ?? 0,
                costPrice: (itemMap['costPrice'] as num?)?.toDouble() ?? 0.0,
                mrp: (itemMap['mrp'] as num?)?.toDouble() ?? 0.0,
                total: (itemMap['total'] as num?)?.toDouble() ?? 0.0,
                createdAt: itemMap['createdAt'] ?? DateTime.now().toIso8601String(),
              );

              if (!purchaseItemsMap.containsKey(purchaseItem.purchaseId)) {
                purchaseItemsMap[purchaseItem.purchaseId] = [];
              }
              purchaseItemsMap[purchaseItem.purchaseId]!.add(purchaseItem);
            } catch (e) {
              // Skip individual purchase item errors
            }
          }

          // Now restore purchases with their items
          for (var purchaseData in purchases) {
            try {
              final purchaseMap = purchaseData as Map<String, dynamic>;
              final purchaseId = purchaseMap['purchaseId'] ?? const Uuid().v4();

              final purchase = PurchaseModel(
                purchaseId: purchaseId,
                supplierId: purchaseMap['supplierId'] ?? '',
                invoiceNumber: purchaseMap['invoiceNumber'],
                totalItems: (purchaseMap['totalItems'] as num?)?.toInt() ?? 0,
                totalAmount: (purchaseMap['totalAmount'] as num?)?.toDouble() ?? 0.0,
                purchaseDate: purchaseMap['purchaseDate'] ?? DateTime.now().toIso8601String(),
                createdAt: purchaseMap['createdAt'] ?? DateTime.now().toIso8601String(),
                updatedAt: purchaseMap['updatedAt'],
              );

              final items = purchaseItemsMap[purchaseId] ?? [];
              await purchaseStore.addPurchase(purchase, items);
              restoredCount++;
              restoredCount += items.length;
            } catch (e) {
              // Skip individual purchase errors
            }
          }
        } catch (e) {
          errors.add('Purchases restore error: $e');
        }
      }

      return {
        'success': true,
        'restoredCount': restoredCount,
        'errors': errors,
        'statistics': data['statistics'] ?? {},
        'message': 'Successfully restored $restoredCount items',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to restore backup: $e',
      };
    }
  }
}