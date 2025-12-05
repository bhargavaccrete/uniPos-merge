// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hold_sale_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HoldSaleStore on _HoldSaleStore, Store {
  Computed<int>? _$holdSaleCountComputed;

  @override
  int get holdSaleCount =>
      (_$holdSaleCountComputed ??= Computed<int>(() => super.holdSaleCount,
              name: '_HoldSaleStore.holdSaleCount'))
          .value;
  Computed<double>? _$totalHoldSalesValueComputed;

  @override
  double get totalHoldSalesValue => (_$totalHoldSalesValueComputed ??=
          Computed<double>(() => super.totalHoldSalesValue,
              name: '_HoldSaleStore.totalHoldSalesValue'))
      .value;
  Computed<int>? _$totalItemsCountComputed;

  @override
  int get totalItemsCount =>
      (_$totalItemsCountComputed ??= Computed<int>(() => super.totalItemsCount,
              name: '_HoldSaleStore.totalItemsCount'))
          .value;

  late final _$holdSalesAtom =
      Atom(name: '_HoldSaleStore.holdSales', context: context);

  @override
  ObservableList<HoldSaleModel> get holdSales {
    _$holdSalesAtom.reportRead();
    return super.holdSales;
  }

  @override
  set holdSales(ObservableList<HoldSaleModel> value) {
    _$holdSalesAtom.reportWrite(value, super.holdSales, () {
      super.holdSales = value;
    });
  }

  late final _$currentHoldSaleItemsAtom =
      Atom(name: '_HoldSaleStore.currentHoldSaleItems', context: context);

  @override
  ObservableList<HoldSaleItemModel> get currentHoldSaleItems {
    _$currentHoldSaleItemsAtom.reportRead();
    return super.currentHoldSaleItems;
  }

  @override
  set currentHoldSaleItems(ObservableList<HoldSaleItemModel> value) {
    _$currentHoldSaleItemsAtom.reportWrite(value, super.currentHoldSaleItems,
        () {
      super.currentHoldSaleItems = value;
    });
  }

  late final _$selectedHoldSaleAtom =
      Atom(name: '_HoldSaleStore.selectedHoldSale', context: context);

  @override
  HoldSaleModel? get selectedHoldSale {
    _$selectedHoldSaleAtom.reportRead();
    return super.selectedHoldSale;
  }

  @override
  set selectedHoldSale(HoldSaleModel? value) {
    _$selectedHoldSaleAtom.reportWrite(value, super.selectedHoldSale, () {
      super.selectedHoldSale = value;
    });
  }

  late final _$searchResultsAtom =
      Atom(name: '_HoldSaleStore.searchResults', context: context);

  @override
  ObservableList<HoldSaleModel> get searchResults {
    _$searchResultsAtom.reportRead();
    return super.searchResults;
  }

  @override
  set searchResults(ObservableList<HoldSaleModel> value) {
    _$searchResultsAtom.reportWrite(value, super.searchResults, () {
      super.searchResults = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_HoldSaleStore.isLoading', context: context);

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

  late final _$initAsyncAction =
      AsyncAction('_HoldSaleStore.init', context: context);

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loadHoldSalesAsyncAction =
      AsyncAction('_HoldSaleStore.loadHoldSales', context: context);

  @override
  Future<void> loadHoldSales() {
    return _$loadHoldSalesAsyncAction.run(() => super.loadHoldSales());
  }

  late final _$addHoldSaleAsyncAction =
      AsyncAction('_HoldSaleStore.addHoldSale', context: context);

  @override
  Future<void> addHoldSale(
      HoldSaleModel holdSale, List<HoldSaleItemModel> items) {
    return _$addHoldSaleAsyncAction
        .run(() => super.addHoldSale(holdSale, items));
  }

  late final _$getHoldSaleByIdAsyncAction =
      AsyncAction('_HoldSaleStore.getHoldSaleById', context: context);

  @override
  Future<HoldSaleModel?> getHoldSaleById(String holdSaleId) {
    return _$getHoldSaleByIdAsyncAction
        .run(() => super.getHoldSaleById(holdSaleId));
  }

  late final _$selectHoldSaleAsyncAction =
      AsyncAction('_HoldSaleStore.selectHoldSale', context: context);

  @override
  Future<void> selectHoldSale(HoldSaleModel holdSale) {
    return _$selectHoldSaleAsyncAction
        .run(() => super.selectHoldSale(holdSale));
  }

  late final _$deleteHoldSaleAsyncAction =
      AsyncAction('_HoldSaleStore.deleteHoldSale', context: context);

  @override
  Future<void> deleteHoldSale(String holdSaleId) {
    return _$deleteHoldSaleAsyncAction
        .run(() => super.deleteHoldSale(holdSaleId));
  }

  late final _$updateHoldSaleAsyncAction =
      AsyncAction('_HoldSaleStore.updateHoldSale', context: context);

  @override
  Future<void> updateHoldSale(HoldSaleModel holdSale) {
    return _$updateHoldSaleAsyncAction
        .run(() => super.updateHoldSale(holdSale));
  }

  late final _$searchHoldSalesAsyncAction =
      AsyncAction('_HoldSaleStore.searchHoldSales', context: context);

  @override
  Future<void> searchHoldSales(String query) {
    return _$searchHoldSalesAsyncAction.run(() => super.searchHoldSales(query));
  }

  late final _$getItemsForHoldSaleAsyncAction =
      AsyncAction('_HoldSaleStore.getItemsForHoldSale', context: context);

  @override
  Future<List<HoldSaleItemModel>> getItemsForHoldSale(String holdSaleId) {
    return _$getItemsForHoldSaleAsyncAction
        .run(() => super.getItemsForHoldSale(holdSaleId));
  }

  late final _$getOldestHoldSaleAsyncAction =
      AsyncAction('_HoldSaleStore.getOldestHoldSale', context: context);

  @override
  Future<HoldSaleModel?> getOldestHoldSale() {
    return _$getOldestHoldSaleAsyncAction.run(() => super.getOldestHoldSale());
  }

  late final _$clearAllHoldSalesAsyncAction =
      AsyncAction('_HoldSaleStore.clearAllHoldSales', context: context);

  @override
  Future<void> clearAllHoldSales() {
    return _$clearAllHoldSalesAsyncAction.run(() => super.clearAllHoldSales());
  }

  late final _$_HoldSaleStoreActionController =
      ActionController(name: '_HoldSaleStore', context: context);

  @override
  void clearSelection() {
    final _$actionInfo = _$_HoldSaleStoreActionController.startAction(
        name: '_HoldSaleStore.clearSelection');
    try {
      return super.clearSelection();
    } finally {
      _$_HoldSaleStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
holdSales: ${holdSales},
currentHoldSaleItems: ${currentHoldSaleItems},
selectedHoldSale: ${selectedHoldSale},
searchResults: ${searchResults},
isLoading: ${isLoading},
holdSaleCount: ${holdSaleCount},
totalHoldSalesValue: ${totalHoldSalesValue},
totalItemsCount: ${totalItemsCount}
    ''';
  }
}
