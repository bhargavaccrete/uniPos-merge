/*
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class ThisWeekbyComparison extends StatefulWidget {
  const ThisWeekbyComparison({super.key});

  @override
  State<ThisWeekbyComparison> createState() => _ThisWeekbyComparisonState();
}

class _ThisWeekbyComparisonState extends State<ThisWeekbyComparison> {
  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  Future<void> _loadComparisonData() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<ProductComparisonData> _calculateComparisonData() {
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();
    final now = DateTime.now();

    // Current week (Monday to now)
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStartDate = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
    final currentWeekEnd = currentWeekStartDate.add(Duration(days: 7));

    // Previous week
    final previousWeekStart = currentWeekStartDate.subtract(Duration(days: 7));
    final previousWeekEnd = currentWeekStartDate;

    // Maps to store quantities per item
    Map<String, int> currentWeekQuantities = {};
    Map<String, int> previousWeekQuantities = {};

    for (final order in allOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      // Check if current week
      if (order.orderAt!.isAfter(currentWeekStartDate.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(currentWeekEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            currentWeekQuantities[item.title] = (currentWeekQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
      // Check if previous week
      else if (order.orderAt!.isAfter(previousWeekStart.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(previousWeekEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            previousWeekQuantities[item.title] = (previousWeekQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
    }

    // Combine all unique products
    final allProducts = {...currentWeekQuantities.keys, ...previousWeekQuantities.keys};

    // Build comparison list
    final List<ProductComparisonData> comparisonList = [];
    for (final productName in allProducts) {
      final currentQty = currentWeekQuantities[productName] ?? 0;
      final previousQty = previousWeekQuantities[productName] ?? 0;
      final difference = currentQty - previousQty;

      comparisonList.add(ProductComparisonData(
        productName: productName,
        previousPeriodQty: previousQty,
        currentPeriodQty: currentQty,
        difference: difference,
      ));
    }

    // Sort by current period quantity (descending)
    comparisonList.sort((a, b) => b.currentPeriodQty.compareTo(a.currentPeriodQty));

    return comparisonList;
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

          final productComparisons = _calculateComparisonData();

          return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Text('Comparison of Current Week with Previous \n Week',
              //   textScaler: TextScaler.linear(1),
              //   style: GoogleFonts.poppins(fontWeight:FontWeight.w500,fontSize: 16),),
              // SizedBox(height: 10,),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {
                    Navigator.pop(context);
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
                          columnWidth:FixedColumnWidth(width *0.3),

                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),

                              child: Text('Item Name',textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth:FixedColumnWidth(width *0.4),

                          // columnWidth:FlexColumnWidth(width * 0.1),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text("Previous week\nQuantity",
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,

                          columnWidth:FixedColumnWidth(width *0.35),

                          label: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Current week\n Quantity',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center)))
                    ],

                    rows: productComparisons.isEmpty
                      ? [
                          DataRow(
                            cells: [
                              DataCell(Center(child: Text('No data available', textScaler: TextScaler.linear(1)))),
                              DataCell(Center(child: Text('-', textScaler: TextScaler.linear(1)))),
                              DataCell(Center(child: Text('-', textScaler: TextScaler.linear(1)))),
                            ],
                          ),
                        ]
                      : productComparisons.map((data) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Center(child: Text(data.productName, textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),)),
                              ),
                              DataCell(
                                Center(child: Text('${data.previousPeriodQty}', textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),)),
                              ),
                              DataCell(
                                Center(child: Text('${data.currentPeriodQty}', textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),)),
                              ),
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

class ProductComparisonData {
  final String productName;
  final int previousPeriodQty;
  final int currentPeriodQty;
  final int difference;

  ProductComparisonData({
    required this.productName,
    required this.previousPeriodQty,
    required this.currentPeriodQty,
    required this.difference,
  });
}
*/
