import 'dart:typed_data';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/filterButton.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/restaurant/audit_trail_helper.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import '../../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';
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
  late String selectedCategoryId;
  late String selectedIMGCategory;

  Uint8List? _selectedImageBytes;

  // ✅ ADDED: New selling method state
  SellingMethod _sellingMethod = SellingMethod.byUnit;
  String _selectedUnit = 'kg';

  String selectedFilter = 'YES';
  String allowOutOfStockFilter = 'YES';
  bool _isSaving = false;

  // For managing variant selections
  late List<bool> _variantCheckedList;
  late List<TextEditingController> _variantPriceControllers;

  // For managing choice selections
  late List<bool> _choiceCheckedList;

  late List<bool> _extraCheckedList;
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
    selectedCategoryId = widget.items.categoryOfItem ?? '';
    selectedIMGCategory = widget.items.isVeg ?? 'Veg';

    // ✅ ADDED: Initialize selling method based on existing item
    _sellingMethod = widget.items.isSoldByWeight == true ? SellingMethod.byWeight : SellingMethod.byUnit;
    _selectedUnit = widget.items.unit ?? 'kg';

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

    // The rest of the function remains the same, as it correctly
    // pre-selects the variants and choices.

    _variantCheckedList = List.generate(allVariants.length, (index) {
      return widget.items.variant?.any((v) => v.variantId == allVariants[index].id) ?? false;
    });

    _variantPriceControllers = List.generate(allVariants.length, (index) {
      final existingVariant = widget.items.variant?.firstWhere((v) => v.variantId == allVariants[index].id,
          orElse: () => ItemVariante(variantId: '', price: 0.0));
      return TextEditingController(text: existingVariant?.price.toString() ?? '');
    });

    _choiceCheckedList = List.generate(allChoices.length, (index) {
      return widget.items.choiceIds?.contains(allChoices[index].id) ?? false;
    });

    _extraCheckedList = List.generate(allExtra.length, (index){
      return widget.items.extraId?.contains(allExtra[index].Id) ?? false;
    });

    // Initialize min/max controllers for extras
    for (var extra in allExtra) {
      final constraints = widget.items.extraConstraints?[extra.Id];
      final hasConstraints = constraints != null && (constraints['min'] != 0 || constraints['max'] != 0);

      _extraHasConstraints[extra.Id] = hasConstraints;
      _extraConstraintControllers[extra.Id] = {
        'min': TextEditingController(text: constraints?['min']?.toString() ?? ''),
        'max': TextEditingController(text: constraints?['max']?.toString() ?? ''),
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

    // Dispose variant price controllers
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
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
    // Handle image: keep existing imageBytes or use newly selected imageBytes
    Uint8List? finalImageBytes = widget.items.imageBytes;

    // Use the bytes that were already read when picking the image
    if (_selectedImageBytes != null) {
      finalImageBytes = _selectedImageBytes;
    }

    List<ItemVariante> selectedVariants = [];
    for (int i = 0; i < data.allVariants.length; i++) {
      if (_variantCheckedList[i]) {
        final priceText = _variantPriceControllers[i].text.trim();
        final variantId = data.allVariants[i].id;

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

        selectedVariants.add(ItemVariante(
            variantId: variantId,
            price: double.tryParse(priceText) ?? 0.0,
            trackInventory: existingVariant?.trackInventory,
            stockQuantity: existingVariant?.stockQuantity));
      }
    }

    List<String> selectedChoiceIds = [];
    for (int i = 0; i < data.allChoices.length; i++) {
      if (_choiceCheckedList[i]) {
        selectedChoiceIds.add(data.allChoices[i].id);
      }
    }


    List<String> selectedExtraId = [];
    for(int i = 0 ; i < data.allExtra.length; i++ ){
      if(_extraCheckedList[i]){
        selectedExtraId.add(data.allExtra[i].Id);
      }
    }

    // Build extra constraints map from controllers
    Map<String, Map<String, int>> extraConstraints = {};
    for(int i = 0 ; i < data.allExtra.length; i++ ){
      if(_extraCheckedList[i]){
        final extraId = data.allExtra[i].Id;
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
      extraId: selectedExtraId,
      extraConstraints: extraConstraints.isNotEmpty ? extraConstraints : null,
      trackInventory: selectedFilter.toLowerCase() == 'yes',
      allowOrderWhenOutOfStock: allowOutOfStockFilter.toLowerCase() == 'yes',
      isSoldByWeight: _sellingMethod == SellingMethod.byWeight,
      unit: _sellingMethod == SellingMethod.byWeight ? _selectedUnit : null,
    );

    AuditTrailHelper.trackEdit(updateItem, editedBy: RestaurantSession.staffName ?? RestaurantSession.effectiveRole);

    await itemStore.updateItem(updateItem);

    if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Item',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
                  items: ['kg', 'gm'].map((String unit) {
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

          // Inventory Management Section
          _buildSectionHeader('Inventory Management', Icons.inventory_2_outlined),
          const SizedBox(height: 15),
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

          // Variants, Choices & Extras Section
          if (data.allVariants.isNotEmpty || data.allChoices.isNotEmpty || data.allExtra.isNotEmpty) ...[
            _buildSectionHeader('Additional Options', Icons.extension),
            const SizedBox(height: 15),
          ],
          if (data.allVariants.isNotEmpty) _buildVariantSection(data.allVariants),
          if (data.allChoices.isNotEmpty) _buildChoiceSection(data.allChoices),
          if(data.allExtra.isNotEmpty) _buildExtrtaSection(data.allExtra),
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
              ],
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: variants.length,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Checkbox(
                      value: _variantCheckedList[index],
                      onChanged: (value) => setState(() => _variantCheckedList[index] = value!),
                    ),
                    Expanded(child: Text(variants[index].name)),
                    SizedBox(
                      width: 120,
                      child: AppTextField(
                        controller: _variantPriceControllers[index],
                        hint: 'Price',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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
              ],
            ),
            const Divider(),
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
              ],
            ),
            const Divider(),
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to delete this category?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
        ],
      ),


    );

    if (confirmed == true) {
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




