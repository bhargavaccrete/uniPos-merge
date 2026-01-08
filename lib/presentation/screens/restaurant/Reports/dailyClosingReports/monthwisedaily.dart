import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_eod.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/util/restaurant/decimal_settings.dart';
import 'package:unipos/util/restaurant/currency_helper.dart';

import '../../../../widget/componets/restaurant/componets/Button.dart';

class MonthWisebyDaily extends StatefulWidget {
  const MonthWisebyDaily({super.key});

  @override
  State<MonthWisebyDaily> createState() => _MonthWisebyDailyState();
}

class _MonthWisebyDailyState extends State<MonthWisebyDaily> {
  List<String> monthitem = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  List<int> yearitem = [
    2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016
  ];

  String dropDownValue1 = 'January';
  int dropdownvalue2 = 2025;
  bool _isLoading = false;
  List<EndOfDayReport> _reports = [];

  Map<String, double> _orderTypeTotals = {};
  Map<String, int> _orderTypeCounts = {};
  Map<String, double> _paymentTypeTotals = {};
  double _totalExpenses = 0.0;
  double _totalSales = 0.0;
  double _totalOpeningBalance = 0.0;
  double _totalClosingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dropDownValue1 = monthitem[now.month - 1];
    dropdownvalue2 = now.year;
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final monthIndex = monthitem.indexOf(dropDownValue1) + 1;
      final year = dropdownvalue2;

      // Get all EOD reports
      final allReports = await HiveEOD.getAllEODReports();

      // Filter reports for selected month and year
      final monthReports = allReports.where((report) {
        return report.date.year == year && report.date.month == monthIndex;
      }).toList();

      // Aggregate data
      _aggregateReports(monthReports);

      setState(() {
        _reports = monthReports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading month data: $e');
    }
  }

  void _aggregateReports(List<EndOfDayReport> reports) {
    _orderTypeTotals.clear();
    _orderTypeCounts.clear();
    _paymentTypeTotals.clear();
    _totalExpenses = 0.0;
    _totalSales = 0.0;
    _totalOpeningBalance = 0.0;
    _totalClosingBalance = 0.0;

    for (final report in reports) {
      // Aggregate order types
      for (final order in report.orderSummaries) {
        _orderTypeTotals[order.orderType] =
            (_orderTypeTotals[order.orderType] ?? 0.0) + order.totalAmount;
        _orderTypeCounts[order.orderType] =
            (_orderTypeCounts[order.orderType] ?? 0) + order.orderCount;
      }

      // Aggregate payment types
      for (final payment in report.paymentSummaries) {
        _paymentTypeTotals[payment.paymentType] =
            (_paymentTypeTotals[payment.paymentType] ?? 0.0) + payment.totalAmount;
      }

      // Sum expenses and sales
      _totalExpenses += report.totalExpenses;
      _totalSales += report.totalSales;
      _totalOpeningBalance += report.openingBalance;
      _totalClosingBalance += report.closingBalance;
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
              SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Month',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5),
                        Container(
                          width: width * 0.4,
                          height: height * 0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: primarycolor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              value: dropDownValue1,
                              isExpanded: true,
                              items: monthitem.map((String items) {
                                return DropdownMenuItem(
                                  value: items,
                                  child: Text(
                                    items,
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  dropDownValue1 = newValue!;
                                });
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Year',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5),
                        Container(
                          width: width * 0.4,
                          height: height * 0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: primarycolor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              value: dropdownvalue2,
                              isExpanded: true,
                              items: yearitem.map((int items) {
                                return DropdownMenuItem(
                                  value: items,
                                  child: Text(
                                    items.toString(),
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  dropdownvalue2 = newValue!;
                                });
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 20, width: 20),
                  InkWell(
                    onTap: _loadMonthData,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: primarycolor,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.search,
                        size: 25,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(height: 20),
              CommonButton(
                width: width * 0.6,
                height: height * 0.06,
                bordercircular: 5,
                onTap: () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_add_outlined, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Export To Excel',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 25),
              if (_reports.isNotEmpty) ...[
                Text(
                  'Total Sales: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalSales)}',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Reports Found: ${_reports.length} day(s)',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 20),
                _buildOrderTable(width),
                SizedBox(height: 30),
                _buildPaymentTable(width),
                SizedBox(height: 30),
                _buildExpenseSection(width),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No Data Available for Selected Month',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTable(double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Summary',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 10),
        Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(5),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Type Of Order',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total Orders',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Amount(${CurrencyHelper.currentSymbol})',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        ..._orderTypeTotals.entries.map((entry) {
          return Container(
            width: width,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.key,
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${_orderTypeCounts[entry.key] ?? 0}',
                    textScaler: TextScaler.linear(1),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DecimalSettings.formatAmount(entry.value),
                    textScaler: TextScaler.linear(1),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPaymentTable(double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Summary',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 10),
        Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(5),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  'Type Of Payment',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Amount(${CurrencyHelper.currentSymbol})',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        ..._paymentTypeTotals.entries.map((entry) {
          return Container(
            width: width,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    entry.key,
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    DecimalSettings.formatAmount(entry.value),
                    textScaler: TextScaler.linear(1),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildExpenseSection(double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.orange[300]!),
          ),
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Expenses',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[800],
                ),
              ),
              Text(
                '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_totalExpenses)}',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15),
        Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.blue[200]!),
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Sales:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  Text(
                    '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_totalSales)}',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Expenses:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.red[700]),
                  ),
                  Text(
                    '- ${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_totalExpenses)}',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.red[700]),
                  ),
                ],
              ),
              Divider(thickness: 1, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Amount:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_totalSales - _totalExpenses)}',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[800]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}