import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_stock_take_item_model.dart';
import '../../models/restaurant/db/restaurant_stock_take_model.dart';

/// Hive I/O for restaurant physical stock counts. Mirrors retail's
/// `StockTakeRepository` — deliberately thin, no variance math or lifecycle
/// rules; that belongs to the store.
class RestaurantStockTakeRepository {
  Box<RestaurantStockTakeModel> get _takes =>
      Hive.box<RestaurantStockTakeModel>(HiveBoxNames.restaurantStockTakes);

  Box<RestaurantStockTakeItemModel> get _items =>
      Hive.box<RestaurantStockTakeItemModel>(HiveBoxNames.restaurantStockTakeItems);

  // ==================== HEADERS ====================

  Future<List<RestaurantStockTakeModel>> getAll() async {
    return _takes.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  RestaurantStockTakeModel? getById(String takeId) => _takes.get(takeId);

  Future<void> save(RestaurantStockTakeModel take) async {
    await _takes.put(take.takeId, take);
  }

  // ==================== LINES ====================

  Future<List<RestaurantStockTakeItemModel>> getItems(String takeId) async {
    return _items.values.where((i) => i.takeId == takeId).toList()
      ..sort((a, b) => a.countedAt.compareTo(b.countedAt));
  }

  /// Synchronous variant for guards that must not await inside a build.
  List<RestaurantStockTakeItemModel> itemsFor(String takeId) =>
      _items.values.where((i) => i.takeId == takeId).toList();

  Future<void> saveItem(RestaurantStockTakeItemModel item) async {
    await _items.put(item.takeItemId, item);
  }

  Future<void> saveItems(List<RestaurantStockTakeItemModel> items) async {
    for (final item in items) {
      await _items.put(item.takeItemId, item);
    }
  }

  Future<void> deleteItem(String takeItemId) async {
    await _items.delete(takeItemId);
  }

  /// Only reachable while a take is still a draft.
  Future<void> deleteTakeWithItems(String takeId) async {
    final keys = _items.values
        .where((i) => i.takeId == takeId)
        .map((i) => i.takeItemId)
        .toList();
    await _items.deleteAll(keys);
    await _takes.delete(takeId);
  }

  /// True when this item is already on the take, so the count screen can
  /// update the existing line instead of adding a duplicate.
  RestaurantStockTakeItemModel? findLine(String takeId, String itemId) {
    for (final item in _items.values) {
      if (item.takeId == takeId && item.itemId == itemId) return item;
    }
    return null;
  }
}
