import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/currency_helper.dart';
import 'package:unipos/util/restaurant/decimal_settings.dart';

import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';

class TodayByDiscount extends StatefulWidget {
  const TodayByDiscount({super.key});

  @override
  State<TodayByDiscount> createState() => _TodayByDiscountState();
}

class _TodayByDiscountState extends State<TodayByDiscount> {
  List<pastOrderModel> _discountedOrders = [];
  double _totalDiscountAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final box = Hive.box<pastOrderModel>(HiveBoxNames.restaurantPastOrders);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(Duration(days: 1));

      final allOrders = box.values.toList();
      final todayOrders = allOrders.where((order) {
        if (order.orderAt == null) return false;
        // Exclude refunded and voided orders
        final status = order.orderStatus?.toUpperCase() ?? '';
        if (status == 'FULLY_REFUNDED' || status == 'VOIDED') return false;

        return order.orderAt!.isAfter(todayStart) &&
            order.orderAt!.isBefore(todayEnd);
      }).toList();

      final discountedOrders = todayOrders.where((order) {
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
      // Handle error if needed
      print("Error loading discount data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            )
                          ],
                        )),

                    SizedBox(
                      height: 25,
                    ),

                    Text(
                      " Total Discount Amount Today(${CurrencyHelper.currentSymbol}) = ${DecimalSettings.formatAmount(_totalDiscountAmount)} ",
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 25),
                    Text(
                      " Total Discount Order Count = ${_discountedOrders.length} ",
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
                            // Removed Mobile No column as it's not in the model
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
                            // Removed Coupon Code as it's not in the model
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
