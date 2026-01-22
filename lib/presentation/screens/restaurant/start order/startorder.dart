import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../util/color.dart';
import '../../../widget/componets/restaurant/componets/drawer.dart';
import '../tabbar/menu.dart';
import '../tabbar/order.dart';
import '../tabbar/table.dart';

class Startorder extends StatefulWidget {
  final OrderModel? existingOrder;
  final bool? isForAddingItem;
  final String? newOrderForTableId;

  const Startorder({super.key,
    this.isForAddingItem,
    this.existingOrder, this.newOrderForTableId});

  @override
  State<Startorder> createState() => _StartorderState();
}

class _StartorderState extends State<Startorder>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  String? _tableIdForCurrentSession;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);

    // Initialize state based on what was passed to the widget
    if (widget.existingOrder != null) {
      _tableIdForCurrentSession = widget.existingOrder!.tableNo;
    } else if (widget.newOrderForTableId != null) {
      _tableIdForCurrentSession = widget.newOrderForTableId;
      tabController.index = 0; // Default to menu for a new order
    }

    // Listen to tab changes - refresh data when switching tabs
    tabController.addListener(() {
      if (mounted) {
        setState(() {});
        _refreshCurrentTab();
      }
    });

    // Initial load
    _refreshCurrentTab();
  }

  void _refreshCurrentTab() {
    print('🔄 Refreshing tab ${tabController.index}');
    // Refresh menu/cart data when switching to menu tab
    if (tabController.index == 0) {
      categoryStore.loadCategories();
      itemStore.loadItems();
      restaurantCartStore.loadCartItems();
    }
    // Refresh orders when switching to orders tab
    else if (tabController.index == 1) {
      orderStore.loadOrders();
    }
    // Refresh tables when switching to tables tab
    else if (tabController.index == 2) {
      tableStore.loadTables();
      orderStore.loadOrders(); // CRITICAL: Need orders to find active order for table
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Widget _buildTabButton(int index, IconData icon, String label, bool isTablet) {
    final isSelected = tabController.index == index;
    return GestureDetector(
      onTap: () {
        tabController.animateTo(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
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
    print(widget.newOrderForTableId ?? 'no table id ');
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: Drawerr(),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.menu, color: AppColors.white, size: 24),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UniPOS',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.newOrderForTableId != null
                              ? 'Table ${widget.newOrderForTableId}'
                              : 'Quick Order',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                 /* GestureDetector(
                    onTap: () {
                      setState(() {});
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.refresh, size: 22, color: AppColors.textSecondary),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.more_vert, size: 22, color: AppColors.textSecondary),
                  ),*/
                ],
              ),
            ),
          ),

          // Horizontal Tabs for Tablet
          if (isTablet)
            Container(
              color: AppColors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton(0, Icons.restaurant_menu, 'Menu', isTablet)),
                  SizedBox(width: 16),
                  Expanded(child: _buildTabButton(1, Icons.receipt_long, 'Orders', isTablet)),
                  SizedBox(width: 16),
                  Expanded(child: _buildTabButton(2, Icons.table_restaurant, 'Tables', isTablet)),
                ],
              ),
            ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                MenuScreen(
                  tableIdForNewOrder:_tableIdForCurrentSession,
                  isForAddingItem: widget.isForAddingItem ?? false,
                ),
                Order(),
                const TableScreen()
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isTablet ? null : Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 60,
            child: TabBar(
              controller: tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.restaurant_menu, size: 24),
                  text: 'Menu',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long, size: 24),
                  text: 'Orders',
                ),
                Tab(
                  icon: Icon(Icons.table_restaurant, size: 24),
                  text: 'Tables',
                ),
              ],
            ),
          ),
        ),
      ),
    );


  }
}
