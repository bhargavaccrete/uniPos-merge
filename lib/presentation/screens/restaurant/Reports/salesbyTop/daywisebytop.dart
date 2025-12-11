import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart' show HivePastOrder;
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class DayWisebyTop extends StatefulWidget {
  const DayWisebyTop({super.key});

  @override
  State<DayWisebyTop> createState() => _DayWisebyTopState();
}

class _DayWisebyTopState extends State<DayWisebyTop> {
  DateTime? _fromDate;
  List<Map<String, dynamic>> _topSellingItems = [];
  bool _isLoading = false;

  // Function to show the Date Picker
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
      });
    }
  }

  Future<void> _loadTopSellingItems() async {
    if (_fromDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date first'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get all past orders
      final allOrders = await HivePastOrder.getAllPastOrderModel();

      // Filter orders for selected date only
      final selectedDateOrders = allOrders.where((order) {
        if (order.orderAt == null) return false;
        final orderDate = order.orderAt!;
        return orderDate.year == _fromDate!.year &&
            orderDate.month == _fromDate!.month &&
            orderDate.day == _fromDate!.day;
      }).toList();

      // Calculate item sales
      Map<String, Map<String, dynamic>> itemSales = {};

      for (var order in selectedDateOrders) {
        for (var item in order.items) {
          final itemName = item.title;
          final quantity = item.quantity;
          final price = item.price;
          final totalAmount = price * quantity;

          if (itemSales.containsKey(itemName)) {
            itemSales[itemName]!['quantity'] += quantity;
            itemSales[itemName]!['totalAmount'] += totalAmount;
          } else {
            itemSales[itemName] = {
              'itemName': itemName,
              'quantity': quantity,
              'totalAmount': totalAmount,
            };
          }
        }
      }

      // Convert to list and sort by quantity (most sold first)
      final sortedItems = itemSales.values.toList()
        ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

      setState(() {
        _topSellingItems = sortedItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading top selling items: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    final displayDate = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : '';

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Date:',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
              ),

              // date picker
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      _pickDate(context);
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                            border: Border.all(color: primarycolor),
                            borderRadius: BorderRadius.circular(5)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fromDate == null
                                  ? ' DD/MM/YYYY'
                                  : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Icon(Icons.date_range, color: primarycolor)
                          ],
                        )),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: _loadTopSellingItems,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: primarycolor, borderRadius: BorderRadius.circular(50)),
                      child: Icon(Icons.search, size: 25, color: Colors.white),
                    ),
                  )
                ],
              ),

              SizedBox(height: 20),
              // Export TO Excel
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined, color: Colors.white),
                      Text(
                        'Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),

              SizedBox(height: 25),

              // Loading or Results
              if (_isLoading)
                Center(child: CircularProgressIndicator(color: primarycolor))
              else if (_topSellingItems.isEmpty && _fromDate != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No sales data for selected date',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_topSellingItems.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                        headingRowHeight: 50,
                        columnSpacing: 2,
                        headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                        border: TableBorder.all(color: Colors.white),
                        columns: [
                          DataColumn(
                              columnWidth: FixedColumnWidth(width * 0.2),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(50),
                                      bottomLeft: Radius.circular(50),
                                    ),
                                  ),
                                  child: Text(
                                    'Date',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ))),
                          DataColumn(
                              headingRowAlignment: MainAxisAlignment.center,
                              columnWidth: FixedColumnWidth(width * 0.3),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "Item Name",
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ))),
                          DataColumn(
                              headingRowAlignment: MainAxisAlignment.center,
                              columnWidth: FixedColumnWidth(width * 0.2),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text('Quantity',
                                      textScaler: TextScaler.linear(1),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      textAlign: TextAlign.center))),
                          DataColumn(
                              headingRowAlignment: MainAxisAlignment.center,
                              columnWidth: FixedColumnWidth(width * 0.25),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text('Total (Rs)',
                                      textScaler: TextScaler.linear(1),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      textAlign: TextAlign.center))),
                        ],
                        rows: _topSellingItems.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Center(
                                    child: Text(displayDate, style: GoogleFonts.poppins(fontSize: 12))),
                              ),
                              DataCell(
                                Center(
                                    child: Text(item['itemName'],
                                        style: GoogleFonts.poppins(fontSize: 12))),
                              ),
                              DataCell(
                                Center(
                                    child: Text('${item['quantity']}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, fontWeight: FontWeight.w600))),
                              ),
                              DataCell(
                                Center(
                                    child: Text('Rs. ${item['totalAmount'].toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, fontWeight: FontWeight.w600))),
                              ),
                            ],
                          );
                        }).toList()),
                  )
            ],
          ),
        ),
      ),
    );
  }
}