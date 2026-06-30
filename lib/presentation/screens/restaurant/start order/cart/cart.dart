import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/screens/restaurant/start%20order/cart/takeaway.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/order_settings.dart';
import '../../tabbar/table.dart';
import '../startorder.dart';
import '../../../../../util/common/app_responsive.dart';

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

  // Staged-commit tracking for existing order edits
  List<CartItem> _originalActiveList = [];
  Map<String, int> _originalQuantities = {};
  List<int> _currentKotBoundaries = [];
  List<int> _currentKotNumbers = [];


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

  Future<bool> _handleBackPress() async {
    if (_newlyAddedList.isNotEmpty) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AppDialogShell(
          title: 'Unplaced Items',
          subtitle: 'Pending changes in order',
          accent: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          body: Text(
            'You have added new items to the cart but haven\'t placed the order yet.\n\nWhat would you like to do?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 'menu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Add More Items',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'discard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Discard & Go Back',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'stay'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      if (result == 'discard') {
        await restaurantCartStore.clearCart();
        return true;
      } else if (result == 'menu') {
        _navigateAndAddMoreItems();
        return false;
      }
      return false;
    }
    return true;
  }
  /// ------------------- CART INITIALIZATION ------------------- ///
  Future<void> _initializeCart() async {
    // Priority 1: If widget has existing order — items are already in memory
    if (widget.existingOrder != null) {
      if (_isIntalizedLoad) {
        restaurantCartStore.clearCart(); // fire-and-forget, no need to await
        _isIntalizedLoad = false;
        // Deep copy — mutations to _activeList items must not leak to the Hive-cached order
        _originalActiveList = widget.existingOrder!.items.map((i) => i.copyWith()).toList();
        _originalQuantities = {for (final item in _originalActiveList) item.id: item.quantity};
        _currentKotBoundaries = List.from(widget.existingOrder!.kotBoundaries);
        _currentKotNumbers = List.from(widget.existingOrder!.kotNumbers);
      }

      // Load any newly added cart items in parallel (non-blocking)
      final cartFuture = restaurantCartStore.loadCartItems();

      setState(() {
        _activeList = widget.existingOrder!.items.map((i) => i.copyWith()).toList();
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
      onAddItems: isExistingOrder ? _navigateAndAddMoreItems : null,
      originalActiveItems: _originalActiveList,
      originalQuantities: _originalQuantities,
      currentKotBoundaries: _currentKotBoundaries,
      currentKotNumbers: _currentKotNumbers,
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
        // Active (KOT'd) items: stage the change, committed on Place Order
        if (_activeList.any((a) => a.id == item.id)) {
          _updateActiveItemQty(item, 1);
          return;
        }

        // New cart items — stock check then cart store update
        Items? inventoryItem;
        try {
          inventoryItem = itemStore.items.firstWhere(
                (invItem) => invItem.name.toLowerCase().trim() == item.title.toLowerCase().trim(),
          );
        } catch (e) {
          if (mounted) NotificationService.instance.showError('Item not found in inventory database');
          return;
        }

        if (inventoryItem.trackInventory && !inventoryItem.allowOrderWhenOutOfStock) {
          final requestedQuantity = item.quantity + 1;
          if (item.variantName != null && inventoryItem.variant != null) {
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
            } catch (e) {}
          } else {
            if (inventoryItem.stockQuantity < requestedQuantity) {
              NotificationService.instance.showError(
                  'Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock');
              return;
            }
          }
        }

        await restaurantCartStore.updateQuantity(item.id, item.quantity + 1);
        await loadCartItems();
      },
      onDecreseQty: (item) async {
        // Active (KOT'd) items: stage the change, committed on Place Order
        if (_activeList.any((a) => a.id == item.id)) {
          if (item.quantity > 1) {
            _updateActiveItemQty(item, -1);
          } else {
            _removeActiveItem(item);
          }
          return;
        }

        // New cart items — cart store update
        if (item.quantity > 1) {
          await restaurantCartStore.updateQuantity(item.id, item.quantity - 1);
        } else {
          await restaurantCartStore.removeFromCart(item.id);
        }
        await loadCartItems();
      },
      onSetQty: (item, newQty) async {
        if (newQty < 1) return;
        // The field only edits non-active items; active items stay staged via +/−.
        if (_activeList.any((a) => a.id == item.id)) {
          setState(() => item.quantity = newQty);
          return;
        }
        // The field pre-validates against stock; the store enforces it too.
        await restaurantCartStore.updateQuantity(item.id, newQty);
        await loadCartItems();
      },
      // Available stock for a cart item, or null when unlimited (untracked or
      // "allow order when out of stock"). Lets the qty field flag over-stock
      // input and block ordering until it's corrected.
      availableStockOf: (item) {
        Items? inv;
        try {
          inv = itemStore.items.firstWhere(
                (i) => i.name.toLowerCase().trim() == item.title.toLowerCase().trim(),
          );
        } catch (_) {
          return null;
        }
        if (!inv.trackInventory || inv.allowOrderWhenOutOfStock) return null;
        if (item.variantName != null && inv.variant != null) {
          try {
            final v = inv.variant!.firstWhere(
                  (vv) => _getVariantName(vv.variantId) == item.variantName,
            );
            return (v.stockQuantity ?? 0).toInt();
          } catch (_) {
            return null;
          }
        }
        return inv.stockQuantity.toInt();
      },
    );
  }

  /// Stage a quantity change for a KOT'd item — committed on "Place Order".
  void _updateActiveItemQty(CartItem item, int delta) {
    if (widget.existingOrder == null) return;
    setState(() => item.quantity = item.quantity + delta);
  }

  /// Stage removal of a KOT'd item — boundaries updated locally, committed on "Place Order".
  void _removeActiveItem(CartItem item) {
    if (widget.existingOrder == null) return;
    final idx = _activeList.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;

    int kotIndex = _currentKotBoundaries.length - 1;
    for (int i = 0; i < _currentKotBoundaries.length; i++) {
      if (idx < _currentKotBoundaries[i]) { kotIndex = i; break; }
    }

    setState(() {
      _activeList.removeAt(idx);
      for (int i = kotIndex; i < _currentKotBoundaries.length; i++) {
        _currentKotBoundaries[i]--;
      }
      if (_currentKotBoundaries.isNotEmpty) {
        final prevBoundary = kotIndex == 0 ? 0 : _currentKotBoundaries[kotIndex - 1];
        if (_currentKotBoundaries[kotIndex] == prevBoundary) {
          _currentKotNumbers.removeAt(kotIndex);
          _currentKotBoundaries.removeAt(kotIndex);
        }
      }
    });
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
    final isTablet = !AppResponsive.isMobile(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            isExistingOrder ? 'Update Order' : 'Cart (${_combinedList.length} ${_combinedList.length == 1 ? 'item' : 'items'})',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: AppResponsive.getValue(context, mobile: 17, tablet: 19),
              fontWeight: FontWeight.w500,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () async {
              final shouldPop = await _handleBackPress();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.white, size: 22),
              onPressed: () async {
                final confirmed = await showAppConfirmDialog(
                  context: context,
                  title: 'Clear Cart',
                  message: 'Remove all items from cart?',
                  confirmLabel: 'Clear',
                  accent: AppColors.danger,
                  icon: Icons.remove_shopping_cart_outlined,
                );
                if (confirmed) clearCart();
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
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: isTablet ? 10 : 8),
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
                          Icon(Icons.receipt_long, color: AppColors.textSecondary, size: 14),
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
                            Container(height: 16, width: 1, color: AppColors.divider, margin: EdgeInsets.symmetric(horizontal: 8)),
                            Text(tableNo ?? widget.existingOrder!.tableNo!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                            SizedBox(width: 6),
                            InkWell(
                              onTap: () async {
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen(isfromcart: true)));
                                if (result is String && result != widget.existingOrder!.tableNo) {
                                  try {
                                    final oldTableNo = widget.existingOrder!.tableNo;
                                    final updatedOrder = widget.existingOrder!.copyWith(tableNo: result);
                                    // Order write is source of truth — crash here leaves state consistent.
                                    await orderStore.updateOrder(updatedOrder);
                                    // Batch both table updates into one yield point to halve the crash window.
                                    await Future.wait([
                                      tableStore.updateTableStatus(result, 'Cooking', total: updatedOrder.totalPrice, orderId: updatedOrder.id, orderTime: updatedOrder.timeStamp),
                                      if (oldTableNo != null && oldTableNo.isNotEmpty)
                                        tableStore.updateTableStatus(oldTableNo, 'Available'),
                                    ]);
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
  
              // Show Add Items button when viewing existing order
              if (_activeList.isNotEmpty)
                Positioned(
                  bottom: 140,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _navigateAndAddMoreItems,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        'Add Items',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildTabChip(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 3),
          padding: EdgeInsets.symmetric(vertical: AppResponsive.getValue(context, mobile: 10, tablet: 12)),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceMedium,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppResponsive.getValue(context, mobile: 16, tablet: 18), color: isSelected ? Colors.white : AppColors.textSecondary),
              SizedBox(width: 6),
              Text(title, style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 12, tablet: 14), fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
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
          Icon(Icons.shopping_cart_outlined, size: 56, color: AppColors.divider),
          const SizedBox(height: 12),
          Text('Your cart is empty', style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary)),
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
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
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
                                  color: AppColors.textSecondary,
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
    final mergeHInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding:
              EdgeInsets.symmetric(horizontal: mergeHInset, vertical: 24),
          backgroundColor: AppColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — accent badge + title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.call_merge_rounded,
                          color: AppColors.warning, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Confirm Merge',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body — question + consequences box
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merge ${sourceOrder.tableNo} into ${widget.existingOrder!.tableNo}?',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('This will:',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          _buildMergeInfoRow(
                              'Combine all items from both tables'),
                          _buildMergeInfoRow('Merge KOT numbers for tracking'),
                          _buildMergeInfoRow('Add up the totals'),
                          _buildMergeInfoRow('Free ${sourceOrder.tableNo} table'),
                          _buildMergeInfoRow(
                              'Keep everything under ${widget.existingOrder!.tableNo}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions — balanced full-width buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Merge Tables',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      await _mergeTables(sourceOrder);
    }
  }

  Widget _buildMergeInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mergeTables(OrderModel sourceOrder) async {
    try {

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

      // 7. Delete the source order
      await orderStore.deleteOrder(sourceOrder.id);

      // 8. Update table statuses in parallel
      await Future.wait([
        tableStore.updateTableStatus(
          widget.existingOrder!.tableNo!,
          'Cooking',
          total: newTotal,
          orderId: mergedOrder.id,
          orderTime: mergedOrder.timeStamp,
        ),
        tableStore.updateTableStatus(sourceOrder.tableNo!, 'Available'),
      ]);

      // 9. Update local state
      setState(() {
        _activeList = List.from(combinedItems);
      });


      // Show success message
      NotificationService.instance.showSuccess(
        'Tables merged successfully! ${sourceOrder.tableNo} → ${widget.existingOrder!.tableNo}',
      );

    } catch (e, stackTrace) {
      NotificationService.instance.showError(
        'Failed to merge tables. Please try again.',
      );
    }
  }
}
