import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_choice.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_extra.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_variante.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/filterButton.dart';
import 'package:unipos/util/restaurant/audit_trail_helper.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';

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

  // ✅ ADDED: State for the new image picker
  File? _selectedImage;

  // ✅ ADDED: New selling method state
  SellingMethod _sellingMethod = SellingMethod.byUnit;
  String _selectedUnit = 'kg';

  String selectedFilter = 'YES';
  String allowOutOfStockFilter = 'YES';

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

    // Auto-select "YES" for manage inventory if track inventory is true
    selectedFilter = widget.items.trackInventory == true ? 'YES' : 'NO';

    // Auto-select "YES" for allow out of stock if allowOrderWhenOutOfStock is true
    allowOutOfStockFilter = widget.items.allowOrderWhenOutOfStock == true ? 'YES' : 'NO';

    _loadDataFuture = _loadInitialData();
  }
// In _EdititemScreenState

  Future<EditScreenData> _loadInitialData() async {
    // ✅ FIX: Use synchronous box access since boxes are already open from main.dart
    final categoryBox = HiveBoxes.getCategory();
    final variantBox = HiveVariante.getVariante();
    final choiceBox = HiveChoice.getchoice();
    final extraBox = HiveExtra.getextra();
    final itemBox = itemsBoxes.getItemBox();

    final allCategories = categoryBox.values.toList();
    final allVariants = variantBox.values.toList();
    final allChoices = choiceBox.values.toList();
    final allExtra = extraBox.values.toList();
    final allItems = itemBox.values.toList();

    // The rest of the function remains the same, as it correctly
    // pre-selects the variants and choices.

    _variantCheckedList = List.generate(allVariants.length, (index) {
      return widget.items.variant?.any((v) => v.variantId == allVariants[index].id) ?? false;
    });

    _variantPriceControllers = List.generate(allVariants.length, (index) {
      final existingVariant = widget.items.variant?.firstWhere((v) => v.variantId == allVariants[index].id,
          orElse: () => ItemVariante(variantId: '', price: 0.0));
      return TextEditingController(text: existingVariant?.price?.toString() ?? '');
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

  // ... (saveImage and saveChanges methods remain the same) ...
  Future<String?> _saveImageAndGetPath(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}${p.extension(imageFile.path)}';
    final savedImagePath = p.join(directory.path, fileName);
    await imageFile.copy(savedImagePath);
    return savedImagePath;
  }

  void _saveChanges(EditScreenData data) async {
    String? finalImagePath = widget.items.imagePath;

    if (_selectedImage != null) {
      finalImagePath = await _saveImageAndGetPath(_selectedImage!);
    }

    List<ItemVariante> selectedVariants = [];
    for (int i = 0; i < data.allVariants.length; i++) {
      if (_variantCheckedList[i]) {
        final priceText = _variantPriceControllers[i].text.trim();
        selectedVariants.add(ItemVariante(
            variantId: data.allVariants[i].id,
            price: double.tryParse(priceText) ?? 0.0));
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

    final bool isTrackingInventory = selectedFilter.toLowerCase() == 'yes';

    final updateItem = widget.items.copyWith(
      name: _nameController.text,
      price: double.tryParse(_itemPriceController.text),
      description: _descController.text,
      isVeg: selectedIMGCategory,
      categoryOfItem: selectedCategoryId,
      imagePath: finalImagePath,
      variant: selectedVariants,
      choiceIds: selectedChoiceIds,
      extraId: selectedExtraId,
      extraConstraints: extraConstraints.isNotEmpty ? extraConstraints : null,
      trackInventory: isTrackingInventory,
      allowOrderWhenOutOfStock: allowOutOfStockFilter.toLowerCase() == 'yes',
      // ✅ ADDED: Weight selling support
      isSoldByWeight: _sellingMethod == SellingMethod.byWeight,
      unit: _sellingMethod == SellingMethod.byWeight ? _selectedUnit : null,
    );

    // 🔍 AUDIT TRAIL: Track this edit
    AuditTrailHelper.trackEdit(updateItem, editedBy: 'Admin'); // TODO: Replace 'Admin' with actual logged-in user

    await itemsBoxes.updateItem(updateItem);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primarycolor,
        title: Text('Edit Item',style: GoogleFonts.poppins(color: Colors.white),),
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

  // This method now contains your full UI, including the missing parts
  Widget _buildForm(EditScreenData data) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    final currentCategoryName = data.allCategories.firstWhere(
            (cat) => cat.id == selectedCategoryId,
        orElse: () => Category(id: '', name: 'Select Category')
    ).name;




    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          CommonTextForm(
              borderc: 5,
              LabelColor: Colors.grey,
              controller: _nameController,
              labelText: 'Item Name',
              obsecureText: false),
          const SizedBox(height: 10),

          // ✅ UPDATED: New Selling Method UI matching bottomsheet
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
                  child: CommonTextForm(
                      borderc: 5,
                      LabelColor: Colors.grey,
                      controller: _itemPriceController, labelText: 'Item Price',
                      obsecureText: false,
                      keyboardType: TextInputType.number)
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
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
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
          const SizedBox(height: 20),
          // Your Category Selector UI
          Container( /* ... same as your code ... */ ),
          const SizedBox(height: 20),


          // ✅ YOUR CATEGORY SELECTOR UI IS HERE
          Container(
            height: 60,
            decoration: BoxDecoration(border: Border.all(width: 0.5, color: Colors.black38)),
            child: CommonButton(
              height: 60,
              bgcolor: Colors.transparent,
              bordercolor: Colors.transparent,
              onTap: () async {
                final String? newId = await showModalBottomSheet(
                  context: context,
                  builder: (_) => _CategorySelectionSheet(
                    categories: data.allCategories,
                    allItems: data.allItems,
                    selectedId: selectedCategoryId,
                    // ✅ FIX: Pass a callback to handle deletion
                    onCategoryDeleted: (deletedCategoryId) {
                      // If the deleted category was the selected one, clear the selection
                      if (selectedCategoryId == deletedCategoryId) {
                        setState(() {
                          selectedCategoryId = '';
                        });
                      }
                      // Refresh the FutureBuilder to get the updated category list
                      setState(() {
                        _loadDataFuture = _loadInitialData();
                      });
                    },
                  ),
                );
                if (newId != null) {
                  setState(() {
                    selectedCategoryId = newId;
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(currentCategoryName, style: GoogleFonts.poppins(fontSize: 16)),
                    const Icon(Icons.arrow_forward_ios)
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ✅ UPDATED: Inventory Management Container matching bottomsheet
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
          const SizedBox(height: 20),


          // ✅ ADDED: Your Image Picker UI
          InkWell(
            onTap: () async {
              final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                setState(() { _selectedImage = File(pickedFile.path); });
              }
            },
            child: Column(
              children: [
                Container(
                  height: ResponsiveHelper.responsiveHeight(context, 0.16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _buildImage(), // Using a helper method for clarity
                ),
                const SizedBox(height: 4),
                Text('Upload Image (png, .jpg, .jpeg) upto 3mb', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          CommonTextForm(maxline: 3, controller: _descController, hintText: 'Description (Optional)', obsecureText: false),
          const SizedBox(height: 16),
          if (data.allVariants.isNotEmpty) _buildVariantSection(data.allVariants),
          if (data.allChoices.isNotEmpty) _buildChoiceSection(data.allChoices),
          if(data.allExtra.isNotEmpty) _buildExtrtaSection(data.allExtra),
          const SizedBox(height: 24),
          CommonButton(onTap: () => _saveChanges(data), child: const Text('Save')),
        ],
      ),
    );
  }
  // ✅ ADDED: Helper method to decide what image to show
  Widget _buildImage() {
    // If a new image has been selected, show it.
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    }
    // If there's an existing image path from the original item, show it.
    if (widget.items.imagePath != null && widget.items.imagePath!.isNotEmpty) {
      final imageFile = File(widget.items.imagePath!);
      if (imageFile.existsSync()) {
        return Image.file(
          imageFile,
          fit: BoxFit.fill,
          width: 80,
          height: 80,
        );
      }
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Variants', style: Theme.of(context).textTheme.titleMedium),
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
                      child: CommonTextForm(
                        controller: _variantPriceControllers[index],
                        hintText: 'Price',
                        keyboardType: TextInputType.number, obsecureText: false,
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
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choices', style: Theme.of(context).textTheme.titleMedium),
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
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extra', style: Theme.of(context).textTheme.titleMedium),
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
                                      child: TextField(
                                        controller: _extraConstraintControllers[extraItem.Id]?['min'],
                                        decoration: const InputDecoration(
                                          labelText: 'Minimum',
                                          hintText: '0',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _extraConstraintControllers[extraItem.Id]?['max'],
                                        decoration: const InputDecoration(
                                          labelText: 'Maximum',
                                          hintText: '0',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
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
      await HiveBoxes.getCategory().delete(categoryId);
      // Refresh the list inside the sheet
      setState(() {
        _currentCategories.removeWhere((cat) => cat.id == categoryId);
      });
    }
  }
  // ✅ ADDED: Functionality to add a new category
  Future<void> _onAddNewCategory() async {
    final newCategoryName = await showDialog<String>(
      context: context,
      builder: (ctx) => _AddCategoryDialog(),
    );

    if (newCategoryName != null && newCategoryName.isNotEmpty) {
      final newCategory = Category(id: const Uuid().v4(), name: newCategoryName);
      await HiveBoxes.getCategory().put(newCategory.id, newCategory);
      // Refresh the list inside this sheet to show the new category
      setState(() {
        _currentCategories.add(newCategory);
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
                // Calculate product count for this category
                final productCount = widget.allItems.where((item) => item.categoryOfItem == category.id).length ?? 0;
                // final itemCount =
                //     itemsList?.where((item) => item.categoryOfItem == category.id).length ?? 0;
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
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name),
                      // Text(
                      //   // Text(
                      //   //   '$itemCount item${itemCount == 1 ? '' : 's'} Added',
                      //   //   style: GoogleFonts.poppins(color: Colors.grey),
                      //   // )
                      //   '$productCount Product${productCount == 1 ? '' : 's'} Listed',
                      //   style: const TextStyle(fontSize: 12, color: Colors.grey),
                      // ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:  Icon(Icons.edit, color: primarycolor),
                        onPressed: () {
                          // TODO: Implement navigation to an EditCategoryScreen
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
          CommonButton(
            onTap:_onAddNewCategory,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add),
                SizedBox(width: 8),
                Text("Add New Category"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



/// ✅ ADDED: A simple dialog for adding a new category
class _AddCategoryDialog extends StatelessWidget {
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Category'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Category Name'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
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




// old items edit code

// import 'dart:io';
//
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/Textform.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/database/hive_choice.dart';
// import 'package:BillBerry/database/hive_variante.dart';
// import 'package:BillBerry/model/db/itemvariantemodel_12.dart';
// import 'package:BillBerry/model/db/variantmodel_5.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:hive/hive.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:uuid/uuid.dart';
//
// import '../../../componets/Button.dart';
// import '../../../componets/filterButton.dart';
// import '../../../database/hive_db.dart';
// import '../../../model/db/categorymodel_0.dart';
// import '../../../model/db/choicemodel_6.dart';
// import '../../../model/db/choiceoptionmodel_7.dart';
// import '../../../model/db/itemmodel_2.dart';
// import '../../../utils/responsive_helper.dart';
//
// class EdititemScreen extends StatefulWidget {
//   final Items items;
//
//   const EdititemScreen({super.key, required this.items});
//
//   @override
//   State<EdititemScreen> createState() => _EdititemScreenState();
// }
//
// class _EdititemScreenState extends State<EdititemScreen> {
//   late TextEditingController _nameController = TextEditingController();
//   late TextEditingController _itemPriceController = TextEditingController();
//   final TextEditingController _barcodeController = TextEditingController();
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _descController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   final TextEditingController CategoryController = TextEditingController();
//   String? selectedCategory;
//   String? selectedCategoryId;
//   String? option = 'Each';
//   String selectedIMGCategory = '';
//   String selectedFilter = 'yes';
//   String selectedFilter2 = 'yes';
//   File? _selectedImage;
//   bool isChecked = false;
//   bool isCheckedone = false;
//   bool isCheckedtwo = false;
//   final ImagePicker _picker = ImagePicker();
//   bool IsYes = false;
//   Box<Category>? categorybox;
//
//   // variant
//   List<VariantModel> variantList = [];
//   List<bool> isCheckedList = [];
//   List<TextEditingController> priceController = [];
//
//
//   // Choice
//   List<ChoicesModel> choiceList = [];
//   List<ChoiceOption> tempOptions = [];
//   List<bool> isCheckedListChoice = [];
//
//
//   // function For Image Pick
//   Future<void> _pickIMage(ImageSource source) async {
//     final pickedFile = await _picker.pickImage(source: source);
//     if (pickedFile != null) {
//       setState(() {
//         _selectedImage = File(pickedFile.path);
//       });
//     }
//     Navigator.pop(context);
//   }
//
//   void _showImagePicker() {
//     showModalBottomSheet(
//         context: context,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         builder: (context) {
//           return Padding(
//               padding: EdgeInsets.all(20),
//               child: Container(
//                 // color: Colors.red,
//                 width: double.infinity,
//                 height: ResponsiveHelper.responsiveHeight(context, 0.25),
//
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     InkWell(
//                       onTap: () => _pickIMage(ImageSource.gallery),
//                       child: Container(
//                         alignment: Alignment.center,
//                         width: ResponsiveHelper.responsiveWidth(context, 0.35),
//                         height: ResponsiveHelper.responsiveHeight(context, 0.2),
//                         decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(4)),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.photo_library,
//                               size: 50,
//                               color: primarycolor,
//                             ),
//                             Text('From Gallery'),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Container(
//                       width: ResponsiveHelper.responsiveWidth(context, 0.35),
//                       height: ResponsiveHelper.responsiveHeight(context, 0.2),
//                       decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(4)),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.search,
//                             size: 50,
//                             color: primarycolor,
//                           ),
//                           Text('From Search'),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ));
//         });
//   }
//
//
//
//   List<Category> categorieshive = [];
//
//   // Future<void> loadHiveCategory() async {
//   //   final box = await HiveBoxes.getCategory();
//   //   categorybox = await Hive.openBox<Category>('categories');
//   //
//   //   setState(() {
//   //     categorieshive = box.values.toList();
//   //     // selectedCategory =
//   //   });
//   // }
//
//
//
//
//   Future<void> loadVariant() async {
//     final box = await HiveVariante.getvariante();
//     final loadedVariants = box.values.toList();
//
//     setState(() {
//       variantList = loadedVariants;
//       isCheckedList = List.generate(variantList.length, (_) => false);
//       priceController = List.generate(
//         variantList.length,
//             (index) => TextEditingController(),
//       );
//     });
//   }
//   Future<void> loadChoice() async {
//     final box = await HiveChoice.getchoice();
//     final loadedChoice = box.values.toList();
//
//     setState(() {
//       choiceList = loadedChoice;
//       isCheckedListChoice = List.generate(choiceList.length, (_) => false);
//
//     });
//   }
//
//
//   Future<void> loadHiveCategory() async {
//     categorybox = await Hive.openBox<Category>('categories');
//     categorieshive = categorybox!.values.toList();
//
//     final matchedCategory = categorybox!.values.firstWhere(
//           (cat) => cat.id == selectedCategoryId,
//       orElse: () => Category(id: '', name: 'Unknown'),
//     );
//
//     setState(() {
//       selectedCategory = matchedCategory.name;
//     });
//   }
//
//   // Future<void> loadHiveCategory() async {
//   //   categorybox = await Hive.openBox<Category>('category');
//   //
//   //   final matchedCategory = categorybox!.values.firstWhere(
//   //         (cat) => cat.id == selectedCategoryId,
//   //     orElse: () => Category(id: '', name: 'Unknown'),
//   //   );
//   //
//   //   setState(() {
//   //     selectedCategory = matchedCategory.name;
//   //   });
//   // }
//
//   Future<void> _addcategoryHive() async {
//     if (CategoryController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Category name cannot be Empty')));
//       return;
//     }
//     final newcategory = Category(
//         imagePath: _selectedImage != null ? _selectedImage!.path : null,
//         id: const Uuid().v4(),
//         name: CategoryController.text.trim());
//
//     await HiveBoxes.addCategory(newcategory);
//     _clearImage();
//     Navigator.pop(context);
//
// // _clearImage();
//   }
//
//   void _clearImage() {
//     setState(() {
//       _selectedImage = null;
//
//       // Navigator.pop(context);
//     });
//   }
//
//   final outborder = OutlineInputBorder(borderRadius: BorderRadius.circular(5));
//
//   // In EdititemScreen.dart
//
//   void saveChnages() async {
//     // This part for Variants is correct
//     List<ItemVariante> selectedVariants = [];
//     for (int i = 0; i < variantList.length; i++) {
//       if (isCheckedList[i]) {
//         final priceText = priceController[i].text.trim();
//         if (priceText.isNotEmpty) {
//           selectedVariants.add(ItemVariante(
//               variantId: variantList[i].id,
//               price: double.tryParse(priceText) ?? 0.0));
//         }
//       }
//     }
//
//     // This is the corrected part for Choices
//     List<String> selectedChoiceIds = [];
//     for (int i = 0; i < choiceList.length; i++) {
//       // THE FIX IS ON THIS LINE: It should be isCheckedListChoice
//       if (isCheckedListChoice[i]) {
//         selectedChoiceIds.add(choiceList[i].id);
//       }
//     }
//
//     final updateItem = widget.items.copyWith(
//       name: _nameController.text,
//       price: double.tryParse(_itemPriceController.text),
//       isVeg: selectedIMGCategory,
//       categoryOfItem: selectedCategoryId,
//       variant: selectedVariants,
//       choiceIds: selectedChoiceIds,
//     );
//
//     await itemsBoxes.updateItem(updateItem);
//     Navigator.pop(context, true);
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     loadChoice();
//     loadVariant();
//     _nameController = TextEditingController(text: widget.items.name);
//     _itemPriceController = TextEditingController(text:  widget.items.price.toString());
//     selectedIMGCategory = widget.items.isVeg == 'Veg' ? 'Veg' : 'Non-Veg';
//     selectedCategoryId = widget.items.categoryOfItem;
//     selectedCategory = categorybox?.values.firstWhere(
//             (cat) => cat.id == selectedCategoryId,
//         orElse: ()=> Category(id: '', name: 'Unknow')).name;
//     setState(() {});
//     loadHiveCategory();
//
//
//   //   initialize state list based on variantList
//     isCheckedList = List.generate(variantList.length,(_)=>false);
//     priceController = List.generate(
//         variantList.length,
//         (index)=> TextEditingController());
//
//
//   }
//
//   Future<void> loadCategoryAndSetSelected() async {
//     categorybox = await Hive.openBox<Category>('category');
//     selectedCategoryId = widget.items.categoryOfItem;
//
//     final matchedCategory = categorybox!.values.firstWhere(
//           (cat) => cat.id == selectedCategoryId,
//       orElse: () => Category(id: '', name: 'Unknown'),
//     );
//
//     setState(() {
//       selectedCategory = matchedCategory.name;
//     });
//   }
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//     return Scaffold(
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         backgroundColor: primarycolor,
//         leading: IconButton(
//             onPressed: () {
//               Navigator.pop(context);
//             },
//             icon: Icon(
//               Icons.arrow_back_ios,
//               color: Colors.white,
//             )),
//         title: Text(
//           "Edit Items ",
//           style: TextStyle(color: Colors.white),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Container(
//           child: Padding(
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               children: [
//                 CommonTextForm(
//                   controller: _nameController,
//                   borderc: 5,
//                   obsecureText: false,
//                   hintText: 'Item Name',
//                   HintColor: Colors.grey,
//                 ),
//
//                 SizedBox(
//                   height: 10,
//                 ),
//                 Row(
//                   children: [
//                     Text("Sold by: "),
//                     Radio<String>(
//                       value: 'Each',
//                       groupValue: option,
//                       onChanged: (value) {
//                         setState(() {
//                           option = value;
//                         });
//                       },
//                     ),
//                     Text('Each'),
//                     SizedBox(
//                       width: width * 0.1,
//                     ),
//                     Radio<String>(
//                       value: 'Weight',
//                       groupValue: option,
//                       onChanged: (value) {
//                         setState(() {
//                           option = value;
//                         });
//                       },
//                     ),
//                     Text('Weight'),
//                   ],
//                 ),
//
//                 SizedBox(
//                   height: 10,
//                 ),
//                 // price
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Container(
//                           // color: Colors.red,
//                           child: TextFormField(
//                         controller: _itemPriceController,
//                         decoration: InputDecoration(
//                             contentPadding: EdgeInsets.all(5),
//                             hintText: 'Item Price',
//                             border: UnderlineInputBorder(
//                                 borderRadius: BorderRadius.circular(5)),
//                             focusedBorder: outborder,
//                             focusedErrorBorder: outborder,
//                             errorBorder: outborder,
//                             disabledBorder: outborder,
//                             enabledBorder: outborder),
//                       )),
//                     ),
//                     SizedBox(width: 10),
//                     // veg - nonveg
//                     Expanded(
//                       child: InkWell(
//                         onTap: () {
//                           showModalBottomSheet(
//                             context: context,
//                             builder: (context) {
//                               return StatefulBuilder(
//                                 builder: (context, setModalState) {
//                                   return Column(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       Padding(
//                                         padding: const EdgeInsets.symmetric(
//                                             horizontal: 16, vertical: 12),
//                                         child: Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             Text(
//                                               'Select Type ',
//                                               style: TextStyle(
//                                                 fontSize: 18,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//                                             GestureDetector(
//                                               onTap: () =>
//                                                   Navigator.pop(context),
//                                               child: Icon(Icons.close),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Divider(thickness: 1),
//                                       Container(
//                                         margin: EdgeInsets.symmetric(
//                                             horizontal: 12, vertical: 6),
//                                         decoration: BoxDecoration(
//                                           border: Border.all(
//                                               color: Colors.black, width: 1),
//                                           borderRadius:
//                                               BorderRadius.circular(8),
//                                         ),
//                                         child: ListTile(
//                                           leading: Icon(Icons.circle,
//                                               color: Colors.green),
//                                           title: Text('Veg'),
//                                           onTap: () {
//                                             setState(() {
//                                               selectedIMGCategory = 'Veg';
//                                             });
//                                             Navigator.pop(context);
//                                           },
//                                         ),
//                                       ),
//                                       Container(
//                                         margin: EdgeInsets.symmetric(
//                                             horizontal: 12, vertical: 6),
//                                         decoration: BoxDecoration(
//                                           border: Border.all(
//                                               color: Colors.black, width: 1),
//                                           borderRadius:
//                                               BorderRadius.circular(8),
//                                         ),
//                                         child: ListTile(
//                                           leading: Icon(Icons.circle,
//                                               color: Colors.red),
//                                           title: Text('Non-Veg'),
//                                           onTap: () {
//                                             setState(() {
//                                               selectedIMGCategory = 'Non-Veg';
//                                             });
//                                             Navigator.pop(context);
//                                           },
//                                         ),
//                                       ),
//                                     ],
//                                   );
//                                 },
//                               );
//                             },
//                           );
//                         },
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                               horizontal: 12, vertical: 10),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey),
//                             borderRadius: BorderRadius.circular(3),
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Row(
//                                 children: [
//                                   // widget.items.isVeg=='Veg'?
//                                   //     selectedIMGCategory = 'Veg':
//                                   //     selectedIMGCategory = 'Non-Veg',
//
//                                   if (selectedIMGCategory == 'Veg') ...[
//                                     Icon(Icons.circle,
//                                         color: Colors.green, size: 16),
//                                     SizedBox(width: 6),
//                                     Text('Veg',
//                                         style: TextStyle(color: Colors.black)),
//                                   ] else if (selectedIMGCategory ==
//                                       'Non-Veg') ...[
//                                     Icon(Icons.circle,
//                                         color: Colors.red, size: 16),
//                                     SizedBox(width: 6),
//                                     Text('Non-Veg',
//                                         style: TextStyle(color: Colors.black)),
//                                   ],
//                                 ],
//                               ),
//                               Icon(Icons.keyboard_arrow_down_rounded),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     // Expanded(child:)
//                   ],
//                 ),
//                 SizedBox(
//                   height: 20,
//                 ),
//
//                 SizedBox(height: 10,),
//                 Container(
//                     height: height * 0.1,
//                     // padding: EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                         // color: Colors.red,
//
//                         border: Border.all(width: 0.5, color: Colors.black38)),
//                     child:
//                     CommonButton(
//
//                         height: height * 0.1,
//                         bgcolor: Colors.transparent,
//                         bordercolor: Colors.black12,
//                         bordercircular: 0,
//                         onTap: () async {
//                           // Reload the latest category list before showing the bottom sheet
//                           await loadHiveCategory();
//                           showModalBottomSheet(
//                               context: context,
//                               builder: (BuildContext context) {
//                                 return FutureBuilder(
//                                     future: loadHiveCategory(),
//                                     builder: (context, snapshot) {
//                                       return Container(
//                                         // color: Colors.red,
//                                         padding: EdgeInsets.all(20),
//                                         height:
//                                             categorieshive.isEmpty ? 300 : 500,
//                                         child: Column(
//                                           children: [
//                                             Row(
//                                               mainAxisAlignment:
//                                                   MainAxisAlignment
//                                                       .spaceBetween,
//                                               children: [
//                                                 Text(selectedCategory.toString(),
//                                                   style: GoogleFonts.poppins(
//                                                       fontSize: ResponsiveHelper
//                                                           .responsiveTextSize(
//                                                               context, 16),
//                                                       fontWeight:
//                                                           FontWeight.w600),
//                                                 ),
//                                                 IconButton(
//                                                     color: Colors.blue,
//                                                     onPressed: () {
//                                                       Navigator.pop(context);
//                                                     },
//                                                     icon: Icon(
//                                                       Icons.cancel,
//                                                       color: Colors.grey,
//                                                     ))
//                                               ],
//                                             ),
//                                             Divider(),
//                                             Expanded(
//                                                 child: categorieshive.isEmpty
//                                                     ? Container(
//                                                         padding:
//                                                             EdgeInsets.all(30),
//                                                         width: double.infinity,
//                                                         height: ResponsiveHelper
//                                                             .responsiveHeight(
//                                                                 context, 0.2),
//                                                         // color: Colors.green,
//                                                         child: Column(
//                                                           mainAxisAlignment:
//                                                               MainAxisAlignment
//                                                                   .spaceBetween,
//                                                           children: [
//                                                             Text(
//                                                               'No Category added yet!! Please \n add  category for your items',
//                                                               textScaler:
//                                                                   TextScaler
//                                                                       .linear(
//                                                                           1),
//                                                               style: GoogleFonts
//                                                                   .poppins(
//                                                                 fontSize: ResponsiveHelper
//                                                                     .responsiveTextSize(
//                                                                         context,
//                                                                         12),
//                                                               ),
//                                                               textAlign:
//                                                                   TextAlign
//                                                                       .center,
//                                                             ),
//                                                             CommonButton(
//                                                                 width: double
//                                                                     .infinity,
//                                                                 height: ResponsiveHelper
//                                                                     .responsiveHeight(
//                                                                         context,
//                                                                         0.08),
//                                                                 onTap: () {
//                                                                   showModalBottomSheet(
//                                                                       isScrollControlled:
//                                                                           true,
//                                                                       context:
//                                                                           context,
//                                                                       builder:
//                                                                           (BuildContext
//                                                                               context) {
//                                                                         return Padding(
//                                                                             padding:
//                                                                                 EdgeInsets.only(
//                                                                               bottom: MediaQuery.of(context).viewInsets.bottom,
//                                                                             ),
//                                                                             child: Container(
//                                                                               width: double.infinity,
//                                                                               height: ResponsiveHelper.responsiveHeight(context, 0.6),
//                                                                               padding: ResponsiveHelper.responsivePadding(
//                                                                                 context,
//                                                                               ),
//                                                                               child: Column(
//                                                                                 children: [
//                                                                                   Text(
//                                                                                     'Add Category',
//                                                                                     style: GoogleFonts.poppins(fontSize: ResponsiveHelper.responsiveTextSize(context, 20), fontWeight: FontWeight.w400),
//                                                                                   ),
//                                                                                   Divider(),
//                                                                                   Container(
//                                                                                     height: ResponsiveHelper.responsiveHeight(context, 0.08),
//                                                                                     child: TextField(
//                                                                                       controller: CategoryController,
//                                                                                       decoration: InputDecoration(
//                                                                                         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
//                                                                                         labelStyle: GoogleFonts.poppins(
//                                                                                           color: Colors.grey,
//                                                                                         ),
//                                                                                         border: OutlineInputBorder(),
//                                                                                         labelText: "Category Name (English)",
//                                                                                       ),
//                                                                                     ),
//                                                                                   ),
//                                                                                   SizedBox(height: 10),
//                                                                                   InkWell(
//                                                                                       onTap: _showImagePicker,
//                                                                                       child: Column(
//                                                                                         children: [
//                                                                                           Container(
//                                                                                               // color:Colors.red,
//                                                                                               height: ResponsiveHelper.responsiveHeight(context, 0.16),
//                                                                                               decoration: BoxDecoration(
//                                                                                                 border: Border.all(color: Colors.grey),
//                                                                                                 borderRadius: BorderRadius.circular(10),
//                                                                                               ),
//                                                                                               child: _selectedImage != null
//                                                                                                   ? Image.file(
//                                                                                                       _selectedImage!,
//                                                                                                       fit: BoxFit.cover,
//                                                                                                       height: 50,
//                                                                                                       width: 150,
//                                                                                                     )
//                                                                                                   : Column(
//                                                                                                       mainAxisAlignment: MainAxisAlignment.center,
//                                                                                                       children: [
//                                                                                                         Center(child: Icon(Icons.image, color: Colors.grey, size: 50)),
//                                                                                                         SizedBox(
//                                                                                                           height: 5,
//                                                                                                         ),
//                                                                                                         Text(
//                                                                                                           'Upload Image',
//                                                                                                           textScaler: TextScaler.linear(1),
//                                                                                                           style: GoogleFonts.poppins(fontSize: ResponsiveHelper.responsiveTextSize(context, 16), fontWeight: FontWeight.w500),
//                                                                                                         ),
//                                                                                                         Text(
//                                                                                                           '600X400',
//                                                                                                           textScaler: TextScaler.linear(1),
//                                                                                                           style: GoogleFonts.poppins(
//                                                                                                             fontSize: ResponsiveHelper.responsiveTextSize(context, 12),
//                                                                                                           ),
//                                                                                                         )
//                                                                                                       ],
//                                                                                                     )),
//                                                                                           Text(
//                                                                                             'Upload Image (png , .jpg, .jpeg) upto 3mb',
//                                                                                             textScaler: TextScaler.linear(1),
//                                                                                             style: GoogleFonts.poppins(
//                                                                                               fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
//                                                                                             ),
//                                                                                           )
//                                                                                         ],
//                                                                                       )),
//                                                                                   SizedBox(
//                                                                                     height: ResponsiveHelper.responsiveHeight(context, 0.02),
//                                                                                   ),
//                                                                                   CommonButton(
//                                                                                       onTap: () {
//                                                                                         _addcategoryHive();
//                                                                                       },
//                                                                                       // bgcolor: Colors.white,
//                                                                                       // bordercolor: Colors.deepOrange,
//                                                                                       width: ResponsiveHelper.responsiveWidth(context, 0.9),
//                                                                                       height: ResponsiveHelper.responsiveHeight(context, 0.07),
//                                                                                       child: Row(
//                                                                                         mainAxisAlignment: MainAxisAlignment.center,
//                                                                                         children: [
//                                                                                           Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.add)),
//                                                                                           SizedBox(
//                                                                                             width: 5,
//                                                                                           ),
//                                                                                           Text(
//                                                                                             'Add Category',
//                                                                                             style: GoogleFonts.poppins(fontSize: ResponsiveHelper.responsiveTextSize(context, 16), color: Colors.white),
//                                                                                           )
//                                                                                         ],
//                                                                                       )),
//                                                                                 ],
//                                                                               ),
//                                                                             ));
//                                                                       });
//                                                                 },
//                                                                 child: Padding(
//                                                                   padding:
//                                                                       const EdgeInsets
//                                                                           .all(
//                                                                           8.0),
//                                                                   child: Row(
//                                                                     mainAxisAlignment:
//                                                                         MainAxisAlignment
//                                                                             .center,
//                                                                     children: [
//                                                                       Container(
//                                                                         decoration: BoxDecoration(
//                                                                             borderRadius:
//                                                                                 BorderRadius.circular(15),
//                                                                             color: Colors.white),
//                                                                         child:
//                                                                             Icon(
//                                                                           Icons
//                                                                               .add,
//                                                                         ),
//                                                                       ),
//                                                                       SizedBox(
//                                                                         width: ResponsiveHelper.responsiveWidth(
//                                                                             context,
//                                                                             0.03),
//                                                                       ),
//                                                                       Text(
//                                                                         'Add New Category',
//                                                                         style: GoogleFonts.poppins(
//                                                                             color:
//                                                                                 Colors.white),
//                                                                       )
//                                                                     ],
//                                                                   ),
//                                                                 ))
//                                                           ],
//                                                         ),
//                                                       )
//
//                                                     : ListView.builder(
//                                                         itemCount:
//                                                             categorieshive
//                                                                 .length,
//                                                         itemBuilder:
//                                                             (context, index) {
//                                                           var category =
//                                                               categorieshive[
//                                                                   index];
//
//                                                           return InkWell(
//                                                             onTap: () {
//                                                               setState(() {
//                                                                 selectedCategory =
//                                                                     category
//                                                                         .name;
//                                                                 selectedCategoryId = category.id;
//                                                               });
//                                                               Navigator.pop(
//                                                                   context);
//                                                             },
//                                                             child: Container(
//                                                               child: Column(
//                                                                 children: [
//                                                                   Row(
//                                                                     mainAxisAlignment:
//                                                                         MainAxisAlignment
//                                                                             .spaceBetween,
//                                                                     children: [
//                                                                       Row(
//                                                                         children: [
//                                                                           Checkbox(
//                                                                               value: true,
//                                                                               onChanged: (value) {}),
//                                                                           Column(
//                                                                             crossAxisAlignment:
//                                                                                 CrossAxisAlignment.start,
//                                                                             children: [
//                                                                               Text(
//                                                                                 category.name,
//                                                                                 style: GoogleFonts.poppins(
//                                                                                   fontWeight: FontWeight.w600,
//                                                                                   fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
//                                                                                 ),
//                                                                               ),
//                                                                               Text(
//                                                                                 '0 Product Listed',
//                                                                                 style: GoogleFonts.poppins(fontSize: ResponsiveHelper.responsiveTextSize(context, 14), color: Colors.grey),
//                                                                               )
//                                                                             ],
//                                                                           ),
//                                                                         ],
//                                                                       ),
//                                                                       Row(
//                                                                         children: [
//                                                                           Container(
//                                                                             width:
//                                                                                 ResponsiveHelper.responsiveWidth(context, 0.1),
//                                                                             height:
//                                                                                 ResponsiveHelper.responsiveHeight(context, 0.04),
//                                                                             decoration:
//                                                                                 BoxDecoration(color: primarycolor, borderRadius: BorderRadius.circular(5)),
//                                                                             child:
//                                                                                 Icon(
//                                                                               Icons.edit,
//                                                                               color: Colors.white,
//                                                                             ),
//                                                                           ),
//                                                                           SizedBox(
//                                                                             width:
//                                                                                 5,
//                                                                           ),
//                                                                           Container(
//                                                                             width:
//                                                                                 ResponsiveHelper.responsiveWidth(context, 0.1),
//                                                                             height:
//                                                                                 ResponsiveHelper.responsiveHeight(context, 0.04),
//                                                                             decoration:
//                                                                                 BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
//                                                                             child:
//                                                                                 Icon(
//                                                                               Icons.delete,
//                                                                               color: Colors.white,
//                                                                             ),
//                                                                           ),
//                                                                         ],
//                                                                       )
//                                                                     ],
//                                                                   ),
//                                                                   Divider()
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                           );
//                                                         }))
//                                           ],
//                                         ),
//                                       );
//                                     });
//                               });
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 5),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 selectedCategory?? 'Select',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: ResponsiveHelper.responsiveTextSize(
//                                       context, 16),
//                                 ),
//                               ),
//                               Icon(Icons.arrow_forward_ios)
//                             ],
//                           ),
//                         ))),
//
//                 SizedBox(
//                   height: 10,
//                 ),
//
//                 /// manage inventory
//
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                   decoration:
//                       BoxDecoration(border: Border.all(color: Colors.grey)),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Manage Inventory",
//                         style: GoogleFonts.poppins(
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       Row(
//                         children: [
//                           Filterbutton(
//                             borderc: 0,
//                             title: 'YES',
//                             selectedFilter: selectedFilter,
//                             onpressed: () {
//                               setState(() {
//                                 IsYes = true;
//                                 selectedFilter = "YES";
//                               });
//                             },
//                           ),
//                           SizedBox(
//                             width: 10,
//                           ),
//                           Filterbutton(
//                             borderc: 0,
//                             title: 'NO',
//                             selectedFilter: selectedFilter,
//                             onpressed: () {
//                               setState(() {
//                                 IsYes = false;
//                                 selectedFilter = "NO";
//                               });
//                             },
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 IsYes == true
//                     ? Container(
//                         padding:
//                             EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                         decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey)),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               "select order when stock is not available ?",
//                               textScaler: TextScaler.linear(1.2),
//                               style: GoogleFonts.poppins(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Filterbutton(
//                                   borderc: 0,
//                                   title: 'YES',
//                                   selectedFilter: selectedFilter2,
//                                   onpressed: () {
//                                     setState(() {
//                                       IsYes = true;
//                                       selectedFilter2 = "YES";
//                                     });
//                                   },
//                                 ),
//                                 SizedBox(
//                                   width: 10,
//                                 ),
//                                 Filterbutton(
//                                   borderc: 0,
//                                   title: 'NO',
//                                   selectedFilter: selectedFilter2,
//                                   onpressed: () {
//                                     setState(() {
//                                       selectedFilter2 = "NO";
//                                     });
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       )
//                     : SizedBox(),
//
//                 /// picture uplode
//                 SizedBox(height: 10),
//                 InkWell(
//                     onTap: _showImagePicker,
//                     child: Column(
//                       children: [
//                         Container(
//                             // color:Colors.red,
//                             height: ResponsiveHelper.responsiveHeight(
//                                 context, 0.16),
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.grey),
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             child: _selectedImage != null
//                                 ? Image.file(
//                                     _selectedImage!,
//                                     fit: BoxFit.cover,
//                                     height: 50,
//                                     width: 150,
//                                   )
//                                 : Column(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Center(
//                                           child: Icon(Icons.image,
//                                               color: Colors.grey, size: 50)),
//                                       SizedBox(
//                                         height: 5,
//                                       ),
//                                       Text(
//                                         'Upload Image',
//                                         textScaler: TextScaler.linear(1),
//                                         style: GoogleFonts.poppins(
//                                             fontSize: ResponsiveHelper
//                                                 .responsiveTextSize(
//                                                     context, 16),
//                                             fontWeight: FontWeight.w500),
//                                       ),
//                                       Text(
//                                         '600X400',
//                                         textScaler: TextScaler.linear(1),
//                                         style: GoogleFonts.poppins(
//                                           fontSize: ResponsiveHelper
//                                               .responsiveTextSize(context, 12),
//                                         ),
//                                       )
//                                     ],
//                                   )),
//                       ],
//                     )),
//                 Text(
//                   'Upload Image (png , .jpg, .jpeg) upto 3mb',
//                   textScaler: TextScaler.linear(1),
//                   style: GoogleFonts.poppins(
//                     fontSize: ResponsiveHelper.responsiveTextSize(context, 12),
//                     color: Colors.grey,
//                   ),
//                 ),
//                 SizedBox(
//                   height: 10,
//                 ),
//
//                 /// for discription
//                 ///
//                 CommonTextForm(
//                   maxline: 2,
//                   controller: _descController,
//                   borderc: 5,
//                   obsecureText: false,
//                   hintText: 'Description (Optional)',
//                   HintColor: Colors.grey,
//                 ),
//                 SizedBox(
//                   height: 10,
//                 ),
//
//                 ///for varient
//                 variantList.isNotEmpty
//                 ?Card(
//                   child: Container(
//                     // color: Colors.red,
//                     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                     height: height * 0.3,
//                     width: width * 0.9,
//                     // color: Colors.grey,
//                     child: Container(
//                       // color: Colors.red,
//                       padding: EdgeInsets.symmetric(horizontal: 20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Varients",
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Divider(),
//
//                          Container(height: height  * 0.2,
//                            // color: Colors.grey,
//                            child: ListView.builder(
//                                itemCount: variantList.length,
//                                itemBuilder: (context, index){
//
//
//                                  return Container(
//                                    // color: Colors.red,
//                                    child:Row(
//                                      // crossAxisAlignment: CrossAxisAlignment.start,
//                                      mainAxisAlignment: MainAxisAlignment.start,
//                                      children: [
//                                        if(variantList.isNotEmpty)
//                                        Checkbox(
//
//                                          value: isCheckedList[index],
//                                          onChanged: (bool? value) {
//                                            setState(() {
//                                              isCheckedList[index] = value!;
//                                            });
//                                          },
//                                          activeColor: primarycolor,
//                                          checkColor: Colors.white,
//                                        ),
//                                        SizedBox(
//                                          width: 15,
//                                        ),
//                                        Container(
//                                          // color: Colors.red,
//                                            width: width * 0.2,
//                                            child: Text(variantList[index].name,textAlign: TextAlign.center,)),
//                                        SizedBox(
//                                          width: 20,
//                                        ),
//                                        SizedBox(
//                                          height: height * 0.06,
//                                          width: width * 0.3,
//                                          child: TextField(
//                                            controller: priceController[index],
//                                            decoration: InputDecoration(
//                                                labelText: "Price",
//                                                border: OutlineInputBorder(),
//                                                focusedBorder: OutlineInputBorder(
//                                                  borderSide: BorderSide(
//                                                      color: Colors.blue),
//                                                )),
//                                          ),
//                                        )
//                                      ],
//                                    ),
//                                  );
//
//                            }),
//                          )
//
//                          /* Container(
//                             // color: Colors.red,
//                             padding: EdgeInsets.all(10),
//                             child: Column(
//                               children: [
//                                 Row(
//                                   // crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     Checkbox(
//                                       value: isChecked,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isChecked = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                     SizedBox(
//                                       width: 15,
//                                     ),
//                                     Text("small"),
//                                     SizedBox(
//                                       width: 20,
//                                     ),
//                                     SizedBox(
//                                       height: height * 0.06,
//                                       width: width * 0.3,
//                                       child: TextField(
//                                         controller: _priceController,
//                                         decoration: InputDecoration(
//                                             labelText: "Price",
//                                             border: OutlineInputBorder(),
//                                             focusedBorder: OutlineInputBorder(
//                                               borderSide: BorderSide(
//                                                   color: Colors.blue),
//                                             )),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: 25,
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     Checkbox(
//                                       value: isCheckedone,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isCheckedone = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                     SizedBox(
//                                       width: 20,
//                                     ),
//                                     Text("mid"),
//                                     SizedBox(
//                                       width: 25,
//                                     ),
//                                     SizedBox(
//                                       height: height * 0.06,
//                                       width: width * 0.3,
//                                       child: TextField(
//                                         controller: _priceController,
//                                         decoration: InputDecoration(
//                                             labelText: "Price",
//                                             border: OutlineInputBorder(),
//                                             focusedBorder: OutlineInputBorder(
//                                               borderSide: BorderSide(
//                                                   color: Colors.blue),
//                                             )),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: 25,
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     Checkbox(
//                                       value: isCheckedtwo,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isCheckedtwo = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                     SizedBox(
//                                       width: 20,
//                                     ),
//                                     Text("big"),
//                                     SizedBox(
//                                       width: 25,
//                                     ),
//                                     SizedBox(
//                                       height: height * 0.06,
//                                       width: width * 0.3,
//                                       child: TextField(
//                                         controller: _priceController,
//                                         decoration: InputDecoration(
//                                             labelText: "Price",
//                                             border: OutlineInputBorder(),
//                                             focusedBorder: OutlineInputBorder(
//                                               borderSide: BorderSide(
//                                                   color: Colors.blue),
//                                             )),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: 25,
//                                 ),
//                               ],
//                             ),
//                           ),*/
//                         ],
//                       ),
//                     ),
//                   ),
//                 )
//                 :SizedBox(),
//
//                 ///for choice
//                 choiceList.isNotEmpty
//                 ?Card(
//                   child: Container(
//                     // color: Colors.red,
//                     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                     height: height * 0.3,
//                     width: width * 0.9,
//                     // color: Colors.grey,
//                     child: Container(
//                       // color: Colors.red,
//                       padding: EdgeInsets.symmetric(horizontal: 20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Choices",
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Divider(),
//
//                          Container(height: height  * 0.2,
//                            // color: Colors.grey,
//                            child: ListView.builder(
//                                itemCount: choiceList.length,
//                                itemBuilder: (context, index){
//                                  return Container(
//                                 child:
//                                 ListTile(
//                                   leading:  Checkbox(
//                                       value: isCheckedListChoice[index],
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isCheckedListChoice[index] = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                   title: Text(
//                                     choiceList[index].name,
//                                     style: GoogleFonts.poppins(fontSize: 16),
//                                   ),
//
//                                   subtitle: tempOptions.isNotEmpty
//                                       ? Padding(
//                                     padding: const EdgeInsets.only(top: 8),
//                                     child: Align(
//                                       alignment: Alignment.centerLeft,
//                                       child: Wrap(
//                                         spacing: 8,
//                                         runSpacing: 8,
//                                         children: tempOptions.asMap().entries.map((entry) {
//                                           final idx = entry.key;
//                                           final opt = entry.value;
//                                           return Container(
//                                             decoration: BoxDecoration(
//                                               color: Colors.red.shade100,
//                                               borderRadius: BorderRadius.circular(8),
//                                             ),
//                                             padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                                             child: Row(
//                                               mainAxisSize: MainAxisSize.min,
//                                               children: [
//                                                 Text(opt.name,
//                                                     style: GoogleFonts.poppins(fontSize: 14)),
//                                                 SizedBox(width: 4),
//                                                 GestureDetector(
//                                                   onTap: () {
//                                                     setState(() {
//                                                       tempOptions.removeAt(idx);
//                                                     });
//                                                   },
//                                                   child: Icon(Icons.delete,
//                                                       size: 18, color: Colors.redAccent),
//                                                 ),
//                                               ],
//                                             ),
//                                           );
//                                         }).toList(),
//                                       ),
//                                     ),
//                                   )
//                                       : SizedBox.shrink(),
//
//
//                                   // trailing:
//                                   trailing: Container(
//                                     width: 60,
//                                     child: Row(
//                                       children: [
//                                         SizedBox(
//                                           width: 5,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),   // color: Colors.red,
//                                    // child:Row(
//                                    //   // crossAxisAlignment: CrossAxisAlignment.start,
//                                    //   mainAxisAlignment: MainAxisAlignment.start,
//                                    //   children: [
//                                    //     if(variantList.isNotEmpty)
//                                    //     Checkbox(
//                                    //       value: isCheckedListChoice[index],
//                                    //       onChanged: (bool? value) {
//                                    //         setState(() {
//                                    //           isCheckedListChoice[index] = value!;
//                                    //         });
//                                    //       },
//                                    //       activeColor: primarycolor,
//                                    //       checkColor: Colors.white,
//                                    //     ),
//                                    //     SizedBox(
//                                    //       width: 15,
//                                    //     ),
//                                    //     Container(
//                                    //       // color: Colors.red,
//                                    //         width: width * 0.2,
//                                    //         child: Text(choiceList[index].name,textAlign: TextAlign.center,)),
//                                    //     SizedBox(
//                                    //       width: 20,
//                                    //     ),
//                                    //     SizedBox(
//                                    //       height: height * 0.06,
//                                    //       width: width * 0.3,
//                                    //       child: TextField(
//                                    //         controller: priceController[index],
//                                    //         decoration: InputDecoration(
//                                    //             labelText: "Price",
//                                    //             border: OutlineInputBorder(),
//                                    //             focusedBorder: OutlineInputBorder(
//                                    //               borderSide: BorderSide(
//                                    //                   color: Colors.blue),
//                                    //             )),
//                                    //       ),
//                                    //     )
//                                    //   ],
//                                    // ),
//                                  );
//
//                            }),
//                          )
//
//                          /* Container(
//                             // color: Colors.red,
//                             padding: EdgeInsets.all(10),
//                             child: Column(
//                               children: [
//                                 Row(
//                                   // crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     Checkbox(
//                                       value: isChecked,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isChecked = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                     SizedBox(
//                                       width: 15,
//                                     ),
//                                     Text("small"),
//                                     SizedBox(
//                                       width: 20,
//                                     ),
//                                     SizedBox(
//                                       height: height * 0.06,
//                                       width: width * 0.3,
//                                       child: TextField(
//                                         controller: _priceController,
//                                         decoration: InputDecoration(
//                                             labelText: "Price",
//                                             border: OutlineInputBorder(),
//                                             focusedBorder: OutlineInputBorder(
//                                               borderSide: BorderSide(
//                                                   color: Colors.blue),
//                                             )),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: 25,
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     Checkbox(
//                                       value: isCheckedone,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isCheckedone = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                     SizedBox(
//                                       width: 20,
//                                     ),
//                                     Text("mid"),
//                                     SizedBox(
//                                       width: 25,
//                                     ),
//                                     SizedBox(
//                                       height: height * 0.06,
//                                       width: width * 0.3,
//                                       child: TextField(
//                                         controller: _priceController,
//                                         decoration: InputDecoration(
//                                             labelText: "Price",
//                                             border: OutlineInputBorder(),
//                                             focusedBorder: OutlineInputBorder(
//                                               borderSide: BorderSide(
//                                                   color: Colors.blue),
//                                             )),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: 25,
//                                 ),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     Checkbox(
//                                       value: isCheckedtwo,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           isCheckedtwo = value!;
//                                         });
//                                       },
//                                       activeColor: primarycolor,
//                                       checkColor: Colors.white,
//                                     ),
//                                     SizedBox(
//                                       width: 20,
//                                     ),
//                                     Text("big"),
//                                     SizedBox(
//                                       width: 25,
//                                     ),
//                                     SizedBox(
//                                       height: height * 0.06,
//                                       width: width * 0.3,
//                                       child: TextField(
//                                         controller: _priceController,
//                                         decoration: InputDecoration(
//                                             labelText: "Price",
//                                             border: OutlineInputBorder(),
//                                             focusedBorder: OutlineInputBorder(
//                                               borderSide: BorderSide(
//                                                   color: Colors.blue),
//                                             )),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: 25,
//                                 ),
//                               ],
//                             ),
//                           ),*/
//                         ],
//                       ),
//                     ),
//                   ),
//                 )
//                 :SizedBox(),
//
//                 SizedBox(
//                   height: 10,
//                 ),
//                 CommonButton(
//                     height: height * 0.07,
//                     onTap: () {
//                       saveChnages();
//                     },
//                     child: Text('Save'))
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
