import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';


class VariantManagementScreen extends StatefulWidget {
  final ProductModel product;

  const VariantManagementScreen({
    super.key,
    required this.product,
  });

  @override
  State<VariantManagementScreen> createState() => _VariantManagementScreenState();
}

class _VariantManagementScreenState extends State<VariantManagementScreen> {
  List<VarianteModel> variants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() => isLoading = true);
    final loadedVariants = await productStore.getVariantsForProduct(widget.product.productId);
    setState(() {
      variants = loadedVariants;
      isLoading = false;
    });
  }

  Future<void> _deleteVariant(VarianteModel variant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variant'),
        content: Text('Are you sure you want to delete ${_getVariantDisplayName(variant)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await productStore.deleteVariant(variant.varianteId);
      await _loadVariants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Variant deleted successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }

  String _getVariantDisplayName(VarianteModel variant) {
    return variant.shortDescription;
  }

  Color _getColorFromName(String? colorName) {
    if (colorName == null) return Colors.grey;
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'brown':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.productName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              'Manage Variants',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
            onPressed: () => _showAddVariantDialog(),
            tooltip: 'Add Variant',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : variants.isEmpty
              ? _buildEmptyState()
              : _buildVariantList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Color(0xFFD0D0D0),
          ),
          const SizedBox(height: 16),
          const Text(
            'No variants added yet',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add variants with different sizes, colors, etc.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddVariantDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add First Variant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantList() {
    // Group variants by color
    final Map<String?, List<VarianteModel>> groupedVariants = {};
    for (var variant in variants) {
      final color = variant.color ?? 'No Color';
      if (!groupedVariants.containsKey(color)) {
        groupedVariants[color] = [];
      }
      groupedVariants[color]!.add(variant);
    }

    return Column(
      children: [
        _buildSummaryCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedVariants.length,
            itemBuilder: (context, index) {
              final color = groupedVariants.keys.elementAt(index);
              final colorVariants = groupedVariants[color]!;
              return _buildColorGroup(color, colorVariants);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stockQty);
    final totalVariants = variants.length;
    final avgPrice = variants.isNotEmpty
        ? variants.fold<double>(0, (sum, v) => sum + (v.costPrice ?? 0)) / variants.length
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Row(
        children: [
          _buildSummaryItem('Total Variants', totalVariants.toString(), Icons.widgets_outlined),
          const SizedBox(width: 16),
          _buildSummaryItem('Total Stock', totalStock.toString(), Icons.inventory_outlined),
          const SizedBox(width: 16),
          _buildSummaryItem('Avg Price', '₹${avgPrice.toStringAsFixed(0)}', Icons.currency_rupee),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF6B6B6B)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorGroup(String? color, List<VarianteModel> colorVariants) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                if (color != null && color != 'No Color')
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getColorFromName(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8E8E8),
                        width: 1,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  color ?? 'No Color',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Text(
                  '${colorVariants.length} variant${colorVariants.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          // Variants in this color
          ...colorVariants.map((variant) => _buildVariantItem(variant)),
        ],
      ),
    );
  }

  Widget _buildVariantItem(VarianteModel variant) {
    final isLowStock = variant.minStock != null && variant.stockQty <= variant.minStock!;

    return InkWell(
      onTap: () => _showEditVariantDialog(variant),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Size/Weight/Custom Attributes info
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (variant.size != null)
                    Text(
                      'Size: ${variant.size}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  if (variant.weight != null)
                    Text(
                      'Weight: ${variant.weight}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  // Custom Attributes
                  if (variant.customAttributes != null && variant.customAttributes!.isNotEmpty)
                    ...variant.customAttributes!.entries.map((entry) => Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6B6B),
                      ),
                    )),
                  if (variant.sku != null)
                    Text(
                      'SKU: ${variant.sku}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB0B0B0),
                      ),
                    ),
                ],
              ),
            ),
            // Price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${variant.costPrice?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  if (variant.mrp != null)
                    Text(
                      'MRP: ₹${variant.mrp!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ),
            // Stock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock: ${variant.stockQty}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isLowStock ? Colors.red : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (isLowStock)
                    const Text(
                      'Low Stock!',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Color(0xFF6B6B6B)),
                  onPressed: () => _showEditVariantDialog(variant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _deleteVariant(variant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVariantDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Choose Add Method',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        contentPadding: const EdgeInsets.all(16),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Single Variant Card
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => _AddVariantDialog(
                      productId: widget.product.productId,
                      onVariantAdded: _loadVariants,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_box_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Single Variant',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'One color, one size, one barcode',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9E9E9E)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bulk Variant Card
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => _BulkAddVariantDialog(
                      productId: widget.product.productId,
                      onVariantsAdded: _loadVariants,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2196F3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2196F3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.library_add_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Bulk Add Variants',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.flash_on, color: Color(0xFFFFC107), size: 18),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'One color, multiple sizes (S, M, L)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF2196F3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Helper text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFFF57C00)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Use Bulk Add to quickly create multiple sizes for one color',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditVariantDialog(VarianteModel variant) {
    showDialog(
      context: context,
      builder: (context) => _EditVariantDialog(
        variant: variant,
        onVariantUpdated: _loadVariants,
      ),
    );
  }
}

// Add Variant Dialog
class _AddVariantDialog extends StatefulWidget {
  final String productId;
  final VoidCallback onVariantAdded;

  const _AddVariantDialog({
    required this.productId,
    required this.onVariantAdded,
  });

  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _weightController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _taxRateController = TextEditingController();

  // Custom attributes
  final List<_CustomAttrData> _customAttributes = [];

  @override
  void dispose() {
    _sizeController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _taxRateController.dispose();
    for (var attr in _customAttributes) {
      attr.dispose();
    }
    super.dispose();
  }

  void _addCustomAttribute() {
    setState(() {
      _customAttributes.add(_CustomAttrData());
    });
  }

  void _removeCustomAttribute(int index) {
    setState(() {
      _customAttributes[index].dispose();
      _customAttributes.removeAt(index);
    });
  }

  Map<String, String>? _getCustomAttributesMap() {
    final map = <String, String>{};
    for (var attr in _customAttributes) {
      final key = attr.keyController.text.trim();
      final value = attr.valueController.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map.isEmpty ? null : map;
  }

  Future<void> _saveVariant() async {
    if (!_formKey.currentState!.validate()) return;

    final variantId = '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}';
    final variant = VarianteModel.create(
      varianteId: variantId,
      productId: widget.productId,
      size: _sizeController.text.trim().isEmpty ? null : _sizeController.text.trim(),
      color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
      weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      costPrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
      mrp: _mrpController.text.trim().isEmpty ? null : double.tryParse(_mrpController.text.trim()),
      stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
      minStock: _minStockController.text.trim().isEmpty ? null : int.tryParse(_minStockController.text.trim()),
      taxRate: _taxRateController.text.trim().isEmpty ? null : double.tryParse(_taxRateController.text.trim()),
      customAttributes: _getCustomAttributesMap(),
    );

    await productStore.addVariant(variant);

    if (mounted) {
      Navigator.pop(context);
      widget.onVariantAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Variant added successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Variant'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(_colorController, 'Color', 'e.g., Red, Blue'),
                const SizedBox(height: 12),
                _buildTextField(_sizeController, 'Size', 'e.g., S, M, L'),
                const SizedBox(height: 12),
                _buildTextField(_weightController, 'Weight (Optional)', 'e.g., 500g'),
                const SizedBox(height: 12),
                _buildTextField(_priceController, 'Cost Price', '0.00',
                  keyboardType: TextInputType.number, required: true),
                const SizedBox(height: 12),
                _buildTextField(_mrpController, 'MRP (Optional)', '0.00',
                  keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField(_stockController, 'Stock Quantity', '0',
                  keyboardType: TextInputType.number, required: true),
                const SizedBox(height: 12),
                _buildTextField(_minStockController, 'Min Stock (Optional)', '0',
                  keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField(_barcodeController, 'Barcode (Optional)', 'Scan or enter'),
                const SizedBox(height: 12),
                _buildTextField(_skuController, 'SKU (Optional)', 'Enter SKU'),
                const SizedBox(height: 12),
                _buildTextField(_taxRateController, 'Tax Rate % (Optional)', '0.00',
                  keyboardType: TextInputType.number),

                // Custom Attributes Section
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: [
                    const Text(
                      'Custom Attributes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addCustomAttribute,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                if (_customAttributes.isEmpty)
                  Text(
                    'Add custom attributes like Material, Flavor, etc.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ..._customAttributes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attr = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: attr.keyController,
                            decoration: const InputDecoration(
                              labelText: 'Attribute',
                              hintText: 'e.g., Material',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: attr.valueController,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              hintText: 'e.g., Cotton',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                          onPressed: () => _removeCustomAttribute(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveVariant,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: keyboardType,
      validator: required
          ? (value) => value == null || value.isEmpty ? 'Required' : null
          : null,
    );
  }
}

// Helper class for custom attribute data
class _CustomAttrData {
  final TextEditingController keyController = TextEditingController();
  final TextEditingController valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

// Edit Variant Dialog
class _EditVariantDialog extends StatefulWidget {
  final VarianteModel variant;
  final VoidCallback onVariantUpdated;

  const _EditVariantDialog({
    required this.variant,
    required this.onVariantUpdated,
  });

  @override
  State<_EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<_EditVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _stockController;
  late TextEditingController _priceController;
  late TextEditingController _minStockController;

  // Custom attributes
  final List<_CustomAttrData> _customAttributes = [];

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(text: widget.variant.stockQty.toString());
    _priceController = TextEditingController(text: widget.variant.costPrice?.toString() ?? '0');
    _minStockController = TextEditingController(text: widget.variant.minStock?.toString() ?? '');

    // Load existing custom attributes
    if (widget.variant.customAttributes != null) {
      for (var entry in widget.variant.customAttributes!.entries) {
        final attr = _CustomAttrData();
        attr.keyController.text = entry.key;
        attr.valueController.text = entry.value;
        _customAttributes.add(attr);
      }
    }
  }

  @override
  void dispose() {
    _stockController.dispose();
    _priceController.dispose();
    _minStockController.dispose();
    for (var attr in _customAttributes) {
      attr.dispose();
    }
    super.dispose();
  }

  void _addCustomAttribute() {
    setState(() {
      _customAttributes.add(_CustomAttrData());
    });
  }

  void _removeCustomAttribute(int index) {
    setState(() {
      _customAttributes[index].dispose();
      _customAttributes.removeAt(index);
    });
  }

  Map<String, String>? _getCustomAttributesMap() {
    final map = <String, String>{};
    for (var attr in _customAttributes) {
      final key = attr.keyController.text.trim();
      final value = attr.valueController.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map.isEmpty ? null : map;
  }

  Future<void> _updateVariant() async {
    if (!_formKey.currentState!.validate()) return;

    final updatedVariant = VarianteModel(
      varianteId: widget.variant.varianteId,
      productId: widget.variant.productId,
      size: widget.variant.size,
      color: widget.variant.color,
      weight: widget.variant.weight,
      sku: widget.variant.sku,
      barcode: widget.variant.barcode,
      mrp: widget.variant.mrp,
      costPrice: double.tryParse(_priceController.text.trim()),
      stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
      minStock: _minStockController.text.trim().isEmpty ? null : int.tryParse(_minStockController.text.trim()),
      taxRate: widget.variant.taxRate,
      createdAt: widget.variant.createdAt,
      updateAt: DateTime.now().toIso8601String(),
      customAttributes: _getCustomAttributesMap(),
    );

    await productStore.updateVariant(updatedVariant);

    if (mounted) {
      Navigator.pop(context);
      widget.onVariantUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Variant updated successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Variant'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display variant info
                if (widget.variant.hasAttributes)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.variant.variantDescription,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Min Stock (Optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),

                // Custom Attributes Section
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: [
                    const Text(
                      'Custom Attributes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addCustomAttribute,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                if (_customAttributes.isEmpty)
                  Text(
                    'No custom attributes',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ..._customAttributes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attr = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: attr.keyController,
                            decoration: const InputDecoration(
                              labelText: 'Attribute',
                              hintText: 'e.g., Material',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: attr.valueController,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              hintText: 'e.g., Cotton',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                          onPressed: () => _removeCustomAttribute(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateVariant,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }
}

// Bulk Add Variant Dialog
class _BulkAddVariantDialog extends StatefulWidget {
  final String productId;
  final VoidCallback onVariantsAdded;

  const _BulkAddVariantDialog({
    required this.productId,
    required this.onVariantsAdded,
  });

  @override
  State<_BulkAddVariantDialog> createState() => _BulkAddVariantDialogState();
}

class _BulkAddVariantDialogState extends State<_BulkAddVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _colorController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _baseBarcodeController = TextEditingController();
  final _taxRateController = TextEditingController();

  // Size selection
  final List<String> _availableSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  final Set<String> _selectedSizes = {};

  // Custom sizes
  final List<String> _customSizes = [];
  final _customSizeController = TextEditingController();

  @override
  void dispose() {
    _colorController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _baseBarcodeController.dispose();
    _taxRateController.dispose();
    _customSizeController.dispose();
    super.dispose();
  }

  Future<void> _saveVariants() async {
    if (!_formKey.currentState!.validate()) return;

    final allSizes = [..._selectedSizes, ..._customSizes];

    if (allSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one size'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final color = _colorController.text.trim().isEmpty ? null : _colorController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final mrp = _mrpController.text.trim().isEmpty ? null : double.tryParse(_mrpController.text.trim());
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = _minStockController.text.trim().isEmpty ? null : int.tryParse(_minStockController.text.trim());
    final baseBarcode = _baseBarcodeController.text.trim();
    final taxRate = _taxRateController.text.trim().isEmpty ? null : double.tryParse(_taxRateController.text.trim());

    // Create variants for each size
    int barcodeCounter = 1;
    for (final size in allSizes) {
      final variantId = '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}_$barcodeCounter';

      // Generate barcode: if base is provided, append counter
      String? barcode;
      if (baseBarcode.isNotEmpty) {
        barcode = '$baseBarcode${barcodeCounter.toString().padLeft(3, '0')}';
      }

      final variant = VarianteModel.create(
        varianteId: variantId,
        productId: widget.productId,
        size: size,
        color: color,
        weight: null,
        sku: null,
        barcode: barcode,
        costPrice: price,
        mrp: mrp,
        stockQty: stock,
        minStock: minStock,
        taxRate: taxRate,
      );

      await productStore.addVariant(variant);
      barcodeCounter++;

      // Small delay to ensure unique timestamps
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onVariantsAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${allSizes.length} variants added successfully'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _addCustomSize() {
    final customSize = _customSizeController.text.trim();
    if (customSize.isNotEmpty && !_customSizes.contains(customSize) && !_availableSizes.contains(customSize)) {
      setState(() {
        _customSizes.add(customSize);
        _customSizeController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Add Variants'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    hintText: 'e.g., Green, Red',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Size Selection
                const Text(
                  'Select Sizes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSizes.map((size) {
                    final isSelected = _selectedSizes.contains(size);
                    return FilterChip(
                      label: Text(size),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSizes.add(size);
                          } else {
                            _selectedSizes.remove(size);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF4CAF50),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),

                // Custom sizes
                if (_customSizes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _customSizes.map((size) {
                      return Chip(
                        label: Text(size),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _customSizes.remove(size);
                          });
                        },
                        backgroundColor: const Color(0xFF2196F3),
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customSizeController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Size',
                          hintText: 'e.g., 32, 34',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addCustomSize(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                      onPressed: _addCustomSize,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Price
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price (for all)',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // MRP
                TextFormField(
                  controller: _mrpController,
                  decoration: const InputDecoration(
                    labelText: 'MRP (Optional)',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Stock
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity (per variant)',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Min Stock
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Min Stock (Optional)',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Base Barcode
                TextFormField(
                  controller: _baseBarcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Base Barcode (Optional)',
                    hintText: 'e.g., 789456',
                    helperText: 'Will append 001, 002, 003... to each variant',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Tax Rate
                TextFormField(
                  controller: _taxRateController,
                  decoration: const InputDecoration(
                    labelText: 'Tax Rate % (Optional)',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveVariants,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          child: Text('Add ${_selectedSizes.length + _customSizes.length} Variants'),
        ),
      ],
    );
  }
}