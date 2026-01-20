// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CustomerStoreRes on _CustomerStore, Store {
  Computed<List<RestaurantCustomer>>? _$filteredCustomersComputed;

  @override
  List<RestaurantCustomer> get filteredCustomers =>
      (_$filteredCustomersComputed ??= Computed<List<RestaurantCustomer>>(
              () => super.filteredCustomers,
              name: '_CustomerStore.filteredCustomers'))
          .value;
  Computed<int>? _$totalCustomersComputed;

  @override
  int get totalCustomers =>
      (_$totalCustomersComputed ??= Computed<int>(() => super.totalCustomers,
              name: '_CustomerStore.totalCustomers'))
          .value;
  Computed<List<RestaurantCustomer>>? _$topCustomersByPointsComputed;

  @override
  List<RestaurantCustomer> get topCustomersByPoints =>
      (_$topCustomersByPointsComputed ??= Computed<List<RestaurantCustomer>>(
              () => super.topCustomersByPoints,
              name: '_CustomerStore.topCustomersByPoints'))
          .value;
  Computed<List<RestaurantCustomer>>? _$frequentCustomersComputed;

  @override
  List<RestaurantCustomer> get frequentCustomers =>
      (_$frequentCustomersComputed ??= Computed<List<RestaurantCustomer>>(
              () => super.frequentCustomers,
              name: '_CustomerStore.frequentCustomers'))
          .value;

  late final _$customersAtom =
      Atom(name: '_CustomerStore.customers', context: context);

  @override
  ObservableList<RestaurantCustomer> get customers {
    _$customersAtom.reportRead();
    return super.customers;
  }

  @override
  set customers(ObservableList<RestaurantCustomer> value) {
    _$customersAtom.reportWrite(value, super.customers, () {
      super.customers = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_CustomerStore.isLoading', context: context);

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
      Atom(name: '_CustomerStore.errorMessage', context: context);

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
      Atom(name: '_CustomerStore.searchQuery', context: context);

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

  late final _$loadCustomersAsyncAction =
      AsyncAction('_CustomerStore.loadCustomers', context: context);

  @override
  Future<void> loadCustomers() {
    return _$loadCustomersAsyncAction.run(() => super.loadCustomers());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_CustomerStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addCustomerAsyncAction =
      AsyncAction('_CustomerStore.addCustomer', context: context);

  @override
  Future<bool> addCustomer(RestaurantCustomer customer) {
    return _$addCustomerAsyncAction.run(() => super.addCustomer(customer));
  }

  late final _$getCustomerByIdAsyncAction =
      AsyncAction('_CustomerStore.getCustomerById', context: context);

  @override
  Future<RestaurantCustomer?> getCustomerById(String customerId) {
    return _$getCustomerByIdAsyncAction
        .run(() => super.getCustomerById(customerId));
  }

  late final _$getCustomerByPhoneAsyncAction =
      AsyncAction('_CustomerStore.getCustomerByPhone', context: context);

  @override
  Future<RestaurantCustomer?> getCustomerByPhone(String phone) {
    return _$getCustomerByPhoneAsyncAction
        .run(() => super.getCustomerByPhone(phone));
  }

  late final _$updateCustomerAsyncAction =
      AsyncAction('_CustomerStore.updateCustomer', context: context);

  @override
  Future<bool> updateCustomer(RestaurantCustomer updatedCustomer) {
    return _$updateCustomerAsyncAction
        .run(() => super.updateCustomer(updatedCustomer));
  }

  late final _$deleteCustomerAsyncAction =
      AsyncAction('_CustomerStore.deleteCustomer', context: context);

  @override
  Future<bool> deleteCustomer(String customerId) {
    return _$deleteCustomerAsyncAction
        .run(() => super.deleteCustomer(customerId));
  }

  late final _$updateCustomerVisitAsyncAction =
      AsyncAction('_CustomerStore.updateCustomerVisit', context: context);

  @override
  Future<bool> updateCustomerVisit(
      {required String customerId,
      required String orderType,
      int pointsToAdd = 0}) {
    return _$updateCustomerVisitAsyncAction.run(() => super.updateCustomerVisit(
        customerId: customerId,
        orderType: orderType,
        pointsToAdd: pointsToAdd));
  }

  late final _$addLoyaltyPointsAsyncAction =
      AsyncAction('_CustomerStore.addLoyaltyPoints', context: context);

  @override
  Future<bool> addLoyaltyPoints(String customerId, int points) {
    return _$addLoyaltyPointsAsyncAction
        .run(() => super.addLoyaltyPoints(customerId, points));
  }

  late final _$searchCustomersAsyncAction =
      AsyncAction('_CustomerStore.searchCustomers', context: context);

  @override
  Future<List<RestaurantCustomer>> searchCustomers(String query) {
    return _$searchCustomersAsyncAction.run(() => super.searchCustomers(query));
  }

  late final _$_CustomerStoreActionController =
      ActionController(name: '_CustomerStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_CustomerStoreActionController.startAction(
        name: '_CustomerStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_CustomerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_CustomerStoreActionController.startAction(
        name: '_CustomerStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_CustomerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
customers: ${customers},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
filteredCustomers: ${filteredCustomers},
totalCustomers: ${totalCustomers},
topCustomersByPoints: ${topCustomersByPoints},
frequentCustomers: ${frequentCustomers}
    ''';
  }
}
