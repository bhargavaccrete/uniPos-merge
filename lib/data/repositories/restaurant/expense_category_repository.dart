import 'package:hive/hive.dart';
import 'package:unipos/core/config/app_config.dart';
import '../../models/restaurant/db/expensemodel_315.dart';

/// Repository layer for Expense Category data access (Restaurant)
/// Handles all Hive database operations for expense categories
class ExpenseCategoryRepository {
  late Box<ExpenseCategory> _expenseCategoryBox;

  ExpenseCategoryRepository() {
    final boxName = AppConfig.isRetail
        ? 'expenseCategory'
        : 'restaurant_expenseCategory';
    _expenseCategoryBox = Hive.box<ExpenseCategory>(boxName);
  }

  /// Add a new expense category
  Future<void> addExpenseCategory(ExpenseCategory category) async {
    await _expenseCategoryBox.put(category.id, category);
  }

  /// Get all expense categories
  Future<List<ExpenseCategory>> getAllExpenseCategories() async {
    return _expenseCategoryBox.values.toList();
  }

  /// Get expense category by ID
  Future<ExpenseCategory?> getExpenseCategoryById(String id) async {
    return _expenseCategoryBox.get(id);
  }

  /// Update expense category
  Future<void> updateExpenseCategory(ExpenseCategory category) async {
    await _expenseCategoryBox.put(category.id, category);
  }

  /// Delete expense category
  Future<void> deleteExpenseCategory(String id) async {
    await _expenseCategoryBox.delete(id);
  }

  /// Search expense categories by name
  Future<List<ExpenseCategory>> searchExpenseCategories(String query) async {
    if (query.isEmpty) return getAllExpenseCategories();

    final lowercaseQuery = query.toLowerCase();
    return _expenseCategoryBox.values
        .where(
            (category) => category.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get expense category count
  Future<int> getExpenseCategoryCount() async {
    return _expenseCategoryBox.length;
  }
}