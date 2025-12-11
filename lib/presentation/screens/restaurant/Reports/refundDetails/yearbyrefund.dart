import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/orderDetails.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import '../../../../../data/models/restaurant/db/database/hive_pastorder.dart';

class YearWisebyRefund extends StatefulWidget {
  const YearWisebyRefund({super.key});

  @override
  State<YearWisebyRefund> createState() => _YearWisebyRefundState();
}

class _YearWisebyRefundState extends State<YearWisebyRefund> {
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

    final selectedYear = dropdownvalue2;

    final filteredOrders = allOrders.where((order) {
      if (order.isRefunded == true && order.refundedAt != null) {
        return order.refundedAt!.year == selectedYear;
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
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Year',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              SizedBox(
                height: 5,
              ),

              Row(
                children: [
                  Container(
                    width: width * 0.4,
                    height: height * 0.05,
                    padding: EdgeInsets.all(5),
                    decoration:
                    BoxDecoration(border: Border.all(color: primarycolor)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton(
                          value: dropdownvalue2,
                          isExpanded: true,
                          items: yearitem.map((dynamic items) {
                            return DropdownMenuItem(
                                value: items, child: Text(items.toString(),textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),));
                          }).toList(),
                          onChanged: (dynamic? newValue) {
                            setState(() {
                              dropdownvalue2 = newValue!;
                            });
                            _loadRefundedOrders();
                          }),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                    // width: width ,
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: primarycolor, shape: BoxShape.circle),
                      // alignment: Alignment.bottomCenter,
                      // height: height * 0.06,'
                      child: Icon(
                        Icons.search,
                        size: 25,
                        color: Colors.white,
                      )),
                ],
              ),
              // SizedBox(height: 20,width: 20,),
              SizedBox(
                height: 20,
              ),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        color: Colors.white,
                      ),
                      Text(
                        'Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),

              SizedBox(
                height: 25,
              ),
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
                        columnWidth:FixedColumnWidth(width *0.25),

                        label: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(50),
                                bottomLeft: Radius.circular(50),
                              ),
                            ),

                            child: Text('Date',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),))),
                    DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        columnWidth:FixedColumnWidth(width *0.2),

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

                        columnWidth:FixedColumnWidth(width *0.4),

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

                        columnWidth:FixedColumnWidth(width *0.3),

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
                                style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center))),DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,

                        columnWidth:FixedColumnWidth(width *0.3),

                        label: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                            ),
                            child: Text('Order Type',textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center))),DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,

                        columnWidth:FixedColumnWidth(width *0.3),

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
                                style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center))),DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,

                        columnWidth:FixedColumnWidth(width *0.3),

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
                                style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center))),
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

              // table
              // Container(
              //   color: Colors.red,
              //   child: DataTable(
              //       columnSpacing: 0,
              //       columns: [
              //
              //     DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //               borderRadius: BorderRadius.only(topLeft: Radius
              //                   .circular(10),
              //                   bottomLeft: Radius.circular(10))
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.2,
              //           height: height * 0.04,
              //           child: Text("Date", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )), DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.25,
              //           height: height * 0.04,
              //           child: Text("Item Name", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )), DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.25,
              //           height: height * 0.04,
              //           child: Text("Quality", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )), DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.25,
              //           height: height * 0.04,
              //           child: Text("Total (RS)", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )),
              //   ],
              //       rows:[]),
              // )
            ],
          ),
        ),
      ),
    );
  }
}
