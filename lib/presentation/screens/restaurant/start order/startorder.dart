import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/plan/plan_enforcement.dart';
import '../../../../core/plan/entitlement_keys.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../util/color.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../../util/restaurant/order_settings.dart';
import '../../../widget/componets/restaurant/componets/drawer.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
import '../../../../domain/services/common/auto_backup_service.dart';
import '../tabbar/menu.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../tabbar/order.dart';
import '../tabbar/table.dart';

class Startorder extends StatefulWidget {
  final OrderModel? existingOrder;
  final bool? isForAddingItem;
  final String? newOrderForTableId;

  const Startorder({
    super.key,
    this.isForAddingItem,
    this.existingOrder,
    this.newOrderForTableId,
  });

  @override
  State<Startorder> createState() => _StartorderState();
}

class _StartorderState extends State<Startorder>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  String? _tableIdForCurrentSession;
  late final int _tabCount =
      (OrderSettings.enableDineIn && PlanEnforce.allows(EntKeys.billingTables))
      ? 3
      : 2;
  DateTime? _lastBackPress;
  int _previousTabIndex = 0;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: _tabCount, vsync: this);

    // Initialize state based on what was passed to the widget
    if (widget.existingOrder != null) {
      _tableIdForCurrentSession = widget.existingOrder!.tableNo;
    } else if (widget.newOrderForTableId != null) {
      _tableIdForCurrentSession = widget.newOrderForTableId;
      tabController.index = 0; // Default to menu for a new order
    }

    _previousTabIndex = tabController.index;

    // Listen to tab changes - refresh data when switching tabs
    tabController.addListener(() {
      if (mounted && tabController.index != _previousTabIndex) {
        _previousTabIndex = tabController.index;
        setState(() {});
        _refreshCurrentTab();
      }
    });

    // Initial

    _refreshCurrentTab();
  }

  /// Only the loads covering a real stale-data path remain. Category, cart and
  /// table stores all keep their observable lists current on write, so
  /// reloading them here was duplicate work.
  void _refreshCurrentTab() {
    // Menu tab (0) needs no reload: MenuScreen loads items on init, and every
    // item write — stock included — goes through ItemStore.
    // Refresh orders when switching to orders tab
    if (tabController.index == 1) {
      // Kept: captain-app edits go through HiveOrders.updateOrder, which writes
      // straight to the box and leaves orderStore's list stale.
      orderStore.loadOrders();
    }
    // Refresh orders when switching to tables tab (only if dine-in enabled)
    else if (tabController.index == 2 &&
        (OrderSettings.enableDineIn &&
            PlanEnforce.allows(EntKeys.billingTables))) {
      orderStore
          .loadOrders(); // CRITICAL: Need orders to find active order for table
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = tabController.index == index;
    final fs = AppResponsive.bodyFontSize(context);
    final iconSz = AppResponsive.getValue<double>(
      context,
      mobile: 18,
      tablet: 20,
      desktop: 22,
    );
    return GestureDetector(
      onTap: () => tabController.animateTo(index),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: AppResponsive.smallSpacing(context),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceMedium,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSz,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fs,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  /// Builds the detailed view for an existing order (matches your screenshot).
  // Widget _buildExistingOrderView() {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('Order Details'),
  //       leading: IconButton(
  //         icon: const Icon(Icons.arrow_back),
  //         onPressed: () => Navigator.of(context).pop(),
  //       ),
  //       actions: [
  //         TextButton.icon(
  //           icon: const Icon(Icons.clear, color: Colors.white),
  //           label: const Text('Clear Cart', style: TextStyle(color: Colors.white)),
  //           style: TextButton.styleFrom(backgroundColor: AppColors.primary),
  //           onPressed: () {
  //             // You can add a confirmation dialog here
  //             setState(() {
  //               _currentCartItems.clear();
  //             });
  //           },
  //         )
  //       ],
  //     ),
  //     body: Column(
  //       children: [
  //         // Header buttons
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               ElevatedButton.icon(onPressed: (){}, icon: Icon(Icons.delivery_dining), label: Text('Take Away')),
  //               ElevatedButton.icon(onPressed: (){}, icon: Icon(Icons.dinner_dining), label: Text('Dine In'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary)),
  //               ElevatedButton.icon(onPressed: (){}, icon: Icon(Icons.delivery_dining_outlined), label: Text('Delivery')),
  //             ],
  //           ),
  //         ),
  //         // Table Number and Headers
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           color: Colors.grey.shade200,
  //           child: Column(
  //             children: [
  //               if (_tableIdForCurrentSession != null) ...[
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //                   decoration: BoxDecoration(
  //                       border: Border.all(color: AppColors.primary),
  //                       borderRadius: BorderRadius.circular(20)
  //                   ),
  //                   child: Text('Table No: $_tableIdForCurrentSession', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
  //                 ),
  //                 const SizedBox(height: 10),
  //               ],
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Expanded(flex: 3, child: Text('Items', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
  //                   Expanded(flex: 2, child: Center(child: Text('QTY', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
  //                   Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         // Items List
  //         Expanded(
  //           child: _currentCartItems.isEmpty
  //               ? const Center(child: Text('No items in this order.'))
  //               : ListView.separated(
  //             padding: const EdgeInsets.all(16),
  //             itemCount: _currentCartItems.length,
  //             separatorBuilder: (context, index) => const Divider(),
  //             itemBuilder: (context, index) {
  //               final item = _currentCartItems[index];
  //               return Row(
  //                 children: [
  //                   Expanded(
  //                     flex: 3,
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text('KOT - #${widget.existingOrder?.kotNumber ?? 'N/A'}', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
  //                         Text(item.title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
  //                       ],
  //                     ),
  //                   ),
  //                   Expanded(
  //                     flex: 2,
  //                     child: Row(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       children: [
  //                         IconButton(icon: Icon(Icons.remove_circle_outline, color: AppColors.primary), onPressed: () => _decreaseQuantity(item)),
  //                         Text(item.quantity.toString(), style: GoogleFonts.poppins(fontSize: 16)),
  //                         IconButton(icon: Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: () => _increaseQuantity(item)),
  //                       ],
  //                     ),
  //                   ),
  //                   Expanded(
  //                     flex: 2,
  //                     child: Align(
  //                       alignment: Alignment.centerRight,
  //                       child: Text('Rs. ${item.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
  //                     ),
  //                   ),
  //                 ],
  //               );
  //             },
  //           ),
  //         ),
  //         // Bottom Action Bar
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2)],
  //           ),
  //           child: Column(
  //             children: [
  //               CommonButton(
  //                 onTap: _addItem,
  //                 child: const Text('Add Itemm'),
  //               ),
  //               const SizedBox(height: 10),
  //               Row(
  //                 children: [
  //                   Expanded(child: CommonButton(onTap: () {}, child: Text('Settle (Rs. ${_totalPrice.toStringAsFixed(2)})'))),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: CommonButton(onTap: _updateAndSaveChanges, child: const Text('Place Order'))),
  //                 ],
  //               ),
  //               const SizedBox(height: 10),
  //               CommonButton(onTap: () {}, child: const Text('Print Bill')),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  /// Builds the default TabBar view for starting new orders.
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.exit_to_app_rounded,
                  color: Colors.white,
                  size: AppResponsive.iconSize(context),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text(
                  'Press back again to exit',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            margin: EdgeInsets.all(
              AppResponsive.extraLargeSpacing(context),
            ).copyWith(top: 0),
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.largeSpacing(context),
              vertical: AppResponsive.mediumSpacing(context),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        drawer: Drawerr(),
        appBar: buildPrimaryAppBar(
          titleWidget: Row(
            children: [
              Text(
                'Bill Berry Lite',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue<double>(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (widget.newOrderForTableId != null) ...[
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text(
                  '• Table ${widget.newOrderForTableId}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue<double>(
                      context,
                      mobile: 13,
                      tablet: 14,
                    ),
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
        body: Column(
          children: [
            // Auto-backup progress indicator — thin bar at the very top
            ValueListenableBuilder<bool>(
              valueListenable: AutoBackupService.isBackingUp,
              builder: (_, backing, __) => backing
                  ? LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Horizontal Tabs for Tablet
            if (isTablet)
              Container(
                color: AppColors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.largeSpacing(context),
                  vertical: AppResponsive.smallSpacing(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(0, Icons.restaurant_menu, 'Menu'),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: _buildTabButton(1, Icons.receipt_long, 'Orders'),
                    ),
                    if ((OrderSettings.enableDineIn &&
                        PlanEnforce.allows(EntKeys.billingTables))) ...[
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Expanded(
                        child: _buildTabButton(
                          2,
                          Icons.table_restaurant,
                          'Tables',
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // TabBarView
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  // Menu tab: MenuScreen now owns both layouts internally — the
                  // opt-in "Menu Grid View" (mobile only) and the default list;
                  // tablet keeps its own grid layout. Wrapped in the settings
                  // listener so flipping the flag live-swaps the mode without
                  // leaving the screen.
                  ValueListenableBuilder<Map<String, bool>>(
                    valueListenable: AppSettings.settingsNotifier,
                    builder: (context, __, ___) => MenuScreen(
                      tableIdForNewOrder: _tableIdForCurrentSession,
                      isForAddingItem: widget.isForAddingItem ?? false,
                    ),
                  ),
                  Order(),
                  if ((OrderSettings.enableDineIn &&
                      PlanEnforce.allows(EntKeys.billingTables)))
                    const TableScreen(),
                ],
              ),
            ),
          ],
        ),
        // Mobile-only chrome (isTablet == !isMobile), so every value below is
        // permanently on the ladder's mobile step. Static is correct here:
        // swapping `size: 22` for AppResponsive.iconSize would SHRINK it to 20
        // rather than make it responsive.
        bottomNavigationBar: isTablet
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SafeArea(
                  child: SizedBox(
                    height: 56,
                    child: TabBar(
                      controller: tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 2,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: [
                        Tab(
                          icon: Icon(Icons.restaurant_menu, size: 22),
                          text: 'Menu',
                        ),
                        Tab(
                          icon: Icon(Icons.receipt_long, size: 22),
                          text: 'Orders',
                        ),
                        if ((OrderSettings.enableDineIn &&
                            PlanEnforce.allows(EntKeys.billingTables)))
                          Tab(
                            icon: Icon(Icons.table_restaurant, size: 22),
                            text: 'Tables',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
