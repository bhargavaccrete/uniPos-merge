import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/stock_take_item_model_181.dart';
import '../../models/retail/hive_model/stock_take_model_180.dart';

/// Hive I/O for physical stock counts.
///
/// Deliberately thin — no variance maths and no lifecycle rules live here.
/// Variance is derived on the line model, and the draft/commit lifecycle
/// belongs to `StockTakeStore`.
class StockTakeRepository {
  Box<StockTakeModel> get _takes =>
      Hive.box<StockTakeModel>(HiveBoxNames.stockTakes);

  Box<StockTakeItemModel> get _items =>
      Hive.box<StockTakeItemModel>(HiveBoxNames.stockTakeItems);

  // ==================== HEADERS ====================

  /// Newest first — the order the list screen reads in.
  Future<List<StockTakeModel>> getAll() async {
    return _takes.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  StockTakeModel? getById(String takeId) => _takes.get(takeId);

  Future<void> save(StockTakeModel take) async {
    await _takes.put(take.takeId, take);
  }

  // ==================== LINES ====================

  /// Lines in the order they were counted, so the count screen doesn't reorder
  /// under the user as they type.
  Future<List<StockTakeItemModel>> getItems(String takeId) async {
    return _items.values.where((i) => i.takeId == takeId).toList()
      ..sort((a, b) => a.countedAt.compareTo(b.countedAt));
  }

  /// Synchronous variant for guards that must not await inside a build.
  List<StockTakeItemModel> itemsFor(String takeId) =>
      _items.values.where((i) => i.takeId == takeId).toList();

  Future<void> saveItem(StockTakeItemModel item) async {
    await _items.put(item.takeItemId, item);
  }

  Future<void> saveItems(List<StockTakeItemModel> items) async {
    for (final item in items) {
      await _items.put(item.takeItemId, item);
    }
  }

  Future<void> deleteItem(String takeItemId) async {
    await _items.delete(takeItemId);
  }

  /// Only reachable while a take is still a draft — a completed take's lines
  /// are the evidence for adjustments that already happened.
  Future<void> deleteTakeWithItems(String takeId) async {
    final keys = _items.values
        .where((i) => i.takeId == takeId)
        .map((i) => i.takeItemId)
        .toList();
    await _items.deleteAll(keys);
    await _takes.delete(takeId);
  }

  /// True when this variant is already on the take, so the count screen can
  /// update the existing line instead of adding a duplicate.
  StockTakeItemModel? findLine(String takeId, String variantId) {
    for (final item in _items.values) {
      if (item.takeId == takeId && item.variantId == variantId) return item;
    }
    return null;
  }
}
