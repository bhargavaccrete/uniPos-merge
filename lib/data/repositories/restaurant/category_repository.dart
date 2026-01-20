import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/categorymodel_300.dart';
import '../../models/restaurant/db/itemmodel_302.dart';

/// Repository layer for Category data access (Restaurant)
/// Handles all Hive database operations for categories
/// Follows the same pattern as retail repositories
class CategoryRepository {
  late Box<Category> _categoryBox;
  late Box<Items> _itemBox;

  CategoryRepository() {
    _categoryBox = Hive.box<Category>(HiveBoxNames.restaurantCategories);
    _itemBox = Hive.box<Items>(HiveBoxNames.restaurantItems);
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

  /// Delete a category from Hive
  /// Also deletes all associated items
  Future<void> deleteCategory(String categoryId) async {
    // Delete the category

    // Delete all items for this category
    final itemsToDelete = _itemBox.values
        .where((item) => item.categoryOfItem == categoryId)
        .map((item) => item.id)
        .toList();

    if(itemsToDelete.isNotEmpty){
      await _itemBox.deleteAll(itemsToDelete);
    }

    // for (var item in itemsToDelete) {
    //   await _itemBox.delete(item.id);
    // }
    await _categoryBox.delete(categoryId);

  }

  /// Get a category by ID
  Future<Category?> getCategoryById(String categoryId) async {
    return _categoryBox.get(categoryId);
  }

  /// Check if category exists
  Future<bool> categoryExists(String categoryId) async {
    return _categoryBox.containsKey(categoryId);
  }

  /// Get items for a specific category
  Future<List<Items>> getItemsByCategory(String categoryId) async {
    return _itemBox.values
        .where((item) => item.categoryOfItem == categoryId)
        .toList();
  }

  /// Get category count
  Future<int> getCategoryCount() async {
    return _categoryBox.length;
  }

  /// Search categories by name
  Future<List<Category>> searchCategories(String query) async {
    if (query.isEmpty) {
      return getAllCategories();
    }

    final lowercaseQuery = query.toLowerCase();
    return _categoryBox.values
        .where((category) => category.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get categories with item count
  Future<Map<Category, int>> getCategoriesWithItemCount() async {
    final categories = await getAllCategories();
    final result = <Category, int>{};

    for (var category in categories) {
      final itemCount = _itemBox.values
          .where((item) => item.categoryOfItem == category.id)
          .length;
      result[category] = itemCount;
    }

    return result;
  }
}
