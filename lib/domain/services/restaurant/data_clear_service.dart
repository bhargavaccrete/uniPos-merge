import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/database/hive_cart.dart';
import '../../../data/models/restaurant/db/database/hive_order.dart';
import '../../../data/models/restaurant/db/database/hive_pastorder.dart';

class DataClearService {

  /// Clears all transactional data after End of Day is completed
  /// NOTE: Past orders and expenses are NOT cleared - they are kept for historical records
  static Future<void> clearAllTransactionalData() async {
    try {
      // DO NOT clear past orders - keep them for history
      // Past orders will remain in the database for reporting purposes

      // Clear all active orders - using correct class name HiveOrders
      final activeOrders = await HiveOrders.getAllOrder();
      for (final order in activeOrders) {
        await HiveOrders.deleteOrder(order.id);
      }
      debugPrint('Cleared ${activeOrders.length} active orders');

      // DO NOT clear expenses - keep them for expense reports
      // Expenses will remain in the database for historical reporting

      // Clear cart if needed
      await HiveCart.clearCart();
      debugPrint('Cart cleared');

      // Using debugPrint instead of print for production
      debugPrint('EOD data cleared successfully (past orders and expenses preserved)');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }

  /// Clears only completed orders (past orders)
  static Future<void> clearCompletedOrders() async {
    try {
      final pastOrders = await HivePastOrder.getAllPastOrderModel();
      for (final order in pastOrders) {
        await HivePastOrder.deleteOrder(order.id);
      }
      debugPrint('Completed orders cleared successfully');
    } catch (e) {
      debugPrint('Error clearing completed orders: $e');
      rethrow;
    }
  }

  /// Get count of orders to be cleared
  static Future<Map<String, int>> getDataCountsToBeCleared() async {
    try {
      final pastOrders = await HivePastOrder.getAllPastOrderModel();
      final activeOrders = await HiveOrders.getAllOrder();

      return {
        'pastOrders': pastOrders.length,
        'activeOrders': activeOrders.length,
        'totalOrders': pastOrders.length + activeOrders.length,
      };
    } catch (e) {
      return {
        'pastOrders': 0,
        'activeOrders': 0,
        'totalOrders': 0,
      };
    }
  }
}