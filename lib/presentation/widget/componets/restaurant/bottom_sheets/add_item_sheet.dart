

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/config/tax_feature.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/color.dart';
import '../../../../../util/common/app_responsive.dart';
import '../../../../../util/restaurant/staticswitch.dart';
import '../../../../../domain/services/restaurant/stock_adjust_service.dart';
import '../../../../../data/models/restaurant/db/product_type.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../../../screens/restaurant/item/add_more_info_screen.dart';
import 'tax_selector_sheet.dart';
import 'add_category_dialog.dart';
import '../../common/app_text_field.dart';
import '../../common/app_dialog.dart';
import 'add_item_form_state.dart';
import 'category_selector_sheet.dart';
import 'image_picker_sheet.dart';
import 'veg_selector_sheet.dart';
import 'widgets/category_selector_button.dart';
import 'widgets/tax_selector_button.dart';
import 'widgets/inventory_toggle.dart';
import 'widgets/selling_method_selector.dart' show SellingMethodSheet, SellingMethodButton;

/// Responsive add-item sheet:
/// - Mobile  → bottom sheet (DraggableScrollableSheet)
/// - Tablet/Desktop → centered Dialog (width capped at 580)
class AddItemSheet extends StatefulWidget {
  final Function(String)? onCategorySelected;
  final VoidCallback? onItemAdded;
  final bool isDialog;

  const AddItemSheet({
    super.key,
    this.onCategorySelected,

    this.onItemAdded,
    this.isDialog = false,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String)? onCategorySelected,
    VoidCallback? onItemAdded,
  }) async {
    final isWide = !AppResponsive.isMobile(context);

    if (isWide) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: AddItemSheet(
              isDialog: true,
              onCategorySelected: onCategorySelected,
              onItemAdded: onItemAdded,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => AddItemSheet(
          isDialog: false,
          onCategorySelected: onCategorySelected,
          onItemAdded: onItemAdded,
        ),
      );
    }
  }

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formState = AddItemFormState();
  bool _isSaving = false;

  // Focus nodes for all text fields
  final _itemNameFocusNode = FocusNode();
  final _itemCodeFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  @override
  void dispose() {
    _itemNameFocusNode.dispose();
    _itemCodeFocusNode.dispose();
    _priceFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _formState.dispose();
    super.dispose();
  }

  // ── Image ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile == null) return;
      final Uint8List bytes = await pickedFile.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        NotificationService.instance.showError(
            'Image size must be less than 3MB. Please choose a smaller image.');
        return;
      }
      setState(() => _formState.setImage(bytes));
    } catch (_) {
      NotificationService.instance
          .showError('Failed to pick image. Please try again.');
    }
  }

  // ── Selectors ────────────────────────────────────────────────────────────

  Future<void> _selectCategory() async {
    final result = await CategorySelectorSheet.show(
      context,
      selectedCategoryId: _formState.selectedCategoryId,
      onAddCategory: () async {
        Navigator.pop(context);
        final wasAdded = await AddCategoryDialog.show(context);
        if (wasAdded) _selectCategory();
      },
    );
    if (result != null) {
      setState(() => _formState.setCategory(result.id, result.name));
    }
  }

  Future<void> _selectVegCategory() async {
    final result = await VegSelectorSheet.show(
      context,
      currentSelection: _formState.vegCategory,
    );
    if (result != null) {
      setState(() => _formState.setVegCategory(result));
    }
  }

  // ── Save / More Info ─────────────────────────────────────────────────────

  Future<void> _saveItem() async {
    if (_isSaving) return;
    final validation = _formState.validate();
    if (!validation.isValid) {
      _showValidationError(validation);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final item = await _formState.toItem();
      // Respect the store result — addItem returns false (without throwing) when
      // the plan item cap is hit or a duplicate is rejected. Previously this was
      // ignored, so the sheet claimed "added successfully" and closed while the
      // item was never saved (it never appeared in the list).
      final success = await itemStore.addItem(item);
      if (!success) {
        NotificationService.instance
            .showError(itemStore.errorMessage ?? 'Could not add item.');
        return; // keep the sheet open; don't fire onItemAdded / pop
      }
      await StockAdjustService.recordOpeningStock(item);
      // Semi-Finished/Recipe-Based items are created with no recipe (that's
      // built in Edit) — make the incomplete state obvious instead of
      // silently allowing a recipeless item to look fully configured.
      if (ProductType.hasRecipe(item.productType)) {
        NotificationService.instance.showWarning(
            '${item.name} saved — add its recipe in Edit before selling it.');
      }
      widget.onItemAdded?.call();
      if (mounted) {
        Navigator.pop(context);
        if (widget.onCategorySelected != null &&
            _formState.selectedCategoryId != null) {
          widget.onCategorySelected!(_formState.selectedCategoryId!);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleAddMoreInfo() async {
    final validation = _formState.validate();
    if (!validation.isValid) {
      _showValidationError(validation);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMoreInfoScreen(initialData: _formState.toMap()),
      ),
    );
    if (result != null) {
      setState(() => _formState.updateFromMoreInfo(result));
      if (result['shouldSave'] == true) await _saveItem();
    }
  }

  void _showValidationError(ValidationResult validation) {
    showAppErrorDialog(
      context: context,
      errors: validation.missingFields,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return widget.isDialog ? _buildDialogLayout() : _buildSheetLayout();
  }

  // ── Dialog Layout ─────────────────────────────────────────────────────────

  Widget _buildDialogLayout() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDialogHeader(),
          const Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _formFields(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Menu Item',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('Fill in the item details below',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Sheet Layout (mobile) ─────────────────────────────────────────────────

  Widget _buildSheetLayout() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 40 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetHeader(),
                      const SizedBox(height: 20),
                      ..._formFields(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.restaurant_menu_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Menu Item',
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text('Fill in the item details below',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared Form Fields ────────────────────────────────────────────────────

  List<Widget> _formFields() {
    final isRecipeBased = _formState.productType == ProductType.recipeBased;
    final isBackOfHouse = _formState.productType == ProductType.rawMaterial ||
        _formState.productType == ProductType.semiFinished;
    return [
      // Product Type drives every other field below it, so it's the first
      // decision the user makes.
      _buildProductTypeSelector(),
      const SizedBox(height: 18),
      if (_formState.productType == ProductType.rawMaterial) ...[
        _buildSellDirectlyAtPosToggle(),
        const SizedBox(height: 14),
      ],
      _buildItemNameField(),
      const SizedBox(height: 14),
      _buildItemCodeField(),
      const SizedBox(height: 18),
      // Raw Material/Semi-Finished aren't sold, so Selling Method (a POS
      // concept) is replaced by a plain Stock Unit picker.
      isBackOfHouse ? _buildStockUnitSelector() : _buildSellingMethodSelector(),
      const SizedBox(height: 14),
      _buildPriceField(),
      const SizedBox(height: 14),
      _buildCategorySelector(),
      const SizedBox(height: 14),
      if (TaxFeature.enabled) ...[
        _buildTaxSelector(),
        const SizedBox(height: 14),
      ],
      _buildVegSelector(),
      const SizedBox(height: 14),
      _buildDescriptionField(),
      const SizedBox(height: 14),
      // Recipe-Based items have no stock of their own — availability is derived
      // live from their ingredients, so the stock module is replaced by a note
      // plus the one stock-adjacent setting that still applies: Allow Order
      // When Out of Stock, which the inventory service enforces against the
      // calculated available-to-make figure, not a physical quantity.
      if (isRecipeBased) ...[
        _buildRecipeBasedStockNote(),
        const SizedBox(height: 14),
        _buildRecipeBasedAllowOOSToggle(),
      ] else ...[
        _buildInventoryToggle(),
        if (_formState.trackInventory) ...[
          if (_formState.selectedVariants.isEmpty) ...[
            const SizedBox(height: 14),
            _buildCurrentStockField(),
          ] else ...[
            const SizedBox(height: 10),
            Text('Stock is set per variant in More Info.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 14),
          _buildLowStockSection(),
        ],
      ],
      const SizedBox(height: 16),
      _buildImageUploader(),
      const SizedBox(height: 24),
      _buildActionButtons(),
    ];
  }

  // ── Field Builders ────────────────────────────────────────────────────────

  Widget _buildItemNameField() {
    return AppTextField(
      controller: _formState.itemNameController,
      focusNode: _itemNameFocusNode,
      label: 'Item Name',
      hint: 'e.g. Margherita Pizza',
      icon: Icons.fastfood_outlined,
      required: true,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _itemCodeFocusNode.requestFocus(),
    );
  }

  Widget _buildItemCodeField() {
    return AppTextField(
      controller: _formState.itemCodeController,
      focusNode: _itemCodeFocusNode,
      label: 'Item Code',
      hint: 'e.g. 10021',
      icon: Icons.qr_code_scanner_rounded,
      required: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5), // item code = max 5 digits
      ],
      textInputAction: TextInputAction.next,
      // Skip the Selling Method button (not a text field) → jump to Price.
      onFieldSubmitted: (_) => _priceFocusNode.requestFocus(),
    );
  }

  // ── Product Type selector ─────────────────────────────────────────────────

  static const List<
      ({
        String type,
        IconData icon,
        Color color,
        String label,
        String desc,
      })> _productTypeOptions = [
    (
      type: ProductType.finishedGood,
      icon: Icons.inventory_2_rounded,
      color: AppColors.info,
      label: 'Finished Good',
      desc: 'Ready to sell as-is',
    ),
    (
      type: ProductType.recipeBased,
      icon: Icons.lunch_dining_rounded,
      color: AppColors.accent,
      label: 'Recipe-Based',
      desc: 'Assembled from a recipe when sold',
    ),
    (
      type: ProductType.rawMaterial,
      icon: Icons.grass_rounded,
      color: AppColors.success,
      label: 'Raw Material',
      desc: 'Ingredient — bought & stocked',
    ),
    (
      type: ProductType.semiFinished,
      icon: Icons.soup_kitchen_rounded,
      color: AppColors.secondary,
      label: 'Semi-Finished',
      desc: 'Prepped in batches',
    ),
  ];

  Widget _buildProductTypeSelector() {
    final hasRecipe = ProductType.hasRecipe(_formState.productType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Product Type',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final cardWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: _productTypeOptions
                  .map((o) => SizedBox(
                        width: cardWidth,
                        child: _productTypeCard(o),
                      ))
                  .toList(),
            );
          },
        ),
        if (hasRecipe) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Save the item first, then open it to build its recipe (ingredients, yield & live food cost).',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textPrimary,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _productTypeCard(
      ({
        String type,
        IconData icon,
        Color color,
        String label,
        String desc,
      }) o) {
    final bool selected = _formState.productType == o.type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _formState.setProductType(o.type)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? o.color.withValues(alpha: 0.10)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? o.color : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: o.color.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          o.color,
                          Color.lerp(o.color, Colors.black, 0.2) ?? o.color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(o.icon, size: 15, color: Colors.white),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: selected ? o.color : AppColors.divider,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                o.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? o.color : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                o.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  height: 1.25,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown in place of the stock module for Recipe-Based items — they hold no
  /// stock of their own; availability is derived from their ingredients.
  Widget _buildRecipeBasedStockNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.blender_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "No stock is tracked here — a Recipe-Based item's availability is calculated live from its ingredients.",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textPrimary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField() {
    final isRaw = _formState.productType == ProductType.rawMaterial;
    final bool required = _formState.isMenuType;
    final String label = isRaw
        ? 'Cost Price'
        : (_formState.productType == ProductType.recipeBased
            ? 'Selling Price'
            : 'Price');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _formState.priceController,
          focusNode: _priceFocusNode,
          label: label,
          required: required,
          hint: '0.00',
          prefixWidget: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(CurrencyHelper.currentSymbol,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          textInputAction: TextInputAction.next,
          // Skip the Category/Tax/Veg buttons (not text fields) → jump to Description.
          onFieldSubmitted: (_) => _descriptionFocusNode.requestFocus(),
        ),
        if (!required) ...[
          const SizedBox(height: 6),
          _fieldHint(
            isRaw
                ? 'Optional — the real cost is captured automatically at goods-receiving.'
                : 'Optional for back-of-house prep items.',
          ),
        ],
      ],
    );
  }

  /// Small muted helper line shown beneath a field.
  Widget _fieldHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return AppTextField(
      controller: _formState.descriptionController,
      focusNode: _descriptionFocusNode,
      label: 'Description',
      hint: 'Optional',
      icon: Icons.notes_outlined,
      maxLines: 3,
      minLines: 1,
      // Multiline: leave the return key as a newline; just dismiss on submit.
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Future<void> _selectSellingMethod() async {
    // Unfocus any field before opening the sheet
    FocusScope.of(context).unfocus();
    final result = await SellingMethodSheet.show(
      context,
      currentMethod: _formState.sellingMethod,
      currentUnit: _formState.selectedUnit,
    );
    if (result != null) {
      setState(() {
        _formState.setSellingMethod(result.method);
        _formState.setUnit(result.unit);
      });
      // After selecting selling method, move focus to the price field
      _priceFocusNode.requestFocus();
    }
  }

  Widget _buildSellingMethodSelector() {
    return SellingMethodButton(
      method: _formState.sellingMethod,
      unit: _formState.selectedUnit,
      onTap: _selectSellingMethod,
    );
  }

  Future<void> _selectStockUnit() async {
    FocusScope.of(context).unfocus();
    final result = await SellingMethodSheet.show(
      context,
      currentMethod: _formState.sellingMethod,
      currentUnit: _formState.selectedUnit,
      unitOnly: true,
    );
    if (result != null) {
      setState(() => _formState.setUnit(result.unit));
    }
  }

  /// Raw Material/Semi-Finished's stock-keeping unit — independent of
  /// Selling Method, which stays a pure POS-sale concept for menu types.
  Widget _buildStockUnitSelector() {
    return SellingMethodButton(
      method: _formState.sellingMethod,
      unit: _formState.selectedUnit,
      unitOnly: true,
      onTap: _selectStockUnit,
    );
  }

  /// Raw Material only — mirrors Edit Item's identical switch. Default OFF:
  /// a Raw Material stays hidden from the POS grid unless explicitly opted in.
  Widget _buildSellDirectlyAtPosToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text('Sell directly at POS',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
          'Raw materials are hidden from the menu by default. Turn on to sell this one as-is.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
      value: _formState.sellDirectlyAtPos ?? false,
      activeColor: AppColors.primary,
      onChanged: (v) => setState(() => _formState.setSellDirectlyAtPos(v)),
    );
  }

  /// Recipe-Based items hold no physical stock — this controls only whether
  /// POS may sell when the calculated available-to-make figure is zero,
  /// exactly as InventoryService already enforces; it never implies a
  /// tracked quantity.
  Widget _buildRecipeBasedAllowOOSToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text('Allow order if out of stock',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
          'Let staff sell this even when no ingredients remain to make it.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
      value: _formState.allowOrderWhenOutOfStock,
      activeColor: AppColors.primary,
      onChanged: (v) =>
          setState(() => _formState.setAllowOrderWhenOutOfStock(v)),
    );
  }

  Widget _buildCategorySelector() {
    return Observer(
      builder: (_) {
        final liveName = _formState.selectedCategoryId != null
            ? categoryStore.categories
                .where((c) => c.id == _formState.selectedCategoryId)
                .map((c) => c.name)
                .firstOrNull
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategorySelectorButton(
              selectedCategoryName: liveName ?? _formState.selectedCategoryName,
              onTap: _selectCategory,
            ),
            if (!_formState.isMenuType) ...[
              const SizedBox(height: 6),
              _fieldHint(
                  'Optional — ingredients & prep items are grouped by Product Type, not a menu category.'),
            ],
          ],
        );
      },
    );
  }

  Widget _buildVegSelector() {
    return VegSelectorButton(
      selectedCategory: _formState.vegCategory,
      onTap: _selectVegCategory,
    );
  }

  Future<void> _selectTax() async {
    FocusScope.of(context).unfocus();
    final result = await TaxSelectorSheet.show(
      context,
      selectedTaxIds: _formState.selectedTaxIds,
    );
    if (result != null) {
      setState(() => _formState.setTaxes(result.ids, result.rate));
    }
  }

  Widget _buildTaxSelector() {
    return TaxSelectorButton(
      taxRate: _formState.selectedTaxRate,
      onTap: _selectTax,
    );
  }

  Widget _buildCurrentStockField() {
    final unit = _formState.sellingMethod == SellingMethod.byWeight
        ? _formState.selectedUnit
        : 'pcs';
    return AppTextField(
      controller: _formState.stockController,
      label: 'Current Stock ($unit)',
      hint: '0',
      icon: Icons.inventory_2_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildLowStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('Low-stock alert',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text('Warn when this item runs low',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          value: _formState.lowStockAlertEnabled,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _formState.setLowStockAlert(v)),
        ),
        if (_formState.lowStockAlertEnabled) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final unit = _formState.sellingMethod == SellingMethod.byWeight
                ? _formState.selectedUnit
                : 'pcs';
            return AppTextField(
              controller: _formState.lowStockThresholdController,
              label: 'Alert threshold ($unit, optional)',
              hint: 'Default: ${AppSettings.lowStockThreshold.toStringAsFixed(0)} $unit',
              icon: Icons.warning_amber_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildInventoryToggle() {
    return InventoryToggle(
      trackInventory: _formState.trackInventory,
      allowOrderWhenOutOfStock: _formState.allowOrderWhenOutOfStock,
      onTrackInventoryChanged: (value) =>
          setState(() => _formState.setTrackInventory(value)),
      onAllowOutOfStockChanged: (value) =>
          setState(() => _formState.setAllowOrderWhenOutOfStock(value)),
    );
  }

  Widget _buildImageUploader() {
    return ImageUploader(
      imageBytes: _formState.selectedImage,
      onTap: _pickImage,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleAddMoreInfo,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text('More Info',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveItem,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded,
                    size: 18, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving…' : 'Add Item',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
