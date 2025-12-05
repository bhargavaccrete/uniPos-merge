import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/repositories/restaurant/item_repository.dart';

part 'item_store.g.dart';

class ItemStore = _ItemStore with _$ItemStore;

abstract class _ItemStore with Store {
  final ItemRepository _itemRepository = locator<ItemRepository>();

  final ObservableList<Items> items = ObservableList<Items>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? selectedCategoryId;

  @observable
  String searchQuery = '';

  _ItemStore() {
    _init();
  }

  Future<void> _init() async {
    await loadItems();
  }

  // ==================== COMPUTED ====================

  @computed
  List<Items> get filteredItems {
    var result = items.toList();

    // Filter by category
    if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) {
      result = result
          .where((item) => item.categoryOfItem == selectedCategoryId)
          .toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      result = result
          .where((item) => item.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    return result;
  }

  @computed
  List<Items> get enabledItems {
    return items.where((item) => item.isEnabled).toList();
  }

  @computed
  List<Items> get lowStockItems {
    return items
        .where((item) => item.trackInventory && item.stockQuantity <= 10)
        .toList();
  }

  @computed
  List<Items> get outOfStockItems {
    return items
        .where((item) => item.trackInventory && item.stockQuantity <= 0)
        .toList();
  }

  @computed
  int get totalItemCount => items.length;

  @computed
  int get enabledItemCount => enabledItems.length;

  // ==================== ACTIONS ====================

  @action
  Future<void> loadItems() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loadedItems = await _itemRepository.getAllItems();
      items.clear();
      items.addAll(loadedItems);
    } catch (e) {
      errorMessage = 'Failed to load items: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addItem(Items item) async {
    try {
      await _itemRepository.addItem(item);
      items.add(item);
    } catch (e) {
      errorMessage = 'Failed to add item: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateItem(Items item) async {
    try {
      await _itemRepository.updateItem(item);
      final index = items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        items[index] = item;
      }
    } catch (e) {
      errorMessage = 'Failed to update item: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteItem(String id) async {
    try {
      await _itemRepository.deleteItem(id);
      items.removeWhere((item) => item.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete item: $e';
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
  void clearFilters() {
    searchQuery = '';
    selectedCategoryId = null;
  }

  @action
  Future<void> toggleItemEnabled(String id) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = items[index];
      final updatedItem = item.copyWith(
        isEnabled: !item.isEnabled,
        lastEditedTime: DateTime.now(),
      );
      await updateItem(updatedItem);
    }
  }

  @action
  Future<void> updateStock(String id, double quantity) async {
    await _itemRepository.updateStock(id, quantity);
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = items[index];
      items[index] = item.copyWith(
        stockQuantity: quantity,
        lastEditedTime: DateTime.now(),
      );
    }
  }

  @action
  Future<void> deductStock(String id, double quantity) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = items[index];
      if (item.trackInventory) {
        final newQuantity = item.stockQuantity - quantity;
        await updateStock(id, newQuantity);
      }
    }
  }

  @action
  Future<void> addStock(String id, double quantity) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = items[index];
      if (item.trackInventory) {
        final newQuantity = item.stockQuantity + quantity;
        await updateStock(id, newQuantity);
      }
    }
  }

  // ==================== HELPERS ====================

  Items? getItemById(String id) {
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Items> getItemsByCategory(String categoryId) {
    return items.where((item) => item.categoryOfItem == categoryId).toList();
  }

  List<Items> getItemsWithVariants() {
    return items.where((item) => item.hasVariants).toList();
  }
}