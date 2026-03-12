import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unipos/util/color.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

/// Category Management Screen
/// Allows users to view, add, edit, and delete categories with images
/// Uses store pattern for reactive state management
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<Category> _categories = [];
  Map<String, int> _itemCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    try {
      // Load data from stores
      await categoryStore.loadCategories();
      await itemStore.loadItems();

      // Get categories from store
      _categories = categoryStore.categories.toList();

      // Count items per category
      _itemCounts.clear();
      for (final category in _categories) {
        final count = itemStore.items.where((item) => item.categoryOfItem == category.id).length;
        _itemCounts[category.id] = count;
      }
    } catch (e) {
      print('Error loading categories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Category>(
      context: context,
      builder: (context) => const AddCategoryDialog(),
    );

    if (result != null) {
      NotificationService.instance.showSuccess('Category "${result.name}" added successfully!');
      _loadCategories();
    }
  }

  Future<void> _editCategory(Category category) async {
    final result = await showDialog<Category>(
      context: context,
      builder: (context) => AddCategoryDialog(existingCategory: category),
    );

    if (result != null) {
      NotificationService.instance.showSuccess('Category "${result.name}" updated successfully!');
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final itemCount = _itemCounts[category.id] ?? 0;

    if (itemCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Cannot Delete',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'This category has $itemCount item${itemCount > 1 ? 's' : ''}. Please reassign or delete the items first.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Category?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await categoryStore.deleteCategory(category.id);

        if (success) {
          NotificationService.instance.showSuccess('Category "${category.name}" deleted');
          _loadCategories();
        } else {
          NotificationService.instance.showError('Error deleting category: ${categoryStore.errorMessage ?? "Unknown error"}');
        }
      } catch (e) {
        NotificationService.instance.showError('Error deleting category: $e');
      }
    }
  }

  void _selectCategory(Category category) {
    Navigator.pop(context, category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.black),
        //   onPressed: () => Navigator.pop(context),
        // ),
        title: Text(
          'Category Management',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, color: AppColors.primary, size: 28),
            onPressed: _addCategory,
            tooltip: 'Add New Category',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : _buildCategoryList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add,color: AppColors.white),
        label: Text(
          'Add Category',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600,color: AppColors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 100, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No Categories Yet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add your first category to organize your menu items',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            // const SizedBox(height: 30),
            // CommonButton(
            //   onTap: _addCategory,
            //   bgcolor: AppColors.primary,
            //   bordercircular: 10,
            //   height: 50,
            //   width: 200,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       const Icon(Icons.add, color: Colors.white),
            //       const SizedBox(width: 10),
            //       Text(
            //         'Add Category',
            //         style: GoogleFonts.poppins(
            //           color: Colors.white,
            //           fontWeight: FontWeight.w600,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final itemCount = _itemCounts[category.id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _selectCategory(category),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  // Category Image or Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    child: category.imagePath != null && category.imagePath!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(category.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.category, color: AppColors.primary, size: 30);
                              },
                            ),
                          )
                        : Icon(Icons.category, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(width: 15),

                  // Category Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount item${itemCount != 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editCategory(category),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(category),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Add/Edit Category Dialog
class AddCategoryDialog extends StatefulWidget {
  final Category? existingCategory;

  const AddCategoryDialog({Key? key, this.existingCategory}) : super(key: key);

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _uuid = const Uuid();

  File? _selectedImage;
  String? _existingImagePath;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCategory != null) {
      _isEditing = true;
      _nameController.text = widget.existingCategory!.name;
      _existingImagePath = widget.existingCategory!.imagePath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _existingImagePath = null;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _existingImagePath = null;
    });
  }

  Future<String?> _saveImageToLocalStorage(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final categoryImagesDir = Directory('${directory.path}/category_images');

      if (!await categoryImagesDir.exists()) {
        await categoryImagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'category_$timestamp.jpg';
      final savedImage = await imageFile.copy('${categoryImagesDir.path}/$fileName');

      return savedImage.path;
    } catch (e) {
      print('Error saving category image: $e');
      return null;
    }
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // Save image if new one selected
        String? imagePath = _existingImagePath;
        if (_selectedImage != null) {
          imagePath = await _saveImageToLocalStorage(_selectedImage!);
        }

        final category = Category(
          id: _isEditing ? widget.existingCategory!.id : _uuid.v4(),
          name: _nameController.text.trim(),
          imagePath: imagePath,
          createdTime: _isEditing ? widget.existingCategory!.createdTime : DateTime.now(),
          editCount: _isEditing ? widget.existingCategory!.editCount + 1 : 0,
        );

        // Save using store
        final bool success;
        if (_isEditing) {
          success = await categoryStore.updateCategory(category);
        } else {
          success = await categoryStore.addCategory(category);
        }

        // Close loading
        if (mounted) Navigator.pop(context);

        if (success) {
          // Return result
          if (mounted) Navigator.pop(context, category);
        } else {
          // Show error
          if (mounted) {
            NotificationService.instance.showError('Error saving category: ${categoryStore.errorMessage ?? "Unknown error"}');
          }
        }
      } catch (e) {
        // Close loading
        if (mounted) Navigator.pop(context);

        // Show error
        NotificationService.instance.showError('Error saving category: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.category_outlined,
                        color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Category' : 'Add New Category',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Category Name ───────────────────────────────────
                _sectionHeader('Category Name', Icons.label_outline_rounded),
                const SizedBox(height: 12),
                _card(
                  child: AppTextField(
                    controller: _nameController,
                    label: 'Category Name',
                    hint: 'e.g., Beverages, Starters',
                    icon: Icons.category_outlined,
                    required: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Category name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── Category Image ──────────────────────────────────
                _sectionHeader(
                    'Category Image (Optional)', Icons.image_outlined),
                const SizedBox(height: 12),
                _card(child: _buildImagePicker()),
                const SizedBox(height: 24),

                // ── Buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: CommonButton(
                        onTap: () => Navigator.pop(context),
                        bgcolor: Colors.white,
                        bordercolor: Colors.grey[300],
                        bordercircular: 10,
                        height: 50,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CommonButton(
                        onTap: _saveCategory,
                        bgcolor: AppColors.primary,
                        bordercircular: 10,
                        height: 50,
                        child: Text(
                          _isEditing ? 'Update' : 'Add',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _selectedImage != null || _existingImagePath != null;
    if (hasImage) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _selectedImage != null
                ? Image.file(_selectedImage!,
                    height: 150, width: double.infinity, fit: BoxFit.cover)
                : Image.file(
                    File(_existingImagePath!),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to upload image',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            Text(
              'From Gallery',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
