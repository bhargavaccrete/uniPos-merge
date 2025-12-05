import 'package:hive/hive.dart';
import '../models/common/business_type.dart';

/// Repository for BusinessType - handles only Hive CRUD operations
/// No UI logic, no MobX - just database operations
class BusinessTypeRepository {
  static const String _boxName = 'businessTypeBox';
  static const String _selectedKey = 'selectedBusinessType';

  Box<BusinessType> get _box => Hive.box<BusinessType>(_boxName);

  // CREATE / UPDATE
  Future<void> saveSelectedType(BusinessType type) async {
    await _box.put(_selectedKey, type);
  }

  // READ
  BusinessType? getSelectedType() {
    return _box.get(_selectedKey);
  }

  // READ - check exists
  bool hasSelectedType() {
    return _box.containsKey(_selectedKey);
  }

  // DELETE
  Future<void> deleteSelectedType() async {
    await _box.delete(_selectedKey);
  }

  // CLEAR ALL
  Future<void> clearAll() async {
    await _box.clear();
  }
}