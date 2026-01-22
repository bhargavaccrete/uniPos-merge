import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/repositories/restaurant/item_repository.dart';

part 'item_store.g.dart';

class ItemStore = _ItemStore with _$ItemStore;

abstract class _ItemStore with Store {
  final ItemRepository _repository;

  _ItemStore(this._repository) {
    // Load items on initialization
    loadItems();
  }

  // ==================== OBSERVABLES ====================

  @observable
  ObservableList<Items> items = ObservableList<Items>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedCategoryId;

  @observable
  String? vegFilter; // 'veg', 'non-veg', or null for all

  @observable
  bool? enabledFilter; // true for enabled, false for disabled, null for all

  @observable
  bool showLowStockOnly = false;

  @observable
  bool showOutOfStockOnly = false;

  // ==================== COMPUTED ====================

  @computed
  List<Items> get filteredItems {
    var result = items.toList();

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result
          .where((item) => item.name.toLowerCase().contains(lowercaseQuery))
          .toList();
    }

    // Apply category filter
    if (selectedCategoryId != null) {
      result = result
          .where((item) => item.categoryOfItem == selectedCategoryId)
          .toList();
    }

    // Apply veg/non-veg filter
    if (vegFilter != null) {
      result = result.where((item) => item.isVeg == vegFilter).toList();
    }

    // Apply enabled/disabled filter
    if (enabledFilter != null) {
      result = result.where((item) => item.isEnabled == enabledFilter).toList();
    }

    // Apply low stock filter
    if (showLowStockOnly) {
      result = result
          .where((item) =>
              item.trackInventory &&
              item.stockQuantity < 10 &&
              item.stockQuantity > 0)
          .toList();
    }

    // Apply out of stock filter
    if (showOutOfStockOnly) {
      result = result
          .where((item) => item.trackInventory && item.stockQuantity <= 0)
          .toList();
    }

    return result;
  }

  @computed
  int get itemCount => items.length;

  @computed
  int get filteredItemCount => filteredItems.length;

  @computed
  bool get hasItems => items.isNotEmpty;

  @computed
  List<Items> get enabledItems => items.where((item) => item.isEnabled).toList();

  @computed
  List<Items> get disabledItems => items.where((item) => !item.isEnabled).toList();

  @computed
  List<Items> get lowStockItems =>
      items.where((item) => item.trackInventory && item.stockQuantity < 10 && item.stockQuantity > 0).toList();

  @computed
  List<Items> get outOfStockItems =>
      items.where((item) => item.trackInventory && item.stockQuantity <= 0).toList();

  @computed
  int get lowStockCount => lowStockItems.length;

  @computed
  int get outOfStockCount => outOfStockItems.length;

  // ==================== ACTIONS ====================

  @action
  Future<void> loadItems() async {
    try {
      isLoading = true;
      errorMessage = null;

      final loadedItems = await _repository.getAllItems();
      items.clear();
      items.addAll(loadedItems);
    } catch (e) {
      errorMessage = 'Failed to load items: $e';
      print('Error loading items: $e');
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> addItem(Items item) async {
    try {
      isLoading = true;
      errorMessage = null;

      await _repository.addItem(item);
      items.add(item);

      return true;
    } catch (e) {
      errorMessage = 'Failed to add item: $e';
      print('Error adding item: $e');
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateItem(Items item) async {
    try {
      isLoading = true;
      errorMessage = null;

      await _repository.updateItem(item);

      // Force reload to ensure MobX detects changes
      // This is necessary because items are Hive objects and modifying them
      // in place doesn't trigger MobX observers properly
      await loadItems();

      return true;
    } catch (e) {
      errorMessage = 'Failed to update item: $e';
      print('Error updating item: $e');
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> deleteItem(String itemId) async {
    try {
      isLoading = true;
      errorMessage = null;

      await _repository.deleteItem(itemId);

      // Remove from local list
      items.removeWhere((i) => i.id == itemId);

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete item: $e';
      print('Error deleting item: $e');
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> toggleItemStatus(String itemId) async {
    try {
      await _repository.toggleItemStatus(itemId);

      // Update in local list
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final item = items[index];
        items[index] = item.copyWith(
          isEnabled: !item.isEnabled,
          lastEditedTime: DateTime.now(),
        );
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to toggle item status: $e';
      print('Error toggling item status: $e');
      return false;
    }
  }

  @action
  Future<bool> updateStock(String itemId, double newQuantity) async {
    try {
      await _repository.updateStock(itemId, newQuantity);

      // Update in local list
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final item = items[index];
        items[index] = item.copyWith(
          stockQuantity: newQuantity,
          lastEditedTime: DateTime.now(),
        );
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update stock: $e';
      print('Error updating stock: $e');
      return false;
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

  @action
  void setCategoryFilter(String? categoryId) {
    selectedCategoryId = categoryId;
  }

  @action
  void clearCategoryFilter() {
    selectedCategoryId = null;
  }

  @action
  void setVegFilter(String? vegStatus) {
    vegFilter = vegStatus;
  }

  @action
  void clearVegFilter() {
    vegFilter = null;
  }

  @action
  void setEnabledFilter(bool? enabled) {
    enabledFilter = enabled;
  }

  @action
  void clearEnabledFilter() {
    enabledFilter = null;
  }

  @action
  void toggleLowStockFilter() {
    showLowStockOnly = !showLowStockOnly;
    if (showLowStockOnly) {
      showOutOfStockOnly = false;
    }
  }

  @action
  void toggleOutOfStockFilter() {
    showOutOfStockOnly = !showOutOfStockOnly;
    if (showOutOfStockOnly) {
      showLowStockOnly = false;
    }
  }

  @action
  void clearAllFilters() {
    searchQuery = '';
    selectedCategoryId = null;
    vegFilter = null;
    enabledFilter = null;
    showLowStockOnly = false;
    showOutOfStockOnly = false;
  }

  // ==================== HELPER METHODS ====================

  /// Get item by ID
  Items? getItemById(String itemId) {
    try {
      return items.firstWhere((i) => i.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// Get items by category
  List<Items> getItemsByCategory(String categoryId) {
    return items.where((item) => item.categoryOfItem == categoryId).toList();
  }

  /// Check if item exists
  bool itemExists(String itemId) {
    return items.any((i) => i.id == itemId);
  }

  /// Check if item name exists (for duplicate validation)
  bool itemNameExists(String name, {String? excludeId}) {
    return items.any((item) =>
        item.name.toLowerCase() == name.toLowerCase() &&
        item.id != excludeId);
  }

  /// Refresh items (pull from database)
  @action
  Future<void> refresh() async {
    await loadItems();
  }
}
