import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../../../../data/models/restaurant/db/ordermodel_309.dart';


class OrderCard extends StatelessWidget {
  final OrderModel order;
  final Function(String) onDelete;
  final VoidCallback? ontap;
  final VoidCallback? ontapcooking;
  final VoidCallback? onPrintKot; // Add callback
  final Color? color;
  const OrderCard({super.key, required this.order, required this.onDelete, this.ontap  , this.ontapcooking, this.onPrintKot, this.color});




  @override
  Widget build(BuildContext context) {
    // Helper function to create an icon+text pair
    Widget buildHeaderItem(IconData icon, String title) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(height: 4),
          Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
        ],
      );
    }

    // Determine the icon for the order type
    IconData orderTypeIcon() {
      switch (order.orderType) {
        case "Dine In":
          return Icons.restaurant_menu;
        case "Delivery":
          return Icons.delivery_dining;
        default:
          return Icons.takeout_dining; // Take Away
      }
    }

    return InkWell(
      onTap: ontap,
      child: Card                                                                                                                                                                                                                                                                                                                                                                                              (
        elevation: 10,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 1. Header Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: color,
              // Color(0xffc52b33),
              child: Row(
                children: [
                  // Order Type
                  Expanded(child: buildHeaderItem(orderTypeIcon(), order.orderType)),

                  // Order Number (if available)
                  if (order.orderNumber != null)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${order.orderNumber}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Order No.',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),

                  // KOT Numbers
                  Expanded(
                    child: Column(
                      children: [
                        // Display all KOT numbers
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: order.getKotNumbers().map((kotNum) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                '$kotNum',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 4),
                        Text('KOT', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),

                  // Time
                  Expanded(child: Center(child: Text(DateFormat.jm().format(order.timeStamp), style: GoogleFonts.poppins(color: Colors.white)))),
                ],
              ),
            ),

            // 2. Customer & Status Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.customerName.isEmpty ? 'Guest' : order.customerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(order.paymentStatus ?? 'unPaid', style: GoogleFonts.poppins(color: order.isPaid == true ? Colors.green:Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),

                      InkWell(
                        onTap: () => onDelete(order.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.delete, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Admin & KOT Print Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: Colors.teal.shade700, size: 20),
                      const SizedBox(width: 4),
                      Text('#Admin', style: GoogleFonts.poppins()),
                    ],
                  ),
                  InkWell(
                    onTap: onPrintKot, // Trigger print callback
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xff12b294), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          const Icon(Icons.print, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text('Kot', style: GoogleFonts.poppins(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Items Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('QTY   Items', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  // Removed redundant POS ID string
                ],
              ),
            ),

            // 5. Items List and Final Button
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Column(
                children: [
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Text('${item.quantity}X', style: GoogleFonts.poppins()),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: GoogleFonts.poppins()),
                              if (item.variantName != null && item.variantName!.isNotEmpty)
                                Text(
                                  'Size: ${item.variantName}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              if (item.choiceNames != null && item.choiceNames!.isNotEmpty)
                                Text(
                                  'Add-ons: ${item.choiceNames!.join(', ')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              if (item.extras != null && item.extras!.isNotEmpty)
                                Builder(
                                  builder: (context) {
                                    // Group extras by name and count quantities
                                    Map<String, Map<String, dynamic>> groupedExtras = {};

                                    for (var extra in item.extras!) {
                                      final displayName = extra['displayName'] ?? extra['name'] ?? 'Unknown';
                                      final price = extra['price']?.toDouble() ?? 0.0;
                                      final quantity = extra['quantity']?.toInt() ?? 1;

                                      String key = '$displayName-${price.toStringAsFixed(2)}';

                                      if (groupedExtras.containsKey(key)) {
                                        groupedExtras[key]!['quantity'] = (groupedExtras[key]!['quantity'] as int) + quantity;
                                      } else {
                                        groupedExtras[key] = {
                                          'displayName': displayName,
                                          'price': price,
                                          'quantity': quantity,
                                        };
                                      }
                                    }

                                    // Build display string
                                    final extrasDisplay = groupedExtras.entries.map((entry) {
                                      final data = entry.value;
                                      final int qty = data['quantity'] as int;
                                      final String name = data['displayName'] as String;
                                      final double price = data['price'] as double;

                                      if (qty > 1) {
                                        return '${qty}x $name(₹${price.toStringAsFixed(2)})';
                                      } else {
                                        return '$name(₹${price.toStringAsFixed(2)})';
                                      }
                                    }).join(', ');

                                    return Text(
                                      'Extras: $extrasDisplay',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  )).toList(),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:ontapcooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:color,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(order.status, style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



//
//
// Card(
// elevation: 2,
// child: Container(
// decoration: BoxDecoration(
// // borderRadius: BorderRadius.only(topLeft: Radius.circular(15),topRight: Radius.circular(15)),
// borderRadius: BorderRadius.circular(15),
// color: Colors.green,
//
// ),
// // width: width * 0.8,
// // height: height * 0.4,
// child: Column(
// children: [
// Container(
// decoration: BoxDecoration(
// borderRadius: BorderRadius.only(topLeft: Radius.circular(15),topRight: Radius.circular(15)),
//
// color: Colors.red,
//
// ),
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
// Container(
//
// padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
// alignment: Alignment.center,
// child: Column(
// children: [
// Icon(Icons.delivery_dining_outlined,color: Colors.white,),
// Text('Home Delivery',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12),)
// ],
// ),
// ),
// SizedBox(
// width: 5,
// ),
// Container(
// child: Column(
// children: [
// Text('AU-8',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12)),
// Text('KOT NO.',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12)),
// ],
// ),
// ),
// SizedBox(
// width: 5,
// ),
// Container(
// child: Column(
// children: [
// Text('11:30 AM',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12))
// ],
// ),
// ),
// SizedBox(
// width: 5,
// ),
// ],
// ),
// ),
//
// // Test
// Container(
// padding: EdgeInsets.symmetric(horizontal: 10,vertical: 5),
// color: Colors.blue.shade50,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Text('test',style: GoogleFonts.poppins(fontSize: 12)),
// Row(
// children: [
// Text('UNPAID',style: GoogleFonts.poppins(color: Colors.red,fontWeight: FontWeight.w600,fontSize: 12)),
// SizedBox(width: 10,),
// Container(
// // padding: EdgeInsets.all(5),
// // width: width * 0.2,
// // height: height * 0.05,
// decoration: BoxDecoration(
// borderRadius: BorderRadius.circular(2),
// color: Colors.red,
// shape: BoxShape.rectangle
//
// ),
// child: Icon(Icons.delete,color: Colors.white,size: 20,)
// )
// ],
// )
//
// ],
// ),
// ),
// Container(
// padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
// color: Colors.white,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Row(
// children: [
// Icon(Icons.person_outline_outlined,color: AppColors.primary,),
// Text('#Admin',style: GoogleFonts.poppins(fontSize: 12)),
// ],
// ),
// Container(
// padding: EdgeInsets.all(5),
// decoration: BoxDecoration(
// color: AppColors.primary,
// borderRadius: BorderRadius.circular(
// 5
// )
// ),
// child: Row(
// children: [
// Icon(Icons.print,size: 15,color: Colors.white,),
// SizedBox(width: 5,),
// Text('Kot',style: GoogleFonts.poppins(fontSize: 12,color: Colors.white),),
//
// ],
// ),
// )
//
// ],
// ),
// ),
// Container(
// padding: EdgeInsets.symmetric(horizontal: 5),
// color: Colors.blue.shade50,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Row(
// children: [
// Text('QTY',style: GoogleFonts.poppins(fontSize: 12)),
// SizedBox(width: 10,),
// Text('Items',style: GoogleFonts.poppins(fontSize: 12)),
// ],
// ),
// Text('#POS01-006',style: GoogleFonts.poppins(fontSize: 10))
//
// ],
// ),
// ),
// // cooking
// Container(
// decoration: BoxDecoration(
// borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15),bottomRight: Radius.circular(15)),
// color: Colors.white,
// ),
// padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
//
// child: Column(
// children: [
// Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Text('1X'),
// Text('Almonds Carnival Ice Cream',style: GoogleFonts.poppins(fontSize: 12),),
// Container(
// // padding: EdgeInsets.all(5),
// // width: width * 0.2,
// // height: height * 0.05,
// decoration: BoxDecoration(
// borderRadius: BorderRadius.circular(2),
// color: Colors.red,
// shape: BoxShape.rectangle
//
// ),
// child: Icon(Icons.delete,color: Colors.white,size: 20,)
// )
//
// ],
// ),
// SizedBox(height: 10,),
// CommonButton(
// bordercolor: Colors.red,
// bordercircular: 5,
// bgcolor: Colors.red,
// width: width * 0.7,
// height: height *0.04,
// onTap: (){}, child: Text('Cooking',style: GoogleFonts.poppins(color: Colors.white),))
// ],
// ),
// )
//
// ],
// ),
// ),
// ),