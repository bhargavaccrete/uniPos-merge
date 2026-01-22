import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../data/repositories/restaurant/past_order_repository.dart';
import '../../services/restaurant/refund_service.dart';

part 'past_order_store.g.dart';

class PastOrderStore = _PastOrderStore with _$PastOrderStore;

abstract class _PastOrderStore with Store {
  final PastOrderRepository _repository;

  _PastOrderStore(this._repository);

  @observable
  ObservableList<pastOrderModel> pastOrders = ObservableList<pastOrderModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedOrderType;

  @observable
  DateTime? startDate;

  @observable
  DateTime? endDate;

  // Computed properties
  @computed
  List<pastOrderModel> get filteredPastOrders {
    var result = pastOrders.toList();

    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result
          .where((order) => order.customerName.toLowerCase().contains(lowercaseQuery))
          .toList();
    }

    if (selectedOrderType != null && selectedOrderType!.isNotEmpty) {
      result = result.where((order) => order.orderType == selectedOrderType).toList();
    }

    if (startDate != null && endDate != null) {
      result = result
          .where((order) =>
              order.orderAt!.isAfter(startDate!) && order.orderAt!.isBefore(endDate!))
          .toList();
    }

    return result;
  }

  @computed
  double get totalRevenue =>
      pastOrders.fold<double>(0.0, (double sum, order) => sum + order.totalPrice);

  @computed
  int get totalOrderCount => pastOrders.length;

  @computed
  double get averageOrderValue =>
      totalOrderCount > 0 ? totalRevenue / totalOrderCount : 0.0;

  // Actions
  @action
  Future<void> loadPastOrders() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedOrders = await _repository.getAllPastOrders();
      pastOrders = ObservableList.of(loadedOrders);
    } catch (e) {
      errorMessage = 'Failed to load past orders: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadPastOrders();
  }

  @action
  Future<bool> addOrder(pastOrderModel pastOrder) async {
    try {
      await _repository.addOrder(pastOrder);
      pastOrders.add(pastOrder);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add past order: $e';
      return false;
    }
  }

  @action
  Future<pastOrderModel?> getOrderById(String orderId) async {
    try {
      return await _repository.getOrderById(orderId);
    } catch (e) {
      errorMessage = 'Failed to get past order: $e';
      return null;
    }
  }

  @action
  Future<bool> updateOrder(pastOrderModel updatedOrder) async {
    try {
      await _repository.updateOrder(updatedOrder);
      final index = pastOrders.indexWhere((o) => o.id == updatedOrder.id);
      if (index != -1) {
        pastOrders[index] = updatedOrder;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update past order: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteOrder(String orderId) async {
    try {
      await _repository.deleteOrder(orderId);
      pastOrders.removeWhere((order) => order.id == orderId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete past order: $e';
      return false;
    }
  }

  @action
  Future<List<pastOrderModel>> getOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _repository.getOrdersByDateRange(startDate, endDate);
    } catch (e) {
      errorMessage = 'Failed to get orders by date range: $e';
      return [];
    }
  }

  @action
  Future<List<pastOrderModel>> getTodaysPastOrders() async {
    try {
      return await _repository.getTodaysPastOrders();
    } catch (e) {
      errorMessage = 'Failed to get todays past orders: $e';
      return [];
    }
  }

  @action
  Future<List<pastOrderModel>> getOrdersByType(String orderType) async {
    try {
      return await _repository.getOrdersByType(orderType);
    } catch (e) {
      errorMessage = 'Failed to get orders by type: $e';
      return [];
    }
  }

  @action
  Future<double> getTotalRevenue() async {
    try {
      return await _repository.getTotalRevenue();
    } catch (e) {
      errorMessage = 'Failed to get total revenue: $e';
      return 0.0;
    }
  }

  @action
  Future<double> getTodaysRevenue() async {
    try {
      return await _repository.getTodaysRevenue();
    } catch (e) {
      errorMessage = 'Failed to get todays revenue: $e';
      return 0.0;
    }
  }

  @action
  Future<List<pastOrderModel>> searchOrders(String query) async {
    try {
      return await _repository.searchOrders(query);
    } catch (e) {
      errorMessage = 'Failed to search orders: $e';
      return [];
    }
  }

  @action
  Future<bool> deleteAllOrders() async {
    try {
      await _repository.deleteAllOrders();
      pastOrders.clear();
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete all orders: $e';
      return false;
    }
  }

  @action
  Future<int> getOrderCount() async {
    try {
      return await _repository.getOrderCount();
    } catch (e) {
      errorMessage = 'Failed to get order count: $e';
      return 0;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void setOrderTypeFilter(String? orderType) {
    selectedOrderType = orderType;
  }

  @action
  void setDateRange(DateTime? start, DateTime? end) {
    startDate = start;
    endDate = end;
  }

  @action
  void clearFilters() {
    searchQuery = '';
    selectedOrderType = null;
    startDate = null;
    endDate = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  // ==================== REFUND OPERATIONS ====================
  // Business logic delegated to RefundService

  /// Process a refund for an order
  /// Handles both partial and full refunds with stock restoration
  @action
  Future<pastOrderModel?> processRefund({
    required pastOrderModel order,
    required PartialRefundResult refundResult,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Delegate to RefundService for business logic
      final updatedOrder = await RefundService.processRefund(
        order: order,
        refundResult: refundResult,
      );

      // Update local state
      final index = pastOrders.indexWhere((o) => o.id == updatedOrder.id);
      if (index != -1) {
        pastOrders[index] = updatedOrder;
      }

      return updatedOrder;
    } catch (e) {
      errorMessage = 'Failed to process refund: $e';
      print('❌ PastOrderStore: Error processing refund: $e');
      return null;
    } finally {
      isLoading = false;
    }
  }

  /// Validate if an order can be refunded
  /// Returns error message if not eligible, null if eligible
  String? validateRefundEligibility(pastOrderModel order) {
    return RefundService.validateRefundEligibility(order);
  }

  /// Get list of items that can be refunded from an order
  List<CartItem> getRefundableItems(pastOrderModel order) {
    return RefundService.getRefundableItems(order);
  }

  /// Calculate remaining amount that can be refunded
  double getRemainingRefundableAmount(pastOrderModel order) {
    return RefundService.getRemainingRefundableAmount(order);
  }

  /// Void an order (mark as cancelled/voided)
  @action
  Future<pastOrderModel?> voidOrder({
    required pastOrderModel order,
    required String reason,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Delegate to RefundService
      final voidedOrder = await RefundService.voidOrder(
        order: order,
        reason: reason,
      );

      // Update local state
      final index = pastOrders.indexWhere((o) => o.id == voidedOrder.id);
      if (index != -1) {
        pastOrders[index] = voidedOrder;
      }

      return voidedOrder;
    } catch (e) {
      errorMessage = 'Failed to void order: $e';
      print('❌ PastOrderStore: Error voiding order: $e');
      return null;
    } finally {
      isLoading = false;
    }
  }
}