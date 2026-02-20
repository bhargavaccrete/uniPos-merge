import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/common/app_responsive.dart';
import '../../../../screens/restaurant/item/add_more_info_screen.dart';
import '../componets/Button.dart';
import '../componets/Textform.dart';
import 'add_category_dialog.dart';
import 'add_item_form_state.dart';
import 'category_selector_sheet.dart';
import 'image_picker_sheet.dart';
import 'veg_selector_sheet.dart';
import 'widgets/category_selector_button.dart';
import 'widgets/inventory_toggle.dart';
import 'widgets/selling_method_selector.dart';

/// Bottom sheet for adding a new item
class AddItemSheet extends StatefulWidget {
  final Function(String)? onCategorySelected;
  final VoidCallback? onItemAdded;

  const AddItemSheet({
    super.key,
    this.onCategorySelected,
    this.onItemAdded,
  });

  /// Show the add item sheet
  static Future<void> show(
    BuildContext context, {
    Function(String)? onCategorySelected,
    VoidCallback? onItemAdded,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return AddItemSheet(
          onCategorySelected: onCategorySelected,
          onItemAdded: onItemAdded,
        );
      },
    );
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile == null) return;

      final Uint8List bytes = await pickedFile.readAsBytes();
      const maxSizeInBytes = 3 * 1024 * 1024;
      if (bytes.length > maxSizeInBytes) {
        NotificationService.instance.showError('Image size must be less than 3MB. Please choose a smaller image.');
        return;
      }
      setState(() { _formState.setImage(bytes); });
    } catch (e) {
      NotificationService.instance.showError('Failed to pick image. Please try again.');
    }
  }

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
      setState(() {
        _formState.setCategory(result.id, result.name);
      });
    }
  }

  Future<void> _selectVegCategory() async {
    final result = await VegSelectorSheet.show(
      context,
      currentSelection: _formState.vegCategory,
    );

    if (result != null) {
      setState(() {
        _formState.setVegCategory(result);
      });
    }
  }

  Future<void> _saveItem() async {
    if (_isSaving) return;
    final validation = _formState.validate();
    if (!validation.isValid) {
      _showValidationError(validation);
      return;
    }

    setState(() { _isSaving = true; });
    try {
      final item = await _formState.toItem();
      await itemStore.addItem(item);
      widget.onItemAdded?.call();
      if (mounted) {
        Navigator.pop(context);
        if (widget.onCategorySelected != null && _formState.selectedCategoryId != null) {
          widget.onCategorySelected!(_formState.selectedCategoryId!);
        }
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
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
        builder: (context) => AddMoreInfoScreen(
          initialData: _formState.toMap(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _formState.updateFromMoreInfo(result);
      });

      if (result['shouldSave'] == true) {
        await _saveItem();
      }
    }
  }

  void _showValidationError(ValidationResult validation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Missing Required Fields',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            validation.errorMessage,
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.deepOrange),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
                  padding: EdgeInsets.fromLTRB(15, 5, 15, 40 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildItemNameField(),
                const SizedBox(height: 15),
                _buildSellingMethodSelector(),
                const SizedBox(height: 15),
                _buildPriceField(),
                const SizedBox(height: 15),
                _buildCategorySelector(),
                const SizedBox(height: 15),
                _buildVegSelector(),
                const SizedBox(height: 15),
                _buildDescriptionField(),
                const SizedBox(height: 15),
                _buildInventoryToggle(),
                const SizedBox(height: 20),
                _buildImageUploader(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Text(
        "Add Item",
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemNameField() {
    return SizedBox(
      height: AppResponsive.height(context, 0.06),
      child: CommonTextForm(
        borderc: 5,
        labelText: 'Item Name',
        controller: _formState.itemNameController,
        obsecureText: false,
      ),
    );
  }

  Widget _buildSellingMethodSelector() {
    return SellingMethodSelector(
      sellingMethod: _formState.sellingMethod,
      selectedUnit: _formState.selectedUnit,
      onMethodChanged: (method) {
        setState(() {
          _formState.setSellingMethod(method);
        });
      },
      onUnitChanged: (unit) {
        setState(() {
          _formState.setUnit(unit);
        });
      },
    );
  }

  Widget _buildPriceField() {
    return SizedBox(
      height: AppResponsive.height(context, 0.06),
      child: CommonTextForm(
        borderc: 5,
        labelText: 'Price',
        controller: _formState.priceController,
        obsecureText: false,
        keyboardType: TextInputType.number,
      ),
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

  Widget _buildDescriptionField() {
    return TextField(
      controller: _formState.descriptionController,
      maxLines: 3,
      minLines: 1,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Description (Optional)',
        labelStyle: GoogleFonts.poppins(color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.deepOrange),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildInventoryToggle() {
    return InventoryToggle(
      trackInventory: _formState.trackInventory,
      allowOrderWhenOutOfStock: _formState.allowOrderWhenOutOfStock,
      onTrackInventoryChanged: (value) {
        setState(() {
          _formState.setTrackInventory(value);
        });
      },
      onAllowOutOfStockChanged: (value) {
        setState(() {
          _formState.setAllowOrderWhenOutOfStock(value);
        });
      },
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: CommonButton(
            onTap: _handleAddMoreInfo,
            bgcolor: Colors.white,
            bordercolor: Colors.deepOrange,
            height: AppResponsive.height(context, 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'Add More Info',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.2, desktop: 14.4),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CommonButton(
            onTap: _isSaving ? () {} : _saveItem,
            height: AppResponsive.height(context, 0.06),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add, color: Colors.deepOrange),
                      ),
                      const SizedBox(width: 5),
                      Text("Add Item", style: GoogleFonts.poppins(color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
