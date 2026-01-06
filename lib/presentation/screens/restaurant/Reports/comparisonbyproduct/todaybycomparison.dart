import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class TodayByComparison extends StatefulWidget {
  const TodayByComparison({super.key});

  @override
  State<TodayByComparison> createState() => _TodayByComparisonState();
}

class _TodayByComparisonState extends State<TodayByComparison> {
  bool _isLoading = true;
  List<ProductComparisonData> _productComparisons = [];

  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  Future<void> _loadComparisonData() async {
    setState(() => _isLoading = true);

    try {
      final orderBox = Hive.box<pastOrderModel>('pastorderBox');
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

      for (final order in orderBox.values) {
        if (order.orderStatus == 'FULLY_REFUNDED') continue;
        if (order.orderAt == null) continue;

        // Check if today
        if (order.orderAt!.isAfter(todayStart) && order.orderAt!.isBefore(todayEnd)) {
          for (final item in order.items) {
            todayQuantities[item.title] = (todayQuantities[item.title] ?? 0) + item.quantity.toInt();
          }
        }
        // Check if yesterday
        else if (order.orderAt!.isAfter(yesterdayStart) && order.orderAt!.isBefore(yesterdayEnd)) {
          for (final item in order.items) {
            yesterdayQuantities[item.title] = (yesterdayQuantities[item.title] ?? 0) + item.quantity.toInt();
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

      setState(() {
        _productComparisons = comparisonList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comparison: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
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

              if (_productComparisons.isEmpty)
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

              if (_productComparisons.isNotEmpty)
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
                      rows: _productComparisons.map((data) {
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