// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_order_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PurchaseOrderStore on _PurchaseOrderStore, Store {
  Computed<List<PurchaseOrderModel>>? _$receivablePOsComputed;

  @override
  List<PurchaseOrderModel> get receivablePOs => (_$receivablePOsComputed ??=
          Computed<List<PurchaseOrderModel>>(() => super.receivablePOs,
              name: '_PurchaseOrderStore.receivablePOs'))
      .value;
  Computed<int>? _$poCountComputed;

  @override
  int get poCount => (_$poCountComputed ??= Computed<int>(() => super.poCount,
          name: '_PurchaseOrderStore.poCount'))
      .value;
  Computed<int>? _$draftPOCountComputed;

  @override
  int get draftPOCount =>
      (_$draftPOCountComputed ??= Computed<int>(() => super.draftPOCount,
              name: '_PurchaseOrderStore.draftPOCount'))
          .value;
  Computed<int>? _$sentPOCountComputed;

  @override
  int get sentPOCount =>
      (_$sentPOCountComputed ??= Computed<int>(() => super.sentPOCount,
              name: '_PurchaseOrderStore.sentPOCount'))
          .value;
  Computed<int>? _$pendingReceivingCountComputed;

  @override
  int get pendingReceivingCount => (_$pendingReceivingCountComputed ??=
          Computed<int>(() => super.pendingReceivingCount,
              name: '_PurchaseOrderStore.pendingReceivingCount'))
      .value;
  Computed<bool>? _$hasPOSelectionComputed;

  @override
  bool get hasPOSelection =>
      (_$hasPOSelectionComputed ??= Computed<bool>(() => super.hasPOSelection,
              name: '_PurchaseOrderStore.hasPOSelection'))
          .value;
  Computed<bool>? _$hasGRNSelectionComputed;

  @override
  bool get hasGRNSelection =>
      (_$hasGRNSelectionComputed ??= Computed<bool>(() => super.hasGRNSelection,
              name: '_PurchaseOrderStore.hasGRNSelection'))
          .value;
  Computed<int>? _$grnCountComputed;

  @override
  int get grnCount =>
      (_$grnCountComputed ??= Computed<int>(() => super.grnCount,
              name: '_PurchaseOrderStore.grnCount'))
          .value;
  Computed<int>? _$draftGRNCountComputed;

  @override
  int get draftGRNCount =>
      (_$draftGRNCountComputed ??= Computed<int>(() => super.draftGRNCount,
              name: '_PurchaseOrderStore.draftGRNCount'))
          .value;

  late final _$purchaseOrdersAtom =
      Atom(name: '_PurchaseOrderStore.purchaseOrders', context: context);

  @override
  ObservableList<PurchaseOrderModel> get purchaseOrders {
    _$purchaseOrdersAtom.reportRead();
    return super.purchaseOrders;
  }

  @override
  set purchaseOrders(ObservableList<PurchaseOrderModel> value) {
    _$purchaseOrdersAtom.reportWrite(value, super.purchaseOrders, () {
      super.purchaseOrders = value;
    });
  }

  late final _$searchResultsAtom =
      Atom(name: '_PurchaseOrderStore.searchResults', context: context);

  @override
  ObservableList<PurchaseOrderModel> get searchResults {
    _$searchResultsAtom.reportRead();
    return super.searchResults;
  }

  @override
  set searchResults(ObservableList<PurchaseOrderModel> value) {
    _$searchResultsAtom.reportWrite(value, super.searchResults, () {
      super.searchResults = value;
    });
  }

  late final _$currentPOItemsAtom =
      Atom(name: '_PurchaseOrderStore.currentPOItems', context: context);

  @override
  ObservableList<PurchaseOrderItemModel> get currentPOItems {
    _$currentPOItemsAtom.reportRead();
    return super.currentPOItems;
  }

  @override
  set currentPOItems(ObservableList<PurchaseOrderItemModel> value) {
    _$currentPOItemsAtom.reportWrite(value, super.currentPOItems, () {
      super.currentPOItems = value;
    });
  }

  late final _$searchQueryAtom =
      Atom(name: '_PurchaseOrderStore.searchQuery', context: context);

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

  late final _$selectedPOAtom =
      Atom(name: '_PurchaseOrderStore.selectedPO', context: context);

  @override
  PurchaseOrderModel? get selectedPO {
    _$selectedPOAtom.reportRead();
    return super.selectedPO;
  }

  @override
  set selectedPO(PurchaseOrderModel? value) {
    _$selectedPOAtom.reportWrite(value, super.selectedPO, () {
      super.selectedPO = value;
    });
  }

  late final _$statusFilterAtom =
      Atom(name: '_PurchaseOrderStore.statusFilter', context: context);

  @override
  POStatus? get statusFilter {
    _$statusFilterAtom.reportRead();
    return super.statusFilter;
  }

  @override
  set statusFilter(POStatus? value) {
    _$statusFilterAtom.reportWrite(value, super.statusFilter, () {
      super.statusFilter = value;
    });
  }

  late final _$grnsAtom =
      Atom(name: '_PurchaseOrderStore.grns', context: context);

  @override
  ObservableList<GRNModel> get grns {
    _$grnsAtom.reportRead();
    return super.grns;
  }

  @override
  set grns(ObservableList<GRNModel> value) {
    _$grnsAtom.reportWrite(value, super.grns, () {
      super.grns = value;
    });
  }

  late final _$currentGRNItemsAtom =
      Atom(name: '_PurchaseOrderStore.currentGRNItems', context: context);

  @override
  ObservableList<GRNItemModel> get currentGRNItems {
    _$currentGRNItemsAtom.reportRead();
    return super.currentGRNItems;
  }

  @override
  set currentGRNItems(ObservableList<GRNItemModel> value) {
    _$currentGRNItemsAtom.reportWrite(value, super.currentGRNItems, () {
      super.currentGRNItems = value;
    });
  }

  late final _$selectedGRNAtom =
      Atom(name: '_PurchaseOrderStore.selectedGRN', context: context);

  @override
  GRNModel? get selectedGRN {
    _$selectedGRNAtom.reportRead();
    return super.selectedGRN;
  }

  @override
  set selectedGRN(GRNModel? value) {
    _$selectedGRNAtom.reportWrite(value, super.selectedGRN, () {
      super.selectedGRN = value;
    });
  }

  late final _$currentPOGRNsAtom =
      Atom(name: '_PurchaseOrderStore.currentPOGRNs', context: context);

  @override
  ObservableList<GRNModel> get currentPOGRNs {
    _$currentPOGRNsAtom.reportRead();
    return super.currentPOGRNs;
  }

  @override
  set currentPOGRNs(ObservableList<GRNModel> value) {
    _$currentPOGRNsAtom.reportWrite(value, super.currentPOGRNs, () {
      super.currentPOGRNs = value;
    });
  }

  late final _$loadPurchaseOrdersAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadPurchaseOrders', context: context);

  @override
  Future<void> loadPurchaseOrders() {
    return _$loadPurchaseOrdersAsyncAction
        .run(() => super.loadPurchaseOrders());
  }

  late final _$loadPurchaseOrdersByStatusAsyncAction = AsyncAction(
      '_PurchaseOrderStore.loadPurchaseOrdersByStatus',
      context: context);

  @override
  Future<void> loadPurchaseOrdersByStatus(POStatus status) {
    return _$loadPurchaseOrdersByStatusAsyncAction
        .run(() => super.loadPurchaseOrdersByStatus(status));
  }

  late final _$loadActivePurchaseOrdersAsyncAction = AsyncAction(
      '_PurchaseOrderStore.loadActivePurchaseOrders',
      context: context);

  @override
  Future<void> loadActivePurchaseOrders() {
    return _$loadActivePurchaseOrdersAsyncAction
        .run(() => super.loadActivePurchaseOrders());
  }

  late final _$addPurchaseOrderAsyncAction =
      AsyncAction('_PurchaseOrderStore.addPurchaseOrder', context: context);

  @override
  Future<String> addPurchaseOrder(
      PurchaseOrderModel po, List<PurchaseOrderItemModel> items) {
    return _$addPurchaseOrderAsyncAction
        .run(() => super.addPurchaseOrder(po, items));
  }

  late final _$updatePurchaseOrderAsyncAction =
      AsyncAction('_PurchaseOrderStore.updatePurchaseOrder', context: context);

  @override
  Future<void> updatePurchaseOrder(
      PurchaseOrderModel po, List<PurchaseOrderItemModel> items) {
    return _$updatePurchaseOrderAsyncAction
        .run(() => super.updatePurchaseOrder(po, items));
  }

  late final _$deletePurchaseOrderAsyncAction =
      AsyncAction('_PurchaseOrderStore.deletePurchaseOrder', context: context);

  @override
  Future<void> deletePurchaseOrder(String poId) {
    return _$deletePurchaseOrderAsyncAction
        .run(() => super.deletePurchaseOrder(poId));
  }

  late final _$updatePOStatusAsyncAction =
      AsyncAction('_PurchaseOrderStore.updatePOStatus', context: context);

  @override
  Future<void> updatePOStatus(String poId, POStatus newStatus) {
    return _$updatePOStatusAsyncAction
        .run(() => super.updatePOStatus(poId, newStatus));
  }

  late final _$searchPurchaseOrdersAsyncAction =
      AsyncAction('_PurchaseOrderStore.searchPurchaseOrders', context: context);

  @override
  Future<void> searchPurchaseOrders(String query) {
    return _$searchPurchaseOrdersAsyncAction
        .run(() => super.searchPurchaseOrders(query));
  }

  late final _$loadPOItemsAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadPOItems', context: context);

  @override
  Future<void> loadPOItems(String poId) {
    return _$loadPOItemsAsyncAction.run(() => super.loadPOItems(poId));
  }

  late final _$selectPOAsyncAction =
      AsyncAction('_PurchaseOrderStore.selectPO', context: context);

  @override
  Future<void> selectPO(PurchaseOrderModel? po) {
    return _$selectPOAsyncAction.run(() => super.selectPO(po));
  }

  late final _$loadPOGRNsAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadPOGRNs', context: context);

  @override
  Future<void> loadPOGRNs(String poId) {
    return _$loadPOGRNsAsyncAction.run(() => super.loadPOGRNs(poId));
  }

  late final _$clearStatusFilterAsyncAction =
      AsyncAction('_PurchaseOrderStore.clearStatusFilter', context: context);

  @override
  Future<void> clearStatusFilter() {
    return _$clearStatusFilterAsyncAction.run(() => super.clearStatusFilter());
  }

  late final _$loadGRNsAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadGRNs', context: context);

  @override
  Future<void> loadGRNs() {
    return _$loadGRNsAsyncAction.run(() => super.loadGRNs());
  }

  late final _$loadGRNsByPOAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadGRNsByPO', context: context);

  @override
  Future<void> loadGRNsByPO(String poId) {
    return _$loadGRNsByPOAsyncAction.run(() => super.loadGRNsByPO(poId));
  }

  late final _$loadDraftGRNsAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadDraftGRNs', context: context);

  @override
  Future<void> loadDraftGRNs() {
    return _$loadDraftGRNsAsyncAction.run(() => super.loadDraftGRNs());
  }

  late final _$createGRNAsyncAction =
      AsyncAction('_PurchaseOrderStore.createGRN', context: context);

  @override
  Future<String> createGRN(GRNModel grn, List<GRNItemModel> items) {
    return _$createGRNAsyncAction.run(() => super.createGRN(grn, items));
  }

  late final _$updateGRNAsyncAction =
      AsyncAction('_PurchaseOrderStore.updateGRN', context: context);

  @override
  Future<void> updateGRN(GRNModel grn, List<GRNItemModel> items) {
    return _$updateGRNAsyncAction.run(() => super.updateGRN(grn, items));
  }

  late final _$deleteGRNAsyncAction =
      AsyncAction('_PurchaseOrderStore.deleteGRN', context: context);

  @override
  Future<void> deleteGRN(String grnId) {
    return _$deleteGRNAsyncAction.run(() => super.deleteGRN(grnId));
  }

  late final _$loadGRNItemsAsyncAction =
      AsyncAction('_PurchaseOrderStore.loadGRNItems', context: context);

  @override
  Future<void> loadGRNItems(String grnId) {
    return _$loadGRNItemsAsyncAction.run(() => super.loadGRNItems(grnId));
  }

  late final _$selectGRNAsyncAction =
      AsyncAction('_PurchaseOrderStore.selectGRN', context: context);

  @override
  Future<void> selectGRN(GRNModel? grn) {
    return _$selectGRNAsyncAction.run(() => super.selectGRN(grn));
  }

  late final _$confirmGRNAsyncAction =
      AsyncAction('_PurchaseOrderStore.confirmGRN', context: context);

  @override
  Future<List<GRNItemModel>> confirmGRN(String grnId) {
    return _$confirmGRNAsyncAction.run(() => super.confirmGRN(grnId));
  }

  late final _$cancelGRNAsyncAction =
      AsyncAction('_PurchaseOrderStore.cancelGRN', context: context);

  @override
  Future<void> cancelGRN(String grnId) {
    return _$cancelGRNAsyncAction.run(() => super.cancelGRN(grnId));
  }

  late final _$_PurchaseOrderStoreActionController =
      ActionController(name: '_PurchaseOrderStore', context: context);

  @override
  void clearPOSelection() {
    final _$actionInfo = _$_PurchaseOrderStoreActionController.startAction(
        name: '_PurchaseOrderStore.clearPOSelection');
    try {
      return super.clearPOSelection();
    } finally {
      _$_PurchaseOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearGRNSelection() {
    final _$actionInfo = _$_PurchaseOrderStoreActionController.startAction(
        name: '_PurchaseOrderStore.clearGRNSelection');
    try {
      return super.clearGRNSelection();
    } finally {
      _$_PurchaseOrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
purchaseOrders: ${purchaseOrders},
searchResults: ${searchResults},
currentPOItems: ${currentPOItems},
searchQuery: ${searchQuery},
selectedPO: ${selectedPO},
statusFilter: ${statusFilter},
grns: ${grns},
currentGRNItems: ${currentGRNItems},
selectedGRN: ${selectedGRN},
currentPOGRNs: ${currentPOGRNs},
receivablePOs: ${receivablePOs},
poCount: ${poCount},
draftPOCount: ${draftPOCount},
sentPOCount: ${sentPOCount},
pendingReceivingCount: ${pendingReceivingCount},
hasPOSelection: ${hasPOSelection},
hasGRNSelection: ${hasGRNSelection},
grnCount: ${grnCount},
draftGRNCount: ${draftGRNCount}
    ''';
  }
}
