import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Category Management Screen
/// Allows users to view, add, edit, and delete categories with images
/// Uses store pattern for reactive state management
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
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
      await itemStore.ensureLoaded();

      // Get categories from store
      _categories = categoryStore.categories.toList();

      // Count items per category
      _itemCounts.clear();
      for (final category in _categories) {
        final count = itemStore.items
            .where((item) => item.categoryOfItem == category.id)
            .length;
        _itemCounts[category.id] = count;
      }
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Category>(
      context: context,
      useRootNavigator: false, // stays inside the wizard's pane
      builder: (context) => const AddCategoryDialog(),
    );

    if (result != null) {
      NotificationService.instance.showSuccess(
        'Category "${result.name}" added successfully!',
      );
      _loadCategories();
    }
  }

  Future<void> _editCategory(Category category) async {
    final result = await showDialog<Category>(
      context: context,
      useRootNavigator: false, // stays inside the wizard's pane
      builder: (context) => AddCategoryDialog(existingCategory: category),
    );

    if (result != null) {
      NotificationService.instance.showSuccess(
        'Category "${result.name}" updated successfully!',
      );
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final itemCount = _itemCounts[category.id] ?? 0;

    // Used to refuse outright while the category held items, asking the user to
    // reassign them by hand. The delete no longer destroys anything, so it just
    // states where those items land.
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Delete Category?',
      message: itemCount > 0
          ? 'Delete "${category.name}"? $itemCount '
                'item${itemCount > 1 ? 's' : ''} will be moved to '
                'Uncategorized. Nothing is deleted.'
          : 'Are you sure you want to delete "${category.name}"?',
      confirmLabel: 'Delete',
      accent: Colors.red,
      icon: Icons.delete_rounded,
    );

    if (confirm == true) {
      try {
        final success = await categoryStore.deleteCategory(category.id);

        if (success) {
          NotificationService.instance.showSuccess(
            'Category "${category.name}" deleted',
          );
          _loadCategories();
        } else {
          NotificationService.instance.showError(
            'Error deleting category: ${categoryStore.errorMessage ?? "Unknown error"}',
          );
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
      appBar: buildPrimaryAppBar(
        title: 'Category Management',
        titleFontSize: AppResponsive.subheadingFontSize(context),
        actions: const [],
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        maxWidth: AppResponsive.maxContentWidth(context),
        alignment: Alignment.topCenter,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
            ? _buildEmptyState()
            : _buildCategoryList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text(
          'Add Category',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          AppResponsive.getValue(
            context,
            mobile: 40.0,
            tablet: 48.0,
            desktop: 56.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: AppResponsive.getValue(
                context,
                mobile: 100.0,
                tablet: 120.0,
                desktop: 140.0,
              ),
              color: Colors.grey[300],
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text(
              'No Categories Yet',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              'Add your first category to organize your menu items',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: Colors.grey[500],
              ),
            ),
            // const SizedBox(height: 30),
            // CommonButton(
            //   onTap: _addCategory,
            //   bgcolor: AppColors.primary,
            //   bordercircular: 10,
            //   height: AppResponsive.buttonHeight(context),
            //   width: 200,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       const Icon(Icons.add, color: Colors.white),
            //       SizedBox(width: AppResponsive.smallSpacing(context)),
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
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.largeSpacing(context),
        vertical: AppResponsive.mediumSpacing(context),
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final itemCount = _itemCounts[category.id] ?? 0;

        return Container(
          margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => _selectCategory(category),
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context),
              ),
              child: Row(
                children: [
                  // Category Image or Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: AppResponsive.iconSize(context),
                    ),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),

                  // Category Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.name,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$itemCount item${itemCount != 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Compact action buttons
                  GestureDetector(
                    onTap: () => _editCategory(category),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context),
                        ),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.blue,
                        size: AppResponsive.smallIconSize(context),
                      ),
                    ),
                  ),
                  SizedBox(width: AppResponsive.smallSpacing(context)),
                  GestureDetector(
                    onTap: () => _deleteCategory(category),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context),
                        ),
                      ),
                      child: Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                        size: AppResponsive.smallIconSize(context),
                      ),
                    ),
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
  final _uuid = const Uuid();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCategory != null) {
      _isEditing = true;
      _nameController.text = widget.existingCategory!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      // Duplicate name check (case-insensitive, exclude self when editing)
      final trimmedName = _nameController.text.trim().toLowerCase();
      final duplicate = categoryStore.categories.any(
        (c) =>
            c.name.trim().toLowerCase() == trimmedName &&
            c.id != (widget.existingCategory?.id ?? ''),
      );
      if (duplicate) {
        NotificationService.instance.showError(
          'A category with this name already exists',
        );
        return;
      }

      try {
        // Show loading
        showDialog(
          context: context,
          useRootNavigator: false, // stays inside the wizard's pane
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        final category = Category(
          id: _isEditing ? widget.existingCategory!.id : _uuid.v4(),
          name: _nameController.text.trim(),
          createdTime: _isEditing
              ? widget.existingCategory!.createdTime
              : DateTime.now(),
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
            NotificationService.instance.showError(
              'Error saving category: ${categoryStore.errorMessage ?? "Unknown error"}',
            );
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
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      color: AppColors.primary,
                      size: AppResponsive.iconSize(context),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Category' : 'Add New Category',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: AppResponsive.iconSize(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // ── Category Name ───────────────────────────────────
                _sectionHeader('Category Name', Icons.label_outline_rounded),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
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
                SizedBox(height: AppResponsive.extraLargeSpacing(context)),

                // ── Buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: CommonButton(
                        onTap: () => Navigator.pop(context),
                        bgcolor: Colors.white,
                        bordercolor: Colors.grey[300],
                        bordercircular: 10,
                        height: AppResponsive.buttonHeight(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppResponsive.mediumSpacing(context)),
                    Expanded(
                      child: CommonButton(
                        onTap: _saveCategory,
                        bgcolor: AppColors.primary,
                        bordercircular: 10,
                        height: AppResponsive.buttonHeight(context),
                        child: Text(
                          _isEditing ? 'Update' : 'Add',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: AppResponsive.buttonFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
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
        Icon(
          icon,
          color: AppColors.primary,
          size: AppResponsive.iconSize(context),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
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
}
