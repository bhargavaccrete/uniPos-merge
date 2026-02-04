/*
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class MonthWisebyComparison extends StatefulWidget {
  const MonthWisebyComparison({super.key});

  @override
  State<MonthWisebyComparison> createState() => _MonthWisebyComparisonState();
}

class _MonthWisebyComparisonState extends State<MonthWisebyComparison> {
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

    // Current month start
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 1);

    // Previous month
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final previousMonthEnd = currentMonthStart;

    // Maps to store quantities per item
    Map<String, int> currentMonthQuantities = {};
    Map<String, int> previousMonthQuantities = {};

    for (final order in allOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      // Check if current month
      if (order.orderAt!.isAfter(currentMonthStart.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(currentMonthEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            currentMonthQuantities[item.title] = (currentMonthQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
      // Check if previous month
      else if (order.orderAt!.isAfter(previousMonthStart.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(previousMonthEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            previousMonthQuantities[item.title] = (previousMonthQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
    }

    // Combine all unique products
    final allProducts = {...currentMonthQuantities.keys, ...previousMonthQuantities.keys};

    // Build comparison list
    final List<ProductComparisonData> comparisonList = [];
    for (final productName in allProducts) {
      final currentQty = currentMonthQuantities[productName] ?? 0;
      final previousQty = previousMonthQuantities[productName] ?? 0;
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
                    border: TableBorder.all(color: Colors.white),
                    decoration: BoxDecoration(),
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
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text("Previous Month\nQuantity",
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth:FixedColumnWidth(width *0.35),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Current Month\n Quantity',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center)))
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
}*/
