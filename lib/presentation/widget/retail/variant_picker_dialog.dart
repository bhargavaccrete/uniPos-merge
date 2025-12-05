import 'package:flutter/material.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/domain/store/retail/attribute_store.dart';



/// WooCommerce-style variant picker dialog for POS
/// Allows selecting variants using attribute chip filters
class VariantPickerDialog extends StatefulWidget {
  final ProductModel product;
  final List<VarianteModel> variants;
  final Function(VarianteModel) onVariantSelected;

  const VariantPickerDialog({
    super.key,
    required this.product,
    required this.variants,
    required this.onVariantSelected,
  });

  /// Show the variant picker dialog
  static Future<VarianteModel?> show({
    required BuildContext context,
    required ProductModel product,
    required List<VarianteModel> variants,
  }) {
    return showDialog<VarianteModel>(
      context: context,
      builder: (context) => VariantPickerDialog(
        product: product,
        variants: variants,
        onVariantSelected: (variant) => Navigator.of(context).pop(variant),
      ),
    );
  }

  @override
  State<VariantPickerDialog> createState() => _VariantPickerDialogState();
}

class _VariantPickerDialogState extends State<VariantPickerDialog> {
  final AttributeStore _attributeStore = attributeStore;

  // Selected attribute values for filtering
  // Key: attributeId, Value: selected valueId
  final Map<String, String?> _selectedFilters = {};

  // All unique attribute-value pairs from variants
  late Map<String, List<AttributeValueInfo>> _attributeOptions;

  // Filtered variants based on selection
  List<VarianteModel> _filteredVariants = [];

  @override
  void initState() {
    super.initState();
    _buildAttributeOptions();
    _filteredVariants = widget.variants;
  }

  void _buildAttributeOptions() {
    _attributeOptions = {};

    // Extract all unique attribute-value combinations from variants
    for (final variant in widget.variants) {
      // From attributeValueIds (WooCommerce-style)
      if (variant.attributeValueIds != null) {
        for (final entry in variant.attributeValueIds!.entries) {
          final attributeId = entry.key;
          final valueId = entry.value;

          final attribute = _attributeStore.getAttributeById(attributeId);
          final value = _attributeStore.getValueById(valueId);

          if (attribute != null && value != null) {
            _attributeOptions.putIfAbsent(attributeId, () => []);
            if (!_attributeOptions[attributeId]!.any((v) => v.valueId == valueId)) {
              _attributeOptions[attributeId]!.add(AttributeValueInfo(
                attributeId: attributeId,
                attributeName: attribute.name,
                valueId: valueId,
                value: value.value,
                colorCode: value.colorCode,
              ));
            }
          }
        }
      }

      // From legacy fields (size, color, weight)
      _addLegacyAttribute('size', 'Size', variant.size);
      _addLegacyAttribute('color', 'Color', variant.color);
      _addLegacyAttribute('weight', 'Weight', variant.weight);

      // From custom attributes
      if (variant.customAttributes != null) {
        for (final entry in variant.customAttributes!.entries) {
          _addLegacyAttribute(
            entry.key.toLowerCase(),
            entry.key,
            entry.value,
          );
        }
      }
    }

    // Initialize filters (all null = no filter)
    for (final attributeId in _attributeOptions.keys) {
      _selectedFilters[attributeId] = null;
    }
  }

  void _addLegacyAttribute(String id, String name, String? value) {
    if (value == null || value.isEmpty) return;

    _attributeOptions.putIfAbsent(id, () => []);
    if (!_attributeOptions[id]!.any((v) => v.value == value)) {
      _attributeOptions[id]!.add(AttributeValueInfo(
        attributeId: id,
        attributeName: name,
        valueId: value, // Use value as ID for legacy
        value: value,
      ));
    }
  }

  void _updateFilters(String attributeId, String? valueId) {
    setState(() {
      _selectedFilters[attributeId] = valueId;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredVariants = widget.variants.where((variant) {
      for (final entry in _selectedFilters.entries) {
        final attributeId = entry.key;
        final selectedValueId = entry.value;

        if (selectedValueId == null) continue; // No filter for this attribute

        // Check WooCommerce-style attributeValueIds
        if (variant.attributeValueIds != null) {
          final variantValueId = variant.attributeValueIds![attributeId];
          if (variantValueId == selectedValueId) continue;
        }

        // Check legacy fields
        String? variantValue;
        if (attributeId == 'size') variantValue = variant.size;
        if (attributeId == 'color') variantValue = variant.color;
        if (attributeId == 'weight') variantValue = variant.weight;

        // Check custom attributes
        if (variant.customAttributes != null) {
          for (final ca in variant.customAttributes!.entries) {
            if (ca.key.toLowerCase() == attributeId) {
              variantValue = ca.value;
              break;
            }
          }
        }

        if (variantValue == selectedValueId) continue;

        return false; // Doesn't match filter
      }
      return true;
    }).toList();

    // Auto-select if only one variant matches
    if (_filteredVariants.length == 1) {
      widget.onVariantSelected(_filteredVariants.first);
    }
  }

  void _clearFilters() {
    setState(() {
      for (final key in _selectedFilters.keys) {
        _selectedFilters[key] = null;
      }
      _filteredVariants = widget.variants;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select variant',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Attribute Filters
            if (_attributeOptions.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _attributeOptions.entries.map((entry) {
                    return _AttributeFilterRow(
                      attributeId: entry.key,
                      attributeName: entry.value.firstOrNull?.attributeName ?? entry.key,
                      values: entry.value,
                      selectedValueId: _selectedFilters[entry.key],
                      onValueSelected: (valueId) => _updateFilters(entry.key, valueId),
                    );
                  }).toList(),
                ),
              ),

            // Filter Summary & Clear
            if (_selectedFilters.values.any((v) => v != null))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${_filteredVariants.length} variant(s) match',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear Filters'),
                    ),
                  ],
                ),
              ),

            const Divider(),

            // Variant List
            Flexible(
              child: _filteredVariants.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No variants match the selected filters'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredVariants.length,
                      itemBuilder: (context, index) {
                        final variant = _filteredVariants[index];
                        return _VariantListItem(
                          variant: variant,
                          onTap: () => widget.onVariantSelected(variant),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributeFilterRow extends StatelessWidget {
  final String attributeId;
  final String attributeName;
  final List<AttributeValueInfo> values;
  final String? selectedValueId;
  final Function(String?) onValueSelected;

  const _AttributeFilterRow({
    required this.attributeId,
    required this.attributeName,
    required this.values,
    required this.selectedValueId,
    required this.onValueSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isColor = attributeName.toLowerCase().contains('color') ||
        attributeName.toLowerCase().contains('colour');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attributeName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // "All" option
              _FilterChip(
                label: 'All',
                isSelected: selectedValueId == null,
                onTap: () => onValueSelected(null),
              ),
              // Value options
              ...values.map((value) {
                return _FilterChip(
                  label: value.value,
                  colorCode: isColor ? value.colorCode : null,
                  isSelected: selectedValueId == value.valueId,
                  onTap: () => onValueSelected(value.valueId),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? colorCode;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.colorCode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? chipColor;
    if (colorCode != null) {
      try {
        final hex = colorCode!.replaceAll('#', '');
        chipColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Material(
      color: isSelected
          ? Theme.of(context).primaryColor
          : (chipColor?.withOpacity(0.2) ?? Colors.grey[200]),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chipColor != null) ...[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: chipColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantListItem extends StatelessWidget {
  final VarianteModel variant;
  final VoidCallback onTap;

  const _VariantListItem({
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = variant.stockQty <= 0;

    return Card(
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: isOutOfStock ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Variant Image (if available)
                if (variant.imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      variant.imagePath!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey[400],
                    ),
                  ),

                const SizedBox(width: 12),

                // Variant Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.shortDescription,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (variant.sku != null)
                            Text(
                              'SKU: ${variant.sku}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          if (variant.barcode != null) ...[
                            if (variant.sku != null)
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                            Text(
                              variant.barcode!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Stock & Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${variant.effectivePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.red[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOutOfStock ? 'Out of Stock' : 'Stock: ${variant.stockQty}',
                        style: TextStyle(
                          color: isOutOfStock ? Colors.red[700] : Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper class to store attribute value info
class AttributeValueInfo {
  final String attributeId;
  final String attributeName;
  final String valueId;
  final String value;
  final String? colorCode;

  AttributeValueInfo({
    required this.attributeId,
    required this.attributeName,
    required this.valueId,
    required this.value,
    this.colorCode,
  });
}