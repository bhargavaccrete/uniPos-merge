import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../../domain/services/restaurant/cart_calculation_service.dart';
import '../../../../../domain/services/restaurant/day_management_service.dart';
import '../../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../../../../util/restaurant/staticswitch.dart';
import '../../../../../util/restaurant/restaurant_session.dart';

import '../../../../../data/models/restaurant/db/customer_model_125.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../widget/componets/common/app_text_field.dart';
import '../../tabbar/table.dart';
import '../startorder.dart';
import 'customerdetails.dart';
import '../../util/restaurant_print_helper.dart';
import '../../../../../server/websocket.dart' as ws;
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/stores/payment_method_store.dart';
class Takeaway extends StatefulWidget {
  bool isexisting = false;
  final OrderModel? existingModel;
  String? selectedTableNo;
  final bool isdelivery;
  final bool isDineIn;
  final List<CartItemStatus> cartItems;
  final String? tableid;
  final Function(CartItem) onAddtoCart;
  final Function(CartItem) onIncreseQty;
  final Function(CartItem) onDecreseQty;
  final List<CartItem>? originalActiveItems;
  final Map<String, int>? originalQuantities;
  final List<int>? currentKotBoundaries;
  final List<int>? currentKotNumbers;

  Takeaway(
      {super.key,
        this.tableid,
        this.existingModel,
        required this.isexisting,
        required this.isdelivery,
        required this.cartItems,
        required this.onAddtoCart,
        required this.onIncreseQty,
        required this.onDecreseQty,
        required this.isDineIn,
        this.selectedTableNo,
        this.originalActiveItems,
        this.originalQuantities,
        this.currentKotBoundaries,
        this.currentKotNumbers});

  @override
  State<Takeaway> createState() => _TakeawayState();
}

class _TakeawayState extends State<Takeaway> {




  // Active/NEW Label
  Widget _buildGroupedCartItems() {
    // If viewing an existing order, group by KOT number
    if (widget.isexisting && widget.existingModel != null) {
      return _buildKotGroupedItems();
    }

    // Otherwise, use the active/new grouping for new orders
    final activeItems = widget.cartItems.where((item) => item.isActive).toList();
    final newItems = widget.cartItems.where((item) => !item.isActive).toList();

    return ListView(
      children: [
        // Active Items Section (always at top)
        if (activeItems.isNotEmpty)
          _buildItemSection('ACTIVE', AppColors.success, activeItems),

        // Add spacing between sections
        if (activeItems.isNotEmpty && newItems.isNotEmpty)
          SizedBox(height: 16),

        // New Items Section
        if (newItems.isNotEmpty)
          _buildItemSection('NEW', AppColors.info, newItems),
      ],
    );
  }

  // Group items by KOT number for existing orders
  Widget _buildKotGroupedItems() {
    if (widget.existingModel == null) return SizedBox();

    final existingModel = widget.existingModel!;
    final List<int> kotNumbers = widget.currentKotNumbers ?? existingModel.kotNumbers;
    final List<int> kotBoundaries = widget.currentKotBoundaries ?? existingModel.kotBoundaries;

    List<Widget> kotSections = [];
    final allItems = widget.cartItems;

    int startIndex = 0;
    for (int i = 0; i < kotNumbers.length; i++) {
      int endIndex = kotBoundaries[i];
      int kotNum = kotNumbers[i];

      // Get items for this KOT
      if (startIndex < allItems.length) {
        int actualEndIndex = endIndex > allItems.length ? allItems.length : endIndex;
        List<CartItemStatus> kotItems = allItems.sublist(startIndex, actualEndIndex);

        if (kotItems.isNotEmpty) {
          // Separate active and new items within this KOT
          final activeKotItems = kotItems.where((item) => item.isActive).toList();
          final newKotItems = kotItems.where((item) => !item.isActive).toList();

          final kotStatus = existingModel.getKotStatus(kotNum).toLowerCase();
          final isCooked = kotStatus == 'cooked' || kotStatus == 'ready' || kotStatus == 'served' || kotStatus == 'completed';

          // Show ACTIVE items for this KOT
          if (activeKotItems.isNotEmpty) {
            kotSections.add(
                _buildItemSection('KOT #$kotNum - ACTIVE${isCooked ? ' (Cooked)' : ''}', isCooked ? AppColors.warning : AppColors.success, activeKotItems, isCooked: isCooked)
            );
            kotSections.add(SizedBox(height: 16));
          }

          // Show NEW items for this KOT
          if (newKotItems.isNotEmpty) {
            kotSections.add(
                _buildItemSection('KOT #$kotNum - NEW', Colors.blue, newKotItems)
            );
            kotSections.add(SizedBox(height: 16));
          }
        }

        startIndex = endIndex;
      }
    }

    // Handle any new items added beyond the last KOT (will be part of next KOT)
    if (startIndex < allItems.length) {
      List<CartItemStatus> newItems = allItems.sublist(startIndex);
      if (newItems.isNotEmpty) {
        kotSections.add(
            _buildItemSection('NEW ITEMS (Pending KOT)', AppColors.warning, newItems)
        );
      }
    }

    return ListView(
      children: kotSections,
    );
  }

  Widget _buildItemSection(String title, Color color, List<CartItemStatus> items, {bool isCooked = false}) {
    final sectionFs = AppResponsive.getValue<double>(context, mobile: 11, tablet: 13, desktop: 14);
    final countFs = AppResponsive.getValue<double>(context, mobile: 10, tablet: 12, desktop: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              SizedBox(width: 6),
              Text(title, style: GoogleFonts.poppins(fontSize: sectionFs, fontWeight: FontWeight.w500, color: color)),
              SizedBox(width: 6),
              Text('${items.length}', style: GoogleFonts.poppins(fontSize: countFs, color: Colors.grey.shade500)),
            ],
          ),
        ),
        ...items.map((item) => buildCartItemRow(item, isCooked: isCooked)).toList(),
      ],
    );
  }


  Widget buildCartItemRow(CartItemStatus wrapped, {bool isCooked = false}) {
    final item = wrapped.item;

    final String? variantLine = item.variantName;
    final List<String> addOns = [];

    // Choices — deduplicated
    if (item.choiceNames != null && item.choiceNames!.isNotEmpty) {
      addOns.addAll(item.choiceNames!.toSet());
    }

    // Extras — grouped by name with price
    if (item.extras != null && item.extras!.isNotEmpty) {
      Map<String, Map<String, dynamic>> groupedExtras = {};
      for (var extra in item.extras!) {
        String displayName;
        if (extra['displayName'] != null && extra['displayName'].toString().isNotEmpty) {
          displayName = extra['displayName'];
        } else if (extra['categoryName'] != null && extra['categoryName'].toString().isNotEmpty) {
          displayName = '${extra['categoryName']} - ${extra['name']}';
        } else {
          displayName = extra['name'] ?? 'Unknown';
        }
        final double price = extra['price']?.toDouble() ?? 0.0;
        final int itemQuantity = extra['quantity']?.toInt() ?? 1;
        String key = '$displayName-${price.toStringAsFixed(2)}';
        if (groupedExtras.containsKey(key)) {
          groupedExtras[key]!['quantity'] = (groupedExtras[key]!['quantity'] as int) + itemQuantity;
        } else {
          groupedExtras[key] = {'displayName': displayName, 'price': price, 'quantity': itemQuantity};
        }
      }
      addOns.addAll(groupedExtras.entries.map((e) {
        final d = e.value;
        final qty = d['quantity'] as int;
        final name = d['displayName'] as String;
        final price = d['price'] as double;
        return qty > 1 ? '${qty}x $name(${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)})' : '$name(${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)})';
      }));
    }

    final String? addOnsLine = addOns.isNotEmpty ? addOns.join(', ') : null;

    final nameFs = AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 17);
    final variantFs = AppResponsive.getValue<double>(context, mobile: 12, tablet: 14, desktop: 15);
    final modFs = AppResponsive.getValue<double>(context, mobile: 11, tablet: 13, desktop: 14);
    final qtyFs = AppResponsive.getValue<double>(context, mobile: 15, tablet: 17, desktop: 18);
    final priceFs = AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 17);
    final iconSize = AppResponsive.getValue<double>(context, mobile: 16, tablet: 18, desktop: 20);
    final btnPad = AppResponsive.getValue<double>(context, mobile: 5, tablet: 7, desktop: 8);
    final priceWidth = AppResponsive.getValue<double>(context, mobile: 75, tablet: 95, desktop: 115);
    final hPad = AppResponsive.getValue<double>(context, mobile: 12, tablet: 16, desktop: 20);
    final vPad = AppResponsive.getValue<double>(context, mobile: 5, tablet: 7, desktop: 8);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Row(
        children: [
          // Item name + variant + modifiers
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name + variant inline
                Text.rich(
                  TextSpan(
                    text: item.title,
                    style: GoogleFonts.poppins(fontSize: nameFs, fontWeight: FontWeight.w500),
                    children: [
                      if (variantLine != null)
                        TextSpan(text: '  $variantLine', style: GoogleFonts.poppins(fontSize: variantFs, fontWeight: FontWeight.w400, color: Colors.grey.shade600)),
                      if (item.weightDisplay != null)
                        TextSpan(text: '  ${item.weightDisplay}', style: GoogleFonts.poppins(fontSize: modFs, fontWeight: FontWeight.w400, color: Colors.grey.shade500)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Choices + extras — one line, comma separated, wraps naturally
                if (addOnsLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(addOnsLine, style: GoogleFonts.poppins(fontSize: modFs, color: Colors.grey.shade500)),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // Qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!wrapped.isActive) ...[
                InkWell(
                  onTap: () => widget.onDecreseQty(item),
                  child: Container(
                    padding: EdgeInsets.all(btnPad),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                    child: Icon(Icons.remove, size: iconSize, color: Colors.grey.shade700),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(item.quantity.toString(), style: GoogleFonts.poppins(fontSize: qtyFs, fontWeight: FontWeight.w600)),
                ),
                InkWell(
                  onTap: () => widget.onIncreseQty(item),
                  child: Container(
                    padding: EdgeInsets.all(btnPad),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                    child: Icon(Icons.add, size: iconSize, color: Colors.white),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${item.quantity}x', style: GoogleFonts.poppins(fontSize: qtyFs, fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: 8),
                if (isCooked)
                  Tooltip(
                    message: 'Cannot cancel cooked items',
                    child: Container(
                      padding: EdgeInsets.all(btnPad),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.cancel_outlined, size: iconSize, color: Colors.grey.shade400),
                    ),
                  )
                else
                  InkWell(
                    onTap: () => _showCancelDialog(context, item),
                    child: Container(
                      padding: EdgeInsets.all(btnPad),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.cancel_outlined, size: iconSize, color: Colors.red),
                    ),
                  ),
              ],
            ],
          ),
          SizedBox(width: 12),
          // Price
          SizedBox(
            width: priceWidth,
            child: Text(
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.totalPrice)}',
              style: GoogleFonts.poppins(fontSize: priceFs, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, CartItem item) {
    int cancelQty = 1;
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Cancel Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How many "${item.title}" do you want to cancel?', style: GoogleFonts.poppins(fontSize: 14)),
                  SizedBox(height: 20),
                  if (item.quantity > 1)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: cancelQty > 1 ? () => setState(() => cancelQty--) : null,
                            icon: Icon(Icons.remove_circle_outline, color: cancelQty > 1 ? AppColors.primary : Colors.grey),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('$cancelQty', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            onPressed: cancelQty < item.quantity ? () => setState(() => cancelQty++) : null,
                            icon: Icon(Icons.add_circle_outline, color: cancelQty < item.quantity ? AppColors.primary : Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Text('Cancel 1x ${item.title}?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.red)),
                  SizedBox(height: 10),
                  Text('This will print a Cancel KOT for the kitchen.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Keep Item', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    for (int i = 0; i < cancelQty; i++) {
                      widget.onDecreseQty(item);
                    }
                  },
                  child: Text('Confirm Cancel', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
                )
              ],
            );
          },
        );
      },
    );
  }
  Future<void> clearCart() async {
    try {
      await restaurantCartStore.clearCart();
      // await loadCartItems();
      if (mounted) {
        NotificationService.instance.showInfo(
          'Cart cleared',
        );

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Cart cleared'),
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      }
    } catch (e) {
      if (mounted) {

        NotificationService.instance.showError(
          'Error clearing cart',
        );

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Error clearing cart'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    }
  }

  Future<void> DineinCart() async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TableScreen()));
  }

  // Handle customer selection from autocomplete
  void _onCustomerSelected(RestaurantCustomer customer) {
    setState(() {
      selectedCustomer = customer;
      nameController.text = customer.name ?? '';
      emailController.text = ''; // Email not stored in customer model
      mobileController.text = customer.phone ?? '';
    });
  }

  // Update customer statistics (visits, loyalty points, last visit, etc.)
  Future<void> _updateCustomerStats(RestaurantCustomer customer, String orderType, {int pointsToEarn = 0}) async {
    try {

      await restaurantCustomerStore.updateCustomerVisit(
        customerId: customer.customerId,
        orderType: orderType,
        pointsToAdd: pointsToEarn,
      );

      // Verify the update
      final updatedCustomer = await restaurantCustomerStore.getCustomerById(customer.customerId);
      if (updatedCustomer != null) {
      } else {
      }
    } catch (e) {
    }
  }

  // Check if customer exists or create new customer
  Future<RestaurantCustomer?> _getOrCreateCustomer(String name, String phone, String orderType) async {
    try {
      // If customer is already selected, return it
      if (selectedCustomer != null) {
        return selectedCustomer;
      }

      // Skip if both name and phone are empty
      if (name.trim().isEmpty && phone.trim().isEmpty) {
        return null;
      }

      // Search for existing customer by phone number (phone is more unique than name)
      if (phone.trim().isNotEmpty) {
        final searchResults = await restaurantCustomerStore.searchCustomers(phone.trim());

        // Check if we have an exact phone match
        for (var customer in searchResults) {
          if (customer.phone?.trim().toLowerCase() == phone.trim().toLowerCase()) {
            return customer;
          }
        }
      }

      // If not found and we have at least phone or name, create new customer
      if (phone.trim().isNotEmpty || name.trim().isNotEmpty) {

        final newCustomer = RestaurantCustomer.create(
          customerId: Uuid().v4(),
          name: name.trim().isEmpty ? null : name.trim(),
          phone: phone.trim().isEmpty ? null : phone.trim(),
        );

        await restaurantCustomerStore.addCustomer(newCustomer);

        return newCustomer;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  late final PaymentMethodStore _paymentMethodStore;

  TextEditingController nameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController remarkController = TextEditingController();

  // Customer selection
  RestaurantCustomer? selectedCustomer;
  List<RestaurantCustomer> nameSuggestions = [];
  List<RestaurantCustomer> phoneSuggestions = [];
  bool showNameSuggestions = false;
  bool showPhoneSuggestions = false;

  // NEW ORDER
  Future<void> _placeOrder(CartCalculationService calculations) async {
    // Block if no active day session — orders placed without a session are excluded from EOD
    final bool sessionOpen = await DayManagementService.isSessionOpen();
    if (!sessionOpen) {
      if (mounted) {
        Navigator.pop(context);
        NotificationService.instance.showError(
          'No active session. Please start the day from the End Day menu first.',
        );
      }
      return;
    }

    final plainItems = widget.cartItems.map((w) => w.item).toList();

    // Validate mobile number if entered
    final phone = mobileController.text.trim();
    if (phone.isNotEmpty) {
      final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length != 10) {
        NotificationService.instance.showError('Mobile number must be exactly 10 digits');
        return;
      }
    }

    // Check stock availability before placing order
    final bool stockAvailable = await InventoryService.checkStockAvailability(plainItems);
    if (!stockAvailable) {
      if (mounted) {
        Navigator.pop(context);
        NotificationService.instance.showError(
          'Cannot place order: Some items are out of stock or have insufficient quantity',
        );

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Cannot place order: Some items are out of stock or have insufficient quantity'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
      return; // Stop order placement
    }

    // Get or create customer BEFORE creating the order so we can link them
    final customer = await _getOrCreateCustomer(
      nameController.text.trim(),
      mobileController.text.trim(),
      widget.isDineIn ? 'Dine In' : 'Take Away',
    );

    if (customer != null) {
    }

    final int newKotNumber = await orderStore.getNextKotNumber();

    // Generate daily order number
    final int orderNumber = await orderStore.getNextOrderNumber();

    // Get current session ID
    final currentSessionId = await DayManagementService.getCurrentSessionId();

    final neworder = OrderModel(
      id: Uuid().v4(),
      customerName: nameController.text.trim(),
      customerNumber: mobileController.text.trim(),
      customerEmail: emailController.text.trim(),
      items: plainItems,
      status: 'Processing',
      timeStamp: DateTime.now(),
      orderType: widget.isDineIn ? 'Dine In' : 'Take Away',
      // kotNumber removed - using kotNumbers only
      tableNo: widget.selectedTableNo ?? '',
      // widget.selectedTableNo.toString()
      remark: remarkController.text.trim(),

      // ✅ Use the service as the single source of truth for ALL financial data
      subTotal: AppSettings.isTaxInclusive
          ? calculations.subtotal - calculations.totalGST
          : calculations.subtotal,
      gstAmount: calculations.totalGST,
      totalPrice: calculations.grandTotal, // This is the final, correct amount to be paid
      gstRate: 0, // You can enhance your service to provide this if needed

      // Initialize KOT tracking fields - single source of truth
      kotNumbers: [newKotNumber],
      itemCountAtLastKot: plainItems.length,
      kotBoundaries: [plainItems.length], // First KOT boundary at item count
      kotStatuses: {newKotNumber: 'Processing'}, // Initialize first KOT status
      orderNumber: orderNumber, // Daily order number
      customerId: customer?.customerId, // Link to customer (now properly set)
      isTaxInclusive: AppSettings.isTaxInclusive, // Store tax mode at order creation
      sessionId: currentSessionId, // Link to POS session
    );

    await orderStore.addOrder(neworder);

    // NOTE: Customer stats (visits + points) are updated only at settlement, not here.
    // Adding points on order placement would double-count when the order is later settled.


    // Auto-print KOT directly to printer (only if Generate KOT setting is enabled)
    if (mounted && AppSettings.generateKOT) {
      try {
        await RestaurantPrintHelper.printKOT(
          context: context,
          order: neworder,
          kotNumber: newKotNumber,
          autoPrint: true, // Direct print without preview
        );
      } catch (e) {
        // Don't block order placement if print fails
      }
    } else if (!AppSettings.generateKOT) {
    }

    // Deduct stock after successfully adding the order
    await InventoryService.deductStockForOrder(plainItems);

    // print("")
    if (widget.isDineIn && widget.selectedTableNo != null) {
      // Also use the correct total here
      await tableStore.updateTableStatus(
        widget.selectedTableNo!,
        'Running',
        total: neworder.totalPrice,
        orderId: neworder.id,
        orderTime: neworder.timeStamp,
      );
    }

    await clearCart();

    if (mounted) {
      Navigator.of(context).pop(); // Pop the dialog first
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Startorder()),
            (Route<dynamic> route) => false,
      );
      NotificationService.instance.showSuccess(
        'Order Placed Successfully',
      );


      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order Placed Successfully')));
    }
  }




  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    remarkController.dispose();
    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    _paymentMethodStore = locator<PaymentMethodStore>();
    if (_paymentMethodStore.paymentMethods.isEmpty) {
      _paymentMethodStore.init();
    }
    if (widget.isexisting && widget.existingModel != null) {
      final m = widget.existingModel!;
      nameController.text   = m.customerName   ?? '';
      mobileController.text = m.customerNumber ?? '';
      emailController.text  = m.customerEmail  ?? '';
      remarkController.text = m.remark         ?? '';
      // Restore the linked customer so _getOrCreateCustomer skips search/create
      if (m.customerId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final customer = await restaurantCustomerStore.getCustomerById(m.customerId!);
          if (mounted && customer != null) {
            setState(() => selectedCustomer = customer);
          }
        });
      }
    }
  }
  Future<void> _updateExistingOrder(CartCalculationService calculations) async {
    if (!widget.isexisting || widget.existingModel == null) return;
    final existingModel = widget.existingModel!;

    final List<CartItem> currentActiveItems = widget.cartItems.where((w) => w.isActive).map((w) => w.item).toList();
    final List<CartItem> newlyAddedItems    = widget.cartItems.where((w) => !w.isActive).map((w) => w.item).toList();
    final List<CartItem> allCurrentItems    = [...currentActiveItems, ...newlyAddedItems];

    if (allCurrentItems.isEmpty) {
      NotificationService.instance.showError('Cannot place order: cart is empty');
      return;
    }

    // Snapshot of original state (passed from cart.dart)
    final List<CartItem> originalItems = widget.originalActiveItems ?? existingModel.items;
    final Map<String, int> origQtyMap  = widget.originalQuantities  ?? {for (final i in originalItems) i.id: i.quantity};

    int getKotNumberForItem(String itemId) {
      final int idx = originalItems.indexWhere((orig) => orig.id == itemId);
      if (idx == -1) return 0;
      final boundaries = existingModel.kotBoundaries;
      final kotNums = existingModel.getKotNumbers();
      for (int i = 0; i < boundaries.length; i++) {
        if (idx < boundaries[i]) {
          return i < kotNums.length ? kotNums[i] : 0;
        }
      }
      return 0;
    }

    // Items removed entirely from the active list
    final List<CartItem> removedItems = originalItems
        .where((orig) => !currentActiveItems.any((curr) => curr.id == orig.id))
        .map((orig) => orig.copyWith(instruction: 'Cancelled from KOT #${getKotNumberForItem(orig.id)}'))
        .toList();

    // Items still present but with changed quantity → inventory delta items
    final List<CartItem> stockToDeduct  = [];
    final List<CartItem> stockToRestore = [];
    for (final curr in currentActiveItems) {
      final origQty = origQtyMap[curr.id];
      if (origQty == null) continue;
      final delta = curr.quantity - origQty;
      if (delta > 0) {
        stockToDeduct.add(CartItem(
          id: curr.id, title: curr.title, price: curr.price,
          productId: curr.productId, quantity: delta,
          variantName: curr.variantName, weightDisplay: curr.weightDisplay,
          discount: curr.discount,
        ));
      } else if (delta < 0) {
        stockToRestore.add(CartItem(
          id: curr.id, title: curr.title, price: curr.price,
          productId: curr.productId, quantity: -delta,
          variantName: curr.variantName, weightDisplay: curr.weightDisplay,
          discount: curr.discount,
          instruction: 'Reduced from KOT #${getKotNumberForItem(curr.id)}',
        ));
      }
    }

    final bool hasNewItems  = newlyAddedItems.isNotEmpty;
    final bool hasCorrection = removedItems.isNotEmpty || stockToRestore.isNotEmpty;

    // Items to include in correction KOT (removed + reduced)
    final List<CartItem> correctionItems = [
      ...removedItems,
      ...stockToRestore,
    ];

    // Build KOT structure from staged local state
    List<int> updatedKotNumbers    = List<int>.from(widget.currentKotNumbers ?? existingModel.getKotNumbers());
    List<int> updatedKotBoundaries = List<int>.from(widget.currentKotBoundaries ?? existingModel.kotBoundaries);
    Map<int, String> updatedKotStatuses = Map<int, String>.from(existingModel.kotStatuses ?? {});

    int? newAddedKotNumber;
    if (hasNewItems) {
      newAddedKotNumber = await orderStore.getNextKotNumber();
      updatedKotNumbers.add(newAddedKotNumber);
      updatedKotBoundaries.add(currentActiveItems.length + newlyAddedItems.length);
      updatedKotStatuses[newAddedKotNumber] = 'Processing';
    }

    final currentSessionId = await DayManagementService.getCurrentSessionId();

    final updateOrder = existingModel.copyWith(
      items: allCurrentItems,
      totalPrice: calculations.grandTotal,
      subTotal: AppSettings.isTaxInclusive
          ? calculations.subtotal - calculations.totalGST
          : calculations.subtotal,
      gstAmount: calculations.totalGST,
      customerName: nameController.text.isNotEmpty ? nameController.text : existingModel.customerName,
      customerNumber: mobileController.text.isNotEmpty ? mobileController.text : existingModel.customerNumber,
      tableNo: widget.selectedTableNo ?? existingModel.tableNo,
      kotNumbers: updatedKotNumbers,
      itemCountAtLastKot: allCurrentItems.length,
      kotBoundaries: updatedKotBoundaries,
      kotStatuses: updatedKotStatuses,
      sessionId: currentSessionId ?? existingModel.sessionId,
    );

    await orderStore.updateOrder(updateOrder);

    // Apply all inventory changes at commit time
    for (final item in removedItems) await InventoryService.restoreStockForOrder([item]);
    if (stockToRestore.isNotEmpty) await InventoryService.restoreStockForOrder(stockToRestore);
    if (stockToDeduct.isNotEmpty)  await InventoryService.deductStockForOrder(stockToDeduct);
    if (hasNewItems) await InventoryService.deductStockForOrder(newlyAddedItems);

    // WebSocket: new items KOT
    if (hasNewItems && newAddedKotNumber != null) {
      try {
        final kotStatusesJson = updatedKotStatuses.map((k, v) => MapEntry(k.toString(), v));
        ws.broadcastEvent({
          'type': 'NEW_ITEMS_ADDED',
          'orderId': updateOrder.id,
          'status': updateOrder.status,
          'tableNo': updateOrder.tableNo,
          'kotNumber': newAddedKotNumber,
          'newItemCount': newlyAddedItems.length,
          'allKotNumbers': updatedKotNumbers,
          'kotBoundaries': updatedKotBoundaries,
          'kotStatuses': kotStatusesJson,
        });
      } catch (e) {}
    }

    // WebSocket: correction (removals / quantity reductions)
    if (hasCorrection) {
      try {
        ws.broadcastEvent({
          'type': 'ORDER_MODIFIED',
          'orderId': updateOrder.id,
          'tableNo': updateOrder.tableNo,
          'removedItems': removedItems.map((i) => {'id': i.id, 'title': i.title, 'quantity': i.quantity}).toList(),
          'reducedItems': stockToRestore.map((i) => {'id': i.id, 'title': i.title, 'reducedBy': i.quantity}).toList(),
        });
      } catch (e) {}
    }

    // Print new-items KOT
    if (hasNewItems && newAddedKotNumber != null && mounted && AppSettings.generateKOT) {
      try {
        await RestaurantPrintHelper.printKOT(
          context: context,
          order: updateOrder,
          kotNumber: newAddedKotNumber,
          autoPrint: true,
        );
      } catch (e) {}
    }

    // Print correction KOT for removed / reduced items
    if (correctionItems.isNotEmpty && mounted && AppSettings.generateKOT) {
      try {
        final correctionKotNumber = await orderStore.getNextKotNumber();
        final correctionOrder = existingModel.copyWith(
          items: correctionItems,
          kotNumbers: [correctionKotNumber],
          kotBoundaries: [correctionItems.length],
          kotStatuses: {correctionKotNumber: 'CANCEL'},
        );

        final uniqueKots = correctionItems.map((i) {
           final match = RegExp(r'#(\d+)').firstMatch(i.instruction ?? '');
           return match != null ? match.group(1) : null;
        }).where((e) => e != null).toSet().toList();
        final cancelRef = uniqueKots.isNotEmpty ? 'KOT #${uniqueKots.join(', ')}' : null;

        await RestaurantPrintHelper.printKOT(
          context: context,
          order: correctionOrder,
          kotNumber: correctionKotNumber,
          autoPrint: true,
          cancelReference: cancelRef,
        );
      } catch (e) {}
    }

    // Update table total
    if (updateOrder.tableNo != null) {
      await tableStore.updateTableStatus(
        updateOrder.tableNo!,
        updateOrder.status,
        total: calculations.grandTotal,
        orderId: updateOrder.id,
        orderTime: updateOrder.timeStamp,
      );
    }

    await clearCart();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Startorder()),
        (Route<dynamic> route) => false,
      );

      final msgParts = <String>[];
      if (hasNewItems && newAddedKotNumber != null) msgParts.add('New KOT #$newAddedKotNumber');
      if (hasCorrection) msgParts.add('Correction KOT printed');

      NotificationService.instance.showSuccess(
        msgParts.isNotEmpty ? 'Order Updated — ${msgParts.join(' • ')}' : 'Order Updated',
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final plainItems  = widget.cartItems.map((w)=> w.item).toList();

    // ✅ FIX: Use saved values from existing order to show correct total
    final double discountValue;
    final double serviceChargeValue;
    final double deliveryChargeValue;

    if (widget.isexisting && widget.existingModel != null) {
      // Use the saved values from the existing order
      discountValue = widget.existingModel!.discount ?? 0.0;
      // For delivery orders, serviceCharge field stores the delivery charge
      if (widget.isdelivery) {
        serviceChargeValue = 0.0;
        deliveryChargeValue = widget.existingModel!.serviceCharge ?? 0.0;
      } else {
        serviceChargeValue = widget.existingModel!.serviceCharge ?? 0.0;
        deliveryChargeValue = 0.0;
      }
    } else {
      // For new orders, use default values
      discountValue = 0.0;
      serviceChargeValue = 0.0;
      deliveryChargeValue = 0.0;
    }

    // ✅ 1. Create an instance of the service here with correct values
    final calculations = CartCalculationService(
      items: plainItems,
      discountType: DiscountType.amount,
      discountValue: discountValue,
      serviceChargePercentage: serviceChargeValue,
      deliveryCharge: deliveryChargeValue,
      isDeliveryOrder: widget.isdelivery,
      // Use stored tax mode from existing order, or current app setting for new orders
      isTaxInclusive: widget.isexisting
          ? (widget.existingModel?.isTaxInclusive ?? AppSettings.isTaxInclusive)
          : AppSettings.isTaxInclusive,
    );



    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Column(
      children: [
        // Cart items
        Expanded(
          child: widget.cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                      SizedBox(height: 8),
                      Text('Your cart is empty', style: GoogleFonts.poppins(fontSize: AppResponsive.getValue<double>(context, mobile: 14, tablet: 16), color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          if (widget.isDineIn)
                            Text("Table ${widget.selectedTableNo}", style: GoogleFonts.poppins(fontSize: AppResponsive.getValue<double>(context, mobile: 12, tablet: 14), fontWeight: FontWeight.w500, color: Colors.grey.shade600))
                          else
                            Text(widget.isexisting ? 'Existing Order' : 'New Order', style: GoogleFonts.poppins(fontSize: AppResponsive.getValue<double>(context, mobile: 12, tablet: 14), fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Expanded(child: _buildGroupedCartItems()),
                  ],
                ),
        ),

        // Bottom: total + buttons
        SafeArea(
          top: false,
          child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.poppins(fontSize: AppResponsive.getValue<double>(context, mobile: 15, tablet: 17, desktop: 18), fontWeight: FontWeight.w500)),
                  Text(
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)}',
                    style: GoogleFonts.poppins(fontSize: AppResponsive.getValue<double>(context, mobile: 17, tablet: 20, desktop: 22), fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
              SizedBox(height: 12),
              widget.isexisting ? _existingButtons(height, width, calculations) : _neworderButtons(height, width, calculations),
            ],
          ),
        ),
        ), // SafeArea
      ],
    );
  }

  Widget _existingButtons(double height, double width, CartCalculationService calculations) {
    final plainItems = widget.cartItems.map((w) => w.item).toList();

    if (widget.isdelivery) {
      return SizedBox(width: double.infinity, child: _buildActionButton('Place Order', () => _updateExistingOrder(calculations)));
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Settle (${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)})',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => Customerdetails(
                  tableid: widget.tableid, existingModel: widget.existingModel,
                  cartitems: plainItems, totalPrice: calculations.grandTotal,
                ))),
              ),
            ),
            SizedBox(width: 8),
            Expanded(child: _buildActionButton('Place Order', () => _updateExistingOrder(calculations))),
          ],
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.cartItems.isEmpty || widget.existingModel == null ? null : () async {
              try {
                await RestaurantPrintHelper.printBillForActiveOrder(context: context, order: widget.existingModel!, currentItems: plainItems);
              } catch (e) {
                NotificationService.instance.showError('Failed to print bill');
              }
            },
            icon: Icon(Icons.print_outlined, size: 16),
            label: Text('Print Bill', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    final btnFs = AppResponsive.getValue<double>(context, mobile: 13, tablet: 15, desktop: 16);
    final btnPad = AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 18);
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: btnPad),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: btnFs, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    );
  }

  Widget _neworderButtons(double height, double width, CartCalculationService calculations) {
    final plainItems = widget.cartItems.map((w) => w.item).toList();

    if (widget.isdelivery) {
      return SizedBox(
        width: double.infinity,
        child: _buildActionButton('Place Order', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => Customerdetails(
            tableid: widget.tableid, cartitems: plainItems,
            totalPrice: calculations.grandTotal, orderType: 'Delivery', isSettle: true,
          )));
        }),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton('Place Order', () {
                nameSuggestions = []; phoneSuggestions = [];
                showNameSuggestions = false; showPhoneSuggestions = false;
                _showPlaceOrderDialog(height, calculations);
              }),
            ),
            SizedBox(width: 8),
            Expanded(child: _buildActionButton('Quick Settle', () => _showQuickSettleSheet(calculations))),
          ],
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.cartItems.isEmpty ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => Customerdetails(
                tableid: widget.tableid, cartitems: plainItems,
                totalPrice: calculations.grandTotal, orderType: widget.isDineIn ? 'Dine In' : 'Take Away', isSettle: true,
              )));
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
            ),
            child: Text('Settle & Print Bill', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  /// Place order dialog — extracted from inline builder
  void _showPlaceOrderDialog(double height, CartCalculationService calculations) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Widget suggestionList(List<RestaurantCustomer> suggestions, void Function(RestaurantCustomer) onSelect) {
              return Container(
                constraints: const BoxConstraints(maxHeight: 140),
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, index) {
                    final c = suggestions[index];
                    return InkWell(
                      onTap: () => onSelect(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text(c.name?.isNotEmpty == true ? c.name![0].toUpperCase() : '?',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                  Text('${c.phone ?? ''} • ${c.totalVisites} visits', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 460,
                constraints: BoxConstraints(maxHeight: height * 0.85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(child: Text('Place Order', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
                          IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: Icon(Icons.close, size: 20, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selected customer chip
                            if (selectedCustomer != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Text(selectedCustomer!.name ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                                    Spacer(),
                                    Text('${selectedCustomer!.totalVisites} visits', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => setDialogState(() {
                                        selectedCustomer = null; nameController.clear(); emailController.clear(); mobileController.clear();
                                      }),
                                      child: Icon(Icons.close, size: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            AppTextField(
                              controller: nameController, label: 'Customer Name', hint: 'e.g. John Doe', icon: Icons.person_outline,
                              onChanged: (value) async {
                                if (value.isEmpty) { setDialogState(() { showNameSuggestions = false; nameSuggestions = []; }); }
                                else { final r = await restaurantCustomerStore.searchCustomers(value); setDialogState(() { nameSuggestions = r; showNameSuggestions = r.isNotEmpty; }); }
                              },
                            ),
                            if (showNameSuggestions && nameSuggestions.isNotEmpty)
                              suggestionList(nameSuggestions, (c) { setDialogState(() {
                                selectedCustomer = c; nameController.text = c.name ?? ''; emailController.text = ''; mobileController.text = c.phone ?? '';
                                showNameSuggestions = false; nameSuggestions = [];
                              }); })
                            else const SizedBox(height: 12),

                            AppTextField(
                              controller: mobileController, label: 'Mobile', hint: 'e.g. 9876543210', icon: Icons.phone_outlined,
                              keyboardType: TextInputType.number, maxLength: 10,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (value) async {
                                if (value.isEmpty) { setDialogState(() { showPhoneSuggestions = false; phoneSuggestions = []; }); }
                                else { final r = await restaurantCustomerStore.searchCustomers(value); setDialogState(() { phoneSuggestions = r; showPhoneSuggestions = r.isNotEmpty; }); }
                              },
                            ),
                            if (showPhoneSuggestions && phoneSuggestions.isNotEmpty)
                              suggestionList(phoneSuggestions, (c) { setDialogState(() {
                                selectedCustomer = c; nameController.text = c.name ?? ''; emailController.text = ''; mobileController.text = c.phone ?? '';
                                showPhoneSuggestions = false; phoneSuggestions = [];
                              }); })
                            else const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(child: AppTextField(controller: emailController, label: 'Email', hint: 'Optional', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress)),
                                const SizedBox(width: 12),
                                Expanded(child: AppTextField(controller: remarkController, label: 'Remark', hint: 'e.g. No onions', icon: Icons.note_alt_outlined)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                                Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)}',
                                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(),
                            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildActionButton('Place Order', () => _placeOrder(calculations))),
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

  Future<void> completeOrder(OrderModel activeModel) async {

    // Generate daily bill number for completed order
    final int billNumber = await orderStore.getNextBillNumber();

    // Directly convert the active order to a past order.
    // All calculations (GST, subtotal) were already done and saved on the activeModel.
    final pastOrder = PastOrderModel(
      id: activeModel.id,
      customerName: activeModel.customerName,
      totalPrice: activeModel.totalPrice,
      items: activeModel.items,
      orderAt: activeModel.timeStamp,
      orderType: activeModel.orderType,
      paymentmode: activeModel.paymentMethod ?? 'Cash', // Use the payment method if available
      subTotal: activeModel.subTotal,
      gstRate: activeModel.gstRate,
      gstAmount: activeModel.gstAmount,
      kotNumbers: activeModel.kotNumbers, // Always present in new orders
      kotBoundaries: activeModel.kotBoundaries, // KOT boundaries for grouping items
      billNumber: billNumber, // Daily bill number (resets every day)
      isTaxInclusive: activeModel.isTaxInclusive, // Use stored tax mode from active order
      shiftId: RestaurantSession.currentShiftId,
    );

    await pastOrderStore.addOrder(pastOrder);

    // This is the critical missing step: delete the order from the ACTIVE list.
    await orderStore.deleteOrder(activeModel.id);
  }

  void _showQuickSettleSheet(CartCalculationService calculations) {
    final methods = _paymentMethodStore.enabledMethods;
    String selected = methods.isNotEmpty ? methods.first.name : 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.flash_on_rounded, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Quick Settle', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700))),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 18, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Total amount card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount to Collect', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                        Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)}',
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payment method label
                  Text('Select Payment Method', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  const SizedBox(height: 10),

                  // Payment chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: methods.map((m) {
                      final isSelected = selected == m.name;
                      return GestureDetector(
                        onTap: () => setDialog(() => selected = m.name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300, width: 1.5),
                            boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))] : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_paymentIcon(m.name), size: 16, color: isSelected ? Colors.white : Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(m.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: Colors.grey.shade300),
                            foregroundColor: Colors.grey.shade700,
                          ),
                          child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _qucikSettleNewOrder(calculations, selected);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text('Settle Now', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
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
  }

  IconData _paymentIcon(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('cash')) return Icons.payments_outlined;
    if (lower.contains('card') || lower.contains('credit') || lower.contains('debit')) return Icons.credit_card_outlined;
    if (lower.contains('upi') || lower.contains('qr')) return Icons.qr_code_outlined;
    if (lower.contains('wallet')) return Icons.account_balance_wallet_outlined;
    if (lower.contains('bank') || lower.contains('transfer') || lower.contains('neft')) return Icons.account_balance_outlined;
    return Icons.payment_outlined;
  }

// Replace your entire _qucikSettleNewOrder function with this one.
  Future<void> _qucikSettleNewOrder(CartCalculationService calculations, String paymentMethod) async {
    // Get the plain cart items
    final plainItems = widget.cartItems.map((w) => w.item).toList();

    // Check stock availability before processing order
    final bool stockAvailable = await InventoryService.checkStockAvailability(plainItems);
    if (!stockAvailable) {
      if (mounted) {

        NotificationService.instance.showError(
            'Cannot process order: Some items are out of stock or have insufficient quantity'
        );


        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Cannot process order: Some items are out of stock or have insufficient quantity'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
      return; // Stop order processing
    }

    // No need for a temporary OrderModel. We create the final pastOrderModel directly.
    final int quickSettleKotNumber = await orderStore.getNextKotNumber();

    // Generate daily bill number for quick settle
    final int billNumber = await orderStore.getNextBillNumber();

    // Get current session ID
    final currentSessionId = await DayManagementService.getCurrentSessionId();

    final pastOrder = PastOrderModel(
      id: Uuid().v4(), // Generate a unique ID for this transaction
      customerName: 'Quick Settle',
      totalPrice: calculations.grandTotal, // ✅ Use the final grand total from the service
      items: plainItems,
      orderAt: DateTime.now(),
      orderType: widget.isDineIn ? 'Dine In' : 'Take Away',
      paymentmode: paymentMethod,

      // ✅ Use the CORRECT values from the calculation service
      subTotal: AppSettings.isTaxInclusive
          ? calculations.subtotal - calculations.totalGST
          : calculations.subtotal,
      gstAmount: calculations.totalGST,
      gstRate: 0,

      // ✅ KOT tracking - REQUIRED
      kotNumbers: [quickSettleKotNumber],
      kotBoundaries: [plainItems.length], // Single KOT with all items
      billNumber: billNumber, // Daily bill number (resets every day)
      isTaxInclusive: AppSettings.isTaxInclusive, // Store tax mode at order creation
      tableNo: widget.isDineIn ? (widget.selectedTableNo ?? widget.tableid) : null,
      shiftId: RestaurantSession.currentShiftId,
      sessionId: currentSessionId, // Link to POS session
    );

    // 1. Add the completed order to history
    await pastOrderStore.addOrder(pastOrder);

    // 2. Deduct stock after successfully adding the order
    await InventoryService.deductStockForOrder(plainItems);

    // 3. Free the table for Dine In quick settle
    final String? tableForQuickSettle = widget.isDineIn
        ? (widget.selectedTableNo ?? widget.tableid)
        : null;
    if (tableForQuickSettle != null && tableForQuickSettle.isNotEmpty) {
      await tableStore.updateTableStatus(tableForQuickSettle, 'Available');
    }

    // 4. Clear the user's cart
    await restaurantCartStore.clearCart();

    // 4. Navigate and show success message
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Startorder()),
            (Route<dynamic> route) => false,
      );
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quick Settle Successful')));

      NotificationService.instance.showSuccess(
          'Quick Settle Successful'
      );
    }
  }


}
