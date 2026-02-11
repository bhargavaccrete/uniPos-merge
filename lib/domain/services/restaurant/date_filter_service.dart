import 'package:hive/hive.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';

/// Optimized date filtering service for LazyBox
/// Provides efficient date-based queries without loading full dataset
/// Supports pagination (limit/offset) for large result sets
class DateFilterService {
  final LazyBox<PastOrderModel> _lazyBox;

  DateFilterService(this._lazyBox);

  /// Get orders in date range with optional pagination
  /// Only loads orders that match the date filter - very efficient!
  Future<List<PastOrderModel>> getOrdersByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? limit,   // Max items to return (for pagination)
    int? offset,  // Skip first N items (for pagination)
  }) async {
    final results = <PastOrderModel>[];
    int skipped = 0;
    int loaded = 0;

    // Iterate through keys only (fast - keys are in memory)
    for (final key in _lazyBox.keys) {
      // Apply offset (skip first N)
      if (offset != null && skipped < offset) {
        skipped++;
        continue;
      }

      // Apply limit (stop after N)
      if (limit != null && loaded >= limit) {
        break;
      }

      // Load order from disk only if needed
      final order = await _lazyBox.get(key);
      if (order?.orderAt != null &&
          order!.orderAt!.isAfter(startDate) &&
          order.orderAt!.isBefore(endDate)) {
        results.add(order);
        loaded++;
      }
    }

    return results;
  }

  /// Quick filter: Get today's orders
  Future<List<PastOrderModel>> getTodaysOrders({
    int? limit,
    int? offset,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getOrdersByDateRange(
      startDate: start,
      endDate: end,
      limit: limit,
      offset: offset,
    );
  }

  /// Quick filter: Get this week's orders
  Future<List<PastOrderModel>> getWeekOrders({
    int? limit,
    int? offset,
  }) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getOrdersByDateRange(
      startDate: start,
      endDate: end,
      limit: limit,
      offset: offset,
    );
  }

  /// Quick filter: Get this month's orders
  Future<List<PastOrderModel>> getMonthOrders({
    int? limit,
    int? offset,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return getOrdersByDateRange(
      startDate: start,
      endDate: end,
      limit: limit,
      offset: offset,
    );
  }

  /// Quick filter: Get this year's orders
  Future<List<PastOrderModel>> getYearOrders({
    int? limit,
    int? offset,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31, 23, 59, 59);

    return getOrdersByDateRange(
      startDate: start,
      endDate: end,
      limit: limit,
      offset: offset,
    );
  }

  /// Count orders in date range (efficient - doesn't load full data)
  /// Only loads orderAt field to check dates
  Future<int> countOrdersInRange(DateTime startDate, DateTime endDate) async {
    int count = 0;

    for (final key in _lazyBox.keys) {
      final order = await _lazyBox.get(key);
      if (order?.orderAt != null &&
          order!.orderAt!.isAfter(startDate) &&
          order.orderAt!.isBefore(endDate)) {
        count++;
      }
    }

    return count;
  }

  /// Load orders from specific keys (used after filtering)
  Future<List<PastOrderModel>> loadOrdersFromKeys(List<String> keys) async {
    final orders = <PastOrderModel>[];

    for (final key in keys) {
      final order = await _lazyBox.get(key);
      if (order != null) {
        orders.add(order);
      }
    }

    return orders;
  }
}
