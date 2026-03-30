
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  final TextEditingController _searchController = TextEditingController();
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
    super.dispose();
  }

  void _deleteCategoryhive(dynamic id) async {
    // Cascade-delete all items belonging to this category first
    final itemsToDelete = itemStore.items
        .where((item) => item.categoryOfItem == id)
        .map((item) => item.id)
        .toList();
    for (final itemId in itemsToDelete) {
      await itemStore.deleteItem(itemId);
    }
    await categoryStore.deleteCategory(id);
  }

  Future<void> _showAddCategoryBottomSheet() async {
    await AddCategoryDialog.show(context);
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
          Padding(
            padding: const EdgeInsets.all(10),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search categories…',
              icon: Icons.search_rounded,
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
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
            crossAxisSpacing: 12,
            mainAxisSpacing: 8,
            childAspectRatio: 3.5,
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

  Widget _buildCategoryCard(Category category, List<Items> items, {required bool isGrid}) {
    return Container(
      margin: isGrid ? EdgeInsets.zero : EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isGrid ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Main row: name + item count + actions
          Row(
            children: [
              Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${items.length} items', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              // Actions inline
              InkWell(
                onTap: () => AddCategoryDialog.show(context, editCategory: category),
                child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue)),
              ),
              InkWell(
                onTap: () => _showDeleteDialog(category),
                child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 18, color: Colors.red)),
              ),
              if (items.isNotEmpty)
                Builder(builder: (_) {
                  final allEnabled = items.every((i) => i.isEnabled);
                  return InkWell(
                    onTap: () => _bulkToggleCategory(category.id, items),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        allEnabled ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: allEnabled ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                  );
                }),
            ],
          ),
          // Audit trail — compact (mobile only)
          if (!isGrid && AuditTrailHelper.hasBeenEdited(category))
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Edited ${category.editCount}x • ${category.lastEditedTime!.day}/${category.lastEditedTime!.month}/${category.lastEditedTime!.year}${category.editedBy != null ? ' by ${category.editedBy}' : ''}',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bulk toggle ──────────────────────────────────────────────────────────────

  Future<void> _bulkToggleCategory(
      String categoryId, List<Items> items) async {
    // Enable all if any disabled; disable all if every item is enabled
    final anyDisabled = items.any((i) => !i.isEnabled);
    for (final item in items.where((i) => i.isEnabled != anyDisabled)) {
      await itemStore.toggleItemStatus(item.id);
    }
  }


  void _showDeleteDialog(Category category) {
    final itemCount = itemStore.items.where((i) => i.categoryOfItem == category.id).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete "${category.name}"?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(
          itemCount > 0
              ? 'This will also delete $itemCount item${itemCount > 1 ? 's' : ''} in this category.'
              : 'This category has no items.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () { _deleteCategoryhive(category.id); Navigator.pop(context); },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showAddCategoryBottomSheet,
          icon: Icon(Icons.add, size: 20),
          label: Text('Add Category', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}