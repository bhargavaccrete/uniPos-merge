import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_Table.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_order.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/OrderCard.dart';
import '../start order/cart/cart.dart';


class Activeorder extends StatefulWidget {
  const Activeorder({super.key});

  @override
  State<Activeorder> createState() => _ActiveorderState();
}

class _ActiveorderState extends State<Activeorder> {
  String dropDownValue = 'All';

  List<String> dropdownItems = [
    'All',
    'Take Away', // Note: Make sure this matches the string in your OrderModel exactly
    'Delivery',
    'Dine In',
  ];

  Future<void> _deleteOrder(String orderId) async {
    // Show a confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Order'),
        content: Text('Are you sure you want to delete this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Only delete if the user confirmed
    if (shouldDelete == true) {
      await HiveOrders.deleteOrder(orderId);
      // setState(() {
      //   // Refresh the FutureBuilder by getting the updated list of orders
      //   // _ordersFuture = HiveOrders.getAllOrder();
      // });
    }
  }



  // In _ActiveorderState class
  Color _getColorForStatus(String? status) {
    switch (status) {
      case 'Cooking':
        return Colors.red.shade500; // Red for Cooking
      case 'Ready':
        return Colors.orange.shade300; // Orange for Ready
      default:
        return Colors.white; // Default color
    }
  }

  // In _ActiveorderState class

// This function shows the main dialog
  void _showStatusUpdateDialog(OrderModel order, bool istakeaway,) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text('Update Status #${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id.substring(0, 8)}'),

              InkWell(
                  onTap: (){
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.cancel))
            ],
          ),
          content: Text('What is the status of this order?'),
          actions: <Widget>[
            // Button 1: Ready to Pickup
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                order.status == 'Ready'
                    ? SizedBox()
                    : CommonButton(
                  bgcolor: Colors.white,
                  width: 300,
                  height: 50,
                  child: Text(istakeaway?'Ready to Pickup':'Ready to Served',style:GoogleFonts.poppins(color: Colors.black)),
                  onTap: () {
                    Navigator.of(context).pop(); // Close the dialog
                    _updateOrderStatus(order, 'Ready');
                  },
                ),
                SizedBox(height: 10,),
                // Button 2: Picked Up
                CommonButton(
                  bgcolor: Colors.white,
                  width: 300,
                  height: 50,
                  child: Text(istakeaway?'Picked Up':'Served',style:GoogleFonts.poppins(color: Colors.black)),
                  onTap: () {
                    Navigator.of(context).pop(); // Close the dialog

                    if(order.paymentStatus == 'Paid'){
                      _moveOrderToPast(order);
                    }
                    _updateOrderStatus(order, 'Ready');
                  },
                ),
              ],
            )
          ],
        );
      },
    );
  }

// ACTION 1: Updates the status and changes the color
  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    // Create an updated version of the order
    final updatedOrder = order.copyWith(status: newStatus);
    // Save the change to the Hive database
    await HiveOrders.updateOrder(updatedOrder);
    // Refresh the screen to show the new color
    // _refreshOrders();
    print("Order ${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id} status updated to $newStatus.");
  }

// ACTION 2: Moves the order to the past orders box
  Future<void> _moveOrderToPast(OrderModel order) async {
    // NOTE: This assumes you have a `pastOrderModel` and `HivePastOrder` setup.
    // Create a past order record from the active order
    final pastOrder = pastOrderModel(
      id: order.id,
      customerName: order.customerName,
      totalPrice: order.totalPrice,
      items: order.items,
      orderAt: order.timeStamp,
      orderType: order.orderType,
      paymentmode: order.paymentMethod ?? 'N/A',
      subTotal: order.subTotal,
      gstAmount: order.gstAmount,
      Discount: order.discount,
      remark: order.remark,
      // ✅ KOT tracking - REQUIRED
      kotNumbers: order.kotNumbers,
      kotBoundaries: order.kotBoundaries, // KOT boundaries for grouping items
      // ... copy other relevant fields
    );

    // Add to past orders and delete from active orders
    await HivePastOrder.addOrder(pastOrder);
    await HiveOrders.deleteOrder(order.id);
    await HiveTables.updateTableStatus(order.tableNo!, 'Available');

    // Refresh the screen to remove the card
    // _refreshOrders();
    print("Order ${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id} moved to past orders.");
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: The main layout is now a Column
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // This Row stays at the top
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Type',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                DropdownButton<String>(
                  value: dropDownValue,
                  items: dropdownItems.map((String item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      dropDownValue = newValue!;
                    });
                  },
                )
              ],
            ),
            SizedBox(height: 10), // Add some spacing

            // FIX: This Expanded now has a fixed space to fill
            Expanded(
                child:  ValueListenableBuilder(
                  valueListenable: Hive.box<OrderModel>('orderBox').listenable(),
                  builder: (context, orders ,_){

                    final allOrders = orders.values.toList();

                    allOrders.sort((a,b)=> b.timeStamp.compareTo(a.timeStamp));


                    if(allOrders.isEmpty){
                      return Center(
                        child: Text(
                          'No Active Orders',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 28,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      );
                    }

                    final filterOrderList = dropDownValue == 'All'
                        ? allOrders
                        : allOrders.where((order)=> order.orderType == dropDownValue)
                        .toList();

                    if(filterOrderList.isEmpty){
                      return Center(child: Text('No Order of Type "$dropDownValue" found.'));
                    }

                    return ListView.builder(
                      itemCount: filterOrderList.length,
                      itemBuilder: (context, index) {
                        final order = filterOrderList[index];
                        return OrderCard(
                          color: _getColorForStatus(order.status),

                          order: order,
                          onDelete: _deleteOrder,
                          ontapcooking: () async {
                            if (order.status == 'Cooking' || order.status == 'Ready') {
                              _showStatusUpdateDialog(order,order.orderType == 'Take Away'? true : false);
                            }
                          },

                          ontap: () async { // Make the function async
                            // If status is 'Cooking', show the update dialog

                            // If not paid, navigate to the cart to complete payment
                            if (order.isPaid != true) {
                              print('Card with Kot ${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id}');

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CartScreen(
                                    existingOrder: order,
                                    selectedTableNo: order.tableNo,
                                  ),
                                ),
                              );
                              // _refreshOrders();
                            }
                            // Handle other statuses if needed
                            else {
                              print("Order is in status: ${order.status}");
                            }
                          },
                        );
                      },
                    );
                  },
                )



            ),
          ],
        ),
      ),
    );
  }
}


// Future Builder
/*  FutureBuilder<List<OrderModel>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No Active Orders',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 28,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    );
                  }

                  final allOrders = snapshot.data!;

                  allOrders.sort((a,b)=> b.timeStamp.compareTo(a.timeStamp!));

                  // Filter the orders based on the dropdown value
                  // final filteredOrders = dropDownValue == 'All'
                  //     ? allOrders
                  //     : allOrders
                  //     .where((order) => order.orderType == dropDownValue)
                  //     .toList();
                  //
                  // if (filteredOrders.isEmpty) {
                  //   return Center(child: Text('No orders of type "$dropDownValue" found.'));
                  // }




                  // The ListView provides its own scrolling
                  // Inside your build method's FutureBuilder

                },
              ),*/