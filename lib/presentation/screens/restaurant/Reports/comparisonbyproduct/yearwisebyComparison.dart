import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';

class YearWisebyComparison extends StatefulWidget {
  const YearWisebyComparison({super.key});

  @override
  State<YearWisebyComparison> createState() => _YearWisebyComparisonState();
}

class _YearWisebyComparisonState extends State<YearWisebyComparison> {
  List<dynamic> yearitem = [2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016];
  dynamic dropdownvalue2 = 2026;

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

    // Current year (selected year)
    final currentYear = dropdownvalue2 as int;
    final currentYearStart = DateTime(currentYear, 1, 1);
    final currentYearEnd = DateTime(currentYear + 1, 1, 1);

    // Previous year
    final previousYear = currentYear - 1;
    final previousYearStart = DateTime(previousYear, 1, 1);
    final previousYearEnd = DateTime(previousYear + 1, 1, 1);

    // Maps to store quantities per item
    Map<String, int> currentYearQuantities = {};
    Map<String, int> previousYearQuantities = {};

    for (final order in allOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      // Check if current year
      if (order.orderAt!.isAfter(currentYearStart.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(currentYearEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            currentYearQuantities[item.title] = (currentYearQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
      // Check if previous year
      else if (order.orderAt!.isAfter(previousYearStart.subtract(Duration(seconds: 1))) &&
          order.orderAt!.isBefore(previousYearEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            previousYearQuantities[item.title] = (previousYearQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
    }

    // Combine all unique products
    final allProducts = {...currentYearQuantities.keys, ...previousYearQuantities.keys};

    // Build comparison list
    final List<ProductComparisonData> comparisonList = [];
    for (final productName in allProducts) {
      final currentQty = currentYearQuantities[productName] ?? 0;
      final previousQty = previousYearQuantities[productName] ?? 0;
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
              // Year selector
              Row(
                children: [
                  Text(
                    'Select Year:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButton(
                      value: dropdownvalue2,
                      underline: Container(),
                      icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      items: yearitem.map((items) {
                        return DropdownMenuItem(value: items, child: Text('$items'));
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          dropdownvalue2 = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),

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
                          columnWidth: FixedColumnWidth(width * 0.3),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),
                              child: Text(
                                'Item Name',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
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
                              child: Text(
                                "${dropdownvalue2 - 1} Year\nQuantity",
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,
                              ))),
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
                              child: Text(
                                '$dropdownvalue2 Year\n Quantity',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,
                              )))
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
                                  Center(
                                      child: Text(data.productName,
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(fontSize: 14))),
                                ),
                                DataCell(
                                  Center(
                                      child: Text('${data.previousPeriodQty}',
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(fontSize: 14))),
                                ),
                                DataCell(
                                  Center(
                                      child: Text('${data.currentPeriodQty}',
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(fontSize: 14))),
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