import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/repositories/restaurant/order_repository.dart';

part 'order_store.g.dart';

class OrderStore = _OrderStore with _$OrderStore;

abstract class _OrderStore with Store {
  final OrderRepository _orderRepository = locator<OrderRepository>();

  final ObservableList<OrderModel> orders = ObservableList<OrderModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? selectedStatus;

  @observable
  String? selectedOrderType;

  _OrderStore() {
    _init();
  }

  Future<void> _init() async {
    await loadOrders();
  }

  // ==================== COMPUTED ====================

  @computed
  List<OrderModel> get filteredOrders {
    var result = orders.toList();

    if (selectedStatus != null && selectedStatus!.isNotEmpty) {
      result = result.where((order) => order.status == selectedStatus).toList();
    }

    if (selectedOrderType != null && selectedOrderType!.isNotEmpty) {
      result = result
          .where((order) => order.orderType == selectedOrderType)
          .toList();
    }

    return result;
  }

  @computed
  List<OrderModel> get processingOrders {
    return orders
        .where((order) =>
            order.status == 'Processing' || order.status == 'Cooking')
        .toList();
  }

  @computed
  List<OrderModel> get completedOrders {
    return orders.where((order) => order.status == 'Completed').toList();
  }

  @computed
  List<OrderModel> get todaysOrders {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return orders.where((order) => order.timeStamp.isAfter(startOfDay)).toList();
  }

  @computed
  int get totalOrderCount => orders.length;

  @computed
  int get processingOrderCount => processingOrders.length;

  @computed
  double get todaysSalesTotal {
    double total = 0.0;
    for (var order in todaysOrders) {
      if (order.isPaid == true) {
        total += order.totalPrice;
      }
    }
    return total;
  }

  // ==================== ACTIONS ====================

  @action
  Future<void> loadOrders() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loadedOrders = _orderRepository.getAllOrders();
      orders.clear();
      orders.addAll(loadedOrders);
    } catch (e) {
      errorMessage = 'Failed to load orders: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addOrder(OrderModel order) async {
    try {
      await _orderRepository.addOrder(order);
      orders.add(order);
    } catch (e) {
      errorMessage = 'Failed to add order: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateOrder(OrderModel order) async {
    try {
      await _orderRepository.updateOrder(order);
      final index = orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        orders[index] = order;
      }
    } catch (e) {
      errorMessage = 'Failed to update order: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteOrder(String id) async {
    try {
      await _orderRepository.deleteOrder(id);
      orders.removeWhere((order) => order.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete order: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _orderRepository.updateOrderStatus(orderId, newStatus);
      final index = orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        orders[index] = orders[index].copyWith(status: newStatus);
      }
    } catch (e) {
      errorMessage = 'Failed to update order status: $e';
      rethrow;
    }
  }

  @action
  Future<void> markOrderAsPaid(
    String orderId, {
    String? paymentMethod,
  }) async {
    try {
      await _orderRepository.markOrderAsPaid(
        orderId,
        paymentMethod: paymentMethod,
      );
      final index = orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        orders[index] = orders[index].copyWith(
          isPaid: true,
          paymentStatus: 'Paid',
          paymentMethod: paymentMethod,
          completedAt: DateTime.now(),
          status: 'Completed',
        );
      }
    } catch (e) {
      errorMessage = 'Failed to mark order as paid: $e';
      rethrow;
    }
  }

  @action
  void setStatusFilter(String? status) {
    selectedStatus = status;
  }

  @action
  void setOrderTypeFilter(String? orderType) {
    selectedOrderType = orderType;
  }

  @action
  void clearFilters() {
    selectedStatus = null;
    selectedOrderType = null;
  }

  @action
  Future<int> getNextKotNumber() async {
    return await _orderRepository.getNextKotNumber();
  }

  // ==================== HELPERS ====================

  OrderModel? getOrderById(String id) {
    try {
      return orders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }

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

  List<OrderModel> getOrdersByDateRange(DateTime start, DateTime end) {
    return orders.where((order) {
      return order.timeStamp.isAfter(start) && order.timeStamp.isBefore(end);
    }).toList();
  }
}