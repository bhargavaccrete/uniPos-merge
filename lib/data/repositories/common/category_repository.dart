import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/common/categorymodel_300.dart';
import '../../models/restaurant/db/itemmodel_302.dart';
import '../../models/retail/hive_model/product_model_200.dart';

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
/// mode-specific behavior, unlike the category box itself. `deleteCategory`
/// carries the retail half of that split too: it re-parents products instead of
/// deleting them.
class CategoryRepository {
  late Box<Category> _categoryBox;
  Box<Items>? _itemBox;
  Box<ProductModel>? _productBox;

  CategoryRepository() {
    _categoryBox = Hive.box<Category>(HiveBoxNames.category);
    if (AppConfig.isRestaurant) {
      _itemBox = Hive.box<Items>(HiveBoxNames.restaurantItems);
    } else {
      _productBox = Hive.box<ProductModel>(HiveBoxNames.products);
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
  ///
  /// **Neither mode deletes what was inside the category.** Both re-parent to
  /// no category. Deleting a category is an organisational act; a menu item or
  /// product carries far more setup than the label being removed, and losing it
  /// cannot be undone.
  ///
  /// Restaurant used to cascade-delete its items here while `CategoryStore`
  /// simultaneously tried to re-parent them from its in-memory list — so the
  /// outcome depended on which screen called, and on whether the plan allowed
  /// item editing. Doing the re-parent here, against the box, settles it: one
  /// policy, no dependence on whether a store has hydrated.
  ///
  /// Retail: products are never deleted — they are re-parented to no category,
  /// which is what every retail delete prompt has always promised. Leaving the
  /// id in place instead would strand it: every retail lookup falls back to
  /// `?? product.category`, so the raw id would surface as the category NAME in
  /// Inventory, on the product page, and — via `cart_store` — get written onto
  /// sale lines, where it would show up forever as a junk row in the
  /// category-wise sales report.
  Future<void> deleteCategory(String categoryId) async {
    if (_itemBox != null) {
      // Iterated by KEY, and written back to the same key. Some legacy items
      // are stored under Hive's auto-increment index rather than under their
      // own `id`, so a `put(item.id, …)` would insert a second copy of those
      // instead of updating them.
      for (final key in _itemBox!.keys.toList()) {
        final item = _itemBox!.get(key);
        if (item == null || item.categoryOfItem != categoryId) continue;
        await _itemBox!.put(key, item.copyWith(categoryOfItem: ''));
      }
    }

    if (_productBox != null) {
      final orphaned = _productBox!.values
          .where((product) => product.category == categoryId)
          .toList();

      for (final product in orphaned) {
        await _productBox!.put(
          product.productId,
          product.copyWith(category: ''),
        );
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

