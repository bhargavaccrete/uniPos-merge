import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../data/repositories/restaurant/category_repository.dart';

part 'category_store.g.dart';

class CategoryStore = _CategoryStore with _$CategoryStore;

abstract class _CategoryStore with Store {
  final CategoryRepository _categoryRepository = locator<CategoryRepository>();

  final ObservableList<Category> categories = ObservableList<Category>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedCategoryId;

  _CategoryStore() {
    _init();
  }

  Future<void> _init() async {
    await loadCategories();
  }

  // ==================== COMPUTED ====================

  @computed
  List<Category> get filteredCategories {
    if (searchQuery.isEmpty) {
      return categories.toList();
    }
    final lowerQuery = searchQuery.toLowerCase();
    return categories
        .where((category) => category.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @computed
  int get totalCategoryCount => categories.length;

  @computed
  Category? get selectedCategory {
    if (selectedCategoryId == null) return null;
    try {
      return categories.firstWhere((c) => c.id == selectedCategoryId);
    } catch (e) {
      return null;
    }
  }

  // ==================== ACTIONS ====================

  @action
  Future<void> loadCategories() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loadedCategories = await _categoryRepository.getAllCategories();
      categories.clear();
      categories.addAll(loadedCategories);
    } catch (e) {
      errorMessage = 'Failed to load categories: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addCategory(Category category) async {
    try {
      await _categoryRepository.addCategory(category);
      categories.add(category);
    } catch (e) {
      errorMessage = 'Failed to add category: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateCategory(Category category) async {
    try {
      await _categoryRepository.updateCategory(category);
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        categories[index] = category;
      }
    } catch (e) {
      errorMessage = 'Failed to update category: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteCategory(String id) async {
    try {
      await _categoryRepository.deleteCategory(id);
      categories.removeWhere((category) => category.id == id);
      // Reset selection if deleted category was selected
      if (selectedCategoryId == id) {
        selectedCategoryId = null;
      }
    } catch (e) {
      errorMessage = 'Failed to delete category: $e';
      rethrow;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void setSelectedCategory(String? categoryId) {
    selectedCategoryId = categoryId;
  }

  @action
  void clearSelection() {
    selectedCategoryId = null;
  }

  // ==================== HELPERS ====================

  Category? getCategoryById(String id) {
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  String? getCategoryName(String? categoryId) {
    if (categoryId == null) return null;
    final category = getCategoryById(categoryId);
    return category?.name;
  }

  int getItemCountForCategory(String categoryId) {
    return _categoryRepository.getItemCountForCategory(categoryId);
  }
}