import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';



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
      // _addLegacyAttribute('size', 'Size', variant.size);
      // _addLegacyAttribute('color', 'Color', variant.color);
      // _addLegacyAttribute('weight', 'Weight', variant.weight);

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
        // if (attributeId == 'size') variantValue = variant.size;
        // if (attributeId == 'color') variantValue = variant.color;
        // if (attributeId == 'weight') variantValue = variant.weight;

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
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                    AppResponsive.dialogWidth(context)) /
                2)
            .clamp(40.0, double.infinity)
        : 20.0;
    final hasActiveFilter = _selectedFilters.values.any((v) => v != null);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
      backgroundColor: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: AppResponsive.screenHeight(context) * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (_attributeOptions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _attributeOptions.entries.map((entry) {
                    return _AttributeFilterRow(
                      attributeName:
                          entry.value.firstOrNull?.attributeName ?? entry.key,
                      values: entry.value,
                      selectedValueId: _selectedFilters[entry.key],
                      onValueSelected: (valueId) =>
                          _updateFilters(entry.key, valueId),
                    );
                  }).toList(),
                ),
              ),
              Divider(height: 1, thickness: 1, color: AppColors.divider),
            ],

            // Result count + clear — only while a filter is active
            if (hasActiveFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    Text(
                      '${_filteredVariants.length} of ${widget.variants.length} match',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        'Clear',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Variant list
            Flexible(
              child: _filteredVariants.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      itemCount: _filteredVariants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.style_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a variant to add',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
            iconSize: 22,
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No variants match the selected filters',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeFilterRow extends StatelessWidget {
  final String attributeName;
  final List<AttributeValueInfo> values;
  final String? selectedValueId;
  final Function(String?) onValueSelected;

  const _AttributeFilterRow({
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attributeName.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
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
    Color? swatch;
    if (colorCode != null) {
      try {
        final hex = colorCode!.replaceAll('#', '');
        swatch = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    final radius = BorderRadius.circular(10);

    return Material(
      color: isSelected ? AppColors.primary : AppColors.surfaceLight,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (swatch != null) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.white : AppColors.divider,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    final stockColor = isOutOfStock ? AppColors.danger : AppColors.success;
    final radius = BorderRadius.circular(12);

    return Material(
      color: AppColors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: radius,
        child: Opacity(
          opacity: isOutOfStock ? 0.55 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                // Variant image (network path) or placeholder tile
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: variant.imagePath != null
                      ? Image.network(
                          variant.imagePath!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderTile(),
                        )
                      : _placeholderTile(),
                ),

                const SizedBox(width: 12),

                // Variant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.shortDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (variant.sku != null || variant.barcode != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (variant.sku != null) 'SKU: ${variant.sku}',
                            if (variant.barcode != null) variant.barcode!,
                          ].join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Price & stock
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: CurrencyHelper.currencyNotifier,
                      builder: (context, currencyCode, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: DecimalSettings.precisionNotifier,
                          builder: (context, precision, child) {
                            final symbol = CurrencyHelper.currentSymbol;
                            final formattedPrice =
                                variant.effectivePrice.toStringAsFixed(precision);
                            return Text(
                              '$symbol$formattedPrice',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : 'Stock: ${variant.stockQty}',
                        style: GoogleFonts.poppins(
                          color: stockColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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

  Widget _placeholderTile() => Container(
        width: 46,
        height: 46,
        color: AppColors.surfaceMedium,
        child: Icon(
          Icons.inventory_2_outlined,
          size: 22,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
      );
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