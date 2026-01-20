// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ItemStore on _ItemStore, Store {
  Computed<List<Items>>? _$filteredItemsComputed;

  @override
  List<Items> get filteredItems => (_$filteredItemsComputed ??=
          Computed<List<Items>>(() => super.filteredItems,
              name: '_ItemStore.filteredItems'))
      .value;
  Computed<int>? _$itemCountComputed;

  @override
  int get itemCount => (_$itemCountComputed ??=
          Computed<int>(() => super.itemCount, name: '_ItemStore.itemCount'))
      .value;
  Computed<int>? _$filteredItemCountComputed;

  @override
  int get filteredItemCount => (_$filteredItemCountComputed ??= Computed<int>(
          () => super.filteredItemCount,
          name: '_ItemStore.filteredItemCount'))
      .value;
  Computed<bool>? _$hasItemsComputed;

  @override
  bool get hasItems => (_$hasItemsComputed ??=
          Computed<bool>(() => super.hasItems, name: '_ItemStore.hasItems'))
      .value;
  Computed<List<Items>>? _$enabledItemsComputed;

  @override
  List<Items> get enabledItems => (_$enabledItemsComputed ??=
          Computed<List<Items>>(() => super.enabledItems,
              name: '_ItemStore.enabledItems'))
      .value;
  Computed<List<Items>>? _$disabledItemsComputed;

  @override
  List<Items> get disabledItems => (_$disabledItemsComputed ??=
          Computed<List<Items>>(() => super.disabledItems,
              name: '_ItemStore.disabledItems'))
      .value;
  Computed<List<Items>>? _$lowStockItemsComputed;

  @override
  List<Items> get lowStockItems => (_$lowStockItemsComputed ??=
          Computed<List<Items>>(() => super.lowStockItems,
              name: '_ItemStore.lowStockItems'))
      .value;
  Computed<List<Items>>? _$outOfStockItemsComputed;

  @override
  List<Items> get outOfStockItems => (_$outOfStockItemsComputed ??=
          Computed<List<Items>>(() => super.outOfStockItems,
              name: '_ItemStore.outOfStockItems'))
      .value;
  Computed<int>? _$lowStockCountComputed;

  @override
  int get lowStockCount =>
      (_$lowStockCountComputed ??= Computed<int>(() => super.lowStockCount,
              name: '_ItemStore.lowStockCount'))
          .value;
  Computed<int>? _$outOfStockCountComputed;

  @override
  int get outOfStockCount =>
      (_$outOfStockCountComputed ??= Computed<int>(() => super.outOfStockCount,
              name: '_ItemStore.outOfStockCount'))
          .value;

  late final _$itemsAtom = Atom(name: '_ItemStore.items', context: context);

  @override
  ObservableList<Items> get items {
    _$itemsAtom.reportRead();
    return super.items;
  }

  @override
  set items(ObservableList<Items> value) {
    _$itemsAtom.reportWrite(value, super.items, () {
      super.items = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ItemStore.isLoading', context: context);

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
      Atom(name: '_ItemStore.errorMessage', context: context);

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
      Atom(name: '_ItemStore.searchQuery', context: context);

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

  late final _$selectedCategoryIdAtom =
      Atom(name: '_ItemStore.selectedCategoryId', context: context);

  @override
  String? get selectedCategoryId {
    _$selectedCategoryIdAtom.reportRead();
    return super.selectedCategoryId;
  }

  @override
  set selectedCategoryId(String? value) {
    _$selectedCategoryIdAtom.reportWrite(value, super.selectedCategoryId, () {
      super.selectedCategoryId = value;
    });
  }

  late final _$vegFilterAtom =
      Atom(name: '_ItemStore.vegFilter', context: context);

  @override
  String? get vegFilter {
    _$vegFilterAtom.reportRead();
    return super.vegFilter;
  }

  @override
  set vegFilter(String? value) {
    _$vegFilterAtom.reportWrite(value, super.vegFilter, () {
      super.vegFilter = value;
    });
  }

  late final _$enabledFilterAtom =
      Atom(name: '_ItemStore.enabledFilter', context: context);

  @override
  bool? get enabledFilter {
    _$enabledFilterAtom.reportRead();
    return super.enabledFilter;
  }

  @override
  set enabledFilter(bool? value) {
    _$enabledFilterAtom.reportWrite(value, super.enabledFilter, () {
      super.enabledFilter = value;
    });
  }

  late final _$showLowStockOnlyAtom =
      Atom(name: '_ItemStore.showLowStockOnly', context: context);

  @override
  bool get showLowStockOnly {
    _$showLowStockOnlyAtom.reportRead();
    return super.showLowStockOnly;
  }

  @override
  set showLowStockOnly(bool value) {
    _$showLowStockOnlyAtom.reportWrite(value, super.showLowStockOnly, () {
      super.showLowStockOnly = value;
    });
  }

  late final _$showOutOfStockOnlyAtom =
      Atom(name: '_ItemStore.showOutOfStockOnly', context: context);

  @override
  bool get showOutOfStockOnly {
    _$showOutOfStockOnlyAtom.reportRead();
    return super.showOutOfStockOnly;
  }

  @override
  set showOutOfStockOnly(bool value) {
    _$showOutOfStockOnlyAtom.reportWrite(value, super.showOutOfStockOnly, () {
      super.showOutOfStockOnly = value;
    });
  }

  late final _$loadItemsAsyncAction =
      AsyncAction('_ItemStore.loadItems', context: context);

  @override
  Future<void> loadItems() {
    return _$loadItemsAsyncAction.run(() => super.loadItems());
  }

  late final _$addItemAsyncAction =
      AsyncAction('_ItemStore.addItem', context: context);

  @override
  Future<bool> addItem(Items item) {
    return _$addItemAsyncAction.run(() => super.addItem(item));
  }

  late final _$updateItemAsyncAction =
      AsyncAction('_ItemStore.updateItem', context: context);

  @override
  Future<bool> updateItem(Items item) {
    return _$updateItemAsyncAction.run(() => super.updateItem(item));
  }

  late final _$deleteItemAsyncAction =
      AsyncAction('_ItemStore.deleteItem', context: context);

  @override
  Future<bool> deleteItem(String itemId) {
    return _$deleteItemAsyncAction.run(() => super.deleteItem(itemId));
  }

  late final _$toggleItemStatusAsyncAction =
      AsyncAction('_ItemStore.toggleItemStatus', context: context);

  @override
  Future<bool> toggleItemStatus(String itemId) {
    return _$toggleItemStatusAsyncAction
        .run(() => super.toggleItemStatus(itemId));
  }

  late final _$updateStockAsyncAction =
      AsyncAction('_ItemStore.updateStock', context: context);

  @override
  Future<bool> updateStock(String itemId, double newQuantity) {
    return _$updateStockAsyncAction
        .run(() => super.updateStock(itemId, newQuantity));
  }

  late final _$refreshAsyncAction =
      AsyncAction('_ItemStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$_ItemStoreActionController =
      ActionController(name: '_ItemStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSearch() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.clearSearch');
    try {
      return super.clearSearch();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setCategoryFilter(String? categoryId) {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.setCategoryFilter');
    try {
      return super.setCategoryFilter(categoryId);
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCategoryFilter() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.clearCategoryFilter');
    try {
      return super.clearCategoryFilter();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setVegFilter(String? vegStatus) {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.setVegFilter');
    try {
      return super.setVegFilter(vegStatus);
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearVegFilter() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.clearVegFilter');
    try {
      return super.clearVegFilter();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setEnabledFilter(bool? enabled) {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.setEnabledFilter');
    try {
      return super.setEnabledFilter(enabled);
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearEnabledFilter() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.clearEnabledFilter');
    try {
      return super.clearEnabledFilter();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleLowStockFilter() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.toggleLowStockFilter');
    try {
      return super.toggleLowStockFilter();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleOutOfStockFilter() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.toggleOutOfStockFilter');
    try {
      return super.toggleOutOfStockFilter();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearAllFilters() {
    final _$actionInfo = _$_ItemStoreActionController.startAction(
        name: '_ItemStore.clearAllFilters');
    try {
      return super.clearAllFilters();
    } finally {
      _$_ItemStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
items: ${items},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedCategoryId: ${selectedCategoryId},
vegFilter: ${vegFilter},
enabledFilter: ${enabledFilter},
showLowStockOnly: ${showLowStockOnly},
showOutOfStockOnly: ${showOutOfStockOnly},
filteredItems: ${filteredItems},
itemCount: ${itemCount},
filteredItemCount: ${filteredItemCount},
hasItems: ${hasItems},
enabledItems: ${enabledItems},
disabledItems: ${disabledItems},
lowStockItems: ${lowStockItems},
outOfStockItems: ${outOfStockItems},
lowStockCount: ${lowStockCount},
outOfStockCount: ${outOfStockCount}
    ''';
  }
}
