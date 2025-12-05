import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/data/models/retail/hive_model/category_model_215.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/domain/services/retail/variant_generator_service.dart';
import 'package:unipos/presentation/screens/retail/category_management_screen.dart';
import 'package:unipos/presentation/screens/retail/scanner_screen.dart';
import 'package:unipos/presentation/widget/retail/product_attribute_selector.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';

const _uuid = Uuid();

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

// Custom attribute data for form
class CustomAttributeData {
  final String id;
  final TextEditingController keyController;
  final TextEditingController valueController;

  CustomAttributeData({required this.id})
      : keyController = TextEditingController(),
        valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

// Variant data model for form
class VariantFormData {
  final String id;
  final TextEditingController sizeController;
  final TextEditingController colorController;
  final TextEditingController barcodeController;
  final TextEditingController costPriceController;
  final TextEditingController priceController;
  final TextEditingController mrpController;
  final TextEditingController stockController;
  final TextEditingController weightController;
  final TextEditingController skuController;
  final List<CustomAttributeData> customAttributes;

  VariantFormData({
    required this.id,
  })  : sizeController = TextEditingController(),
        colorController = TextEditingController(),
        barcodeController = TextEditingController(),
        costPriceController = TextEditingController(),
        priceController = TextEditingController(),
        mrpController = TextEditingController(),
        stockController = TextEditingController(),
        weightController = TextEditingController(),
        skuController = TextEditingController(),
        customAttributes = [];

  void addCustomAttribute() {
    customAttributes.add(CustomAttributeData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    ));
  }

  void removeCustomAttribute(int index) {
    customAttributes[index].dispose();
    customAttributes.removeAt(index);
  }

  Map<String, String>? getCustomAttributesMap() {
    final map = <String, String>{};
    for (var attr in customAttributes) {
      final key = attr.keyController.text.trim();
      final value = attr.valueController.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map.isEmpty ? null : map;
  }

  void dispose() {
    sizeController.dispose();
    colorController.dispose();
    barcodeController.dispose();
    costPriceController.dispose();
    priceController.dispose();
    mrpController.dispose();
    stockController.dispose();
    weightController.dispose();
    skuController.dispose();
    for (var attr in customAttributes) {
      attr.dispose();
    }
  }
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _defaultPriceController = TextEditingController();
  final _defaultCostController = TextEditingController();
  final _defaultMrpController = TextEditingController();
  final _defaultStockController = TextEditingController();

  String? _selectedCategory;
  CategoryModel? _selectedCategoryModel;
  bool _hasVariants = false;
  List<CategoryModel> _categories = [];

  // Product type: 'simple' or 'variable'
  String _productType = 'simple';

  // For variable products - selected attributes
  List<AttributeWithValues> _selectedAttributes = [];

  // Generated variants from attributes
  List<VarianteModel> _generatedVariants = [];

  // Track selected variants for bulk operations (by variantId)
  final Set<String> _selectedVariantsForBulk = {};

  // Key for attribute selector to allow refresh
  final GlobalKey<ProductAttributeSelectorState> _attributeSelectorKey =
      GlobalKey<ProductAttributeSelectorState>();

  // List of variants (manual entry)
  final List<VariantFormData> _variants = [];

  @override
  void initState() {
    super.initState();
    // Add first variant by default
    _addVariant();
    _loadCategories();
    // Load attributes
    attributeStore.loadAttributes();
  }

  Future<void> _loadCategories() async {
    _categories = await categoryModelRepository.getAllCategories();
    if (_categories.isEmpty) {
      await categoryModelRepository.addDefaultCategories();
      _categories = await categoryModelRepository.getAllCategories();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _taxRateController.dispose();
    for (var variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      _variants.add(VariantFormData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      ));
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  void _showAddCategoryDialog() {
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'Enter category name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final category = categoryController.text.trim();
              if (category.isNotEmpty) {
                productStore.addCategory(category);
                setState(() {
                  _selectedCategory = category;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcode(VariantFormData variant) async {
    final String? barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (barcode != null) {
      variant.barcodeController.text = barcode;
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate based on product type
    if (_productType == 'variable') {
      // Variable product - check generated variants
      if (_generatedVariants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please generate variants by selecting attributes'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Simple product - check manual variants
      if (_variants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one variant'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate all manual variants
      for (var variant in _variants) {
        if (variant.costPriceController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter cost price for all variants'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (variant.priceController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter selling price for all variants'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (variant.stockController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter stock for all variants'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    // Get GST rate from input or category
    final taxRate = _taxRateController.text.trim().isEmpty
        ? (_selectedCategoryModel?.gstRate)
        : double.tryParse(_taxRateController.text.trim());

    // Create ProductModel
    final productId = _uuid.v4();
    final product = ProductModel.fromProduct(
      productId: productId,
      productName: _nameController.text.trim(),
      brandName: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
      category: _selectedCategory ?? 'Uncategorized',
      imagePath: null,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      hasVariants: _hasVariants || _productType == 'variable',
      productType: _productType,
      gstRate: taxRate,
    );

    await productStore.addProduct(product);

    int variantCount = 0;

    if (_productType == 'variable') {
      // Save generated variants
      for (var variant in _generatedVariants) {
        // Update product ID to the actual one we created
        final updatedVariant = variant.copyWith(
          productId: productId,
          taxRate: taxRate,
        );
        await productStore.addVariant(updatedVariant);
        variantCount++;
      }
    } else {
      // Save manual variants
      for (var i = 0; i < _variants.length; i++) {
        final variantData = _variants[i];
        final variantId = _uuid.v4();

        final variant = VarianteModel.create(
          varianteId: variantId,
          productId: productId,
          size: variantData.sizeController.text.trim().isEmpty
              ? null
              : variantData.sizeController.text.trim(),
          color: variantData.colorController.text.trim().isEmpty
              ? null
              : variantData.colorController.text.trim(),
          weight: variantData.weightController.text.trim().isEmpty
              ? null
              : variantData.weightController.text.trim(),
          sku: variantData.skuController.text.trim().isEmpty
              ? null
              : variantData.skuController.text.trim(),
          barcode: variantData.barcodeController.text.trim().isEmpty
              ? null
              : variantData.barcodeController.text.trim(),
          mrp: variantData.priceController.text.trim().isEmpty
              ? null
              : double.tryParse(variantData.priceController.text.trim()),
          costPrice: double.tryParse(variantData.costPriceController.text.trim()) ?? 0.0,
          stockQty: int.tryParse(variantData.stockController.text.trim()) ?? 0,
          taxRate: taxRate,
          customAttributes: variantData.getCustomAttributesMap(),
        );

        await productStore.addVariant(variant);
        variantCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.productName} with $variantCount variant(s) added successfully'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Add Product'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Observer(
        builder: (context) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Product Information Section
              _buildSectionHeader('Product Information'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: 'Product Name',
                hint: 'e.g., Puma T-Shirt',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _brandController,
                label: 'Brand Name (Optional)',
                hint: 'e.g., Puma, Nike',
              ),
              const SizedBox(height: 12),
              _buildCategoryDropdown(),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hint: 'Enter product description',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _taxRateController,
                label: 'Tax Rate % (Optional)',
                hint: '0.00',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Product Type Selector
              _buildProductTypeSelector(),

              const SizedBox(height: 24),

              // Show different UI based on product type
              if (_productType == 'variable') ...[
                // Attribute Selector Section (WooCommerce-style)
                _buildSectionHeader('Product Attributes'),
                const SizedBox(height: 12),
                _buildAttributeSelector(),

                // Generated Variants Section
                if (_generatedVariants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('Generated Variants (${_generatedVariants.length})'),
                  const SizedBox(height: 12),

                  // Bulk Edit Bar
                  _buildBulkEditBar(),
                  const SizedBox(height: 12),

                  _buildGeneratedVariantsList(),
                ],
              ] else ...[
                // Simple product - Manual Variants Section
                _buildSectionHeader('Variants (${_variants.length})'),
                const SizedBox(height: 12),

                // List all variants
                ..._variants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final variant = entry.value;
                  return _buildVariantCard(variant, index);
                }).toList(),

                // Add Variant Button
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addVariant,
                  icon: const Icon(Icons.add, color: Color(0xFF2196F3)),
                  label: const Text('Add Another Variant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2196F3),
                    side: const BorderSide(color: Color(0xFF2196F3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _productType == 'variable'
                        ? 'Add Product with ${_generatedVariants.length} Variant(s)'
                        : 'Add Product with ${_variants.length} Variant(s)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard(VariantFormData variant, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Variant ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_variants.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeVariant(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Variant Fields
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.colorController,
                  label: 'Color',
                  hint: 'e.g., Green',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: variant.sizeController,
                  label: 'Size',
                  hint: 'e.g., M',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: variant.barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    hintText: 'Scan or enter',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF4CAF50), size: 20),
                      onPressed: () => _scanBarcode(variant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: variant.weightController,
                  label: 'Weight',
                  hint: 'e.g., 500g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.costPriceController,
                  label: 'Cost Price*',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: variant.priceController,
                  label: 'Selling Price*',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.mrpController,
                  label: 'MRP',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: variant.skuController,
                  label: 'SKU',
                  hint: 'Optional',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.stockController,
                  label: 'Stock*',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),

          // Custom Attributes Section
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Custom Attributes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    variant.addCustomAttribute();
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (variant.customAttributes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...variant.customAttributes.asMap().entries.map((entry) {
              final attrIndex = entry.key;
              final attr = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: attr.keyController,
                        label: 'Attribute',
                        hint: 'e.g., Material',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        controller: attr.valueController,
                        label: 'Value',
                        hint: 'e.g., Cotton',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          variant.removeCustomAttribute(attrIndex);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Add custom attributes like Material, Flavor, Capacity, etc.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: [
            ..._categories.map((category) {
              return DropdownMenuItem(
                value: category.categoryName,
                child: Text(
                  '${category.categoryName} (GST ${(category.gstRate ?? 0).toInt()}%)',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const DropdownMenuItem(
              value: '__manage__',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings, size: 20, color: Color(0xFF2196F3)),
                  SizedBox(width: 8),
                  Text('Manage Categories', style: TextStyle(color: Color(0xFF2196F3))),
                ],
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == '__manage__') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
              );
              // Reload categories after returning
              await _loadCategories();
            } else {
              setState(() {
                _selectedCategory = value;
                _selectedCategoryModel = _categories.firstWhere(
                  (c) => c.categoryName == value,
                  orElse: () => _categories.first,
                );
                // Auto-fill tax rate from category if not set
                if (_taxRateController.text.isEmpty && _selectedCategoryModel != null) {
                  _taxRateController.text = (_selectedCategoryModel!.gstRate ?? 0).toString();
                }
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty || value == '__manage__') {
              return 'Please select a category';
            }
            return null;
          },
        ),
        if (_selectedCategoryModel != null && (_selectedCategoryModel!.gstRate ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Category GST: ${(_selectedCategoryModel!.gstRate ?? 0).toInt()}% will be applied if no product/variant GST is set',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Has Variants',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enable if product has multiple variants',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _hasVariants,
            onChanged: (value) {
              setState(() {
                _hasVariants = value;
              });
            },
            activeColor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  /// Product type selector (Simple / Variable)
  Widget _buildProductTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  title: 'Simple',
                  subtitle: 'Single product, enter variants manually',
                  icon: Icons.inventory_2_outlined,
                  isSelected: _productType == 'simple',
                  onTap: () {
                    setState(() {
                      _productType = 'simple';
                      _hasVariants = false;
                      _generatedVariants = [];
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  title: 'Variable',
                  subtitle: 'Auto-generate variants from attributes',
                  icon: Icons.auto_awesome,
                  isSelected: _productType == 'variable',
                  onTap: () {
                    setState(() {
                      _productType = 'variable';
                      _hasVariants = true;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Attribute selector widget for variable products
  Widget _buildAttributeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: ProductAttributeSelector(
        key: _attributeSelectorKey,
        productId: DateTime.now().millisecondsSinceEpoch.toString(),
        defaultPrice: double.tryParse(_defaultPriceController.text),
        defaultCostPrice: double.tryParse(_defaultCostController.text),
        existingVariants: _generatedVariants.isNotEmpty ? _generatedVariants : null,
        onAttributesChanged: (attributes) {
          setState(() {
            _selectedAttributes = attributes;
          });
        },
        onVariantsGenerated: (variants) {
          setState(() {
            _generatedVariants = variants;
          });
        },
      ),
    );
  }

  /// Bulk Edit Bar - WooCommerce-style "Set prices for all"
  Widget _buildBulkEditBar() {
    final allSelected = _selectedVariantsForBulk.length == _generatedVariants.length;
    final noneSelected = _selectedVariantsForBulk.isEmpty;
    final selectedCount = _selectedVariantsForBulk.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Select All / Unselect All
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulk Edit - $selectedCount / ${_generatedVariants.length} selected',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF57C00),
                  ),
                ),
              ),
              // Select All button
              TextButton(
                onPressed: allSelected ? null : () {
                  setState(() {
                    _selectedVariantsForBulk.clear();
                    for (var v in _generatedVariants) {
                      _selectedVariantsForBulk.add(v.varianteId);
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 12,
                    color: allSelected ? Colors.grey : const Color(0xFFF57C00),
                  ),
                ),
              ),
              const Text(' | ', style: TextStyle(color: Colors.grey)),
              // Unselect All button
              TextButton(
                onPressed: noneSelected ? null : () {
                  setState(() {
                    _selectedVariantsForBulk.clear();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Unselect All',
                  style: TextStyle(
                    fontSize: 12,
                    color: noneSelected ? Colors.grey : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // First Row: Cost Price, Selling Price
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _defaultCostController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _defaultPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),

            ],
          ),

          const SizedBox(height: 8),
          // Second Row: MRP with Apply button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _defaultMrpController,
                  decoration: const InputDecoration(
                    labelText: 'MRP',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _defaultStockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            /*  const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyBulkPricesAndStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Apply'),
              ),*/
            ],
          ),
          const SizedBox(width: 8),
          Center(
            child: ElevatedButton(
              onPressed: _applyBulkPricesAndStock,
              style: ElevatedButton.styleFrom(
                minimumSize:Size(400,20),
                backgroundColor: const Color(0xFFF57C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Text('Apply'),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Enter values and click Apply to update all variants at once',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Apply bulk prices to all variants
  void _applyBulkPricesAndStock() {
    final costPrice = double.tryParse(_defaultCostController.text);
    final sellingPrice = double.tryParse(_defaultPriceController.text);
    final mrp = double.tryParse(_defaultMrpController.text);
    final stock = int.tryParse(_defaultStockController.text);

    if (costPrice == null && sellingPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one price value'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _applyToAllVariants(costPrice: costPrice, sellingPrice: sellingPrice);
    _applyToAllVariants(mrp: mrp, stock: stock);

    final appliedCount = _selectedVariantsForBulk.isEmpty
        ? _generatedVariants.length
        : _selectedVariantsForBulk.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied to $appliedCount variant(s)'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Apply bulk MRP and Stock to all variants
  // void _applyBulkMrpStock() {
  //   final mrp = double.tryParse(_defaultMrpController.text);
  //   final stock = int.tryParse(_defaultStockController.text);
  //
  //   if (mrp == null && stock == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Please enter MRP or Stock value'),
  //         backgroundColor: Colors.orange,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   _applyToAllVariants(mrp: mrp, stock: stock);
  //
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('Applied to ${_generatedVariants.length} variant(s)'),
  //       backgroundColor: const Color(0xFF4CAF50),
  //       duration: const Duration(seconds: 1),
  //     ),
  //   );
  // }

  /// Apply values to selected variants only
  void _applyToAllVariants({
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    int? stock,
  }) {
    setState(() {
      for (var i = 0; i < _generatedVariants.length; i++) {
        final variant = _generatedVariants[i];
        // Only apply to selected variants (or all if none selected)
        if (_selectedVariantsForBulk.isEmpty || _selectedVariantsForBulk.contains(variant.varianteId)) {
          _generatedVariants[i] = variant.copyWith(
            costPrice: costPrice ?? variant.costPrice,
            sellingPrice: sellingPrice ?? variant.sellingPrice,
            mrp: mrp ?? variant.mrp,
            stockQty: stock ?? variant.stockQty,
          );
        }
      }
    });
  }

  /// List of generated variants with editing capability
  Widget _buildGeneratedVariantsList() {
    return Column(
      children: _generatedVariants.asMap().entries.map((entry) {
        final index = entry.key;
        final variant = entry.value;
        return _buildGeneratedVariantCard(variant, index);
      }).toList(),
    );
  }

  Widget _buildGeneratedVariantCard(VarianteModel variant, int index) {
    final isSelected = _selectedVariantsForBulk.contains(variant.varianteId);

    // Use Key to force rebuild when variant data changes
    return Container(
      key: ValueKey('${variant.varianteId}_${variant.costPrice}_${variant.sellingPrice}_${variant.mrp}_${variant.stockQty}_$isSelected'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFF57C00) : const Color(0xFFE8E8E8),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with checkbox and variant name
          Row(
            children: [
              // Checkbox for bulk selection
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedVariantsForBulk.remove(variant.varianteId);
                    } else {
                      _selectedVariantsForBulk.add(variant.varianteId);
                    }
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF57C00) : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF57C00) : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  variant.shortDescription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (variant.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'SKU: ${variant.sku ?? "Auto"}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Editable fields - using key to force rebuild on value change
          Row(
            children: [
              Expanded(
                child: _buildVariantTextField(
                  key: 'cost_$index',
                  value: variant.costPrice?.toString() ?? '',
                  label: 'Cost Price',
                  onChanged: (value) {
                    _updateGeneratedVariant(index, costPrice: double.tryParse(value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVariantTextField(
                  key: 'sell_$index',
                  value: variant.sellingPrice?.toString() ?? '',
                  label: 'Selling Price',
                  onChanged: (value) {
                    _updateGeneratedVariant(index, sellingPrice: double.tryParse(value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVariantTextField(
                  key: 'stock_$index',
                  value: variant.stockQty.toString(),
                  label: 'Stock',
                  onChanged: (value) {
                    _updateGeneratedVariant(index, stockQty: int.tryParse(value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('barcode_${index}_${variant.barcode}'),
                  initialValue: variant.barcode ?? '',
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () async {
                        final barcode = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (_) => const ScannerScreen()),
                        );
                        if (barcode != null) {
                          _updateGeneratedVariant(index, barcode: barcode);
                        }
                      },
                    ),
                  ),
                  onChanged: (value) {
                    _updateGeneratedVariant(index, barcode: value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVariantTextField(
                  key: 'mrp_$index',
                  value: variant.mrp?.toString() ?? '',
                  label: 'MRP',
                  onChanged: (value) {
                    _updateGeneratedVariant(index, mrp: double.tryParse(value));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a text field for variant that properly updates when value changes
  Widget _buildVariantTextField({
    required String key,
    required String value,
    required String label,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      key: ValueKey('${key}_$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }

  void _updateGeneratedVariant(
    int index, {
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    int? stockQty,
    String? barcode,
  }) {
    setState(() {
      final variant = _generatedVariants[index];
      _generatedVariants[index] = variant.copyWith(
        costPrice: costPrice ?? variant.costPrice,
        sellingPrice: sellingPrice ?? variant.sellingPrice,
        mrp: mrp ?? variant.mrp,
        stockQty: stockQty ?? variant.stockQty,
        barcode: barcode ?? variant.barcode,
      );
    });
  }
}