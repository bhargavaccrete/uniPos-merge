import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/shift_model.dart';
import '../../models/restaurant/db/pastordermodel_313.dart';

/// Repository layer for Shift data access (Restaurant)
/// Handles all Hive database operations for staff shifts
class ShiftRepository {
  late Box<ShiftModel> _shiftBox;

  ShiftRepository() {
    _shiftBox = Hive.box<ShiftModel>(HiveBoxNames.restaurantShift);
  }

  /// Save (insert or update) a shift
  Future<void> saveShift(ShiftModel shift) async {
    await _shiftBox.put(shift.id, shift);
  }

  /// Get shift by ID
  Future<ShiftModel?> getShiftById(String id) async {
    return _shiftBox.get(id);
  }

  /// Get all shifts, sorted newest first
  Future<List<ShiftModel>> getAllShifts() async {
    final list = _shiftBox.values.toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  /// Get open shift for a specific staff member, or null if none
  Future<ShiftModel?> getOpenShiftForStaff(String staffId) async {
    try {
      return _shiftBox.values.firstWhere(
        (s) => s.staffId == staffId && s.status == 'open',
      );
    } catch (_) {
      return null;
    }
  }

  /// Get shifts within a date range (filter by startTime)
  Future<List<ShiftModel>> getShiftsByDateRange(
      DateTime start, DateTime end) async {
    return _shiftBox.values
        .where((s) =>
            s.startTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
            s.startTime.isBefore(end.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Delete a shift by ID
  Future<void> deleteShift(String id) async {
    await _shiftBox.delete(id);
  }

  /// Get total shift count
  Future<int> getShiftCount() async {
    return _shiftBox.length;
  }

  /// Check if a shift exists
  Future<bool> shiftExists(String id) async {
    return _shiftBox.containsKey(id);
  }

  /// Returns pastOrders belonging to the given shift.
  ///
  /// Strategy (no global flag — per-order decision):
  ///   • Orders WITH shiftId == shift.id  → always included (direct link).
  ///   • Orders WITH a different shiftId  → always excluded (belong elsewhere).
  ///   • Orders WITH shiftId == null      → included only if their orderAt falls
  ///     inside this shift's time window (legacy / missed assignment fallback).
  ///
  /// This avoids the previous bug where a single order having any shiftId would
  /// silently exclude ALL null-shiftId orders from every shift report.
  Future<List<PastOrderModel>> getOrdersForShift(ShiftModel shift) async {
    final pastOrderBox =
        Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    final all = pastOrderBox.values.toList();
    final end = shift.endTime ?? DateTime.now();

    return all.where((o) {
      // Direct match — order explicitly linked to this shift
      if (o.shiftId == shift.id) return true;

      // Belongs to a different shift — exclude
      if (o.shiftId != null) return false;

      // Legacy / null-shiftId — include if time falls within shift window
      return o.orderAt != null &&
          o.orderAt!
              .isAfter(shift.startTime.subtract(const Duration(seconds: 1))) &&
          o.orderAt!.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }
}