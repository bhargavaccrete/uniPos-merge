import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/orderDetails.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class TodayByRefund extends StatefulWidget {
  const TodayByRefund({super.key});

  @override
  State<TodayByRefund> createState() => _TodayByRefundState();
}

class _TodayByRefundState extends State<TodayByRefund> {
  @override
  void initState() {
    super.initState();
    _loadRefundedOrders();
  }

  Future<void> _loadRefundedOrders() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<pastOrderModel> _calculateRefundedOrders() {
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();
    final today = DateTime.now();

    final filteredOrders = allOrders.where((order) {
      if (order.refundedAt == null) return false;
      final refundDate = order.refundedAt!;
      return refundDate.year == today.year &&
          refundDate.month == today.month &&
          refundDate.day == today.day;
    }).toList();

    return filteredOrders;
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

          final refundedOrders = _calculateRefundedOrders();

          return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CommonButton
              CommonButton(
                  width:width * 0.5 ,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: (){},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined,color: Colors.white,),
                      Text('Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500),)
                    ],)),

              SizedBox(height: 25,),

              refundedOrders.isEmpty
                  ? Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No refunds found for today',
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
                              child: Text('Refund(${CurrencyHelper.currentSymbol})',
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
                    rows: refundedOrders.map((order) {
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
                              child: Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(order.refundAmount ?? 0.0)}',
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
      );
        },
      ),
    );
  }
}
