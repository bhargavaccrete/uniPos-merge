import 'package:hive/hive.dart';
import 'package:unipos/models/tax_details.dart';

/// Repository for TaxDetails - handles only Hive CRUD operations
/// No UI logic, no MobX - just database operations
class TaxDetailsRepository {
  static const String _boxName = 'taxBox';
  static const String _key = 'taxDetails';

  Box<TaxDetails> get _box => Hive.box<TaxDetails>(_boxName);

  // CREATE / UPDATE
  Future<void> save(TaxDetails details) async {
    await _box.put(_key, details);
  }

  // READ
  TaxDetails? get() {
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
