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
import 'package:unipos/util/common/app_responsive.dart';
import 'package:uuid/uuid.dart';
import '../../../../../constants/restaurant/color.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          height: AppResponsive.height(context, 0.25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImageSourceOption(
                icon: Icons.photo_library,
                label: 'From Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              _buildImageSourceOption(
                icon: Icons.search,
                label: 'From Search',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: AppResponsive.width(context, 0.35),
        height: AppResponsive.height(context, 0.18),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
    Navigator.pop(context);
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _categoryController.clear();
    });
  }

  Future<void> _addcategoryHive() async {
    if (_categoryController.text.trim().isEmpty) {
      Navigator.pop(context);
      NotificationService.instance.showError('Category name cannot be Empty');
      return;
    }

    final newcategory = Category(
      imagePath: _selectedImage != null ? _selectedImage!.path : null,
      id: const Uuid().v4(),
      name: _categoryController.text.trim(),
    );

    await categoryStore.addCategory(newcategory);
    _clearImage();
    Navigator.pop(context);
  }

  void _deleteCategoryhive(dynamic id) async {
    await categoryStore.deleteCategory(id);
  }

  void _showAddCategoryBottomSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.category, color: AppColors.primary),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Add New Category',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Divider(height: 30),
                TextField(
                  controller: _categoryController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Category Name",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.edit, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                InkWell(
                  onTap: _showImagePicker,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  color: Colors.grey.shade400, size: 50),
                              SizedBox(height: 10),
                              Text(
                                'Upload Image',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '600 x 400 • PNG, JPG (Max 3MB)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _addcategoryHive,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Add Category',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _getGridColumns(double width) {
    if (width > 1200) return 4;
    else if (width > 900) return 3;
    else return 2;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Search categories...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Categories List
          Expanded(
            child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout(size),
          ),

          // Add Category Button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Observer(
      builder: (_) {
        final categories = categoryStore.categories.toList();
        final allItems = itemStore.items.toList();
        final filteredCategories = _getFilteredCategories(categories);

        if (filteredCategories.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredCategories.length,
          itemBuilder: (context, index) {
            var category = filteredCategories[index];
            final items = allItems
                .where((item) => item.categoryOfItem == category.id)
                .toList();
            return _buildCategoryCard(category, items, isGrid: false);
          },
        );
      },
    );
  }

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final categories = categoryStore.categories.toList();
        final allItems = itemStore.items.toList();
        final filteredCategories = _getFilteredCategories(categories);

        if (filteredCategories.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridColumns(size.width),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
          ),
          itemCount: filteredCategories.length,
          itemBuilder: (context, index) {
            var category = filteredCategories[index];
            final items = allItems
                .where((item) => item.categoryOfItem == category.id)
                .toList();
            return _buildCategoryCard(category, items, isGrid: true);
          },
        );
      },
    );
  }

  List<Category> _getFilteredCategories(List<Category> categories) {
    return query.isEmpty
        ? categories
        : categories.where((cat) {
            final name = cat.name.toLowerCase();
            final queryLower = query.toLowerCase();
            return name.contains(queryLower);
          }).toList();
  }

  Widget _buildEmptyState(double height) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(AppImages.notfoundanimation, height: height * 0.25),
          SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No Categories Found' : 'No matching categories',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (query.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Start by adding your first category',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Category category, List items, {required bool isGrid}) {
    return Card(
      margin: isGrid ? EdgeInsets.zero : EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isGrid ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Row(
              children: [
                // Category Image or Icon
                Container(
                  width: isGrid ? 50 : 60,
                  height: isGrid ? 50 : 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: category.imagePath != null &&
                          File(category.imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(category.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.category,
                          color: AppColors.primary,
                          size: isGrid ? 25 : 30,
                        ),
                ),
                SizedBox(width: isGrid ? 12 : 16),

                // Category Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.poppins(
                          fontSize: isGrid ? 15 : 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${items.length} items',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!isGrid) SizedBox(height: 12),

            // Action Buttons
            Padding(
              padding: EdgeInsets.only(top: isGrid ? 12 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditCategory(category: category),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            if (!isGrid) ...[
                              SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _showDeleteDialog(category);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            if (!isGrid) ...[
                              SizedBox(width: 6),
                              Text(
                                'Delete',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Audit Trail (only in mobile view)
            if (!isGrid &&
                (category.createdTime != null ||
                    AuditTrailHelper.hasBeenEdited(category)))
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.createdTime != null)
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          SizedBox(width: 4),
                          Text(
                            'Created: ${category.createdTime!.day}/${category.createdTime!.month}/${category.createdTime!.year} ${category.createdTime!.hour}:${category.createdTime!.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    if (AuditTrailHelper.hasBeenEdited(category))
                      Padding(
                        padding: EdgeInsets.only(
                            top: category.createdTime != null ? 4 : 0),
                        child: Row(
                          children: [
                            Icon(Icons.edit,
                                size: 12, color: Colors.orange.shade700),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Edited ${category.editCount} time(s) • Last: ${category.lastEditedTime!.day}/${category.lastEditedTime!.month}/${category.lastEditedTime!.year}${category.editedBy != null ? ' by ${category.editedBy}' : ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Category category) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Category',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete this category and all its items?",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              _deleteCategoryhive(category.id);
              Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _showAddCategoryBottomSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, color: AppColors.primary, size: 20),
              ),
              SizedBox(width: 10),
              Text(
                'Add Category',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}