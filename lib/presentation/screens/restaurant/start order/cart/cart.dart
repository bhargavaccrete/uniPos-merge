import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_Table.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_cart.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_order.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/takeaway.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/order_settings.dart';
import '../../../../widget/componets/restaurant/componets/filterButton.dart';
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

  // Set default order type based on enabled settings
  void _setDefaultOrderType() {
    // Use the first enabled order type as default
    if (OrderSettings.enableTakeAway) {
      selectedFilter = "Take Away";
    } else if (OrderSettings.enableDineIn) {
      selectedFilter = "Dine In";
    } else if (OrderSettings.enableDelivery) {
      selectedFilter = "Delivery";
    }
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
    // Add these lines for debugging
    print("--- Placing Order ---");
    // print("Is Dine In? ${widget.isDineIn}");
    print("Selected Table No: ${widget.selectedTableNo}");

    // Priority 1: If widget has existing order
    if (widget.existingOrder != null) {
      if(_isIntalizedLoad){
        await HiveCart.clearCart();
        _isIntalizedLoad =false;
      }

      setState(() {
        _activeList = List.from(widget.existingOrder!.items);
        isExistingOrder = true;
        selectedFilter = widget.existingOrder!.orderType;
        tableNo = widget.existingOrder!.tableNo;
      });
      await loadCartItems();
      return;
    }

    // Priority 2: Restore persisted state
    final appBox = Hive.box('app_state');
    final bool persistedExisting =
    appBox.get('is_existing_order', defaultValue: false);

    if (persistedExisting) {
      final String? persistedTableId = appBox.get('existing_order_table');
      if (persistedTableId != null) {
        final existingOrder =
        await HiveOrders.getActiveOrderByTableId(persistedTableId);
        if (existingOrder != null && mounted) {
          setState(() {
            _activeList = existingOrder.items;
            isExistingOrder = true;
            selectedFilter = 'Dine In';
            tableNo = existingOrder.tableNo;
          });
          return;
        }
      }
    }

    // Priority 3: Fresh cart
    final newCartItems = await HiveCart.getAllCartItems();
    if (mounted) {
      setState(() {
        _newlyAddedList = newCartItems;
        isExistingOrder = false;
        tableNo = widget.selectedTableNo;
        if (tableNo != null) selectedFilter = 'Dine In';
      });
    }
  }

  /// ------------------- CART HELPERS ------------------- ///
  Future<void> loadCartItems() async {
    try {
      final items = await HiveCart.getAllCartItems();
      if (mounted) setState(() => _newlyAddedList = items);
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _showSnackBar('Error loading cart items', isError: true);
    }
  }

  Future<void> clearCart() async {
    try {
      await HiveCart.clearCart();
      await loadCartItems();
      _showSnackBar('Cart cleared');
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      _showSnackBar('Error clearing cart', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    NotificationService.instance.showInfo(
      message,
    );


    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: isError ? Colors.red : null,
    //     duration: const Duration(seconds: 2),
    //   ),
    // );
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
        final result = await HiveCart.addToCart(item);
        if (result['success'] == true) {
          await loadCartItems();
        } else {
          // Show stock limitation error
          if (mounted) {


            NotificationService.instance.showInfo(
              result['message'] ?? 'Cannot add item to cart',
            );

            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(result['message'] ?? 'Cannot add item to cart'),
            //     backgroundColor: Colors.red,
            //     duration: Duration(seconds: 3),
            //   ),
            // );
          }
        }
      },
      onIncreseQty: (item) async {
        // Check stock availability before increasing quantity
        // Box is already opened during app startup in HiveInit
        final itemBox = Hive.box<Items>('itemBoxs');
        Items? inventoryItem;

        try {
          inventoryItem = itemBox.values.firstWhere(
                (invItem) => invItem.id == item.id,
          );
        } catch (e) {
          // Try to find by name if not found by ID
          try {
            inventoryItem = itemBox.values.firstWhere(
                  (invItem) => invItem.name.toLowerCase().trim() == item.title.toLowerCase().trim(),
            );
          } catch (e2) {
            // Item not found, allow increase (no inventory tracking)
            await HiveCart.updateQuantity(item.id, item.quantity + 1);
            await loadCartItems();
            return;
          }
        }

        // Check if inventory tracking is enabled and stock is available
        if (inventoryItem != null && inventoryItem.trackInventory) {
          if (!inventoryItem.allowOrderWhenOutOfStock) {
            // Check stock availability
            final requestedQuantity = item.quantity + 1;

            if (item.variantName != null && inventoryItem.variant != null) {
              // Check variant stock
              try {
                final variantBox = Hive.box<VariantModel>('variante');
                final variant = inventoryItem.variant!.firstWhere(
                      (v) => variantBox.get(v.variantId)?.name == item.variantName,
                );
                final availableStock = variant.stockQuantity ?? 0;

                if (availableStock < requestedQuantity) {
                  // Show error message
                  NotificationService.instance.showInfo(
                    'Only $availableStock ${item.title} (${item.variantName}) available in stock',
                  );


                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   SnackBar(
                  //     content: Text('Only $availableStock ${item.title} (${item.variantName}) available in stock'),
                  //     backgroundColor: Colors.red,
                  //     duration: Duration(seconds: 2),
                  //   ),
                  // );
                  return;
                }
              } catch (e) {
                print('Error checking variant stock: $e');
              }
            } else {
              // Check regular item stock
              if (inventoryItem.stockQuantity < requestedQuantity) {
                // Show error message

                NotificationService.instance.showInfo(
                    'Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock'
                );



                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text('Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock'),
                //     backgroundColor: Colors.red,
                //     duration: Duration(seconds: 2),
                //   ),
                // );
                return;
              }
            }
          }
        }

        // If all checks pass, update quantity
        await HiveCart.updateQuantity(item.id, item.quantity + 1);
        await loadCartItems();
      },
      onDecreseQty: (item) async {
        if (item.quantity > 1) {
          await HiveCart.updateQuantity(item.id, item.quantity - 1);
        } else {
          await HiveCart.removeFromCart(item.id);
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
        backgroundColor: primarycolor,
        title: Text(
          isExistingOrder ? 'Update Order' : 'Cart',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear Cart'),
                  content: const Text('Are you sure you want to clear the cart?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        clearCart();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
// floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,


      body: _combinedList.isEmpty
          ? _buildEmptyCart()
          : Stack(
          children:[



            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Take Away button - only show if enabled
                      if (OrderSettings.enableTakeAway)
                        Filterbutton(
                          title: 'Take Away',
                          selectedFilter: selectedFilter,
                          onpressed: () =>
                              setState(() => selectedFilter = "Take Away"),
                        ),
                      // Dine In button - only show if enabled
                      if (OrderSettings.enableDineIn)
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Filterbutton(
                            title: 'Dine In',
                            selectedFilter: selectedFilter,
                            onpressed: () async {


                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const TableScreen(isfromcart: true,)),
                              );
                              if (result is String) {
                                setState(() {
                                  selectedFilter = "Dine In";
                                  _selectedTableNoForUI = result;
                                });
                              }
                            },
                          ),
                        ),
                      // Delivery button - only show if enabled
                      if (OrderSettings.enableDelivery)
                        Filterbutton(

                          title: 'Delivery',
                          selectedFilter: selectedFilter,
                          onpressed: () =>
                              setState(() => selectedFilter = "Delivery"),
                        ),
                    ],
                  ),
                ),
                // Display KOT numbers and table info for existing orders (Compact Version)
                if (isExistingOrder && widget.existingOrder != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // KOT Numbers Section (Left Side)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long, color: Colors.blue.shade700, size: 16),
                              SizedBox(width: 6),
                              Expanded(
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: (widget.existingOrder!.kotNumbers ??
                                      (widget.existingOrder!.kotNumber != null ? [widget.existingOrder!.kotNumber!] : []))
                                      .map((kotNum) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '#$kotNum',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Info Section (Right Side) - Only for Dine In
                        if (widget.existingOrder!.orderType == 'Dine In' && widget.existingOrder!.tableNo != null && widget.existingOrder!.tableNo!.isNotEmpty) ...[
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.blue.shade300,
                            margin: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Icon(Icons.table_restaurant, color: Colors.blue.shade700, size: 16),
                          SizedBox(width: 4),
                          Text(
                            tableNo ?? widget.existingOrder!.tableNo!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(width: 6),
                          // Change Table Button
                          InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TableScreen(isfromcart: true),
                                ),
                              );
                              if (result is String && result != widget.existingOrder!.tableNo) {
                                try {
                                  final oldTableNo = widget.existingOrder!.tableNo;

                                  print('=== TABLE CHANGE DEBUG ===');
                                  print('Old table: $oldTableNo');
                                  print('New table: $result');
                                  print('Order ID: ${widget.existingOrder!.id}');

                                  final updatedOrder = widget.existingOrder!.copyWith(tableNo: result);
                                  await HiveOrders.updateOrder(updatedOrder);
                                  print('✅ Order updated in database');

                                  if (oldTableNo != null && oldTableNo.isNotEmpty) {
                                    await HiveTables.updateTableStatus(oldTableNo, 'Available');
                                    print('✅ Old table ($oldTableNo) set to Available');
                                  }

                                  await HiveTables.updateTableStatus(
                                    result,
                                    'Cooking',
                                    total: updatedOrder.totalPrice,
                                    orderId: updatedOrder.id,
                                    orderTime: updatedOrder.timeStamp,
                                  );
                                  print('✅ New table ($result) set to Cooking');

                                  setState(() {
                                    _selectedTableNoForUI = result;
                                    tableNo = result;
                                  });

                                  print('=== TABLE CHANGE COMPLETE ===');

                                  NotificationService.instance.showInfo(
                                    'Table changed from $oldTableNo to $result',
                                  );
                                } catch (e, stackTrace) {
                                  print('❌ Error changing table: $e');
                                  print('Stack trace: $stackTrace');
                                  NotificationService.instance.showInfo(
                                    'Failed to change table. Please try again.',
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 4),
                          // Merge Table Button
                          InkWell(
                            onTap: () => _showMergeTableDialog(),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.merge_type, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Expanded(child: _getBody()),
              ],
            ),

            // Show Add button only when there are active items but no new items added
            if (_activeList.isNotEmpty && _newlyAddedList.isEmpty)
              Positioned(
                bottom: 150,
                right: 130,
                child:   FloatingActionButton.extended(
                  backgroundColor: primarycolor,

                  onPressed: _navigateAndAddMoreItems,
                  icon: const Icon(Icons.add,color: Colors.white,), // The icon to display.
                  label:  Text('Add',style: GoogleFonts.poppins(color: Colors.white)),     // The text label to display.
                ),),
          ]


      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// ------------------- MERGE TABLE FUNCTIONALITY ------------------- ///
  Future<void> _showMergeTableDialog() async {
    if (widget.existingOrder == null) return;

    // Get all active orders with their table numbers
    final allOrders = await HiveOrders.getAllOrder();
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
                          trailing: Icon(Icons.arrow_forward, color: primarycolor),
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
      await HiveOrders.updateOrder(mergedOrder);
      print('✅ Merged order updated in database');

      // 7. Delete the source order
      await HiveOrders.deleteOrder(sourceOrder.id);
      print('✅ Source order deleted');

      // 8. Update table statuses
      // Target table keeps cooking status with updated total
      await HiveTables.updateTableStatus(
        widget.existingOrder!.tableNo!,
        'Cooking',
        total: newTotal,
        orderId: mergedOrder.id,
        orderTime: mergedOrder.timeStamp,
      );

      // Source table becomes available
      await HiveTables.updateTableStatus(sourceOrder.tableNo!, 'Available');
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
