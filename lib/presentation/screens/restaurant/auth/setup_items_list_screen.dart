import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart';

/// Full-detail item list opened from the Setup Wizard "View Added Items" banner.
/// Shows every item in itemStore with variants, choices, extras, stock, tax.
/// Each item has an edit button that pushes [EdititemScreen].
class SetupItemsListScreen extends StatefulWidget {
  const SetupItemsListScreen({super.key});

  @override
  State<SetupItemsListScreen> createState() => _SetupItemsListScreenState();
}

class _SetupItemsListScreenState extends State<SetupItemsListScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    itemStore.loadItems();
    categoryStore.loadCategories();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _categoryName(String? id) {
    if (id == null) return '—';
    try {
      return categoryStore.categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return '—';
    }
  }

  List<Items> _filtered(List<Items> all) {
    if (_query.isEmpty) return all;
    return all.where((item) {
      return item.name.toLowerCase().contains(_query) ||
          _categoryName(item.categoryOfItem).toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Observer(builder: (_) {
              if (itemStore.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = _filtered(itemStore.items.toList());
              if (itemStore.items.isEmpty) return _buildEmptyState();
              if (items.isEmpty) return _buildNoResults();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: items.length,
                itemBuilder: (context, index) => _ItemCard(
                    item: items[index],
                    categoryName: _categoryName(items[index].categoryOfItem)),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name or category…',
          hintStyle: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _searchFocus.unfocus();
                  },
                  child: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 52,
              color: AppColors.textSecondary.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Text('No items match "$_query"',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _searchController.clear(),
            child: Text('Clear search',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Observer(
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Menu Items',
                style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text('${itemStore.items.length} item(s) in database',
                style: GoogleFonts.poppins(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No items added yet',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Go back and add your first item',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Item Card ────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Items item;
  final String categoryName;

  const _ItemCard({required this.item, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final isVeg = (item.isVeg ?? 'Veg') == 'Veg';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Veg / Non-veg indicator
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isVeg ? AppColors.success : AppColors.danger,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isVeg ? AppColors.success : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(categoryName,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),

                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${item.price?.toStringAsFixed(2) ?? '—'}',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    if (item.taxRate != null && item.taxRate! > 0)
                      Text(
                          'Tax ${(item.taxRate! * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          // ── Chips row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.trackInventory)
                  _chip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock: ${item.stockQuantity.toStringAsFixed(0)}',
                    color: item.stockQuantity > 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                if ((item.variant?.isNotEmpty ?? false))
                  _chip(
                    icon: Icons.tune,
                    label: '${item.variant!.length} Variants',
                    color: Colors.deepPurple,
                  ),
                if ((item.choiceIds?.isNotEmpty ?? false))
                  _chip(
                    icon: Icons.checklist,
                    label: '${item.choiceIds!.length} Choices',
                    color: Colors.teal,
                  ),
                if ((item.extraId?.isNotEmpty ?? false))
                  _chip(
                    icon: Icons.add_circle_outline,
                    label: '${item.extraId!.length} Extras',
                    color: Colors.orange,
                  ),
                if (item.isSoldByWeight)
                  _chip(
                    icon: Icons.scale,
                    label: 'By Weight (${item.unit ?? ''})',
                    color: Colors.brown,
                  ),
                if (!item.isEnabled)
                  _chip(
                    icon: Icons.block,
                    label: 'Disabled',
                    color: AppColors.danger,
                  ),
              ],
            ),
          ),

          // ── Variant detail ───────────────────────────────────────────
          if (item.variant?.isNotEmpty ?? false)
            _buildVariantRow(item.variant!),

          // ── Divider + edit button ───────────────────────────────────
          const Divider(height: 1, color: AppColors.divider),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => EdititemScreen(items: item)),
              );
              // Reload after edit
              await itemStore.loadItems();
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text('Edit Item',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantRow(List<dynamic> variants) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: variants.map((v) {
          final name = (v as ItemVariante).variantId;
          final price = '₹${v.price.toStringAsFixed(2)}';
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.2)),
            ),
            child: Text(
              price.isNotEmpty ? '$name · $price' : name,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
