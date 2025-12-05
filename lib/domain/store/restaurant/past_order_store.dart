import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../data/repositories/restaurant/past_order_repository.dart';

part 'past_order_store.g.dart';

class PastOrderStore = _PastOrderStore with _$PastOrderStore;

abstract class _PastOrderStore with Store {
  final PastOrderRepository _pastOrderRepository = locator<PastOrderRepository>();

  final ObservableList<pastOrderModel> pastOrders = ObservableList<pastOrderModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  DateTime? filterStartDate;

  @observable
  DateTime? filterEndDate;

  _PastOrderStore() {
    _init();
  }

  Future<void> _init() async {
    await loadPastOrders();
  }

  @computed
  List<pastOrderModel> get filteredOrders {
    if (filterStartDate == null && filterEndDate == null) {
      return pastOrders.toList();
    }
    return pastOrders.where((order) {
      if (order.orderAt == null) return false;
      if (filterStartDate != null && order.orderAt!.isBefore(filterStartDate!)) {
        return false;
      }
      if (filterEndDate != null && order.orderAt!.isAfter(filterEndDate!)) {
        return false;
      }
      return true;
    }).toList();
  }

  @computed
  List<pastOrderModel> get todaysOrders {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return pastOrders.where((order) =>
      order.orderAt != null && order.orderAt!.isAfter(startOfDay)
    ).toList();
  }

  @computed
  int get totalOrderCount => pastOrders.length;

  @computed
  double get totalSales {
    double total = 0;
    for (var order in pastOrders) {
      total += order.totalPrice;
    }
    return total;
  }

  @computed
  double get todaysSales {
    double total = 0;
    for (var order in todaysOrders) {
      total += order.totalPrice;
    }
    return total;
  }

  @action
  Future<void> loadPastOrders() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _pastOrderRepository.getAllPastOrders();
      pastOrders.clear();
      pastOrders.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load past orders: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addOrder(pastOrderModel order) async {
    try {
      await _pastOrderRepository.addOrder(order);
      pastOrders.add(order);
    } catch (e) {
      errorMessage = 'Failed to add order: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateOrder(pastOrderModel order) async {
    try {
      await _pastOrderRepository.updateOrder(order);
      final index = pastOrders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        pastOrders[index] = order;
      }
    } catch (e) {
      errorMessage = 'Failed to update order: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteOrder(String id) async {
    try {
      await _pastOrderRepository.deleteOrder(id);
      pastOrders.removeWhere((order) => order.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete order: $e';
      rethrow;
    }
  }

  @action
  void setDateFilter(DateTime? start, DateTime? end) {
    filterStartDate = start;
    filterEndDate = end;
  }

  @action
  void clearDateFilter() {
    filterStartDate = null;
    filterEndDate = null;
  }

  pastOrderModel? getOrderById(String id) {
    try {
      return pastOrders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }
}