import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';

class Todaytab extends StatefulWidget {
  const Todaytab({super.key});

  @override
  State<Todaytab> createState() => _TodaytabState();
}

class _TodaytabState extends State<Todaytab> {
  // State variables to hold the report data
  List<pastOrderModel> _todaysOrders = [];
  double _totalSales = 0.0;
  int _orderCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayReport();
  }

  Future<void> _loadTodayReport() async {
    setState(() {
      _isLoading = true;
    });

    // Always reload from Hive to get latest data including refunds
    final box = Hive.box<pastOrderModel>('pastorderBox');
    final allOrders = box.values.toList();
    final now = DateTime.now();


    final filteredList = allOrders.where((order) {
      final orderDate = order.orderAt;
      if (orderDate == null) return false;
      return orderDate.year == now.year &&
          orderDate.month == now.month &&
          orderDate.day == now.day;
    }).toList();

    // Debug: Check refund data in orders
    print('DEBUG TotalSales: Found ${filteredList.length} orders for today');
    for (final order in filteredList) {
      if ((order.refundAmount ?? 0.0) > 0 || order.orderStatus == 'FULLY_REFUNDED' || order.orderStatus == 'PARTIALLY_REFUNDED') {
        print('  Order ${order.id}: status=${order.orderStatus}, total=${order.totalPrice}, refund=${order.refundAmount}');
      }
    }

    // Calculate totals from the filtered list (exclude refunded amounts)
    final totalSales = filteredList.fold(0.0, (sum, order) => sum + (order.totalPrice - (order.refundAmount ?? 0.0)));
    final orderCount = filteredList.where((order) => order.orderStatus != 'FULLY_REFUNDED').length;

    print('DEBUG TotalSales: Calculated totalSales=$totalSales, orderCount=$orderCount');

    // Update the state to rebuild the UI with new data
    setState(() {
      _todaysOrders = filteredList;
      _totalSales = totalSales;
      _orderCount = orderCount;
      _isLoading = false;
    });
  }

  // --- Export to Excel (CSV) Logic ---
  Future<void> _exportToExcel() async {
    if (_todaysOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    // Define the headers for your CSV file
    List<String> headers = [
      'Date',
      'Invoice ID',
      'Customer Name',
      'Payment Method',
      'Order Type',
      'Total Amount (Rs.)'
    ];

    // Map your order data to rows
    List<List<dynamic>> rows = [];
    rows.add(headers);
    for (var order in _todaysOrders) {
      rows.add([
        order.orderAt != null ? DateFormat('dd-MM-yyyy').format(order.orderAt!) : 'N/A',
        order.id,
        order.customerName,
        order.paymentmode ?? 'N/A',
        order.orderType ?? 'N/A',
        (order.totalPrice - (order.refundAmount ?? 0.0)).toStringAsFixed(2), // Net amount after refunds
      ]);
    }

    // Convert data to CSV format
    String csv = const ListToCsvConverter().convert(rows);

    // Save the file and share it
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/today_sales_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], text: "Today's Sales Report");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting file: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // --- FIX: Added this check to show a loading indicator ---
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // This UI will only be built after the data is loaded
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonButton(
              width: 200,
              height: 50,
              bordercircular: 8,
              onTap: _exportToExcel,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Export To Excel',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                  )
                ],
              )),
          const SizedBox(height: 25),
          Text(
            'Total Sales Of Today (Rs.) = ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(_totalSales)}',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          const SizedBox(height: 25),
          Text(
            'Total Order Count = $_orderCount',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          const SizedBox(height: 25),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                border: TableBorder.all(
                    color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8)),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Invoice ID')),
                  DataColumn(label: Text('Customer Name')),
                  DataColumn(label: Text('Mobile No')),
                  DataColumn(label: Text('Payment Method')),
                  DataColumn(label: Text('Order Type')),
                  DataColumn(label: Text('Total (Rs.)')),
                  DataColumn(label: Text('Details')),
                ],
                rows: _todaysOrders.map((order) {
                  return DataRow(cells: [
                    DataCell(Text(order.orderAt != null
                        ? DateFormat('dd-MM-yy hh:mm a').format(order.orderAt!)
                        : 'N/A')),
                    DataCell(Text('#${order.id.substring(0, 8)}...')),
                    DataCell(Text(order.customerName)),
                    const DataCell(Text('-')), // Placeholder for Mobile No
                    DataCell(Text(order.paymentmode ?? 'N/A')),
                    DataCell(Text(order.orderType ?? 'N/A')),
                    DataCell(Text((order.totalPrice - (order.refundAmount ?? 0.0)).toStringAsFixed(2))), // Show net amount
                    DataCell(IconButton( // Placeholder for a 'Details' button/icon.
                      icon: Icon(Icons.visibility, color: AppColors.primary),
                      onPressed: () {
                        // TODO: Add navigation to a detailed order view if needed.
                      },
                    )),
                  ]);
                }).toList()),
          )
        ],
      ),
    );
  }


}
