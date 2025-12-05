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
  Computed<List<OrderModel>>? _$processingOrdersComputed;

  @override
  List<OrderModel> get processingOrders => (_$processingOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.processingOrders,
              name: '_OrderStore.processingOrders'))
      .value;
  Computed<List<OrderModel>>? _$completedOrdersComputed;

  @override
  List<OrderModel> get completedOrders => (_$completedOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.completedOrders,
              name: '_OrderStore.completedOrders'))
      .value;
  Computed<List<OrderModel>>? _$todaysOrdersComputed;

  @override
  List<OrderModel> get todaysOrders => (_$todaysOrdersComputed ??=
          Computed<List<OrderModel>>(() => super.todaysOrders,
              name: '_OrderStore.todaysOrders'))
      .value;
  Computed<int>? _$totalOrderCountComputed;

  @override
  int get totalOrderCount =>
      (_$totalOrderCountComputed ??= Computed<int>(() => super.totalOrderCount,
              name: '_OrderStore.totalOrderCount'))
          .value;
  Computed<int>? _$processingOrderCountComputed;

  @override
  int get processingOrderCount => (_$processingOrderCountComputed ??=
          Computed<int>(() => super.processingOrderCount,
              name: '_OrderStore.processingOrderCount'))
      .value;
  Computed<double>? _$todaysSalesTotalComputed;

  @override
  double get todaysSalesTotal => (_$todaysSalesTotalComputed ??=
          Computed<double>(() => super.todaysSalesTotal,
              name: '_OrderStore.todaysSalesTotal'))
      .value;

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

  late final _$loadOrdersAsyncAction =
      AsyncAction('_OrderStore.loadOrders', context: context);

  @override
  Future<void> loadOrders() {
    return _$loadOrdersAsyncAction.run(() => super.loadOrders());
  }

  late final _$addOrderAsyncAction =
      AsyncAction('_OrderStore.addOrder', context: context);

  @override
  Future<void> addOrder(OrderModel order) {
    return _$addOrderAsyncAction.run(() => super.addOrder(order));
  }

  late final _$updateOrderAsyncAction =
      AsyncAction('_OrderStore.updateOrder', context: context);

  @override
  Future<void> updateOrder(OrderModel order) {
    return _$updateOrderAsyncAction.run(() => super.updateOrder(order));
  }

  late final _$deleteOrderAsyncAction =
      AsyncAction('_OrderStore.deleteOrder', context: context);

  @override
  Future<void> deleteOrder(String id) {
    return _$deleteOrderAsyncAction.run(() => super.deleteOrder(id));
  }

  late final _$updateOrderStatusAsyncAction =
      AsyncAction('_OrderStore.updateOrderStatus', context: context);

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus) {
    return _$updateOrderStatusAsyncAction
        .run(() => super.updateOrderStatus(orderId, newStatus));
  }

  late final _$markOrderAsPaidAsyncAction =
      AsyncAction('_OrderStore.markOrderAsPaid', context: context);

  @override
  Future<void> markOrderAsPaid(String orderId, {String? paymentMethod}) {
    return _$markOrderAsPaidAsyncAction.run(
        () => super.markOrderAsPaid(orderId, paymentMethod: paymentMethod));
  }

  late final _$getNextKotNumberAsyncAction =
      AsyncAction('_OrderStore.getNextKotNumber', context: context);

  @override
  Future<int> getNextKotNumber() {
    return _$getNextKotNumberAsyncAction.run(() => super.getNextKotNumber());
  }

  late final _$_OrderStoreActionController =
      ActionController(name: '_OrderStore', context: context);

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
  void clearFilters() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
        name: '_OrderStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
selectedStatus: ${selectedStatus},
selectedOrderType: ${selectedOrderType},
filteredOrders: ${filteredOrders},
processingOrders: ${processingOrders},
completedOrders: ${completedOrders},
todaysOrders: ${todaysOrders},
totalOrderCount: ${totalOrderCount},
processingOrderCount: ${processingOrderCount},
todaysSalesTotal: ${todaysSalesTotal}
    ''';
  }
}
