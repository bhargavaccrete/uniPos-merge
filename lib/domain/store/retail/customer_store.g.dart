// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CustomerStore on _CustomerStore, Store {
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
  ObservableList<CustomerModel> get customers {
    _$customersAtom.reportRead();
    return super.customers;
  }

  @override
  set customers(ObservableList<CustomerModel> value) {
    _$customersAtom.reportWrite(value, super.customers, () {
      super.customers = value;
    });
  }

  late final _$searchResultsAtom =
      Atom(name: '_CustomerStore.searchResults', context: context);

  @override
  ObservableList<CustomerModel> get searchResults {
    _$searchResultsAtom.reportRead();
    return super.searchResults;
  }

  @override
  set searchResults(ObservableList<CustomerModel> value) {
    _$searchResultsAtom.reportWrite(value, super.searchResults, () {
      super.searchResults = value;
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
  CustomerModel? get selectedCustomer {
    _$selectedCustomerAtom.reportRead();
    return super.selectedCustomer;
  }

  @override
  set selectedCustomer(CustomerModel? value) {
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

  late final _$addCustomerAsyncAction =
      AsyncAction('_CustomerStore.addCustomer', context: context);

  @override
  Future<void> addCustomer(CustomerModel customer) {
    return _$addCustomerAsyncAction.run(() => super.addCustomer(customer));
  }

  late final _$updateCustomerAsyncAction =
      AsyncAction('_CustomerStore.updateCustomer', context: context);

  @override
  Future<void> updateCustomer(CustomerModel customer) {
    return _$updateCustomerAsyncAction
        .run(() => super.updateCustomer(customer));
  }

  late final _$deleteCustomerAsyncAction =
      AsyncAction('_CustomerStore.deleteCustomer', context: context);

  @override
  Future<void> deleteCustomer(String customerId) {
    return _$deleteCustomerAsyncAction
        .run(() => super.deleteCustomer(customerId));
  }

  late final _$searchCustomersAsyncAction =
      AsyncAction('_CustomerStore.searchCustomers', context: context);

  @override
  Future<void> searchCustomers(String query) {
    return _$searchCustomersAsyncAction.run(() => super.searchCustomers(query));
  }

  late final _$updateAfterPurchaseAsyncAction =
      AsyncAction('_CustomerStore.updateAfterPurchase', context: context);

  @override
  Future<void> updateAfterPurchase(
      String customerId, double amount, int points) {
    return _$updateAfterPurchaseAsyncAction
        .run(() => super.updateAfterPurchase(customerId, amount, points));
  }

  late final _$clearAllCustomersAsyncAction =
      AsyncAction('_CustomerStore.clearAllCustomers', context: context);

  @override
  Future<void> clearAllCustomers() {
    return _$clearAllCustomersAsyncAction.run(() => super.clearAllCustomers());
  }

  late final _$redeemCustomerPointsAsyncAction =
      AsyncAction('_CustomerStore.redeemCustomerPoints', context: context);

  @override
  Future<void> redeemCustomerPoints(String customerId, int points) {
    return _$redeemCustomerPointsAsyncAction
        .run(() => super.redeemCustomerPoints(customerId, points));
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
  Future<List<CustomerModel>> getCustomersWithCredit() {
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
  void selectCustomer(CustomerModel? customer) {
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
searchQuery: ${searchQuery},
selectedCustomer: ${selectedCustomer},
customerCount: ${customerCount},
hasSelection: ${hasSelection},
totalOutstandingCredit: ${totalOutstandingCredit},
customersWithCreditCount: ${customersWithCreditCount}
    ''';
  }
}
