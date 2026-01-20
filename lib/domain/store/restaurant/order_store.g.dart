// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$OrderStore on _OrderStore, Store {
  Computed<List<OrderModel>>? _$filteredOrdersComputed;

  @override
  List<OrderModel> get filteredOrders => (_$filteredOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.filteredOrders,
              name: '_OrderStore.filteredOrders'))
      .value;
  Computed<int>? _$orderCountComputed;

  @override
  int get orderCount => (_$orderCountComputed ??=
          Computed<int>(() => super.orderCount, name: '_OrderStore.orderCount'))
      .value;
  Computed<int>? _$filteredOrderCountComputed;

  @override
  int get filteredOrderCount => (_$filteredOrderCountComputed ??= Computed<int>(
          () => super.filteredOrderCount,
          name: '_OrderStore.filteredOrderCount'))
      .value;
  Computed<bool>? _$hasOrdersComputed;

  @override
  bool get hasOrders => (_$hasOrdersComputed ??=
          Computed<bool>(() => super.hasOrders, name: '_OrderStore.hasOrders'))
      .value;
  Computed<List<OrderModel>>? _$activeOrdersComputed;

  @override
  List<OrderModel> get activeOrders => (_$activeOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.activeOrders,
              name: '_OrderStore.activeOrders'))
      .value;
  Computed<List<OrderModel>>? _$completedOrdersComputed;

  @override
  List<OrderModel> get completedOrders => (_$completedOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.completedOrders,
              name: '_OrderStore.completedOrders'))
      .value;
  Computed<List<OrderModel>>? _$processingOrdersComputed;

  @override
  List<OrderModel> get processingOrders => (_$processingOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.processingOrders,
              name: '_OrderStore.processingOrders'))
      .value;
  Computed<List<OrderModel>>? _$cookingOrdersComputed;

  @override
  List<OrderModel> get cookingOrders => (_$cookingOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.cookingOrders,
              name: '_OrderStore.cookingOrders'))
      .value;
  Computed<List<OrderModel>>? _$readyOrdersComputed;

  @override
  List<OrderModel> get readyOrders => (_$readyOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.readyOrders,
              name: '_OrderStore.readyOrders'))
      .value;
  Computed<List<OrderModel>>? _$servedOrdersComputed;

  @override
  List<OrderModel> get servedOrders => (_$servedOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.servedOrders,
              name: '_OrderStore.servedOrders'))
      .value;
  Computed<List<OrderModel>>? _$paidOrdersComputed;

  @override
  List<OrderModel> get paidOrders => (_$paidOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.paidOrders,
              name: '_OrderStore.paidOrders'))
      .value;
  Computed<List<OrderModel>>? _$unpaidOrdersComputed;

  @override
  List<OrderModel> get unpaidOrders => (_$unpaidOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.unpaidOrders,
              name: '_OrderStore.unpaidOrders'))
      .value;
  Computed<List<OrderModel>>? _$todaysOrdersComputed;

  @override
  List<OrderModel> get todaysOrders => (_$todaysOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.todaysOrders,
              name: '_OrderStore.todaysOrders'))
      .value;
  Computed<int>? _$activeOrderCountComputed;

  @override
  int get activeOrderCount => (_$activeOrderCountComputed ??= Computed<int>(
          () => super.activeOrderCount,
          name: '_OrderStore.activeOrderCount'))
      .value;
  Computed<int>? _$completedOrderCountComputed;

  @override
  int get completedOrderCount => (_$completedOrderCountComputed ??=
          Computed<int>(() => super.completedOrderCount,
              name: '_OrderStore.completedOrderCount'))
      .value;
  Computed<int>? _$todaysOrderCountComputed;

  @override
  int get todaysOrderCount => (_$todaysOrderCountComputed ??= Computed<int>(
          () => super.todaysOrderCount,
          name: '_OrderStore.todaysOrderCount'))
      .value;
  Computed<double>? _$totalRevenueComputed;

  @override
  double get totalRevenue =>
      (_$totalRevenueComputed ??= Computed<double>(() => super.totalRevenue,
              name: '_OrderStore.totalRevenue'))
          .value;
  Computed<double>? _$todaysRevenueComputed;

  @override
  double get todaysRevenue =>
      (_$todaysRevenueComputed ??= Computed<double>(() => super.todaysRevenue,
              name: '_OrderStore.todaysRevenue'))
          .value;
  Computed<double>? _$averageOrderValueComputed;

  @override
  double get averageOrderValue => (_$averageOrderValueComputed ??=
          Computed<double>(() => super.averageOrderValue,
              name: '_OrderStore.averageOrderValue'))
      .value;
  Computed<Map<String, int>>? _$orderCountByStatusComputed;

  @override
  Map<String, int> get orderCountByStatus => (_$orderCountByStatusComputed ??=
          Computed<Map<String, int>>(() => super.orderCountByStatus,
              name: '_OrderStore.orderCountByStatus'))
      .value;
  Computed<Map<String, int>>? _$orderCountByTypeComputed;

  @override
  Map<String, int> get orderCountByType => (_$orderCountByTypeComputed ??=
          Computed<Map<String, int>>(() => super.orderCountByType,
              name: '_OrderStore.orderCountByType'))
      .value;

  late final _$ordersAtom = Atom(name: '_OrderStore.orders', context: context);

  @override
  ObservableList<OrderModel> get orders {
    _$ordersAtom.reportRead();
    return super.orders;
  }

  @override
  set orders(ObservableList<OrderModel> value) {
    _$ordersAtom.reportWrite(value, super.orders, () {
      super.orders = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_OrderStore.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_OrderStore.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$searchQueryAtom =
      Atom(name: '_OrderStore.searchQuery', context: context);

  @override
  String get searchQuery {
    _$searchQueryAtom.reportRead();
    return super.searchQuery;
  }

  @override
  set searchQuery(String value) {
    _$searchQueryAtom.reportWrite(value, super.searchQuery, () {
      super.searchQuery = value;
    });
  }

  late final _$selectedStatusAtom =
      Atom(name: '_OrderStore.selectedStatus', context: context);

  @override
  String? get selectedStatus {
    _$selectedStatusAtom.reportRead();
    return super.selectedStatus;
  }

  @override
  set selectedStatus(String? value) {
    _$selectedStatusAtom.reportWrite(value, super.selectedStatus, () {
      super.selectedStatus = value;
    });
  }

  late final _$selectedOrderTypeAtom =
      Atom(name: '_OrderStore.selectedOrderType', context: context);

  @override
  String? get selectedOrderType {
    _$selectedOrderTypeAtom.reportRead();
    return super.selectedOrderType;
  }

  @override
  set selectedOrderType(String? value) {
    _$selectedOrderTypeAtom.reportWrite(value, super.selectedOrderType, () {
      super.selectedOrderType = value;
    });
  }

  late final _$selectedTableNoAtom =
      Atom(name: '_OrderStore.selectedTableNo', context: context);

  @override
  String? get selectedTableNo {
    _$selectedTableNoAtom.reportRead();
    return super.selectedTableNo;
  }

  @override
  set selectedTableNo(String? value) {
    _$selectedTableNoAtom.reportWrite(value, super.selectedTableNo, () {
      super.selectedTableNo = value;
    });
  }

  late final _$showTodayOnlyAtom =
      Atom(name: '_OrderStore.showTodayOnly', context: context);

  @override
  bool get showTodayOnly {
    _$showTodayOnlyAtom.reportRead();
    return super.showTodayOnly;
  }

  @override
  set showTodayOnly(bool value) {
    _$showTodayOnlyAtom.reportWrite(value, super.showTodayOnly, () {
      super.showTodayOnly = value;
    });
  }

  late final _$showPaidOnlyAtom =
      Atom(name: '_OrderStore.showPaidOnly', context: context);

  @override
  bool get showPaidOnly {
    _$showPaidOnlyAtom.reportRead();
    return super.showPaidOnly;
  }

  @override
  set showPaidOnly(bool value) {
    _$showPaidOnlyAtom.reportWrite(value, super.showPaidOnly, () {
      super.showPaidOnly = value;
    });
  }

  late final _$showUnpaidOnlyAtom =
      Atom(name: '_OrderStore.showUnpaidOnly', context: context);

  @override
  bool get showUnpaidOnly {
    _$showUnpaidOnlyAtom.reportRead();
    return super.showUnpaidOnly;
  }

  @override
  set showUnpaidOnly(bool value) {
    _$showUnpaidOnlyAtom.reportWrite(value, super.showUnpaidOnly, () {
      super.showUnpaidOnly = value;
    });
  }

  late final _$filterStartDateAtom =
      Atom(name: '_OrderStore.filterStartDate', context: context);

  @override
  DateTime? get filterStartDate {
    _$filterStartDateAtom.reportRead();
    return super.filterStartDate;
  }

  @override
  set filterStartDate(DateTime? value) {
    _$filterStartDateAtom.reportWrite(value, super.filterStartDate, () {
      super.filterStartDate = value;
    });
  }

  late final _$filterEndDateAtom =
      Atom(name: '_OrderStore.filterEndDate', context: context);

  @override
  DateTime? get filterEndDate {
    _$filterEndDateAtom.reportRead();
    return super.filterEndDate;
  }

  @override
  set filterEndDate(DateTime? value) {
    _$filterEndDateAtom.reportWrite(value, super.filterEndDate, () {
      super.filterEndDate = value;
    });
  }

  late final _$loadOrdersAsyncAction =
      AsyncAction('_OrderStore.loadOrders', context: context);

  @override
  Future<void> loadOrders() {
    return _$loadOrdersAsyncAction.run(() => super.loadOrders());
  }

  late final _$addOrderAsyncAction =
      AsyncAction('_OrderStore.addOrder', context: context);

  @override
  Future<bool> addOrder(OrderModel order) {
    return _$addOrderAsyncAction.run(() => super.addOrder(order));
  }

  late final _$updateOrderAsyncAction =
      AsyncAction('_OrderStore.updateOrder', context: context);

  @override
  Future<bool> updateOrder(OrderModel order) {
    return _$updateOrderAsyncAction.run(() => super.updateOrder(order));
  }

  late final _$deleteOrderAsyncAction =
      AsyncAction('_OrderStore.deleteOrder', context: context);

  @override
  Future<bool> deleteOrder(String orderId) {
    return _$deleteOrderAsyncAction.run(() => super.deleteOrder(orderId));
  }

  late final _$updateOrderStatusAsyncAction =
      AsyncAction('_OrderStore.updateOrderStatus', context: context);

  @override
  Future<bool> updateOrderStatus(String orderId, String newStatus) {
    return _$updateOrderStatusAsyncAction
        .run(() => super.updateOrderStatus(orderId, newStatus));
  }

  late final _$markOrderAsPaidAsyncAction =
      AsyncAction('_OrderStore.markOrderAsPaid', context: context);

  @override
  Future<bool> markOrderAsPaid(String orderId,
      {String? paymentMethod, DateTime? completedAt}) {
    return _$markOrderAsPaidAsyncAction.run(() => super.markOrderAsPaid(orderId,
        paymentMethod: paymentMethod, completedAt: completedAt));
  }

  late final _$updateOrderWithNewItemsAsyncAction =
      AsyncAction('_OrderStore.updateOrderWithNewItems', context: context);

  @override
  Future<OrderModel?> updateOrderWithNewItems(
      {required OrderModel existingOrder, required List<CartItem> newItems}) {
    return _$updateOrderWithNewItemsAsyncAction.run(() => super
        .updateOrderWithNewItems(
            existingOrder: existingOrder, newItems: newItems));
  }

  late final _$getNextKotNumberAsyncAction =
      AsyncAction('_OrderStore.getNextKotNumber', context: context);

  @override
  Future<int> getNextKotNumber() {
    return _$getNextKotNumberAsyncAction.run(() => super.getNextKotNumber());
  }

  late final _$getNextBillNumberAsyncAction =
      AsyncAction('_OrderStore.getNextBillNumber', context: context);

  @override
  Future<int> getNextBillNumber() {
    return _$getNextBillNumberAsyncAction.run(() => super.getNextBillNumber());
  }

  late final _$getNextOrderNumberAsyncAction =
      AsyncAction('_OrderStore.getNextOrderNumber', context: context);

  @override
  Future<int> getNextOrderNumber() {
    return _$getNextOrderNumberAsyncAction
        .run(() => super.getNextOrderNumber());
  }

  late final _$updateKotStatusAsyncAction =
      AsyncAction('_OrderStore.updateKotStatus', context: context);

  @override
  Future<bool> updateKotStatus(
      String orderId, int kotNumber, String newStatus) {
    return _$updateKotStatusAsyncAction
        .run(() => super.updateKotStatus(orderId, kotNumber, newStatus));
  }

  late final _$refreshAsyncAction =
      AsyncAction('_OrderStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$_OrderStoreActionController =
      ActionController(name: '_OrderStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSearch() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearSearch');
    try {
      return super.clearSearch();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setStatusFilter(String? status) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.setStatusFilter');
    try {
      return super.setStatusFilter(status);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearStatusFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearStatusFilter');
    try {
      return super.clearStatusFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setOrderTypeFilter(String? orderType) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.setOrderTypeFilter');
    try {
      return super.setOrderTypeFilter(orderType);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearOrderTypeFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearOrderTypeFilter');
    try {
      return super.clearOrderTypeFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setTableFilter(String? tableNo) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.setTableFilter');
    try {
      return super.setTableFilter(tableNo);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearTableFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearTableFilter');
    try {
      return super.clearTableFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleTodayFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.toggleTodayFilter');
    try {
      return super.toggleTodayFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void togglePaidFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.togglePaidFilter');
    try {
      return super.togglePaidFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleUnpaidFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.toggleUnpaidFilter');
    try {
      return super.toggleUnpaidFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setDateRangeFilter(DateTime? startDate, DateTime? endDate) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.setDateRangeFilter');
    try {
      return super.setDateRangeFilter(startDate, endDate);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearDateRangeFilter() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearDateRangeFilter');
    try {
      return super.clearDateRangeFilter();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearAllFilters() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearAllFilters');
    try {
      return super.clearAllFilters();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
orders: ${orders},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedStatus: ${selectedStatus},
selectedOrderType: ${selectedOrderType},
selectedTableNo: ${selectedTableNo},
showTodayOnly: ${showTodayOnly},
showPaidOnly: ${showPaidOnly},
showUnpaidOnly: ${showUnpaidOnly},
filterStartDate: ${filterStartDate},
filterEndDate: ${filterEndDate},
filteredOrders: ${filteredOrders},
orderCount: ${orderCount},
filteredOrderCount: ${filteredOrderCount},
hasOrders: ${hasOrders},
activeOrders: ${activeOrders},
completedOrders: ${completedOrders},
processingOrders: ${processingOrders},
cookingOrders: ${cookingOrders},
readyOrders: ${readyOrders},
servedOrders: ${servedOrders},
paidOrders: ${paidOrders},
unpaidOrders: ${unpaidOrders},
todaysOrders: ${todaysOrders},
activeOrderCount: ${activeOrderCount},
completedOrderCount: ${completedOrderCount},
todaysOrderCount: ${todaysOrderCount},
totalRevenue: ${totalRevenue},
todaysRevenue: ${todaysRevenue},
averageOrderValue: ${averageOrderValue},
orderCountByStatus: ${orderCountByStatus},
orderCountByType: ${orderCountByType}
    ''';
  }
}
