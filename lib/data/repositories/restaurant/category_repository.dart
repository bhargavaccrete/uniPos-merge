import 'package:hive/hive.dart';

import '../../models/restaurant/db/categorymodel_300.dart';
import '../../models/restaurant/db/itemmodel_302.dart';

/// Repository layer for Category data access
/// Handles all Hive database operations for categories
class CategoryRepository {
  static const String _boxName = 'restaurant_categories';
  static const String _itemBoxName = 'itemBoxs';
  late Box<Category> _categoryBox;
  late Box<Items> _itemBox;

  CategoryRepository() {
    _categoryBox = Hive.box<Category>(_boxName);
    _itemBox = Hive.box<Items>(_itemBoxName);
  }

  /// Get all categories from Hive
  Future<List<Category>> getAllCategories() async {
    return _categoryBox.values.toList();
  }

  /// Add a new category to Hive
  Future<void> addCategory(Category category) async {
    await _categoryBox.put(category.id, category);
  }

  /// Update an existing category in Hive
  Future<void> updateCategory(Category category) async {
    await _categoryBox.put(category.id, category);
  }

  /// Delete a category from Hive (with cascade delete of items)
  Future<void> deleteCategory(String id) async {
    await _categoryBox.delete(id);

    // Cascade delete items associated with this category
    final itemsToDelete = _itemBox.values
        .where((item) => item.categoryOfItem == id)
        .toList();

    for (var item in itemsToDelete) {
      await item.delete();
    }
  }

  /// Get a category by ID
  Category? getCategoryById(String id) {
    return _categoryBox.get(id);
  }

  /// Check if category exists
  bool categoryExists(String id) {
    return _categoryBox.containsKey(id);
  }

  /// Get total category count
  int getCategoryCount() {
    return _categoryBox.length;
  }

  /// Get item count for a category
  int getItemCountForCategory(String categoryId) {
    return _itemBox.values
        .where((item) => item.categoryOfItem == categoryId)
        .length;
  }

  /// Search categories by name
  List<Category> searchCategories(String query) {
    final lowerQuery = query.toLowerCase();
    return _categoryBox.values
        .where((category) => category.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Clear all categories
  Future<void> clearAll() async {
    await _categoryBox.clear();
  }

  /// Bulk import categories
  Future<void> importCategories(List<Category> categories) async {
    for (final category in categories) {
      await _categoryBox.put(category.id, category);
    }
  }

  /// Export all categories as maps
  List<Map<String, dynamic>> exportCategories() {
    return _categoryBox.values.map((category) => category.toMap()).toList();
  }
}