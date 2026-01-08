import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../data/models/restaurant/db/database/hive_db.dart';
import '../../../../../util/restaurant/responsive_helper.dart';
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

  @override
  void dispose() {
    _formState.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePickerSheet.show(context);
    if (image != null) {
      setState(() {
        _formState.setImage(image);
      });
    }
  }

  Future<void> _selectCategory() async {
    final result = await CategorySelectorSheet.show(
      context,
      selectedCategoryId: _formState.selectedCategoryId,
      onAddCategory: () async {
        Navigator.pop(context);
        await AddCategoryDialog.show(context);
        // Re-open category selector after adding
        _selectCategory();
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
    final validation = _formState.validate();
    if (!validation.isValid) {
      _showValidationError(validation);
      return;
    }

    final item = await _formState.toItem();
    await itemsBoxes.addItem(item);

    widget.onItemAdded?.call();

    if (mounted) {
      Navigator.pop(context);
      if (widget.onCategorySelected != null && _formState.selectedCategoryId != null) {
        widget.onCategorySelected!(_formState.selectedCategoryId!);
      }
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
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 40),
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
        );
      },
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Text(
        "Add Item",
        style: TextStyle(
          fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemNameField() {
    return SizedBox(
      height: ResponsiveHelper.responsiveHeight(context, 0.06),
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
      height: ResponsiveHelper.responsiveHeight(context, 0.06),
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
    return CategorySelectorButton(
      selectedCategoryName: _formState.selectedCategoryName,
      onTap: _selectCategory,
    );
  }

  Widget _buildVegSelector() {
    return VegSelectorButton(
      selectedCategory: _formState.vegCategory,
      onTap: _selectVegCategory,
    );
  }

  Widget _buildDescriptionField() {
    return SizedBox(
      height: ResponsiveHelper.responsiveHeight(context, 0.06),
      child: CommonTextForm(
        borderc: 5,
        labelText: 'Description (Optional)',
        controller: _formState.descriptionController,
        obsecureText: false,
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
            height: ResponsiveHelper.responsiveHeight(context, 0.06),
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
                    fontSize: ResponsiveHelper.responsiveTextSize(context, 12),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CommonButton(
            onTap: _saveItem,
            height: ResponsiveHelper.responsiveHeight(context, 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 5),
                const Text("Add Item")
              ],
            ),
          ),
        ),
      ],
    );
  }
}
