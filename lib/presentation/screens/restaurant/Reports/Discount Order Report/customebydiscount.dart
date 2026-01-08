import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/currency_helper.dart';
import 'package:unipos/util/restaurant/decimal_settings.dart';

import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';

class CustomByDiscount extends StatefulWidget {
  const CustomByDiscount({super.key});

  @override
  State<CustomByDiscount> createState() => _CustomByDiscountState();
}

class _CustomByDiscountState extends State<CustomByDiscount> {
  DateTime? _fromDate;
  DateTime? _toDate;

  List<pastOrderModel> _discountedOrders = [];
  double _totalDiscountAmount = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadData() async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select both Start and End dates")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final box = Hive.box<pastOrderModel>(HiveBoxNames.restaurantPastOrders);
      
      // Normalize dates to include full days
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(Duration(days: 1));

      final allOrders = box.values.toList();
      final rangeOrders = allOrders.where((order) {
        if (order.orderAt == null) return false;
        // Exclude refunded and voided orders
        final status = order.orderStatus?.toUpperCase() ?? '';
        if (status == 'FULLY_REFUNDED' || status == 'VOIDED') return false;

        return order.orderAt!.isAfter(start) &&
            order.orderAt!.isBefore(end);
      }).toList();

      final discountedOrders = rangeOrders.where((order) {
        return (order.Discount ?? 0) > 0;
      }).toList();

      // Sort by date descending (newest first)
      discountedOrders.sort((a, b) => b.orderAt!.compareTo(a.orderAt!));

      double totalDiscount = 0.0;
      for (var order in discountedOrders) {
        totalDiscount += (order.Discount ?? 0.0);
      }

      setState(() {
        _discountedOrders = discountedOrders;
        _totalDiscountAmount = totalDiscount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error loading discount data: $e");
    }
  }

  // Function to  pick "From Date"
  Future<void> _pickFromDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _fromDate??DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
        //   Ensure "To Date" is after "from Date"
        if(_toDate != null && _toDate!.isBefore(_fromDate!)){
          _toDate =null;
        }
      });
    }
  }
  // Function to  pick To Date"
  Future<void> _pickToDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _toDate?? _fromDate??DateTime.now(),
        firstDate: _fromDate?? DateTime(2000),
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
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.start,
                  ),
                  InkWell(
                    onTap: () {
                      _pickFromDate(context); // Fixed to use _pickFromDate
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                            border: Border.all(color: primarycolor),
                            // color: Colors.red,
                            borderRadius: BorderRadius.circular(5)
                        ),
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
                            Icon(Icons.date_range,color: primarycolor,)
                          ],
                        )),
                  ),

                  // Search Button Row
                  // Adjusted layout to be next to To Date or separate line?
                  // Original layout had search button below From Date which was weird.
                  // I'll put it in a nicer place, maybe after To Date.

                  SizedBox(height: 10,),
                  Text(
                    'To Date:',
                    textScaler: TextScaler.linear(1),

                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.start,
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: _fromDate ==null ? null: ()=> _pickToDate(context),

                        child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            width: width * 0.6,
                            height: height * 0.05,
                            decoration: BoxDecoration(
                                border: Border.all(color: primarycolor),
                                // color: Colors.red,
                                borderRadius: BorderRadius.circular(5)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _toDate == null
                                      ? ' DD/MM/YYYY'
                                      : '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Icon(Icons.date_range,color: primarycolor,)
                              ],
                            )),
                      ),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: _loadData,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: primarycolor,
                              borderRadius: BorderRadius.circular(50)
                          ),
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
                  onTap: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Export coming soon")));
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        color: Colors.white,
                      ),
                      Text(
                        'Export To Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),

              SizedBox(
                height: 25,
              ),

              Text(
                " Total Discount Amount (${CurrencyHelper.currentSymbol}) = ${DecimalSettings.formatAmount(_totalDiscountAmount)} ",
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              Text(
                " Total Discount Order Count = ${_discountedOrders.length} ",
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),

              SizedBox(
                height: 25,
              ),

              _isLoading 
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                    headingRowHeight: 50,
                    columnSpacing: 20,
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
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('Date',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),),
                              ))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text(
                                "Order ID",textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,
                              ))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Customer Name',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Payment Method',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Order Type',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Discount',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Total Amount(${CurrencyHelper.currentSymbol})',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                    ],
                    rows: _discountedOrders.map((order) {
                            return DataRow(cells: [
                              DataCell(Text(
                                order.orderAt != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(order.orderAt!)
                                    : '-',
                                style: GoogleFonts.poppins(fontSize: 13),
                              )),
                              DataCell(Center(
                                child: Text(
                                  order.billNumber != null
                                      ? order.billNumber.toString()
                                      : order.id.substring(0, 8),
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              )),
                              DataCell(Center(
                                child: Text(
                                  order.customerName,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              )),
                              DataCell(Center(
                                child: Text(
                                  order.paymentmode ?? '-',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              )),
                              DataCell(Center(
                                child: Text(
                                  order.orderType ?? '-',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              )),
                              DataCell(Center(
                                child: Text(
                                  DecimalSettings.formatAmount(
                                      order.Discount ?? 0.0),
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: Colors.green),
                                ),
                              )),
                              DataCell(Center(
                                child: Text(
                                  DecimalSettings.formatAmount(
                                      order.totalPrice),
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              )),
                            ]);
                          }).toList()),
              )
            ],
          ),
        ),
      ),
    );
  }
}
