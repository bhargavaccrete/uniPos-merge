import 'package:mobx/mobx.dart';
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
      print('Error loading categories: $e');
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

      await _repository.addCategory(category);
      categories.add(category);
      categoryItemsMap[category.id] = [];

      return true;
    } catch (e) {
      errorMessage = 'Failed to add category: $e';
      print('Error adding category: $e');
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

      await _repository.updateCategory(category);

      // Update in local list
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        categories[index] = category;
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update category: $e';
      print('Error updating category: $e');
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

      await _repository.deleteCategory(categoryId);

      // Remove from local list
      categories.removeWhere((c) => c.id == categoryId);
      categoryItemsMap.remove(categoryId);

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete category: $e';
      print('Error deleting category: $e');
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
