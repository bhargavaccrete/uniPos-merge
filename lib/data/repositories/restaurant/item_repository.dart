import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/itemmodel_302.dart';
import '../../models/restaurant/db/categorymodel_300.dart';

/// Repository layer for Item data access (Restaurant)
/// Handles all Hive database operations for menu items
/// Follows the same pattern as retail repositories
class ItemRepository {
  late Box<Items> _itemBox;
  late Box<Category> _categoryBox;

  ItemRepository() {
    _itemBox = Hive.box<Items>(HiveBoxNames.restaurantItems);
    _categoryBox = Hive.box<Category>(HiveBoxNames.restaurantCategories);
  }

  /// Get all items from Hive
  Future<List<Items>> getAllItems() async {
    return _itemBox.values.toList();
  }

  /// Add a new item to Hive
  Future<void> addItem(Items item) async {
    await _itemBox.put(item.id, item);

    // CRITICAL: Flush to disk on web platform
    if (kIsWeb) {
      await _itemBox.flush();
    }
  }

  /// Update an existing item in Hive
  Future<void> updateItem(Items item) async {
    print('📝 REPOSITORY - Saving item: ${item.name}');
    print('   trackInventory BEFORE save: ${item.trackInventory}');
    print('   allowOrderWhenOutOfStock BEFORE save: ${item.allowOrderWhenOutOfStock}');

    await _itemBox.put(item.id, item);

    // CRITICAL: Flush to disk on web platform to ensure data is persisted
    // Hive web uses IndexedDB which has caching issues
    if (kIsWeb) {
      await _itemBox.flush();
    }

    // Verify what was actually saved
    final savedItem = _itemBox.get(item.id);
    print('   trackInventory AFTER save: ${savedItem?.trackInventory}');
    print('   allowOrderWhenOutOfStock AFTER save: ${savedItem?.allowOrderWhenOutOfStock}');
  }

  /// Delete an item from Hive
  Future<void> deleteItem(String itemId) async {
    await _itemBox.delete(itemId);
  }

  /// Get an item by ID
  Future<Items?> getItemById(String itemId) async {
    return _itemBox.get(itemId);
  }

  /// Check if item exists
  Future<bool> itemExists(String itemId) async {
    return _itemBox.containsKey(itemId);
  }

  /// Get items by category
  Future<List<Items>> getItemsByCategory(String categoryId) async {
    return _itemBox.values
        .where((item) => item.categoryOfItem == categoryId)
        .toList();
  }

  /// Get enabled items only
  Future<List<Items>> getEnabledItems() async {
    return _itemBox.values.where((item) => item.isEnabled).toList();
  }

  /// Get disabled items only
  Future<List<Items>> getDisabledItems() async {
    return _itemBox.values.where((item) => !item.isEnabled).toList();
  }

  /// Get items by veg/non-veg status
  Future<List<Items>> getItemsByVegStatus(String vegStatus) async {
    return _itemBox.values
        .where((item) => item.isVeg == vegStatus)
        .toList();
  }

  /// Search items by name
  Future<List<Items>> searchItems(String query) async {
    if (query.isEmpty) {
      return getAllItems();
    }

    final lowercaseQuery = query.toLowerCase();
    return _itemBox.values
        .where((item) => item.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get items with low stock (below threshold)
  Future<List<Items>> getLowStockItems({int threshold = 10}) async {
    return _itemBox.values
        .where((item) =>
            item.trackInventory &&
            item.stockQuantity < threshold &&
            item.stockQuantity >= 0)
        .toList();
  }

  /// Get out of stock items
  Future<List<Items>> getOutOfStockItems() async {
    return _itemBox.values
        .where((item) => item.trackInventory && item.stockQuantity <= 0)
        .toList();
  }

  /// Update stock quantity
  Future<void> updateStock(String itemId, double newQuantity) async {
    final item = await getItemById(itemId);
    if (item != null) {
      final updatedItem = item.copyWith(
        stockQuantity: newQuantity,
        lastEditedTime: DateTime.now(),
      );
      await updateItem(updatedItem);
    }
  }

  /// Decrease stock (for orders)
  Future<bool> decreaseStock(String itemId, double quantity) async {
    final item = await getItemById(itemId);
    if (item == null) return false;

    if (!item.trackInventory) {
      return true; // Don't track inventory, always allow
    }

    final newQuantity = item.stockQuantity - quantity;

    if (newQuantity < 0 && !item.allowOrderWhenOutOfStock) {
      return false; // Not enough stock and not allowed to order
    }

    await updateStock(itemId, newQuantity);
    return true;
  }

  /// Increase stock (for stock adjustments)
  Future<void> increaseStock(String itemId, double quantity) async {
    final item = await getItemById(itemId);
    if (item != null) {
      final newQuantity = item.stockQuantity + quantity;
      await updateStock(itemId, newQuantity);
    }
  }

  /// Toggle item enabled status
  Future<void> toggleItemStatus(String itemId) async {
    final item = await getItemById(itemId);
    if (item != null) {
      final updatedItem = item.copyWith(
        isEnabled: !item.isEnabled,
        lastEditedTime: DateTime.now(),
      );
      await updateItem(updatedItem);
    }
  }

  /// Get item count
  Future<int> getItemCount() async {
    return _itemBox.length;
  }

  /// Get item count by category
  Future<Map<String, int>> getItemCountByCategory() async {
    final categories = _categoryBox.values.toList();
    final result = <String, int>{};

    for (var category in categories) {
      final count = _itemBox.values
          .where((item) => item.categoryOfItem == category.id)
          .length;
      result[category.id] = count;
    }

    return result;
  }

  /// Get items with variants
  Future<List<Items>> getItemsWithVariants() async {
    return _itemBox.values.where((item) => item.hasVariants).toList();
  }

  /// Get items without variants
  Future<List<Items>> getItemsWithoutVariants() async {
    return _itemBox.values.where((item) => !item.hasVariants).toList();
  }

  /// Apply tax to item
  Future<void> applyTaxToItem(String itemId, double taxRate) async {
    final item = await getItemById(itemId);
    if (item != null) {
      final updatedItem = item.copyWith(
        taxRate: taxRate,
        lastEditedTime: DateTime.now(),
      );
      await updateItem(updatedItem);
    }
  }

  /// Remove tax from item
  Future<void> removeTaxFromItem(String itemId) async {
    final item = await getItemById(itemId);
    if (item != null) {
      final updatedItem = item.copyWith(
        taxRate: 0.0,
        lastEditedTime: DateTime.now(),
      );
      await updateItem(updatedItem);
    }
  }

  /// Get items by price range
  Future<List<Items>> getItemsByPriceRange(
      double minPrice, double maxPrice) async {
    return _itemBox.values
        .where((item) =>
            item.price != null &&
            item.price! >= minPrice &&
            item.price! <= maxPrice)
        .toList();
  }

  /// Get recently edited items
  Future<List<Items>> getRecentlyEditedItems({int limit = 10}) async {
    final items = _itemBox.values.toList();
    items.sort((a, b) {
      if (a.lastEditedTime == null && b.lastEditedTime == null) return 0;
      if (a.lastEditedTime == null) return 1;
      if (b.lastEditedTime == null) return -1;
      return b.lastEditedTime!.compareTo(a.lastEditedTime!);
    });
    return items.take(limit).toList();
  }

  /// Get items sold by weight
  Future<List<Items>> getWeightBasedItems() async {
    return _itemBox.values.where((item) => item.isSoldByWeight).toList();
  }

  /// Bulk update items (useful for price updates, stock adjustments, etc.)
  Future<void> bulkUpdateItems(List<Items> items) async {
    for (var item in items) {
      await updateItem(item);
    }
  }

  /// Delete items by category (when category is deleted)
  Future<void> deleteItemsByCategory(String categoryId) async {
    final itemsToDelete = await getItemsByCategory(categoryId);
    for (var item in itemsToDelete) {
      await deleteItem(item.id);
    }
  }
}
