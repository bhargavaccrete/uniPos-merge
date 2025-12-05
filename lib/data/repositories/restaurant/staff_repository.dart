import 'package:hive/hive.dart';

import '../../models/restaurant/db/staffModel_310.dart';

/// Repository layer for Staff data access
class StaffRepository {
  static const String _boxName = 'staffBox';
  late Box<StaffModel> _staffBox;

  StaffRepository() {
    _staffBox = Hive.box<StaffModel>(_boxName);
  }

  List<StaffModel> getAllStaff() {
    return _staffBox.values.toList();
  }

  Future<void> addStaff(StaffModel staff) async {
    await _staffBox.put(staff.id, staff);
  }

  Future<void> updateStaff(StaffModel staff) async {
    await _staffBox.put(staff.id, staff);
  }

  Future<void> deleteStaff(String id) async {
    await _staffBox.delete(id);
  }

  StaffModel? getStaffById(String id) {
    return _staffBox.get(id);
  }

  StaffModel? getStaffByPin(String pin) {
    try {
      return _staffBox.values.firstWhere((staff) => staff.pinNo == pin);
    } catch (e) {
      return null;
    }
  }

  List<StaffModel> getActiveStaff() {
    return _staffBox.values.where((staff) => staff.isActive == true).toList();
  }

  int getStaffCount() {
    return _staffBox.length;
  }

  Future<void> clearAll() async {
    await _staffBox.clear();
  }
}