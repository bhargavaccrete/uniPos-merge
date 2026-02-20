/*
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';

class WeekByDiscount extends StatefulWidget {
  const WeekByDiscount({super.key});

  @override
  State<WeekByDiscount> createState() => _WeekByDiscountState();
}

class _WeekByDiscountState extends State<WeekByDiscount> {
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
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();
    final now = DateTime.now();

    // Calculate start of the week (assuming Monday is start)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeekMidnight = startOfWeekMidnight.add(Duration(days: 7));

    final weekOrders = allOrders.where((order) {
      if (order.orderAt == null) return false;
      // Exclude refunded and voided orders
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status == 'FULLY_REFUNDED' || status == 'VOIDED') return false;

      return order.orderAt!.isAfter(startOfWeekMidnight) &&
          order.orderAt!.isBefore(endOfWeekMidnight);
    }).toList();

    final discountedOrders = weekOrders.where((order) {
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
      'Report Date': ReportExportService.formatDate(DateTime.now()),
      'Total Orders': orders.length.toString(),
      'Total Amount': ReportExportService.formatCurrency(totalAmount),
      'Total Discount': ReportExportService.formatCurrency(totalDiscount),
      'Final Amount': ReportExportService.formatCurrency(finalAmount),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'discount_orders_week_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Discount Orders Report - This Week',
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            )
                          ],
                        )),
                    SizedBox(
                      height: 25,
                    ),

                    Text(
                      " Total Discount Amount Week (${CurrencyHelper.currentSymbol}) = ${DecimalSettings.formatAmount(totalDiscountAmount)} ",
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 25),
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
                          headingRowColor:
                              WidgetStateProperty.all(Colors.grey[300]),
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
