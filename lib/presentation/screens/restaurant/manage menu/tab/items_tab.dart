import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/categorymodel_300.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart' show EdititemScreen;
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/images.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';
import '../../../../../util/restaurant/restaurant_session.dart';
import '../../../../../util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';

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

  /// Only admin and manager can add, edit, or delete items.
  /// Cashier can only toggle item enabled/disabled.
  bool get _canEdit => RestaurantSession.isAdmin || RestaurantSession.staffRole == 'Manager';

  // Action entitlements layered on top of the role check (plan can withhold add/
  // edit/delete even for an admin). The store also enforces these for non-UI callers.
  // Visibility = role only; plan entitlement is enforced on the action (add via
  // the add-item screen, edit/delete below) so denied actions show the blocker.
  bool get _canAddItem => _canEdit;
  bool get _canEditItem => _canEdit;
  bool get _canDeleteItem => _canEdit;

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
    if (!PlanGuard.allowedOr(context, EntKeys.manageMenuItemsDelete, featureName: 'Delete Items')) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Item',
      message: 'Are you sure you want to delete this item?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      await itemStore.deleteItem(id);
    }
  }

  void editItems(Items itemToEdit) async {
    if (!PlanGuard.allowedOr(context, EntKeys.manageMenuItemsEdit, featureName: 'Edit Items')) return;
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

          // Bottom Sheet Menu — Add Item bar (admin/manager + add entitlement).
          if (_canAddItem)
            BottomsheetMenu(
              onCategorySelected: (category) {
                setState(() {});
              },
              onItemAdded: () {
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
              item.name.toLowerCase().contains(query.toLowerCase()) ||
              (item.itemCode != null && item.itemCode!.toLowerCase().contains(query.toLowerCase()));
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
                  padding: AppResponsive.padding(context),
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
                      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
                      padding: AppResponsive.cardPadding(context),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: AppResponsive.shadowBlurRadius(context),
                            offset: Offset(0, 2),
                          ),
                        ],
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
                                    Text(
                                      item.name,
                                      style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item.itemCode != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${item.itemCode}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '$categoryName  •  ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}',
                                      style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions: edit & delete (Admin/Manager only), switch (all roles)
                              if (_canEditItem)
                                InkWell(
                                  onTap: () => editItems(item),
                                  child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary)),
                                ),
                              if (_canDeleteItem)
                                InkWell(
                                  onTap: () => _deleteItem(item.id),
                                  child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red)),
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
              item.name.toLowerCase().contains(query.toLowerCase()) ||
              (item.itemCode != null && item.itemCode!.toLowerCase().contains(query.toLowerCase()));
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

        return GridView.builder(
          padding: AppResponsive.padding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppResponsive.gridColumns(context, mobile: 2, tablet: 3, desktop: 4),
            crossAxisSpacing: AppResponsive.gridSpacing(context),
            mainAxisSpacing: AppResponsive.gridSpacing(context),
            // Lower ratio = taller cells, so the 2-row card never bottom-overflows.
            childAspectRatio: AppResponsive.getValue(context, mobile: 2.6, tablet: 2.3, desktop: 2.6),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + veg icon + switch
                  Row(
                    children: [
                      Container(
                        width: 16, height: 16,
                        margin: const EdgeInsets.only(right: 6),
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
                        child: Text(
                          item.name,
                          style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          activeColor: Colors.white, activeTrackColor: Colors.green,
                          inactiveThumbColor: Colors.white70, inactiveTrackColor: Colors.red.shade300,
                          value: item.isEnabled,
                          onChanged: (bool value) async => await itemStore.toggleItemStatus(item.id),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  if (item.itemCode != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${item.itemCode}',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Category + price + actions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$categoryName  •  ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((item.price ?? 0).toDouble())}',
                          style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_canEditItem)
                        InkWell(onTap: () => editItems(item), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary))),
                      if (_canDeleteItem)
                        InkWell(onTap: () => _deleteItem(item.id), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red))),
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