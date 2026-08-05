import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tax_feature.dart';

class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

class _GstSettingsScreenState extends State<GstSettingsScreen> {
  bool _taxInclusiveMode = false;
  double _defaultGstRate = 0;
  bool _isLoading = true;
  final GstService _gstService = GstService();

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _taxInclusiveMode = await _gstService.isTaxInclusiveMode();
      _defaultGstRate = await _gstService.getDefaultGstRate();
    } catch (e) {
      debugPrint('Error loading GST settings: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleTaxInclusiveMode(bool value) async {
    await _gstService.setTaxInclusiveMode(value);
    setState(() => _taxInclusiveMode = value);
  }

  Future<void> _updateDefaultGstRate(double rate) async {
    await _gstService.setDefaultGstRate(rate);
    setState(() => _defaultGstRate = rate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('GST Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('General Settings'),
                  const SizedBox(height: 12),
                  _buildGeneralSettingsCard(),
                  const SizedBox(height: 24),

                  // Note: GST/HSN is set per product (and can be overridden per
                  // variant) — not per category, since one category can hold
                  // items with different tax classes.
                  _buildSectionTitle('Tax Rates'),
                  const SizedBox(height: 12),
                  _buildTaxRatesCard(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Common GST Rates (India)'),
                  const SizedBox(height: 12),
                  _buildGstRateReferenceCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildTaxDisabledNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFFFF8E1),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFFB28900)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7A5C00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
    final enabled = TaxFeature.enabled;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        children: [
          if (!enabled)
            _buildTaxDisabledNotice(
                'Tax is currently disabled. This business is marked as not registered for tax during setup.'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tax Inclusive Mode Toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tax Inclusive Pricing',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Product prices include GST',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _taxInclusiveMode,
                      onChanged: enabled ? _toggleTaxInclusiveMode : null,
                      activeColor: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Default GST Rate
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Default GST Rate',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Applied when no product/variant tax is set',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: enabled ? () => _showDefaultGstRateDialog() : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_defaultGstRate.toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: enabled ? const Color(0xFF4CAF50) : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRatesCard() {
    if (!TaxFeature.enabled) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: _buildTaxDisabledNotice(
            'Tax rate management is unavailable while tax is disabled for this business.'),
      );
    }
    return Observer(
      builder: (_) {
        final taxes = taxStore.taxes;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
          ),
          child: Column(
            children: [
              if (taxes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No named tax rates yet. Add one to pick it on products/variants.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
              else
                ...taxes.map((tax) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tax.taxname,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${tax.taxperecentage ?? 0}%',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showTaxDialog(existingTax: tax),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: const Color(0xFF4CAF50),
                          ),
                          IconButton(
                            onPressed: () => _confirmDeleteTax(tax),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    )),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showTaxDialog(),
                    icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
                    label: const Text('Add Tax Rate', style: TextStyle(color: Color(0xFF4CAF50))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteTax(Tax tax) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tax?'),
        content: Text('Delete "${tax.taxname}" (${tax.taxperecentage ?? 0}%)? '
            'Products already using it keep their stored rate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await taxStore.deleteTax(tax.id);
    }
  }

  Future<void> _showTaxDialog({Tax? existingTax}) async {
    final nameController = TextEditingController(text: existingTax?.taxname ?? '');
    final rateController = TextEditingController(
      text: existingTax?.taxperecentage != null ? existingTax!.taxperecentage.toString() : '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingTax == null ? 'Add Tax Rate' : 'Edit Tax Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tax Name', hintText: 'e.g. GST'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateController,
              decoration: const InputDecoration(labelText: 'Rate %', hintText: 'e.g. 18'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final rate = double.tryParse(rateController.text.trim());
              if (name.isEmpty || rate == null || rate < 0 || rate > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid name and rate (0-100)')),
                );
                return;
              }
              if (existingTax == null) {
                await taxStore.addTax(Tax(id: const Uuid().v4(), taxname: name, taxperecentage: rate));
              } else {
                await taxStore.updateTax(existingTax.copyWith(taxname: name, taxperecentage: rate));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(existingTax == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildGstRateReferenceCard() {
    final rates = [
      {'rate': '0%', 'items': 'Essential goods, milk, vegetables, fruits'},
      {'rate': '5%', 'items': 'Clothing under Rs.1000, footwear under Rs.500'},
      {'rate': '12%', 'items': 'Clothing Rs.1000+, footwear Rs.500-1000'},
      {'rate': '18%', 'items': 'Electronics, appliances, services'},
      {'rate': '28%', 'items': 'Luxury goods, automobiles, cosmetics'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        children: rates.map((rate) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rate['rate']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rate['items']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showDefaultGstRateDialog() async {
    final taxes = taxStore.taxes;
    final rates = taxes.isNotEmpty
        ? taxes.map((t) => t.taxperecentage ?? 0).toSet().toList()
        : GstService.commonGstRates;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default GST Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: rates.map((rate) {
            return ListTile(
              title: Text('${rate.toInt()}%'),
              leading: Radio<double>(
                value: rate,
                groupValue: _defaultGstRate,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    _updateDefaultGstRate(value);
                  }
                },
                activeColor: const Color(0xFF4CAF50),
              ),
              onTap: () {
                Navigator.pop(context);
                _updateDefaultGstRate(rate);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
