
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/images.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';
import '../../../../../util/restaurant/restaurant_session.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();

  /// Only admin and manager can add, edit, or delete categories.
  bool get _canEdit => RestaurantSession.isAdmin || RestaurantSession.staffRole == 'Manager';
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


  @override
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: AppResponsive.padding(context),
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

          // Add Category Button — only shown to Admin/Manager
          if (_canEdit) _buildAddButton(),
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
          padding: AppResponsive.padding(context),
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
          padding: AppResponsive.padding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppResponsive.gridColumns(context, mobile: 2, tablet: 3, desktop: 4),
            crossAxisSpacing: AppResponsive.gridSpacing(context),
            mainAxisSpacing: AppResponsive.gridSpacing(context),
            // Lower ratio = taller cells, so the card content never bottom-overflows.
            childAspectRatio: AppResponsive.getValue(context, mobile: 3.0, tablet: 2.6, desktop: 3.0),
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
      margin: isGrid ? EdgeInsets.zero : EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      // Grid cells have a fixed (short) height — keep vertical padding tight there.
      padding: isGrid
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isGrid ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Main row: name + item count + actions
          Row(
            children: [
              // Compact plain icon in the short grid cells; tinted box in the list.
              if (isGrid)
                Icon(Icons.category_rounded, color: AppColors.primary, size: AppResponsive.iconSize(context))
              else
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                  ),
                  child: Icon(Icons.category_rounded, color: AppColors.primary, size: AppResponsive.iconSize(context)),
                ),
              SizedBox(width: isGrid ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.name, style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${items.length} items', style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Actions inline — edit & delete only for Admin/Manager
              if (_canEdit) ...[
                InkWell(
                  onTap: () => AddCategoryDialog.show(context, editCategory: category),
                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary)),
                ),
                InkWell(
                  onTap: () => _showDeleteDialog(category),
                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red)),
                ),
              ],
              if (items.isNotEmpty)
                Builder(builder: (_) {
                  final allEnabled = items.every((i) => i.isEnabled);
                  return InkWell(
                    onTap: () => _bulkToggleCategory(category.id, items),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        allEnabled ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: AppResponsive.smallIconSize(context),
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
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
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
    return Container(
      padding: AppResponsive.padding(context),
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
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showAddCategoryBottomSheet,
            icon: Icon(Icons.add, size: AppResponsive.iconSize(context)),
            label: Text('Add Category', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: AppResponsive.mediumSpacing(context)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }
}