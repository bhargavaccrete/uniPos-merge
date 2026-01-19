// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/Button.dart';
// import 'package:BillBerry/componets/Textform.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/main.dart';
// import 'package:BillBerry/model/cartitem.dart';
// import 'package:BillBerry/store/appStore.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class Takeaway extends StatefulWidget {
//   final  bool isdelivery;
//   final List<cartItem> cartItems;
//   final Function(cartItem) onAddtoCart;
//   final Function(int) onIncreseQty;
//   final Function(int) onDecreseQty;
//
//   const Takeaway({
//     super.key,
//     required this.isdelivery,
//     required this.cartItems,
//     required this.onAddtoCart,
//     required this.onIncreseQty,
//     required this.onDecreseQty,
//   });
//
//   @override
//   State<Takeaway> createState() => _TakeawayState();
// }
//
//
// class _TakeawayState extends State<Takeaway> {
//   @override
//
//   Widget build(BuildContext context) {
//
//     debugPrint('Device Category: ${appStore.deviceCategory}');
//     final height = MediaQuery.of(context).size.height;
//     final width = MediaQuery.of(context).size.width;
//
//     double total = widget.cartItems.fold(
//         0.0, (sum, item) => sum + item.price * item.quantity);
//
//     Widget buildCartItemRow(cartItem item, int index) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 5.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(item.title,style: GoogleFonts.poppins(fontSize: 14),textScaler: TextScaler.linear(1),),
//             Row(
//               children: [
//                 GestureDetector(
//                   onTap: () => widget.onDecreseQty(index),
//                   child: Icon(Icons.remove, color: AppColors.primary),
//                 ),
//                 SizedBox(width: 5),
//                 Container(
//                   alignment: Alignment.center,
//                   width: width * 0.07,
//                   height: height * 0.04,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Text(
//                     item.quantity.toString(),
//                     textScaler: TextScaler.linear(1),
//                     style: GoogleFonts.poppins(fontSize: 14),
//                   ),
//                 ),
//                 SizedBox(width: 5),
//                 GestureDetector(
//                   onTap: () => widget.onIncreseQty(index),
//                   child: Icon(Icons.add, color: AppColors.primary),
//                 ),
//               ],
//             ),
//             Text(
//               (item.price * item.quantity).toStringAsFixed(2),
//               textScaler: TextScaler.linear(1),
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return Scaffold(
//       body: SingleChildScrollView(
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//           child: Column(
//             children: [
//               // Header
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 color: Colors.teal.shade100,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: const [
//                     Text('Items',
//                         textScaler: TextScaler.linear(1),
//
//                         style: TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.w500)),
//                     Text('Qty',
//                         textScaler: TextScaler.linear(1),
//
//                         style: TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.w500)),
//                     Text('Amount',
//                         textScaler: TextScaler.linear(1),
//
//                         style: TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.w500)),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               // New Order label
//               Container(
//                 alignment: Alignment.center,
//                 width: width * 0.3,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(width: 2, color: AppColors.primary),
//                   borderRadius: BorderRadius.circular(5),
//                 ),
//                 child:  Text(
//                   'New Order',
//                   style: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 14),
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               // Cart Items List
//               Container(
//                 alignment: Alignment.topCenter,
//                 height: height * 0.4,
//                 child: Column(
//                   children: widget.cartItems
//                       .asMap()
//                       .entries
//                       .map((entry) =>
//                       buildCartItemRow(entry.value, entry.key))
//                       .toList(),
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               CommonButton(
//                 width: width * 0.3,
//                 height: height * 0.05,
//                 onTap: () => Navigator.pop(context),
//                 child: Center(
//                   child: Text(
//                     'Add Item',
//                     textScaler: TextScaler.linear(1),
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w500,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               // Bottom Total and Actions
//               Container(
//                 width: width,
//                 color: Colors.indigo.shade50,
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   children: [
//                     // Total
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text('Total:',
//                             textScaler: TextScaler.linear(1),
//
//                             style: GoogleFonts.poppins(
//                                 fontSize: 18, fontWeight: FontWeight.bold)),
//                         Text('Rs.${total.toStringAsFixed(2)}',
//                             textScaler: TextScaler.linear(1),
//
//                             style: GoogleFonts.poppins(
//                                 fontSize: 18, fontWeight: FontWeight.bold)),
//                       ],
//                     ),
//
//                     const SizedBox(height: 25),
//
//                     // Place Order & Quick Settle
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         CommonButton(
//                           bordercircular: 5,
//                           width:  widget.isdelivery?width * 0.8: width * 0.40,
//                           height: height * 0.05,
//                           onTap: () {
//                             showDialog(
//                               context: context,
//                               builder: (BuildContext context) {
//                                 return AlertDialog(
//                                   title: Text(
//                                     'Place Order',
//                                     textScaler: TextScaler.linear(1),
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   titlePadding: const EdgeInsets.all(20),
//                                   alignment: Alignment.center,
//                                   actions: [
//                                     Container(
//                                       width: width * 0.9,
//                                       height: height * 0.5,
//                                       child: Column(
//                                         children: [
//                                           Text('Customer Details',
//                                               style: GoogleFonts.poppins(
//                                                   fontSize: 18,
//                                                   fontWeight: FontWeight.w500),
//                                               textAlign: TextAlign.start),
//                                           const SizedBox(height: 10),
//                                           CommonTextForm(
//                                               hintText: 'Name',
//                                               BorderColor: AppColors.primary,
//                                               HintColor: AppColors.primary,
//                                               obsecureText: false),
//                                           const SizedBox(height: 10),
//                                           CommonTextForm(
//                                               hintText: 'Mobile No',
//                                               BorderColor: AppColors.primary,
//                                               HintColor: AppColors.primary,
//                                               obsecureText: false),
//                                           const SizedBox(height: 25),
//                                           CommonTextForm(
//                                               hintText: 'Email ID (Optional)',
//                                               BorderColor: AppColors.primary,
//                                               HintColor: AppColors.primary,
//                                               obsecureText: false),
//                                           const SizedBox(height: 10),
//                                           CommonTextForm(
//                                               hintText: 'Remark',
//                                               BorderColor: AppColors.primary,
//                                               HintColor: AppColors.primary,
//                                               obsecureText: false),
//                                           const SizedBox(height: 25),
//                                           const Divider(),
//                                           Row(
//                                             mainAxisAlignment:
//                                             MainAxisAlignment
//                                                 .spaceBetween,
//                                             children: [
//                                               Text('To Be Paid',
//                                                   style: GoogleFonts.poppins(
//                                                       fontSize: 20,
//                                                       fontWeight:
//                                                       FontWeight.bold)),
//                                               Text('Rs.${total.toStringAsFixed(2)}',
//                                                   style: GoogleFonts.poppins(
//                                                       fontSize: 20,
//                                                       fontWeight:
//                                                       FontWeight.bold)),
//                                             ],
//                                           ),
//                                           const Divider(),
//                                           Row(
//                                             mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                             children: [
//                                               CommonButton(
//                                                 width: width * 0.3,
//                                                 height: height * 0.06,
//                                                 bordercircular: 2,
//                                                 onTap: () {},
//                                                 child: Center(
//                                                   child: Text('Print & Order',
//                                                       style:
//                                                       GoogleFonts.poppins(
//                                                         color: Colors.white,
//                                                         fontWeight:
//                                                         FontWeight.w500,
//                                                         fontSize: 18,
//                                                       )),
//                                                 ),
//                                               ),
//                                               CommonButton(
//                                                 width: width * 0.3,
//                                                 height: height * 0.05,
//                                                 bordercircular: 2,
//                                                 onTap: () {},
//                                                 child: Center(
//                                                   child: Text('Place Order',
//                                                       style:
//                                                       GoogleFonts.poppins(
//                                                         color: Colors.white,
//                                                         fontWeight:
//                                                         FontWeight.w500,
//                                                         fontSize: 18,
//                                                       )),
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ],
//                                       ),
//                                     )
//                                   ],
//                                 );
//                               },
//                             );
//                           },
//                           child: Center(
//                             child: Text(
//                               'Place Order',
//                               textScaler: TextScaler.linear(1),
//                               style: GoogleFonts.poppins(color: Colors.white,
//                                   fontWeight: FontWeight.w500,
//                                   fontSize: 16),
//                             ),
//                           ),
//                         ),
//                         widget.isdelivery?
//                         SizedBox():
//                         CommonButton(
//                           bordercircular: 5,
//
//                           width: width * 0.40,
//                           height: height * 0.05,
//                           onTap: () {},
//                           child: Center(
//                             child: Text(
//                               'Quick Settle',
//                               textScaler: TextScaler.linear(1),
//
//                               style: GoogleFonts.poppins(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w500,
//                                   fontSize: 16),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 10),
//
//                     // Settle & Print Bill
//                     widget.isdelivery
//                         ? SizedBox():
//                     CommonButton(
//                       bordercircular: 5,
//
//                       width: width,
//                       height: height * 0.06,
//                       onTap: () {},
//                       child: Center(
//                         child: Text(
//                           'Settle & Print Bill',
//                           textScaler: TextScaler.linear(1),
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w500,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     )
//
//
//                   ],
//                 ),
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }