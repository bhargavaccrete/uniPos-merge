import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/restaurant/history_data_generator.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_data_generator.dart';
import 'package:billberrylite/domain/services/restaurant/setup_data_generator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/common/categorymodel_300.dart';
import '../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../data/models/common/staffModel_310.dart';
import '../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../data/models/common/taxmodel_314.dart';
import '../../../data/models/restaurant/db/variantmodel_305.dart';


class ComprehensiveDataGenerator {
  static final Random _random = Random();

  // Master method to generate all data
  static Future<Map<String, dynamic>> generateAllData({
    int categories = 20,
    int items = 500,
    int tables = 50,
    int staff = 20,
    int customers = 200,
    int historyDays = 30,
    int ordersPerDay = 60,
    int purchaseOrders = 40,
    bool withImages = false,
    void Function(String message)? onProgress,
  }) async {
    final overallStart = DateTime.now();
    final Map<String, dynamic> results = {};

    try {
      final setupStart = DateTime.now();
      onProgress?.call('Creating menu, tables, staff and customers…');
      final setup = await SetupDataGenerator.generate(
        categories: categories,
        items: items,
        tables: tables,
        staff: staff,
        customers: customers,
        imageFor: withImages ? _placeholderImageBytes : null,
      );
      results['setup'] = setup;
      results['setupTime'] =
          DateTime.now().difference(setupStart).inMilliseconds;
      for (final e in setup.counts.entries) {
        results[e.key] = e.value.added;
      }

      if (purchaseOrders > 0) {
        final inventoryStart = DateTime.now();
        results['inventory'] = await InventoryDataGenerator.generate(
          purchaseOrders: purchaseOrders,
          historyDays: historyDays,
          onProgress: onProgress,
        );
        results['inventoryTime'] =
            DateTime.now().difference(inventoryStart).inMilliseconds;
      }

      final historyStart = DateTime.now();
      final history = await HistoryDataGenerator.generate(
        days: historyDays,
        ordersPerDay: ordersPerDay,
        onProgress: onProgress,
      );
      results['history'] = history;
      results['historyTime'] =
          DateTime.now().difference(historyStart).inMilliseconds;

      results['totalTime'] =
          DateTime.now().difference(overallStart).inMilliseconds;
      results['success'] = true;
    } catch (e) {
      debugPrint('Data generation failed: $e');
      results['error'] = e.toString();
      results['success'] = false;
    }

    return results;
  }

  /// 400×400 PNG placeholder for an item photo.
  static Future<Uint8List?> _placeholderImageBytes(
      String itemName, int index) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = const Size(400, 400);

      // More variety in background colors
      final colors = [
        Colors.red.shade400,
        Colors.blue.shade400,
        Colors.green.shade400,
        Colors.orange.shade400,
        Colors.purple.shade400,
        Colors.teal.shade400,
        Colors.pink.shade400,
        Colors.indigo.shade400,
        Colors.amber.shade400,
        Colors.cyan.shade400,
        Colors.lime.shade400,
        Colors.deepOrange.shade400,
        Colors.lightBlue.shade400,
        Colors.lightGreen.shade400,
        Colors.deepPurple.shade400,
      ];

      // Use random color instead of sequential
      final bgColor = colors[_random.nextInt(colors.length)];

      // Draw background with gradient
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width, size.height),
          [bgColor, bgColor.withOpacity(0.7)],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Draw decorative shapes for variety
      final shapePaint = Paint()..color = Colors.white.withOpacity(0.2);
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 60, shapePaint);
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 80, shapePaint);

      // Draw text with shadow
      final textPainter = TextPainter(
        text: TextSpan(
          text: itemName.length > 20 ? '${itemName.substring(0, 17)}...' : itemName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black45,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: size.width - 40);
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );

      // Add item number at bottom
      final numberPainter = TextPainter(
        text: TextSpan(
          text: '#${index + 1}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      numberPainter.layout();
      numberPainter.paint(
        canvas,
        Offset((size.width - numberPainter.width) / 2, size.height - 40),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Placeholder image failed for item #${index + 1}: $e');
      return null;
    }
  }

  // Clear all data from all boxes
  static Future<void> clearAllData() async {
    print('🗑️ Clearing all data from all boxes...');

    final boxes = [
      'categories',
      'itemBoxs',
      'variante',
      'extra',
      'orderBox',
      'pastorderBox',
      'tablesBox',
      'staffBox',
      'taxes',
      'restaurant_eodBox',
      'cart_box',
      HiveBoxNames.restaurantChoices,
      HiveBoxNames.customer,
      HiveBoxNames.restaurantStockMovements,
      HiveBoxNames.restaurantCashMovements,
      HiveBoxNames.restaurantExpense,
      HiveBoxNames.shift,
      HiveBoxNames.restaurantStockJournal,
      HiveBoxNames.restaurantRecipes,
      HiveBoxNames.restaurantRecipeProductions,
      HiveBoxNames.restaurantSuppliers,
      HiveBoxNames.restaurantSupplierLedger,
      HiveBoxNames.restaurantPurchaseOrders,
      HiveBoxNames.restaurantPurchaseOrderItems,
      HiveBoxNames.restaurantGrns,
      HiveBoxNames.restaurantGrnItems,
      HiveBoxNames.restaurantPurchaseReturns,
      HiveBoxNames.restaurantPurchaseReturnItems,
      HiveBoxNames.restaurantSupplierClaims,
      HiveBoxNames.restaurantSupplierClaimItems,
      HiveBoxNames.restaurantInventoryLosses,
      HiveBoxNames.restaurantStockTakes,
      HiveBoxNames.restaurantStockTakeItems,
    ];

    for (final boxName in boxes) {
      try {
        final box = Hive.box(boxName);
        final count = box.length;
        await box.clear();
        print('✅ Cleared $boxName (had $count items)');
      } catch (e) {
        print('⚠️ Error clearing $boxName: $e');
      }
    }

    // Closed sessions only — the open day's session is still referenced by
    // the day state, and deleting it would break today's session.
    try {
      final sessions =
          Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
      final closed = sessions.keys
          .where((k) => sessions.get(k)?.isClosed ?? false)
          .toList();
      await sessions.deleteAll(closed);
    } catch (e) {
      debugPrint('Error clearing sessions: $e');
    }

    await SetupDataGenerator.reloadStores();
    await Future.wait([
      pastOrderStore.loadPastOrders(),
      orderStore.loadOrders(),
      eodStore.loadEODReports(),
      expenseStore.loadExpenses(),
      restaurantSupplierStore.loadSuppliers(),
      restaurantPurchaseOrderStore.loadPurchaseOrders(),
      restaurantPurchaseOrderStore.loadGRNs(),
      restaurantDamagedGoodsStore.loadAll(),
      restaurantStockTakeStore.loadTakes(),
    ]);
    print('✅ All data cleared!');
  }

  /// Counts for boxes [getAllStats] leaves out (kept separate because the
  /// Performance Statistics report sums every [getAllStats] value).
  static Map<String, int> getExtraStats() {
    int len(String name) {
      try {
        return Hive.box(name).length;
      } catch (_) {
        return 0;
      }
    }

    return {
      'choices': len(HiveBoxNames.restaurantChoices),
      'customers': len(HiveBoxNames.customer),
      'stockMovements': len(HiveBoxNames.restaurantStockMovements),
      'sessions': len(HiveBoxNames.restaurantSessions),
      'cashMovements': len(HiveBoxNames.restaurantCashMovements),
      'expenses': len(HiveBoxNames.restaurantExpense),
      'shifts': len(HiveBoxNames.shift),
      'suppliers': len(HiveBoxNames.restaurantSuppliers),
      'purchaseOrders': len(HiveBoxNames.restaurantPurchaseOrders),
      'grns': len(HiveBoxNames.restaurantGrns),
      'supplierLedger': len(HiveBoxNames.restaurantSupplierLedger),
      'recipes': len(HiveBoxNames.restaurantRecipes),
      'productions': len(HiveBoxNames.restaurantRecipeProductions),
      'inventoryLosses': len(HiveBoxNames.restaurantInventoryLosses),
      'stockTakes': len(HiveBoxNames.restaurantStockTakes),
    };
  }

  // Get statistics for all boxes
  static Map<String, int> getAllStats() {
    return {
      'categories': Hive.box<Category>('categories').length,
      'items': Hive.box<Items>('itemBoxs').length,
      'variants': Hive.box<VariantModel>('variante').length,
      'extras': Hive.box<Extramodel>('extra').length,
      'activeOrders': Hive.box<OrderModel>('orderBox').length,
      'pastOrders': Hive.box<PastOrderModel>('pastorderBox').length,
      'tables': Hive.box<TableModel>('tablesBox').length,
      'staff': Hive.box<StaffModel>('staffBox').length,
      'taxRates': Hive.box<Tax>('taxes').length,
      'eodReports': Hive.box<EndOfDayReport>('restaurant_eodBox').length,
      'cart': Hive.box<CartItem>('cart_box').length,
    };
  }

  // Get file sizes for all boxes
  static Future<Map<String, String>> getBoxFileSizes() async {
    final Map<String, String> sizes = {};

    final boxes = [
      'categories', 'itemBoxs', 'variante', 'extra', 'orderBox',
      'pastorderBox', 'tablesBox', 'staffBox', 'taxes', 'restaurant_eodBox', 'cart_box',
    ];

    for (final boxName in boxes) {
      try {
        final box = Hive.box(boxName);

        // Try to get file size using Hive's internal methods
        if (box.isOpen) {
          // Hive stores data, calculate approximate size based on entries
          final itemCount = box.length;
          if (itemCount == 0) {
            sizes[boxName] = '0 B';
          } else {
            // Get the actual file path
            final path = box.path;
            if (path != null && path.isNotEmpty) {
              try {
                final file = File(path);
                if (await file.exists()) {
                  final bytes = await file.length();
                  sizes[boxName] = _formatBytes(bytes);
                } else {
                  // File doesn't exist yet, estimate size
                  sizes[boxName] = 'Empty';
                }
              } catch (fileError) {
                // If file read fails, show count instead
                sizes[boxName] = '$itemCount items';
              }
            } else {
              // No path available, show item count
              sizes[boxName] = '$itemCount items';
            }
          }
        } else {
          sizes[boxName] = 'Closed';
        }
      } catch (e) {
        // Fallback: try to show the error or item count
        try {
          final box = Hive.box(boxName);
          sizes[boxName] = '${box.length} items';
        } catch (_) {
          sizes[boxName] = 'N/A';
        }
      }
    }

    return sizes;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
