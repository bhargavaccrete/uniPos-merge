import 'dart:typed_data';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/restaurant/audit_trail_helper.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/tax_selector_sheet.dart';
// Shared add/edit-item components — kept in sync with the Add Item sheet so both
// screens present the same controls. The SellingMethod enum is the canonical one.
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/add_item_form_state.dart'
    show SellingMethod;
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/widgets/selling_method_selector.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/veg_selector_sheet.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/category_selector_sheet.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/widgets/category_selector_button.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/widgets/tax_selector_button.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/widgets/inventory_toggle.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/image_picker_sheet.dart';
import '../../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../item/default_choice_picker.dart';
import '../../item/variant_selection_screen.dart';
import '../../item/choice_selection_screen.dart';
import '../../item/extra_selection_screen.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../../data/models/restaurant/db/product_type.dart';
import '../../../../../data/models/restaurant/db/recipe_model.dart';
import '../../../../widget/componets/restaurant/recipe_builder_widget.dart';
import '../../../../widget/componets/restaurant/componets/dropdown.dart';

// Helper class to hold all the data needed for the screen
class EditScreenData {
  final List<Category> allCategories;
  final List<VariantModel> allVariants;
  final List<ChoicesModel> allChoices;
  final List<Items> allItems;
  final List<Extramodel> allExtra;
  EditScreenData({
    required this.allCategories,
    required this.allVariants,
    required this.allChoices,
    required this.allItems,
    required this.allExtra,
  });
}

class EdititemScreen extends StatefulWidget {
  final Items items;
  const EdititemScreen({super.key, required this.items});

  @override
  State<EdititemScreen> createState() => _EdititemScreenState();
}

class _EdititemScreenState extends State<EdititemScreen> {
  // --- Controllers and State for the form ---
  late TextEditingController _nameController;
  late TextEditingController _itemPriceController;
  late TextEditingController _descController;
  late TextEditingController _lowStockController;
  late TextEditingController _stockController;
  late TextEditingController _itemCodeController;

  // Focus chain (mirrors the Add Item sheet): name → code → price → description.
  final _nameFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _descFocus = FocusNode();

  late String selectedCategoryId;
  late String selectedIMGCategory;

  // Tax selection — multiple taxes allowed; selectedTaxRate is their summed total.
  List<String> selectedTaxIds = [];
  double? selectedTaxRate;

  Uint8List? _selectedImageBytes;

  // ✅ ADDED: New selling method state
  SellingMethod _sellingMethod = SellingMethod.byUnit;
  String _selectedUnit = 'kg';

  String selectedFilter = 'YES';
  String allowOutOfStockFilter = 'YES';
  String _lowStockAlertFilter = 'NO';
  bool _isSaving = false;
  bool _isEnabled = true;

  // Product Type + Recipe (BOM) — see docs/inventory_recipe_system_plan.md
  String _productType = ProductType.finishedGood;
  // null = follow the product-type default (Raw Material hidden, rest shown).
  bool? _sellDirectlyAtPos;
  RecipeModel? _currentRecipe;

  // Live option catalogs (mutable so options created via "+ New" appear
  // immediately without re-loading and discarding in-progress edits).
  List<VariantModel> _allVariants = [];
  List<ChoicesModel> _allChoices = [];
  List<Extramodel> _allExtra = [];

  // For managing variant selections
  late List<bool> _variantCheckedList;
  // Variants section starts collapsed; auto-expands when the item already has
  // variants selected (set in initState).
  bool _variantsExpanded = false;
  late List<TextEditingController> _variantPriceControllers;
  late List<TextEditingController> _variantStockControllers;

  // For managing choice selections
  late List<bool> _choiceCheckedList;
  bool _choicesExpanded = false;
  // Per-item default-selected choice options (pre-ticked in the POS).
  List<String> _defaultChoiceOptionIds = [];

  late List<bool> _extraCheckedList;
  bool _extrasExpanded = false;
  Map<String, Map<String, TextEditingController>> _extraConstraintControllers =
      {}; // extraId -> {min, max}
  Map<String, bool> _extraHasConstraints =
      {}; // Track if extra has min/max enabled

  // This Future will safely load all data before building the UI
  late Future<EditScreenData> _loadDataFuture;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.items.name);
    _itemPriceController = TextEditingController(
      text: widget.items.price?.toString() ?? '',
    );
    _descController = TextEditingController(
      text: widget.items.description ?? '',
    );
    _itemCodeController = TextEditingController(
      text: widget.items.itemCode ?? '',
    );
    final stock = widget.items.stockQuantity;
    _stockController = TextEditingController(
      text: stock == 0
          ? ''
          : (stock % 1 == 0 ? stock.toStringAsFixed(0) : stock.toString()),
    );
    final lowStock = widget.items.lowStockThreshold;
    _lowStockController = TextEditingController(
      text: lowStock == null
          ? ''
          : (lowStock % 1 == 0
                ? lowStock.toStringAsFixed(0)
                : lowStock.toString()),
    );
    _lowStockAlertFilter = widget.items.lowStockAlertEnabled ? 'YES' : 'NO';
    selectedCategoryId = widget.items.categoryOfItem ?? '';
    selectedIMGCategory = widget.items.isVeg ?? 'Veg';
    selectedTaxRate = widget.items.taxRate;
    selectedTaxIds = List<String>.from(widget.items.taxIds ?? const []);

    // ✅ ADDED: Initialize selling method based on existing item
    _sellingMethod = widget.items.isSoldByWeight == true
        ? SellingMethod.byWeight
        : SellingMethod.byUnit;
    // Clamp to a supported value (kItemUnits); imported/legacy items may carry
    // an unsupported unit, which would crash the DropdownButton.
    _selectedUnit = normalizeItemUnit(widget.items.unit) ?? kItemUnits.first;

    selectedFilter = widget.items.trackInventory == true ? 'YES' : 'NO';
    allowOutOfStockFilter = widget.items.allowOrderWhenOutOfStock == true
        ? 'YES'
        : 'NO';

    _isEnabled = widget.items.isEnabled;
    _productType = widget.items.effectiveProductType;
    _sellDirectlyAtPos = widget.items.sellDirectlyAtPos;
    _currentRecipe = recipeRepository.getRecipeForItem(widget.items.id);

    _loadDataFuture = _loadInitialData();
  }
  // In _EdititemScreenState

  Future<EditScreenData> _loadInitialData() async {
    // Load data from stores
    final allCategories = categoryStore.categories.toList();
    final allVariants = variantStore.variants.toList();
    final allChoices = choiceStore.choices.toList();
    final allExtra = extraStore.extras.toList();
    final allItems = itemStore.items.toList();

    // Mirror into mutable state so "+ New" can grow these lists in place.
    _allVariants = allVariants;
    _allChoices = allChoices;
    _allExtra = allExtra;

    // The rest of the function remains the same, as it correctly
    // pre-selects the variants and choices.

    _variantCheckedList = List.generate(allVariants.length, (index) {
      return widget.items.variant?.any(
            (v) => v.variantId == allVariants[index].id,
          ) ??
          false;
    });
    // Open the Variants section automatically if any are already selected.
    _variantsExpanded = _variantCheckedList.contains(true);

    _variantPriceControllers = List.generate(allVariants.length, (index) {
      final existingVariant = widget.items.variant?.firstWhere(
        (v) => v.variantId == allVariants[index].id,
        orElse: () => ItemVariante(variantId: '', price: 0.0),
      );
      return TextEditingController(
        text: existingVariant?.price.toString() ?? '',
      );
    });

    _variantStockControllers = List.generate(allVariants.length, (index) {
      final existingVariant = widget.items.variant?.firstWhere(
        (v) => v.variantId == allVariants[index].id,
        orElse: () => ItemVariante(variantId: '', price: 0.0),
      );
      final s = existingVariant?.stockQuantity;
      return TextEditingController(
        text: (s == null || s == 0)
            ? ''
            : (s % 1 == 0 ? s.toInt().toString() : s.toString()),
      );
    });

    _choiceCheckedList = List.generate(allChoices.length, (index) {
      return widget.items.choiceIds?.contains(allChoices[index].id) ?? false;
    });
    _choicesExpanded = _choiceCheckedList.contains(true);
    _defaultChoiceOptionIds = List<String>.from(
      widget.items.defaultChoiceOptionIds ?? const [],
    );

    _extraCheckedList = List.generate(allExtra.length, (index) {
      return widget.items.extraId?.contains(allExtra[index].Id) ?? false;
    });
    _extrasExpanded = _extraCheckedList.contains(true);

    // Initialize min/max controllers for extras.
    // Per-item constraints take priority; global extra defaults pre-fill when no override exists.
    for (var extra in allExtra) {
      final constraints = widget.items.extraConstraints?[extra.Id];
      final globalMin = extra.minimum;
      final globalMax = extra.maximum;
      final hasConstraints = constraints != null
          ? (constraints['min'] != 0 || constraints['max'] != 0)
          : (globalMin != null && globalMin != 0) ||
                (globalMax != null && globalMax != 0);

      _extraHasConstraints[extra.Id] = hasConstraints;
      _extraConstraintControllers[extra.Id] = {
        'min': TextEditingController(
          text:
              constraints?['min']?.toString() ??
              (globalMin != null && globalMin != 0 ? globalMin.toString() : ''),
        ),
        'max': TextEditingController(
          text:
              constraints?['max']?.toString() ??
              (globalMax != null && globalMax != 0 ? globalMax.toString() : ''),
        ),
      };
    }

    return EditScreenData(
      allCategories: allCategories,
      allVariants: allVariants,
      allChoices: allChoices,
      allExtra: allExtra,
      allItems: allItems,
    );
  }

  @override
  void dispose() {
    // Dispose basic controllers
    _nameController.dispose();
    _itemPriceController.dispose();
    _descController.dispose();
    _lowStockController.dispose();
    _stockController.dispose();
    _itemCodeController.dispose();
    _nameFocus.dispose();
    _codeFocus.dispose();
    _priceFocus.dispose();
    _descFocus.dispose();

    // Dispose variant price controllers
    for (var controller in _variantStockControllers) {
      controller.dispose();
    }
    for (var controller in _variantPriceControllers) {
      controller.dispose();
    }

    // Dispose extra constraint controllers
    for (var controllerMap in _extraConstraintControllers.values) {
      controllerMap['min']?.dispose();
      controllerMap['max']?.dispose();
    }

    super.dispose();
  }

  void _saveChanges(EditScreenData data) async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Item name cannot be empty');
      return;
    }

    final itemCode = _itemCodeController.text.trim();
    if (itemCode.isEmpty) {
      NotificationService.instance.showError('Item code cannot be empty');
      return;
    }
    if (!RegExp(r'^\d{4,5}$').hasMatch(itemCode)) {
      NotificationService.instance.showError('Item code must be 4-5 digits');
      return;
    }
    final duplicateCode = itemStore.items.any(
      (i) => i.itemCode == itemCode && i.id != widget.items.id,
    );
    if (duplicateCode) {
      NotificationService.instance.showError(
        'Item code already exists. Please enter a different code.',
      );
      return;
    }

    // Menu-facing types (Finished Good, Recipe-Based) need a selling price and
    // a category — matches Add Item's validate(). Raw Material/Semi-Finished
    // stay optional, as today.
    if (ProductType.isMenuType(_productType)) {
      final priceValue = double.tryParse(_itemPriceController.text.trim());
      if (priceValue == null || priceValue <= 0) {
        NotificationService.instance.showError(
          'Please enter a valid selling price',
        );
        return;
      }
      if (selectedCategoryId.isEmpty) {
        NotificationService.instance.showError('Please select a category');
        return;
      }
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Handle image: keep existing imageBytes or use newly selected imageBytes
      Uint8List? finalImageBytes = widget.items.imageBytes;

      // Use the bytes that were already read when picking the image
      if (_selectedImageBytes != null) {
        finalImageBytes = _selectedImageBytes;
      }

      // Variant stock changes to log as adjustments after the item is saved.
      final pendingAdjustments = <Map<String, dynamic>>[];
      Map<String, dynamic>? pendingSimpleAdjustment;
      List<ItemVariante> selectedVariants = [];
      final isRawOrSemi =
          _productType == ProductType.rawMaterial ||
          _productType == ProductType.semiFinished;
      if (!isRawOrSemi) {
        for (int i = 0; i < _allVariants.length; i++) {
          if (_variantCheckedList[i]) {
            final priceText = _variantPriceControllers[i].text.trim();
            final variantId = _allVariants[i].id;

            // ✅ FIX: Preserve existing stock quantities when editing
            // Find the existing variant with this variantId to preserve stock data
            final existingVariant = widget.items.variant?.firstWhere(
              (v) => v.variantId == variantId,
              orElse: () => ItemVariante(
                variantId: variantId,
                price: 0.0,
                trackInventory: null,
                stockQuantity: null,
              ),
            );

            // When inventory tracking is on, take the edited per-variant stock;
            // otherwise keep whatever was there.
            final newStock = selectedFilter.toLowerCase() == 'yes'
                ? (double.tryParse(_variantStockControllers[i].text.trim()) ??
                      existingVariant?.stockQuantity ??
                      0.0)
                : existingVariant?.stockQuantity;

            // Log an adjustment if a tracked variant's stock actually changed.
            if (selectedFilter.toLowerCase() == 'yes' && newStock != null) {
              final oldStock = existingVariant?.stockQuantity ?? 0.0;
              if (newStock != oldStock) {
                pendingAdjustments.add({
                  'variantId': variantId,
                  'old': oldStock,
                  'new': newStock,
                });
              }
            }

            selectedVariants.add(
              ItemVariante(
                variantId: variantId,
                price: double.tryParse(priceText) ?? 0.0,
                trackInventory: existingVariant?.trackInventory,
                stockQuantity: newStock,
              ),
            );
          }
        }
      }

      List<String> selectedChoiceIds = [];
      for (int i = 0; i < _allChoices.length; i++) {
        if (_choiceCheckedList[i]) {
          selectedChoiceIds.add(_allChoices[i].id);
        }
      }

      List<String> selectedExtraId = [];
      for (int i = 0; i < _allExtra.length; i++) {
        if (_extraCheckedList[i]) {
          selectedExtraId.add(_allExtra[i].Id);
        }
      }

      // Build extra constraints map from controllers
      Map<String, Map<String, int>> extraConstraints = {};
      for (int i = 0; i < _allExtra.length; i++) {
        if (_extraCheckedList[i]) {
          final extraId = _allExtra[i].Id;
          final minText =
              _extraConstraintControllers[extraId]?['min']?.text.trim() ?? '';
          final maxText =
              _extraConstraintControllers[extraId]?['max']?.text.trim() ?? '';

          final minValue = int.tryParse(minText) ?? 0;
          final maxValue = int.tryParse(maxText) ?? 0;

          extraConstraints[extraId] = {'min': minValue, 'max': maxValue};
        }
      }

      final updateItem = widget.items.copyWith(
        name: trimmedName,
        price: double.tryParse(_itemPriceController.text.trim()),
        // Raw Material only: also seed lastPurchaseCost from the same Cost
        // Price input, since that's what recipe costing actually reads (B1).
        lastPurchaseCost: ProductType.seededLastPurchaseCost(
          _productType,
          double.tryParse(_itemPriceController.text.trim()),
        ),
        description: _descController.text.trim(),
        isVeg: selectedIMGCategory,
        categoryOfItem: selectedCategoryId,
        imageBytes: finalImageBytes,
        variant: selectedVariants,
        choiceIds: selectedChoiceIds,
        defaultChoiceOptionIds: _defaultChoiceOptionIds,
        extraId: selectedExtraId,
        extraConstraints: extraConstraints.isNotEmpty ? extraConstraints : null,
        allowOrderWhenOutOfStock: allowOutOfStockFilter.toLowerCase() == 'yes',
        isSoldByWeight: _sellingMethod == SellingMethod.byWeight,
        // Raw Material/Semi-Finished: a stock-keeping unit, independent of
        // Selling Method (a POS-sale concept that doesn't apply to them), so
        // it's always persisted. Finished Good/Recipe-Based keep the original
        // by-weight-only condition, unchanged.
        unit:
            (_productType == ProductType.rawMaterial ||
                _productType == ProductType.semiFinished)
            ? _selectedUnit
            : (_sellingMethod == SellingMethod.byWeight ? _selectedUnit : null),
        itemCode: itemCode,
        productType: _productType,
        isEnabled: _isEnabled,
      );

      // Set tax directly (not via copyWith) so selecting "No Tax" (null) actually
      // clears it — copyWith's `?? this.taxRate` would otherwise keep the old rate.
      updateItem.taxRate = selectedTaxRate;
      updateItem.taxIds = selectedTaxIds;

      // recipeId: same "can't clear via copyWith" issue as taxRate above — set
      // directly so switching away from a recipe-having type actually detaches it.
      updateItem.recipeId = ProductType.hasRecipe(_productType)
          ? _currentRecipe?.id
          : null;

      // sellDirectlyAtPos: same direct-set reason. Only Raw Materials and Semi-Finished carry an
      // override; switching to any other type clears it back to null so the item
      // follows that type's default.
      updateItem.sellDirectlyAtPos =
          (_productType == ProductType.rawMaterial ||
              _productType == ProductType.semiFinished)
          ? _sellDirectlyAtPos
          : null;

      // Low-stock alert (only meaningful when inventory tracking is on).
      // Set directly so turning tracking/alert off clears the override.
      final lowStockOn =
          selectedFilter.toLowerCase() == 'yes' &&
          _lowStockAlertFilter == 'YES';
      updateItem.lowStockAlertEnabled = lowStockOn;
      updateItem.lowStockThreshold = lowStockOn
          ? double.tryParse(_lowStockController.text.trim())
          : null;

      // Item-level stock for SIMPLE items (no variants). Variant items keep the
      // item-level quantity at 0 and track stock per-variant instead.
      final requestedStockQuantity = !_variantCheckedList.contains(true)
          ? (selectedFilter.toLowerCase() == 'yes'
                ? (double.tryParse(_stockController.text.trim()) ?? 0.0)
                : 0.0)
          : 0.0;
      // Recipe-Based items derive availability from their recipe and must never
      // carry over stale tracking/quantity from before a type switch — see
      // ProductType.resolvePhysicalStock. Every other type passes through
      // unchanged.
      final physicalStock = ProductType.resolvePhysicalStock(
        _productType,
        requestedTrackInventory: selectedFilter.toLowerCase() == 'yes',
        requestedStockQuantity: requestedStockQuantity,
      );
      updateItem.trackInventory = physicalStock.trackInventory;
      if (!_variantCheckedList.contains(true)) {
        final oldStock = widget.items.stockQuantity;
        updateItem.stockQuantity = physicalStock.stockQuantity;
        // Log an adjustment if a tracked item's stock actually changed.
        if (physicalStock.trackInventory &&
            physicalStock.stockQuantity != oldStock) {
          pendingSimpleAdjustment = {
            'old': oldStock,
            'new': physicalStock.stockQuantity,
          };
        }
      } else if (ProductType.isStockDerived(_productType)) {
        // A variant-having item switched to Recipe-Based must not retain stale
        // item-level stock either, even though variants normally govern it.
        updateItem.stockQuantity = 0.0;
      }

      AuditTrailHelper.trackEdit(
        updateItem,
        editedBy:
            RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
      );

      await itemStore.updateItem(updateItem);

      // Persist (or drop) the recipe alongside the item — see design doc §4.
      if (ProductType.hasRecipe(_productType) && _currentRecipe != null) {
        await recipeRepository.saveRecipe(
          _currentRecipe!.copyWith(itemId: updateItem.id),
        );
      } else {
        await recipeRepository.deleteRecipeForItem(updateItem.id);
      }

      // Log any variant stock changes so the history & running balance stay honest.
      for (final adj in pendingAdjustments) {
        await StockAdjustService.logAdjustment(
          item: updateItem,
          variantId: adj['variantId'] as String,
          oldStock: adj['old'] as double,
          newStock: adj['new'] as double,
        );
      }

      // Same for a simple (non-variant) item whose stock was edited.
      if (pendingSimpleAdjustment != null) {
        await StockAdjustService.logAdjustment(
          item: updateItem,
          oldStock: pendingSimpleAdjustment['old'] as double,
          newStock: pendingSimpleAdjustment['new'] as double,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Edit Item',
        titleFontSize: AppResponsive.subheadingFontSize(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<EditScreenData>(
        future: _loadDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            return _buildForm(snapshot.data!);
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }

  // Helper method for section headers (matching setup screen style)
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: AppResponsive.iconSize(context),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // This method now contains your full UI with improved structure
  Widget _buildForm(EditScreenData data) {
    // Category name is read live from the store so a rename/delete inside the
    // picker reflects immediately (null → the button shows "Select Category").
    final match = categoryStore.categories
        .where((c) => c.id == selectedCategoryId)
        .toList();
    final selectedCategoryName = match.isEmpty ? null : match.first.name;

    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      // Form width cap — a single-column form stretched to a 1400px desktop is
      // unreadable. heightFactor: 1 is required inside a scroll view, or the
      // Align tries to take infinite height.
      child: AppResponsive.constrainedContent(
        context: context,
        maxWidth: AppResponsive.maxFormWidth(context),
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionHeader('Basic Information', Icons.info_outline),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            AppTextField(
              controller: _nameController,
              focusNode: _nameFocus,
              label: 'Item Name',
              icon: Icons.fastfood_outlined,
              required: true,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _codeFocus.requestFocus(),
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            AppTextField(
              controller: _itemCodeController,
              focusNode: _codeFocus,
              label: 'Item Code',
              icon: Icons.qr_code_scanner_rounded,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _priceFocus.requestFocus(),
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Active / Enabled',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Turn off to temporarily hide this item from POS and listings.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              value: _isEnabled,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _isEnabled = v),
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Selling Method Section — Raw Material/Semi-Finished get a plain
            // Stock Unit picker instead (they aren't sold, so Selling Method
            // doesn't apply).
            if (_productType == ProductType.rawMaterial ||
                _productType == ProductType.semiFinished) ...[
              _buildSectionHeader('Stock Unit', Icons.straighten_outlined),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              SellingMethodButton(
                method: _sellingMethod,
                unit: _selectedUnit,
                unitOnly: true,
                onTap: _selectStockUnit,
              ),
            ] else ...[
              _buildSectionHeader('Selling Method', Icons.scale),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              SellingMethodButton(
                method: _sellingMethod,
                unit: _selectedUnit,
                onTap: _selectSellingMethod,
              ),
            ],
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Price
            AppTextField(
              controller: _itemPriceController,
              focusNode: _priceFocus,
              label: 'Price',
              prefixWidget: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Text(
                  CurrencyHelper.currentSymbol,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _descFocus.requestFocus(),
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Category Section
            _buildSectionHeader('Category', Icons.category_outlined),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            CategorySelectorButton(
              selectedCategoryName: selectedCategoryName,
              onTap: _selectCategory,
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Product Type — determines whether this item is stocked directly,
            // made from a recipe, or both. See docs/inventory_recipe_system_plan.md §3/§8.1.
            if (PlanEnforce.allows(EntKeys.inventory)) ...[
              _buildSectionHeader('Product Type', Icons.category_rounded),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              Dropdown(
                items: ProductType.all.map(ProductType.displayName).toList(),
                selectedItem: ProductType.displayName(_productType),
                onChanged: (label) {
                  final type = ProductType.all.firstWhere(
                    (t) => ProductType.displayName(t) == label,
                    orElse: () => ProductType.finishedGood,
                  );
                  setState(() {
                    _productType = type;
                    // Switching away from a recipe type drops the in-progress
                    // recipe rather than silently keeping stale ingredients.
                    if (!ProductType.hasRecipe(type)) _currentRecipe = null;
                    // Recipe-Based is always stock-governed via its ingredients —
                    // same "enforce limits by default" policy as enabling
                    // inventory tracking above, so Add and Edit agree.
                    if (type == ProductType.recipeBased) {
                      allowOutOfStockFilter = 'NO';
                    }
                  });
                },
              ),
            ],
            // Raw Materials / Semi-Finished are ingredients/prep items, so they stay out of
            // the POS sale grid unless explicitly opted in.
            if (_productType == ProductType.rawMaterial ||
                _productType == ProductType.semiFinished) ...[
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  _productType == ProductType.rawMaterial
                      ? 'Sell directly at POS'
                      : 'Show on POS Menu',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _productType == ProductType.rawMaterial
                      ? 'Raw materials are hidden from the menu by default. Turn on to sell this one as-is.'
                      : 'Semi-finished prep items are hidden from the menu by default. Turn on to show and sell this one.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _sellDirectlyAtPos ?? false,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _sellDirectlyAtPos = v),
              ),
            ],
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Tax Section
            if (TaxFeature.enabled) ...[
              _buildSectionHeader('Tax', Icons.percent_rounded),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              TaxSelectorButton(taxRate: selectedTaxRate, onTap: _selectTax),
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            ],

            // Food Type (Veg / Non-Veg)
            _buildSectionHeader('Food Type', Icons.eco_outlined),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            VegSelectorButton(
              selectedCategory: selectedIMGCategory,
              onTap: _selectVeg,
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Description
            AppTextField(
              controller: _descController,
              focusNode: _descFocus,
              label: 'Description',
              hint: 'Optional',
              icon: Icons.notes_outlined,
              maxLines: 3,
              minLines: 1,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Inventory Management — stock module. InventoryToggle hides itself
            // when the plan excludes `inventory`, so guard the header/fields to match.
            // Recipe-Based items have no stock of their own — their availability is
            // derived live from the recipe's ingredients (§7 of the design doc), so
            // this whole module is replaced by an "Available to Make" readout below.
            if (PlanEnforce.allows(EntKeys.inventory) &&
                _productType != ProductType.recipeBased) ...[
              _buildSectionHeader(
                'Inventory Management',
                Icons.inventory_2_outlined,
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              InventoryToggle(
                trackInventory: selectedFilter.toLowerCase() == 'yes',
                allowOrderWhenOutOfStock:
                    allowOutOfStockFilter.toLowerCase() == 'yes',
                onTrackInventoryChanged: (v) => setState(() {
                  selectedFilter = v ? 'YES' : 'NO';
                  // Enforce stock limits by default when enabling tracking.
                  if (v) allowOutOfStockFilter = 'NO';
                }),
                onAllowOutOfStockChanged: (v) =>
                    setState(() => allowOutOfStockFilter = v ? 'YES' : 'NO'),
              ),
              if (selectedFilter.toLowerCase() == 'yes') ...[
                // Current Stock — only for SIMPLE items. Variant items track stock
                // per-variant in the Variants section below.
                if (!_variantCheckedList.contains(true)) ...[
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _buildCurrentStockField(),
                ] else ...[
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Text(
                    'Stock is set per variant below.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildLowStockSection(),
              ],
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            ],
            if (_productType == ProductType.recipeBased) ...[
              _buildSectionHeader('Availability', Icons.inventory_2_outlined),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              _buildAvailableToMakeCard(),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              // No physical stock for Recipe-Based — this only controls whether
              // POS may sell when the calculated available-to-make figure is
              // zero, exactly as InventoryService already enforces.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Allow order if out of stock',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Let staff sell this even when no ingredients remain to make it.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
                value: allowOutOfStockFilter.toLowerCase() == 'yes',
                activeColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => allowOutOfStockFilter = v ? 'YES' : 'NO'),
              ),
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            ],

            // Recipe (Bill of Materials) — Semi-Finished items describe what
            // they're prepped FROM; Recipe-Based items describe what they're
            // assembled FROM at sale time. See design doc §3/§4/§8.2.
            if (PlanEnforce.allows(EntKeys.inventory) &&
                ProductType.hasRecipe(_productType)) ...[
              RecipeBuilderWidget(
                itemId: widget.items.id,
                allItems: itemStore.items
                    .where((i) => i.id != widget.items.id)
                    .toList(),
                initialRecipe: _currentRecipe,
                sellingPrice: double.tryParse(_itemPriceController.text.trim()),
                onChanged: (recipe) => setState(() => _currentRecipe = recipe),
              ),
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            ],

            // Item Image Section
            _buildSectionHeader('Item Image', Icons.image_outlined),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            ImageUploader(imageBytes: _displayImageBytes, onTap: _pickImage),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),

            // Variants, Choices & Extras Section — always shown so new options can
            // be created here (via the "+ New" button in each section header).
            _buildSectionHeader('Additional Options', Icons.extension),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            if (_productType != ProductType.rawMaterial &&
                _productType != ProductType.semiFinished) ...[
              _buildVariantSection(_allVariants),
            ],
            _buildChoiceSection(_allChoices),
            if (_choiceCheckedList.contains(true))
              _buildDefaultSelectionButton(_allChoices),
            _buildExtrtaSection(_allExtra),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            // Save Button
            SizedBox(
              width: double.infinity,
              height: AppResponsive.buttonHeight(context),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveChanges(data),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSaving ? 'Saving…' : 'Save Changes',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
          ],
        ),
      ),
    );
  }
  // ── Selectors (open the shared sheets, mirroring the Add Item sheet) ────────

  Future<void> _selectSellingMethod() async {
    FocusScope.of(context).unfocus();
    final result = await SellingMethodSheet.show(
      context,
      currentMethod: _sellingMethod,
      currentUnit: _selectedUnit,
    );
    if (result != null) {
      setState(() {
        _sellingMethod = result.method;
        _selectedUnit = result.unit;
      });
    }
  }

  /// Raw Material/Semi-Finished's stock-keeping unit — independent of
  /// Selling Method, which stays a pure POS-sale concept for menu types.
  Future<void> _selectStockUnit() async {
    FocusScope.of(context).unfocus();
    final result = await SellingMethodSheet.show(
      context,
      currentMethod: _sellingMethod,
      currentUnit: _selectedUnit,
      unitOnly: true,
    );
    if (result != null) {
      setState(() => _selectedUnit = result.unit);
    }
  }

  Future<void> _selectVeg() async {
    FocusScope.of(context).unfocus();
    final result = await VegSelectorSheet.show(
      context,
      currentSelection: selectedIMGCategory,
    );
    if (result != null) setState(() => selectedIMGCategory = result);
  }

  Future<void> _selectTax() async {
    FocusScope.of(context).unfocus();
    final result = await TaxSelectorSheet.show(
      context,
      selectedTaxIds: selectedTaxIds,
    );
    if (result != null) {
      setState(() {
        selectedTaxIds = result.ids;
        selectedTaxRate = result.rate == 0 ? null : result.rate;
      });
    }
  }

  Future<void> _selectCategory() async {
    FocusScope.of(context).unfocus();
    final result = await CategorySelectorSheet.show(
      context,
      selectedCategoryId: selectedCategoryId.isEmpty
          ? null
          : selectedCategoryId,
      onAddCategory: () async {
        Navigator.pop(context);
        final wasAdded = await AddCategoryDialog.show(context);
        if (wasAdded) _selectCategory();
      },
    );
    if (result != null) {
      setState(() => selectedCategoryId = result.id);
    } else if (selectedCategoryId.isNotEmpty &&
        !categoryStore.categories.any((c) => c.id == selectedCategoryId)) {
      // The selected category may have been deleted from inside the picker.
      setState(() => selectedCategoryId = '');
    }
  }

  // ── Image ───────────────────────────────────────────────────────────────────

  /// Bytes to preview: the freshly-picked image, else the item's existing image.
  Uint8List? get _displayImageBytes {
    if (_selectedImageBytes != null) return _selectedImageBytes;
    final existing = widget.items.imageBytes;
    return (existing != null && existing.isNotEmpty) ? existing : null;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // 3 MB cap — matches the Add Item sheet (was 2 MB here).
    if (bytes.length > 3 * 1024 * 1024) {
      NotificationService.instance.showError(
        'Image size must be less than 3MB. Please choose a smaller image.',
      );
      return;
    }
    if (mounted) setState(() => _selectedImageBytes = bytes);
  }

  // ── Inventory sub-fields (mirror the Add Item sheet) ────────────────────────

  /// The unit to show next to a stock quantity field. Raw Material/
  /// Semi-Finished always use their Stock Unit (independent of Selling
  /// Method, which they don't show); Finished Good/Recipe-Based keep the
  /// original by-weight-only condition, unchanged.
  String _unitLabel() {
    final isBackOfHouse =
        _productType == ProductType.rawMaterial ||
        _productType == ProductType.semiFinished;
    if (isBackOfHouse) return _selectedUnit;
    return _sellingMethod == SellingMethod.byWeight ? _selectedUnit : 'pcs';
  }

  Widget _buildCurrentStockField() {
    final unit = _unitLabel();
    return AppTextField(
      controller: _stockController,
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
          title: Text(
            'Low-stock alert',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'Warn when this item runs low',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          value: _lowStockAlertFilter == 'YES',
          activeColor: AppColors.primary,
          onChanged: (v) =>
              setState(() => _lowStockAlertFilter = v ? 'YES' : 'NO'),
        ),
        if (_lowStockAlertFilter == 'YES') ...[
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Builder(
            builder: (_) {
              final unit = _unitLabel();
              return AppTextField(
                controller: _lowStockController,
                label: 'Alert threshold ($unit, optional)',
                hint:
                    'Default: ${AppSettings.lowStockThreshold.toStringAsFixed(0)} $unit',
                icon: Icons.warning_amber_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              );
            },
          ),
        ],
      ],
    );
  }

  /// Live "N can be made" readout for a Recipe-Based item, computed from the
  /// IN-PROGRESS [_currentRecipe] (not the last-saved one) against current
  /// ingredient stock — updates as the user edits the recipe below, before
  /// saving. Mirrors InventoryService.calculateAvailableToMake's formula.
  /// See docs/inventory_recipe_system_plan.md §7.
  Widget _buildAvailableToMakeCard() {
    final recipe = _currentRecipe;
    double? available;
    if (recipe != null && recipe.hasIngredients) {
      double? minBatches;
      for (final line in recipe.ingredients) {
        if (line.effectiveQuantity <= 0) continue;
        Items? ingredient;
        try {
          ingredient = itemStore.items.firstWhere(
            (i) => i.id == line.ingredientItemId,
          );
        } catch (_) {
          minBatches = 0;
          break;
        }
        if (!ingredient.trackInventory) continue;
        final batches = ingredient.stockQuantity / line.effectiveQuantity;
        minBatches = minBatches == null
            ? batches
            : (batches < minBatches ? batches : minBatches);
      }
      final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
      available = minBatches == null
          ? double.infinity
          : (minBatches * yieldQty).floorToDouble();
    }

    final color = available == null
        ? AppColors.textSecondary
        : available <= 0
        ? AppColors.danger
        : available <= 5
        ? Colors.orange
        : AppColors.success;

    return Container(
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            color: color,
            size: AppResponsive.iconSize(context),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available == null
                      ? 'Add ingredients below to see availability'
                      : available == double.infinity
                      ? 'Unlimited (no tracked ingredients)'
                      : '${available.toStringAsFixed(0)} can be made right now',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stock is derived from the recipe\'s ingredients — selling this item deducts them, not a stock count of its own.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Small "+ New" action shown in each option section header.
  Widget _addNewButton(VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add, size: AppResponsive.smallIconSize(context)),
      label: Text(
        'New',
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // "+ New" opens the SAME create dialog used in the Add-Item flow (no full-page
  // navigation). After a new option is created in its store, the matching list
  // is rebuilt: existing rows keep their controllers/selection (no lost edits),
  // newly-created options are appended and auto-ticked.
  Future<void> _addNewVariants() async {
    await showAddVariantDialog(context, onAdded: _refreshVariants);
  }

  void _refreshVariants() {
    final old = _allVariants;
    final fresh = variantStore.variants.toList();
    final checked = <bool>[];
    final prices = <TextEditingController>[];
    final stocks = <TextEditingController>[];
    for (final v in fresh) {
      final i = old.indexWhere((o) => o.id == v.id);
      if (i != -1) {
        checked.add(_variantCheckedList[i]);
        prices.add(_variantPriceControllers[i]);
        stocks.add(_variantStockControllers[i]);
      } else {
        checked.add(true); // newly created → auto-tick
        prices.add(TextEditingController());
        stocks.add(TextEditingController());
      }
    }
    setState(() {
      _allVariants = fresh;
      _variantCheckedList = checked;
      _variantPriceControllers = prices;
      _variantStockControllers = stocks;
      // Reveal the list so the newly added (auto-ticked) variant is visible.
      _variantsExpanded = true;
    });
  }

  Future<void> _addNewChoices() async {
    await showAddChoiceDialog(context, onAdded: _refreshChoices);
  }

  void _refreshChoices() {
    final old = _allChoices;
    final fresh = choiceStore.choices.toList();
    final checked = <bool>[];
    for (final c in fresh) {
      final i = old.indexWhere((o) => o.id == c.id);
      checked.add(i != -1 ? _choiceCheckedList[i] : true);
    }
    setState(() {
      _allChoices = fresh;
      _choiceCheckedList = checked;
      _choicesExpanded = true;
    });
  }

  Future<void> _addNewExtras() async {
    await showAddExtraDialog(context, onAdded: _refreshExtras);
  }

  void _refreshExtras() {
    final old = _allExtra;
    final fresh = extraStore.extras.toList();
    final checked = <bool>[];
    for (final e in fresh) {
      final i = old.indexWhere((o) => o.Id == e.Id);
      checked.add(i != -1 ? _extraCheckedList[i] : true);
      // Ensure every extra has min/max constraint controllers (new ones fresh).
      _extraConstraintControllers.putIfAbsent(e.Id, () {
        final gMin = e.minimum, gMax = e.maximum;
        return {
          'min': TextEditingController(
            text: (gMin != null && gMin != 0) ? gMin.toString() : '',
          ),
          'max': TextEditingController(
            text: (gMax != null && gMax != 0) ? gMax.toString() : '',
          ),
        };
      });
      _extraHasConstraints.putIfAbsent(
        e.Id,
        () =>
            (e.minimum != null && e.minimum != 0) ||
            (e.maximum != null && e.maximum != 0),
      );
    }
    setState(() {
      _allExtra = fresh;
      _extraCheckedList = checked;
      _extrasExpanded = true;
    });
  }

  // Helper widget for building the variants section
  Widget _buildVariantSection(List<VariantModel> variants) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _variantsExpanded = !_variantsExpanded),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune,
                            color: AppColors.primary,
                            size: AppResponsive.iconSize(context),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Text(
                            'Variants',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _variantsExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
                              size: AppResponsive.iconSize(context),
                            ),
                          ),
                          if (!_variantsExpanded &&
                              _variantCheckedList.contains(true)) ...[
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Text(
                              '${_variantCheckedList.where((c) => c).length} selected',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _addNewButton(_addNewVariants),
              ],
            ),
            if (_variantsExpanded) ...[
              const Divider(),
              if (variants.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.smallSpacing(context),
                  ),
                  child: Text(
                    'No variants yet. Tap "New" to add one.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              // Bucket on the MEASURED row width, not the screen width: the
              // page cap, page padding and card padding all shrink what a row
              // actually gets (a 360px phone leaves this ListView ~296px).
              // Resolve once here and pass it to every row.
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < _variantRowStackBelow;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: variants.length,
                    itemBuilder: (context, index) => _buildVariantRow(
                      variants[index],
                      index,
                      stacked: stacked,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Below this row width the variant fields move to a second line. Derived
  /// from the single-row layout: a 48px checkbox plus two 8px gaps leaves
  /// (w - 64) / 3 per column, and AppTextField's static 16px content padding
  /// eats 32 of that — so under ~400px the price/stock boxes fall below ~70px
  /// of usable typing width and the name ellipsises to a couple of letters.
  static const double _variantRowStackBelow = 400;

  /// One variant row. When [stacked], the name gets its own line and the
  /// price/stock fields sit indented beneath it; otherwise all three share a
  /// single row. Which fields appear is identical either way.
  Widget _buildVariantRow(
    VariantModel variant,
    int index, {
    required bool stacked,
  }) {
    final trackOn = selectedFilter.toLowerCase() == 'yes';
    // Per-variant stock — only when inventory tracking is on.
    final showStock = trackOn && _variantCheckedList[index];
    final gap = SizedBox(width: AppResponsive.smallSpacing(context));

    final checkbox = Checkbox(
      value: _variantCheckedList[index],
      onChanged: (value) => setState(() => _variantCheckedList[index] = value!),
    );

    final name = Text(
      variant.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: AppColors.textPrimary,
      ),
    );

    final priceField = AppTextField(
      controller: _variantPriceControllers[index],
      hint: 'Price',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
    );

    final stockField = AppTextField(
      controller: _variantStockControllers[index],
      hint: 'Stock',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
    );

    if (!stacked) {
      // Flex-based layout so name/price/stock share the row width and scale on
      // any screen — fixed-width fields used to squeeze the name column to
      // nothing (e.g. "Half" wrapped to "Ha"/"lf").
      return Row(
        children: [
          checkbox,
          Expanded(flex: 3, child: name),
          gap,
          Expanded(flex: 3, child: priceField),
          if (showStock) ...[gap, Expanded(flex: 3, child: stockField)],
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              checkbox,
              Expanded(child: name),
            ],
          ),
          Padding(
            // 48 = the Checkbox's tap-target width, so the fields line up under
            // the variant name rather than under the checkbox.
            padding: const EdgeInsets.only(left: 48),
            child: Row(
              children: [
                Expanded(child: priceField),
                if (showStock) ...[gap, Expanded(child: stockField)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tappable card to set this item's default-selected choice options.
  Widget _buildDefaultSelectionButton(List<ChoicesModel> allChoices) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickItemDefaults(allChoices),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        child: Container(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.task_alt_outlined,
                color: AppColors.primary,
                size: AppResponsive.iconSize(context),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Selection',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Pre-tick choice options for this item',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_defaultChoiceOptionIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                  ),
                  child: Text(
                    '${_defaultChoiceOptionIds.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: AppResponsive.smallFontSize(context),
                    ),
                  ),
                ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Icon(
                Icons.arrow_forward_ios,
                size: AppResponsive.smallIconSize(context),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickItemDefaults(List<ChoicesModel> allChoices) async {
    // Choice groups currently ticked for this item.
    final selectedChoiceIds = <String>[];
    for (int i = 0; i < allChoices.length; i++) {
      if (i < _choiceCheckedList.length && _choiceCheckedList[i]) {
        selectedChoiceIds.add(allChoices[i].id);
      }
    }
    final result = await showDefaultChoicePicker(
      context,
      selectedChoiceIds,
      _defaultChoiceOptionIds,
    );
    if (result != null && mounted) {
      setState(() => _defaultChoiceOptionIds = result);
    }
  }

  // Helper widget for building the choices section
  Widget _buildChoiceSection(List<ChoicesModel> choices) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: AppResponsive.smallSpacing(context),
      ),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _choicesExpanded = !_choicesExpanded),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.checklist,
                            color: AppColors.primary,
                            size: AppResponsive.iconSize(context),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Text(
                            'Choices',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _choicesExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
                              size: AppResponsive.iconSize(context),
                            ),
                          ),
                          if (!_choicesExpanded &&
                              _choiceCheckedList.contains(true)) ...[
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Text(
                              '${_choiceCheckedList.where((c) => c).length} selected',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _addNewButton(_addNewChoices),
              ],
            ),
            if (_choicesExpanded) ...[
              const Divider(),
              if (choices.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.smallSpacing(context),
                  ),
                  child: Text(
                    'No choices yet. Tap "New" to add one.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      choices[index].name,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    value: _choiceCheckedList[index],
                    onChanged: (value) =>
                        setState(() => _choiceCheckedList[index] = value!),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtrtaSection(List<Extramodel> extra) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: AppResponsive.smallSpacing(context),
      ),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _extrasExpanded = !_extrasExpanded),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary,
                            size: AppResponsive.iconSize(context),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Text(
                            'Extras',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _extrasExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
                              size: AppResponsive.iconSize(context),
                            ),
                          ),
                          if (!_extrasExpanded &&
                              _extraCheckedList.contains(true)) ...[
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Text(
                              '${_extraCheckedList.where((c) => c).length} selected',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _addNewButton(_addNewExtras),
              ],
            ),
            if (_extrasExpanded) ...[
              const Divider(),
              if (extra.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.smallSpacing(context),
                  ),
                  child: Text(
                    'No extras yet. Tap "New" to add one.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: extra.length,
                itemBuilder: (context, index) {
                  final extraItem = extra[index];
                  final isChecked = _extraCheckedList[index];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          extraItem.Ename,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.textPrimary,
                          ),
                        ),
                        value: isChecked,
                        onChanged: (value) =>
                            setState(() => _extraCheckedList[index] = value!),
                      ),
                      if (isChecked)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 56.0,
                            right: 16.0,
                            bottom: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Set Min/Max',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                    color: Colors.grey[700],
                                  ),
                                ),
                                value:
                                    _extraHasConstraints[extraItem.Id] ?? false,
                                onChanged: (value) {
                                  setState(() {
                                    _extraHasConstraints[extraItem.Id] = value!;
                                    // Clear controllers if unchecked
                                    if (!value) {
                                      _extraConstraintControllers[extraItem
                                              .Id]?['min']
                                          ?.clear();
                                      _extraConstraintControllers[extraItem
                                              .Id]?['max']
                                          ?.clear();
                                    }
                                  });
                                },
                              ),
                              if (_extraHasConstraints[extraItem.Id] ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller:
                                              _extraConstraintControllers[extraItem
                                                  .Id]?['min'],
                                          label: 'Minimum',
                                          hint: '0',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: AppResponsive.largeSpacing(
                                          context,
                                        ),
                                      ),
                                      Expanded(
                                        child: AppTextField(
                                          controller:
                                              _extraConstraintControllers[extraItem
                                                  .Id]?['max'],
                                          label: 'Maximum',
                                          hint: '0',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
