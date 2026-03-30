import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/takeaway.dart';
import 'package:unipos/util/color.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/order_settings.dart';
import '../../tabbar/table.dart';
import '../startorder.dart';

class CartItemStatus {
  final CartItem item;
  final bool isActive;
  CartItemStatus(this.item , this.isActive);
}

class CartScreen extends StatefulWidget {
  final OrderModel? existingOrder;
  final bool isShowButtons;
  String? selectedTableNo;

  CartScreen({
    super.key,
    this.existingOrder,
    // this.tableid,
    this.selectedTableNo,
    this.isShowButtons = false,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {

  bool _isIntalizedLoad = true;

  List<CartItem> _activeList = [];
  List<CartItem> _newlyAddedList = [];


  List<CartItemStatus>
  get _combinedList =>[
    ..._activeList.map((item)=>CartItemStatus(item, true)),
    ..._newlyAddedList.map((item)=> CartItemStatus(item,false))
  ];

  List<CartItem> cartItems = [];
  String selectedFilter = "Take Away";
  bool isExistingOrder = false;
  String? tableNo;

  String? _selectedTableNoForUI; // Add a state variable

  @override
  void initState() {
    super.initState();
    _selectedTableNoForUI = widget.selectedTableNo;
    _setDefaultOrderType();
    _initializeCart();
  }

  // Set default order type — Take Away is always available
  void _setDefaultOrderType() {
    selectedFilter = "Take Away";
  }
  void _navigateAndAddMoreItems() async {
    // Navigate to the menu to add more items
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Startorder(isForAddingItem: true), // Assuming MenuScreen exists
      ),
    );

    // When the user returns, re-initialize the cart to show the new items
    _initializeCart();
  }
  /// ------------------- CART INITIALIZATION ------------------- ///
  Future<void> _initializeCart() async {
    // Priority 1: If widget has existing order — items are already in memory
    if (widget.existingOrder != null) {
      if (_isIntalizedLoad) {
        restaurantCartStore.clearCart(); // fire-and-forget, no need to await
        _isIntalizedLoad = false;
      }

      // Load any newly added cart items in parallel (non-blocking)
      final cartFuture = restaurantCartStore.loadCartItems();

      setState(() {
        _activeList = List.from(widget.existingOrder!.items);
        isExistingOrder = true;
        selectedFilter = widget.existingOrder!.orderType;
        tableNo = widget.existingOrder!.tableNo;
      });

      await cartFuture;
      if (mounted) {
        setState(() => _newlyAddedList = restaurantCartStore.cartItems.toList());
      }
      return;
    }

    // Priority 2: Fresh cart - load from store
    await restaurantCartStore.loadCartItems();
    if (mounted) {
      setState(() {
        _newlyAddedList = restaurantCartStore.cartItems.toList();
        isExistingOrder = false;
        tableNo = widget.selectedTableNo;
        if (tableNo != null) selectedFilter = 'Dine In';
      });
    }
  }

  /// ------------------- CART HELPERS ------------------- ///
  Future<void> loadCartItems() async {
    try {
      await restaurantCartStore.loadCartItems();
      if (mounted) setState(() => _newlyAddedList = restaurantCartStore.cartItems.toList());
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _showSnackBar('Error loading cart items', isError: true);
    }
  }

  Future<void> clearCart() async {
    try {
      await restaurantCartStore.clearCart();
      await loadCartItems();
      _showSnackBar('Cart cleared');
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      _showSnackBar('Error clearing cart', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    if (isError) {
      NotificationService.instance.showError(message);
    } else {
      NotificationService.instance.showInfo(message);
    }


    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: isError ? Colors.red : null,
    //     duration: const Duration(seconds: 2),
    //   ),
    // );
  }

  String _getVariantName(String variantId) {
    try {
      final variant = variantStore.variants.firstWhere(
        (v) => v.id == variantId,
        orElse: () => variantStore.variants.first,
      );
      return variant.name;
    } catch (e) {
      return 'Unknown Variant';
    }
  }

  /// ------------------- UI HELPERS ------------------- ///
  Widget _buildTakeaway({
    required bool isDineIn,
    required bool isDelivery,
    String? tableNo,
  }) {
    return Takeaway(
      existingModel: widget.existingOrder,
      tableid: _selectedTableNoForUI ?? '',
      selectedTableNo: tableNo ?? widget.selectedTableNo ?? '',
      isexisting: isExistingOrder,
      isDineIn: isDineIn,
      isdelivery: isDelivery,
      cartItems: _combinedList,
      onAddtoCart: (item) async {
        final result = await restaurantCartStore.addToCart(item);
        if (result['success'] == true) {
          await loadCartItems();
        } else {
          // Show stock limitation error
          if (mounted) {
            NotificationService.instance.showError(
              result['message'] ?? 'Cannot add item to cart',
            );
          }
        }
      },
      onIncreseQty: (item) async {
        // Check stock availability before increasing quantity
        Items? inventoryItem;

        try {
          inventoryItem = itemStore.items.firstWhere(
                (invItem) => invItem.name.toLowerCase().trim() == item.title.toLowerCase().trim(),
          );
        } catch (e) {
          // Item not found, allow increase (no inventory tracking)
          await restaurantCartStore.updateQuantity(item.id, item.quantity + 1);
          await loadCartItems();
          return;
        }

        // Check if inventory tracking is enabled and stock is available
        if (inventoryItem.trackInventory) {
          if (!inventoryItem.allowOrderWhenOutOfStock) {
            final requestedQuantity = item.quantity + 1;

            if (item.variantName != null && inventoryItem.variant != null) {
              // Check variant stock - use stockQuantity directly from ItemVariante
              try {
                final variant = inventoryItem.variant!.firstWhere(
                      (v) => _getVariantName(v.variantId) == item.variantName,
                );
                final availableStock = variant.stockQuantity ?? 0;

                if (availableStock < requestedQuantity) {
                  NotificationService.instance.showError(
                    'Only ${availableStock.toInt()} ${item.title} (${item.variantName}) available in stock',
                  );
                  return;
                }
              } catch (e) {
                print('Error checking variant stock: $e');
              }
            } else {
              // Check regular item stock - use stockQuantity directly from Items
              if (inventoryItem.stockQuantity < requestedQuantity) {
                NotificationService.instance.showError(
                    'Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock'
                );
                return;
              }
            }
          }
        }

        // If all checks pass, update quantity
        await restaurantCartStore.updateQuantity(item.id, item.quantity + 1);
        await loadCartItems();
      },
      onDecreseQty: (item) async {
        if (item.quantity > 1) {
          await restaurantCartStore.updateQuantity(item.id, item.quantity - 1);
        } else {
          await restaurantCartStore.removeFromCart(item.id);
        }
        await loadCartItems();
      },
    );
  }

  Widget _getBody() {
    switch (selectedFilter) {
      case "Take Away":
        return _buildTakeaway(isDineIn: false, isDelivery: false);
      case "Dine In":
        return _buildTakeaway(
            isDineIn: true, isDelivery: false, tableNo: tableNo ?? _selectedTableNoForUI ?? widget.existingOrder?.tableNo ?? '');
      case "Delivery":
        return _buildTakeaway(isDineIn: false, isDelivery: true);
      default:
        return const Center(child: Text('No data available'));
    }
  }

  /// ------------------- MAIN BUILD ------------------- ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          isExistingOrder ? 'Update Order' : 'Cart (${_combinedList.length})',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.white, size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text('Clear Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
                  content: Text('Remove all items from cart?', style: GoogleFonts.poppins(fontSize: 14)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () { Navigator.pop(context); clearCart(); },
                      child: Text('Clear', style: GoogleFonts.poppins(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 4),
        ],
      ),

      body: _combinedList.isEmpty
          ? _buildEmptyCart()
          : Stack(
          children: [
            Column(
              children: [
                // Order type tabs
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _buildTabChip('Take Away', Icons.shopping_bag_outlined, selectedFilter == "Take Away",
                        () => setState(() => selectedFilter = "Take Away")),
                      if (OrderSettings.enableDineIn)
                        _buildTabChip('Dine In', Icons.restaurant, selectedFilter == "Dine In",
                          () async {
                            final result = await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const TableScreen(isfromcart: true)));
                            if (result is String) setState(() { selectedFilter = "Dine In"; _selectedTableNoForUI = result; });
                          }),
                      if (OrderSettings.enableDelivery)
                        _buildTabChip('Delivery', Icons.delivery_dining, selectedFilter == "Delivery",
                          () => setState(() => selectedFilter = "Delivery")),
                    ],
                  ),
                ),
                // Existing order info (KOT + table)
                if (isExistingOrder && widget.existingOrder != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.grey.shade600, size: 14),
                        SizedBox(width: 4),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: (widget.existingOrder!.kotNumbers ??
                                (widget.existingOrder!.kotNumber != null ? [widget.existingOrder!.kotNumber!] : []))
                                .map((kotNum) => Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('#$kotNum', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.primary)),
                                )).toList(),
                          ),
                        ),
                        if (widget.existingOrder!.orderType == 'Dine In' && widget.existingOrder!.tableNo != null && widget.existingOrder!.tableNo!.isNotEmpty) ...[
                          Container(height: 16, width: 1, color: Colors.grey.shade300, margin: EdgeInsets.symmetric(horizontal: 8)),
                          Text(tableNo ?? widget.existingOrder!.tableNo!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                          SizedBox(width: 6),
                          InkWell(
                            onTap: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen(isfromcart: true)));
                              if (result is String && result != widget.existingOrder!.tableNo) {
                                try {
                                  final oldTableNo = widget.existingOrder!.tableNo;
                                  final updatedOrder = widget.existingOrder!.copyWith(tableNo: result);
                                  await orderStore.updateOrder(updatedOrder);
                                  if (oldTableNo != null && oldTableNo.isNotEmpty) await tableStore.updateTableStatus(oldTableNo, 'Available');
                                  await tableStore.updateTableStatus(result, 'Cooking', total: updatedOrder.totalPrice, orderId: updatedOrder.id, orderTime: updatedOrder.timeStamp);
                                  setState(() { _selectedTableNoForUI = result; tableNo = result; });
                                  NotificationService.instance.showInfo('Table changed to $result');
                                } catch (e) {
                                  NotificationService.instance.showError('Failed to change table');
                                }
                              }
                            },
                            child: Icon(Icons.swap_horiz, size: 20, color: AppColors.primary),
                          ),
                          SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showMergeTableDialog(),
                            child: Icon(Icons.merge_type, size: 20, color: Colors.orange.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                Expanded(child: _getBody()),
              ],
            ),

            // Show Add Items button when viewing existing order with no new items
            if (_activeList.isNotEmpty && _newlyAddedList.isEmpty)
              Positioned(
                bottom: 140,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _navigateAndAddMoreItems,
                    icon: Icon(Icons.add, size: 18),
                    label: Text('Add Items', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
          ],
      ),
    );
  }

  Widget _buildTabChip(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 3),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
              SizedBox(width: 6),
              Text(title, style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Your cart is empty', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  /// ------------------- MERGE TABLE FUNCTIONALITY ------------------- ///
  Future<void> _showMergeTableDialog() async {
    if (widget.existingOrder == null) return;

    // Get all active orders with their table numbers
    await orderStore.loadOrders();
    final allOrders = orderStore.orders;
    final activeOrders = allOrders.where((order) =>
    (order.status == 'Cooking' || order.status == 'Processing') &&
        (order.isPaid == null || order.isPaid == false) && // Exclude paid orders
        (order.paymentStatus == null || order.paymentStatus != 'Paid') // Double-check payment status
    ).toList();

    // Filter out the current table
    final otherTables = activeOrders.where((order) =>
    order.tableNo != widget.existingOrder!.tableNo &&
        order.orderType == 'Dine In' &&
        order.tableNo != null &&
        order.tableNo!.isNotEmpty
    ).toList();

    if (otherTables.isEmpty) {
      NotificationService.instance.showInfo(
        'No other active tables to merge with',
      );
      return;
    }

    // Show dialog to select table to merge
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Merge Table',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a table to merge with ${widget.existingOrder!.tableNo}:',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: otherTables.length,
                    itemBuilder: (context, index) {
                      final order = otherTables[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.table_restaurant,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          title: Text(
                            order.tableNo!,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${order.items.length} items • ₹${order.totalPrice.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              Text(
                                'KOTs: ${order.kotNumbers.join(", ")}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward, color: AppColors.primary),
                          onTap: () {
                            Navigator.pop(context);
                            _confirmMerge(order);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmMerge(OrderModel sourceOrder) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Merge',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merge ${sourceOrder.tableNo} into ${widget.existingOrder!.tableNo}?',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildMergeInfoRow('• Combine all items from both tables'),
                    _buildMergeInfoRow('• Merge KOT numbers for tracking'),
                    _buildMergeInfoRow('• Add up the totals'),
                    _buildMergeInfoRow('• Free ${sourceOrder.tableNo} table'),
                    _buildMergeInfoRow('• Keep everything under ${widget.existingOrder!.tableNo}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
              child: Text('Merge Tables'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _mergeTables(sourceOrder);
    }
  }

  Widget _buildMergeInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }

  Future<void> _mergeTables(OrderModel sourceOrder) async {
    try {
      print('=== MERGE TABLES DEBUG ===');
      print('Source Table: ${sourceOrder.tableNo}');
      print('Target Table: ${widget.existingOrder!.tableNo}');
      print('Source Items: ${sourceOrder.items.length}');
      print('Target Items: ${widget.existingOrder!.items.length}');

      // 1. Combine items from both orders
      final combinedItems = [
        ...widget.existingOrder!.items,
        ...sourceOrder.items,
      ];

      // 2. Merge KOT numbers (keep them separate for tracking)
      final combinedKotNumbers = [
        ...widget.existingOrder!.kotNumbers,
        ...sourceOrder.kotNumbers,
      ];

      // 3. Calculate boundaries for merged KOTs
      final combinedBoundaries = [
        ...widget.existingOrder!.kotBoundaries,
        ...sourceOrder.kotBoundaries.map((boundary) =>
        boundary + widget.existingOrder!.items.length
        ),
      ];

      // 4. Calculate new total
      final newTotal = widget.existingOrder!.totalPrice + sourceOrder.totalPrice;

      // 5. Create merged order
      final mergedOrder = widget.existingOrder!.copyWith(
        items: combinedItems,
        kotNumbers: combinedKotNumbers,
        kotBoundaries: combinedBoundaries,
        totalPrice: newTotal,
        itemCountAtLastKot: combinedItems.length,
      );

      // 6. Update the main order in database
      await orderStore.updateOrder(mergedOrder);
      print('✅ Merged order updated in database');

      // 7. Delete the source order
      await orderStore.deleteOrder(sourceOrder.id);
      print('✅ Source order deleted');

      // 8. Update table statuses
      // Target table keeps cooking status with updated total
      await tableStore.updateTableStatus(
        widget.existingOrder!.tableNo!,
        'Cooking',
        total: newTotal,
        orderId: mergedOrder.id,
        orderTime: mergedOrder.timeStamp,
      );

      // Source table becomes available
      await tableStore.updateTableStatus(sourceOrder.tableNo!, 'Available');
      print('✅ Table statuses updated');

      // 9. Update local state
      setState(() {
        _activeList = List.from(combinedItems);
      });

      print('=== MERGE COMPLETE ===');

      // Show success message
      NotificationService.instance.showSuccess(
        'Tables merged successfully! ${sourceOrder.tableNo} → ${widget.existingOrder!.tableNo}',
      );

    } catch (e, stackTrace) {
      print('❌ Error merging tables: $e');
      print('Stack trace: $stackTrace');
      NotificationService.instance.showError(
        'Failed to merge tables. Please try again.',
      );
    }
  }
}
