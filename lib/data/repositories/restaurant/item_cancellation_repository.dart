import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/item_cancellation_model_134.dart';

/// Hive access for item-level cancellation audit records.
class ItemCancellationRepository {
  Box<ItemCancellationModel> get _box =>
      Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations);

  Future<void> add(ItemCancellationModel record) async {
    await _box.put(record.id, record);
  }

  /// All records, newest first.
  List<ItemCancellationModel> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> delete(String id) async => _box.delete(id);
}
