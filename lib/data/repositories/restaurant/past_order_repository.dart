import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/pastordermodel_313.dart';

/// Repository layer for Past Order data access (Restaurant)
/// Handles all Hive database operations for past/completed orders
class PastOrderRepository {
  late Box<pastOrderModel> _pastOrderBox;

  PastOrderRepository() {
    _pastOrderBox = Hive.box<pastOrderModel>(HiveBoxNames.restaurantPastOrders);
  }

  /// Get all past orders
  Future<List<pastOrderModel>> getAllPastOrders() async {
    return _pastOrderBox.values.toList();
  }

  /// Add a new past order
  Future<void> addOrder(pastOrderModel pastOrder) async {
    await _pastOrderBox.put(pastOrder.id, pastOrder);
  }

  /// Get past order by ID
  Future<pastOrderModel?> getOrderById(String orderId) async {
    return _pastOrderBox.get(orderId);
  }

  /// Update past order
  Future<void> updateOrder(pastOrderModel updatedOrder) async {
    await _pastOrderBox.put(updatedOrder.id, updatedOrder);
  }

  /// Delete past order
  Future<void> deleteOrder(String orderId) async {
    await _pastOrderBox.delete(orderId);
  }

  /// Get past orders by date range
  Future<List<pastOrderModel>> getOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _pastOrderBox.values
        .where((order) =>
            order.orderAt!.isAfter(startDate) &&
            order.orderAt!.isBefore(endDate))
        .toList();
  }

  /// Get today's past orders
  Future<List<pastOrderModel>> getTodaysPastOrders() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getOrdersByDateRange(startOfDay, endOfDay);
  }

  /// Get past orders by order type
  Future<List<pastOrderModel>> getOrdersByType(String orderType) async {
    return _pastOrderBox.values
        .where((order) => order.orderType == orderType)
        .toList();
  }

  /// Get revenue from past orders
  Future<double> getTotalRevenue() async {
    final orders = await getAllPastOrders();
    return orders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
  }

  /// Get today's revenue
  Future<double> getTodaysRevenue() async {
    final todaysOrders = await getTodaysPastOrders();
    return todaysOrders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
  }

  /// Search past orders by customer name
  Future<List<pastOrderModel>> searchOrders(String query) async {
    if (query.isEmpty) {
      return getAllPastOrders();
    }

    final lowercaseQuery = query.toLowerCase();
    return _pastOrderBox.values
        .where((order) => order.customerName.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Delete all past orders (use with caution!)
  Future<void> deleteAllOrders() async {
    await _pastOrderBox.clear();
  }

  /// Get past order count
  Future<int> getOrderCount() async {
    return _pastOrderBox.length;
  }
}