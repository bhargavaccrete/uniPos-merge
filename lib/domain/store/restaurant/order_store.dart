import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/repositories/restaurant/order_repository.dart';

part 'order_store.g.dart';

class OrderStore = _OrderStore with _$OrderStore;

abstract class _OrderStore with Store {
  final OrderRepository _repository;

  _OrderStore(this._repository) {
    // Load orders on initialization
    loadOrders();
  }

  // ==================== OBSERVABLES ====================

  @observable
  ObservableList<OrderModel> orders = ObservableList<OrderModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedStatus; // Filter by status

  @observable
  String? selectedOrderType; // Filter by order type (Dine-in, Takeaway, Delivery)

  @observable
  String? selectedTableNo; // Filter by table number

  @observable
  bool showTodayOnly = false;

  @observable
  bool showPaidOnly = false;

  @observable
  bool showUnpaidOnly = false;

  @observable
  DateTime? filterStartDate;

  @observable
  DateTime? filterEndDate;

  // ==================== COMPUTED ====================

  @computed
  List<OrderModel> get filteredOrders {
    var result = orders.toList();

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result
          .where((order) =>
              order.customerName.toLowerCase().contains(lowercaseQuery) ||
              order.customerNumber.contains(searchQuery) ||
              (order.orderNumber?.toString().contains(searchQuery) ?? false))
          .toList();
    }

    // Apply status filter
    if (selectedStatus != null) {
      result = result.where((order) => order.status == selectedStatus).toList();
    }

    // Apply order type filter
    if (selectedOrderType != null) {
      result = result
          .where((order) => order.orderType == selectedOrderType)
          .toList();
    }

    // Apply table filter
    if (selectedTableNo != null) {
      result =
          result.where((order) => order.tableNo == selectedTableNo).toList();
    }

    // Apply today filter
    if (showTodayOnly) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      result = result
          .where((order) =>
              order.timeStamp.isAfter(startOfDay) &&
              order.timeStamp.isBefore(endOfDay))
          .toList();
    }

    // Apply date range filter
    if (filterStartDate != null && filterEndDate != null) {
      result = result
          .where((order) =>
              order.timeStamp.isAfter(filterStartDate!) &&
              order.timeStamp.isBefore(filterEndDate!))
          .toList();
    }

    // Apply paid/unpaid filter
    if (showPaidOnly) {
      result = result.where((order) => order.isPaid == true).toList();
    } else if (showUnpaidOnly) {
      result = result.where((order) => order.isPaid != true).toList();
    }

    // Sort by timestamp (newest first)
    result.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));

    return result;
  }

  @computed
  int get orderCount => orders.length;

  @computed
  int get filteredOrderCount => filteredOrders.length;

  @computed
  bool get hasOrders => orders.isNotEmpty;

  @computed
  List<OrderModel> get activeOrders => orders
      .where((order) =>
          order.status == 'Processing' ||
          order.status == 'Cooking' ||
          order.status == 'Ready' ||
          order.status == 'Served')
      .toList();

  @computed
  List<OrderModel> get completedOrders => orders
      .where((order) =>
          order.status == 'Completed' ||
          order.status == 'Paid' ||
          order.isPaid == true)
      .toList();

  @computed
  List<OrderModel> get processingOrders =>
      orders.where((order) => order.status == 'Processing').toList();

  @computed
  List<OrderModel> get cookingOrders =>
      orders.where((order) => order.status == 'Cooking').toList();

  @computed
  List<OrderModel> get readyOrders =>
      orders.where((order) => order.status == 'Ready').toList();

  @computed
  List<OrderModel> get servedOrders =>
      orders.where((order) => order.status == 'Served').toList();

  @computed
  List<OrderModel> get paidOrders =>
      orders.where((order) => order.isPaid == true).toList();

  @computed
  List<OrderModel> get unpaidOrders =>
      orders.where((order) => order.isPaid != true).toList();

  @computed
  List<OrderModel> get todaysOrders {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return orders
        .where((order) =>
            order.timeStamp.isAfter(startOfDay) &&
            order.timeStamp.isBefore(endOfDay))
        .toList();
  }

  @computed
  int get activeOrderCount => activeOrders.length;

  @computed
  int get completedOrderCount => completedOrders.length;

  @computed
  int get todaysOrderCount => todaysOrders.length;

  @computed
  double get totalRevenue =>
      orders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);

  @computed
  double get todaysRevenue =>
      todaysOrders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);

  @computed
  double get averageOrderValue {
    if (orders.isEmpty) return 0.0;
    return totalRevenue / orders.length;
  }

  @computed
  Map<String, int> get orderCountByStatus {
    final Map<String, int> statusCount = {};
    for (var order in orders) {
      statusCount[order.status] = (statusCount[order.status] ?? 0) + 1;
    }
    return statusCount;
  }

  @computed
  Map<String, int> get orderCountByType {
    final Map<String, int> typeCount = {};
    for (var order in orders) {
      typeCount[order.orderType] = (typeCount[order.orderType] ?? 0) + 1;
    }
    return typeCount;
  }

  // ==================== ACTIONS ====================

  @action
  Future<void> loadOrders() async {
    try {
      isLoading = true;
      errorMessage = null;

      final loadedOrders = await _repository.getAllOrders();
      orders.clear();
      orders.addAll(loadedOrders);
    } catch (e) {
      errorMessage = 'Failed to load orders: $e';
      print('Error loading orders: $e');
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> addOrder(OrderModel order) async {
    try {
      isLoading = true;
      errorMessage = null;

      await _repository.addOrder(order);
      orders.add(order);

      return true;
    } catch (e) {
      errorMessage = 'Failed to add order: $e';
      print('Error adding order: $e');
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateOrder(OrderModel order) async {
    try {
      isLoading = true;
      errorMessage = null;

      await _repository.updateOrder(order);

      // Update in local list
      final index = orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        orders[index] = order;
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update order: $e';
      print('Error updating order: $e');
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> deleteOrder(String orderId) async {
    try {
      isLoading = true;
      errorMessage = null;

      await _repository.deleteOrder(orderId);

      // Remove from local list
      orders.removeWhere((o) => o.id == orderId);

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete order: $e';
      print('Error deleting order: $e');
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _repository.updateOrderStatus(orderId, newStatus);

      // Update in local list
      final index = orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        orders[index] = orders[index].copyWith(status: newStatus);
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update order status: $e';
      print('Error updating order status: $e');
      return false;
    }
  }

  @action
  Future<bool> markOrderAsPaid(
    String orderId, {
    String? paymentMethod,
    DateTime? completedAt,
  }) async {
    try {
      await _repository.markOrderAsPaid(
        orderId,
        paymentMethod: paymentMethod,
        completedAt: completedAt,
      );

      // Update in local list
      final index = orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        orders[index] = orders[index].copyWith(
          isPaid: true,
          paymentStatus: 'Paid',
          status: 'Completed',
          paymentMethod: paymentMethod ?? orders[index].paymentMethod,
          completedAt: completedAt ?? DateTime.now(),
        );
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to mark order as paid: $e';
      print('Error marking order as paid: $e');
      return false;
    }
  }

  @action
  Future<OrderModel?> updateOrderWithNewItems({
    required OrderModel existingOrder,
    required List<CartItem> newItems,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;

      final updatedOrder = await _repository.updateOrderWithNewItems(
        existingOrder: existingOrder,
        newItems: newItems,
      );

      // Update in local list
      final index = orders.indexWhere((o) => o.id == existingOrder.id);
      if (index != -1) {
        orders[index] = updatedOrder;
      }

      return updatedOrder;
    } catch (e) {
      errorMessage = 'Failed to update order with new items: $e';
      print('Error updating order with new items: $e');
      return null;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<int> getNextKotNumber() async {
    try {
      return await _repository.getNextKotNumber();
    } catch (e) {
      errorMessage = 'Failed to get next KOT number: $e';
      print('Error getting next KOT number: $e');
      return 0;
    }
  }

  @action
  Future<int> getNextBillNumber() async {
    try {
      return await _repository.getNextBillNumber();
    } catch (e) {
      errorMessage = 'Failed to get next bill number: $e';
      print('Error getting next bill number: $e');
      return 0;
    }
  }

  @action
  Future<int> getNextOrderNumber() async {
    try {
      return await _repository.getNextOrderNumber();
    } catch (e) {
      errorMessage = 'Failed to get next order number: $e';
      print('Error getting next order number: $e');
      return 0;
    }
  }

  @action
  Future<bool> updateKotStatus(
      String orderId, int kotNumber, String newStatus) async {
    try {
      await _repository.updateKotStatus(orderId, kotNumber, newStatus);

      // Update in local list
      final index = orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        final order = orders[index];
        final updatedKotStatuses =
            Map<int, String>.from(order.kotStatuses ?? {});
        updatedKotStatuses[kotNumber] = newStatus;
        orders[index] = order.copyWith(kotStatuses: updatedKotStatuses);
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update KOT status: $e';
      print('Error updating KOT status: $e');
      return false;
    }
  }

  // ==================== FILTER ACTIONS ====================

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearSearch() {
    searchQuery = '';
  }

  @action
  void setStatusFilter(String? status) {
    selectedStatus = status;
  }

  @action
  void clearStatusFilter() {
    selectedStatus = null;
  }

  @action
  void setOrderTypeFilter(String? orderType) {
    selectedOrderType = orderType;
  }

  @action
  void clearOrderTypeFilter() {
    selectedOrderType = null;
  }

  @action
  void setTableFilter(String? tableNo) {
    selectedTableNo = tableNo;
  }

  @action
  void clearTableFilter() {
    selectedTableNo = null;
  }

  @action
  void toggleTodayFilter() {
    showTodayOnly = !showTodayOnly;
  }

  @action
  void togglePaidFilter() {
    showPaidOnly = !showPaidOnly;
    if (showPaidOnly) {
      showUnpaidOnly = false;
    }
  }

  @action
  void toggleUnpaidFilter() {
    showUnpaidOnly = !showUnpaidOnly;
    if (showUnpaidOnly) {
      showPaidOnly = false;
    }
  }

  @action
  void setDateRangeFilter(DateTime? startDate, DateTime? endDate) {
    filterStartDate = startDate;
    filterEndDate = endDate;
  }

  @action
  void clearDateRangeFilter() {
    filterStartDate = null;
    filterEndDate = null;
  }

  @action
  void clearAllFilters() {
    searchQuery = '';
    selectedStatus = null;
    selectedOrderType = null;
    selectedTableNo = null;
    showTodayOnly = false;
    showPaidOnly = false;
    showUnpaidOnly = false;
    filterStartDate = null;
    filterEndDate = null;
  }

  // ==================== HELPER METHODS ====================

  /// Get order by ID
  OrderModel? getOrderById(String orderId) {
    try {
      return orders.firstWhere((o) => o.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Get active order by table ID
  OrderModel? getActiveOrderByTableId(String tableId) {
    try {
      return orders.firstWhere(
        (order) =>
            order.tableNo == tableId &&
            (order.status == 'Processing' || order.status == 'Cooking'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get orders by table number
  List<OrderModel> getOrdersByTableNo(String tableNo) {
    return orders.where((order) => order.tableNo == tableNo).toList();
  }

  /// Get orders by customer ID
  List<OrderModel> getOrdersByCustomerId(String customerId) {
    return orders.where((order) => order.customerId == customerId).toList();
  }

  /// Check if order exists
  bool orderExists(String orderId) {
    return orders.any((o) => o.id == orderId);
  }

  /// Refresh orders (pull from database)
  @action
  Future<void> refresh() async {
    await loadOrders();
  }

  /// Get revenue for specific date range
  double getRevenueForDateRange(DateTime startDate, DateTime endDate) {
    final ordersInRange = orders
        .where((order) =>
            order.timeStamp.isAfter(startDate) &&
            order.timeStamp.isBefore(endDate))
        .toList();
    return ordersInRange.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);
  }

  /// Get orders by payment method
  List<OrderModel> getOrdersByPaymentMethod(String paymentMethod) {
    return orders
        .where((order) => order.paymentMethod == paymentMethod)
        .toList();
  }
}