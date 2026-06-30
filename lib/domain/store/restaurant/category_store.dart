import 'package:mobx/mobx.dart';
import '../../../core/plan/entitlement_keys.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/repositories/restaurant/category_repository.dart';

part 'category_store.g.dart';

class CategoryStore = _CategoryStore with _$CategoryStore;

abstract class _CategoryStore with Store {
  final CategoryRepository _repository;

  _CategoryStore(this._repository) {
    // Load categories on initialization
    loadCategories();
  }

  // ==================== OBSERVABLES ====================

  @observable
  ObservableList<Category> categories = ObservableList<Category>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Map to store items grouped by category ID
  @observable
  ObservableMap<String, List<Items>> categoryItemsMap = ObservableMap<String, List<Items>>();

  // ==================== COMPUTED ====================

  @computed
  List<Category> get filteredCategories {
    if (searchQuery.isEmpty) {
      return categories;
    }
    final lowercaseQuery = searchQuery.toLowerCase();
    return categories
        .where((category) => category.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @computed
  int get categoryCount => categories.length;

  @computed
  bool get hasCategories => categories.isNotEmpty;

  // ==================== ACTIONS ====================

  @action
  Future<void> loadCategories() async {
    try {
      isLoading = true;
      errorMessage = null;

      final loadedCategories = await _repository.getAllCategories();
      categories.clear();
      categories.addAll(loadedCategories);

      // Load items for each category
      await _loadCategoryItems();
    } catch (e) {
      errorMessage = 'Failed to load categories: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> _loadCategoryItems() async {
    categoryItemsMap.clear();

    for (var category in categories) {
      final items = await _repository.getItemsByCategory(category.id);
      categoryItemsMap[category.id] = items;
    }
  }

  @action
  Future<bool> addCategory(Category category) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Plan gate — add category (manage_menu.categories.add).
      if (!PlanEnforce.allows(EntKeys.manageMenuCategoriesAdd)) {
        errorMessage =
            'Adding categories isn’t available on your current plan.';
        return false;
      }

      // Block case-insensitive duplicate names at the source, so every caller
      // (add screens, import) is protected even if it forgets to pre-check.
      final nameKey = category.name.trim().toLowerCase();
      final isDuplicate =
          categories.any((c) => c.name.trim().toLowerCase() == nameKey);
      if (isDuplicate) {
        errorMessage =
            'A category named "${category.name.trim()}" already exists';
        return false;
      }

      await _repository.addCategory(category);
      categories.add(category);
      categoryItemsMap[category.id] = [];

      return true;
    } catch (e) {
      errorMessage = 'Failed to add category: $e';
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateCategory(Category category) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Plan gate — edit category (manage_menu.categories.edit).
      if (!PlanEnforce.allows(EntKeys.manageMenuCategoriesEdit)) {
        errorMessage = 'Editing categories isn’t available on your current plan.';
        return false;
      }

      await _repository.updateCategory(category);

      // Update in local list
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        categories[index] = category;
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update category: $e';
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> deleteCategory(String categoryId) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Plan gate — delete category (manage_menu.categories.delete).
      if (!PlanEnforce.allows(EntKeys.manageMenuCategoriesDelete)) {
        errorMessage = 'Deleting categories isn’t available on your current plan.';
        return false;
      }

      await _repository.deleteCategory(categoryId);

      // Remove from local list
      categories.removeWhere((c) => c.id == categoryId);
      categoryItemsMap.remove(categoryId);

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete category: $e';
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearSearch() {
    searchQuery = '';
  }

  // ==================== HELPER METHODS ====================

  /// Get items for a specific category
  List<Items> getItemsForCategory(String categoryId) {
    return categoryItemsMap[categoryId] ?? [];
  }

  /// Get item count for a category
  int getItemCountForCategory(String categoryId) {
    return categoryItemsMap[categoryId]?.length ?? 0;
  }

  /// Categories that contain at least one of [items]. Callers pass the live
  /// item list (e.g. the menu's enabled items) so the result matches exactly
  /// what's on screen — out-of-stock items still count, only categories with no
  /// items at all are dropped. Used to hide empty categories on the order screen.
  List<Category> categoriesWithItems(List<Items> items) {
    final usedIds = items.map((i) => i.categoryOfItem).toSet();
    return categories.where((c) => usedIds.contains(c.id)).toList();
  }

  /// Check if category exists
  bool categoryExists(String categoryId) {
    return categories.any((c) => c.id == categoryId);
  }

  /// Get category by ID
  Category? getCategoryById(String categoryId) {
    try {
      return categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh categories (pull from database)
  @action
  Future<void> refresh() async {
    await loadCategories();
  }
}
