import 'package:hive/hive.dart';
import '../models/common/business_details.dart';

/// Repository for BusinessDetails - handles only Hive CRUD operations
/// No UI logic, no MobX - just database operations
class BusinessDetailsRepository {
  static const String _boxName = 'businessDetailsBox';
  static const String _key = 'businessDetails';

  Box<BusinessDetails> get _box => Hive.box<BusinessDetails>(_boxName);

  // CREATE / UPDATE
  Future<void> save(BusinessDetails details) async {
    await _box.put(_key, details);
  }

  // READ
  BusinessDetails? get() {
    return _box.get(_key);
  }

  // READ - check exists
  bool exists() {
    return _box.containsKey(_key);
  }

  // DELETE
  Future<void> delete() async {
    await _box.delete(_key);
  }

  // CLEAR ALL
  Future<void> clearAll() async {
    await _box.clear();
  }
}