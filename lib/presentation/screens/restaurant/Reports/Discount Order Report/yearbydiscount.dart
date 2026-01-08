import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/currency_helper.dart';
import 'package:unipos/util/restaurant/decimal_settings.dart';

import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';

class YearWisebyDiscount extends StatefulWidget {
  const YearWisebyDiscount({super.key});

  @override
  State<YearWisebyDiscount> createState() => _YearWisebyDiscountState();
}

class _YearWisebyDiscountState extends State<YearWisebyDiscount> {
  List<int> yearitem = [
    2026,
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
  int dropdownvalue2 = 2026;

  List<pastOrderModel> _discountedOrders = [];
  double _totalDiscountAmount = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dropdownvalue2 = now.year;
    if (!yearitem.contains(dropdownvalue2)) {
      yearitem.insert(0, dropdownvalue2);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final box = Hive.box<pastOrderModel>(HiveBoxNames.restaurantPastOrders);
      
      int year = dropdownvalue2;
      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(year + 1, 1, 1);

      final allOrders = box.values.toList();
      final yearOrders = allOrders.where((order) {
        if (order.orderAt == null) return false;
        // Exclude refunded and voided orders
        final status = order.orderStatus?.toUpperCase() ?? '';
        if (status == 'FULLY_REFUNDED' || status == 'VOIDED') return false;

        return order.orderAt!.isAfter(startOfYear.subtract(Duration(seconds: 1))) &&
            order.orderAt!.isBefore(endOfYear);
      }).toList();

      final discountedOrders = yearOrders.where((order) {
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
                          items: yearitem.map((
                              int items,
                              ) {
                            return DropdownMenuItem(
                                value: items,
                                child: Text(
                                  items.toString(),
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ));
                          }).toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              dropdownvalue2 = newValue!;
                            });
                          }),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: _loadData,
                    child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: primarycolor, shape: BoxShape.circle),
                        child: Icon(
                          Icons.search,
                          size: 25,
                          color: Colors.white,
                        )),
                  ),
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
                                child: Text(
                                  'Date',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
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
                                "Order ID",
                                textScaler: TextScaler.linear(1),
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
                              child: Text('Customer Name',
                                  textScaler: TextScaler.linear(1),
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
                              child: Text('Payment Method',
                                  textScaler: TextScaler.linear(1),
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
                              child: Text('Order Type',
                                  textScaler: TextScaler.linear(1),
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
                              child: Text('Discount',
                                  textScaler: TextScaler.linear(1),
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
                              child: Text('Total Amount(${CurrencyHelper.currentSymbol})',
                                  textScaler: TextScaler.linear(1),
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
