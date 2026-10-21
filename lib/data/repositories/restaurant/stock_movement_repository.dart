import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/stock_movement_model.dart';

/// Data access layer for [StockMovementModel].
///
/// Append-only: movements are saved, never edited or deleted. Screens read
/// through this class so the Hive box name lives in one place.
class StockMovementRepository {
  Box<StockMovementModel> get _box =>
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements);

  /// Persist a movement. Uses [id] as the Hive key so save = upsert.
  Future<void> saveMovement(StockMovementModel movement) async {
    await _box.put(movement.id, movement);
  }

  /// Whether a movement with this id was already saved — lets a caller that
  /// uses a deterministic id make its write idempotent.
  bool contains(String id) => _box.containsKey(id);

  /// All movements for an item (including its variants), newest first.
  /// The per-item history shows everything for the item; the stored
  /// [StockMovementModel.itemName] distinguishes variant rows.
  List<StockMovementModel> movementsForItem(String itemId) {
    final list = _box.values.where((m) => m.itemId == itemId).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Every movement in the box, unsorted — callers sort for their own view.
  /// Used by retail's stock-adjustment history, which spans all products.
  List<StockMovementModel> allMovements() => _box.values.toList();
}
