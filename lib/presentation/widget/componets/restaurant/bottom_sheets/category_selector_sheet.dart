import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../core/di/service_locator.dart';
import '../componets/Button.dart';
import 'package:unipos/util/color.dart';
/// Result from category selection
class CategorySelectionResult {
  final String id;
  final String name;

  CategorySelectionResult({required this.id, required this.name});
}

/// Bottom sheet for selecting a category
class CategorySelectorSheet extends StatefulWidget {
  final String? selectedCategoryId;
  final Function(CategorySelectionResult) onCategorySelected;
  final VoidCallback onAddCategory;

  const CategorySelectorSheet({
    super.key,
    this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onAddCategory,
  });

  /// Show the category selector and return the selected category
  static Future<CategorySelectionResult?> show(
    BuildContext context, {
    String? selectedCategoryId,
    required VoidCallback onAddCategory,
  }) async {
    CategorySelectionResult? result;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return CategorySelectorSheet(
          selectedCategoryId: selectedCategoryId,
          onCategorySelected: (category) {
            result = category;
            Navigator.pop(context);
          },
          onAddCategory: onAddCategory,
        );
      },
    );

    return result;
  }

  @override
  State<CategorySelectorSheet> createState() => _CategorySelectorSheetState();
}

class _CategorySelectorSheetState extends State<CategorySelectorSheet> {
  List<Category> _categories = [];
  List<Items> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = categoryStore.categories.toList();
    final items = itemStore.items.toList();

    setState(() {
      _categories = categories;
      _items = items;
      _isLoading = false;
    });
  }

  int _getItemCount(String categoryId) {
    return _items.where((item) => item.categoryOfItem == categoryId).length;
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text('Are you sure you want to delete "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await categoryStore.deleteCategory(category.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty) {
      return _buildEmptyState();
    }

    return _buildCategoryList();
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No Category added yet! Please add category for your items',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 20),
          _buildAddCategoryButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 500,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select a Category',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel, color: Colors.grey),
              )
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final itemCount = _getItemCount(category.id);
                return _buildCategoryItem(category, itemCount);
              },
            ),
          ),
          _buildAddCategoryButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Category category, int itemCount) {
    final isSelected = widget.selectedCategoryId == category.id;

    return InkWell(
      onTap: () {
        widget.onCategorySelected(
          CategorySelectionResult(id: category.id, name: category.name),
        );
      },
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      widget.onCategorySelected(
                        CategorySelectionResult(id: category.id, name: category.name),
                      );
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'} Added',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      )
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: () => _deleteCategory(category),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                ],
              )
            ],
          ),
          const Divider()
        ],
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return CommonButton(
      width: double.infinity,
      height: 50,
      onTap: widget.onAddCategory,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 10),
          Text(
            'Add New Category',
            style: GoogleFonts.poppins(color: Colors.white),
          )
        ],
      ),
    );
  }
}
