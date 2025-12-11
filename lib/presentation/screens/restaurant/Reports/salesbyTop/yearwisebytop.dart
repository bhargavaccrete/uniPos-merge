import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/daywisebytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/monthwisebytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/thisweekbytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/todaybytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/yearwisebytop.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import '../../../../../constants/restaurant/color.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class YearWisebyTop extends StatefulWidget {
  const YearWisebyTop({super.key});

  @override
  State<YearWisebyTop> createState() => _YearWisebyTopState();
}

class _YearWisebyTopState extends State<YearWisebyTop> {
  List<Map<String, dynamic>> _topSellingItems = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTopSellingItems();
  }

  Future<void> _selectYear() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2016),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Year',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primarycolor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadTopSellingItems();
    }
  }

  Future<void> _loadTopSellingItems() async {
    setState(() => _isLoading = true);

    try {
      // Get all past orders
      final allOrders = await HivePastOrder.getAllPastOrderModel();

      // Calculate start and end of selected year
      final yearStart = DateTime(_selectedDate.year, 1, 1);
      final yearEnd = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);

      // Filter orders for selected year
      final yearOrders = allOrders.where((order) {
        if (order.orderAt == null) return false;
        final orderDate = order.orderAt!;
        return orderDate.isAfter(yearStart.subtract(Duration(seconds: 1))) &&
            orderDate.isBefore(yearEnd.add(Duration(seconds: 1)));
      }).toList();

      // Calculate item sales
      Map<String, Map<String, dynamic>> itemSales = {};

      for (var order in yearOrders) {
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
    final yearDisplay = DateFormat('yyyy').format(_selectedDate);

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primarycolor))
          : SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Year',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5),
                        InkWell(
                          onTap: _selectYear,
                          child: Container(
                            width: width * 0.4,
                            height: height * 0.05,
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: primarycolor),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  yearDisplay,
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Icon(Icons.calendar_today, color: primarycolor, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: InkWell(
                      onTap: _loadTopSellingItems,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primarycolor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search,
                          size: 25,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
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
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 25),
              if (_topSellingItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No sales data for $yearDisplay',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
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
                            'Year',
                            textScaler: TextScaler.linear(1),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ),
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
                          ),
                        ),
                      ),
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
                          child: Text(
                            'Quantity',
                            textScaler: TextScaler.linear(1),
                            style: GoogleFonts.poppins(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
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
                          child: Text(
                            'Total (Rs)',
                            textScaler: TextScaler.linear(1),
                            style: GoogleFonts.poppins(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    rows: _topSellingItems.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Center(
                              child: Text(
                                yearDisplay,
                                style: GoogleFonts.poppins(fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(
                            Center(
                              child: Text(
                                item['itemName'],
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            Center(
                              child: Text(
                                '${item['quantity']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Center(
                              child: Text(
                                'Rs. ${item['totalAmount'].toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}