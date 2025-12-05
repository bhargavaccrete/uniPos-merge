import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';


/// Service for managing stock alerts and notifications
class StockAlertService {
  static const String _thresholdKey = 'stock_alert_threshold';
  static const String _enabledKey = 'stock_alerts_enabled';
  static const int _defaultThreshold = 10;

  /// Get the current stock alert threshold from preferences
  Future<int> getThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_thresholdKey) ?? _defaultThreshold;
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

  /// Get critical stock items (stock <= 3)
  Future<List<Map<String, dynamic>>> getCriticalStockItems() async {
    final items = await getLowStockItems();
    return items.where((item) => (item['currentStock'] as int) <= 3).toList();
  }

  /// Get warning stock items (stock > 3 but <= threshold)
  Future<List<Map<String, dynamic>>> getWarningStockItems() async {
    final items = await getLowStockItems();
    return items.where((item) => (item['currentStock'] as int) > 3).toList();
  }

  /// Check if there are any low stock items
  Future<bool> hasLowStockItems() async {
    final count = await getLowStockCount();
    return count > 0;
  }

  /// Get stock alert summary
  Future<Map<String, dynamic>> getAlertSummary() async {
    final items = await getLowStockItems();
    final criticalCount = items.where((item) => (item['currentStock'] as int) <= 3).length;
    final warningCount = items.length - criticalCount;
    final outOfStockCount = items.where((item) => (item['currentStock'] as int) == 0).length;

    return {
      'totalAlerts': items.length,
      'criticalCount': criticalCount,
      'warningCount': warningCount,
      'outOfStockCount': outOfStockCount,
      'items': items,
    };
  }
}