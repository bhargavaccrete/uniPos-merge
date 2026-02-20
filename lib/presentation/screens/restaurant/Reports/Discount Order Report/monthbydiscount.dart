/*
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';

class MonthbyDiscount extends StatefulWidget {
  const MonthbyDiscount({super.key});

  @override
  State<MonthbyDiscount> createState() => _MonthbyDiscountState();
}

class _MonthbyDiscountState extends State<MonthbyDiscount> {
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
    'October',
    'November',
    'December',
  ];
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
  String dropDownValue1 = 'January';
  int dropdownvalue2 = 2026;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dropDownValue1 = monthitem[now.month - 1];
    dropdownvalue2 = now.year;
    if (!yearitem.contains(dropdownvalue2)) {
      yearitem.insert(0, dropdownvalue2);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<PastOrderModel> _calculateDiscountedOrders() {
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();

    int monthIndex = monthitem.indexOf(dropDownValue1) + 1;
    int year = dropdownvalue2;

    final startOfMonth = DateTime(year, monthIndex, 1);
    final endOfMonth = DateTime(year, monthIndex + 1, 1);

    final monthOrders = allOrders.where((order) {
      if (order.orderAt == null) return false;
      // Exclude refunded and voided orders
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status == 'FULLY_REFUNDED' || status == 'VOIDED') return false;

      return order.orderAt!.isAfter(startOfMonth.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(endOfMonth);
    }).toList();

    final discountedOrders = monthOrders.where((order) {
      return (order.Discount ?? 0) > 0;
    }).toList();

    // Sort by date descending (newest first)
    discountedOrders.sort((a, b) => b.orderAt!.compareTo(a.orderAt!));

    return discountedOrders;
  }

  double _calculateTotalDiscount(List<PastOrderModel> orders) {
    double totalDiscount = 0.0;
    for (var order in orders) {
      totalDiscount += (order.Discount ?? 0.0);
    }
    return totalDiscount;
  }

  Future<void> _exportReport(List<PastOrderModel> orders, double totalDiscount) async {
    final headers = [
      'Bill #',
      'Date & Time',
      'Customer',
      'Order Type',
      'Total Amount',
      'Discount',
      'Final Amount',
    ];

    final data = orders.map((order) {
      final netAmount = order.totalPrice - (order.Discount ?? 0);
      return [
        order.billNumber?.toString() ?? 'N/A',
        ReportExportService.formatDateTime(order.orderAt),
        order.customerName ?? 'Guest',
        order.orderType ?? 'N/A',
        ReportExportService.formatCurrency(order.totalPrice),
        ReportExportService.formatCurrency(order.Discount ?? 0),
        ReportExportService.formatCurrency(netAmount),
      ];
    }).toList();

    final totalAmount = orders.fold<double>(0, (sum, order) => sum + order.totalPrice);
    final finalAmount = totalAmount - totalDiscount;

    final summary = {
      'Report Period': '$dropDownValue1 $dropdownvalue2',
      'Total Orders': orders.length.toString(),
      'Total Amount': ReportExportService.formatCurrency(totalAmount),
      'Total Discount': ReportExportService.formatCurrency(totalDiscount),
      'Final Amount': ReportExportService.formatCurrency(finalAmount),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'discount_orders_month_${dropDownValue1.toLowerCase()}_$dropdownvalue2',
      reportTitle: 'Discount Orders Report - $dropDownValue1 $dropdownvalue2',
      headers: headers,
      data: data,
      summary: summary,
    );
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

          final discountedOrders = _calculateDiscountedOrders();
          final totalDiscountAmount = _calculateTotalDiscount(discountedOrders);

          return SingleChildScrollView(
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
                        Text(
                          'Select Month:',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: EdgeInsets.all(5),
                          width: width * 0.4,
                          height: height * 0.05,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppColors.primary)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                                value: dropDownValue1,
                                isExpanded: true,
                                items: monthitem.map((String items) {
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(
                                        items,
                                        textScaler: TextScaler.linear(1),
                                        style:
                                            GoogleFonts.poppins(fontSize: 14),
                                      ));
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    dropDownValue1 = newValue!;
                                  });
                                }),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Year:',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Container(
                          width: width * 0.4,
                          height: height * 0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(5)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                                value: dropdownvalue2,
                                isExpanded: true,
                                items: yearitem.map((int items) {
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(
                                        items.toString(),
                                        textScaler: TextScaler.linear(1),
                                        style:
                                            GoogleFonts.poppins(fontSize: 14),
                                      ));
                                }).toList(),
                                onChanged: (int? newValue) {
                                  setState(() {
                                    dropdownvalue2 = newValue!;
                                  });
                                }),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  InkWell(
                    onTap: () => setState(() {}), // Trigger rebuild to refresh data
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(50)),
                      child: Icon(
                        Icons.search,
                        size: 25,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(
                height: 25,
              ),
              CommonButton(
                  width: width * 0.5,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: () => _exportReport(discountedOrders, totalDiscountAmount),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        color: Colors.white,
                      ),
                      Text(
                        'Export Report',
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
                " Total Discount Amount (${CurrencyHelper.currentSymbol}) = ${DecimalSettings.formatAmount(totalDiscountAmount)} ",
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              Text(
                " Total Discount Order Count = ${discountedOrders.length} ",
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),

              SizedBox(
                height: 25,
              ),

              SingleChildScrollView(
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
                    rows: discountedOrders.map((order) {
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
      );
        },
      ),
    );
  }
}
*/
