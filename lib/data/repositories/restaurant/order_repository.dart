import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/ordermodel_309.dart';
import '../../models/restaurant/db/cartmodel_308.dart';

/// Repository layer for Order data access (Restaurant)
/// Handles all Hive database operations for orders
/// Includes KOT management, bill numbering, and order tracking
class OrderRepository {
  late Box<OrderModel> _orderBox;
  late Box _counterBox;

  static const String _counterBoxName = 'appCounters';

  OrderRepository() {
    _orderBox = Hive.box<OrderModel>(HiveBoxNames.restaurantOrders);
    _counterBox = Hive.box(_counterBoxName);
  }

  // ==================== BASIC CRUD ====================

  /// Add an order to the database
  Future<void> addOrder(OrderModel order) async {
    await _orderBox.put(order.id, order);
  }

  /// Get all orders from the database
  Future<List<OrderModel>> getAllOrders() async {
    return _orderBox.values.toList();
  }

  /// Delete an order from the database
  Future<void> deleteOrder(String orderId) async {
    await _orderBox.delete(orderId);
  }

  /// Get an order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    return _orderBox.get(orderId);
  }

  /// Check if order exists
  Future<bool> orderExists(String orderId) async {
    return _orderBox.containsKey(orderId);
  }

  /// Update an existing order
  Future<void> updateOrder(OrderModel updatedOrder) async {
    dynamic orderKey;

    // Loop through the box to find the key of the order with a matching ID
    for (var key in _orderBox.keys) {
      final order = _orderBox.get(key) as OrderModel?;
      if (order?.id == updatedOrder.id) {
        orderKey = key;
        break;
      }
    }

    if (orderKey != null) {
      await _orderBox.put(orderKey, updatedOrder);
      print('✅ Order updated successfully with key: $orderKey');
    } else {
      print("❌ Error: Could not find order with ID ${updatedOrder.id} to update.");
      throw Exception('Order not found');
    }
  }

  // ==================== KOT MANAGEMENT ====================

  /// Get next KOT number
  Future<int> getNextKotNumber() async {
    int lastNumber = await _counterBox.get('lastKotNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await _counterBox.put('lastKotNumber', newNumber);
    return newNumber;
  }

  /// Get next daily bill number (resets every day)
  Future<int> getNextBillNumber() async {
    final lastBillDate = await _counterBox.get('lastBillDate');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // If it's a new day, reset the counter
    if (lastBillDate != todayStr) {
      await _counterBox.put('lastBillNumber', 0);
      await _counterBox.put('lastBillDate', todayStr);
    }

    // Get and increment the bill number
    int lastNumber = await _counterBox.get('lastBillNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await _counterBox.put('lastBillNumber', newNumber);

    return newNumber;
  }

  /// Reset daily bill number (called at end of day)
  Future<void> resetDailyBillNumber() async {
    await _counterBox.put('lastBillNumber', 0);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _counterBox.put('lastBillDate', todayStr);
    print('✅ Daily bill number reset to 0');
  }

  /// Get next daily order number (resets every day)
  Future<int> getNextOrderNumber() async {
    final lastOrderDate = await _counterBox.get('lastOrderDate');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // If it's a new day, reset the counter
    if (lastOrderDate != todayStr) {
      await _counterBox.put('lastOrderNumber', 0);
      await _counterBox.put('lastOrderDate', todayStr);
      print('🔄 New day detected - Order number reset to 0');
    }

    // Get and increment the order number
    int lastNumber = await _counterBox.get('lastOrderNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await _counterBox.put('lastOrderNumber', newNumber);

    print('📋 Order Number Generated: #$newNumber');
    return newNumber;
  }

  /// Reset daily order number (called at end of day)
  Future<void> resetDailyOrderNumber() async {
    await _counterBox.put('lastOrderNumber', 0);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _counterBox.put('lastOrderDate', todayStr);
    print('✅ Daily order number reset to 0');
  }

  /// Update order with new items added (e.g., adding items to existing order)
  /// Automatically handles KOT generation and status reset
  Future<OrderModel> updateOrderWithNewItems({
    required OrderModel existingOrder,
    required List<CartItem> newItems,
  }) async {
    // Check if we need to reset status (order was Ready or Served)
    bool needsStatusReset =
        existingOrder.status == 'Ready' || existingOrder.status == 'Served';

    // Generate new KOT number for the additional items
    final newKotNumber = await getNextKotNumber();

    // Combine existing and new items
    final combinedItems = [...existingOrder.items, ...newItems];

    // Update KOT tracking
    final updatedKotNumbers = [...existingOrder.kotNumbers, newKotNumber];
    final updatedBoundaries = [
      ...existingOrder.kotBoundaries,
      combinedItems.length
    ];

    // Create updated order
    final updatedOrder = existingOrder.copyWith(
      items: combinedItems,
      status: needsStatusReset ? 'Processing' : existingOrder.status,
      kotNumbers: updatedKotNumbers,
      itemCountAtLastKot: combinedItems.length,
      kotBoundaries: updatedBoundaries,
    );

    // Save to database
    await updateOrder(updatedOrder);

    print('✅ Order ${existingOrder.id} updated with ${newItems.length} new items');
    print('   New KOT #$newKotNumber generated');
    print('   Status: ${existingOrder.status} → ${updatedOrder.status}');

    return updatedOrder;
  }

  // ==================== QUERY METHODS ====================

  /// Get active order by table ID
  Future<OrderModel?> getActiveOrderByTableId(String tableId) async {
    final allOrders = await getAllOrders();

    try {
      final order = allOrders.firstWhere(
        (order) =>
            order.tableNo == tableId &&
            (order.status == 'Processing' || order.status == 'Cooking'),
      );
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Get orders by status
  Future<List<OrderModel>> getOrdersByStatus(String status) async {
    return _orderBox.values
        .where((order) => order.status == status)
        .toList();
  }

  /// Get orders by order type (Dine-in, Takeaway, Delivery)
  Future<List<OrderModel>> getOrdersByType(String orderType) async {
    return _orderBox.values
        .where((order) => order.orderType == orderType)
        .toList();
  }

  /// Get orders by table number
  Future<List<OrderModel>> getOrdersByTableNo(String tableNo) async {
    return _orderBox.values
        .where((order) => order.tableNo == tableNo)
        .toList();
  }

  /// Get orders by customer ID
  Future<List<OrderModel>> getOrdersByCustomerId(String customerId) async {
    return _orderBox.values
        .where((order) => order.customerId == customerId)
        .toList();
  }

  /// Get orders by date range
  Future<List<OrderModel>> getOrdersByDateRange(
      DateTime startDate, DateTime endDate) async {
    return _orderBox.values
        .where((order) =>
            order.timeStamp.isAfter(startDate) &&
            order.timeStamp.isBefore(endDate))
        .toList();
  }

  /// Get today's orders
  Future<List<OrderModel>> getTodaysOrders() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getOrdersByDateRange(startOfDay, endOfDay);
  }

  /// Get paid orders
  Future<List<OrderModel>> getPaidOrders() async {
    return _orderBox.values
        .where((order) => order.isPaid == true)
        .toList();
  }

  /// Get unpaid orders
  Future<List<OrderModel>> getUnpaidOrders() async {
    return _orderBox.values
        .where((order) => order.isPaid != true)
        .toList();
  }

  /// Get completed orders (Completed or Paid status)
  Future<List<OrderModel>> getCompletedOrders() async {
    return _orderBox.values
        .where((order) =>
            order.status == 'Completed' ||
            order.status == 'Paid' ||
            order.isPaid == true)
        .toList();
  }

  /// Get active orders (Processing, Cooking, Ready, Served)
  Future<List<OrderModel>> getActiveOrders() async {
    return _orderBox.values
        .where((order) =>
            order.status == 'Processing' ||
            order.status == 'Cooking' ||
            order.status == 'Ready' ||
            order.status == 'Served')
        .toList();
  }

  // ==================== STATUS MANAGEMENT ====================

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final order = await getOrderById(orderId);
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
    final order = await getOrderById(orderId);
    if (order != null) {
      final updatedOrder = order.copyWith(
        isPaid: true,
        paymentStatus: 'Paid',
        status: 'Completed',
        paymentMethod: paymentMethod ?? order.paymentMethod,
        completedAt: completedAt ?? DateTime.now(),
      );
      await updateOrder(updatedOrder);
    }
  }

  /// Update KOT status for a specific KOT number
  Future<void> updateKotStatus(
      String orderId, int kotNumber, String newStatus) async {
    final order = await getOrderById(orderId);
    if (order != null) {
      final updatedKotStatuses = Map<int, String>.from(order.kotStatuses ?? {});
      updatedKotStatuses[kotNumber] = newStatus;

      final updatedOrder = order.copyWith(kotStatuses: updatedKotStatuses);
      await updateOrder(updatedOrder);
    }
  }

  // ==================== STATISTICS ====================

  /// Get order count
  Future<int> getOrderCount() async {
    return _orderBox.length;
  }

  /// Get today's order count
  Future<int> getTodaysOrderCount() async {
    final todaysOrders = await getTodaysOrders();
    return todaysOrders.length;
  }

  /// Get total revenue from orders
  Future<double> getTotalRevenue() async {
    final orders = await getAllOrders();
    return orders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
  }

  /// Get today's revenue
  Future<double> getTodaysRevenue() async {
    final todaysOrders = await getTodaysOrders();
    return todaysOrders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
  }

  /// Get revenue by date range
  Future<double> getRevenueByDateRange(
      DateTime startDate, DateTime endDate) async {
    final orders = await getOrdersByDateRange(startDate, endDate);
    return orders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
  }

  /// Get order count by status
  Future<Map<String, int>> getOrderCountByStatus() async {
    final orders = await getAllOrders();
    final Map<String, int> statusCount = {};

    for (var order in orders) {
      statusCount[order.status] = (statusCount[order.status] ?? 0) + 1;
    }

    return statusCount;
  }

  /// Get order count by type
  Future<Map<String, int>> getOrderCountByType() async {
    final orders = await getAllOrders();
    final Map<String, int> typeCount = {};

    for (var order in orders) {
      typeCount[order.orderType] = (typeCount[order.orderType] ?? 0) + 1;
    }

    return typeCount;
  }

  /// Get average order value
  Future<double> getAverageOrderValue() async {
    final orders = await getAllOrders();
    if (orders.isEmpty) return 0.0;

    final totalRevenue = orders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
    return totalRevenue / orders.length;
  }

  // ==================== SEARCH ====================

  /// Search orders by customer name or number
  Future<List<OrderModel>> searchOrders(String query) async {
    if (query.isEmpty) {
      return getAllOrders();
    }

    final lowercaseQuery = query.toLowerCase();
    return _orderBox.values
        .where((order) =>
            order.customerName.toLowerCase().contains(lowercaseQuery) ||
            order.customerNumber.contains(query))
        .toList();
  }

  // ==================== PAYMENT METHODS ====================

  /// Get orders by payment method
  Future<List<OrderModel>> getOrdersByPaymentMethod(
      String paymentMethod) async {
    return _orderBox.values
        .where((order) => order.paymentMethod == paymentMethod)
        .toList();
  }

  /// Get revenue by payment method
  Future<Map<String, double>> getRevenueByPaymentMethod() async {
    final orders = await getAllOrders();
    final Map<String, double> revenueByMethod = {};

    for (var order in orders) {
      if (order.paymentMethod != null) {
        revenueByMethod[order.paymentMethod!] =
            (revenueByMethod[order.paymentMethod!] ?? 0.0) + order.totalPrice;
      }
    }

    return revenueByMethod;
  }

  // ==================== BULK OPERATIONS ====================

  /// Delete all orders (use with caution!)
  Future<void> deleteAllOrders() async {
    await _orderBox.clear();
  }

  /// Delete orders by date range
  Future<void> deleteOrdersByDateRange(
      DateTime startDate, DateTime endDate) async {
    final ordersToDelete = await getOrdersByDateRange(startDate, endDate);
    for (var order in ordersToDelete) {
      await deleteOrder(order.id);
    }
  }

  /// Bulk update order status
  Future<void> bulkUpdateOrderStatus(
      List<String> orderIds, String newStatus) async {
    for (var orderId in orderIds) {
      await updateOrderStatus(orderId, newStatus);
    }
  }
}