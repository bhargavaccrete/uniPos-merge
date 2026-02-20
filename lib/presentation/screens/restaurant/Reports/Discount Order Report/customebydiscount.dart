/*
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

class CustomByDiscount extends StatefulWidget {
  const CustomByDiscount({super.key});

  @override
  State<CustomByDiscount> createState() => _CustomByDiscountState();
}

class _CustomByDiscountState extends State<CustomByDiscount> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<PastOrderModel> _calculateDiscountedOrders() {
    if (_fromDate == null || _toDate == null) {
      return [];
    }

    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();

    // Normalize dates to include full days
    final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(Duration(days: 1));

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

    String periodDisplay = 'Custom Period';
    if (_fromDate != null && _toDate != null) {
      periodDisplay = '${DateFormat('dd MMM yyyy').format(_fromDate!)} - ${DateFormat('dd MMM yyyy').format(_toDate!)}';
    }

    final summary = {
      'Report Period': periodDisplay,
      'Total Orders': orders.length.toString(),
      'Total Amount': ReportExportService.formatCurrency(totalAmount),
      'Total Discount': ReportExportService.formatCurrency(totalDiscount),
      'Final Amount': ReportExportService.formatCurrency(finalAmount),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'discount_orders_custom_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Discount Orders Report - $periodDisplay',
      headers: headers,
      data: data,
      summary: summary,
    );
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
                            border: Border.all(color: AppColors.primary),
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
                            Icon(Icons.date_range,color: AppColors.primary,)
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
                                border: Border.all(color: AppColors.primary),
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
                                Icon(Icons.date_range,color: AppColors.primary,)
                              ],
                            )),
                      ),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: () => setState(() {}), // Trigger rebuild to refresh data
                        child: Container(
                          padding: EdgeInsets.all(8),
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
