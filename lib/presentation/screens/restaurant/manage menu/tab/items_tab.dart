import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart' show EdititemScreen;
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

class ItemsTab extends StatefulWidget {
  final String? selectedCategory;

  const ItemsTab({
    super.key,
    this.selectedCategory,
  });

  @override
  State<ItemsTab> createState() => _AllTabState();
}

class _AllTabState extends State<ItemsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    // CRITICAL: Fetch fresh item from store instead of using cached object
    // This ensures we always have the latest data from Hive
    final freshItem = itemStore.getItemById(itemToEdit.id);

    if (freshItem == null) {
      // Item was deleted
      if (mounted) {
        NotificationService.instance.showError('Item not found');
      }
      return;
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EdititemScreen(items: freshItem)),
      );
    }
  }

  int _getGridColumns(double width) {
    if (width > 1200) return 4;
    else if (width > 900) return 3;
    else return 2;
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              controller: searchController,
              hint: 'Search items…',
              icon: Icons.search_rounded,
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                  : null,
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
              NotificationService.instance.showSuccess('Item added successfully!');
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

        // Filter items by search query and selected category
        final filteredItems = allItem.where((item) {
          final matchesQuery = query.isEmpty ||
              item.name.toLowerCase().contains(query.toLowerCase());
          final matchesCategory = widget.selectedCategory == null ||
              item.categoryOfItem == widget.selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(AppImages.notfoundanimation, height: size.height * 0.25),
                SizedBox(height: 16),
                Text(
                  query.isEmpty && widget.selectedCategory == null
                      ? 'No Items Found!'
                      : 'No matching items',
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

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: item.isEnabled ? Colors.grey.shade200 : Colors.red.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main row: name + price + veg tag + switch
                          Row(
                            children: [
                              // Veg/Non-veg icon
                              Container(
                                width: 16,
                                height: 16,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: item.isVeg == 'Veg' ? Colors.green : Colors.red.shade800, width: 1.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Center(
                                  child: item.isVeg == 'Veg'
                                      ? Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle))
                                      : CustomPaint(size: Size(8, 8), painter: _TrianglePainter(color: Colors.red.shade800)),
                                ),
                              ),
                              // Name + category + price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    SizedBox(height: 2),
                                    Text(
                                      '$categoryName  •  ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}',
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions: edit, delete, switch
                              InkWell(
                                onTap: () => editItems(item),
                                child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue)),
                              ),
                              InkWell(
                                onTap: () => _deleteItem(item.id),
                                child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 18, color: Colors.red)),
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
                          // Audit trail — compact single line
                          if (AuditTrailHelper.hasBeenEdited(item))
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Edited ${item.editCount}x • ${item.lastEditedTime!.day}/${item.lastEditedTime!.month}/${item.lastEditedTime!.year}${item.editedBy != null ? ' by ${item.editedBy}' : ''}',
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
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

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final allItem = itemStore.items.toList();
        final categorybox = categoryStore.categories;

        // Filter items by search query and selected category
        final filteredItems = allItem.where((item) {
          final matchesQuery = query.isEmpty ||
              item.name.toLowerCase().contains(query.toLowerCase());
          final matchesCategory = widget.selectedCategory == null ||
              item.categoryOfItem == widget.selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(AppImages.notfoundanimation, height: size.height * 0.25),
                SizedBox(height: 16),
                Text(
                  query.isEmpty && widget.selectedCategory == null
                      ? 'No Items Found!'
                      : 'No matching items',
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
            childAspectRatio: 2.8,
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

            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: item.isEnabled ? Colors.grey.shade200 : Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + veg icon + switch
                  Row(
                    children: [
                      Container(
                        width: 16, height: 16,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: item.isVeg == 'Veg' ? Colors.green : Colors.red.shade800, width: 1.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
                          child: item.isVeg == 'Veg'
                              ? Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle))
                              : CustomPaint(size: Size(8, 8), painter: _TrianglePainter(color: Colors.red.shade800)),
                        ),
                      ),
                      Expanded(
                        child: Text(item.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          activeColor: Colors.white, activeTrackColor: Colors.green,
                          inactiveThumbColor: Colors.white70, inactiveTrackColor: Colors.red.shade300,
                          value: item.isEnabled,
                          onChanged: (bool value) async => await itemStore.toggleItemStatus(item.id),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  // Category + price + actions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$categoryName  •  ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(onTap: () => editItems(item), child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit_outlined, size: 15, color: Colors.blue))),
                      InkWell(onTap: () => _deleteItem(item.id), child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, size: 15, color: Colors.red))),
                    ],
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

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}