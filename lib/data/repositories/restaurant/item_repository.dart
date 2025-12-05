
import 'package:hive/hive.dart';

import '../../models/restaurant/db/itemmodel_302.dart';

/// Repository layer for Item data access
/// Handles all Hive database operations for items
class ItemRepository {
  static const String _boxName = 'itemBoxs';
  late Box<Items> _itemBox;

  ItemRepository() {
    _itemBox = Hive.box<Items>(_boxName);
  }

  /// Get all items from Hive
  Future<List<Items>> getAllItems() async {
    return _itemBox.values.toList();
  }

  /// Add a new item to Hive
  Future<void> addItem(Items item) async {
    await _itemBox.put(item.id, item);
  }

  /// Update an existing item in Hive
  Future<void> updateItem(Items item) async {
    await _itemBox.put(item.id, item);
  }

  /// Delete an item from Hive
  Future<void> deleteItem(String id) async {
    await _itemBox.delete(id);
  }

  /// Get an item by ID
  Items? getItemById(String id) {
    return _itemBox.get(id);
  }

  /// Get items by category
  List<Items> getItemsByCategory(String categoryId) {
    return _itemBox.values
        .where((item) => item.categoryOfItem == categoryId)
        .toList();
  }

  /// Get enabled items only
  List<Items> getEnabledItems() {
    return _itemBox.values.where((item) => item.isEnabled).toList();
  }

  /// Get items with low stock
  List<Items> getLowStockItems({double threshold = 10}) {
    return _itemBox.values
        .where((item) =>
            item.trackInventory &&
            item.stockQuantity <= threshold)
        .toList();
  }

  /// Get out of stock items
  List<Items> getOutOfStockItems() {
    return _itemBox.values
        .where((item) =>
            item.trackInventory &&
            item.stockQuantity <= 0)
        .toList();
  }

  /// Search items by name
  List<Items> searchItems(String query) {
    final lowerQuery = query.toLowerCase();
    return _itemBox.values
        .where((item) => item.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Check if item exists
  bool itemExists(String id) {
    return _itemBox.containsKey(id);
  }

  /// Get total item count
  int getItemCount() {
    return _itemBox.length;
  }

  /// Clear all items
  Future<void> clearAll() async {
    await _itemBox.clear();
  }

  /// Update stock quantity for an item
  Future<void> updateStock(String id, double newQuantity) async {
    final item = _itemBox.get(id);
    if (item != null) {
      final updatedItem = item.copyWith(
        stockQuantity: newQuantity,
        lastEditedTime: DateTime.now(),
      );
      await _itemBox.put(id, updatedItem);
    }
  }

  /// Deduct stock (for order processing)
  Future<void> deductStock(String id, double quantity) async {
    final item = _itemBox.get(id);
    if (item != null && item.trackInventory) {
      final newQuantity = item.stockQuantity - quantity;
      await updateStock(id, newQuantity);
    }
  }

  /// Add stock (for returns or restocking)
  Future<void> addStock(String id, double quantity) async {
    final item = _itemBox.get(id);
    if (item != null && item.trackInventory) {
      final newQuantity = item.stockQuantity + quantity;
      await updateStock(id, newQuantity);
    }
  }

  /// Toggle item enabled status
  Future<void> toggleEnabled(String id) async {
    final item = _itemBox.get(id);
    if (item != null) {
      final updatedItem = item.copyWith(
        isEnabled: !item.isEnabled,
        lastEditedTime: DateTime.now(),
      );
      await _itemBox.put(id, updatedItem);
    }
  }

  /// Get items with variants
  List<Items> getItemsWithVariants() {
    return _itemBox.values.where((item) => item.hasVariants).toList();
  }

  /// Bulk import items
  Future<void> importItems(List<Items> items) async {
    for (final item in items) {
      await _itemBox.put(item.id, item);
    }
  }

  /// Export all items as maps
  List<Map<String, dynamic>> exportItems() {
    return _itemBox.values.map((item) => item.toMap()).toList();
  }
}