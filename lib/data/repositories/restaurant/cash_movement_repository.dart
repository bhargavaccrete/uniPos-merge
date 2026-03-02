import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/cash_movement_model.dart';

/// Data access layer for [CashMovementModel].
///
/// All reads go through this class — no screen touches Hive directly.
/// This keeps the Hive box name in one place and makes testing easier.
class CashMovementRepository {
  late Box<CashMovementModel> _box;

  CashMovementRepository() {
    _box = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
  }

  /// Persist a movement. Uses [id] as the Hive key so save = upsert.
  Future<void> saveMovement(CashMovementModel movement) async {
    await _box.put(movement.id, movement);
  }

  /// All movements whose timestamp falls on or after [dayStart].
  /// Used by the Cash Drawer screen to show today's activity log.
  Future<List<CashMovementModel>> getTodayMovements(DateTime dayStart) async {
    final all = _box.values.toList();
    // Include movements from dayStart to now, sorted oldest first for the log
    return all
        .where((m) =>
            m.timestamp.isAfter(dayStart.subtract(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// All movements ever recorded, newest first.
  Future<List<CashMovementModel>> getAllMovements() async {
    final all = _box.values.toList();
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  /// Count of all movements stored.
  int get count => _box.length;
}
