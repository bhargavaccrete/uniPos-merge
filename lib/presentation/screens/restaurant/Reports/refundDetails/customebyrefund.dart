import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/orderDetails.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';


class CustomByRefund extends StatefulWidget {
  const CustomByRefund({super.key});

  @override
  State<CustomByRefund> createState() => _CustomByRefundState();
}

class _CustomByRefundState extends State<CustomByRefund> {
  DateTime? _fromDate;
  DateTime? _toDate;

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

    final allOrders = pastOrderStore.pastOrders.toList();

    List<pastOrderModel> filteredOrders = [];

    if (_fromDate != null && _toDate != null) {
      filteredOrders = allOrders.where((order) {
        if (order.isRefunded == true && order.refundedAt != null) {
          final refundDate = DateTime(
            order.refundedAt!.year,
            order.refundedAt!.month,
            order.refundedAt!.day,
          );
          final fromDate = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
          final toDate = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);

          return (refundDate.isAtSameMomentAs(fromDate) || refundDate.isAfter(fromDate)) &&
                 (refundDate.isAtSameMomentAs(toDate) || refundDate.isBefore(toDate));
        }
        return false;
      }).toList();
    }

    setState(() {
      _refundedOrders = filteredOrders;
      _isLoading = false;
    });
  }

  // // Function to show the Date Picker
  // Future<void> _pickDate(BuildContext context) async {
  //   DateTime? pickedDate = await showDatePicker(
  //       context: context,
  //       initialDate: DateTime.now(),
  //       firstDate: DateTime(2000),
  //       lastDate: DateTime(2100));
  //
  //   if (pickedDate != null) {
  //     setState(() {
  //       _fromDate = pickedDate;
  //     });
  //   }
  // }
  // Function to  pick "From Date"
  Future<void> _pickFromDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _fromDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
        //   Ensure "To Date" is after "from Date"
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = null;
        }
      });
    }
  }

  // Function to  pick To Date"
  Future<void> _pickToDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _toDate ?? _fromDate ?? DateTime.now(),
        firstDate: _fromDate ?? DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _toDate = pickedDate;
      });
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
            // mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                // mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From Date:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.start,
                  ),
                  // Container(
                  //   width: width * 0.6,
                  //   height: height * 0.04,
                  //   child: CommonTextForm(
                  //     hintText: 'DD/MM/YYYY',
                  //     HintColor: Colors.grey,
                  //     gesture: Icon(Icons.date_range, color: primarycolor,),
                  //
                  //     BorderColor: primarycolor,
                  //     obsecureText: false,
                  //   ),
                  // ),

                  // date picker
                  // InkWell(
                  //   onTap: () {
                  //     _pickDate(context);
                  //   },
                  //   child: Container(
                  //       padding: EdgeInsets.symmetric(horizontal: 10),
                  //       width: width * 0.6,
                  //       height: height * 0.04,
                  //       decoration: BoxDecoration(
                  //         border: Border.all(color: primarycolor),
                  //         // color: Colors.red,
                  //         borderRadius: BorderRadius.circular(15)
                  //       ),
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //         children: [
                  //           Text(
                  //             _fromDate == null
                  //                 ? ' DD/MM/yyyy'
                  //                 : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                  //           ),
                  //           Icon(Icons.date_range)
                  //         ],
                  //       )),
                  // ),
                  InkWell(
                    onTap: () {
                      _pickFromDate(context);
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                            border: Border.all(color: primarycolor),
                            // color: Colors.red,
                            borderRadius: BorderRadius.circular(5)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fromDate == null
                                  ? ' DD/MM/yyyy'
                                  : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Icon(Icons.date_range)
                          ],
                        )),
                  ),

                  SizedBox(height: 10,),
                  // SizedBox(height: 25,),
                  Text(
                    'To Date:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.start,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap:
                              _fromDate == null ? null : () => _pickToDate(context),
                          child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              height: height * 0.05,
                              decoration: BoxDecoration(
                                  border: Border.all(color: primarycolor),
                                  // color: Colors.red,
                                  borderRadius: BorderRadius.circular(5)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _toDate == null
                                        ? ' DD/MM/yyyy'
                                        : '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                  Icon(Icons.date_range)
                                ],
                              )),
                        ),
                      ),
                      SizedBox(width: 10,),
                      InkWell(
                        onTap: () {
                          if (_fromDate != null && _toDate != null) {
                            _loadRefundedOrders();
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: primarycolor,
                              borderRadius: BorderRadius.circular(50)),
                          child: Icon(
                            Icons.search,
                            size: 25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                height: 25,
              ),
              // CommonButton
              CommonButton(
                  width: width * 0.5,
                  height: height * 0.07,
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
            ],
          ),
        ),
      ),
    );
  }
}
