// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CustomerStore on _CustomerStore, Store {
  Computed<List<Customer>>? _$filteredCustomersComputed;

  @override
  List<Customer> get filteredCustomers => (_$filteredCustomersComputed ??=
          Computed<List<Customer>>(() => super.filteredCustomers,
              name: '_CustomerStore.filteredCustomers'))
      .value;
  Computed<int>? _$totalCustomersComputed;

  @override
  int get totalCustomers =>
      (_$totalCustomersComputed ??= Computed<int>(() => super.totalCustomers,
              name: '_CustomerStore.totalCustomers'))
          .value;
  Computed<int>? _$customerCountComputed;

  @override
  int get customerCount =>
      (_$customerCountComputed ??= Computed<int>(() => super.customerCount,
              name: '_CustomerStore.customerCount'))
          .value;
  Computed<bool>? _$hasSelectionComputed;

  @override
  bool get hasSelection =>
      (_$hasSelectionComputed ??= Computed<bool>(() => super.hasSelection,
              name: '_CustomerStore.hasSelection'))
          .value;
  Computed<List<Customer>>? _$topCustomersByPointsComputed;

  @override
  List<Customer> get topCustomersByPoints => (_$topCustomersByPointsComputed ??=
          Computed<List<Customer>>(() => super.topCustomersByPoints,
              name: '_CustomerStore.topCustomersByPoints'))
      .value;
  Computed<List<Customer>>? _$frequentCustomersComputed;

  @override
  List<Customer> get frequentCustomers => (_$frequentCustomersComputed ??=
          Computed<List<Customer>>(() => super.frequentCustomers,
              name: '_CustomerStore.frequentCustomers'))
      .value;
  Computed<List<Customer>>? _$recentCustomersComputed;

  @override
  List<Customer> get recentCustomers => (_$recentCustomersComputed ??=
          Computed<List<Customer>>(() => super.recentCustomers,
              name: '_CustomerStore.recentCustomers'))
      .value;
  Computed<double>? _$totalOutstandingCreditComputed;

  @override
  double get totalOutstandingCredit => (_$totalOutstandingCreditComputed ??=
          Computed<double>(() => super.totalOutstandingCredit,
              name: '_CustomerStore.totalOutstandingCredit'))
      .value;
  Computed<int>? _$customersWithCreditCountComputed;

  @override
  int get customersWithCreditCount => (_$customersWithCreditCountComputed ??=
          Computed<int>(() => super.customersWithCreditCount,
              name: '_CustomerStore.customersWithCreditCount'))
      .value;

  late final _$customersAtom =
      Atom(name: '_CustomerStore.customers', context: context);

  @override
  ObservableList<Customer> get customers {
    _$customersAtom.reportRead();
    return super.customers;
  }

  @override
  set customers(ObservableList<Customer> value) {
    _$customersAtom.reportWrite(value, super.customers, () {
      super.customers = value;
    });
  }

  late final _$searchResultsAtom =
      Atom(name: '_CustomerStore.searchResults', context: context);

  @override
  ObservableList<Customer> get searchResults {
    _$searchResultsAtom.reportRead();
    return super.searchResults;
  }

  @override
  set searchResults(ObservableList<Customer> value) {
    _$searchResultsAtom.reportWrite(value, super.searchResults, () {
      super.searchResults = value;
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

  late final _$selectedCustomerAtom =
      Atom(name: '_CustomerStore.selectedCustomer', context: context);

  @override
  Customer? get selectedCustomer {
    _$selectedCustomerAtom.reportRead();
    return super.selectedCustomer;
  }

  @override
  set selectedCustomer(Customer? value) {
    _$selectedCustomerAtom.reportWrite(value, super.selectedCustomer, () {
      super.selectedCustomer = value;
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
  Future<bool> addCustomer(Customer customer) {
    return _$addCustomerAsyncAction.run(() => super.addCustomer(customer));
  }

  late final _$getCustomerByIdAsyncAction =
      AsyncAction('_CustomerStore.getCustomerById', context: context);

  @override
  Future<Customer?> getCustomerById(String customerId) {
    return _$getCustomerByIdAsyncAction
        .run(() => super.getCustomerById(customerId));
  }

  late final _$getCustomerByPhoneAsyncAction =
      AsyncAction('_CustomerStore.getCustomerByPhone', context: context);

  @override
  Future<Customer?> getCustomerByPhone(String phone) {
    return _$getCustomerByPhoneAsyncAction
        .run(() => super.getCustomerByPhone(phone));
  }

  late final _$updateCustomerAsyncAction =
      AsyncAction('_CustomerStore.updateCustomer', context: context);

  @override
  Future<bool> updateCustomer(Customer updatedCustomer) {
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

  late final _$updateAfterPurchaseAsyncAction =
      AsyncAction('_CustomerStore.updateAfterPurchase', context: context);

  @override
  Future<void> updateAfterPurchase(
      String customerId, double amount, int points) {
    return _$updateAfterPurchaseAsyncAction
        .run(() => super.updateAfterPurchase(customerId, amount, points));
  }

  late final _$updateAfterReturnAsyncAction =
      AsyncAction('_CustomerStore.updateAfterReturn', context: context);

  @override
  Future<void> updateAfterReturn(String customerId, double amount, int points) {
    return _$updateAfterReturnAsyncAction
        .run(() => super.updateAfterReturn(customerId, amount, points));
  }

  late final _$addLoyaltyPointsAsyncAction =
      AsyncAction('_CustomerStore.addLoyaltyPoints', context: context);

  @override
  Future<bool> addLoyaltyPoints(String customerId, int points) {
    return _$addLoyaltyPointsAsyncAction
        .run(() => super.addLoyaltyPoints(customerId, points));
  }

  late final _$redeemCustomerPointsAsyncAction =
      AsyncAction('_CustomerStore.redeemCustomerPoints', context: context);

  @override
  Future<void> redeemCustomerPoints(String customerId, int points) {
    return _$redeemCustomerPointsAsyncAction
        .run(() => super.redeemCustomerPoints(customerId, points));
  }

  late final _$searchCustomersAsyncAction =
      AsyncAction('_CustomerStore.searchCustomers', context: context);

  @override
  Future<List<Customer>> searchCustomers(String query) {
    return _$searchCustomersAsyncAction.run(() => super.searchCustomers(query));
  }

  late final _$clearAllCustomersAsyncAction =
      AsyncAction('_CustomerStore.clearAllCustomers', context: context);

  @override
  Future<void> clearAllCustomers() {
    return _$clearAllCustomersAsyncAction.run(() => super.clearAllCustomers());
  }

  late final _$updateCustomerGSTAsyncAction =
      AsyncAction('_CustomerStore.updateCustomerGST', context: context);

  @override
  Future<void> updateCustomerGST(String customerId, String gstNumber) {
    return _$updateCustomerGSTAsyncAction
        .run(() => super.updateCustomerGST(customerId, gstNumber));
  }

  late final _$updateCustomerCreditAsyncAction =
      AsyncAction('_CustomerStore.updateCustomerCredit', context: context);

  @override
  Future<void> updateCustomerCredit(String customerId, double credit) {
    return _$updateCustomerCreditAsyncAction
        .run(() => super.updateCustomerCredit(customerId, credit));
  }

  late final _$updateAfterCreditSaleAsyncAction =
      AsyncAction('_CustomerStore.updateAfterCreditSale', context: context);

  @override
  Future<void> updateAfterCreditSale(String customerId, double amount) {
    return _$updateAfterCreditSaleAsyncAction
        .run(() => super.updateAfterCreditSale(customerId, amount));
  }

  late final _$getCustomersWithCreditAsyncAction =
      AsyncAction('_CustomerStore.getCustomersWithCredit', context: context);

  @override
  Future<List<Customer>> getCustomersWithCredit() {
    return _$getCustomersWithCreditAsyncAction
        .run(() => super.getCustomersWithCredit());
  }

  late final _$updateCreditLimitAsyncAction =
      AsyncAction('_CustomerStore.updateCreditLimit', context: context);

  @override
  Future<void> updateCreditLimit(String customerId, double creditLimit) {
    return _$updateCreditLimitAsyncAction
        .run(() => super.updateCreditLimit(customerId, creditLimit));
  }

  late final _$reduceCreditAsyncAction =
      AsyncAction('_CustomerStore.reduceCredit', context: context);

  @override
  Future<void> reduceCredit(String customerId, double amount) {
    return _$reduceCreditAsyncAction
        .run(() => super.reduceCredit(customerId, amount));
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
  void selectCustomer(Customer? customer) {
    final _$actionInfo = _$_CustomerStoreActionController.startAction(
        name: '_CustomerStore.selectCustomer');
    try {
      return super.selectCustomer(customer);
    } finally {
      _$_CustomerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSelection() {
    final _$actionInfo = _$_CustomerStoreActionController.startAction(
        name: '_CustomerStore.clearSelection');
    try {
      return super.clearSelection();
    } finally {
      _$_CustomerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
customers: ${customers},
searchResults: ${searchResults},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedCustomer: ${selectedCustomer},
filteredCustomers: ${filteredCustomers},
totalCustomers: ${totalCustomers},
customerCount: ${customerCount},
hasSelection: ${hasSelection},
topCustomersByPoints: ${topCustomersByPoints},
frequentCustomers: ${frequentCustomers},
recentCustomers: ${recentCustomers},
totalOutstandingCredit: ${totalOutstandingCredit},
customersWithCreditCount: ${customersWithCreditCount}
    ''';
  }
}
