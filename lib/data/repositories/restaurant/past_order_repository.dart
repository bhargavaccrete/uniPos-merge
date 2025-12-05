import 'package:hive/hive.dart';

import '../../models/restaurant/db/pastordermodel_313.dart';

/// Repository layer for PastOrder data access
class PastOrderRepository {
  static const String _boxName = 'pastorderBox';
  late Box<pastOrderModel> _pastOrderBox;

  PastOrderRepository() {
    _pastOrderBox = Hive.box<pastOrderModel>(_boxName);
  }

  List<pastOrderModel> getAllPastOrders() {
    return _pastOrderBox.values.toList();
  }

  Future<void> addOrder(pastOrderModel order) async {
    await _pastOrderBox.put(order.id, order);
  }

  Future<void> updateOrder(pastOrderModel order) async {
    await _pastOrderBox.put(order.id, order);
  }

  Future<void> deleteOrder(String id) async {
    await _pastOrderBox.delete(id);
  }

  pastOrderModel? getOrderById(String id) {
    return _pastOrderBox.get(id);
  }

  List<pastOrderModel> getOrdersByDateRange(DateTime start, DateTime end) {
    return _pastOrderBox.values.where((order) {
      if (order.orderAt == null) return false;
      return order.orderAt!.isAfter(start) && order.orderAt!.isBefore(end);
    }).toList();
  }

  List<pastOrderModel> getTodaysOrders() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getOrdersByDateRange(startOfDay, endOfDay);
  }

  int getOrderCount() {
    return _pastOrderBox.length;
  }

  double getTotalSales() {
    double total = 0;
    for (var order in _pastOrderBox.values) {
      total += order.totalPrice;
    }
    return total;
  }

  Future<void> clearAll() async {
    await _pastOrderBox.clear();
  }
}