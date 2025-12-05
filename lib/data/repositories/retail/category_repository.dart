
import 'package:hive/hive.dart';

/// Repository layer for Category data access
/// Handles all Hive database operations for categories
class CategoryRepository {
  late Box<String> _categoryBox;

  CategoryRepository() {
    _categoryBox = Hive.box<String>('categories');
  }

  /// Get all categories from Hive
  Future<List<String>> getAllCategories() async {
    return _categoryBox.values.toList();
  }

  /// Add a new category to Hive
  Future<void> addCategory(String category) async {
    // Check if category already exists
    if (!_categoryBox.values.contains(category)) {
      await _categoryBox.add(category);
    }
  }

  /// Delete a category from Hive
  Future<void> deleteCategory(String category) async {
    final key = _categoryBox.keys.firstWhere(
      (key) => _categoryBox.get(key) == category,
      orElse: () => null,
    );

    if (key != null) {
      await _categoryBox.delete(key);
    }
  }

  /// Check if category exists
  bool categoryExists(String category) {
    return _categoryBox.values.contains(category);
  }

  /// Clear all categories
  Future<void> clearAll() async {
    await _categoryBox.clear();
  }

  /// Get total category count
  int getCategoryCount() {
    return _categoryBox.length;
  }

  /// Add default categories if empty
  Future<void> addDefaultCategories() async {
    if (_categoryBox.isEmpty) {
      final defaults = [
        'Electronics',
        'Clothing',
        'Groceries',
        'Uncategorized',
      ];

      for (var category in defaults) {
        await addCategory(category);
      }
    }
  }
}