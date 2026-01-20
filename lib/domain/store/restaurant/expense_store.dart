import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/expensel_316.dart';
import '../../../data/repositories/restaurant/expense_repository.dart';

part 'expense_store.g.dart';

class ExpenseStore = _ExpenseStore with _$ExpenseStore;

abstract class _ExpenseStore with Store {
  final ExpenseRepository _repository;

  _ExpenseStore(this._repository);

  @observable
  ObservableList<Expense> expenses = ObservableList<Expense>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedCategory;

  @observable
  DateTime? startDate;

  @observable
  DateTime? endDate;

  // Computed properties
  @computed
  List<Expense> get filteredExpenses {
    var result = expenses.toList();

    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result
          .where((expense) =>
              (expense.reason?.toLowerCase().contains(lowercaseQuery) ?? false))
          .toList();
    }

    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      result = result
          .where((expense) => expense.categoryOfExpense == selectedCategory)
          .toList();
    }

    if (startDate != null && endDate != null) {
      result = result
          .where((expense) =>
              expense.dateandTime.isAfter(startDate!.subtract(Duration(days: 1))) &&
              expense.dateandTime.isBefore(endDate!.add(Duration(days: 1))))
          .toList();
    }

    return result;
  }

  @computed
  double get totalExpenses =>
      expenses.fold<double>(0.0, (double sum, expense) => sum + expense.amount);

  @computed
  double get filteredTotalExpenses => filteredExpenses.fold<double>(
      0.0, (double sum, expense) => sum + expense.amount);

  @computed
  int get totalExpenseCount => expenses.length;

  // Actions
  @action
  Future<void> loadExpenses() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedExpenses = await _repository.getAllExpenses();
      expenses = ObservableList.of(loadedExpenses);
    } catch (e) {
      errorMessage = 'Failed to load expenses: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadExpenses();
  }

  @action
  Future<bool> addExpense(Expense expense) async {
    try {
      await _repository.addExpense(expense);
      expenses.add(expense);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add expense: $e';
      return false;
    }
  }

  @action
  Future<Expense?> getExpenseById(String id) async {
    try {
      return await _repository.getExpenseById(id);
    } catch (e) {
      errorMessage = 'Failed to get expense: $e';
      return null;
    }
  }

  @action
  Future<bool> updateExpense(Expense updatedExpense) async {
    try {
      await _repository.updateExpense(updatedExpense);
      final index = expenses.indexWhere((e) => e.id == updatedExpense.id);
      if (index != -1) {
        expenses[index] = updatedExpense;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update expense: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteExpense(String id) async {
    try {
      await _repository.deleteExpense(id);
      expenses.removeWhere((e) => e.id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete expense: $e';
      return false;
    }
  }

  @action
  Future<List<Expense>> getTodaysExpenses() async {
    try {
      return await _repository.getTodaysExpenses();
    } catch (e) {
      errorMessage = 'Failed to get todays expenses: $e';
      return [];
    }
  }

  @action
  Future<double> getTotalExpensesByCategory(String categoryId) async {
    try {
      return await _repository.getTotalExpensesByCategory(categoryId);
    } catch (e) {
      errorMessage = 'Failed to get total expenses by category: $e';
      return 0.0;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void setCategoryFilter(String? category) {
    selectedCategory = category;
  }

  @action
  void setDateRange(DateTime? start, DateTime? end) {
    startDate = start;
    endDate = end;
  }

  @action
  void clearDateFilter() {
    startDate = null;
    endDate = null;
  }

  @action
  void clearFilters() {
    searchQuery = '';
    selectedCategory = null;
    startDate = null;
    endDate = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}