import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../../constants/restaurant/color.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';
class CustomByVoid extends StatefulWidget {
  const CustomByVoid({super.key});

  @override
  State<CustomByVoid> createState() => _CustomByVoidState();
}

class _CustomByVoidState extends State<CustomByVoid> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadVoidOrders();
  }

  Future<void> _loadVoidOrders() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<PastOrderModel> _calculateVoidOrders() {
    if (_fromDate == null || _toDate == null) {
      return [];
    }

    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();

    // Normalize dates
    final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);

    final voidOrdersList = allOrders.where((order) {
      // Check if order is voided/cancelled
      if (order.orderStatus == null) return false;
      if (!(order.orderStatus!.toUpperCase().contains('VOID') ||
           order.orderStatus!.toUpperCase().contains('CANCEL'))) {
        return false;
      }

      // Check Date Range
      if (order.orderAt == null) return false;
      return order.orderAt!.isAfter(start.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(end.add(Duration(seconds: 1)));
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

  Future<void> _pickFromDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _fromDate??DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
        // Ensure "To Date" is after "from Date"
        if(_toDate != null && _toDate!.isBefore(_fromDate!)){
          _toDate = null;
        }
      });
    }
  }

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

          final voidOrders = _calculateVoidOrders();
          final totals = _calculateTotals(voidOrders);
          final totalVoidAmount = totals['amount'] as double;
          final totalVoidCount = totals['count'] as int;

          return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
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
                      _pickFromDate(context);
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(5)
                        ),
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
                            Icon(Icons.date_range,color: AppColors.primary,)
                          ],
                        )),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          if (_fromDate == null || _toDate == null) {
                            NotificationService.instance.showError('Please select both From and To dates');
                            return;
                          }
                          setState(() {}); // Trigger rebuild to refresh data
                        },
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
                      ),
                    ],
                  ),
                  Text(
                    'To Date:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.start,
                  ),
                  InkWell(
                    onTap: _fromDate ==null ? null: ()=> _pickToDate(context),

                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(5)
                        ),
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
                            Icon(Icons.date_range,color: AppColors.primary,)
                          ],
                        )),
                  ),
                ],
              ),
              SizedBox(
                height: 25,
              ),
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
                        color: Colors.white),
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
                              child: Text('Details',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
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
                        DataCell(Center(child: Text('-', textScaler: TextScaler.linear(1)))),
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