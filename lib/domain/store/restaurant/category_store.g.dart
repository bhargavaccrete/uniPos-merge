// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CategoryStore on _CategoryStore, Store {
  Computed<List<Category>>? _$filteredCategoriesComputed;

  @override
  List<Category> get filteredCategories => (_$filteredCategoriesComputed ??=
          Computed<List<Category>>(() => super.filteredCategories,
              name: '_CategoryStore.filteredCategories'))
      .value;
  Computed<int>? _$categoryCountComputed;

  @override
  int get categoryCount =>
      (_$categoryCountComputed ??= Computed<int>(() => super.categoryCount,
              name: '_CategoryStore.categoryCount'))
          .value;
  Computed<bool>? _$hasCategoriesComputed;

  @override
  bool get hasCategories =>
      (_$hasCategoriesComputed ??= Computed<bool>(() => super.hasCategories,
              name: '_CategoryStore.hasCategories'))
          .value;

  late final _$categoriesAtom =
      Atom(name: '_CategoryStore.categories', context: context);

  @override
  ObservableList<Category> get categories {
    _$categoriesAtom.reportRead();
    return super.categories;
  }

  @override
  set categories(ObservableList<Category> value) {
    _$categoriesAtom.reportWrite(value, super.categories, () {
      super.categories = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_CategoryStore.isLoading', context: context);

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
      Atom(name: '_CategoryStore.errorMessage', context: context);

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
      Atom(name: '_CategoryStore.searchQuery', context: context);

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

  late final _$categoryItemsMapAtom =
      Atom(name: '_CategoryStore.categoryItemsMap', context: context);

  @override
  ObservableMap<String, List<Items>> get categoryItemsMap {
    _$categoryItemsMapAtom.reportRead();
    return super.categoryItemsMap;
  }

  @override
  set categoryItemsMap(ObservableMap<String, List<Items>> value) {
    _$categoryItemsMapAtom.reportWrite(value, super.categoryItemsMap, () {
      super.categoryItemsMap = value;
    });
  }

  late final _$loadCategoriesAsyncAction =
      AsyncAction('_CategoryStore.loadCategories', context: context);

  @override
  Future<void> loadCategories() {
    return _$loadCategoriesAsyncAction.run(() => super.loadCategories());
  }

  late final _$_loadCategoryItemsAsyncAction =
      AsyncAction('_CategoryStore._loadCategoryItems', context: context);

  @override
  Future<void> _loadCategoryItems() {
    return _$_loadCategoryItemsAsyncAction
        .run(() => super._loadCategoryItems());
  }

  late final _$addCategoryAsyncAction =
      AsyncAction('_CategoryStore.addCategory', context: context);

  @override
  Future<bool> addCategory(Category category) {
    return _$addCategoryAsyncAction.run(() => super.addCategory(category));
  }

  late final _$updateCategoryAsyncAction =
      AsyncAction('_CategoryStore.updateCategory', context: context);

  @override
  Future<bool> updateCategory(Category category) {
    return _$updateCategoryAsyncAction
        .run(() => super.updateCategory(category));
  }

  late final _$deleteCategoryAsyncAction =
      AsyncAction('_CategoryStore.deleteCategory', context: context);

  @override
  Future<bool> deleteCategory(String categoryId) {
    return _$deleteCategoryAsyncAction
        .run(() => super.deleteCategory(categoryId));
  }

  late final _$refreshAsyncAction =
      AsyncAction('_CategoryStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$_CategoryStoreActionController =
      ActionController(name: '_CategoryStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_CategoryStoreActionController.startAction(
        name: '_CategoryStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_CategoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSearch() {
    final _$actionInfo = _$_CategoryStoreActionController.startAction(
        name: '_CategoryStore.clearSearch');
    try {
      return super.clearSearch();
    } finally {
      _$_CategoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
categories: ${categories},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
categoryItemsMap: ${categoryItemsMap},
filteredCategories: ${filteredCategories},
categoryCount: ${categoryCount},
hasCategories: ${hasCategories}
    ''';
  }
}
