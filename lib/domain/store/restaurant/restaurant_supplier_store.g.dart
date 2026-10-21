// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_supplier_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$RestaurantSupplierStore on _RestaurantSupplierStore, Store {
  Computed<List<RestaurantSupplierModel>>? _$filteredSuppliersComputed;

  @override
  List<RestaurantSupplierModel> get filteredSuppliers =>
      (_$filteredSuppliersComputed ??= Computed<List<RestaurantSupplierModel>>(
              () => super.filteredSuppliers,
              name: '_RestaurantSupplierStore.filteredSuppliers'))
          .value;
  Computed<int>? _$supplierCountComputed;

  @override
  int get supplierCount =>
      (_$supplierCountComputed ??= Computed<int>(() => super.supplierCount,
              name: '_RestaurantSupplierStore.supplierCount'))
          .value;
  Computed<double>? _$totalOutstandingComputed;

  @override
  double get totalOutstanding => (_$totalOutstandingComputed ??=
          Computed<double>(() => super.totalOutstanding,
              name: '_RestaurantSupplierStore.totalOutstanding'))
      .value;

  late final _$suppliersAtom =
      Atom(name: '_RestaurantSupplierStore.suppliers', context: context);

  @override
  ObservableList<RestaurantSupplierModel> get suppliers {
    _$suppliersAtom.reportRead();
    return super.suppliers;
  }

  @override
  set suppliers(ObservableList<RestaurantSupplierModel> value) {
    _$suppliersAtom.reportWrite(value, super.suppliers, () {
      super.suppliers = value;
    });
  }

  late final _$searchQueryAtom =
      Atom(name: '_RestaurantSupplierStore.searchQuery', context: context);

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

  late final _$isLoadingAtom =
      Atom(name: '_RestaurantSupplierStore.isLoading', context: context);

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
      Atom(name: '_RestaurantSupplierStore.errorMessage', context: context);

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

  late final _$loadSuppliersAsyncAction =
      AsyncAction('_RestaurantSupplierStore.loadSuppliers', context: context);

  @override
  Future<void> loadSuppliers() {
    return _$loadSuppliersAsyncAction.run(() => super.loadSuppliers());
  }

  late final _$addSupplierAsyncAction =
      AsyncAction('_RestaurantSupplierStore.addSupplier', context: context);

  @override
  Future<RestaurantSupplierModel> addSupplier(
      {required String name,
      String? phone,
      String? address,
      String? gstNumber,
      double openingBalance = 0}) {
    return _$addSupplierAsyncAction.run(() => super.addSupplier(
        name: name,
        phone: phone,
        address: address,
        gstNumber: gstNumber,
        openingBalance: openingBalance));
  }

  late final _$updateSupplierAsyncAction =
      AsyncAction('_RestaurantSupplierStore.updateSupplier', context: context);

  @override
  Future<void> updateSupplier(RestaurantSupplierModel supplier,
      {required String name,
      String? phone,
      String? address,
      String? gstNumber}) {
    return _$updateSupplierAsyncAction.run(() => super.updateSupplier(supplier,
        name: name, phone: phone, address: address, gstNumber: gstNumber));
  }

  late final _$deleteSupplierAsyncAction =
      AsyncAction('_RestaurantSupplierStore.deleteSupplier', context: context);

  @override
  Future<void> deleteSupplier(String supplierId) {
    return _$deleteSupplierAsyncAction
        .run(() => super.deleteSupplier(supplierId));
  }

  late final _$recordBalanceMovementAsyncAction = AsyncAction(
      '_RestaurantSupplierStore.recordBalanceMovement',
      context: context);

  @override
  Future<void> recordBalanceMovement(
      {required String supplierId,
      required double amount,
      required RestaurantSupplierLedgerType type,
      required String description,
      String? docNumber,
      String? docId,
      String? paymentMode,
      String? referenceNo,
      String? note,
      String? date}) {
    return _$recordBalanceMovementAsyncAction.run(() => super
        .recordBalanceMovement(
            supplierId: supplierId,
            amount: amount,
            type: type,
            description: description,
            docNumber: docNumber,
            docId: docId,
            paymentMode: paymentMode,
            referenceNo: referenceNo,
            note: note,
            date: date));
  }

  late final _$_RestaurantSupplierStoreActionController =
      ActionController(name: '_RestaurantSupplierStore', context: context);

  @override
  void setSearchQuery(String value) {
    final _$actionInfo = _$_RestaurantSupplierStoreActionController.startAction(
        name: '_RestaurantSupplierStore.setSearchQuery');
    try {
      return super.setSearchQuery(value);
    } finally {
      _$_RestaurantSupplierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
suppliers: ${suppliers},
searchQuery: ${searchQuery},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
filteredSuppliers: ${filteredSuppliers},
supplierCount: ${supplierCount},
totalOutstanding: ${totalOutstanding}
    ''';
  }
}
