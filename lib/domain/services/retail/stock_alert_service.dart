import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';


/// Service for managing stock alerts and notifications
class StockAlertService {
  static const String _thresholdKey = 'stock_alert_threshold';
  static const String _enabledKey = 'stock_alerts_enabled';
  /// Used when nothing has been stored yet. Public so a screen can seed its
  /// filter with the same number `getThreshold()` would return, instead of
  /// hard-coding its own.
  static const int defaultThreshold = 10;

  /// The threshold values offered in the UI.
  ///
  /// One list, because there are two places to change this setting — Settings
  /// and the Stock Alerts screen — and they used to offer different options
  /// (`[5,10,15,20,25,50]` vs `[5,10,15,20]`) for the same stored value.
  static const List<int> thresholdOptions = [5, 10, 15, 20, 25, 50];

  /// Get the current stock alert threshold from preferences
  Future<int> getThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_thresholdKey) ?? defaultThreshold;
  }

  /// Set the stock alert threshold
  Future<void> setThreshold(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_thresholdKey, threshold);
  }

  /// Check if stock alerts are enabled
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Enable or disable stock alerts
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Get all low stock items based on the configured threshold
  Future<List<Map<String, dynamic>>> getLowStockItems() async {
    final threshold = await getThreshold();
    return await reportService.getLowStockReport(threshold: threshold);
  }

  /// Get the count of low stock items
  Future<int> getLowStockCount() async {
    final items = await getLowStockItems();
    return items.length;
  }

  /// Whether a low-stock row is in the "critical" band rather than merely low.
  ///
  /// Mirrors [ProductStore.statusFor]: a third of that row's reorder point
  /// (its variant `minStock`, or the global threshold), never below 1. A fixed
  /// "<= 3" would mark a variant that reorders at 2 as critical forever.
  ///
  /// PUBLIC because the Low Stock report needs the same answer: it used to
  /// carry its own `stock <= 3` constant, so the Stock Alerts card and the
  /// report disagreed about which rows were critical — over the very same rows,
  /// which both take from `getLowStockReport`. One rule, one place.
  static bool isCritical(Map<String, dynamic> item) {
    // Read as `num`, not `int`: these rows now carry decimal quantities for
    // loose goods, and a hard `as int` cast would throw on the first one.
    final reorderPoint =
        (item['reorderPoint'] as num?)?.toDouble() ?? defaultThreshold.toDouble();
    // Hand-bounded rather than `clamp`, which throws when the reorder point is
    // a fraction below 1. Same result as clamp(1, reorderPoint) for whole values.
    final raw = (reorderPoint / 3).ceilToDouble();
    final atLeastOne = raw < 1.0 ? 1.0 : raw;
    final critical = atLeastOne > reorderPoint ? reorderPoint : atLeastOne;
    return ((item['currentStock'] as num?)?.toDouble() ?? 0) <= critical;
  }

  /// Get critical stock items
  Future<List<Map<String, dynamic>>> getCriticalStockItems() async {
    final items = await getLowStockItems();
    return items.where(isCritical).toList();
  }

  /// Get warning stock items (low, but not yet critical)
  Future<List<Map<String, dynamic>>> getWarningStockItems() async {
    final items = await getLowStockItems();
    return items.where((item) => !isCritical(item)).toList();
  }

  /// Check if there are any low stock items
  Future<bool> hasLowStockItems() async {
    final count = await getLowStockCount();
    return count > 0;
  }

  /// Get stock alert summary
  Future<Map<String, dynamic>> getAlertSummary() async {
    final items = await getLowStockItems();
    final criticalCount = items.where(isCritical).length;
    final warningCount = items.length - criticalCount;
    final outOfStockCount = items
        .where((item) => ((item['currentStock'] as num?)?.toDouble() ?? 0) <= 0)
        .length;

    return {
      'totalAlerts': items.length,
      'criticalCount': criticalCount,
      'warningCount': warningCount,
      'outOfStockCount': outOfStockCount,
      'items': items,
    };
  }
}