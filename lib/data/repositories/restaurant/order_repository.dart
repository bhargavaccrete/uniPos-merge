import 'package:hive/hive.dart';

import '../../models/restaurant/db/ordermodel_309.dart';

/// Repository layer for Order data access
/// Handles all Hive database operations for orders
class OrderRepository {
  static const String _boxName = 'orderBox';
  static const String _counterBoxName = 'appCounters';
  late Box<OrderModel> _orderBox;

  OrderRepository() {
    _orderBox = Hive.box<OrderModel>(_boxName);
  }

  /// Get all orders
  List<OrderModel> getAllOrders() {
    return _orderBox.values.toList();
  }

  /// Add an order
  Future<void> addOrder(OrderModel order) async {
    await _orderBox.put(order.id, order);
  }

  /// Update an existing order
  Future<void> updateOrder(OrderModel updatedOrder) async {
    dynamic orderKey;

    for (var key in _orderBox.keys) {
      final order = _orderBox.get(key);
      if (order?.id == updatedOrder.id) {
        orderKey = key;
        break;
      }
    }

    if (orderKey != null) {
      await _orderBox.put(orderKey, updatedOrder);
    }
  }

  /// Delete an order by id
  Future<void> deleteOrder(String id) async {
    await _orderBox.delete(id);
  }

  /// Get order by id
  OrderModel? getOrderById(String id) {
    return _orderBox.get(id);
  }

  /// Get next KOT number
  Future<int> getNextKotNumber() async {
    final counterBox = await Hive.openBox(_counterBoxName);
    int lastNumber = await counterBox.get('lastKotNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await counterBox.put('lastKotNumber', newNumber);
    return newNumber;
  }

  /// Get active order by table ID
  OrderModel? getActiveOrderByTableId(String tableId) {
    try {
      return _orderBox.values.firstWhere(
        (order) =>
            order.tableNo == tableId &&
            (order.status == 'Processing' || order.status == 'Cooking'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get orders by status
  List<OrderModel> getOrdersByStatus(String status) {
    return _orderBox.values.where((order) => order.status == status).toList();
  }

  /// Get orders by order type
  List<OrderModel> getOrdersByType(String orderType) {
    return _orderBox.values
        .where((order) => order.orderType == orderType)
        .toList();
  }

  /// Get processing orders
  List<OrderModel> getProcessingOrders() {
    return _orderBox.values
        .where((order) =>
            order.status == 'Processing' || order.status == 'Cooking')
        .toList();
  }

  /// Get completed orders
  List<OrderModel> getCompletedOrders() {
    return _orderBox.values
        .where((order) => order.status == 'Completed')
        .toList();
  }

  /// Get orders for a specific date range
  List<OrderModel> getOrdersByDateRange(DateTime start, DateTime end) {
    return _orderBox.values.where((order) {
      return order.timeStamp.isAfter(start) && order.timeStamp.isBefore(end);
    }).toList();
  }

  /// Get today's orders
  List<OrderModel> getTodaysOrders() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getOrdersByDateRange(startOfDay, endOfDay);
  }

  /// Get order count
  int getOrderCount() {
    return _orderBox.length;
  }

  /// Clear all orders
  Future<void> clearAll() async {
    await _orderBox.clear();
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final order = getOrderById(orderId);
    if (order != null) {
      final updatedOrder = order.copyWith(status: newStatus);
      await updateOrder(updatedOrder);
    }
  }

  /// Mark order as paid
  Future<void> markOrderAsPaid(
    String orderId, {
    String? paymentMethod,
    DateTime? completedAt,
  }) async {
    final order = getOrderById(orderId);
    if (order != null) {
      final updatedOrder = order.copyWith(
        isPaid: true,
        paymentStatus: 'Paid',
        paymentMethod: paymentMethod,
        completedAt: completedAt ?? DateTime.now(),
        status: 'Completed',
      );
      await updateOrder(updatedOrder);
    }
  }
}