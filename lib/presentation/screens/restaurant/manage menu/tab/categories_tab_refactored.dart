import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_category.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:uuid/uuid.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../widget/componets/restaurant/componets/custom_category.dart';

/// ✅ REFACTORED: Now uses CategoryStore instead of direct Hive access
class CategoryTabRefactored extends StatefulWidget {
  const CategoryTabRefactored({super.key});

  @override
  State<CategoryTabRefactored> createState() => _CategoryTabRefactoredState();
}

class _CategoryTabRefactoredState extends State<CategoryTabRefactored> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Map<String, bool> toggleState = {};

  @override
  void initState() {
    super.initState();
    // ✅ Load categories from store on init
    categoryStore.loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // function to open bottom sheet
  void _showImagePicker() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: ResponsiveHelper.responsivePadding(context),
              width: double.infinity,
              height: ResponsiveHelper.responsiveHeight(context, 0.25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      alignment: Alignment.center,
                      width: ResponsiveHelper.responsiveWidth(context, 0.35),
                      height: ResponsiveHelper.responsiveHeight(context, 0.2),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 50,
                            color: AppColors.primary,
                          ),
                          const Text('From Gallery'),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: ResponsiveHelper.responsiveWidth(context, 0.35),
                    height: ResponsiveHelper.responsiveHeight(context, 0.2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 50,
                          color: AppColors.primary,
                        ),
                        const Text('From Search'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  // function for image pick
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
    Navigator.pop(context);
  }

  // clear image after refresh
  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _categoryController.clear();
    });
  }

  // ✅ REFACTORED: Add category using CategoryStore
  Future<void> _addCategory() async {
 /*   if (_categoryController.text.trim().isEmpty) {
      Navigator.pop(context);
      NotificationService.instance.showError(
        'Category name cannot be Empty',
      );
      return;
    }*/

    if (_categoryController.text.trim().isEmpty) {
      NotificationService.instance.showError('Category name cannot be Empty');
      return;
    }


    final newCategory = Category(
      imagePath: _selectedImage != null ? _selectedImage!.path : null,
      id: const Uuid().v4(),
      name: _categoryController.text.trim(),
      createdTime: DateTime.now(),
      lastEditedTime: DateTime.now(),
    );

    // ✅ Use store instead of direct Hive access
    final success = await categoryStore.addCategory(newCategory);

    if (success) {
      _clearImage();
      Navigator.pop(context);
      NotificationService.instance.showSuccess('Category added successfully');
    } else {
      NotificationService.instance.showError(
        categoryStore.errorMessage ?? 'Failed to add category',
      );
    }
  }

  // ✅ REFACTORED: Delete category using CategoryStore
  void _deleteCategory(String categoryId) async {
    final success = await categoryStore.deleteCategory(categoryId);

    if (success) {
      NotificationService.instance.showSuccess('Category deleted successfully');
    } else {
      NotificationService.instance.showError(
        categoryStore.errorMessage ?? 'Failed to delete category',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // search Category
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 5),
                    child: TextFormField(
                      controller: _searchController,
                      onChanged: (value) {
                        // ✅ Use store's search functionality
                        categoryStore.setSearchQuery(value);
                      },
                      decoration: InputDecoration(
                        hintText: "Search Category",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: ResponsiveHelper.responsiveTextSize(
                              context, 16),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(Icons.search, color: Colors.teal),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.02),
                  )
                ],
              ),

              // ✅ REFACTORED: Use Observer to reactively update UI
              Observer(
                builder: (_) {
                  // Show loading indicator
                  if (categoryStore.isLoading && categoryStore.categories.isEmpty) {
                    return Container(
                      height: ResponsiveHelper.responsiveHeight(context, 0.6),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // ✅ Use filtered categories from store
                  final categories = categoryStore.filteredCategories;

                  return Column(
                    children: [
                      categories.isEmpty
                          ? Container(
                              height: ResponsiveHelper.responsiveHeight(
                                  context, 0.6),
                              width: width,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Lottie.asset(
                                    AppImages.notfoundanimation,
                                    height: ResponsiveHelper.responsiveHeight(
                                        context, 0.3),
                                  ),
                                  Text(
                                    'No Category Found yet',
                                    style: GoogleFonts.poppins(
                                        fontSize: ResponsiveHelper.responsiveTextSize(
                                            context, 20),
                                        fontWeight: FontWeight.w500),
                                  )
                                ],
                              ),
                            )
                          : Container(
                              height: ResponsiveHelper.responsiveHeight(
                                  context, 0.6),
                              width: ResponsiveHelper.maxContentWidth(context),
                              child: ListView.builder(
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    var category = categories[index];

                                    // ✅ Get items from store's map
                                    final items = categoryStore
                                        .getItemsForCategory(category.id);

                                    toggleState.putIfAbsent(
                                        category.id, () => true);

                                    return Card(
                                      shape: const RoundedRectangleBorder(),
                                      child: Container(
                                          width: double.infinity,
                                          height:
                                              ResponsiveHelper.responsiveHeight(
                                                  context, 0.14),
                                          child: CustomCategory(
                                              imagePath: category.imagePath,
                                              itemCount:
                                                  items.length.toString(),
                                              title: category.name,
                                              isActive:
                                                  toggleState[category.id] ??
                                                      false,
                                              createdTime: category.createdTime,
                                              lastEditedTime:
                                                  category.lastEditedTime,
                                              editedBy: category.editedBy,
                                              editCount: category.editCount,
                                              onDelet: () {
                                                showDialog(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                          title: const Text(
                                                              'Delete Category'),
                                                          content: const Text(
                                                              "Are you sure want to delete this category and all its items?"),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: const Text(
                                                                  "Cancel"),
                                                            ),
                                                            TextButton(
                                                                onPressed: () {
                                                                  _deleteCategory(
                                                                      category
                                                                          .id);
                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                                child: const Text(
                                                                    'Delete',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .red)))
                                                          ],
                                                        ));
                                              },
                                              onEdit: () async {
                                                final result =
                                                    await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditCategory(
                                                      category: category,
                                                    ),
                                                  ),
                                                );

                                                if (result == true) {
                                                  // ✅ Refresh from store
                                                  categoryStore.refresh();
                                                }
                                              },
                                              onToggle: (value) {
                                                setState(() {
                                                  toggleState[category.id] =
                                                      value;
                                                });
                                              })),
                                    );
                                  }),
                            )
                    ],
                  );
                },
              ),

              // Button Add Category
              CommonButton(
                  width: ResponsiveHelper.responsiveWidth(context, 0.5),
                  height: ResponsiveHelper.responsiveHeight(context, 0.06),
                  onTap: () {
                    showModalBottomSheet(
                        isScrollControlled: true,
                        context: context,
                        builder: (BuildContext context) {
                          return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Container(
                                width: double.infinity,
                                height: ResponsiveHelper.responsiveHeight(
                                    context, 0.6),
                                padding: ResponsiveHelper.responsivePadding(
                                  context,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Add Category',
                                      style: GoogleFonts.poppins(
                                          fontSize: ResponsiveHelper
                                              .responsiveTextSize(context, 20),
                                          fontWeight: FontWeight.w400),
                                    ),
                                    const Divider(),
                                    Container(
                                      height: ResponsiveHelper.responsiveHeight(
                                          context, 0.08),
                                      child: TextField(
                                        controller: _categoryController,
                                        decoration: InputDecoration(
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(2)),
                                          labelStyle: GoogleFonts.poppins(
                                            color: Colors.grey,
                                          ),
                                          border: const OutlineInputBorder(),
                                          labelText: "Category Name (English)",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                        onTap: _showImagePicker,
                                        child: Column(
                                          children: [
                                            Container(
                                                height: ResponsiveHelper
                                                    .responsiveHeight(
                                                        context, 0.16),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: _selectedImage != null
                                                    ? Image.file(
                                                        _selectedImage!,
                                                        fit: BoxFit.cover,
                                                        height: 50,
                                                        width: 150,
                                                      )
                                                    : Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          const Center(
                                                              child: Icon(
                                                                  Icons.image,
                                                                  color: Colors
                                                                      .grey,
                                                                  size: 50)),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          Text(
                                                            'Upload Image',
                                                            textScaler:
                                                                const TextScaler
                                                                    .linear(1),
                                                            style: GoogleFonts.poppins(
                                                                fontSize: ResponsiveHelper
                                                                    .responsiveTextSize(
                                                                        context,
                                                                        16),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                          Text(
                                                            '600X400',
                                                            textScaler:
                                                                const TextScaler
                                                                    .linear(1),
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: ResponsiveHelper
                                                                  .responsiveTextSize(
                                                                      context,
                                                                      12),
                                                            ),
                                                          )
                                                        ],
                                                      )),
                                            Text(
                                              'Upload Image (png , .jpg, .jpeg) upto 3mb',
                                              textScaler:
                                                  const TextScaler.linear(1),
                                              style: GoogleFonts.poppins(
                                                fontSize: ResponsiveHelper
                                                    .responsiveTextSize(
                                                        context, 14),
                                              ),
                                            )
                                          ],
                                        )),
                                    SizedBox(
                                      height: ResponsiveHelper.responsiveHeight(
                                          context, 0.02),
                                    ),
                                    CommonButton(
                                        onTap: () {
                                          _addCategory();
                                        },
                                        width: ResponsiveHelper.responsiveWidth(
                                            context, 0.9),
                                        height:
                                            ResponsiveHelper.responsiveHeight(
                                                context, 0.07),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                                decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: const Icon(Icons.add)),
                                            const SizedBox(
                                              width: 5,
                                            ),
                                            Text(
                                              'Add Category',
                                              style: GoogleFonts.poppins(
                                                  fontSize: ResponsiveHelper
                                                      .responsiveTextSize(
                                                          context, 16),
                                                  color: Colors.white),
                                            )
                                          ],
                                        )),
                                  ],
                                ),
                              ));
                        });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        child: const Icon(Icons.add),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        'Add Category',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize:
                              ResponsiveHelper.responsiveTextSize(context, 16),
                        ),
                      )
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
