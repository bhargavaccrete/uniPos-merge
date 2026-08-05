import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/common/categorymodel_300.dart';
import '../../models/restaurant/db/itemmodel_302.dart';

/// Repository layer for Category data access.
///
/// Shared between Restaurant and Retail — both business modes use the same
/// `Category` model (id/name only; GST/HSN live on the product/variant, not
/// the category) AND the same physical box. A device only ever runs one
/// business mode for its whole lifetime, so there's never a moment where
/// restaurant and retail categories would need to be told apart in storage.
///
/// The item-cascade methods (`getItemsByCategory`, `getCategoriesWithItemCount`,
/// the item-delete step inside `deleteCategory`) only apply to restaurant's
/// `Items` box and are no-ops in retail mode — that split is genuinely
/// mode-specific behavior, unlike the category box itself.
class CategoryRepository {
  late Box<Category> _categoryBox;
  Box<Items>? _itemBox;

  CategoryRepository() {
    _categoryBox = Hive.box<Category>(HiveBoxNames.category);
    if (AppConfig.isRestaurant) {
      _itemBox = Hive.box<Items>(HiveBoxNames.restaurantItems);
    }
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

  /// Delete a category from Hive.
  /// Restaurant: also deletes all items in that category (existing behavior).
  /// Retail: category-only — callers re-parent products themselves.
  Future<void> deleteCategory(String categoryId) async {
    if (_itemBox != null) {
      final itemsToDelete = _itemBox!.values
          .where((item) => item.categoryOfItem == categoryId)
          .map((item) => item.id)
          .toList();

      if (itemsToDelete.isNotEmpty) {
        await _itemBox!.deleteAll(itemsToDelete);
      }
    }

    await _categoryBox.delete(categoryId);
  }

  /// Get a category by ID
  Future<Category?> getCategoryById(String categoryId) async {
    return _categoryBox.get(categoryId);
  }

  /// Get a category by name
  Future<Category?> getCategoryByName(String name) async {
    try {
      return _categoryBox.values.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if category exists
  Future<bool> categoryExists(String categoryId) async {
    return _categoryBox.containsKey(categoryId);
  }

  /// Get items for a specific category (restaurant only — empty in retail)
  Future<List<Items>> getItemsByCategory(String categoryId) async {
    if (_itemBox == null) return [];
    return _itemBox!.values
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

  /// Get categories with item count (restaurant only — empty counts in retail)
  Future<Map<Category, int>> getCategoriesWithItemCount() async {
    final categories = await getAllCategories();
    final result = <Category, int>{};

    for (var category in categories) {
      final itemCount = _itemBox?.values
              .where((item) => item.categoryOfItem == category.id)
              .length ??
          0;
      result[category] = itemCount;
    }

    return result;
  }

  /// Add default categories if empty (used by retail's first-run setup)
  Future<void> addDefaultCategories() async {
    if (_categoryBox.isEmpty) {
      final defaults = [
        'Electronics',
        'Clothing',
        'Groceries',
        'Footwear',
        'Cosmetics',
        'Uncategorized',
      ];

      const uuid = Uuid();
      for (var name in defaults) {
        await addCategory(Category(
          id: uuid.v4(),
          name: name,
          createdTime: DateTime.now(),
        ));
      }
    }
  }

  /// Clear all categories from Hive
  Future<void> clearAll() async {
    await _categoryBox.clear();
  }
}

