

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/color.dart';
import '../../../../screens/restaurant/item/add_more_info_screen.dart';
import 'add_category_dialog.dart';
import 'add_item_form_state.dart';
import 'category_selector_sheet.dart';
import 'image_picker_sheet.dart';
import 'veg_selector_sheet.dart';
import 'widgets/category_selector_button.dart';
import 'widgets/inventory_toggle.dart';
import 'widgets/selling_method_selector.dart';

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
    final isWide = MediaQuery.of(context).size.width >= 850;

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

  @override
  void dispose() {
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
      await itemStore.addItem(item);
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Missing Required Fields',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(validation.errorMessage,
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.poppins(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
    return [
      _buildItemNameField(),
      const SizedBox(height: 14),
      _buildSellingMethodSelector(),
      const SizedBox(height: 14),
      _buildPriceField(),
      const SizedBox(height: 14),
      _buildCategorySelector(),
      const SizedBox(height: 14),
      _buildVegSelector(),
      const SizedBox(height: 14),
      _buildDescriptionField(),
      const SizedBox(height: 14),
      _buildInventoryToggle(),
      const SizedBox(height: 16),
      _buildImageUploader(),
      const SizedBox(height: 24),
      _buildActionButtons(),
    ];
  }

  // ── Field Helpers ─────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, IconData icon,
      {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
          color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.poppins(
          fontSize: 14, color: AppColors.textPrimary),
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildItemNameField() {
    return TextField(
      controller: _formState.itemNameController,
      style:
          GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration('Item Name', Icons.fastfood_outlined),
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _formState.priceController,
      keyboardType: TextInputType.number,
      style:
          GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      decoration:
          _inputDecoration('Price', Icons.currency_rupee, prefixText: '₹ '),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _formState.descriptionController,
      maxLines: 3,
      minLines: 1,
      style:
          GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Description (Optional)',
        labelStyle: GoogleFonts.poppins(
            color: AppColors.textSecondary, fontSize: 13),
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 44),
          child: Icon(Icons.notes_outlined,
              color: AppColors.primary, size: 20),
        ),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildSellingMethodSelector() {
    return SellingMethodSelector(
      sellingMethod: _formState.sellingMethod,
      selectedUnit: _formState.selectedUnit,
      onMethodChanged: (method) =>
          setState(() => _formState.setSellingMethod(method)),
      onUnitChanged: (unit) =>
          setState(() => _formState.setUnit(unit)),
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
        return CategorySelectorButton(
          selectedCategoryName: liveName ?? _formState.selectedCategoryName,
          onTap: _selectCategory,
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
