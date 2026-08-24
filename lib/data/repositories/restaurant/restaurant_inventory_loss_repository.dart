import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_inventory_loss_model.dart';

/// Hive I/O for restaurant inventory losses. Mirrors retail's
/// `InventoryLossRepository` — append-only in practice, [delete] exists
/// only for cleanup paths.
class RestaurantInventoryLossRepository {
  Box<RestaurantInventoryLossModel> get _box =>
      Hive.box<RestaurantInventoryLossModel>(HiveBoxNames.restaurantInventoryLosses);

  Future<List<RestaurantInventoryLossModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<void> save(RestaurantInventoryLossModel model) async {
    await _box.put(model.lossId, model);
  }

  Future<void> saveAll(List<RestaurantInventoryLossModel> models) async {
    for (final model in models) {
      await _box.put(model.lossId, model);
    }
  }

  Future<List<RestaurantInventoryLossModel>> getByGRN(String grnId) async {
    return _box.values.where((l) => l.grnId == grnId).toList();
  }

  Future<List<RestaurantInventoryLossModel>> getByItem(String itemId) async {
    return _box.values.where((l) => l.itemId == itemId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<List<RestaurantInventoryLossModel>> getByDateRange(
      DateTime start, DateTime end) async {
    return _box.values.where((l) {
      final at = DateTime.tryParse(l.recordedAt);
      if (at == null) return false;
      final day = DateTime(at.year, at.month, at.day);
      return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
          !day.isAfter(DateTime(end.year, end.month, end.day));
    }).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<void> delete(String lossId) async => _box.delete(lossId);
}
