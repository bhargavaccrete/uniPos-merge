/*
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class TodayByComparison extends StatefulWidget {
  const TodayByComparison({super.key});

  @override
  State<TodayByComparison> createState() => _TodayByComparisonState();
}

class _TodayByComparisonState extends State<TodayByComparison> {
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

    // Today
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(Duration(days: 1));

    // Yesterday
    final yesterdayStart = todayStart.subtract(Duration(days: 1));
    final yesterdayEnd = todayStart;

    // Maps to store quantities per item
    Map<String, int> todayQuantities = {};
    Map<String, int> yesterdayQuantities = {};

    for (final order in allOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      // Check if today
      if (order.orderAt!.isAfter(todayStart) && order.orderAt!.isBefore(todayEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            todayQuantities[item.title] = (todayQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
      // Check if yesterday
      else if (order.orderAt!.isAfter(yesterdayStart) && order.orderAt!.isBefore(yesterdayEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            yesterdayQuantities[item.title] = (yesterdayQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
    }

    // Combine all unique products
    final allProducts = {...todayQuantities.keys, ...yesterdayQuantities.keys};

    // Build comparison list
    final List<ProductComparisonData> comparisonList = [];
    for (final productName in allProducts) {
      final todayQty = todayQuantities[productName] ?? 0;
      final yesterdayQty = yesterdayQuantities[productName] ?? 0;
      final difference = todayQty - yesterdayQty;

      comparisonList.add(ProductComparisonData(
        productName: productName,
        previousPeriodQty: yesterdayQty,
        currentPeriodQty: todayQty,
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
                  onTap: () {},
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

              SizedBox(height: 25),

              if (productComparisons.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      'No data available for comparison',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                  ),
                ),

              if (productComparisons.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                      headingRowHeight: 50,
                      columnSpacing: 2,
                      headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                      border: TableBorder.all(color: Colors.white),
                      columns: [
                        DataColumn(
                            columnWidth: FixedColumnWidth(width * 0.3),
                            label: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(50),
                                    bottomLeft: Radius.circular(50),
                                  ),
                                ),
                                child: Text('Item Name',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14)))),
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
                                child: Text("Previous Day \nQuantity",
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
                                child: Text('Current Day \nQuantity',
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
                                child: Text('Difference',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    textAlign: TextAlign.center))),
                      ],
                      rows: productComparisons.map((data) {
                        Color differenceColor = data.difference > 0
                            ? Colors.green
                            : data.difference < 0
                                ? Colors.red
                                : Colors.grey;
                        String differenceText = data.difference > 0
                            ? '+${data.difference}'
                            : '${data.difference}';

                        return DataRow(cells: [
                          DataCell(Text(data.productName,
                              textScaler: TextScaler.linear(1))),
                          DataCell(Center(
                              child: Text('${data.previousPeriodQty}',
                                  textScaler: TextScaler.linear(1)))),
                          DataCell(Center(
                              child: Text('${data.currentPeriodQty}',
                                  textScaler: TextScaler.linear(1)))),
                          DataCell(Center(
                              child: Text(differenceText,
                                  textScaler: TextScaler.linear(1),
                                  style: TextStyle(
                                      color: differenceColor,
                                      fontWeight: FontWeight.bold)))),
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
