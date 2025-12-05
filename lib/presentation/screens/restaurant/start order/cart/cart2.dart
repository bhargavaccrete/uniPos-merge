// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/filterButton.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/database/hive_cart.dart';
// import 'package:BillBerry/database/hive_order.dart';
// import 'package:BillBerry/model/db/cartmodel_8.dart';
// import 'package:BillBerry/screens/start%20order/cart/takeaway.dart';
// import 'package:BillBerry/screens/start%20order/startorder.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:hive/hive.dart';
// import '../../../model/db/ordermodel_9.dart';
// import '../../tabbar/table.dart';
//
// class CartScreen extends StatefulWidget {
//   // final List<CartItem> cartItems;
//   final OrderModel? existingOrder;
//   String? selectedTableNo;
//   final bool? isShowButtons;
//   final String? tableid;
//   final bool? isActiveCart;
//
//   CartScreen({super.key,
//     // required this.cartItems,
//     this.tableid,
//     this.selectedTableNo,
//     this.existingOrder,
//     this.isShowButtons= false,
//     this.isActiveCart = true,
//   });
//
//   @override
//   State<CartScreen> createState() => _CartScreenState();
// }
//
// class _CartScreenState extends State<CartScreen>
//     with SingleTickerProviderStateMixin {
//   // late List<CartItem> cartItems = [ ];
//   String selectedFilter = "Take Away";
//   bool isExistingOrder = false;
//
//
//   // In _CartScreenState
//   List<CartItem> _activeOrderItems = []; // For items already saved to the order
//   List<CartItem> _newlyAddedItems = [];    // For items you are adding now
//
//
//   List <CartItem> get _combinedCartItems => [..._activeOrderItems,..._newlyAddedItems];
//
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeCart();
//
//   }
//
//
//   String? tableNo;
//   Future<void> _initializeCart() async {
//     // --- Step 1: Determine the source of truth with clear priority ---
//
//     // Priority 1: An existing order was passed directly to the widget.
//     // This is the most reliable source.
//     if (widget.existingOrder != null) {
//       if (mounted) {
//         setState(() {
//           // Use the items directly from the passed order object.
//           _activeOrderItems = List.from(widget.existingOrder!.items);
//           // cartItems = List.from(widget.existingOrder!.items);
//           isExistingOrder = true;
//           selectedFilter = widget.existingOrder!.orderType; // Existing orders are always Dine In
//           tableNo = widget.existingOrder!.tableNo;
//         });
//         loadCartItems();
//       }
//       return; // Stop here, as we have what we need.
//     }
//
//     // Priority 2: Check for a persisted state (e.g., from app resume).
//     // This is less reliable and should only be a fallback.
//     final appBox = Hive.box('app_state');
//     final bool isPersistedExistingOrder = appBox.get('is_existing_order', defaultValue: false);
//
//     if (isPersistedExistingOrder) {
//       final String? persistedTableId = appBox.get('existing_order_table');
//       if (persistedTableId != null) {
//         final existingOrder = await HiveOrders.getActiveOrderByTableId(persistedTableId);
//         if (existingOrder != null && mounted) {
//           setState(() {
//             // cartItems = existingOrder.items;
//             isExistingOrder = true;
//             selectedFilter = 'Dine In';
//             tableNo = existingOrder.tableNo;
//           });
//           return; // Stop here.
//         }
//       }
//     }
//
//     // Priority 3: If all else fails, it's a new order.
//     // Load from the general cart and check if a table was pre-selected.
//     final newCartItems = await HiveCart.getAllCartItems();
//     if (mounted) {
//       setState(() {
//         _newlyAddedItems = newCartItems;
//         // cartItems = newCartItems;
//         isExistingOrder = false;
//         tableNo = widget.selectedTableNo; // For a new order at a specific table
//         // If a table was selected for a new order, default the view to Dine In.
//         if (tableNo != null) {
//           selectedFilter = 'Dine In';
//         }
//       });
//     }
//   }
//
//
//   // Future<void> _InitializeCart() async {
//   //   final appBox = Hive.box('app_state');
//   //
//   //   isExistingOrder =appBox.get('is_existing_order', defaultValue: false);
//   //   // If order was passed directly (hot start), use it
//   //   if (widget.existingOrder != null) {
//   //    setState(() {
//   //      cartItems = List.from(widget.existingOrder!.items);
//   //      selectedFilter = 'Dine In';
//   //      isExistingOrder = true;
//   //    });
//   //   }else if(isExistingOrder){
//   //     final tableId = appBox.get('existing_order_table');
//   //     if(tableId!= null){
//   //       final existinOrder = await HiveOrders.getActiveOrderByTableId(tableId);
//   //       if(existinOrder != null){
//   //         setState(() {
//   //           cartItems = existinOrder.items;
//   //           selectedFilter = 'Dine In';
//   //           widget.selectedTableNo = existinOrder.tableNo ?? '';
//   //         });
//   //         return ;
//   //       }
//   //     }
//   //   }
//   //   if(!isExistingOrder){
//   //   await loadCartItems();
//   //   }
//   // }
//
//   //   initialize func for load defualt cart
//   //
//   //   // Otherwise, try to restore from saved state
//   //   final isExisting = appBox.get('is_existing_order', defaultValue: false);
//   //   final tableId = appBox.get('existing_order_table');
//   //
//   //   if (isExisting == true && tableId != null) {
//   //     // Try to load the existing order from Hive/DB
//   //     final existingOrder = await HiveOrders.getActiveOrderByTableId(tableId);
//   //     if (existingOrder != null) {
//   //       setState(() {
//   //         cartItems = existingOrder.items;
//   //         selectedFilter = 'Dine In';
//   //         widget.selectedTableNo = existingOrder.tableNo;
//   //       });
//   //       return;
//   //     }
//   //   }
//   //
//   //   // Otherwise, load cart normally (Takeaway or Delivery)
//   //   await loadCartItems();
//   // }
//
//
//
//   void _navigateAndAddMoreItems() async {
//     // Navigate to your menu to let the user add items
//     await Navigator.push(context, MaterialPageRoute(builder: (context) => Startorder(isForAddingItem: true,)));
//
//     // When they return, reload the new items from the main cart
//
//     _initializeCart();
//   }
//
//
//
//   Future<void> loadCartItems() async {
//     try {
//       final items = await HiveCart.getAllCartItems();
//       if (mounted) {
//         setState(() {
//           _newlyAddedItems  = items;
//           // cartItems = items;
//         });
//       }
//     } catch (e) {
//       print('Error loading cart items: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error loading cart items'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> clearCart() async {
//     try {
//       await HiveCart.clearCart();
//       await loadCartItems();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Cart cleared'),
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error clearing cart: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error clearing cart'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//
//   Widget dineintable(){
//     // bool? isexisting = widget.existingOrder != null ? true : false;
//     Navigator.push(context, MaterialPageRoute(builder: (context)=> TableScreen())) ;
//     return   Takeaway(
//       existingModel: widget.existingOrder,
//       tableid: widget.tableid ?? '',
//       isexisting: isExistingOrder,
//       isDineIn: true,
//       isdelivery: false,
//       cartItems: _newlyAddedItems,
//       onAddtoCart: (item) async {
//         await HiveCart.addToCart(item);
//         await loadCartItems();
//       },
//       onIncreseQty: (item) async {
//         await HiveCart.updateQuantity(item.id, item.quantity + 1);
//         await loadCartItems();
//       },
//       onDecreseQty: (item) async {
//         if (item.quantity > 1) {
//           await HiveCart.updateQuantity(item.id, item.quantity - 1);
//         } else {
//           await HiveCart.removeFromCart(item.id);
//         }
//         await loadCartItems();
//       },
//     );
//
//   }
//   // String selectedFilterr = "Take Away";
//
//
//
//
//   Widget _getBody() {
//     // bool? isexisting = widget.existingOrder != null ? true : false;
//     switch(selectedFilter) {
//       case"Take Away":
//         return Takeaway(
//           existingModel: widget.existingOrder,
//           tableid: widget.tableid ?? '',
//           isexisting: isExistingOrder,
//           isDineIn: false,
//           isdelivery: selectedFilter == "Delivery",
//           cartItems: _combinedCartItems,
//           onAddtoCart: (item) async {
//             await HiveCart.addToCart(item);
//             await loadCartItems();
//           },
//           onIncreseQty: (item) async {
//             await HiveCart.updateQuantity(item.id, item.quantity + 1);
//             await loadCartItems();
//           },
//           onDecreseQty: (item) async {
//             if (item.quantity > 1) {
//               await HiveCart.updateQuantity(item.id, item.quantity - 1);
//             } else {
//               await HiveCart.removeFromCart(item.id);
//             }
//             await loadCartItems();
//           },
//         );
//       case "Dine In":
//         return Takeaway(
//           existingModel: widget.existingOrder,
//
//           tableid: widget.tableid ?? '',
//           isexisting: isExistingOrder,
//           selectedTableNo: widget.selectedTableNo?? '',
//           isDineIn: true,
//           isdelivery: false,
//           cartItems: _combinedCartItems,
//           onAddtoCart: (item) async {
//             await HiveCart.addToCart(item);
//             await loadCartItems();
//           },
//           onIncreseQty: (item) async {
//             await HiveCart.updateQuantity(item.id, item.quantity + 1);
//             await loadCartItems();
//           },
//           onDecreseQty: (item) async {
//             if (item.quantity > 1) {
//               await HiveCart.updateQuantity(item.id, item.quantity - 1);
//             } else {
//               await HiveCart.removeFromCart(item.id);
//             }
//             await loadCartItems();
//           },
//         );
//       case "Delivery":
//         return Takeaway(
//           existingModel: widget.existingOrder,
//
//           tableid: widget.tableid ?? '',
//           isexisting:isExistingOrder,
//           isDineIn: false,
//           isdelivery: true,
//           cartItems: _combinedCartItems,
//           onAddtoCart: (item) async {
//             await HiveCart.addToCart(item);
//             await loadCartItems();
//           },
//           onIncreseQty: (item) async {
//             await HiveCart.updateQuantity(item.id, item.quantity + 1);
//             await loadCartItems();
//           },
//           onDecreseQty: (item) async {
//             if (item.quantity > 1) {
//               await HiveCart.updateQuantity(item.id, item.quantity - 1);
//             } else {
//               await HiveCart.removeFromCart(item.id);
//             }
//             await loadCartItems();
//           },
//         );
//
//
//       default:
//         return Center(
//           child: Text('NO DATA AVAILABE'),
//         );
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: primarycolor,
//         title: Text(
//           isExistingOrder ? 'Update Order' : 'Cart',
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontSize: 20,
//           ),
//         ),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.delete_outline, color: Colors.white),
//             onPressed: () {
//               showDialog(
//                 context: context,
//                 builder: (context) => AlertDialog(
//                   title: Text('Clear Cart'),
//                   content: Text('Are you sure you want to clear the cart?'),
//                   actions: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: Text('Cancel'),
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         Navigator.pop(context);
//                         clearCart();
//                       },
//                       child: Text('Clear'),
//                       style: TextButton.styleFrom(foregroundColor: Colors.red),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//
//       // ADD THIS BUTTON
//       floatingActionButton: isExistingOrder
//           ? FloatingActionButton.extended(
//         onPressed: _navigateAndAddMoreItems, // Call your function
//         label: Text("Add More Items"),
//         icon: Icon(Icons.add),
//         backgroundColor: primarycolor,
//       )
//           : null, // Button will be hidden for new orders
//
//       body: _combinedCartItems.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.shopping_cart_outlined,
//                 size: 64, color: Colors.grey),
//             SizedBox(height: 16),
//             Text(
//               'Your cart is empty',
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 color: Colors.grey,
//               ),
//             ),
//           ],
//         ),
//       )
//           : Column(
//         children: [
//           // if(isExistingOrder && widget.selectedTableNo!= null)
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//
//
//
//                 // if (!isExistingOrder)
//                 Filterbutton(
//                   title: 'Take Away',
//                   selectedFilter: selectedFilter,
//                   onpressed: () {
//                     setState(() {
//                       selectedFilter = "Take Away";
//                     });
//                   },
//                 ),
//                 Filterbutton(
//                   title: 'Dine In',
//                   selectedFilter: selectedFilter,
//                   onpressed: () async{
//                     final result = await Navigator.push(context, MaterialPageRoute(builder: (context)=> TableScreen()));
//
//                     if(result != null && result is String){
//                       setState(() {
//                         selectedFilter = "Dine In";
//                         widget.selectedTableNo = result ?? ' ';
//                       });
//                     }
//
//
//                     // setState(() {
//                     //   selectedFilter = "Delivery";
//                     // });
//                   },
//                 ),
//
//                 Filterbutton(
//                   title: 'Delivery',
//                   selectedFilter: selectedFilter,
//                   onpressed: () {
//                     setState(() {
//                       selectedFilter = "Delivery";
//                     });
//                   },
//                 ),
//               ],
//             ),
//           ),
//           Expanded(child: _getBody()),
//         ],
//       ),
//     );
//   }
// }