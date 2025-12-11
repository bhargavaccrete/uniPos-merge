import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/orderDetails.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class WeekByRefund extends StatefulWidget {
  const WeekByRefund({super.key});

  @override
  State<WeekByRefund> createState() => _WeekByRefundState();
}

class _WeekByRefundState extends State<WeekByRefund> {
  List<pastOrderModel> _refundedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRefundedOrders();
  }

  Future<void> _loadRefundedOrders() async {
    setState(() => _isLoading = true);
    try {
      final allOrders = await HivePastOrder.getAllPastOrderModel();
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6));

      final filteredOrders = allOrders.where((order) {
        if (order.refundedAt == null) return false;
        final refundDate = order.refundedAt!;
        return refundDate.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
            refundDate.isBefore(endOfWeek.add(Duration(days: 1)));
      }).toList();

      setState(() {
        _refundedOrders = filteredOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommonButton(
                  width: width * 0.5,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined, color: Colors.white),
                      Text('Export TO Excel',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500))
                    ],
                  )),
              SizedBox(height: 25),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _refundedOrders.isEmpty
                  ? Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No refunds found this week',
                      style: GoogleFonts.poppins(fontSize: 16)),
                ),
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                    headingRowHeight: 50,
                    columnSpacing: 2,
                    headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                    border: TableBorder.all(color: Colors.white),
                    columns: [
                      DataColumn(
                          columnWidth: FixedColumnWidth(width * 0.25),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),
                              child: Text('Date',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14)))),
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
                              child: Text("Order ID",
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.4),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Customer Name',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
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
                              child: Text('Payment Type',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
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
                              child: Text('Order Type',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
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
                              child: Text('Refund(Rs.)',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
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
                              child: Text('Reason',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                    ],
                    rows: _refundedOrders.map((order) {
                      final dateStr = order.refundedAt != null
                          ? DateFormat('dd/MM/yyyy').format(order.refundedAt!)
                          : '-';
                      return DataRow(
                        onSelectChanged: (selected) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Orderdetails(Order: order),
                            ),
                          );
                        },
                        cells: [
                          DataCell(Center(
                              child: Text(dateStr,
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
                          DataCell(Center(
                              child: Text(order.id ?? '-',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
                          DataCell(Center(
                              child: Text(order.customerName ?? '-',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
                          DataCell(Center(
                              child: Text(order.paymentmode ?? '-',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
                          DataCell(Center(
                              child: Text(order.orderType ?? '-',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
                          DataCell(Center(
                              child: Text('₹${order.refundAmount?.toStringAsFixed(2) ?? '0.00'}',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
                          DataCell(Center(
                              child: Text(
                                  order.refundReason?.split('\n').last.trim() ?? '-',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 12)))),
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