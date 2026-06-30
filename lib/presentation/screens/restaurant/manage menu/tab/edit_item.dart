import 'dart:typed_data';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/data/models/restaurant/db/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/filterButton.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/restaurant/audit_trail_helper.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/tax_selector_sheet.dart';
import '../../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';
import '../../item/default_choice_picker.dart';
import '../../item/variant_selection_screen.dart';
import '../../item/choice_selection_screen.dart';
import '../../item/extra_selection_screen.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import 'edit_category.dart';

enum SellingMethod { byUnit, byWeight }

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
  Map<String, Map<String, TextEditingController>> _extraConstraintControllers = {}; // extraId -> {min, max}
  Map<String, bool> _extraHasConstraints = {}; // Track if extra has min/max enabled



  // This Future will safely load all data before building the UI
  late Future<EditScreenData> _loadDataFuture;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.items.name);
    _itemPriceController = TextEditingController(text: widget.items.price?.toString() ?? '');
    _descController = TextEditingController(text: widget.items.description ?? '');
    _itemCodeController = TextEditingController(text: widget.items.itemCode ?? '');
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
          : (lowStock % 1 == 0 ? lowStock.toStringAsFixed(0) : lowStock.toString()),
    );
    _lowStockAlertFilter = widget.items.lowStockAlertEnabled ? 'YES' : 'NO';
    selectedCategoryId = widget.items.categoryOfItem ?? '';
    selectedIMGCategory = widget.items.isVeg ?? 'Veg';
    selectedTaxRate = widget.items.taxRate;
    selectedTaxIds = List<String>.from(widget.items.taxIds ?? const []);

    // ✅ ADDED: Initialize selling method based on existing item
    _sellingMethod = widget.items.isSoldByWeight == true ? SellingMethod.byWeight : SellingMethod.byUnit;
    // Clamp to a supported value (kItemUnits); imported/legacy items may carry
    // an unsupported unit, which would crash the DropdownButton.
    _selectedUnit = normalizeItemUnit(widget.items.unit) ?? kItemUnits.first;

    selectedFilter = widget.items.trackInventory == true ? 'YES' : 'NO';
    allowOutOfStockFilter = widget.items.allowOrderWhenOutOfStock == true ? 'YES' : 'NO';

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
      return widget.items.variant?.any((v) => v.variantId == allVariants[index].id) ?? false;
    });
    // Open the Variants section automatically if any are already selected.
    _variantsExpanded = _variantCheckedList.contains(true);

    _variantPriceControllers = List.generate(allVariants.length, (index) {
      final existingVariant = widget.items.variant?.firstWhere((v) => v.variantId == allVariants[index].id,
          orElse: () => ItemVariante(variantId: '', price: 0.0));
      return TextEditingController(text: existingVariant?.price.toString() ?? '');
    });

    _variantStockControllers = List.generate(allVariants.length, (index) {
      final existingVariant = widget.items.variant?.firstWhere((v) => v.variantId == allVariants[index].id,
          orElse: () => ItemVariante(variantId: '', price: 0.0));
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
    _defaultChoiceOptionIds =
        List<String>.from(widget.items.defaultChoiceOptionIds ?? const []);

    _extraCheckedList = List.generate(allExtra.length, (index){
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
          : (globalMin != null && globalMin != 0) || (globalMax != null && globalMax != 0);

      _extraHasConstraints[extra.Id] = hasConstraints;
      _extraConstraintControllers[extra.Id] = {
        'min': TextEditingController(text: constraints?['min']?.toString() ?? (globalMin != null && globalMin != 0 ? globalMin.toString() : '')),
        'max': TextEditingController(text: constraints?['max']?.toString() ?? (globalMax != null && globalMax != 0 ? globalMax.toString() : '')),
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
    final duplicateCode = itemStore.items.any((i) => i.itemCode == itemCode && i.id != widget.items.id);
    if (duplicateCode) {
      NotificationService.instance.showError('Item code already exists. Please enter a different code.');
      return;
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
            pendingAdjustments.add({'variantId': variantId, 'old': oldStock, 'new': newStock});
          }
        }

        selectedVariants.add(ItemVariante(
            variantId: variantId,
            price: double.tryParse(priceText) ?? 0.0,
            trackInventory: existingVariant?.trackInventory,
            stockQuantity: newStock));
      }
    }

    List<String> selectedChoiceIds = [];
    for (int i = 0; i < _allChoices.length; i++) {
      if (_choiceCheckedList[i]) {
        selectedChoiceIds.add(_allChoices[i].id);
      }
    }


    List<String> selectedExtraId = [];
    for(int i = 0 ; i < _allExtra.length; i++ ){
      if(_extraCheckedList[i]){
        selectedExtraId.add(_allExtra[i].Id);
      }
    }

    // Build extra constraints map from controllers
    Map<String, Map<String, int>> extraConstraints = {};
    for(int i = 0 ; i < _allExtra.length; i++ ){
      if(_extraCheckedList[i]){
        final extraId = _allExtra[i].Id;
        final minText = _extraConstraintControllers[extraId]?['min']?.text.trim() ?? '';
        final maxText = _extraConstraintControllers[extraId]?['max']?.text.trim() ?? '';

        final minValue = int.tryParse(minText) ?? 0;
        final maxValue = int.tryParse(maxText) ?? 0;

        extraConstraints[extraId] = {
          'min': minValue,
          'max': maxValue,
        };
      }
    }

    final updateItem = widget.items.copyWith(
      name: trimmedName,
      price: double.tryParse(_itemPriceController.text.trim()),
      description: _descController.text.trim(),
      isVeg: selectedIMGCategory,
      categoryOfItem: selectedCategoryId,
      imageBytes: finalImageBytes,
      variant: selectedVariants,
      choiceIds: selectedChoiceIds,
      defaultChoiceOptionIds: _defaultChoiceOptionIds,
      extraId: selectedExtraId,
      extraConstraints: extraConstraints.isNotEmpty ? extraConstraints : null,
      trackInventory: selectedFilter.toLowerCase() == 'yes',
      allowOrderWhenOutOfStock: allowOutOfStockFilter.toLowerCase() == 'yes',
      isSoldByWeight: _sellingMethod == SellingMethod.byWeight,
      unit: _sellingMethod == SellingMethod.byWeight ? _selectedUnit : null,
      itemCode: itemCode,
    );

    // Set tax directly (not via copyWith) so selecting "No Tax" (null) actually
    // clears it — copyWith's `?? this.taxRate` would otherwise keep the old rate.
    updateItem.taxRate = selectedTaxRate;
    updateItem.taxIds = selectedTaxIds;

    // Low-stock alert (only meaningful when inventory tracking is on).
    // Set directly so turning tracking/alert off clears the override.
    final lowStockOn =
        selectedFilter.toLowerCase() == 'yes' && _lowStockAlertFilter == 'YES';
    updateItem.lowStockAlertEnabled = lowStockOn;
    updateItem.lowStockThreshold =
        lowStockOn ? double.tryParse(_lowStockController.text.trim()) : null;

    // Item-level stock for SIMPLE items (no variants). Variant items keep the
    // item-level quantity at 0 and track stock per-variant instead.
    if (!_variantCheckedList.contains(true)) {
      final oldStock = widget.items.stockQuantity;
      final newStock = selectedFilter.toLowerCase() == 'yes'
          ? (double.tryParse(_stockController.text.trim()) ?? 0.0)
          : 0.0;
      updateItem.stockQuantity = newStock;
      // Log an adjustment if a tracked item's stock actually changed.
      if (selectedFilter.toLowerCase() == 'yes' && newStock != oldStock) {
        pendingSimpleAdjustment = {'old': oldStock, 'new': newStock};
      }
    }

    AuditTrailHelper.trackEdit(updateItem, editedBy: RestaurantSession.staffName ?? RestaurantSession.effectiveRole);

    await itemStore.updateItem(updateItem);

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
      backgroundColor: Colors.grey[50],
      appBar: buildPrimaryAppBar(
        title: 'Edit Item',
        titleFontSize: 18,
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
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // This method now contains your full UI with improved structure
  Widget _buildForm(EditScreenData data) {
    final currentCategoryName = data.allCategories.firstWhere(
            (cat) => cat.id == selectedCategoryId,
        orElse: () => Category(id: '', name: 'Select Category')
    ).name;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Section
          _buildSectionHeader('Basic Information', Icons.info_outline),
          const SizedBox(height: 15),
          AppTextField(
            controller: _nameController,
            label: 'Item Name',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 15),
          AppTextField(
            controller: _itemCodeController,
            label: 'Item Code',
            icon: Icons.qr_code_scanner_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 25),

          // Selling Method Section
          _buildSectionHeader('Selling Method', Icons.scale),
          const SizedBox(height: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sold by:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<SellingMethod>(
                      title: const Text('Unit'),
                      value: SellingMethod.byUnit,
                      groupValue: _sellingMethod,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _sellingMethod = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<SellingMethod>(
                      title: const Text('Weight'),
                      value: SellingMethod.byWeight,
                      groupValue: _sellingMethod,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _sellingMethod = value!),
                    ),
                  ),
                ],
              ),
              if (_sellingMethod == SellingMethod.byWeight)
                DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: InputDecoration(
                    labelText: 'Select Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: kItemUnits.map((String unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedUnit = newValue!;
                    });
                  },
                ),
            ],
          ),



          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _itemPriceController,
                  label: 'Item Price',
                  icon: Icons.currency_rupee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ✅ ADDED: Your Veg/Non-Veg selector UI
              Expanded(
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(context: context, builder: (context) => _VegNonVegSheet(
                      onSelected: (newValue) {
                        setState(() { selectedIMGCategory = newValue; });
                        Navigator.pop(context);
                      },
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, color: selectedIMGCategory == 'Veg' ? Colors.green : Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Text(selectedIMGCategory),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // Category Section
          _buildSectionHeader('Category', Icons.category_outlined),
          const SizedBox(height: 15),
          InkWell(
            onTap: () async {
              final String? newId = await showModalBottomSheet(
                context: context,
                builder: (_) => _CategorySelectionSheet(
                  categories: data.allCategories,
                  allItems: data.allItems,
                  selectedId: selectedCategoryId,
                  onCategoryDeleted: (deletedCategoryId) {
                    if (selectedCategoryId == deletedCategoryId) {
                      setState(() => selectedCategoryId = '');
                    }
                    setState(() => _loadDataFuture = _loadInitialData());
                  },
                ),
              );
              if (newId != null) setState(() => selectedCategoryId = newId);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(currentCategoryName, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Tax Section
          _buildSectionHeader('Tax', Icons.percent_rounded),
          const SizedBox(height: 15),
          InkWell(
            onTap: () async {
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
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.percent_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        selectedTaxRate != null
                            ? 'Tax: ${(selectedTaxRate! * 100).toStringAsFixed(2)}%'
                            : 'No tax applied',
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Inventory Management Section — stock module. Hidden when `inventory`
          // isn't in the plan (a menu item is still fully editable without stock).
          if (PlanEnforce.allows(EntKeys.inventory))
            _buildSectionHeader('Inventory Management', Icons.inventory_2_outlined),
          if (PlanEnforce.allows(EntKeys.inventory)) const SizedBox(height: 15),
          if (PlanEnforce.allows(EntKeys.inventory))
            Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Manage Inventory Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Manage Inventory",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        Filterbutton(
                          title: 'YES',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "YES";
                              // Auto-set "Allow out of stock" to NO when enabling inventory management
                              // This enforces stock limits by default (better UX)
                              allowOutOfStockFilter = "NO";
                            });
                          },
                        ),
                        SizedBox(width: 8),
                        Filterbutton(
                          title: 'NO',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "NO";
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // Out of Stock Option (shown only when inventory is YES)
                if (selectedFilter.toLowerCase() == 'yes') ...[
                  SizedBox(height: 12),
                  // Current Stock — only for SIMPLE items. Variant items track
                  // stock per-variant in the Variants section below.
                  if (!_variantCheckedList.contains(true)) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Current Stock (${_sellingMethod == SellingMethod.byWeight ? _selectedUnit : 'pcs'})",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: AppTextField(
                            controller: _stockController,
                            hint: '0',
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                  ],
                  Divider(height: 1, color: Colors.grey.shade300),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Allow order if out of stock",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Row(
                        children: [
                          Transform.scale(
                            scale: 0.8,
                            child: Filterbutton(
                              title: 'YES',
                              selectedFilter: allowOutOfStockFilter,
                              onpressed: () {
                                setState(() {
                                  allowOutOfStockFilter = "YES";
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 6),
                          Transform.scale(
                            scale: 0.8,
                            child: Filterbutton(
                              title: 'NO',
                              selectedFilter: allowOutOfStockFilter,
                              onpressed: () {
                                setState(() {
                                  allowOutOfStockFilter = "NO";
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.shade300),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Low-stock alert",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Row(
                        children: [
                          Transform.scale(
                            scale: 0.8,
                            child: Filterbutton(
                              title: 'YES',
                              selectedFilter: _lowStockAlertFilter,
                              onpressed: () => setState(() => _lowStockAlertFilter = 'YES'),
                            ),
                          ),
                          SizedBox(width: 6),
                          Transform.scale(
                            scale: 0.8,
                            child: Filterbutton(
                              title: 'NO',
                              selectedFilter: _lowStockAlertFilter,
                              onpressed: () => setState(() => _lowStockAlertFilter = 'NO'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_lowStockAlertFilter == 'YES') ...[
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Alert threshold (${_sellingMethod == SellingMethod.byWeight ? _selectedUnit : 'pcs'})",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: AppTextField(
                            controller: _lowStockController,
                            hint: 'Default ${AppSettings.lowStockThreshold.toStringAsFixed(0)}',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Item Image Section
          _buildSectionHeader('Item Image', Icons.image_outlined),
          const SizedBox(height: 15),
          InkWell(
            onTap: () async {
              final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                
                // Validate image size (max 2MB)
                final int maxSizeInBytes = 2 * 1024 * 1024; // 2MB
                if (bytes.length > maxSizeInBytes) {
                  if (mounted) {
                    NotificationService.instance.showError('Image is too large. Please select an image under 2MB.');
                  }
                  return;
                }

                setState(() => _selectedImageBytes = bytes);
              }
            },
            child: Column(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border.all(color: AppColors.divider, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildImage(),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Upload Image (png, .jpg, .jpeg) up to 3MB', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          AppTextField(
            controller: _descController,
            maxLines: 3,
            hint: 'Description (Optional)',
            icon: Icons.notes_outlined,
          ),
          const SizedBox(height: 25),

          // Variants, Choices & Extras Section — always shown so new options can
          // be created here (via the "+ New" button in each section header).
          _buildSectionHeader('Additional Options', Icons.extension),
          const SizedBox(height: 15),
          _buildVariantSection(_allVariants),
          _buildChoiceSection(_allChoices),
          if (_choiceCheckedList.contains(true))
            _buildDefaultSelectionButton(_allChoices),
          _buildExtrtaSection(_allExtra),
          const SizedBox(height: 30),
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveChanges(data),
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving…' : 'Save Changes',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  // ✅ ADDED: Helper method to decide what image to show
  Widget _buildImage() {
    // If a new image has been selected, show it from bytes (web-compatible)
    if (_selectedImageBytes != null) {
      return Image.memory(_selectedImageBytes!, fit: BoxFit.cover);
    }
    // If there's an existing image bytes from the original item, show it.
    if (widget.items.imageBytes != null && widget.items.imageBytes!.isNotEmpty) {
      return Image.memory(
        widget.items.imageBytes!,
        fit: BoxFit.fill,
        width: 80,
        height: 80,
      );
    }
    // Otherwise, show the placeholder.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.image, color: Colors.grey, size: 50),
        const SizedBox(height: 5),
        Text('Upload Image', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ],
    );
  }

  // Small "+ New" action shown in each option section header.
  Widget _addNewButton(VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16),
      label: Text('New',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
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
              text: (gMin != null && gMin != 0) ? gMin.toString() : ''),
          'max': TextEditingController(
              text: (gMax != null && gMax != 0) ? gMax.toString() : ''),
        };
      });
      _extraHasConstraints.putIfAbsent(
          e.Id,
          () => (e.minimum != null && e.minimum != 0) ||
              (e.maximum != null && e.maximum != 0));
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _variantsExpanded = !_variantsExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.tune, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Variants',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _variantsExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textSecondary, size: 22),
                          ),
                          if (!_variantsExpanded &&
                              _variantCheckedList.contains(true)) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${_variantCheckedList.where((c) => c).length} selected',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No variants yet. Tap "New" to add one.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final trackOn = selectedFilter.toLowerCase() == 'yes';
                  return Row(
                    children: [
                      Checkbox(
                        value: _variantCheckedList[index],
                        onChanged: (value) => setState(() => _variantCheckedList[index] = value!),
                      ),
                      Expanded(child: Text(variants[index].name)),
                      SizedBox(
                        width: trackOn ? 90 : 120,
                        child: AppTextField(
                          controller: _variantPriceControllers[index],
                          hint: 'Price',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                        ),
                      ),
                      // Per-variant stock — only when inventory tracking is on.
                      if (trackOn && _variantCheckedList[index]) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: AppTextField(
                            controller: _variantStockControllers[index],
                            hint: 'Stock',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
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

  /// Tappable card to set this item's default-selected choice options.
  Widget _buildDefaultSelectionButton(List<ChoicesModel> allChoices) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickItemDefaults(allChoices),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.task_alt_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Default Selection',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Pre-tick choice options for this item',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (_defaultChoiceOptionIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${_defaultChoiceOptionIds.length}',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 12)),
                ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.textSecondary),
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
        context, selectedChoiceIds, _defaultChoiceOptionIds);
    if (result != null && mounted) {
      setState(() => _defaultChoiceOptionIds = result);
    }
  }

  // Helper widget for building the choices section
  Widget _buildChoiceSection(List<ChoicesModel> choices) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _choicesExpanded = !_choicesExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.checklist, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Choices',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _choicesExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textSecondary, size: 22),
                          ),
                          if (!_choicesExpanded &&
                              _choiceCheckedList.contains(true)) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${_choiceCheckedList.where((c) => c).length} selected',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No choices yet. Tap "New" to add one.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(choices[index].name),
                    value: _choiceCheckedList[index],
                    onChanged: (value) => setState(() => _choiceCheckedList[index] = value!),
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _extrasExpanded = !_extrasExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Extras',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _extrasExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textSecondary, size: 22),
                          ),
                          if (!_extrasExpanded &&
                              _extraCheckedList.contains(true)) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${_extraCheckedList.where((c) => c).length} selected',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No extras yet. Tap "New" to add one.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
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
                      title: Text(extraItem.Ename),
                      value: isChecked,
                      onChanged: (value) => setState(() => _extraCheckedList[index] = value!),
                    ),
                    if (isChecked)
                      Padding(
                        padding: const EdgeInsets.only(left: 56.0, right: 16.0, bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Set Min/Max', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                              value: _extraHasConstraints[extraItem.Id] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _extraHasConstraints[extraItem.Id] = value!;
                                  // Clear controllers if unchecked
                                  if (!value) {
                                    _extraConstraintControllers[extraItem.Id]?['min']?.clear();
                                    _extraConstraintControllers[extraItem.Id]?['max']?.clear();
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
                                        controller: _extraConstraintControllers[extraItem.Id]?['min'],
                                        label: 'Minimum',
                                        hint: '0',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: AppTextField(
                                        controller: _extraConstraintControllers[extraItem.Id]?['max'],
                                        label: 'Maximum',
                                        hint: '0',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
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


// Helper widget for building the choices section


// ✅ REFACTORED: The Category Selection Sheet is now complete.
class _CategorySelectionSheet extends StatefulWidget {
  final List<Category> categories;
  final List<Items> allItems;
  final String selectedId;
  final Function(String) onCategoryDeleted; // Callback for deletion

  const _CategorySelectionSheet({
    required this.categories,
    required this.allItems,
    required this.selectedId,
    required this.onCategoryDeleted,
  });
  @override
  State<_CategorySelectionSheet> createState() => _CategorySelectionSheetState();
}

class _CategorySelectionSheetState extends State<_CategorySelectionSheet> {
  late List<Category> _currentCategories;

  @override
  void initState() {
    super.initState();
    _currentCategories = widget.categories;
  }

  void _deleteCategory(String categoryId) async {
    // Show confirmation dialog
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Category?',
      message: 'Do you want to delete this category?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      // Unlink items belonging to this category
      final affected = widget.allItems.where((item) => item.categoryOfItem == categoryId).toList();
      for (final item in affected) {
        await itemStore.updateItem(item.copyWith(categoryOfItem: ''));
      }
      await categoryStore.deleteCategory(categoryId);
      widget.onCategoryDeleted(categoryId);
      setState(() {
        _currentCategories.removeWhere((cat) => cat.id == categoryId);
      });
    }
  }
  Future<void> _onAddNewCategory() async {
    final added = await AddCategoryDialog.show(context);
    if (added) {
      setState(() {
        _currentCategories = categoryStore.categories.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Select Category", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currentCategories.length,
              itemBuilder: (context, index) {
                final category = _currentCategories[index];
                return ListTile(
                  onTap: () => Navigator.pop(context, category.id),
                  leading: Radio<String>(
                    value: category.id,
                    groupValue: widget.selectedId,
                    onChanged: (value) {
                      if (value != null) {
                        Navigator.pop(context, value);
                      }
                    },
                  ),
                  title: Text(category.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditCategory(category: category),
                            ),
                          );
                          // Re-pull from the store so the renamed category shows
                          // immediately (mirrors _onAddNewCategory's refresh).
                          if (mounted) {
                            setState(() {
                              _currentCategories = categoryStore.categories.toList();
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(category.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onAddNewCategory,
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: Text('Add New Category', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}




class _VegNonVegSheet extends StatelessWidget {
  final Function(String) onSelected;
  const _VegNonVegSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.circle, color: Colors.green),
          title: Text('Veg'),
          onTap: () => onSelected('Veg'),
        ),
        ListTile(
          leading: Icon(Icons.circle, color: Colors.red),
          title: Text('Non-Veg'),
          onTap: () => onSelected('Non-Veg'),
        ),
      ],
    );
  }}




