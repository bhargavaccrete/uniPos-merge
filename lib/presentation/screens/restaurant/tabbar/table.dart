
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../start order/cart/cart.dart';
import '../start order/startorder.dart';

class TableScreen extends StatefulWidget {
 final bool? isfromcart;
  const TableScreen({super.key, this.isfromcart= false});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  // Use a Future to handle the asynchronous loading of tables
  late Future<List<TableModel>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  /// Loads or reloads the list of tables from the database.
  void _loadTables() {
    setState(() {
      _tablesFuture = Future.value(tableStore.tables.toList());
    });
  }

  /// Shows a dialog to add a new table.
  ///
  void _addTable() {
    final Tcontroller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Table'),

        content: Container(
          width: 200,
          height: 200,
          child: Column(
            children: [
              TextField(
                controller: Tcontroller,
                autofocus: true,
                decoration: InputDecoration(hintText: 'Enter Table Name (e.g., T-4)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Tcontroller.text.isNotEmpty) {
                final newTable = TableModel(
                    id: Tcontroller.text.trim(),

                );
                await tableStore.addTable(newTable);
                Navigator.pop(context);
                _loadTables(); // Refresh the list after adding
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // // --- SUGGESTION 1: Refactored onTap logic for clarity and safety ---
  // /// Handles the logic for when any table card is tapped.
  // void _onTableTapped(TableModel table) async {
  //   // --- SCENARIO A: The screen is being used to SELECT a table for a new order. ---
  //   if (widget.isFromCart) {
  //     if (table.status == 'Available') {
  //       // If the table is free, pop the screen and return the selected table's ID.
  //       Navigator.pop(context, table.id);
  //     } else {
  //       // If the table is occupied, show a message and do nothing.
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Table ${table.id} is already occupied.')),
  //       );
  //     }
  //     return; // Stop here.
  //   }
  //
  //   // --- SCENARIO B: The screen is being used as a general table overview. ---
  //
  //   // If the table is occupied...
  //   if (table.status == 'Cooking' || table.status == 'Reserved') {
  //     final existingOrder = await HiveOrders.getActiveOrderByTableId(table.id);
  //     if (!mounted) return;
  //
  //     if (existingOrder != null) {
  //       // Navigate to the cart, passing the existing order data directly.
  //       // SUGGESTION 2: Removed the unnecessary writes to the 'app_state' Hive box.
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => CartScreen(
  //             existingOrder: existingOrder,
  //           ),
  //         ),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Could not find an active order for Table ${table.id}.')),
  //       );
  //     }
  //   }
  //   // If the table is available...
  //   else {
  //     // Navigate to the MenuScreen to start a brand new order for this specific table.
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => (tableIdForNewOrder: table.id),
  //       ),
  //     );
  //   }
  // }
  //

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Table Layout"),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _loadTables,
            tooltip: 'Sync Table',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Table Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CommonButton(
                  bordercircular: 6,
                  width: width * 0.35,
                  height: height * 0.05,
                  onTap: _addTable,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Table', style: GoogleFonts.poppins(color: Colors.white)),
                    ],
                  ),
                ),


                // CommonButton(
                //   bordercircular: 5,
                //     width: width * 0.40,
                //     height: height * 0.05,
                //     onTap: (){
                //
                //       final controllerone = TextEditingController();
                //       final controllertwo = TextEditingController();
                //     showDialog(context: context, builder: (context)=> AlertDialog(
                //
                //       title: Text('Merge Tables'),
                //       content: Row(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //
                //         children: [
                //          Container(
                //              width: 30,
                //              child: TextFormField(
                //                controller: controllerone,
                //              )),
                //           Icon(Icons.add),
                //           Container(
                //              width: 30,
                //              child: TextFormField(
                //                controller: controllertwo,
                //              )),
                //
                //         ],
                //       ),
                //       // content:
                //       // Container(
                //       //   width: 100,
                //       //   height:  100,
                //       //   child: Row(
                //       //     children: [
                //       //       CommonTextForm(
                //       //         height: 50,
                //       //           width: 50,
                //       //           obsecureText: false),
                //       //       CommonTextForm(
                //       //           height: 50,
                //       //
                //       //           width: 50,
                //       //           obsecureText: false),
                //       //     ],
                //       //   ),
                //       // ),
                //       actions: [
                //         TextButton(
                //           onPressed: () => Navigator.pop(context),
                //           child: Text('Cancel'),
                //         ),
                //         ElevatedButton(
                //           onPressed: () async {
                //
                //           },
                //           child: Text('Confirm'),
                //         ),
                //       ],
                //
                //     ));
                //     },
                //     child:Text('merge Table Order',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12),))
              ],
            ),
            SizedBox(height: 20),

            // Legend for table statuses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.green, 'Available'),
                _buildLegendItem(Colors.orange, 'Reserved'),
                _buildLegendItem(Colors.red, 'Cooking'),
              ],
            ),
            SizedBox(height: 20),

            // Grid of tables loaded from the database
            Expanded(
              child:ValueListenableBuilder(
                valueListenable: Hive.box<TableModel>('tablesBox').listenable(),
                builder: (context,table,_ ) {


                  if(table.isEmpty){
                    return Center(child: Text('No tables found. Add one to get started.'));
                  }

                  dynamic allTable = table.values.toList();


                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: allTable.length,
                    itemBuilder: (context, index) {
                      final table = allTable[index];
                      return TableCard(
                        table: table,
                        onTap: () async {

                          // SCENARIO 1: Table is OCCUPIED ('Cooking' or 'Served')
                          if (table.status == 'Cooking' || table.status == 'Reserved' || table.status == 'Running') {
                            final existingOrder = orderStore.getActiveOrderByTableId(table.id);
                            // if (!mounted) return;

                            if (existingOrder != null) {
                              final appStateBox = Hive.box('app_state');
                              await appStateBox.put('is_existing_order', true);
                              await appStateBox.put('table_id', existingOrder.tableNo);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CartScreen(
                                     // tableid: table.id,
                                    existingOrder: existingOrder,
                                    // cartItems: existingOrder.items,
                                    selectedTableNo: table.id,
                                  ),
                                ),
                              );
                            }
                            else {
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(content: Text('Could not find an active order for Table ${table.id}.')),
                              // );
                              NotificationService.instance.showError(
                                'Could not find an active order for Table ${table.id}.',
                              );


                            }
                          }
                          // SCENARIO 2: Table is AVAILABLE
                          else {
                            // Navigate to the main order screen to start a new order,
                            // passing the selected table's ID.
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => Startorder(newOrderForTableId: table.id),
                            //   ),
                            // );

                            if(widget.isfromcart==true){
                              print(table.id);
                              Navigator.pop(context ,table.id);

                            }else{
                              Navigator.push(context, MaterialPageRoute(builder: (context)=> Startorder(newOrderForTableId: table.id,)));
                            }

                          }
                        },


                        // onTap: () async { // Make the callback async
                        //
                        //   // If the table is OCCUPIED...
                        //   if (table.status == 'Cooking' || table.status == 'Reserved') {
                        //     // Find the active order associated with this table's ID.
                        //     final existingOrder = await HiveOrders.getActiveOrderByTableId(table.id);
                        //
                        //     if (!mounted) return;
                        //
                        //     // If an active order was found...
                        //     if (existingOrder != null) {
                        //       // Navigate to YOUR CartScreen, passing the existing order's details.
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (context) => CartScreen(
                        //             existingOrder: existingOrder,
                        //             cartItems: existingOrder.items, // Pass the items as well
                        //             selectedTableNo: existingOrder.tableNo,
                        //           ),
                        //         ),
                        //       );
                        //     } else {
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(content: Text('Could not find an active order for Table ${table.id}.')),
                        //       );
                        //     }
                        //   }
                        //   // You can add an `else` block here for what happens when an 'Available' table is tapped.
                        // },
                        //



                        // onTap: () async {
                        //   // Only allow selection of available tables
                        //   if (table.status == 'Available') {
                        //     Navigator.of(context).pop(table.id);
                        //  // Navigator.push(context, MaterialPageRoute(builder: (context)=> Startorder(newOrderForTableId: table.id,)));
                        //
                        //   }
                        //   // else {
                        //   //   ScaffoldMessenger.of(context).showSnackBar(
                        //   //     SnackBar(content: Text('Table ${table.id} is currently occupied.')),
                        //   //   );
                        //   // }
                        //   else{
                        //     final existingOrder = await HiveOrders.getActiveOrderByTableId(table.id);
                        //     if(!mounted) return;
                        //     if(existingOrder != null){
                        //       Navigator.push(context,
                        //       MaterialPageRoute(builder: (context)=> Startorder(existingOrder: existingOrder,))
                        //       );
                        //
                        //     }else{
                        //         ScaffoldMessenger.of(context).showSnackBar(
                        //           SnackBar(content: Text('Could not find an active order for Table ${table.id}.')),
                        //         );
                        //     }
                        //   }
                        // },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A reusable widget to display a single table card.
class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;

  const TableCard({super.key, required this.table, required this.onTap});

  String _formatOrderTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // If less than 1 hour, show minutes
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      }
      // If less than 24 hours, show hours
      else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      }
      // Otherwise show the time
      else {
        return DateFormat('hh:mm a').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    switch (table.status) {
      case 'Cooking':
        statusColor = Colors.red;
        break;
      case 'Reserved':
        statusColor = Colors.orange;
        break;
      default: // Available
        statusColor = Colors.green;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main content of the card
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        table.id,
                        style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),

                      // Text(
                      //   '(${table.tableCapacity.toString()})',
                      //   style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      // ),

                    ],
                  ),
                  if (table.status != 'Available') ...[
                    SizedBox(height: 8),
                    Text(
                      'Rs. ${table.currentOrderTotal?.toStringAsFixed(2) ?? '0.00'}',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                        SizedBox(width: 4),
                        Text('#Admin', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12)),
                      ],
                    ),
                    // Display order time
                    if (table.timeStamp != null && table.timeStamp!.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade700),
                          SizedBox(width: 4),
                          Text(
                            _formatOrderTime(table.timeStamp),
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ]
                ],
              ),
            ),
            // Status label positioned over the top border
            Positioned(
              top: -10,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1.5),
                ),
                child: Text(
                  table.status,
                  style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
