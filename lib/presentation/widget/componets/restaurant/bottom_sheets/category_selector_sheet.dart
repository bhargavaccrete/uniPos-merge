import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../presentation/screens/restaurant/manage%20menu/tab/edit_category.dart';
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

  static Future<CategorySelectionResult?> show(
    BuildContext context, {
    String? selectedCategoryId,
    required VoidCallback onAddCategory,
  }) async {
    CategorySelectionResult? result;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _categories = categoryStore.categories.toList();
      _items = itemStore.items.toList();
      _isLoading = false;
    });
  }

  int _getItemCount(String categoryId) =>
      _items.where((i) => i.categoryOfItem == categoryId).length;

  List<Category> get _filtered {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.toLowerCase();
    return _categories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Category?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Delete "${category.name}"? This cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await categoryStore.deleteCategory(category.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.category_outlined,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Category',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('${_categories.length} categories available',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // ── Search ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  hintText: 'Search categories...',
                  hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.primary, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 18, color: Colors.grey),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // ── List ─────────────────────────────────────────────────────────
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_categories.isEmpty)
            _buildEmptyState()
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No categories match "$_query"',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) =>
                    _buildCategoryItem(_filtered[i], _getItemCount(_filtered[i].id)),
              ),
            ),

          // ── Add New Category button ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onAddCategory,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('Add New Category',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No Categories Yet',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Add a category to organise your menu items.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Category category, int itemCount) {
    final isSelected = widget.selectedCategoryId == category.id;

    return InkWell(
      onTap: () => widget.onCategorySelected(
        CategorySelectionResult(id: category.id, name: category.name),
      ),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Leading icon or check
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? Icons.check_rounded : Icons.category_outlined,
                size: 18,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Name + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            // Edit / Delete actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn(
                  icon: Icons.edit_outlined,
                  color: AppColors.primary,
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditCategory(category: category),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red,
                  onTap: () => _deleteCategory(category),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}