import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/inventory_loss_model_178.dart';

/// Hive I/O for inventory losses.
///
/// Append-only in practice: a loss is a historical fact, so nothing here
/// updates a row. [delete] exists only for cleanup paths.
class InventoryLossRepository {
  Box<InventoryLossModel> get _box =>
      Hive.box<InventoryLossModel>(HiveBoxNames.inventoryLosses);

  Future<List<InventoryLossModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<void> save(InventoryLossModel model) async {
    await _box.put(model.lossId, model);
  }

  Future<void> saveAll(List<InventoryLossModel> models) async {
    for (final model in models) {
      await _box.put(model.lossId, model);
    }
  }

  Future<List<InventoryLossModel>> getByGRN(String grnId) async {
    return _box.values.where((l) => l.grnId == grnId).toList();
  }

  Future<List<InventoryLossModel>> getByVariant(String variantId) async {
    return _box.values.where((l) => l.variantId == variantId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<List<InventoryLossModel>> getByDateRange(
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
