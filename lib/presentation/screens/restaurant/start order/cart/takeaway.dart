import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_Table.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_cart.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:uuid/uuid.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/database/hive_order.dart' show HiveOrders;
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../../domain/services/restaurant/cart_calculation_service.dart';
import '../../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/staticswitch.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';
import '../../tabbar/table.dart';
import '../startorder.dart';
import 'customerdetails.dart';
import '../../util/restaurant_print_helper.dart';

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
    print(item.title);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Container(
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(

        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The updated code
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Always show the item name
                      Text(
                        item.title,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                      ),

                      // Conditionally show the weight display string if it's not null
                      if (item.weightDisplay != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            item.weightDisplay!, // e.g., "1.000 KG"
                            style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      color: primarycolor,
                      onPressed: () => widget.onDecreseQty(item),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        // color: wrapped.isActive ? Colors.green : Colors.blue,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.quantity.toString(),
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      color: primarycolor,
                      onPressed: () => widget.onIncreseQty(item),
                    ),
                  ],
                ),
                Expanded(
                  child: Text(
                    'Rs ${item.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),

            if (item.variantName != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Size: ${item.variantName} (Rs.${item.variantPrice?.toStringAsFixed(2)})',
                ),
              ),

            // Add a small space between the boxes

            // 3. (NEW) Display Choices in a similar styled box
            if (item.choiceNames != null && item.choiceNames!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 5),
                // Added margin for spacing
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Add-ons: ${item.choiceNames!.join(', ')}', // This is now safe
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
                ),
              ),

            // const SizedBox(height: 8),

            if (item.extras != null && item.extras!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                    'extra : ${item.extras!.map((extra){
                      // Debug: Print what data we have
                      print('=== EXTRA DEBUG ===');
                      print('Extra keys: ${extra.keys}');
                      print('name: ${extra['name']}');
                      print('displayName: ${extra['displayName']}');
                      print('categoryName: ${extra['categoryName']}');

                      // Try multiple ways to get the display name
                      String displayName;
                      if (extra['displayName'] != null && extra['displayName'].toString().isNotEmpty) {
                        displayName = extra['displayName'];
                      } else if (extra['categoryName'] != null && extra['categoryName'].toString().isNotEmpty) {
                        displayName = '${extra['categoryName']} - ${extra['name']}';
                      } else {
                        displayName = extra['name'];
                      }

                      final double price = extra['price']?.toDouble() ?? 0.0;
                      print('Final displayName: $displayName');
                      print('===================');

                      return '$displayName(Rs. ${price.toStringAsFixed(2)})';
                    }).join(', ')}'
                ),
              ),

            const SizedBox(height: 8),

          ],
        ),
      ),
    );
  }

  Future<void> clearCart() async {
    try {
      await HiveCart.clearCart();
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

  TextEditingController nameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController remarkController = TextEditingController();

/*
  Future<void> _placeOrder() async {
    final plainItems  = widget.cartItems.map((w)=> w.item).toList();
    final gstDetails = _calculateGst(plainItems);
    final int newKotNumber = await HiveOrders.getNextKotNumber();
    final neworder = OrderModel(
      id: Uuid().v4(),
      customerName: nameController.text,
      customerNumber: mobileController.text,
      customerEmail: emailController.text,
      items: plainItems,
      status: 'Cooking',
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

    await HiveOrders.addOrder(neworder);
    print("✅ New active order saved with GST: ${gstDetails['totalGstAmount']}");

    if (widget.isDineIn && widget.selectedTableNo != null) {
      await HiveTables.updateTableStatus(widget.selectedTableNo!, 'Reserved', total: totalPrice);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order Placed SuccessFuly')));
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

    final int newKotNumber = await HiveOrders.getNextKotNumber();

    final neworder = OrderModel(
      id: Uuid().v4(),
      customerName: nameController.text.trim(),
      customerNumber: mobileController.text.trim(),
      customerEmail: emailController.text.trim(),
      items: plainItems,
      status: 'Cooking',
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
    );

    await HiveOrders.addOrder(neworder);
    print("✅ New active order saved with Total: ${neworder.totalPrice}");

    // Deduct stock after successfully adding the order
    await InventoryService.deductStockForOrder(plainItems);
    print("✅ Stock deducted for order items");
    print("✅ Selected Table id is ${widget.selectedTableNo.toString()}");

    // print("")
    if (widget.isDineIn && widget.selectedTableNo != null) {
      // Also use the correct total here
      await HiveTables.updateTableStatus(
        widget.selectedTableNo!,
        'Running',
        total: neworder.totalPrice,
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

      if (hasNewItems) {
        // Generate a new KOT for the newly added items
        newKotNumber = await HiveOrders.getNextKotNumber();
        updatedKotNumbers.add(newKotNumber);
        updatedKotBoundaries.add(newItemCount); // Add boundary at new item count

        print('====== NEW KOT GENERATED ======');
        print('Previous item count: $previousItemCount');
        print('New item count: $newItemCount');
        print('New KOT Number: $newKotNumber');
        print('All KOT Numbers: $updatedKotNumbers');
        print('KOT Boundaries: $updatedKotBoundaries');
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
      );

      await HiveOrders.updateOrder(updateOrder);

      // Update the table's total price as well
      if (updateOrder.tableNo != null) {
        await HiveTables.updateTableStatus(updateOrder.tableNo!, 'Reserved', total: calculations.grandTotal);
      }

      if (mounted) {
        // Pop with 'true' to let the previous screen know the update was successful.
        Navigator.of(context).pop(true);

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
        // Header
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade100,
          // item , quantity , price
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Quantity',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Price',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: primarycolor)),
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
                    'Rs ${calculations.grandTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primarycolor,
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Customerdetails(
                          tableid: widget.tableid,
                          existingModel: widget.existingModel,
                          totalPrice: calculations.grandTotal,
                        )));
              },
              child: Center(
                child: Text(
                  'Settlee \n (Rs. ${calculations.grandTotal.toStringAsFixed(2)})',
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
            backgroundColor: primarycolor,
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
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
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
                      content: SingleChildScrollView(
                        child: Container(
                          width: width,
                          height: height * 0.6,
                          child: Column(
                            children: [
                              Text('Customer Details',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.start),
                              const SizedBox(height: 10),
                              CommonTextForm(
                                  hintText: 'Name',
                                  controller: nameController,
                                  BorderColor: primarycolor,
                                  HintColor: primarycolor,
                                  obsecureText: false),
                              const SizedBox(height: 10),
                              CommonTextForm(
                                  hintText: 'Mobile No',
                                  controller: mobileController,
                                  BorderColor: primarycolor,
                                  HintColor: primarycolor,
                                  obsecureText: false),
                              const SizedBox(height: 25),
                              CommonTextForm(
                                  hintText: 'Email ID (Optional)',
                                  controller: emailController,
                                  BorderColor: primarycolor,
                                  HintColor: primarycolor,
                                  obsecureText: false),
                              const SizedBox(height: 10),
                              CommonTextForm(
                                  hintText: 'Remark',
                                  controller: remarkController,
                                  BorderColor: primarycolor,
                                  HintColor: primarycolor,
                                  obsecureText: false),
                              const SizedBox(height: 25),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('To Be Paid', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text('Rs.${calculations.grandTotal.toStringAsFixed(2)}',
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
            backgroundColor: primarycolor,
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

    await HivePastOrder.addOrder(pastOrder);
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

    // Directly convert the active order to a past order.
    // All calculations (GST, subtotal) were already done and saved on the activeModel.
    final pastOrder = pastOrderModel(
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
    );

    await HivePastOrder.addOrder(pastOrder);
    print("✅ Order saved to past orders history.");

    // This is the critical missing step: delete the order from the ACTIVE list.
    await HiveOrders.deleteOrder(activeModel.id);
    print("🗑️ Active order has been deleted.");
  }

/*
  Future<void>  _qucikSettleNewOrder( double gtotal , CartCalculationService calculations) async {
    final plainItems  = widget.cartItems.map((w)=> w.item).toList();

    final int newKotNumber = await HiveOrders.getNextKotNumber();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quick Settle Successful')));
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
    final int quickSettleKotNumber = await HiveOrders.getNextKotNumber();
    final pastOrder = pastOrderModel(
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
    );

    // 1. Add the completed order to history
    await HivePastOrder.addOrder(pastOrder);

    // 2. Deduct stock after successfully adding the order
    await InventoryService.deductStockForOrder(plainItems);
    print("✅ Stock deducted for quick settle order");

    // 3. Clear the user's cart
    await HiveCart.clearCart();

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
