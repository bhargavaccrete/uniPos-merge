import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/variant_generator_service.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';

import '../../../core/di/service_locator.dart';
import '../../screens/retail/attributes_screen.dart';
import '../componets/common/app_dialog.dart';
import '../componets/common/app_empty_state.dart';
import '../componets/common/app_text_field.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:google_fonts/google_fonts.dart';


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

    if (!mounted) return;
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
      builder: (dialogContext) => AppDialogShell(
        title: 'Create New Attribute',
        subtitle: 'A field you can reuse across products',
        accent: AppColors.primary,
        icon: Icons.new_label_outlined,
        body: AppTextField(
          controller: nameController,
          label: 'Attribute Name',
          hint: 'e.g. Colour, Storage, Flavour',
          icon: Icons.label_outline_rounded,
          required: true,
          autofocus: true,
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Create',
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                NotificationService.instance
                    .showWarning('Please enter an attribute name');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      await _attributeStore.addAttribute(name);
      await _loadAttributes();

      NotificationService.instance.showSuccess('Attribute "$name" created');

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
      builder: (dialogContext) => AppDialogShell(
        title: 'Add Value',
        subtitle: 'for ${attrWithValues.attribute.name}',
        accent: AppColors.primary,
        icon: Icons.playlist_add_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: valueController,
              label: 'Value',
              hint: 'e.g. Red, Large, 1TB',
              icon: Icons.sell_outlined,
              required: true,
              autofocus: true,
            ),
            if (isColor) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: colorController,
                label: 'Colour Code (Optional)',
                hint: 'FF0000',
                icon: Icons.palette_outlined,
              ),
            ],
          ],
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Add',
            onPressed: () {
              final value = valueController.text.trim();
              if (value.isEmpty) {
                NotificationService.instance
                    .showWarning('Please enter a value');
                return;
              }

              Navigator.pop(dialogContext, true);
            },
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

      NotificationService.instance.showSuccess('Value "$value" added successfully');
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
      NotificationService.instance.showWarning('Please select at least one value for each attribute');
      return;
    }

    // Filter only selected combinations
    final selectedCombos = _previewCombinations
        .where((combo) => _selectedCombinations.contains(combo.displayName))
        .toList();

    if (selectedCombos.isEmpty) {
      NotificationService.instance.showWarning('Please select at least one variant to generate');
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

    NotificationService.instance.showSuccess('Generated ${variants.length} variant(s)');
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
            // The screen above already renders the "Product Attributes"
            // section header, so only the action lives here.
            Align(
              alignment: Alignment.centerRight,
              child: _buildAddAttributeButton(),
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
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: Text('Generate $_selectedCount Variant(s)',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  /// "Add Attribute" trigger.
  ///
  /// One button plus a bottom sheet, replacing two near-identical
  /// PopupMenuButtons — the platform menu picked up Material 3's surface tint
  /// and mixed pickable attributes with actions in the same list.
  Widget _buildAddAttributeButton() {
    return InkWell(
      onTap: _showAddAttributeSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Add Attribute',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  /// Attributes still available for this product, plus the create/manage
  /// actions kept below a divider so they can't be mistaken for choices.
  Future<void> _showAddAttributeSheet() async {
    final available = _attributeStore.attributes
        .where((a) =>
            !_selectedAttributes.any((s) => s.attribute.attributeId == a.attributeId))
        .toList();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Text('Add Attribute',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: available.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'All your attributes are already added to this product.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: available.length,
                        itemBuilder: (_, i) {
                          final attr = available[i];
                          final values =
                              _attributeStore.getValues(attr.attributeId);
                          return ListTile(
                            leading: const Icon(Icons.label_outline_rounded,
                                color: AppColors.primary, size: 20),
                            title: Text(attr.name,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            subtitle: Text(
                              values.isEmpty
                                  ? 'No values yet'
                                  : values.map((v) => v.value).take(4).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _addAttribute(attr);
                            },
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary, size: 20),
                title: Text('Create New Attribute',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCreateAttributeDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded,
                    color: AppColors.textSecondary, size: 20),
                title: Text('Manage Attributes',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showManageAttributesInfo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: AppEmptyState(
        dense: true,
        icon: Icons.category_outlined,
        title: 'No attributes selected',
        message: 'Add attributes like Colour or Size to auto-generate variants',
        action: _attributeStore.attributes.isEmpty
            ? OutlinedButton.icon(
                onPressed: _showManageAttributesInfo,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Create Attributes First',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            : null,
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
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Select All / Unselect All
          Row(
            children: [
              const Icon(Icons.preview, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedCount / ${_previewCombinations.length} variants selected',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
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
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: allSelected ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
              ),
              Text(' | ',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              TextButton(
                onPressed: noneSelected ? null : _unselectAllCombinations,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Unselect All',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        noneSelected ? AppColors.textSecondary : AppColors.danger,
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
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(
                    'Select at least one variant to generate',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning),
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
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                attr.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${selected.length}/${available.length})',
                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
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
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: AppColors.textSecondary,
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
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
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
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Add Value',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
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
          ? AppColors.primary
          : (chipColor?.withOpacity(0.2) ?? AppColors.surfaceLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider),
      ),
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
                    border: Border.all(color: AppColors.divider),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value.value,
                style: GoogleFonts.poppins(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 14, color: AppColors.white),
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
          color: isSelected ? AppColors.white : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                decoration: isSelected ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}