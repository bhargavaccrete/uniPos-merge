import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../../domain/services/restaurant/cart_calculation_service.dart';
import '../../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../../../../util/restaurant/staticswitch.dart';
import '../../../../../util/restaurant/order_settings.dart';
import '../../../../../data/models/restaurant/db/customer_model_125.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';
import '../../tabbar/table.dart';
import '../startorder.dart';
import 'customerdetails.dart';
import '../../util/restaurant_print_helper.dart';
import '../../../../../server/websocket.dart' as ws;
import 'package:unipos/util/common/decimal_settings.dart';
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
        this.selectedTableNo});

  @override
  State<Takeaway> createState() => _TakeawayState();
}

class _TakeawayState extends State<Takeaway> {




  /* double get totalPrice {

    // This print statement tells us the function is running.
    print("--- Checking totalPrice ---");

    final double originalTotal = widget.cartItems.fold(0.0, (sum, item) => sum + item.item.totalPrice);

    print("1. Original Total: $originalTotal");

    // This will print true, false, or null, telling us what the app sees.
    print("2. Is 'Round Off' setting on? ${AppSettings.values['Round Off']}");

    if (AppSettings.values['Round Off'] == true) {
      print("   -> Rounding is ON. Proceeding with calculation.");

      final String roundOffSettingValue = AppSettings.selectedRoundOffValue;
      print("3. Rounding to nearest: $roundOffSettingValue");

      final double roundTO = double.tryParse(roundOffSettingValue) ?? 1.0;

      if (roundTO > 0) {
        final double finalPrice = (originalTotal / roundTO).round() * roundTO;
        print("4. Final Calculated Price: $finalPrice");
        return finalPrice;
      }
    }

    print("-> Rounding is OFF or setting not found. Returning original total.");
    return originalTotal;
  }*/

  // Active/NEW Lable
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
          _buildItemSection('ACTIVE', Colors.green, activeItems),

        // Add spacing between sections
        if (activeItems.isNotEmpty && newItems.isNotEmpty)
          SizedBox(height: 16),

        // New Items Section
        if (newItems.isNotEmpty)
          _buildItemSection('NEW', Colors.blue, newItems),
      ],
    );
  }

  // Group items by KOT number for existing orders
  Widget _buildKotGroupedItems() {
    if (widget.existingModel == null) return SizedBox();

    final existingModel = widget.existingModel!;
    final List<int> kotNumbers = existingModel.kotNumbers;
    final List<int> kotBoundaries = existingModel.kotBoundaries;

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

          // Show ACTIVE items for this KOT
          if (activeKotItems.isNotEmpty) {
            kotSections.add(
                _buildItemSection('KOT #$kotNum - ACTIVE', Colors.green, activeKotItems)
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
            _buildItemSection('NEW ITEMS (Pending KOT)', Colors.orange, newItems)
        );
      }
    }

    return ListView(
      children: kotSections,
    );
  }

  Widget _buildItemSection(String title, Color color, List<CartItemStatus> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(color: color, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items List
          ...items.asMap().entries.map((entry) {
            int index = entry.key;
            CartItemStatus item = entry.value;
            bool isLastItem = index == items.length - 1;

            return Column(
              children: [
                buildCartItemRow(item),
                if (!isLastItem) Divider(height: 1, color: color.withOpacity(0.3)),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // Widget _buildSectionHeader(String title, Color color, int itemCount) {
  //   return Container(
  //     width: double.infinity,
  //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: color, width: 1),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Text(
  //           title,
  //           style: GoogleFonts.poppins(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //             color: color,
  //           ),
  //         ),
  //         Container(
  //           padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //           decoration: BoxDecoration(
  //             color: color,
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Text(
  //             '$itemCount',
  //             style: GoogleFonts.poppins(
  //               fontSize: 12,
  //               fontWeight: FontWeight.bold,
  //               color: Colors.white,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget buildCartItemRow(CartItemStatus wrapped) {
    final item = wrapped.item;
    final Color deepBlue = Color(0xFF0D47A1);
    print(item.title);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: deepBlue.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Item Name and Weight
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.1,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.weightDisplay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Text(
                          item.weightDisplay!,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              // Quantity Controls
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: deepBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => widget.onDecreseQty(item),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: deepBlue.withOpacity(0.3), width: 1),
                        ),
                        child: Icon(
                          Icons.remove,
                          color: deepBlue,
                          size: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        item.quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: deepBlue,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => widget.onIncreseQty(item),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: deepBlue,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: deepBlue.withOpacity(0.3),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              // Price
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: deepBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: deepBlue.withOpacity(0.2), width: 1),
                  ),
                  child: Text(
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.totalPrice)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: deepBlue,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),

            if (item.variantName != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.blue.shade700),
                    SizedBox(width: 6),
                    Text(
                      'Size: ${item.variantName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.variantPrice ?? 0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

            if (item.choiceNames != null && item.choiceNames!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 14, color: Colors.orange.shade700),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Add-ons: ${item.choiceNames!.join(', ')}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (item.extras != null && item.extras!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100.withOpacity(0.5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200, width: 1),
                ),
                child: Builder(
                  builder: (context) {
                    // Group extras by name and count them
                    Map<String, Map<String, dynamic>> groupedExtras = {};

                    for (var extra in item.extras!) {
                      // Debug: Print what data we have
                      print('=== EXTRA DEBUG ===');
                      print('Extra data: $extra');
                      print('Extra keys: ${extra.keys}');
                      print('name: ${extra['name']}');
                      print('displayName: ${extra['displayName']}');
                      print('categoryName: ${extra['categoryName']}');
                      print('quantity: ${extra['quantity']}');
                      print('===================');

                      // Try multiple ways to get the display name
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

                      // Create a unique key for grouping
                      String key = '$displayName-${price.toStringAsFixed(2)}';

                      if (groupedExtras.containsKey(key)) {
                        // If extra already exists, increment quantity
                        groupedExtras[key]!['quantity'] = (groupedExtras[key]!['quantity'] as int) + itemQuantity;
                      } else {
                        // Add new extra
                        groupedExtras[key] = {
                          'displayName': displayName,
                          'price': price,
                          'quantity': itemQuantity,
                        };
                      }
                    }

                    // Build the display string
                    String extrasText = groupedExtras.entries.map((entry) {
                      final data = entry.value;
                      final int qty = data['quantity'] as int;
                      final String name = data['displayName'] as String;
                      final double price = data['price'] as double;

                      if (qty > 1) {
                        return '${qty}x $name(${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)})';
                      } else {
                        return '$name(${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)})';
                      }
                    }).join(', ');

                    return Text('extra : $extrasText');
                  },
                ),
              ),
          ],
        )
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
      print('Error clearing cart: $e');
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
  Future<void> _updateCustomerStats(RestaurantCustomer customer, String orderType) async {
    try {
      print('🔍 Updating customer stats for: ${customer.name} (ID: ${customer.customerId})');
      print('🔍 Current visits: ${customer.totalVisites}, Current points: ${customer.loyaltyPoints}');

      await restaurantCustomerStore.updateCustomerVisit(
        customerId: customer.customerId,
        orderType: orderType,
        pointsToAdd: 10, // Award 10 points per order
      );

      // Verify the update
      final updatedCustomer = await restaurantCustomerStore.getCustomerById(customer.customerId);
      if (updatedCustomer != null) {
        print('✅ Customer stats updated successfully!');
        print('✅ New visits: ${updatedCustomer.totalVisites}, New points: ${updatedCustomer.loyaltyPoints}');
      } else {
        print('❌ Failed to verify customer update');
      }
    } catch (e) {
      print('❌ Error updating customer stats: $e');
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
        print('ℹ️ No customer details provided, skipping customer creation');
        return null;
      }

      // Search for existing customer by phone number (phone is more unique than name)
      if (phone.trim().isNotEmpty) {
        print('🔍 Searching for existing customer with phone: $phone');
        final searchResults = await restaurantCustomerStore.searchCustomers(phone.trim());

        // Check if we have an exact phone match
        for (var customer in searchResults) {
          if (customer.phone?.trim().toLowerCase() == phone.trim().toLowerCase()) {
            print('✅ Found existing customer: ${customer.name} (${customer.customerId})');
            return customer;
          }
        }
        print('ℹ️ No existing customer found with phone: $phone');
      }

      // If not found and we have at least phone or name, create new customer
      if (phone.trim().isNotEmpty || name.trim().isNotEmpty) {
        print('➕ Creating new customer: Name=$name, Phone=$phone');

        final newCustomer = RestaurantCustomer.create(
          customerId: Uuid().v4(),
          name: name.trim().isEmpty ? null : name.trim(),
          phone: phone.trim().isEmpty ? null : phone.trim(),
        );

        await restaurantCustomerStore.addCustomer(newCustomer);
        print('✅ New customer created successfully: ${newCustomer.customerId}');

        return newCustomer;
      }

      return null;
    } catch (e) {
      print('❌ Error in _getOrCreateCustomer: $e');
      return null;
    }
  }

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

/*
  Future<void> _placeOrder() async {
    final plainItems  = widget.cartItems.map((w)=> w.item).toList();
    final gstDetails = _calculateGst(plainItems);
    final int newKotNumber = await orderStore.getNextKotNumber();
    final neworder = OrderModel(
      id: Uuid().v4(),
      customerName: nameController.text,
      customerNumber: mobileController.text,
      customerEmail: emailController.text,
      items: plainItems,
      status: 'Processing',
      timeStamp: DateTime.now(),
      orderType: widget.isDineIn ? 'Dine In' : 'Take Away',
      totalPrice: totalPrice,
      kotNumber: newKotNumber,
      tableNo: widget.selectedTableNo ?? '',
      remark: remarkController.text ?? '',

      // ✅ 2. Save the calculated GST details to the active order
      gstRate: gstDetails['gstRate'],
      gstAmount: gstDetails['totalGstAmount'],
    );

    await orderStore.addOrder(neworder);
    print("✅ New active order saved with GST: ${gstDetails['totalGstAmount']}");

    if (widget.isDineIn && widget.selectedTableNo != null) {
      await tableStore.updateTableStatus(
        widget.selectedTableNo!,
        'Reserved',
        total: totalPrice,
        orderId: neworder.id,
        orderTime: neworder.timeStamp,
      );
    }

    await clearCart();
    print('===================This is New Order==============');
    print(neworder);
    print('===================This is past Order==============');
    // print(pastOrder);
    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Startorder()),
        (Route<dynamic> route) => false,
      );
      NotificationService.instance.showSuccess('Order Placed Successfully');
    }
  }


*/

  // NEW ORDER // This is the corrected and reliable version of your function
  Future<void> _placeOrder(CartCalculationService calculations) async {
    final plainItems = widget.cartItems.map((w) => w.item).toList();

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
      print('✅ Customer linked to order: ${customer.name} (${customer.customerId})');
    }

    final int newKotNumber = await orderStore.getNextKotNumber();

    // Generate daily order number
    final int orderNumber = await orderStore.getNextOrderNumber();

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
    );

    await orderStore.addOrder(neworder);

    // Update customer stats after order is created
    if (customer != null) {
      await _updateCustomerStats(customer, widget.isDineIn ? 'Dine In' : 'Take Away');
    }

    print("✅ New active order saved with Total: ${neworder.totalPrice}");
    print("✅ Order ID: ${neworder.id}");
    print("✅ Table No: ${neworder.tableNo}");
    print("✅ Order Status: ${neworder.status}");
    print("✅ Total orders in store: ${orderStore.orders.length}");

    // Auto-print KOT directly to printer (only if Generate KOT setting is enabled)
    if (mounted && AppSettings.generateKOT) {
      try {
        await RestaurantPrintHelper.printKOT(
          context: context,
          order: neworder,
          kotNumber: newKotNumber,
          autoPrint: true, // Direct print without preview
        );
        print("✅ KOT printed successfully");
      } catch (e) {
        print("⚠️ KOT print failed: $e");
        // Don't block order placement if print fails
      }
    } else if (!AppSettings.generateKOT) {
      print("ℹ️ KOT printing skipped - Generate KOT setting is disabled");
    }

    // Deduct stock after successfully adding the order
    await InventoryService.deductStockForOrder(plainItems);
    print("✅ Stock deducted for order items");
    print("✅ Selected Table id is ${widget.selectedTableNo.toString()}");

    // print("")
    if (widget.isDineIn && widget.selectedTableNo != null) {
      // Also use the correct total here
      print('🔄 Updating table ${widget.selectedTableNo} status to Running');
      await tableStore.updateTableStatus(
        widget.selectedTableNo!,
        'Running',
        total: neworder.totalPrice,
        orderId: neworder.id,
        orderTime: neworder.timeStamp,
      );
      print('✅ Table ${widget.selectedTableNo} status updated');
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
    // TODO: implement initState
    super.initState();
  }
  Future<void> _updateExistingOrder(CartCalculationService calculations) async {
    final plainItems  = widget.cartItems.map((w)=> w.item).toList();

    // Use a direct boolean check.
    if (widget.isexisting && widget.existingModel != null) {
      final existingModel = widget.existingModel!;

      // Check if new items have been added
      final int previousItemCount = existingModel.itemCountAtLastKot ?? existingModel.items.length;
      final int newItemCount = plainItems.length;
      final bool hasNewItems = newItemCount > previousItemCount;

      // Generate new KOT if items were added
      int? newKotNumber;
      List<int> updatedKotNumbers = List<int>.from(existingModel.getKotNumbers());
      List<int> updatedKotBoundaries = List<int>.from(existingModel.kotBoundaries);

      // Track KOT statuses
      Map<int, String> updatedKotStatuses = Map<int, String>.from(existingModel.kotStatuses ?? {});

      if (hasNewItems) {
        // Generate a new KOT for the newly added items
        newKotNumber = await orderStore.getNextKotNumber();
        updatedKotNumbers.add(newKotNumber);
        updatedKotBoundaries.add(newItemCount); // Add boundary at new item count

        // Set new KOT status to 'Processing' (not inheriting parent order status)
        updatedKotStatuses[newKotNumber] = 'Processing';

        print('====== NEW KOT GENERATED ======');
        print('Previous item count: $previousItemCount');
        print('New item count: $newItemCount');
        print('New KOT Number: $newKotNumber');
        print('All KOT Numbers: $updatedKotNumbers');
        print('KOT Boundaries: $updatedKotBoundaries');
        print('KOT Statuses: $updatedKotStatuses');
      }

      final updateOrder = existingModel.copyWith(
        // The `widget.cartItems` now correctly contains the merged list
        items: plainItems,
        totalPrice: calculations.grandTotal,
        // You can also update customer details if they were edited
        customerName: nameController.text.isNotEmpty ? nameController.text : existingModel.customerName,
        customerNumber: mobileController.text.isNotEmpty ? mobileController.text : existingModel.customerNumber,
        // Use the current tableNo (which might have been changed) instead of the old one
        tableNo: widget.selectedTableNo ?? existingModel.tableNo,
        // Update KOT tracking fields
        kotNumbers: updatedKotNumbers,
        itemCountAtLastKot: newItemCount,
        kotBoundaries: updatedKotBoundaries, // Update KOT boundaries
        kotStatuses: updatedKotStatuses, // Update KOT statuses
      );

      print('🔍 UPDATE ORDER DEBUG:');
      print('   Order ID: ${updateOrder.id}');
      print('   Table No: ${updateOrder.tableNo}');
      print('   Status: ${updateOrder.status}');
      print('   Total: ${updateOrder.totalPrice}');
      print('   Items count: ${updateOrder.items.length}');

      await orderStore.updateOrder(updateOrder);

      // Broadcast update to KDS via WebSocket
      if (hasNewItems && newKotNumber != null) {
        try {
          // Convert integer keys to strings for JSON encoding
          final kotStatusesJson = updatedKotStatuses.map((key, value) => MapEntry(key.toString(), value));

          ws.broadcastEvent({
            'type': 'NEW_ITEMS_ADDED',
            'orderId': updateOrder.id,
            'status': updateOrder.status,
            'tableNo': updateOrder.tableNo,
            'kotNumber': newKotNumber,
            'newItemCount': newItemCount - previousItemCount,
            'allKotNumbers': updatedKotNumbers,
            'kotBoundaries': updatedKotBoundaries,
            'kotStatuses': kotStatusesJson,
          });
          print('📡 WebSocket event broadcast: NEW_ITEMS_ADDED to KDS');
        } catch (e) {
          print('⚠️ Failed to broadcast WebSocket event: $e');
        }
      }

      // Auto-print KOT for new items directly to printer (only if Generate KOT setting is enabled)
      if (hasNewItems && newKotNumber != null && mounted && AppSettings.generateKOT) {
        try {
          await RestaurantPrintHelper.printKOT(
            context: context,
            order: updateOrder,
            kotNumber: newKotNumber,
            autoPrint: true, // Direct print without preview
          );
          print("✅ KOT #$newKotNumber printed successfully");
        } catch (e) {
          print("⚠️ KOT print failed: $e");
          // Don't block order update if print fails
        }
      } else if (hasNewItems && !AppSettings.generateKOT) {
        print("ℹ️ KOT printing skipped - Generate KOT setting is disabled");
      }

      // Update the table's total price as well
      if (updateOrder.tableNo != null) {
        print('🔄 UPDATE ORDER: Updating table ${updateOrder.tableNo} status to ${updateOrder.status}');
        print('🔄 UPDATE ORDER: Total = ${calculations.grandTotal}');
        await tableStore.updateTableStatus(
          updateOrder.tableNo!,
          updateOrder.status,
          total: calculations.grandTotal,
          orderId: updateOrder.id,
          orderTime: updateOrder.timeStamp,
        );
        print('✅ UPDATE ORDER: Table ${updateOrder.tableNo} status updated');
      } else {
        print('⚠️ UPDATE ORDER: No table number found, skipping table status update');
      }

      // Clear the cart after successfully updating the order
      await clearCart();

      if (mounted) {
        // Navigate back to Startorder to reset the UI completely
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Startorder()),
          (Route<dynamic> route) => false,
        );

        if (hasNewItems) {
          NotificationService.instance.showSuccess(
            'Order Updated - New KOT #$newKotNumber Generated',
          );
        } else {
          NotificationService.instance.showSuccess(
            'Order Updated Successfully',
          );
        }

        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Order Updated Successfully'))
        // );
      }
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
      isDeliveryOrder: widget.isdelivery ?? false,
      // orderType: widget.isdelivery? 'Delivery' : 'Take Away'
    );



    // print(widget.isexisting);
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Column(
      children: [
        // Header - Compact Design
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1).withOpacity(0.15), Color(0xFF1565C0).withOpacity(0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF0D47A1).withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0D47A1).withOpacity(0.1),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: Color(0xFF0D47A1), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Item',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D47A1),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.shopping_cart_outlined, color: Color(0xFF0D47A1), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Qty',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 40),
              Row(
                children: [
                  Icon(Icons.currency_rupee, color: Color(0xFF0D47A1), size: 16),
                  SizedBox(width: 2),
                  Text(
                    'Price',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Cart Items

        // cart item
        Expanded(
          child: widget.cartItems.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Your cart is empty',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
              : Column(
            children: [
              Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.primary)),
                  child: widget.isDineIn
                      ? Text("Table no:${widget.selectedTableNo.toString()}")
                      : Text(widget.isexisting ? 'Existing Order' : 'New Order')),
              Expanded(
                child: _buildGroupedCartItems(),
              ),
            ],
          ),
        ),

        // Total and Checkout
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              // ✅ Pass the calculations object to _existingButtons
              widget.isexisting ? _existingButtons(height, width, calculations) : _neworderButtons(height, width, calculations)   ],

          ),
        ),
      ],
    );
  }

  Widget _existingButtons(double height, double width, CartCalculationService calculations) {
    return Column(
      children: [
        widget.isdelivery
            ? CommonButton(
          bordercircular: 5,
          width: width * 0.8,
          height: height * 0.05,
          onTap: ()=> _updateExistingOrder(calculations),
          child: Center(
            child: Text(
              'Place Order',
              textScaler: TextScaler.linear(1),
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CommonButton(
              bordercircular: 5,
              width: width * 0.40,
              height: height * 0.06,
              onTap: () {
                // _completeOrder();
                final plainItems = widget.cartItems.map((w) => w.item).toList();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Customerdetails(
                          tableid: widget.tableid,
                          existingModel: widget.existingModel,
                          cartitems: plainItems, // Include all items (old + new)
                          totalPrice: calculations.grandTotal,
                        )));
              },
              child: Center(
                child: Text(
                  'Settle \n (${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)})',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ),
            ),
            widget.isdelivery
                ? SizedBox()
                : CommonButton(
              bordercircular: 5,
              width: width * 0.40,
              height: height * 0.05,
              onTap:()=>_updateExistingOrder(calculations),
              child: Center(
                child: Text(
                  'place Order',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 10,
        ),
        widget.isdelivery
            ? SizedBox()
            : ElevatedButton(
          onPressed: widget.cartItems.isEmpty || widget.existingModel == null
              ? null
              : () async {
            // Handle print bill for existing order
            print('🖨️ Print Bill button pressed');
            print('📦 Cart items count: ${widget.cartItems.length}');
            print('📄 Existing model: ${widget.existingModel?.id}');

            try {
              final plainItems = widget.cartItems.map((w) => w.item).toList();
              print('✅ Plain items count: ${plainItems.length}');

              await RestaurantPrintHelper.printBillForActiveOrder(
                context: context,
                order: widget.existingModel!,
                currentItems: plainItems,
              );

              print('✅ Print completed successfully');
              NotificationService.instance.showSuccess('Bill printed successfully');
            } catch (e, stackTrace) {
              print('❌ Print error: $e');
              print('Stack trace: $stackTrace');
              NotificationService.instance.showError('Failed to print bill: $e');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'print Bill',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _neworderButtons(double height, double width ,  CartCalculationService calculations)  {
    final plainItems = widget.cartItems.map((w) => w.item).toList();

    return Column(
      children: [

        // new order placeorder button
        widget.isdelivery
            ? CommonButton(
          bordercircular: 5,
          width: width * 0.8,
          height: height * 0.05,
          onTap:() {
            // _completeOrder();
            Navigator.push(
                context,
                MaterialPageRoute(

                    builder: (context) => Customerdetails(
                      tableid: widget.tableid,
                      cartitems: plainItems,
                      totalPrice:calculations.grandTotal ,
                      orderType: 'Delivery',
                      isSettle: true,
                    )));
            // Handle checkout
          },
          child: Center(
            child: Text(
              'Place Orderr',
              textScaler: TextScaler.linear(1),
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CommonButton(
              bordercircular: 5,
              width: width * 0.40,
              height: height * 0.05,
              onTap: () {
                // Check if dialog should be shown based on order type and settings
                bool shouldShowDialog = false;

                if (widget.isDineIn && OrderSettings.showDineInDialog) {
                  shouldShowDialog = true;
                } else if (!widget.isDineIn && !widget.isdelivery && OrderSettings.showTakeAwayDialog) {
                  shouldShowDialog = true;
                }

                // If dialog is disabled, directly place order
                if (!shouldShowDialog) {
                  _placeOrder(calculations);
                  return;
                }

                // Clear suggestions before showing dialog
                nameSuggestions = [];
                phoneSuggestions = [];
                showNameSuggestions = false;
                showPhoneSuggestions = false;

                // Show dialog for customer details
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        return AlertDialog(
                          title: Center(
                            child: Text(
                              'Place Order',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          content: Container(
                            width: width * 0.9,
                            height: height * 0.7,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                              Text('Customer Details',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.start),
                              const SizedBox(height: 10),

                              // Show selected customer info
                              if (selectedCustomer != null)
                                Container(
                                  width: width,
                                  padding: EdgeInsets.all(8),
                                  margin: EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.green.shade200,
                                        child: Text(
                                          selectedCustomer!.name?.isNotEmpty == true
                                              ? selectedCustomer!.name![0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              selectedCustomer!.name ?? 'Unknown',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${selectedCustomer!.totalVisites} visits • ${selectedCustomer!.loyaltyPoints} pts',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.clear, color: Colors.red, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        onPressed: () {
                                          setDialogState(() {
                                            selectedCustomer = null;
                                            nameController.clear();
                                            emailController.clear();
                                            mobileController.clear();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                              // Name Field with inline suggestions
                              CommonTextForm(
                                hintText: 'Name (type to search customers)',
                                controller: nameController,
                                BorderColor: AppColors.primary,
                                HintColor: AppColors.primary,
                                obsecureText: false,
                                onChanged: (value) async {
                                  if (value.isEmpty) {
                                    setDialogState(() {
                                      showNameSuggestions = false;
                                      nameSuggestions = [];
                                    });
                                  } else {
                                    final results = await restaurantCustomerStore.searchCustomers(value);
                                    setDialogState(() {
                                      nameSuggestions = results;
                                      showNameSuggestions = nameSuggestions.isNotEmpty;
                                    });
                                  }
                                },
                              ),

                              // Name suggestions list
                              if (showNameSuggestions && nameSuggestions.isNotEmpty)
                                Container(
                                  constraints: BoxConstraints(maxHeight: 150),
                                  margin: EdgeInsets.only(top: 5, bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: nameSuggestions.length,
                                    itemBuilder: (context, index) {
                                      final customer = nameSuggestions[index];
                                      return InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedCustomer = customer;
                                            nameController.text = customer.name ?? '';
                                            emailController.text = '';
                                            mobileController.text = customer.phone ?? '';
                                            showNameSuggestions = false;
                                            nameSuggestions = [];
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                                child: Text(
                                                  customer.name?.isNotEmpty == true
                                                      ? customer.name![0].toUpperCase()
                                                      : '?',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      customer.name ?? 'Unknown',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${customer.phone ?? ''} • ${customer.totalVisites} visits',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              if (!showNameSuggestions)
                                const SizedBox(height: 10),

                              // Phone Field with inline suggestions
                              CommonTextForm(
                                hintText: 'Mobile No (type to search customers)',
                                controller: mobileController,
                                BorderColor: AppColors.primary,
                                HintColor: AppColors.primary,
                                obsecureText: false,
                                onChanged: (value) async {
                                  if (value.isEmpty) {
                                    setDialogState(() {
                                      showPhoneSuggestions = false;
                                      phoneSuggestions = [];
                                    });
                                  } else {
                                    final results = await restaurantCustomerStore.searchCustomers(value);
                                    setDialogState(() {
                                      phoneSuggestions = results;
                                      showPhoneSuggestions = phoneSuggestions.isNotEmpty;
                                    });
                                  }
                                },
                              ),

                              // Phone suggestions list
                              if (showPhoneSuggestions && phoneSuggestions.isNotEmpty)
                                Container(
                                  constraints: BoxConstraints(maxHeight: 150),
                                  margin: EdgeInsets.only(top: 5, bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: phoneSuggestions.length,
                                    itemBuilder: (context, index) {
                                      final customer = phoneSuggestions[index];
                                      return InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedCustomer = customer;
                                            nameController.text = customer.name ?? '';
                                            emailController.text = '';
                                            mobileController.text = customer.phone ?? '';
                                            showPhoneSuggestions = false;
                                            phoneSuggestions = [];
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                                child: Text(
                                                  customer.name?.isNotEmpty == true
                                                      ? customer.name![0].toUpperCase()
                                                      : '?',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      customer.name ?? 'Unknown',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${customer.phone ?? ''} • ${customer.totalVisites} visits',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              if (!showPhoneSuggestions)
                                const SizedBox(height: 25),
                              CommonTextForm(
                                  hintText: 'Email ID (Optional)',
                                  controller: emailController,
                                  BorderColor: AppColors.primary,
                                  HintColor: AppColors.primary,
                                  obsecureText: false),
                              const SizedBox(height: 10),
                              CommonTextForm(
                                  hintText: 'Remark',
                                  controller: remarkController,
                                  BorderColor: AppColors.primary,
                                  HintColor: AppColors.primary,
                                  obsecureText: false),
                              const SizedBox(height: 25),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('To Be Paid', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calculations.grandTotal)}',
                                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [

                                  // butttons for placing new order
                                  Expanded(
                                    child: CommonButton(
                                      // width: width * 0.3,
                                      height: height * 0.06,
                                      bordercircular: 2,
                                      onTap: ()=> _placeOrder(calculations),
                                      child: Center(
                                        child: Text('Print & Order',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            )),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),

                                  Expanded(
                                    child: CommonButton(
                                      // width: width * 0.3,
                                      height: height * 0.06,
                                      bordercircular: 2,
                                      onTap: ()=> _placeOrder(calculations),
                                      child: Center(
                                        child: Text('Place Order',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            )),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // SizedBox(height: 10,)
                                ],
                              ),
                            ),
                          ),
                          titlePadding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          actions: [],
                        );
                      },
                    );
                  },
                );
              },
              child: Center(
                child: Text(
                  'Place Order',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ),
            ),
            widget.isdelivery
                ? SizedBox()
                : CommonButton(
              bordercircular: 5,
              width: width * 0.40,
              height: height * 0.05,
              onTap: ()=> _qucikSettleNewOrder(calculations),
              child: Center(
                child: Text(
                  'Quick Settlee',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 10,
        ),
        widget.isdelivery
            ? SizedBox()
            : ElevatedButton(
          onPressed: widget.cartItems.isEmpty
              ? null
              : () {
            // _completeOrder();
            Navigator.push(
                context,
                MaterialPageRoute(

                    builder: (context) => Customerdetails(
                      tableid: widget.tableid,
                      cartitems: plainItems,
                      totalPrice: calculations.grandTotal,
                      orderType:  widget.isDineIn ? 'Dine In' : 'Take Away',
                      isSettle: true,
                    )));
            // Handle checkout
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Settle & Print Bill',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

/*
  Future<void> completeOrder(OrderModel activeModel) async {
    print("--- Starting to complete order KOT #${activeModel.kotNumber} ---");

    // ✅ 1. Calculate the GST from the items
    // final gstDetails = _calculateGst(activeModel.items);
    final pastOrder = pastOrderModel(
        id: activeModel.id,
        customerName: activeModel.customerName,
        totalPrice: activeModel.totalPrice,
        items: activeModel.items,
        orderAt: activeModel.timeStamp,
        kotNumber: activeModel.kotNumber,
        orderType: activeModel.orderType,
        paymentmode: 'Cash',
      gstRate: activeModel.gstRate,
      gstAmount: activeModel.gstAmount,
    subTotal: activeModel.subTotal,
      );

    await pastOrderStore.addOrder(pastOrder);
    // print("✅ Order saved to past orders history with GST: ${gstDetails['totalGstAmount']}");


    // 3. IMPORTANT: Now, delete the original order from the ACTIVE orders box
    await clearCart();
    // await HiveOrders.deleteOrder(activeModel.id);
    print("🗑️ Active order has been deleted.");
    print("--- Order completion process finished. ---");
    // await HiveOrders.deleteOrder(c);

    print('Order ${activeModel.id} moved to past');
  }
*/

  // Replace your completeOrder function with this simplified version
  Future<void> completeOrder(OrderModel activeModel) async {
    print("--- Completing order KOT #${activeModel.kotNumber} ---");

    // Generate daily bill number for completed order
    final int billNumber = await orderStore.getNextBillNumber();
    print('✅ Bill number generated: $billNumber');

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
    );

    await pastOrderStore.addOrder(pastOrder);
    print("✅ Order saved to past orders history with Bill #$billNumber");

    // This is the critical missing step: delete the order from the ACTIVE list.
    await orderStore.deleteOrder(activeModel.id);
    print("🗑️ Active order has been deleted.");
  }

/*
  Future<void>  _qucikSettleNewOrder( double gtotal , CartCalculationService calculations) async {
    final plainItems  = widget.cartItems.map((w)=> w.item).toList();

    final int newKotNumber = await orderStore.getNextKotNumber();
    // Step 1: Calculate the GST amount from the cart items first.
    final gstDetails = _calculateGst(plainItems);
    final double gstAmount = gstDetails['totalGstAmount'] ?? 0;
    final double gstRate = gstDetails['gstRate'] ?? 0;

    final double finalGrandTotal = AppSettings.isTaxInclusive
        ? totalPrice // If tax is included, the subtotal IS the grand total.
        : totalPrice + gstAmount; // If tax is exclusive, add it on top.


    final newOrder = OrderModel(
        id: Uuid().v4(),
        customerName: 'Quick Settle',
        customerNumber: '',
        customerEmail: '',
        items: plainItems,
        status: 'completed',
        timeStamp: DateTime.now(),
        orderType: widget.isDineIn ? 'Dine In' : 'Take Away',
        totalPrice: gtotal,
        kotNumber: newKotNumber,
        subTotal: totalPrice,
        gstAmount: calculations.totalGST,
        gstRate: 0,
    );

    await completeOrder(newOrder);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Startorder()),
        (Route<dynamic> route) => false,
      );
      NotificationService.instance.showSuccess('Quick Settle Successful');
    }
  }

*/

// Replace your entire _qucikSettleNewOrder function with this one.
  Future<void> _qucikSettleNewOrder(CartCalculationService calculations) async {
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
    print('✅ Bill number generated for quick settle: $billNumber');

    final pastOrder = PastOrderModel(
      id: Uuid().v4(), // Generate a unique ID for this transaction
      customerName: 'Quick Settle',
      totalPrice: calculations.grandTotal, // ✅ Use the final grand total from the service
      items: plainItems,
      orderAt: DateTime.now(),
      orderType: widget.isDineIn ? 'Dine In' : 'Take Away',
      paymentmode: 'Cash', // Default for quick settle

      // ✅ Use the CORRECT values from the calculation service
      subTotal: AppSettings.isTaxInclusive
          ? calculations.subtotal - calculations.totalGST
          : calculations.subtotal,
      gstAmount: calculations.totalGST,
      gstRate: 0, // You can enhance your service to calculate and provide this if needed

      // ✅ KOT tracking - REQUIRED
      kotNumbers: [quickSettleKotNumber],
      kotBoundaries: [plainItems.length], // Single KOT with all items
      billNumber: billNumber, // Daily bill number (resets every day)
    );

    // 1. Add the completed order to history
    await pastOrderStore.addOrder(pastOrder);

    // 2. Deduct stock after successfully adding the order
    await InventoryService.deductStockForOrder(plainItems);
    print("✅ Stock deducted for quick settle order");

    // 3. Clear the user's cart
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


// Add this helper method inside your _TakeawayState class
// Place this method inside your _CustomerdetailsState class
//   Map<String, double> _calculateGst(List<CartItem> items) {
//     double totalGstAmount = 0;
//     double gstRate = 0;
//
//     for (final cartItem in items) {
//       // Get the tax rate that was locked into the cart item (e.g., 0.18)
//       final itemTaxRateDecimal = cartItem.taxRate ?? 0;
//
//       if (itemTaxRateDecimal > 0) {
//         // Get the total final price for this line item (e.g., 2 pizzas * 150 = 300)
//         final lineItemFinalPrice = cartItem.totalPrice;
//
//         // This is the core formula to find the tax included in the price
//         final lineItemBasePrice = lineItemFinalPrice / (1 + itemTaxRateDecimal);
//         final lineItemTaxAmount = lineItemFinalPrice - lineItemBasePrice;
//
//         // Add the tax from this line item to the grand total
//         totalGstAmount += lineItemTaxAmount;
//
//         // Store the rate for display purposes (e.g., 18%)
//         if (gstRate == 0) {
//           gstRate = itemTaxRateDecimal * 100;
//         }
//       }
//     }
//
//     return {
//       'totalGstAmount': totalGstAmount,
//       'gstRate': gstRate,
//     };
//   }


}
