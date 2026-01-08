import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_eod.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/util/restaurant/decimal_settings.dart';
import 'package:unipos/util/restaurant/currency_helper.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';

class DayWisebyDaily extends StatefulWidget {
  const DayWisebyDaily({super.key});

  @override
  State<DayWisebyDaily> createState() => _DayWisebyDailyState();
}

class _DayWisebyDailyState extends State<DayWisebyDaily> {
  DateTime? _fromDate;
  EndOfDayReport? _report;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (_fromDate == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final report = await HiveEOD.getEODByDate(_fromDate!);
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading EOD report: $e');
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _fromDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
      });
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
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Date:',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  InkWell(
                    onTap: () => _pickDate(context),
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
                  SizedBox(width: 10),
                  InkWell(
                    onTap: _loadReport,
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
              if (_report != null) ...[
                Text(
                  'Total Sales : ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_report!.totalSales)}',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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
                      'No Data Available for Selected Date',
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
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Numbers Of Orders',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total Amount(${CurrencyHelper.currentSymbol})',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._report!.orderSummaries.map((order) {
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
                    order.orderType,
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${order.orderCount}',
                    textScaler: TextScaler.linear(1),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DecimalSettings.formatAmount(order.totalAmount),
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
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Total Amount(${CurrencyHelper.currentSymbol})',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._report!.paymentSummaries.map((payment) {
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
                    payment.paymentType,
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    DecimalSettings.formatAmount(payment.totalAmount),
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
                '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_report!.totalExpenses)}',
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
                    'Opening Balance:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  Text(
                    '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_report!.openingBalance)}',
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
                    'Total Sales:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  Text(
                    '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_report!.totalSales)}',
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
                    'Expenses:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.red[700]),
                  ),
                  Text(
                    '- ${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_report!.totalExpenses)}',
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
                    'Closing Balance:',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${CurrencyHelper.currentSymbol} ${DecimalSettings.formatAmount(_report!.closingBalance)}',
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