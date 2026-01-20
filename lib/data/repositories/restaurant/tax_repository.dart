import 'package:hive/hive.dart';
import '../../models/restaurant/db/taxmodel_314.dart';

/// Repository layer for Tax data access (Restaurant)
/// Handles all Hive database operations for taxes
class TaxRepository {
  late Box<Tax> _taxBox;

  TaxRepository() {
    _taxBox = Hive.box<Tax>('restaurant_taxes');
  }

  /// Add a new tax
  Future<void> addTax(Tax tax) async {
    await _taxBox.put(tax.id, tax);
  }

  /// Get all taxes
  Future<List<Tax>> getAllTaxes() async {
    return _taxBox.values.toList();
  }

  /// Get tax by ID
  Future<Tax?> getTaxById(String id) async {
    return _taxBox.get(id);
  }

  /// Update tax
  Future<void> updateTax(Tax tax) async {
    await _taxBox.put(tax.id, tax);
  }

  /// Delete tax
  Future<void> deleteTax(String id) async {
    await _taxBox.delete(id);
  }

  /// Search taxes by name
  Future<List<Tax>> searchTaxes(String query) async {
    if (query.isEmpty) return getAllTaxes();

    final lowercaseQuery = query.toLowerCase();
    return _taxBox.values
        .where((tax) => tax.taxname.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get tax count
  Future<int> getTaxCount() async {
    return _taxBox.length;
  }

  /// Get taxes sorted by rate
  Future<List<Tax>> getTaxesSortedByRate({bool ascending = true}) async {
    final taxes = _taxBox.values.toList();
    taxes.sort((a, b) => ascending
        ? (a.taxperecentage ?? 0).compareTo(b.taxperecentage ?? 0)
        : (b.taxperecentage ?? 0).compareTo(a.taxperecentage ?? 0));
    return taxes;
  }
}