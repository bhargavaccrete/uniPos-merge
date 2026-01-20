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
  Computed<double>? _$totalExpensesComputed;

  @override
  double get totalExpenses =>
      (_$totalExpensesComputed ??= Computed<double>(() => super.totalExpenses,
              name: '_ExpenseStore.totalExpenses'))
          .value;
  Computed<double>? _$filteredTotalExpensesComputed;

  @override
  double get filteredTotalExpenses => (_$filteredTotalExpensesComputed ??=
          Computed<double>(() => super.filteredTotalExpenses,
              name: '_ExpenseStore.filteredTotalExpenses'))
      .value;
  Computed<int>? _$totalExpenseCountComputed;

  @override
  int get totalExpenseCount => (_$totalExpenseCountComputed ??= Computed<int>(
          () => super.totalExpenseCount,
          name: '_ExpenseStore.totalExpenseCount'))
      .value;

  late final _$expensesAtom =
      Atom(name: '_ExpenseStore.expenses', context: context);

  @override
  ObservableList<Expense> get expenses {
    _$expensesAtom.reportRead();
    return super.expenses;
  }

  @override
  set expenses(ObservableList<Expense> value) {
    _$expensesAtom.reportWrite(value, super.expenses, () {
      super.expenses = value;
    });
  }

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

  late final _$searchQueryAtom =
      Atom(name: '_ExpenseStore.searchQuery', context: context);

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

  late final _$selectedCategoryAtom =
      Atom(name: '_ExpenseStore.selectedCategory', context: context);

  @override
  String? get selectedCategory {
    _$selectedCategoryAtom.reportRead();
    return super.selectedCategory;
  }

  @override
  set selectedCategory(String? value) {
    _$selectedCategoryAtom.reportWrite(value, super.selectedCategory, () {
      super.selectedCategory = value;
    });
  }

  late final _$startDateAtom =
      Atom(name: '_ExpenseStore.startDate', context: context);

  @override
  DateTime? get startDate {
    _$startDateAtom.reportRead();
    return super.startDate;
  }

  @override
  set startDate(DateTime? value) {
    _$startDateAtom.reportWrite(value, super.startDate, () {
      super.startDate = value;
    });
  }

  late final _$endDateAtom =
      Atom(name: '_ExpenseStore.endDate', context: context);

  @override
  DateTime? get endDate {
    _$endDateAtom.reportRead();
    return super.endDate;
  }

  @override
  set endDate(DateTime? value) {
    _$endDateAtom.reportWrite(value, super.endDate, () {
      super.endDate = value;
    });
  }

  late final _$loadExpensesAsyncAction =
      AsyncAction('_ExpenseStore.loadExpenses', context: context);

  @override
  Future<void> loadExpenses() {
    return _$loadExpensesAsyncAction.run(() => super.loadExpenses());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_ExpenseStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addExpenseAsyncAction =
      AsyncAction('_ExpenseStore.addExpense', context: context);

  @override
  Future<bool> addExpense(Expense expense) {
    return _$addExpenseAsyncAction.run(() => super.addExpense(expense));
  }

  late final _$getExpenseByIdAsyncAction =
      AsyncAction('_ExpenseStore.getExpenseById', context: context);

  @override
  Future<Expense?> getExpenseById(String id) {
    return _$getExpenseByIdAsyncAction.run(() => super.getExpenseById(id));
  }

  late final _$updateExpenseAsyncAction =
      AsyncAction('_ExpenseStore.updateExpense', context: context);

  @override
  Future<bool> updateExpense(Expense updatedExpense) {
    return _$updateExpenseAsyncAction
        .run(() => super.updateExpense(updatedExpense));
  }

  late final _$deleteExpenseAsyncAction =
      AsyncAction('_ExpenseStore.deleteExpense', context: context);

  @override
  Future<bool> deleteExpense(String id) {
    return _$deleteExpenseAsyncAction.run(() => super.deleteExpense(id));
  }

  late final _$getTodaysExpensesAsyncAction =
      AsyncAction('_ExpenseStore.getTodaysExpenses', context: context);

  @override
  Future<List<Expense>> getTodaysExpenses() {
    return _$getTodaysExpensesAsyncAction.run(() => super.getTodaysExpenses());
  }

  late final _$getTotalExpensesByCategoryAsyncAction =
      AsyncAction('_ExpenseStore.getTotalExpensesByCategory', context: context);

  @override
  Future<double> getTotalExpensesByCategory(String categoryId) {
    return _$getTotalExpensesByCategoryAsyncAction
        .run(() => super.getTotalExpensesByCategory(categoryId));
  }

  late final _$_ExpenseStoreActionController =
      ActionController(name: '_ExpenseStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setCategoryFilter(String? category) {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.setCategoryFilter');
    try {
      return super.setCategoryFilter(category);
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setDateRange(DateTime? start, DateTime? end) {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.setDateRange');
    try {
      return super.setDateRange(start, end);
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearDateFilter() {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.clearDateFilter');
    try {
      return super.clearDateFilter();
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilters() {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_ExpenseStoreActionController.startAction(
        name: '_ExpenseStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_ExpenseStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
expenses: ${expenses},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedCategory: ${selectedCategory},
startDate: ${startDate},
endDate: ${endDate},
filteredExpenses: ${filteredExpenses},
totalExpenses: ${totalExpenses},
filteredTotalExpenses: ${filteredTotalExpenses},
totalExpenseCount: ${totalExpenseCount}
    ''';
  }
}
