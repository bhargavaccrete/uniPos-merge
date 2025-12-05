// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ExpenseStore on _ExpenseStore, Store {
  Computed<List<Expense>>? _$filteredExpensesComputed;

  @override
  List<Expense> get filteredExpenses => (_$filteredExpensesComputed ??=
          Computed<List<Expense>>(() => super.filteredExpenses,
              name: '_ExpenseStore.filteredExpenses'))
      .value;
  Computed<List<Expense>>? _$todaysExpensesComputed;

  @override
  List<Expense> get todaysExpenses => (_$todaysExpensesComputed ??=
          Computed<List<Expense>>(() => super.todaysExpenses,
              name: '_ExpenseStore.todaysExpenses'))
      .value;
  Computed<double>? _$totalExpensesComputed;

  @override
  double get totalExpenses =>
      (_$totalExpensesComputed ??= Computed<double>(() => super.totalExpenses,
              name: '_ExpenseStore.totalExpenses'))
          .value;
  Computed<double>? _$todaysTotalExpensesComputed;

  @override
  double get todaysTotalExpenses => (_$todaysTotalExpensesComputed ??=
          Computed<double>(() => super.todaysTotalExpenses,
              name: '_ExpenseStore.todaysTotalExpenses'))
      .value;
  Computed<int>? _$totalExpenseCountComputed;

  @override
  int get totalExpenseCount => (_$totalExpenseCountComputed ??= Computed<int>(
          () => super.totalExpenseCount,
          name: '_ExpenseStore.totalExpenseCount'))
      .value;
  Computed<int>? _$categoryCountComputed;

  @override
  int get categoryCount =>
      (_$categoryCountComputed ??= Computed<int>(() => super.categoryCount,
              name: '_ExpenseStore.categoryCount'))
          .value;

  late final _$isLoadingAtom =
      Atom(name: '_ExpenseStore.isLoading', context: context);

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
      Atom(name: '_ExpenseStore.errorMessage', context: context);

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

  late final _$selectedCategoryIdAtom =
      Atom(name: '_ExpenseStore.selectedCategoryId', context: context);

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

  late final _$loadCategoriesAsyncAction =
      AsyncAction('_ExpenseStore.loadCategories', context: context);

  @override
  Future<void> loadCategories() {
    return _$loadCategoriesAsyncAction.run(() => super.loadCategories());
  }

  late final _$addCategoryAsyncAction =
      AsyncAction('_ExpenseStore.addCategory', context: context);

  @override
  Future<void> addCategory(ExpenseCategory category) {
    return _$addCategoryAsyncAction.run(() => super.addCategory(category));
  }

  late final _$updateCategoryAsyncAction =
      AsyncAction('_ExpenseStore.updateCategory', context: context);

  @override
  Future<void> updateCategory(ExpenseCategory category) {
    return _$updateCategoryAsyncAction
        .run(() => super.updateCategory(category));
  }

  late final _$deleteCategoryAsyncAction =
      AsyncAction('_ExpenseStore.deleteCategory', context: context);

  @override
  Future<void> deleteCategory(String id) {
    return _$deleteCategoryAsyncAction.run(() => super.deleteCategory(id));
  }

  late final _$loadExpensesAsyncAction =
      AsyncAction('_ExpenseStore.loadExpenses', context: context);

  @override
  Future<void> loadExpenses() {
    return _$loadExpensesAsyncAction.run(() => super.loadExpenses());
  }

  late final _$addExpenseAsyncAction =
      AsyncAction('_ExpenseStore.addExpense', context: context);

  @override
  Future<void> addExpense(Expense expense) {
    return _$addExpenseAsyncAction.run(() => super.addExpense(expense));
  }

  late final _$updateExpenseAsyncAction =
      AsyncAction('_ExpenseStore.updateExpense', context: context);

  @override
  Future<void> updateExpense(Expense expense) {
    return _$updateExpenseAsyncAction.run(() => super.updateExpense(expense));
  }

  late final _$deleteExpenseAsyncAction =
      AsyncAction('_ExpenseStore.deleteExpense', context: context);

  @override
  Future<void> deleteExpense(String id) {
    return _$deleteExpenseAsyncAction.run(() => super.deleteExpense(id));
  }

  late final _$_ExpenseStoreActionController =
      ActionController(name: '_ExpenseStore', context: context);

  @override
  void setCategoryFilter(String? categoryId) {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.setCategoryFilter');
    try {
      return super.setCategoryFilter(categoryId);
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilter() {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.clearFilter');
    try {
      return super.clearFilter();
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
selectedCategoryId: ${selectedCategoryId},
filteredExpenses: ${filteredExpenses},
todaysExpenses: ${todaysExpenses},
totalExpenses: ${totalExpenses},
todaysTotalExpenses: ${todaysTotalExpenses},
totalExpenseCount: ${totalExpenseCount},
categoryCount: ${categoryCount}
    ''';
  }
}
