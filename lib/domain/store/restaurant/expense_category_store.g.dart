// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_category_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ExpenseCategoryStore on _ExpenseCategoryStore, Store {
  Computed<List<ExpenseCategory>>? _$filteredCategoriesComputed;

  @override
  List<ExpenseCategory> get filteredCategories =>
      (_$filteredCategoriesComputed ??= Computed<List<ExpenseCategory>>(
              () => super.filteredCategories,
              name: '_ExpenseCategoryStore.filteredCategories'))
          .value;
  Computed<List<ExpenseCategory>>? _$enabledCategoriesComputed;

  @override
  List<ExpenseCategory> get enabledCategories =>
      (_$enabledCategoriesComputed ??= Computed<List<ExpenseCategory>>(
              () => super.enabledCategories,
              name: '_ExpenseCategoryStore.enabledCategories'))
          .value;
  Computed<int>? _$totalCategoriesComputed;

  @override
  int get totalCategories =>
      (_$totalCategoriesComputed ??= Computed<int>(() => super.totalCategories,
              name: '_ExpenseCategoryStore.totalCategories'))
          .value;

  late final _$categoriesAtom =
      Atom(name: '_ExpenseCategoryStore.categories', context: context);

  @override
  ObservableList<ExpenseCategory> get categories {
    _$categoriesAtom.reportRead();
    return super.categories;
  }

  @override
  set categories(ObservableList<ExpenseCategory> value) {
    _$categoriesAtom.reportWrite(value, super.categories, () {
      super.categories = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ExpenseCategoryStore.isLoading', context: context);

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
      Atom(name: '_ExpenseCategoryStore.errorMessage', context: context);

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
      Atom(name: '_ExpenseCategoryStore.searchQuery', context: context);

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

  late final _$loadCategoriesAsyncAction =
      AsyncAction('_ExpenseCategoryStore.loadCategories', context: context);

  @override
  Future<void> loadCategories() {
    return _$loadCategoriesAsyncAction.run(() => super.loadCategories());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_ExpenseCategoryStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addCategoryAsyncAction =
      AsyncAction('_ExpenseCategoryStore.addCategory', context: context);

  @override
  Future<bool> addCategory(ExpenseCategory category) {
    return _$addCategoryAsyncAction.run(() => super.addCategory(category));
  }

  late final _$getCategoryByIdAsyncAction =
      AsyncAction('_ExpenseCategoryStore.getCategoryById', context: context);

  @override
  Future<ExpenseCategory?> getCategoryById(String id) {
    return _$getCategoryByIdAsyncAction.run(() => super.getCategoryById(id));
  }

  late final _$updateCategoryAsyncAction =
      AsyncAction('_ExpenseCategoryStore.updateCategory', context: context);

  @override
  Future<bool> updateCategory(ExpenseCategory updatedCategory) {
    return _$updateCategoryAsyncAction
        .run(() => super.updateCategory(updatedCategory));
  }

  late final _$deleteCategoryAsyncAction =
      AsyncAction('_ExpenseCategoryStore.deleteCategory', context: context);

  @override
  Future<bool> deleteCategory(String id) {
    return _$deleteCategoryAsyncAction.run(() => super.deleteCategory(id));
  }

  late final _$_ExpenseCategoryStoreActionController =
      ActionController(name: '_ExpenseCategoryStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_ExpenseCategoryStoreActionController.startAction(
        name: '_ExpenseCategoryStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_ExpenseCategoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_ExpenseCategoryStoreActionController.startAction(
        name: '_ExpenseCategoryStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_ExpenseCategoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
categories: ${categories},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
filteredCategories: ${filteredCategories},
enabledCategories: ${enabledCategories},
totalCategories: ${totalCategories}
    ''';
  }
}
