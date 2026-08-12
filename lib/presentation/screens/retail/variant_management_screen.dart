import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tax_feature.dart';
import '../../../data/models/common/taxmodel_314.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../domain/services/retail/simple_product_fields_service.dart';
import '../../../domain/services/retail/variant_attribute_mapper.dart';


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

  /// Configured descriptor fields (Settings → Simple Product Fields). The first
  /// one becomes the grouping axis for the list.
  List<AttributeModel> _fields = [];

  /// Group key for variants with no value for the grouping field.
  static const String _ungroupedKey = '__ungrouped__';

  /// Only show the colour swatch when the grouping field is actually a colour —
  /// grouping by Flavour or Capacity should not render colour dots.
  bool get _isColourLike {
    final name = _groupingField?.name.toLowerCase() ?? '';
    return name.contains('color') || name.contains('colour');
  }

  @override
  void initState() {
    super.initState();
    _loadVariants();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() => _fields = fields);
  }

  Future<void> _loadVariants() async {
    setState(() => isLoading = true);
    final loadedVariants = await productStore.getVariantsForProduct(widget.product.productId);
    setState(() {
      variants = loadedVariants;
      isLoading = false;
    });
  }

  /// Resolves the product's category name once, used as the SKU prefix when
  /// auto-generating for new variants added from this screen.
  String? _categoryName() {
    for (final c in categoryStore.categories) {
      if (c.id == widget.product.category) return c.name;
    }
    return null;
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
            'Add variants for each option you stock.',
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

  /// The field variants are grouped by - the first configured descriptor
  /// field, not hardcoded colour. Null when nothing is configured.
  AttributeModel? get _groupingField => _fields.isEmpty ? null : _fields.first;

  /// This variant's value for the grouping field.
  String _groupValueFor(VarianteModel variant) {
    final field = _groupingField;
    if (field == null) return '';
    return attributeStore.attributesOf(variant)[field.name] ?? '';
  }

  Widget _buildVariantList() {
    // Group by the first configured field (was hardcoded to colour)
    final Map<String?, List<VarianteModel>> groupedVariants = {};
    for (var variant in variants) {
      final value = _groupValueFor(variant);
      final key = value.isEmpty ? _ungroupedKey : value;
      if (!groupedVariants.containsKey(key)) {
        groupedVariants[key] = [];
      }
      groupedVariants[key]!.add(variant);
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
                if (_isColourLike && color != null && color != _ungroupedKey)
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
                  color == _ungroupedKey || color == null
                      ? 'Not set'
                      : color,
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
                  // Whatever attributes this variant actually has — the
                  // labels come from the attribute names, not hardcoded ones.
                  if (attributeStore
                      .describeAttributes(attributeStore.attributesOf(variant))
                      .isNotEmpty)
                    Text(
                      attributeStore
                          .describeAttributes(attributeStore.attributesOf(variant)),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
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
                      categoryName: _categoryName(),
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
                              'A single variant with its own barcode',
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
                      categoryName: _categoryName(),
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
                              'Many variants at once, one per value',
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
                        'Tip: Use Bulk Add to create several variants in one go',
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
  final String? categoryName;
  final VoidCallback onVariantAdded;

  const _AddVariantDialog({
    required this.productId,
    this.categoryName,
    required this.onVariantAdded,
  });

  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _formKey = GlobalKey<FormState>();

  /// Descriptor fields from Settings → Simple Product Fields, replacing the
  /// previously hardcoded Size / Color / Weight inputs.
  List<AttributeModel> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};

  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  String? _selectedTaxId;

  // Custom attributes
  final List<_CustomAttrData> _customAttributes = [];

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() => _fields = fields);
  }

  TextEditingController _fieldController(String attributeId) =>
      _fieldControllers.putIfAbsent(attributeId, () => TextEditingController());

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _skuController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
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

  /// Hint from the attribute's own defined values, so a grocery shop sees
  /// "e.g. 500ml" rather than a hardcoded apparel example.
  String _hintForAttribute(AttributeModel attribute) {
    final values = attributeStore.getValues(attribute.attributeId);
    return values.isEmpty ? '' : 'e.g. ${values.first.value}';
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

    // Auto-generate only when left blank — never overwrite what was typed.
    final sku = _skuController.text.trim().isEmpty
        ? await skuGeneratorService.generate(widget.categoryName)
        : _skuController.text.trim();

    final variantId = '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}';
    // Configured fields + any one-off rows, projected onto the legacy columns
    // by the one shared rule so receipts and reports keep working.
    final entered = <String, String>{
      for (final attribute in _fields)
        if ((_fieldControllers[attribute.attributeId]?.text.trim() ?? '')
            .isNotEmpty)
          attribute.name: _fieldControllers[attribute.attributeId]!.text.trim(),
    };
    final attributes = mergeVariantAttributes(
      entered,
      extraCustomAttributes: _getCustomAttributesMap(),
    );
    final variant = VarianteModel.create(
      varianteId: variantId,
      productId: widget.productId,
      sku: sku,
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      costPrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
      mrp: _mrpController.text.trim().isEmpty ? null : double.tryParse(_mrpController.text.trim()),
      stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
      minStock: _minStockController.text.trim().isEmpty ? null : int.tryParse(_minStockController.text.trim()),
      taxRate: _selectedTaxId == null
          ? null
          : taxStore.taxes
              .firstWhere((t) => t.id == _selectedTaxId,
                  orElse: () => Tax(id: '', taxname: '', taxperecentage: null))
              .taxperecentage,
      taxId: _selectedTaxId,
      customAttributes: attributes,
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
                for (final attribute in _fields) ...[
                  _buildTextField(
                    _fieldController(attribute.attributeId),
                    attribute.name,
                    _hintForAttribute(attribute),
                  ),
                  const SizedBox(height: 12),
                ],
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
                if (TaxFeature.enabled) ...[
                  const SizedBox(height: 12),
                  _buildTaxDropdown(_selectedTaxId, (value) => setState(() => _selectedTaxId = value)),
                ],

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

// Shared by both the Add and Edit variant dialogs.
Widget _buildTaxDropdown(String? selectedTaxId, ValueChanged<String?> onChanged) {
  return Observer(
    builder: (_) {
      final taxes = taxStore.taxes;
      return DropdownButtonFormField<String>(
        value: taxes.any((t) => t.id == selectedTaxId) ? selectedTaxId : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tax Rate (Optional)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('No tax')),
          ...taxes.map((tax) => DropdownMenuItem(
                value: tax.id,
                child: Text('${tax.taxname} (${tax.taxperecentage ?? 0}%)'),
              )),
        ],
        onChanged: onChanged,
      );
    },
  );
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
      // size: widget.variant.size,
      // color: widget.variant.color,
      // weight: widget.variant.weight,
      sku: widget.variant.sku,
      barcode: widget.variant.barcode,
      mrp: widget.variant.mrp,
      costPrice: double.tryParse(_priceController.text.trim()),
      stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
      minStock: _minStockController.text.trim().isEmpty ? null : int.tryParse(_minStockController.text.trim()),
      taxRate: widget.variant.taxRate,
      taxId: widget.variant.taxId,
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
  final String? categoryName;
  final VoidCallback onVariantsAdded;

  const _BulkAddVariantDialog({
    required this.productId,
    this.categoryName,
    required this.onVariantsAdded,
  });

  @override
  State<_BulkAddVariantDialog> createState() => _BulkAddVariantDialogState();
}

class _BulkAddVariantDialogState extends State<_BulkAddVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _baseBarcodeController = TextEditingController();
  String? _selectedTaxId;

  /// Configured descriptor fields (Settings → Simple Product Fields).
  List<AttributeModel> _fields = [];

  /// The attribute that VARIES across the generated variants — one variant per
  /// selected value. Replaces the old hardcoded "sizes" axis.
  AttributeModel? _varyingAttribute;

  /// Selected values of [_varyingAttribute], from its defined values plus any
  /// typed in here.
  final Set<String> _selectedValues = {};
  final List<String> _customValues = [];
  final _customValueController = TextEditingController();

  /// Fixed values applied to EVERY generated variant (the other fields).
  final Map<String, TextEditingController> _fixedControllers = {};

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() {
      _fields = fields;
      // Default the varying axis to the first configured field.
      _varyingAttribute = fields.isEmpty ? null : fields.first;
    });
  }

  TextEditingController _fixedController(String attributeId) =>
      _fixedControllers.putIfAbsent(attributeId, () => TextEditingController());

  /// Values offered for the varying attribute: its defined values + custom ones.
  List<String> get _availableValues {
    final attribute = _varyingAttribute;
    if (attribute == null) return const [];
    return attributeStore
        .getValues(attribute.attributeId)
        .map((v) => v.value)
        .toList();
  }

  @override
  void dispose() {
    _customValueController.dispose();
    for (final controller in _fixedControllers.values) {
      controller.dispose();
    }
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _baseBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveVariants() async {
    if (!_formKey.currentState!.validate()) return;

    final allValues = [..._selectedValues, ..._customValues];
    final varying = _varyingAttribute;

    if (varying == null || allValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(varying == null
              ? 'Add a field in Settings → Simple Product Fields first'
              : 'Please select at least one ${varying.name.toLowerCase()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Values typed once and applied to every generated variant.
    final fixedValues = <String, String>{
      for (final attribute in _fields)
        if (attribute.attributeId != varying.attributeId &&
            (_fixedControllers[attribute.attributeId]?.text.trim() ?? '')
                .isNotEmpty)
          attribute.name:
              _fixedControllers[attribute.attributeId]!.text.trim(),
    };

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final mrp = _mrpController.text.trim().isEmpty ? null : double.tryParse(_mrpController.text.trim());
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = _minStockController.text.trim().isEmpty ? null : int.tryParse(_minStockController.text.trim());
    final baseBarcode = _baseBarcodeController.text.trim();
    final taxRate = _selectedTaxId == null
        ? null
        : taxStore.taxes
            .firstWhere((t) => t.id == _selectedTaxId,
                orElse: () => Tax(id: '', taxname: '', taxperecentage: null))
            .taxperecentage;

    // One variant per selected value of the varying attribute
    int barcodeCounter = 1;
    for (final value in allValues) {
      final variantId = '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}_$barcodeCounter';

      // Generate barcode: if base is provided, append counter
      String? barcode;
      if (baseBarcode.isNotEmpty) {
        barcode = '$baseBarcode${barcodeCounter.toString().padLeft(3, '0')}';
      }

      // Bulk-created variants have no manual SKU input, so every one gets an
      // auto-generated SKU (each call advances the shared global sequence).
      final sku = await skuGeneratorService.generate(widget.categoryName);

      final attributes = mergeVariantAttributes({
        ...fixedValues,
        varying.name: value,
      });

      final variant = VarianteModel.create(
        varianteId: variantId,
        productId: widget.productId,
        customAttributes: attributes,
        sku: sku,
        barcode: barcode,
        costPrice: price,
        mrp: mrp,
        stockQty: stock,
        minStock: minStock,
        taxRate: taxRate,
        taxId: _selectedTaxId,
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
          content: Text('${allValues.length} variants added successfully'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _addCustomValue() {
    final value = _customValueController.text.trim();
    if (value.isNotEmpty &&
        !_customValues.contains(value) &&
        !_availableValues.contains(value)) {
      setState(() {
        _customValues.add(value);
        _customValueController.clear();
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
                // Which field varies across the generated variants
                if (_fields.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _varyingAttribute?.attributeId,
                    decoration: const InputDecoration(
                      labelText: 'Create one variant per',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _fields
                        .map((a) => DropdownMenuItem(
                              value: a.attributeId,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() {
                        _varyingAttribute =
                            _fields.firstWhere((a) => a.attributeId == id);
                        _selectedValues.clear();
                        _customValues.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Fixed values - typed once, applied to every variant
                for (final attribute in _fields)
                  if (attribute.attributeId != _varyingAttribute?.attributeId) ...[
                    TextFormField(
                      controller: _fixedController(attribute.attributeId),
                      decoration: InputDecoration(
                        labelText: attribute.name,
                        hintText: 'Same for all variants',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                // Values of the varying field
                Text(
                  _varyingAttribute == null
                      ? 'No fields configured'
                      : 'Select ${_varyingAttribute!.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                if (_availableValues.isEmpty && _customValues.isEmpty)
                  Text(
                    _varyingAttribute == null
                        ? 'Add a field in Settings, Simple Product Fields.'
                        : 'No preset values - type them below.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableValues.map((value) {
                    final isSelected = _selectedValues.contains(value);
                    return FilterChip(
                      label: Text(value),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedValues.add(value);
                          } else {
                            _selectedValues.remove(value);
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

                // Values typed in here
                if (_customValues.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _customValues.map((value) {
                      return Chip(
                        label: Text(value),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() => _customValues.remove(value));
                        },
                        backgroundColor: const Color(0xFF2196F3),
                        labelStyle:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customValueController,
                        enabled: _varyingAttribute != null,
                        decoration: InputDecoration(
                          labelText: _varyingAttribute == null
                              ? 'Value'
                              : 'Add ${_varyingAttribute!.name}',
                          hintText: 'Type a value and press +',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addCustomValue(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                      onPressed:
                          _varyingAttribute == null ? null : _addCustomValue,
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
                // Tax Rate
                if (TaxFeature.enabled) ...[
                  const SizedBox(height: 12),
                  _buildTaxDropdown(_selectedTaxId, (value) => setState(() => _selectedTaxId = value)),
                ],
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
          child: Text(
              'Add ${_selectedValues.length + _customValues.length} Variants'),
        ),
      ],
    );
  }
}