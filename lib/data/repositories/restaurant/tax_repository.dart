import 'package:hive/hive.dart';

import '../../models/restaurant/db/taxmodel_314.dart';

/// Repository layer for Tax data access
class TaxRepository {
  static const String _boxName = 'TaxBox';
  late Box<Tax> _taxBox;

  TaxRepository() {
    _taxBox = Hive.box<Tax>(_boxName);
  }

  List<Tax> getAllTaxes() {
    return _taxBox.values.toList();
  }

  Future<void> addTax(Tax tax) async {
    await _taxBox.put(tax.id, tax);
  }

  Future<void> updateTax(Tax tax) async {
    await _taxBox.put(tax.id, tax);
  }

  Future<void> deleteTax(String id) async {
    await _taxBox.delete(id);
  }

  Tax? getTaxById(String id) {
    return _taxBox.get(id);
  }

  int getTaxCount() {
    return _taxBox.length;
  }

  Future<void> clearAll() async {
    await _taxBox.clear();
  }
}