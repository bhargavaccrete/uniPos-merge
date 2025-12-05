import 'package:hive/hive.dart';
import 'package:unipos/models/tax_details.dart';

class TaxBox {
  static const String _boxName = 'taxBox';
  static const String _key = 'tax';

  // Open the tax box
  static Future<Box<TaxDetails>> openBox() async {
    return await Hive.openBox<TaxDetails>(_boxName);
  }

  // Get already-opened box
  static Box<TaxDetails> getBox() {
    return Hive.box<TaxDetails>(_boxName);
  }

  // Save or replace the single tax record
  static Future<void> saveTax(TaxDetails tax) async {
    final box = getBox();
    await box.put(_key, tax);
    print('✅ Tax details saved successfully to Hive!');
  }

  // Get the tax details
  static TaxDetails? getTax() {
    final box = getBox();
    return box.get(_key);
  }

  // Check if tax details exist
  static bool hasTax() {
    final box = getBox();
    return box.containsKey(_key);
  }

  // Update specific tax fields
  static Future<void> updateTax({
    bool? isEnabled,
    bool? isInclusive,
    double? defaultRate,
    String? taxName,
    String? placeOfSupply,
    bool? applyOnDelivery,
    String? notes,
  }) async {
    final currentTax = getTax();
    if (currentTax != null) {
      final updatedTax = currentTax.copyWith(
        isEnabled: isEnabled,
        isInclusive: isInclusive,
        defaultRate: defaultRate,
        taxName: taxName,
        placeOfSupply: placeOfSupply,
        applyOnDelivery: applyOnDelivery,
        notes: notes,
      );
      await saveTax(updatedTax);
    }
  }

  // Delete tax details
  static Future<void> deleteTax() async {
    final box = getBox();
    await box.delete(_key);
    print('🗑️ Tax details deleted from Hive!');
  }

  // Clear all tax data
  static Future<void> clearAll() async {
    final box = getBox();
    await box.clear();
    print('🧹 All tax data cleared from Hive!');
  }

  // Get tax status summary
  static Map<String, dynamic> getTaxSummary() {
    final tax = getTax();
    if (tax == null) {
      return {
        'exists': false,
        'isEnabled': false,
        'taxName': 'No tax configured',
        'defaultRate': 0.0,
      };
    }
    
    return {
      'exists': true,
      'isEnabled': tax.isEnabled,
      'taxName': tax.taxName,
      'defaultRate': tax.defaultRate,
      'isInclusive': tax.isInclusive,
      'placeOfSupply': tax.placeOfSupply ?? 'Not specified',
    };
  }

  // Enable/disable tax
  static Future<void> setTaxEnabled(bool enabled) async {
    await updateTax(isEnabled: enabled);
  }

  // Set tax rate
  static Future<void> setTaxRate(double rate) async {
    await updateTax(defaultRate: rate);
  }

  // Set tax type (inclusive/exclusive)
  static Future<void> setTaxType(bool isInclusive) async {
    await updateTax(isInclusive: isInclusive);
  }
}