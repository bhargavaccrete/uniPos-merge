import 'package:hive/hive.dart';
import '../data/models/common/business_type.dart';

class BusinessTypeBox {
  static const String _boxName = 'businessTypeBox';
  static const String _selectedKey = 'selectedBusinessType';

  static Box<BusinessType> openBox() {
    // Box is already opened during app startup in HiveInit
    return Hive.box<BusinessType>(_boxName);
  }

  static Box<BusinessType> getBox() {
    return Hive.box<BusinessType>(_boxName);
  }

  // Save selected business type
  static Future<void> saveSelectedType(BusinessType type) async {
    final box = getBox();
    await box.put(_selectedKey, type);
  }

  // Get selected business type
  static BusinessType? getSelectedType() {
    final box = getBox();
    return box.get(_selectedKey);
  }

  // Delete selected business type
  static Future<void> deleteSelectedType() async {
    final box = getBox();
    await box.delete(_selectedKey);
  }

  // Clear all data
  static Future<void> clearBox() async {
    final box = getBox();
    await box.clear();
  }

  // Check if business type is selected
  static bool hasSelectedType() {
    return getSelectedType() != null;
  }
}