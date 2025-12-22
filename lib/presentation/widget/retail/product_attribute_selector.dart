import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/domain/services/retail/variant_generator_service.dart';
import 'package:unipos/domain/store/retail/attribute_store.dart';

import '../../../core/di/service_locator.dart';
import '../../screens/retail/attributes_screen.dart';


/// WooCommerce-style attribute selector widget for product form
/// Allows selecting global attributes and their values for a product
class ProductAttributeSelector extends StatefulWidget {
  final Function(List<AttributeWithValues>) onAttributesChanged;
  final Function(List<VarianteModel>) onVariantsGenerated;
  final String productId;
  final double? defaultPrice;
  final double? defaultMrp;
  final double? defaultCostPrice;
  final List<VarianteModel>? existingVariants;

  const ProductAttributeSelector({
    super.key,
    required this.onAttributesChanged,
    required this.onVariantsGenerated,
    required this.productId,
    this.defaultPrice,
    this.defaultMrp,
    this.defaultCostPrice,
    this.existingVariants,
  });

  @override
  State<ProductAttributeSelector> createState() => ProductAttributeSelectorState();
}

class ProductAttributeSelectorState extends State<ProductAttributeSelector> {
  final AttributeStore _attributeStore = attributeStore;
  final VariantGeneratorService _variantGenerator = variantGeneratorService;

  // Selected attributes with their values
  final List<AttributeWithValues> _selectedAttributes = [];

  // Generated variants preview
  List<VariantCombination> _previewCombinations = [];

  // Track which combinations are selected (by their display name)
  final Set<String> _selectedCombinations = {};

  @override
  void initState() {
    super.initState();
    _loadAttributes();
  }

  Future<void> _loadAttributes() async {
    await _attributeStore.loadAttributes();

    // Refresh selected attributes with updated values
    for (int i = 0; i < _selectedAttributes.length; i++) {
      final attributeId = _selectedAttributes[i].attribute.attributeId;
      final updatedValues = _attributeStore.getValues(attributeId);
      final updatedAttribute = _attributeStore.attributes.firstWhere(
        (a) => a.attributeId == attributeId,
        orElse: () => _selectedAttributes[i].attribute,
      );

      _selectedAttributes[i] = _selectedAttributes[i].copyWith(
        attribute: updatedAttribute,
        availableValues: updatedValues,
      );
    }

    setState(() {});
  }

  void _addAttribute(AttributeModel attribute) {
    if (_selectedAttributes.any((a) => a.attribute.attributeId == attribute.attributeId)) {
      return; // Already added
    }

    final values = _attributeStore.getValues(attribute.attributeId);
    setState(() {
      _selectedAttributes.add(AttributeWithValues(
        attribute: attribute,
        availableValues: values,
        selectedValues: [],
        usedForVariants: true,
      ));
    });
    _notifyChange();
  }

  void _removeAttribute(String attributeId) {
    setState(() {
      _selectedAttributes.removeWhere((a) => a.attribute.attributeId == attributeId);
      _updatePreview();
    });
    _notifyChange();
  }

  void _toggleValue(String attributeId, AttributeValueModel value) {
    final index = _selectedAttributes.indexWhere(
      (a) => a.attribute.attributeId == attributeId,
    );
    if (index == -1) return;

    setState(() {
      final attr = _selectedAttributes[index];
      final isSelected = attr.selectedValues.any((v) => v.valueId == value.valueId);

      if (isSelected) {
        _selectedAttributes[index] = attr.copyWith(
          selectedValues: attr.selectedValues.where((v) => v.valueId != value.valueId).toList(),
        );
      } else {
        _selectedAttributes[index] = attr.copyWith(
          selectedValues: [...attr.selectedValues, value],
        );
      }
      _updatePreview();
    });
    _notifyChange();
  }

  /// Show dialog to create a new attribute
  Future<void> _showCreateAttributeDialog() async {
    final TextEditingController nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Attribute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Attribute Name',
                hintText: 'e.g., Color, Size, Material',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an attribute name'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      await _attributeStore.addAttribute(name);
      await _loadAttributes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attribute "$name" created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Auto-select the newly created attribute
      final newAttr = _attributeStore.attributes.firstWhere(
        (a) => a.name.toLowerCase() == name.toLowerCase(),
      );
      _addAttribute(newAttr);
    }
  }

  /// Show dialog to add a new value to an existing attribute
  Future<void> _showAddValueDialog(AttributeWithValues attrWithValues) async {
    final TextEditingController valueController = TextEditingController();
    final TextEditingController colorController = TextEditingController();
    final isColor = attrWithValues.attribute.name.toLowerCase().contains('color') ||
        attrWithValues.attribute.name.toLowerCase().contains('colour');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Value to ${attrWithValues.attribute.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g., Red, Large, Cotton',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            if (isColor) ...[
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Color Code (Optional)',
                  hintText: '#FF0000',
                  border: OutlineInputBorder(),
                  prefixText: '#',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = valueController.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a value'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final value = valueController.text.trim();
      String? colorCode;
      if (isColor && colorController.text.trim().isNotEmpty) {
        colorCode = colorController.text.trim().startsWith('#')
            ? colorController.text.trim()
            : '#${colorController.text.trim()}';
      }

      await _attributeStore.addValue(
        attrWithValues.attribute.attributeId,
        value,
        colorCode: colorCode,
      );
      await _loadAttributes();

      // Refresh the selected attribute's available values
      final index = _selectedAttributes.indexWhere(
        (a) => a.attribute.attributeId == attrWithValues.attribute.attributeId,
      );
      if (index != -1) {
        final updatedValues = _attributeStore.getValues(attrWithValues.attribute.attributeId);
        setState(() {
          _selectedAttributes[index] = _selectedAttributes[index].copyWith(
            availableValues: updatedValues,
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Value "$value" added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _selectAllValues(String attributeId) {
    final index = _selectedAttributes.indexWhere(
      (a) => a.attribute.attributeId == attributeId,
    );
    if (index == -1) return;

    setState(() {
      final attr = _selectedAttributes[index];
      _selectedAttributes[index] = attr.copyWith(
        selectedValues: List.from(attr.availableValues),
      );
      _updatePreview();
    });
    _notifyChange();
  }

  void _clearValues(String attributeId) {
    final index = _selectedAttributes.indexWhere(
      (a) => a.attribute.attributeId == attributeId,
    );
    if (index == -1) return;

    setState(() {
      final attr = _selectedAttributes[index];
      _selectedAttributes[index] = attr.copyWith(selectedValues: []);
      _updatePreview();
    });
    _notifyChange();
  }

  void _updatePreview() {
    _previewCombinations = _variantGenerator.generateCombinations(
      attributesWithValues: _selectedAttributes,
    );
    // Auto-select all new combinations
    for (final combo in _previewCombinations) {
      if (!_selectedCombinations.contains(combo.displayName)) {
        _selectedCombinations.add(combo.displayName);
      }
    }
    // Remove combinations that no longer exist
    _selectedCombinations.removeWhere(
      (name) => !_previewCombinations.any((c) => c.displayName == name),
    );
  }

  void _toggleCombination(String displayName) {
    setState(() {
      if (_selectedCombinations.contains(displayName)) {
        _selectedCombinations.remove(displayName);
      } else {
        _selectedCombinations.add(displayName);
      }
    });
  }

  void _selectAllCombinations() {
    setState(() {
      _selectedCombinations.clear();
      for (final combo in _previewCombinations) {
        _selectedCombinations.add(combo.displayName);
      }
    });
  }

  void _unselectAllCombinations() {
    setState(() {
      _selectedCombinations.clear();
    });
  }

  /// Get selected combinations count
  int get _selectedCount => _selectedCombinations.length;

  void _notifyChange() {
    widget.onAttributesChanged(_selectedAttributes);
  }

  void generateVariants() {
    if (_previewCombinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one value for each attribute'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Filter only selected combinations
    final selectedCombos = _previewCombinations
        .where((combo) => _selectedCombinations.contains(combo.displayName))
        .toList();

    if (selectedCombos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one variant to generate'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final variants = _variantGenerator.generateVariants(
      productId: widget.productId,
      combinations: selectedCombos,
      defaultPrice: widget.defaultPrice,
      defaultMrp: widget.defaultMrp,
      defaultCostPrice: widget.defaultCostPrice,
      existingVariants: widget.existingVariants,
    );

    widget.onVariantsGenerated(variants);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated ${variants.length} variant(s)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Get variant count that would be generated
  int get variantCount => _variantGenerator.calculateVariantCount(_selectedAttributes);

  /// Get variant description
  String get variantDescription => _variantGenerator.describeVariants(_selectedAttributes);

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (_attributeStore.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add Attribute Button
            Row(
              children: [
                const Text(
                  'Product Attributes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildAddAttributeButton(),
              ],
            ),
            const SizedBox(height: 8),

            if (_selectedAttributes.isEmpty)
              _buildEmptyState()
            else ...[
              // Selected Attributes
              ..._selectedAttributes.map((attrWithValues) =>
                _AttributeSection(
                  attributeWithValues: attrWithValues,
                  onRemove: () => _removeAttribute(attrWithValues.attribute.attributeId),
                  onToggleValue: (value) => _toggleValue(attrWithValues.attribute.attributeId, value),
                  onSelectAll: () => _selectAllValues(attrWithValues.attribute.attributeId),
                  onClearAll: () => _clearValues(attrWithValues.attribute.attributeId),
                  onAddValue: () => _showAddValueDialog(attrWithValues),
                ),
              ),

              const SizedBox(height: 16),

              // Variant Preview
              _buildVariantPreview(),

              // Generate Button
              if (_previewCombinations.isNotEmpty && _selectedCount > 0) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: generateVariants,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text('Generate $_selectedCount Variant(s)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildAddAttributeButton() {
    final availableAttributes = _attributeStore.attributes
        .where((a) => !_selectedAttributes.any((s) => s.attribute.attributeId == a.attributeId))
        .toList();

    if (availableAttributes.isEmpty) {
      return PopupMenuButton<String>(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: Colors.blue),
              SizedBox(width: 4),
              Text('Add Attribute', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'create_new',
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 18, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text('Create New Attribute', style: TextStyle(color: Colors.green[700])),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'manage',
            child: Row(
              children: [
                Icon(Icons.settings, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Manage Attributes', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'create_new') {
            _showCreateAttributeDialog();
          } else if (value == 'manage') {
            _showManageAttributesInfo();
          }
        },
      );
    }

    return PopupMenuButton<dynamic>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: Colors.blue),
            SizedBox(width: 4),
            Text('Add Attribute', style: TextStyle(color: Colors.blue)),
          ],
        ),
      ),
      itemBuilder: (context) => [
        ...availableAttributes.map((attr) => PopupMenuItem(
          value: attr,
          child: Text(attr.name),
        )),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'create_new',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text('Create New Attribute', style: TextStyle(color: Colors.green[700])),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              Icon(Icons.settings, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Manage Attributes', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value is AttributeModel) {
          _addAttribute(value);
        } else if (value == 'create_new') {
          _showCreateAttributeDialog();
        } else if (value == 'manage') {
          _showManageAttributesInfo();
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No attributes selected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add attributes like Color, Size to auto-generate variants',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_attributeStore.attributes.isEmpty)
            OutlinedButton.icon(
              onPressed: _showManageAttributesInfo,
              icon: const Icon(Icons.add),
              label: const Text('Create Attributes First'),
            ),
        ],
      ),
    );
  }

  Widget _buildVariantPreview() {
    if (_previewCombinations.isEmpty) {
      return const SizedBox.shrink();
    }

    final allSelected = _selectedCount == _previewCombinations.length;
    final noneSelected = _selectedCount == 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Select All / Unselect All
          Row(
            children: [
              const Icon(Icons.preview, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedCount / ${_previewCombinations.length} variants selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ),
              // Select All / Unselect All buttons
              TextButton(
                onPressed: allSelected ? null : _selectAllCombinations,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 12,
                    color: allSelected ? Colors.grey : Colors.green,
                  ),
                ),
              ),
              const Text(' | ', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: noneSelected ? null : _unselectAllCombinations,
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

          // Variant checkboxes
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _previewCombinations.map((combo) {
              final isSelected = _selectedCombinations.contains(combo.displayName);
              return _VariantCheckbox(
                label: combo.shortDescription,
                isSelected: isSelected,
                onTap: () => _toggleCombination(combo.displayName),
              );
            }).toList(),
          ),

          // Warning if none selected
          if (noneSelected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Select at least one variant to generate',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Navigate to Attributes screen and reload attributes on return
  Future<void> _showManageAttributesInfo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttributesScreen()),
    );
    // Reload attributes when returning from the screen
    await _loadAttributes();
  }
}

class _AttributeSection extends StatelessWidget {
  final AttributeWithValues attributeWithValues;
  final VoidCallback onRemove;
  final Function(AttributeValueModel) onToggleValue;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final VoidCallback? onAddValue;

  const _AttributeSection({
    required this.attributeWithValues,
    required this.onRemove,
    required this.onToggleValue,
    required this.onSelectAll,
    required this.onClearAll,
    this.onAddValue,
  });

  @override
  Widget build(BuildContext context) {
    final attr = attributeWithValues.attribute;
    final available = attributeWithValues.availableValues;
    final selected = attributeWithValues.selectedValues;
    final isColor = attr.name.toLowerCase().contains('color') ||
        attr.name.toLowerCase().contains('colour');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                attr.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${selected.length}/${available.length})',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: selected.length == available.length ? onClearAll : onSelectAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  selected.length == available.length ? 'Clear All' : 'Select All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: Colors.grey[600],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Values
          if (available.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No values defined for this attribute.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                if (onAddValue != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onAddValue,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Value'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...available.map((value) {
                      final isSelected = selected.any((v) => v.valueId == value.valueId);
                      return _ValueChip(
                        value: value,
                        isColor: isColor,
                        isSelected: isSelected,
                        onTap: () => onToggleValue(value),
                      );
                    }),
                    // Add Value button as a chip
                    if (onAddValue != null)
                      InkWell(
                        onTap: onAddValue,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Add Value',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final AttributeValueModel value;
  final bool isColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ValueChip({
    required this.value,
    required this.isColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? chipColor;
    if (isColor && value.colorCode != null) {
      try {
        final hex = value.colorCode!.replaceAll('#', '');
        chipColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Material(
      color: isSelected
          ? Colors.blue
          : (chipColor?.withOpacity(0.2) ?? Colors.grey[200]),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chipColor != null) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: chipColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox widget for variant selection
class _VariantCheckbox extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VariantCheckbox({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isSelected ? Colors.green : Colors.grey[400],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.black87 : Colors.grey[600],
                decoration: isSelected ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}