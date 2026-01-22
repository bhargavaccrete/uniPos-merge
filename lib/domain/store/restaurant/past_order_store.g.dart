// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'past_order_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PastOrderStore on _PastOrderStore, Store {
  Computed<List<pastOrderModel>>? _$filteredPastOrdersComputed;

  @override
  List<pastOrderModel> get filteredPastOrders =>
      (_$filteredPastOrdersComputed ??= Computed<List<pastOrderModel>>(
              () => super.filteredPastOrders,
              name: '_PastOrderStore.filteredPastOrders'))
          .value;
  Computed<double>? _$totalRevenueComputed;

  @override
  double get totalRevenue =>
      (_$totalRevenueComputed ??= Computed<double>(() => super.totalRevenue,
              name: '_PastOrderStore.totalRevenue'))
          .value;
  Computed<int>? _$totalOrderCountComputed;

  @override
  int get totalOrderCount =>
      (_$totalOrderCountComputed ??= Computed<int>(() => super.totalOrderCount,
              name: '_PastOrderStore.totalOrderCount'))
          .value;
  Computed<double>? _$averageOrderValueComputed;

  @override
  double get averageOrderValue => (_$averageOrderValueComputed ??=
          Computed<double>(() => super.averageOrderValue,
              name: '_PastOrderStore.averageOrderValue'))
      .value;

  late final _$pastOrdersAtom =
      Atom(name: '_PastOrderStore.pastOrders', context: context);

  @override
  ObservableList<pastOrderModel> get pastOrders {
    _$pastOrdersAtom.reportRead();
    return super.pastOrders;
  }

  @override
  set pastOrders(ObservableList<pastOrderModel> value) {
    _$pastOrdersAtom.reportWrite(value, super.pastOrders, () {
      super.pastOrders = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_PastOrderStore.isLoading', context: context);

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
      Atom(name: '_PastOrderStore.errorMessage', context: context);

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
      Atom(name: '_PastOrderStore.searchQuery', context: context);

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

  late final _$selectedOrderTypeAtom =
      Atom(name: '_PastOrderStore.selectedOrderType', context: context);

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

  late final _$startDateAtom =
      Atom(name: '_PastOrderStore.startDate', context: context);

  @override
  DateTime? get startDate {
    _$startDateAtom.reportRead();
    return super.startDate;
  }

  @override
  set startDate(DateTime? value) {
    _$startDateAtom.reportWrite(value, super.startDate, () {
      super.startDate = value;
    });
  }

  late final _$endDateAtom =
      Atom(name: '_PastOrderStore.endDate', context: context);

  @override
  DateTime? get endDate {
    _$endDateAtom.reportRead();
    return super.endDate;
  }

  @override
  set endDate(DateTime? value) {
    _$endDateAtom.reportWrite(value, super.endDate, () {
      super.endDate = value;
    });
  }

  late final _$loadPastOrdersAsyncAction =
      AsyncAction('_PastOrderStore.loadPastOrders', context: context);

  @override
  Future<void> loadPastOrders() {
    return _$loadPastOrdersAsyncAction.run(() => super.loadPastOrders());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_PastOrderStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addOrderAsyncAction =
      AsyncAction('_PastOrderStore.addOrder', context: context);

  @override
  Future<bool> addOrder(pastOrderModel pastOrder) {
    return _$addOrderAsyncAction.run(() => super.addOrder(pastOrder));
  }

  late final _$getOrderByIdAsyncAction =
      AsyncAction('_PastOrderStore.getOrderById', context: context);

  @override
  Future<pastOrderModel?> getOrderById(String orderId) {
    return _$getOrderByIdAsyncAction.run(() => super.getOrderById(orderId));
  }

  late final _$updateOrderAsyncAction =
      AsyncAction('_PastOrderStore.updateOrder', context: context);

  @override
  Future<bool> updateOrder(pastOrderModel updatedOrder) {
    return _$updateOrderAsyncAction.run(() => super.updateOrder(updatedOrder));
  }

  late final _$deleteOrderAsyncAction =
      AsyncAction('_PastOrderStore.deleteOrder', context: context);

  @override
  Future<bool> deleteOrder(String orderId) {
    return _$deleteOrderAsyncAction.run(() => super.deleteOrder(orderId));
  }

  late final _$getOrdersByDateRangeAsyncAction =
      AsyncAction('_PastOrderStore.getOrdersByDateRange', context: context);

  @override
  Future<List<pastOrderModel>> getOrdersByDateRange(
      DateTime startDate, DateTime endDate) {
    return _$getOrdersByDateRangeAsyncAction
        .run(() => super.getOrdersByDateRange(startDate, endDate));
  }

  late final _$getTodaysPastOrdersAsyncAction =
      AsyncAction('_PastOrderStore.getTodaysPastOrders', context: context);

  @override
  Future<List<pastOrderModel>> getTodaysPastOrders() {
    return _$getTodaysPastOrdersAsyncAction
        .run(() => super.getTodaysPastOrders());
  }

  late final _$getOrdersByTypeAsyncAction =
      AsyncAction('_PastOrderStore.getOrdersByType', context: context);

  @override
  Future<List<pastOrderModel>> getOrdersByType(String orderType) {
    return _$getOrdersByTypeAsyncAction
        .run(() => super.getOrdersByType(orderType));
  }

  late final _$getTotalRevenueAsyncAction =
      AsyncAction('_PastOrderStore.getTotalRevenue', context: context);

  @override
  Future<double> getTotalRevenue() {
    return _$getTotalRevenueAsyncAction.run(() => super.getTotalRevenue());
  }

  late final _$getTodaysRevenueAsyncAction =
      AsyncAction('_PastOrderStore.getTodaysRevenue', context: context);

  @override
  Future<double> getTodaysRevenue() {
    return _$getTodaysRevenueAsyncAction.run(() => super.getTodaysRevenue());
  }

  late final _$searchOrdersAsyncAction =
      AsyncAction('_PastOrderStore.searchOrders', context: context);

  @override
  Future<List<pastOrderModel>> searchOrders(String query) {
    return _$searchOrdersAsyncAction.run(() => super.searchOrders(query));
  }

  late final _$deleteAllOrdersAsyncAction =
      AsyncAction('_PastOrderStore.deleteAllOrders', context: context);

  @override
  Future<bool> deleteAllOrders() {
    return _$deleteAllOrdersAsyncAction.run(() => super.deleteAllOrders());
  }

  late final _$getOrderCountAsyncAction =
      AsyncAction('_PastOrderStore.getOrderCount', context: context);

  @override
  Future<int> getOrderCount() {
    return _$getOrderCountAsyncAction.run(() => super.getOrderCount());
  }

  late final _$processRefundAsyncAction =
      AsyncAction('_PastOrderStore.processRefund', context: context);

  @override
  Future<pastOrderModel?> processRefund(
      {required pastOrderModel order,
      required PartialRefundResult refundResult}) {
    return _$processRefundAsyncAction.run(
        () => super.processRefund(order: order, refundResult: refundResult));
  }

  late final _$voidOrderAsyncAction =
      AsyncAction('_PastOrderStore.voidOrder', context: context);

  @override
  Future<pastOrderModel?> voidOrder(
      {required pastOrderModel order, required String reason}) {
    return _$voidOrderAsyncAction
        .run(() => super.voidOrder(order: order, reason: reason));
  }

  late final _$_PastOrderStoreActionController =
      ActionController(name: '_PastOrderStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_PastOrderStoreActionController.startAction(
        name: '_PastOrderStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_PastOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setOrderTypeFilter(String? orderType) {
    final _$actionInfo = _$_PastOrderStoreActionController.startAction(
        name: '_PastOrderStore.setOrderTypeFilter');
    try {
      return super.setOrderTypeFilter(orderType);
    } finally {
      _$_PastOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setDateRange(DateTime? start, DateTime? end) {
    final _$actionInfo = _$_PastOrderStoreActionController.startAction(
        name: '_PastOrderStore.setDateRange');
    try {
      return super.setDateRange(start, end);
    } finally {
      _$_PastOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilters() {
    final _$actionInfo = _$_PastOrderStoreActionController.startAction(
        name: '_PastOrderStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_PastOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_PastOrderStoreActionController.startAction(
        name: '_PastOrderStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_PastOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
pastOrders: ${pastOrders},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedOrderType: ${selectedOrderType},
startDate: ${startDate},
endDate: ${endDate},
filteredPastOrders: ${filteredPastOrders},
totalRevenue: ${totalRevenue},
totalOrderCount: ${totalOrderCount},
averageOrderValue: ${averageOrderValue}
    ''';
  }
}
