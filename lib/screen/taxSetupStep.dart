import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_tax.dart';
import 'package:unipos/models/tax_details.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../util/color.dart';
import '../core/config/app_config.dart';
import '../core/di/service_locator.dart';
import 'package:unipos/util/restaurant/staticswitch.dart';

/// Tax Setup Step
/// UI Only - uses Observer to listen to store changes
/// Calls store methods for actions
class TaxSetupStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const TaxSetupStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<TaxSetupStep> createState() => _TaxSetupStepState();
}

class _TaxSetupStepState extends State<TaxSetupStep> {
  final _taxNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _uuid = const Uuid();

  List<TaxItem> _taxes = [];

  @override
  void initState() {
    super.initState();
    // Load existing tax data from store and database
    _loadFromStore();
    _loadFromDatabase();
    _loadRestaurantSettings();
  }

  void _loadFromStore() {
    // If store has tax data, populate the list
    if (widget.store.taxName.isNotEmpty && widget.store.taxRate > 0) {
      _taxes = [
        TaxItem(widget.store.taxName, widget.store.taxRate, true),
      ];
    }
  }

  /// Load tax settings from AppSettings for restaurant mode
  /// This ensures the setup wizard toggle syncs with the restaurant customization settings
  Future<void> _loadRestaurantSettings() async {
    if (AppConfig.isRestaurant) {
      // Load AppSettings to get current "Tax Is Inclusive" setting
      // This is the SAME setting controlled in:
      // Restaurant → Settings & Customization → Order Processing → "Tax Is Inclusive"
      await AppSettings.load();

      // Sync the loaded value to the store so the toggle shows correct state
      widget.store.setTaxEnabled(AppSettings.isTaxInclusive);
      print('📥 Loaded restaurant tax settings from AppSettings: Tax Is Inclusive = ${AppSettings.isTaxInclusive}');
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      // Only load from restaurant tax database if in restaurant mode
      if (AppConfig.isRestaurant) {
        final existingTaxes = await taxStore.taxes.toList();
        if (existingTaxes.isNotEmpty && _taxes.isEmpty) {
          setState(() {
            _taxes = existingTaxes.map((tax) {
              return TaxItem(tax.taxname, tax.taxperecentage ?? 0, false);
            }).toList();
            if (_taxes.isNotEmpty) {
              _taxes[0] = TaxItem(_taxes[0].name, _taxes[0].rate, true);
            }
          });
          _syncToStore();
        }
      }
    } catch (e) {
      print('Error loading taxes from database: $e');
    }
  }

  /// Save all taxes to restaurant Hive database (restaurant mode only)
  Future<void> _saveTaxesToDatabase() async {
    // Only save to restaurant tax database if in restaurant mode
    if (!AppConfig.isRestaurant) {
      print('ℹ️ Skipping restaurant tax save (not in restaurant mode)');
      return;
    }

    try {
      print('💾 Saving ${_taxes.length} taxes to restaurant database...');

      // Get existing taxes from database
      final existingTaxes = await taxStore.taxes.toList();

      // Create a map of existing taxes by name for quick lookup
      final existingTaxMap = <String, Tax>{};
      for (final tax in existingTaxes) {
        existingTaxMap[tax.taxname.toLowerCase()] = tax;
      }

      // Save or update each tax
      for (final taxItem in _taxes) {
        final existingTax = existingTaxMap[taxItem.name.toLowerCase()];

        if (existingTax != null) {
          // Update existing tax
          existingTax.taxperecentage = taxItem.rate;
          await taxStore.updateTax(existingTax);
          print('🔄 Updated tax: ${existingTax.taxname} (${existingTax.taxperecentage}%)');
        } else {
          // Create new tax
          final tax = Tax(
            id: _uuid.v4(), // Generate unique ID
            taxname: taxItem.name,
            taxperecentage: taxItem.rate,
          );
          await taxStore.addTax(tax);
          print('✅ Created tax: ${tax.taxname} (${tax.taxperecentage}%)');
        }
      }

      print('✅ All taxes saved to restaurant database');
    } catch (e) {
      print('❌ Error saving taxes to database: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save taxes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _taxNameController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _addTax() {
    if (_taxNameController.text.isNotEmpty && _taxRateController.text.isNotEmpty) {
      setState(() {
        _taxes.add(TaxItem(
          _taxNameController.text,
          double.parse(_taxRateController.text),
          _taxes.isEmpty,
        ));
        _taxNameController.clear();
        _taxRateController.clear();
      });
      _syncToStore();
    }
  }

  void _syncToStore() {
    // Find default tax and save to store
    final defaultTax = _taxes.firstWhere(
      (t) => t.isDefault,
      orElse: () => _taxes.isNotEmpty ? _taxes.first : TaxItem('GST', 0, true),
    );
    widget.store.setTaxName(defaultTax.name);
    widget.store.setTaxRate(defaultTax.rate);
    // Save all tax rates to store
    widget.store.setTaxRates(_taxes);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tax Configuration',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Configure tax settings for your business',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),

          // Tax Settings Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tax Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNeutral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ✅ Tax Inclusive Toggle
                // This toggle is CONNECTED to Restaurant → Settings & Customization → "Tax Is Inclusive"
                // Both toggles control the SAME setting via AppSettings
                Observer(
                  builder: (_) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Include Tax in Pricing',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            if (AppConfig.isRestaurant)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Also accessible in Settings & Customization',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: widget.store.taxEnabled,
                        onChanged: (value) async {
                          // Update the store value for UI reactivity
                          widget.store.setTaxEnabled(value);

                          // ✅ CRITICAL: For restaurant mode, sync to AppSettings
                          // This ensures the toggle in "Settings & Customization" shows the same value
                          if (AppConfig.isRestaurant) {
                            await AppSettings.updateSetting('Tax Is Inclusive', value);
                            print('✅ Tax setting synced to AppSettings: Tax Is Inclusive = $value');
                          }
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                // Tax Type Selection - Only show for RETAIL mode
                // Restaurant manages this in Settings screen, not setup wizard
                if (AppConfig.isRetail) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Tax Type',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Observer(
                    builder: (_) => Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Exclusive'),
                            value: false,
                            groupValue: widget.store.taxInclusive,
                            onChanged: (value) => widget.store.setTaxInclusive(value!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Inclusive'),
                            value: true,
                            groupValue: widget.store.taxInclusive,
                            onChanged: (value) => widget.store.setTaxInclusive(value!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Add Tax Rates
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_circle, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tax Rates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNeutral,
                      ),
                    ),
                  ],

                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _taxNameController,
                        decoration: InputDecoration(
                          labelText: 'Tax Name',
                          hintText: 'e.g., GST, VAT',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _taxRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Rate %',
                          hintText: '18',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _addTax,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),

                if (_taxes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ...List.generate(_taxes.length, (index) {
                    final tax = _taxes[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _taxes = _taxes.asMap().entries.map((entry) {
                            return TaxItem(
                              entry.value.name,
                              entry.value.rate,
                              entry.key == index,
                            );
                          }).toList();
                        });
                        _syncToStore();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tax.isDefault ? AppColors.primary : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: tax.isDefault ? AppColors.primary : Colors.grey[400],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${tax.name} - ${tax.rate}%',
                                style: TextStyle(
                                  fontWeight: tax.isDefault ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (tax.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 18, color: AppColors.danger),
                              onPressed: () {
                                setState(() {
                                  _taxes.removeAt(index);
                                  if (_taxes.isNotEmpty && index == 0) {
                                    _taxes[0] = TaxItem(_taxes[0].name, _taxes[0].rate, true);
                                  }
                                });
                                _syncToStore();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: Observer(
                  builder: (_) => ElevatedButton(
                    onPressed: widget.store.isLoading
                        ? null
                        : () async {
                            // Save to configuration store
                            widget.store.saveTaxDetails();

                            // ✅ Save tax settings based on mode
                            if (AppConfig.isRetail) {
                              // Retail: Save to GstService
                              await gstService.setTaxInclusiveMode(widget.store.taxInclusive);
                              // Also save the default tax rate if one is selected
                              if (_taxes.isNotEmpty) {
                                final defaultTax = _taxes.firstWhere(
                                  (t) => t.isDefault,
                                  orElse: () => _taxes.first,
                                );
                                await gstService.setDefaultGstRate(defaultTax.rate);
                              }
                              print('✅ Tax settings saved to GstService:');
                              print('   - Tax Inclusive: ${widget.store.taxInclusive}');
                              print('   - Default Rate: ${_taxes.isNotEmpty ? _taxes.firstWhere((t) => t.isDefault, orElse: () => _taxes.first).rate : 0}%');
                            } else if (AppConfig.isRestaurant) {
                              // Restaurant: Save to AppSettings
                              await AppSettings.updateSetting('Tax Is Inclusive', widget.store.taxEnabled);
                              print('✅ Restaurant tax settings saved to AppSettings:');
                              print('   - Tax Is Inclusive: ${widget.store.taxEnabled}');
                            }

                            // Save to restaurant database
                            await _saveTaxesToDatabase();

                            // Continue to next step
                            widget.onNext();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: widget.store.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============== DATA MODELS ==============
class TaxItem {
  final String name;
  final double rate;
  final bool isDefault;

  TaxItem(this.name, this.rate, this.isDefault);
}