import 'package:mobx/mobx.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../data/models/common/categorymodel_300.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/repositories/common/category_repository.dart';
import '../../../core/plan/mode_keys.dart';

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

  /// Category id → name, for screens that resolve many ids per rebuild.
  /// Reactive (unlike caching the map in widget State) and O(1) per lookup
  /// instead of [getCategoryById]'s linear scan.
  @computed
  Map<String, String> get categoryNameById =>
      {for (final c in categories) c.id: c.name};

  // ==================== ACTIONS ====================

  @action
  Future<void> loadCategories() async {
    try {
      isLoading = true;
      errorMessage = null;

      var loadedCategories = await _repository.getAllCategories();
      if (loadedCategories.isEmpty && AppConfig.isRetail) {
        await _repository.addDefaultCategories();
        loadedCategories = await _repository.getAllCategories();
      }
      categories.clear();
      categories.addAll(loadedCategories);

      // Load items for each category (restaurant only — retail counts
      // products directly off productStore, see getItemCountForCategory).
      if (AppConfig.isRestaurant) {
        await _loadCategoryItems();
      }
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

      // Plan gate — ModeKeys picks retail's or restaurant's category key, since
      // this store serves both. Retail stays open until a manifest arrives.
      if (!PlanEnforce.allows(ModeKeys.categoriesAdd)) {
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

      // Plan gate — ModeKeys picks retail's or restaurant's category key.
      if (!PlanEnforce.allows(ModeKeys.categoriesEdit)) {
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

      // Plan gate — ModeKeys picks retail's or restaurant's category key.
      if (!PlanEnforce.allows(ModeKeys.categoriesDelete)) {
        errorMessage = 'Deleting categories isn’t available on your current plan.';
        return false;
      }

      await _repository.deleteCategory(categoryId);

      if (AppConfig.isRestaurant) {
        // Re-parent any items that belonged to this category so none are left
        // pointing at a deleted category (which would otherwise render as
        // "Unknown"). This makes deletion safe from every caller — the add-item
        // sheet, the edit screen, and category management all share this path.
        final orphaned =
            itemStore.items.where((i) => i.categoryOfItem == categoryId).toList();
        for (final item in orphaned) {
          await itemStore.updateItem(item.copyWith(categoryOfItem: ''));
        }
        categoryItemsMap.remove(categoryId);
      } else {
        // Retail: re-parent products so none are left pointing at a deleted
        // category id.
        final orphaned =
            productStore.products.where((p) => p.category == categoryId).toList();
        for (final product in orphaned) {
          await productStore.updateProduct(product.copyWith(category: ''));
        }
      }

      // Remove from local list
      categories.removeWhere((c) => c.id == categoryId);

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

  /// Get item count for a category (product count in retail mode)
  int getItemCountForCategory(String categoryId) {
    if (AppConfig.isRetail) {
      return productStore.products.where((p) => p.category == categoryId).length;
    }
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
