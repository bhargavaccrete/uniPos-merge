import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';

class CustomeDaily extends StatefulWidget {
  const CustomeDaily({super.key});

  @override
  State<CustomeDaily> createState() => _CustomeDailyState();
}

class _CustomeDailyState extends State<CustomeDaily> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = false;
  List<EndOfDayReport> _reports = [];

  Map<String, double> _orderTypeTotals = {};
  Map<String, int> _orderTypeCounts = {};
  Map<String, double> _paymentTypeTotals = {};
  double _totalExpenses = 0.0;
  double _totalSales = 0.0;
  double _totalOpeningBalance = 0.0;
  double _totalClosingBalance = 0.0;

  Future<void> _pickFromDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _fromDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
        // Ensure "To Date" is after "From Date"
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = null;
        }
      });
    }
  }

  Future<void> _pickToDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _toDate ?? _fromDate ?? DateTime.now(),
        firstDate: _fromDate ?? DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _toDate = pickedDate;
      });
    }
  }

  Future<void> _loadCustomData() async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both From and To dates')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all EOD reports
      final allReports = eodStore.reports.toList();

      // Filter reports for date range
      final rangeReports = allReports.where((report) {
        final reportDate = DateTime(
          report.date.year,
          report.date.month,
          report.date.day,
        );
        final fromDate = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
        );
        final toDate = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
        );

        return (reportDate.isAfter(fromDate) || reportDate.isAtSameMomentAs(fromDate)) &&
            (reportDate.isBefore(toDate) || reportDate.isAtSameMomentAs(toDate));
      }).toList();

      // Aggregate data
      _aggregateReports(rangeReports);

      setState(() {
        _reports = rangeReports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading custom range data: $e');
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From Date:',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        InkWell(
                          onTap: () => _pickFromDate(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            width: width * 0.6,
                            height: height * 0.05,
                            decoration: BoxDecoration(
                              border: Border.all(color: primarycolor),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fromDate == null
                                      ? 'DD/MM/YYYY'
                                      : '${_fromDate!.day.toString().padLeft(2, '0')}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.year}',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Icon(Icons.date_range, color: primarycolor)
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 25),
                        Text(
                          'To Date:',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        InkWell(
                          onTap: _fromDate == null
                              ? null
                              : () => _pickToDate(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            width: width * 0.6,
                            height: height * 0.05,
                            decoration: BoxDecoration(
                              border: Border.all(color: primarycolor),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _toDate == null
                                      ? 'DD/MM/YYYY'
                                      : '${_toDate!.day.toString().padLeft(2, '0')}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.year}',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Icon(Icons.date_range, color: primarycolor)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    Row(
                      children: [
                        InkWell(
                          onTap: _loadCustomData,
                          child: Container(
                            padding: EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: primarycolor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        CommonButton(
                          width: width * 0.5,
                          height: height * 0.07,
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
                      ],
                    ),
                    SizedBox(height: 25),
                    if (_reports.isNotEmpty) ...[
                      Text(
                        'Total Sales: Rs. ${_totalSales.toStringAsFixed(1)}',
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
                    ] else if (_fromDate != null && _toDate != null) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No Data Available for Selected Date Range',
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
                  'Amount(Rs.)',
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
                    entry.value.toStringAsFixed(1),
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
                  'Amount(Rs.)',
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
                    entry.value.toStringAsFixed(1),
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
                'Rs. ${_totalExpenses.toStringAsFixed(2)}',
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
                    'Rs. ${_totalSales.toStringAsFixed(2)}',
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
                    '- Rs. ${_totalExpenses.toStringAsFixed(2)}',
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
                    'Rs. ${(_totalSales - _totalExpenses).toStringAsFixed(2)}',
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