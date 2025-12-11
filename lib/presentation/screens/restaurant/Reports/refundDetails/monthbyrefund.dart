import 'dart:core';

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
class Monthbyrefund extends StatefulWidget {
  const Monthbyrefund({super.key});

  @override
  State<Monthbyrefund> createState() => _MonthbyrefundState();
}

class _MonthbyrefundState extends State<Monthbyrefund> {
  List<String> monthitem = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'Octomber',
    'November',
    'December',
  ];
  List<dynamic> yearitem = [
    2025,
    2024,
    2023,
    2022,
    2021,
    2020,
    2019,
    2018,
    2017,
    2016
  ];
  String dropDownValue1 = 'January';
  dynamic dropdownvalue2 = 2025;

  List<pastOrderModel> _refundedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRefundedOrders();
  }

  Future<void> _loadRefundedOrders() async {
    setState(() {
      _isLoading = true;
    });

    final allOrders = await HivePastOrder.getAllPastOrderModel();

    // Get the selected month number (1-12)
    final selectedMonth = monthitem.indexOf(dropDownValue1) + 1;
    final selectedYear = dropdownvalue2;

    final filteredOrders = allOrders.where((order) {
      if (order.isRefunded == true && order.refundedAt != null) {
        return order.refundedAt!.month == selectedMonth &&
            order.refundedAt!.year == selectedYear;
      }
      return false;
    }).toList();

    setState(() {
      _refundedOrders = filteredOrders;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height * 1;
    final width = MediaQuery
        .of(context)
        .size
        .width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      // mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Month:',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w500),),


                        Container(
                          padding: EdgeInsets.all(5),
                          width: width * 0.4,
                          height: height * 0.05,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: primarycolor)
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                                value: dropDownValue1,
                                items: monthitem.map((String items) {
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(items,textScaler: TextScaler.linear(1),
                                        style: GoogleFonts.poppins(fontSize: 14),));
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    dropDownValue1 = newValue!;
                                  });
                                  _loadRefundedOrders();
                                }),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(width: 10,),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Year:', textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontWeight: FontWeight
                              .w500, fontSize: 16),),

                        Container(
                          width: width * 0.4,
                          height: height * 0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              border: Border.all(color: primarycolor),
                              borderRadius: BorderRadius.circular(5)
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                                value: dropdownvalue2,
                                items: yearitem.map((dynamic items) {
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(items.toString(),textScaler: TextScaler.linear(1),
                                        style: GoogleFonts.poppins(fontSize: 14),));
                                }).toList(),
                                onChanged: (dynamic? newValue) {
                                  setState(() {
                                    dropdownvalue2 = newValue!;
                                  });
                                  _loadRefundedOrders();
                                }),
                          ),
                        )

                      ],
                    ),
                  ),
                  SizedBox(width: 5,),
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: primarycolor,
                        borderRadius: BorderRadius.circular(50)
                    ),
                    child: Icon(
                      Icons.search,
                      size: 25,
                      color: Colors.white,
                    ),
                  )
                ],
              ),
              SizedBox(height: 25,),
              CommonButton(
                  width: width * 0.5,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined, color: Colors.white,),
                      Text('Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),)
                    ],)),

              SizedBox(height: 25,),


              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 50,
                  columnSpacing: 2,
                  headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                  border: TableBorder.all(
                    // borderRadius: BorderRadius.circular(5),
                      color: Colors.white),
                  decoration: BoxDecoration(
                    // borderRadius:BorderRadiusDirectional.only(topStart: Radius.circular(15),bottomStart: Radius.circular(15)),
                    // color: Colors.green,

                  ),
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

                            child: Text('Date', textScaler: TextScaler.linear(
                                1),
                              style: GoogleFonts.poppins(fontSize: 14),))),
                    DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        columnWidth: FixedColumnWidth(width * 0.2),

                        // columnWidth:FlexColumnWidth(width * 0.1),
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
                              textAlign: TextAlign.center,))),
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
                                textAlign: TextAlign.center))), DataColumn(
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
                                'Order Type', textScaler: TextScaler.linear(
                                1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center))), DataColumn(
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
                                textAlign: TextAlign.center))), DataColumn(
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

                  rows: _isLoading
                      ? []
                      : _refundedOrders.isEmpty
                      ? []
                      : _refundedOrders.map((order) {
                    String reason = '';
                    if (order.refundReason != null && order.refundReason!.isNotEmpty) {
                      final lines = order.refundReason!.split('\n');
                      reason = lines.isNotEmpty ? lines.last.trim() : '';
                    }

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
                        DataCell(
                          Center(
                            child: Text(
                              order.refundedAt != null
                                  ? DateFormat('dd/MM/yyyy').format(order.refundedAt!)
                                  : '',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              order.id,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              order.customerName,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              order.paymentmode ?? '',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              order.orderType ?? '',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              order.refundAmount != null
                                  ? '₹${order.refundAmount!.toStringAsFixed(2)}'
                                  : '₹0.00',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              reason,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),

                ),
              ),

              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: primarycolor),
                  ),
                ),

              if (!_isLoading && _refundedOrders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No refunds found',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}
