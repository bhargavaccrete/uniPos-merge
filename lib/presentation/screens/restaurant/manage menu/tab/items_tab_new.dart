/*
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart';
import 'package:unipos/presentation/widget/componets/restaurant/common/generic_tab_manager.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';

/// 🎯 NEW ITEMS TAB - USING GENERIC TAB MANAGER
///
/// Compare this to the old items_tab.dart:
/// - OLD: 600+ lines with duplicate search/delete/edit logic
/// - NEW: 150 lines focused only on Items-specific configuration
///
/// **Learning Goal**: See how much simpler code becomes with reusable components!

class ItemsTabNew extends StatelessWidget {
  final String? selectedCategory;

  const ItemsTabNew({
    Key? key,
    this.selectedCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure items are loaded
    print('🚀 ItemsTabNew: Building tab, itemStore has ${itemStore.items.length} items');

    return GenericTabManager<Items>(
      config: TabConfig<Items>(
        // 1. DATA SOURCE: Where to get items from (MobX observable)
        getItems: () {
          final items = itemStore.items.toList();
          print('📦 ItemsTabNew: Returning ${items.length} items from itemStore');
          return items;
        },

        // 2. ACTIONS: What to do when user interacts
        onDelete: (id) => itemStore.deleteItem(id),
        onEdit: (item) => EdititemScreen(items: item),
        getItemId: (item) => item.id,

        // 3. DISPLAY: How to show items
        searchHint: 'Search items...',
        emptyMessage: 'No items found',
        itemBuilder: (item, onEdit, onDelete) => _buildItemCard(
          context,
          item,
          onEdit,
          onDelete,
        ),

        // 4. FILTERING: How to search items
        // TODO(human): Implement this function below!
        filterItems: _filterItems,

        // 5. ADD BUTTON: Floating action button
        floatingActionButton: BottomsheetMenu(
          onCategorySelected: (category) {
            // Handle category selection if needed
          },
          onItemAdded: () {
            // Show success message
          },
        ),
      ),
    );
  }

  /// TODO(human): IMPLEMENT THIS FILTERING FUNCTION
  ///
  /// This is your hands-on learning task! Implement the item filtering logic.
  ///
  /// **Context**: When users type in the search bar, we need to filter the items
  /// to show only those that match the query. Items should match if the query
  /// appears in the item name or category name.
  ///
  /// **Your Task**: Implement the filtering logic below.
  ///
  /// **Guidance**:
  /// - If query is empty, return all items
  /// - Otherwise, filter items where:
  ///   - item.name contains the query (case-insensitive), OR
  ///   - item category name contains the query (case-insensitive)
  /// - Use .toLowerCase() to make it case-insensitive
  /// - Use .contains() to check if text includes the query
  /// - You'll need to get the category name from categoryStore.categories
  ///
  /// **Hint**: Look at the old items_tab.dart for reference, or try:
  /// ```dart
  /// return items.where((item) {
  ///   // Your filtering logic here
  /// }).toList();
  /// ```



  static List<Items> _filterItems(List<Items> items, String query) {
    print('🔍 _filterItems: Filtering ${items.length} items with query "$query"');

    // Early return if no search query
    if (query.isEmpty) {
      print('✅ _filterItems: No query, returning all ${items.length} items');
      return items;
    }

    final queryLower = query.toLowerCase();

    final filtered = items.where((item) {
      // Check if item name matches
      final name = item.name.toLowerCase();
      final nameMatches = name.contains(queryLower);

      // Check if category name matches
      final category = categoryStore.categories.firstWhere(
        (cat) => cat.id == item.categoryOfItem,
        orElse: () => Category(
          id: '',
          name: '',
          createdTime: DateTime.now(),
          editCount: 0,
        ),
      );
      final categoryName = category.name.toLowerCase();
      final categoryMatches = categoryName.contains(queryLower);

      // Return true if either name OR category matches
      return nameMatches || categoryMatches;
    }).toList();

    print('✅ _filterItems: Returning ${filtered.length} filtered items');
    return filtered;
  }

  /// Builds the card UI for each item
  /// This is Items-specific - shows name, price, category, image, etc.
  Widget _buildItemCard(
    BuildContext context,
    Items item,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    // Get category name - use fallback if not found (defensive programming!)
    final category = categoryStore.categories.firstWhere(
      (cat) => cat.id == item.categoryOfItem,
      orElse: () => Category(
        id: '',
        name: 'Uncategorized',
        createdTime: DateTime.now(),
        editCount: 0,
      ),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image (fixed height instead of Expanded)
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                // Image
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: item.imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.memory(
                            item.imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.fastfood,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),

                // Veg/Non-Veg indicator
                if (item.isVeg != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.circle,
                        size: 12,
                        color: item.isVeg?.toLowerCase() == 'veg'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),

                // Action buttons
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.edit,
                        color: Colors.blue,
                        onTap: onEdit,
                      ),
                      SizedBox(width: 4),
                      _buildActionButton(
                        icon: Icons.delete,
                        color: Colors.red,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Item Details (fixed height instead of Expanded)
          SizedBox(
            height: 120,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Item Name
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),

                  // Category
                  Text(
                    category.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Price (no Spacer, using mainAxisAlignment instead)
                  Row(
                    children: [
                      Text(
                        '${CurrencyHelper.currentSymbol}${item.price?.toStringAsFixed(2) ?? '0.00'}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (item.hasVariants)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '+',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: Builds action buttons (Edit/Delete)
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
*/
