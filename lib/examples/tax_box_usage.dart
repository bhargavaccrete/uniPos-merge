// Example usage of TaxBox - for demonstration purposes
import 'package:unipos/Boxes/hive_tax.dart';
import 'package:unipos/models/tax_details.dart';

class TaxBoxUsageExample {
  
  // Example: Save tax configuration
  static Future<void> saveTaxConfiguration() async {
    final taxDetails = TaxDetails(
      isEnabled: true,
      isInclusive: false, // Tax exclusive
      defaultRate: 18.0,  // 18% GST
      taxName: 'GST',
      placeOfSupply: 'Karnataka',
      applyOnDelivery: true,
      notes: 'Standard GST rate for Karnataka',
    );
    
    await TaxBox.saveTax(taxDetails);
    print('Tax configuration saved!');
  }
  
  // Example: Load and display tax configuration
  static void loadTaxConfiguration() {
    final tax = TaxBox.getTax();
    
    if (tax != null) {
      print('Tax Configuration Found:');
      print('- Enabled: ${tax.isEnabled}');
      print('- Type: ${tax.isInclusive ? "Inclusive" : "Exclusive"}');
      print('- Rate: ${tax.defaultRate}%');
      print('- Name: ${tax.taxName}');
      print('- Place of Supply: ${tax.placeOfSupply ?? "Not specified"}');
      print('- Apply on Delivery: ${tax.applyOnDelivery}');
      print('- Notes: ${tax.notes ?? "No notes"}');
    } else {
      print('No tax configuration found');
    }
  }
  
  // Example: Update specific tax settings
  static Future<void> updateTaxRate(double newRate) async {
    if (TaxBox.hasTax()) {
      await TaxBox.setTaxRate(newRate);
      print('Tax rate updated to ${newRate}%');
    } else {
      print('No tax configuration to update');
    }
  }
  
  // Example: Toggle tax enabled/disabled
  static Future<void> toggleTax() async {
    final tax = TaxBox.getTax();
    if (tax != null) {
      await TaxBox.setTaxEnabled(!tax.isEnabled);
      print('Tax ${tax.isEnabled ? "disabled" : "enabled"}');
    }
  }
  
  // Example: Get tax summary for dashboard
  static void displayTaxSummary() {
    final summary = TaxBox.getTaxSummary();
    
    print('=== Tax Summary ===');
    print('Status: ${summary['exists'] ? "Configured" : "Not configured"}');
    print('Enabled: ${summary['isEnabled']}');
    print('Tax Name: ${summary['taxName']}');
    print('Default Rate: ${summary['defaultRate']}%');
    
    if (summary['exists']) {
      print('Type: ${summary['isInclusive'] ? "Inclusive" : "Exclusive"}');
      print('Place of Supply: ${summary['placeOfSupply']}');
    }
  }
  
  // Example: Complete tax setup flow
  static Future<void> setupTaxFlow() async {
    print('Starting tax setup...');
    
    // 1. Check if tax already exists
    if (TaxBox.hasTax()) {
      print('Tax already configured. Current settings:');
      displayTaxSummary();
      return;
    }
    
    // 2. Create default tax configuration
    await saveTaxConfiguration();
    
    // 3. Verify it was saved
    print('Verifying tax configuration...');
    loadTaxConfiguration();
    
    // 4. Show summary
    displayTaxSummary();
    
    print('Tax setup complete!');
  }
  
  // Example: Reset tax configuration
  static Future<void> resetTaxConfiguration() async {
    await TaxBox.deleteTax();
    print('Tax configuration reset');
  }
}