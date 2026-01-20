import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart' show EdititemScreen;
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';

/// ✅ REFACTORED: Now uses ItemStore and CategoryStore instead of direct Hive access
class ItemsTabRefactored extends StatefulWidget {
  final String? selectedCategory;

  const ItemsTabRefactored({
    super.key,
    this.selectedCategory,
  });

  @override
  State<ItemsTabRefactored> createState() => _ItemsTabRefactoredState();
}

class _ItemsTabRefactoredState extends State<ItemsTabRefactored> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ✅ Load items and categories from stores
    itemStore.loadItems();
    categoryStore.loadCategories();

    // ✅ Apply category filter if provided
    if (widget.selectedCategory != null) {
      itemStore.setCategoryFilter(widget.selectedCategory);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ✅ REFACTORED: Delete item using ItemStore
  void _deleteItem(String id) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await itemStore.deleteItem(id);
      if (success) {
        NotificationService.instance.showSuccess('Item deleted successfully');
      } else {
        NotificationService.instance.showError(
          itemStore.errorMessage ?? 'Failed to delete item',
        );
      }
    }
  }

  // ✅ REFACTORED: Toggle item status using ItemStore
  void _toggleItemStatus(String itemId, bool currentValue) async {
    final success = await itemStore.toggleItemStatus(itemId);
    if (!success) {
      NotificationService.instance.showError(
        itemStore.errorMessage ?? 'Failed to update item status',
      );
    }
  }

  void _editItem(Items itemToEdit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EdititemScreen(items: itemToEdit),
      ),
    );
    // ✅ Refresh items after editing
    itemStore.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          // ✅ Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                // ✅ Use store's search functionality
                itemStore.setSearchQuery(value);
              },
              decoration: InputDecoration(
                hintText: "Search Items",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
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

          // ✅ Filter chips
          Observer(
            builder: (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  // Veg filter
                  FilterChip(
                    label: const Text('Veg'),
                    selected: itemStore.vegFilter == 'Veg',
                    onSelected: (selected) {
                      itemStore.setVegFilter(selected ? 'Veg' : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Non-veg filter
                  FilterChip(
                    label: const Text('Non-Veg'),
                    selected: itemStore.vegFilter == 'Non-Veg',
                    onSelected: (selected) {
                      itemStore.setVegFilter(selected ? 'Non-Veg' : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Enabled filter
                  FilterChip(
                    label: const Text('Enabled'),
                    selected: itemStore.enabledFilter == true,
                    onSelected: (selected) {
                      itemStore.setEnabledFilter(selected ? true : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Low stock filter
                  FilterChip(
                    label: Text('Low Stock (${itemStore.lowStockCount})'),
                    selected: itemStore.showLowStockOnly,
                    onSelected: (_) {
                      itemStore.toggleLowStockFilter();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ✅ REFACTORED: Use Observer to reactively update UI
          Observer(
            builder: (_) {
              // Show loading indicator
              if (itemStore.isLoading && itemStore.items.isEmpty) {
                return Container(
                  height: height * 0.6,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // ✅ Use filtered items from store
              final items = itemStore.filteredItems;

              // Show empty state
              if (items.isEmpty) {
                return Container(
                  height: height * 0.6,
                  width: width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        AppImages.notfoundanimation,
                        height: height * 0.3,
                      ),
                      Text(
                        'No such items Found!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (itemStore.searchQuery.isNotEmpty ||
                          itemStore.selectedCategoryId != null ||
                          itemStore.vegFilter != null ||
                          itemStore.enabledFilter != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextButton.icon(
                            onPressed: () {
                              itemStore.clearAllFilters();
                              searchController.clear();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Filters'),
                          ),
                        ),
                    ],
                  ),
                );
              }

              // Show items list
              return Container(
                height: height * 0.6,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    // ✅ Get category name from CategoryStore
                    final category = categoryStore.getCategoryById(
                      item.categoryOfItem ?? '',
                    );
                    final categoryName = category?.name ?? 'Unknown';

                    return Card(
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.name,
                                  textScaler: const TextScaler.linear(1),
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.circle,
                                  color: item.isVeg == 'Veg'
                                      ? Colors.green
                                      : Colors.red,
                                  size: 10,
                                ),
                              ],
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                activeThumbColor: Colors.white,
                                activeTrackColor: AppColors.primary,
                                inactiveThumbColor: Colors.white70,
                                inactiveTrackColor: Colors.grey.shade400,
                                value: item.isEnabled,
                                onChanged: (bool value) {
                                  // ✅ Use store to toggle status
                                  _toggleItemStatus(item.id, value);
                                },
                              ),
                            )
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                            // Audit trail display
                            if (item.createdTime != null ||
                                AuditTrailHelper.hasBeenEdited(item))
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4.0,
                                  bottom: 4.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.createdTime != null)
                                      Text(
                                        'Created: ${item.createdTime!.day}/${item.createdTime!.month}/${item.createdTime!.year} ${item.createdTime!.hour}:${item.createdTime!.minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    if (AuditTrailHelper.hasBeenEdited(item))
                                      Text(
                                        'Edited ${item.editCount} time(s) • Last: ${item.lastEditedTime!.day}/${item.lastEditedTime!.month}/${item.lastEditedTime!.year} ${item.lastEditedTime!.hour}:${item.lastEditedTime!.minute.toString().padLeft(2, '0')}${item.editedBy != null ? ' by ${item.editedBy}' : ''}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Price display
                                Text(
                                  "${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // Action buttons
                                Row(
                                  children: [
                                    const Icon(Icons.qr_code),
                                    const SizedBox(width: 3),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      height: 30,
                                      width: 30,
                                      child: InkWell(
                                        onTap: () => _editItem(item),
                                        child: const Icon(
                                          Icons.mode_edit_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    InkWell(
                                      onTap: () => _deleteItem(item.id),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        height: 30,
                                        width: 30,
                                        child: const Icon(Icons.delete),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}