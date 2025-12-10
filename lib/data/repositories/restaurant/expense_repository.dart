import 'package:hive/hive.dart';

import '../../models/restaurant/db/expensel_316.dart';
import '../../models/restaurant/db/expensemodel_315.dart';

/// Repository layer for Expense data access
class ExpenseRepository {
  static const String _categoryBoxName = 'expenseCategories'; // Fixed: was 'expenseCategory'
  static const String _expenseBoxName = 'expenses'; // Fixed: was 'expenseBox'
  late Box<ExpenseCategory> _categoryBox;
  late Box<Expense> _expenseBox;

  ExpenseRepository() {
    _categoryBox = Hive.box<ExpenseCategory>(_categoryBoxName);
    _expenseBox = Hive.box<Expense>(_expenseBoxName);
  }

  // ==================== EXPENSE CATEGORY ====================

  List<ExpenseCategory> getAllCategories() {
    return _categoryBox.values.toList();
  }

  Future<void> addCategory(ExpenseCategory category) async {
    await _categoryBox.put(category.id, category);
  }

  Future<void> updateCategory(ExpenseCategory category) async {
    await _categoryBox.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    await _categoryBox.delete(id);
  }

  ExpenseCategory? getCategoryById(String id) {
    return _categoryBox.get(id);
  }

  // ==================== EXPENSES ====================

  List<Expense> getAllExpenses() {
    return _expenseBox.values.toList();
  }

  Future<void> addExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense);
  }

  Future<void> deleteExpense(String id) async {
    await _expenseBox.delete(id);
  }

  Expense? getExpenseById(String id) {
    return _expenseBox.get(id);
  }

  List<Expense> getExpensesByCategory(String categoryId) {
    return _expenseBox.values
        .where((expense) => expense.categoryOfExpense == categoryId)
        .toList();
  }

  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    return _expenseBox.values.where((expense) {
      return expense.dateandTime.isAfter(start) && expense.dateandTime.isBefore(end);
    }).toList();
  }

  List<Expense> getTodaysExpenses() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getExpensesByDateRange(startOfDay, endOfDay);
  }

  double getTotalExpenses() {
    double total = 0;
    for (var expense in _expenseBox.values) {
      total += expense.amount;
    }
    return total;
  }

  double getTodaysTotalExpenses() {
    double total = 0;
    for (var expense in getTodaysExpenses()) {
      total += expense.amount;
    }
    return total;
  }

  int getExpenseCount() {
    return _expenseBox.length;
  }

  Future<void> clearAllExpenses() async {
    await _expenseBox.clear();
  }

  Future<void> clearAllCategories() async {
    await _categoryBox.clear();
  }
}