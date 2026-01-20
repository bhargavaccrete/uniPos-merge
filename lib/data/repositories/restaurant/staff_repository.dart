import 'package:hive/hive.dart';
import '../../models/restaurant/db/staffModel_310.dart';

/// Repository layer for Staff data access (Restaurant)
/// Handles all Hive database operations for staff members
class StaffRepository {
  late Box<StaffModel> _staffBox;

  StaffRepository() {
    _staffBox = Hive.box<StaffModel>('staffBox');
  }

  /// Add a new staff member
  Future<void> addStaff(StaffModel staff) async {
    await _staffBox.put(staff.id, staff);
  }

  /// Get all staff members
  Future<List<StaffModel>> getAllStaff() async {
    return _staffBox.values.toList();
  }

  /// Get staff by ID
  Future<StaffModel?> getStaffById(String id) async {
    return _staffBox.get(id);
  }

  /// Update staff member
  Future<void> updateStaff(StaffModel staff) async {
    await _staffBox.put(staff.id, staff);
  }

  /// Delete staff member
  Future<void> deleteStaff(String id) async {
    await _staffBox.delete(id);
  }

  /// Search staff by name or username
  Future<List<StaffModel>> searchStaff(String query) async {
    if (query.isEmpty) return getAllStaff();

    final lowercaseQuery = query.toLowerCase();
    return _staffBox.values
        .where((staff) =>
            staff.firstName.toLowerCase().contains(lowercaseQuery) ||
            staff.lastName.toLowerCase().contains(lowercaseQuery) ||
            staff.userName.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get staff by cashier status
  Future<List<StaffModel>> getStaffByCashierStatus(String isCashier) async {
    return _staffBox.values
        .where((staff) => staff.isCashier == isCashier)
        .toList();
  }

  /// Get active staff members
  Future<List<StaffModel>> getActiveStaff() async {
    return _staffBox.values.where((staff) => staff.isActive == true).toList();
  }

  /// Get staff count
  Future<int> getStaffCount() async {
    return _staffBox.length;
  }

  /// Check if staff exists
  Future<bool> staffExists(String id) async {
    return _staffBox.containsKey(id);
  }
}