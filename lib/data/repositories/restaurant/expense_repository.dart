import 'package:hive/hive.dart';
import 'package:unipos/core/config/app_config.dart';
import '../../models/restaurant/db/expensel_316.dart';

/// Repository layer for Expense data access (Restaurant)
/// Handles all Hive database operations for expenses
class ExpenseRepository {
  late Box<Expense> _expenseBox;

  ExpenseRepository() {
    final boxName =
        AppConfig.isRetail ? 'expenseBox' : 'restaurant_expenseBox';
    _expenseBox = Hive.box<Expense>(boxName);
  }

  /// Add a new expense
  Future<void> addExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense);
  }

  /// Get all expenses
  Future<List<Expense>> getAllExpenses() async {
    return _expenseBox.values.toList();
  }

  /// Get expense by ID
  Future<Expense?> getExpenseById(String id) async {
    return _expenseBox.get(id);
  }

  /// Update expense
  Future<void> updateExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense);
  }

  /// Delete expense
  Future<void> deleteExpense(String id) async {
    await _expenseBox.delete(id);
  }

  /// Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String categoryId) async {
    return _expenseBox.values
        .where((expense) => expense.categoryOfExpense == categoryId)
        .toList();
  }

  /// Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _expenseBox.values
        .where((expense) =>
            expense.dateandTime.isAfter(startDate.subtract(Duration(days: 1))) &&
            expense.dateandTime.isBefore(endDate.add(Duration(days: 1))))
        .toList();
  }

  /// Get today's expenses
  Future<List<Expense>> getTodaysExpenses() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getExpensesByDateRange(startOfDay, endOfDay);
  }

  /// Get total expenses
  Future<double> getTotalExpenses() async {
    final expenses = await getAllExpenses();
    return expenses.fold<double>(
        0.0, (double sum, expense) => sum + expense.amount);
  }

  /// Get total expenses by date range
  Future<double> getTotalExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final expenses = await getExpensesByDateRange(startDate, endDate);
    return expenses.fold<double>(
        0.0, (double sum, expense) => sum + expense.amount);
  }

  /// Get total expenses by category
  Future<double> getTotalExpensesByCategory(String categoryId) async {
    final expenses = await getExpensesByCategory(categoryId);
    return expenses.fold<double>(
        0.0, (double sum, expense) => sum + expense.amount);
  }

  /// Search expenses by reason
  Future<List<Expense>> searchExpenses(String query) async {
    if (query.isEmpty) return getAllExpenses();

    final lowercaseQuery = query.toLowerCase();
    return _expenseBox.values
        .where((expense) =>
            (expense.reason?.toLowerCase().contains(lowercaseQuery) ?? false))
        .toList();
  }

  /// Get expense count
  Future<int> getExpenseCount() async {
    return _expenseBox.length;
  }
}