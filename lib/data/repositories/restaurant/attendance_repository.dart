import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/attendance_model.dart';

class AttendanceRepository {
  Box<AttendanceModel> get _box =>
      Hive.box<AttendanceModel>(HiveBoxNames.restaurantAttendance);

  /// Get all records
  Future<List<AttendanceModel>> getAllRecords() async {
    return _box.values.toList();
  }

  /// Get records for a specific date
  Future<List<AttendanceModel>> getRecordsByDate(String dateKey) async {
    return _box.values.where((r) => r.date == dateKey).toList()
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));
  }

  /// Get records for a specific month (between start and end dates)
  Future<List<AttendanceModel>> getRecordsBetweenDates(DateTime start, DateTime end) async {
    return _box.values.where((r) {
      return r.clockIn.isAfter(start.subtract(const Duration(seconds: 1))) &&
             r.clockIn.isBefore(end.add(const Duration(seconds: 1)));
    }).toList()
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));
  }

  /// Get a single record by ID
  AttendanceModel? getRecordById(String id) {
    return _box.get(id);
  }

  /// Add a new record
  Future<void> addRecord(AttendanceModel record) async {
    await _box.put(record.id, record);
  }

  /// Update an existing record
  Future<void> updateRecord(AttendanceModel record) async {
    await record.save(); // Since it extends HiveObject
  }

  /// Delete a record
  Future<void> deleteRecord(String id) async {
    await _box.delete(id);
  }
}