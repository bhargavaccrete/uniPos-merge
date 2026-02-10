import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../../constants/restaurant/color.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';

class MonthbyVoid extends StatefulWidget {
  const MonthbyVoid({super.key});

  @override
  State<MonthbyVoid> createState() => _MonthbyVoidState();
}

class _MonthbyVoidState extends State<MonthbyVoid> {
  List<String> monthitem =['January','February','March','April','May','June','July','August','September','Octomber','November','December',];
  List<int> yearitem = [];
  String dropDownValue1 = 'January';
  int dropdownvalue2 = 2025;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Generate years dynamically: Current year down to 20 years ago
    yearitem = List.generate(20, (index) => now.year - index);

    dropDownValue1 = monthitem[now.month - 1]; // 0-based index
    dropdownvalue2 = now.year;

    _loadVoidOrders();
  }

  Future<void> _loadVoidOrders() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<PastOrderModel> _calculateVoidOrders() {
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();
    final selectedMonthIndex = monthitem.indexOf(dropDownValue1) + 1;
    final selectedYear = dropdownvalue2;

    final voidOrdersList = allOrders.where((order) {
      // Check if order is voided/cancelled
      if (order.orderStatus == null) return false;
      if (!(order.orderStatus!.toUpperCase().contains('VOID') ||
           order.orderStatus!.toUpperCase().contains('CANCEL'))) {
        return false;
      }

      // Check Month and Year
      if (order.orderAt == null) return false;
      return order.orderAt!.month == selectedMonthIndex &&
          order.orderAt!.year == selectedYear;
    }).toList();

    return voidOrdersList;
  }

  Map<String, dynamic> _calculateTotals(List<PastOrderModel> voidOrders) {
    double totalAmount = 0.0;
    for (final order in voidOrders) {
      totalAmount += order.totalPrice;
    }
    return {
      'amount': totalAmount,
      'count': voidOrders.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: Observer(
        builder: (_) {
          if (pastOrderStore.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          final voidOrders = _calculateVoidOrders();
          final totals = _calculateTotals(voidOrders);
          final totalVoidAmount = totals['amount'] as double;
          final totalVoidCount = totals['count'] as int;

          return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
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
                        Text('Select Month:',                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500),),



                        Container(
                          padding: EdgeInsets.all(5),
                          width: width * 0.4,
                          height:  height * 0.05,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.primary)
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              value: dropDownValue1,
                                items: monthitem.map((String items){
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(items,textScaler: TextScaler.linear(1),
                                        style: GoogleFonts.poppins(fontSize: 14),));
                                }).toList(),
                                onChanged: (String? newValue){
                                  setState(() {
                                    dropDownValue1 = newValue!;

                                  });
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
                        Text('Select Year:',                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600,fontSize: 16 ),),

                        Container(
                          width:  width *0.4,
                          height: height *0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(5)
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              value: dropdownvalue2,
                                items: yearitem.map((dynamic items){
                              return DropdownMenuItem(
                                  value: items,
                                  child: Text(items.toString(),textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),) );
                            }).toList(),
                                onChanged: (dynamic? newValue){
                                setState(() {
                                  dropdownvalue2 = newValue!;
                                });
                                }),
                          ),
                        )

                      ],
                    ),
                  ),
                  SizedBox(width: 5,),
                  InkWell(
                    onTap: () => setState(() {}), // Trigger rebuild to refresh data
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(50)
                      ),
                      child: Icon(
                        Icons.search,
                        size: 25,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(height: 25,),
              CommonButton(
                  width:width * 0.5 ,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: (){},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined,color: Colors.white,),
                      Text('Export To Excel',                          textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500),)
                    ],)),

              SizedBox(height: 25,),

              // Total Amount
              Text(
                " Total Void Order Amount (${CurrencyHelper.currentSymbol}) = ${DecimalSettings.formatAmount(totalVoidAmount)} ",
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),

              // Total Count
              Text(
                " Total Void Order Count = $totalVoidCount ",
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 25),


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
                              child: Text('Date',textScaler: TextScaler.linear(1),
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
                              child: Text(
                                "Order ID",textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,
                              ))),
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
                              child: Text('Customer Name',textScaler: TextScaler.linear(1),
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
                              child: Text('Mobile No',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.35),
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
                          columnWidth: FixedColumnWidth(width * 0.3),
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
                          columnWidth: FixedColumnWidth(width * 0.4),
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
                              child:
                              Text('Status', textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center))),
                    ],
                    rows: voidOrders.map((order) {
                      return DataRow(cells: [
                        DataCell(Center(
                            child: Text(
                                order.orderAt != null
                                    ? DateFormat('dd-MM-yyyy').format(order.orderAt!)
                                    : '-',
                                textScaler: TextScaler.linear(1)))),
                        DataCell(Center(child: Text(order.id ?? '-', textScaler: TextScaler.linear(1)))),
                        DataCell(Center(
                            child: Text(order.customerName.isNotEmpty ? order.customerName : 'Guest', textScaler: TextScaler.linear(1)))),
                        DataCell(Center(child: Text('-', textScaler: TextScaler.linear(1)))),
                        DataCell(Center(child: Text(order.paymentmode ?? '-', textScaler: TextScaler.linear(1)))),
                        DataCell(Center(child: Text(order.orderType ?? '-', textScaler: TextScaler.linear(1)))),
                        DataCell(Center(
                            child: Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(order.totalPrice)}', textScaler: TextScaler.linear(1)))),
                        DataCell(Center(
                            child: Text(
                          order.orderStatus ?? '-',
                          textScaler: TextScaler.linear(1),
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ))),
                      ]);
                    }).toList()),
              )

            ],
          ),
        ),
      );
        },
      ),
    );
  }
}
