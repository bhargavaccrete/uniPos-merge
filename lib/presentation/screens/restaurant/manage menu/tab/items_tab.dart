import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart' show EdititemScreen;
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';
import 'package:unipos/util/common/currency_helper.dart';

class ItemsTab extends StatefulWidget {
  final String? selectedCategory;

  const ItemsTab({
    super.key,
    this.selectedCategory,
  });

  @override
  State<ItemsTab> createState() => _AllTabState();
}

class _AllTabState extends State<ItemsTab> {
  TextEditingController searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() {
        query = searchController.text;
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _deleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this item?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await itemStore.deleteItem(id);
    }
  }

  void editItems(Items itemToEdit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EdititemScreen(items: itemToEdit)),
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
    final height = size.height;
    final width = size.width;

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
                controller: searchController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Search items...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () {
                            searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Items List
          Expanded(
            child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout(size),
          ),

          // Bottom Sheet Menu
          BottomsheetMenu(
            onCategorySelected: (category) {
              setState(() {});
            },
            onItemAdded: () {
              // Show success feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Item added successfully!',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Observer(
      builder: (_) {
        final allItem = itemStore.items.toList();
        final categorybox = categoryStore.categories;

        // Filter items by search query
        final filteredItems = query.isEmpty
            ? allItem
            : allItem.where((item) {
                final name = item.name.toLowerCase();
                final queryLower = query.toLowerCase();
                return name.contains(queryLower);
              }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(AppImages.notfoundanimation, height: size.height * 0.25),
                SizedBox(height: 16),
                Text(
                  query.isEmpty ? 'No Items Found!' : 'No matching items',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (query.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Try searching with different keywords',
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

        return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final categoryName = categorybox
                        .firstWhere(
                          (cat) => cat.id == item.categoryOfItem,
                          orElse: () => Category(id: '', name: 'Unknown'),
                        )
                        .name;

                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: item.isEnabled ? Colors.grey.shade200 : Colors.red.shade100,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                // Item Icon
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: item.isEnabled
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    color: item.isEnabled ? Colors.green : Colors.red,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),

                                // Item Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: item.isVeg == 'Veg'
                                                  ? Colors.green.withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: item.isVeg == 'Veg' ? Colors.green : Colors.red,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              item.isVeg == 'Veg' ? 'Veg' : 'Non-Veg',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: item.isVeg == 'Veg' ? Colors.green : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                                          SizedBox(width: 4),
                                          Text(
                                            categoryName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Toggle Switch
                                Transform.scale(
                                  scale: 0.9,
                                  child: Switch(
                                    activeColor: Colors.white,
                                    activeTrackColor: Colors.green,
                                    inactiveThumbColor: Colors.white70,
                                    inactiveTrackColor: Colors.red.shade300,
                                    value: item.isEnabled,
                                    onChanged: (bool value) async {
                                      await itemStore.toggleItemStatus(item.id);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Audit Trail Info
                            if (item.createdTime != null || AuditTrailHelper.hasBeenEdited(item))
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
                                    if (item.createdTime != null)
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                          SizedBox(width: 4),
                                          Text(
                                            'Created: ${item.createdTime!.day}/${item.createdTime!.month}/${item.createdTime!.year} ${item.createdTime!.hour}:${item.createdTime!.minute.toString().padLeft(2, '0')}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (AuditTrailHelper.hasBeenEdited(item))
                                      Padding(
                                        padding: EdgeInsets.only(top: item.createdTime != null ? 4 : 0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 12, color: Colors.orange.shade700),
                                            SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Edited ${item.editCount} time(s) • Last: ${item.lastEditedTime!.day}/${item.lastEditedTime!.month}/${item.lastEditedTime!.year} ${item.lastEditedTime!.hour}:${item.lastEditedTime!.minute.toString().padLeft(2, '0')}${item.editedBy != null ? ' by ${item.editedBy}' : ''}',
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

                            // Footer Row (Price and Actions)
                            Container(
                              margin: EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Price Tag
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.currency_rupee,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        Text(
                                          "${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // QR Code Icon
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.qr_code, size: 20, color: Colors.grey.shade700),
                                      ),
                                      SizedBox(width: 8),

                                      // Edit Button
                                      InkWell(
                                        onTap: () => editItems(item),
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                        ),
                                      ),
                                      SizedBox(width: 8),

                                      // Delete Button
                                      InkWell(
                                        onTap: () => _deleteItem(item.id),
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
  }

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final allItem = itemStore.items.toList();
        final categorybox = categoryStore.categories;

        // Filter items by search query
        final filteredItems = query.isEmpty
            ? allItem
            : allItem.where((item) {
                final name = item.name.toLowerCase();
                final queryLower = query.toLowerCase();
                return name.contains(queryLower);
              }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(AppImages.notfoundanimation, height: size.height * 0.25),
                SizedBox(height: 16),
                Text(
                  query.isEmpty ? 'No Items Found!' : 'No matching items',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (query.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Try searching with different keywords',
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

        final columns = _getGridColumns(size.width);
        final isTablet = size.width > 600;

        return GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            // childAspectRatio: isTablet ? 1.0 : 0.75,
            childAspectRatio:1.5,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final categoryName = categorybox
                .firstWhere(
                  (cat) => cat.id == item.categoryOfItem,
                  orElse: () => Category(id: '', name: 'Unknown'),
                )
                .name;

            return Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: item.isEnabled ? Colors.grey.shade200 : Colors.red.shade100,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isTablet ? 8 : 10),
                    decoration: BoxDecoration(
                      color: item.isEnabled
                          ? Colors.green.withOpacity(0.05)
                          : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 6 : 8),
                              decoration: BoxDecoration(
                                color: item.isEnabled
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.restaurant_menu,
                                color: item.isEnabled ? Colors.green : Colors.red,
                                size: isTablet ? 18 : 20,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                activeColor: Colors.white,
                                activeTrackColor: Colors.green,
                                inactiveThumbColor: Colors.white70,
                                inactiveTrackColor: Colors.red.shade300,
                                value: item.isEnabled,
                                onChanged: (bool value) async {
                                  await itemStore.toggleItemStatus(item.id);
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 6 : 8),
                        Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 8 : 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: item.isVeg == 'Veg'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: item.isVeg == 'Veg' ? Colors.green : Colors.red,
                                ),
                              ),
                              child: Text(
                                item.isVeg == 'Veg' ? 'Veg' : 'Non-Veg',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: item.isVeg == 'Veg' ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.category, size: 11, color: Colors.grey.shade600),
                            SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                categoryName,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 8 : 10),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.currency_rupee, size: 13, color: AppColors.primary),
                              Text(
                                "${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}",
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 13 : 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: EdgeInsets.all(isTablet ? 6 : 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () => editItems(item),
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 5 : 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.edit_outlined, size: isTablet ? 15 : 16, color: Colors.blue),
                          ),
                        ),
                        InkWell(
                          onTap: () => _deleteItem(item.id),
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 5 : 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.delete_outline, size: isTablet ? 15 : 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}