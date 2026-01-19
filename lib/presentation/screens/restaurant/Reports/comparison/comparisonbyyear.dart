import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class ComparisonByYear extends StatefulWidget {
  const ComparisonByYear({super.key});

  @override
  State<ComparisonByYear> createState() => _ComparisonByYearState();
}

class _ComparisonByYearState extends State<ComparisonByYear> {
  bool _isLoading = true;
  ComparisonData? _data;

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

      // Current year start
      final currentYearStart = DateTime(now.year, 1, 1);

      // Previous year start and end
      final previousYearStart = DateTime(now.year - 1, 1, 1);
      final previousYearEnd = currentYearStart.subtract(Duration(seconds: 1));

      int currentOrders = 0;
      double currentAmount = 0.0;
      int previousOrders = 0;
      double previousAmount = 0.0;

      for (final order in orderBox.values) {
        if (order.orderStatus == 'FULLY_REFUNDED') continue;
        if (order.orderAt == null) continue;

        final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);

        // Current year
        if (order.orderAt!.isAfter(currentYearStart) ||
            order.orderAt!.isAtSameMomentAs(currentYearStart)) {
          currentOrders++;
          currentAmount += netAmount;
        }
        // Previous year
        else if (order.orderAt!.isAfter(previousYearStart) &&
            order.orderAt!.isBefore(previousYearEnd)) {
          previousOrders++;
          previousAmount += netAmount;
        }
      }

      setState(() {
        _data = ComparisonData(
          currentPeriod: now.year.toString(),
          previousPeriod: (now.year - 1).toString(),
          currentOrders: currentOrders,
          currentAmount: currentAmount,
          previousOrders: previousOrders,
          previousAmount: previousAmount,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comparison data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comparison By Year',
          textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Comparison',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Comparison of Current Year with Previous Year',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w400, fontSize: 14),
                      textAlign: TextAlign.start,
                    ),
                    SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_data?.currentPeriod ?? ""} vs ${_data?.previousPeriod ?? ""}',
                            textScaler: TextScaler.linear(1),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: Colors.grey.shade700),
                          ),
                        ),
                        IconButton(
                          onPressed: _loadComparisonData,
                          icon: Icon(Icons.refresh, color: AppColors.primary),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    CommonButton(
                        width: width * 0.6,
                        height: height * 0.06,
                        bordercircular: 5,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Export feature coming soon')),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Export TO Excel',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            )
                          ],
                        )),

                    SizedBox(height: 25),

                    if (_data == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Text(
                            'No data available',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                              headingRowHeight: 50,
                              columnSpacing: 20,
                              headingRowColor:
                                  WidgetStateProperty.all(Colors.grey[300]),
                              border: TableBorder.all(color: Colors.white),
                              decoration: BoxDecoration(),
                              columns: [
                                DataColumn(
                                    columnWidth: FixedColumnWidth(width * 0.35),
                                    label: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(50),
                                            bottomLeft: Radius.circular(50),
                                          ),
                                        ),
                                        child: Text(
                                          'Details',
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ))),
                                DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    columnWidth: FixedColumnWidth(width * 0.3),
                                    label: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          "${_data!.previousPeriod}",
                                          textAlign: TextAlign.center,
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ))),
                                DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    columnWidth: FixedColumnWidth(width * 0.3),
                                    label: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          '${_data!.currentPeriod}',
                                          textAlign: TextAlign.center,
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        )))
                              ],
                              rows: [
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'Total Orders',
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                          child: Text(
                                        _data!.previousOrders.toString(),
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                      )),
                                    ),
                                    DataCell(
                                      Center(
                                          child: Text(
                                        _data!.currentOrders.toString(),
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary),
                                      )),
                                    ),
                                  ],
                                ),
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'Total Amount (${CurrencyHelper.currentSymbol})',
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                          child: Text(
                                        DecimalSettings.formatAmount(_data!.previousAmount),
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                      )),
                                    ),
                                    DataCell(
                                      Center(
                                          child: Text(
                                        DecimalSettings.formatAmount(_data!.currentAmount),
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700),
                                      )),
                                    ),
                                  ],
                                ),
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'Growth %',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    DataCell(
                                      Center(child: Text('-')),
                                    ),
                                    DataCell(
                                      Center(
                                          child: Text(
                                        _calculateGrowth(
                                            _data!.previousAmount,
                                            _data!.currentAmount),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _getGrowthColor(
                                              _data!.previousAmount,
                                              _data!.currentAmount),
                                        ),
                                      )),
                                    ),
                                  ],
                                ),
                              ]),
                        ),
                      )
                  ],
                ),
              ),
            ),
    );
  }

  String _calculateGrowth(double previous, double current) {
    if (previous == 0) {
      return current > 0 ? '+100%' : '0%';
    }
    final growth = ((current - previous) / previous) * 100;
    return '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%';
  }

  Color _getGrowthColor(double previous, double current) {
    if (current > previous) return Colors.green.shade700;
    if (current < previous) return Colors.red.shade700;
    return Colors.grey;
  }
}

class ComparisonData {
  final String currentPeriod;
  final String previousPeriod;
  final int currentOrders;
  final double currentAmount;
  final int previousOrders;
  final double previousAmount;

  ComparisonData({
    required this.currentPeriod,
    required this.previousPeriod,
    required this.currentOrders,
    required this.currentAmount,
    required this.previousOrders,
    required this.previousAmount,
  });
}