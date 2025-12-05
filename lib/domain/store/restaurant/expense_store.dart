import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/expensel_316.dart';
import '../../../data/models/restaurant/db/expensemodel_315.dart';
import '../../../data/repositories/restaurant/expense_repository.dart';

part 'expense_store.g.dart';

class ExpenseStore = _ExpenseStore with _$ExpenseStore;

abstract class _ExpenseStore with Store {
  final ExpenseRepository _expenseRepository = locator<ExpenseRepository>();

  final ObservableList<Expense> expenses = ObservableList<Expense>();
  final ObservableList<ExpenseCategory> categories =
      ObservableList<ExpenseCategory>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? selectedCategoryId;

  _ExpenseStore() {
    _init();
  }

  Future<void> _init() async {
    await loadCategories();
    await loadExpenses();
  }

  @computed
  List<Expense> get filteredExpenses {
    if (selectedCategoryId == null) {
      return expenses.toList();
    }
    return expenses
        .where((expense) => expense.categoryOfExpense == selectedCategoryId)
        .toList();
  }

  @computed
  List<Expense> get todaysExpenses {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return expenses.where((expense) => expense.dateandTime.isAfter(startOfDay)).toList();
  }

  @computed
  double get totalExpenses {
    double total = 0;
    for (var expense in expenses) {
      total += expense.amount;
    }
    return total;
  }

  @computed
  double get todaysTotalExpenses {
    double total = 0;
    for (var expense in todaysExpenses) {
      total += expense.amount;
    }
    return total;
  }

  @computed
  int get totalExpenseCount => expenses.length;

  @computed
  int get categoryCount => categories.length;

  // ==================== CATEGORY ACTIONS ====================

  @action
  Future<void> loadCategories() async {
    try {
      final loaded = _expenseRepository.getAllCategories();
      categories.clear();
      categories.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load categories: $e';
    }
  }

  @action
  Future<void> addCategory(ExpenseCategory category) async {
    try {
      await _expenseRepository.addCategory(category);
      categories.add(category);
    } catch (e) {
      errorMessage = 'Failed to add category: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateCategory(ExpenseCategory category) async {
    try {
      await _expenseRepository.updateCategory(category);
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        categories[index] = category;
      }
    } catch (e) {
      errorMessage = 'Failed to update category: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteCategory(String id) async {
    try {
      await _expenseRepository.deleteCategory(id);
      categories.removeWhere((category) => category.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete category: $e';
      rethrow;
    }
  }

  // ==================== EXPENSE ACTIONS ====================

  @action
  Future<void> loadExpenses() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _expenseRepository.getAllExpenses();
      expenses.clear();
      expenses.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load expenses: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addExpense(Expense expense) async {
    try {
      await _expenseRepository.addExpense(expense);
      expenses.add(expense);
    } catch (e) {
      errorMessage = 'Failed to add expense: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateExpense(Expense expense) async {
    try {
      await _expenseRepository.updateExpense(expense);
      final index = expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        expenses[index] = expense;
      }
    } catch (e) {
      errorMessage = 'Failed to update expense: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteExpense(String id) async {
    try {
      await _expenseRepository.deleteExpense(id);
      expenses.removeWhere((expense) => expense.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete expense: $e';
      rethrow;
    }
  }

  @action
  void setCategoryFilter(String? categoryId) {
    selectedCategoryId = categoryId;
  }

  @action
  void clearFilter() {
    selectedCategoryId = null;
  }

  ExpenseCategory? getCategoryById(String id) {
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  Expense? getExpenseById(String id) {
    try {
      return expenses.firstWhere((expense) => expense.id == id);
    } catch (e) {
      return null;
    }
  }
}