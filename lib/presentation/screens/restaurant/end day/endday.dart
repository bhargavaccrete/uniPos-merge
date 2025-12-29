import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_order.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/domain/services/restaurant/data_clear_service.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/domain/services/restaurant/eod_service.dart';
import 'package:unipos/presentation/screens/restaurant/welcome_Admin.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';

import '../../../../data/models/restaurant/db/database/hive_cart.dart';
import '../../../../data/models/restaurant/db/database/hive_pastorder.dart';

class EndDayDrawer extends StatefulWidget {
  const EndDayDrawer({super.key});

  @override
  State<EndDayDrawer> createState() => _EndDayDrawerState();
}

class _EndDayDrawerState extends State<EndDayDrawer> {
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _differenceController = TextEditingController();

  bool _isLoading = false;
  bool _isGenerating = false;
  EndOfDayReport? _currentReport;
  DateTime selectedDate = DateTime.now();
  double openingBalance = 0.0;
  double expectedCash = 0.0;
  double totalExpenses = 0.0;
  double cashExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadEODData();
  }

  Future<void> _loadEODData() async {
    setState(() => _isLoading = true);

    try {
      // Verify ALL required boxes are initialized before proceeding
      final requiredBoxes = {
        'eodBox': 'EOD reports',
        'dayManagementBox': 'day management',
        'pastorderBox': 'past orders',
        'expenseCategory': 'expense categories',
        'expenseBox': 'expenses',
      };

      final missingBoxes = <String>[];
      for (final entry in requiredBoxes.entries) {
        if (!Hive.isBoxOpen(entry.key)) {
          missingBoxes.add('${entry.value} (${entry.key})');
        }
      }

      if (missingBoxes.isNotEmpty) {
        throw Exception(
          'EOD system not fully initialized. Missing boxes:\n${missingBoxes.join('\n')}\n\n'
          'Please restart the app completely (stop and relaunch).'
        );
      }

      print('✅ All boxes reported as open, attempting to access data...');

      // Check if there are any past orders (transactions) to display
      print('📦 Fetching past orders...');
      final pastOrders = await HivePastOrder.getAllPastOrderModel();
      print('✅ Got ${pastOrders.length} past orders');

      // If there are no past orders, show empty state
      if (pastOrders.isEmpty) {
        setState(() {
          _currentReport = null;
          openingBalance = 0.0;
          expectedCash = 0.0;
          totalExpenses = 0.0;
          _isLoading = false;
        });
        return;
      }

      // 1) Get opening balance
      print('📊 Getting opening balance...');
      final currentOpeningBalance = await DayManagementService.getOpeningBalance();
      print('✅ Opening balance: $currentOpeningBalance');

      // 2) Always generate EOD from Past Orders for selectedDate
      print('📋 Generating EOD report...');
      final report = await EODService.generateEODReport(
        date: selectedDate,
        openingBalance: currentOpeningBalance,
        actualCash: 0.0,
      );
      print('✅ EOD report generated');

      // 3) Expected CASH only
      final expectedCashAmount = report.paymentSummaries
          .where((p) => (p.paymentType ?? '').toLowerCase().trim() == 'cash')
          .fold<double>(0.0, (sum, p) => sum + p.totalAmount);

      // 4) Decide whether there's anything to show
      final hasAnyData = (report.totalSales > 0) ||
          (report.totalOrderCount > 0) ||
          (report.totalDiscount > 0) ||
          (report.totalTax > 0) ||
          (report.totalExpenses > 0) ||
          (currentOpeningBalance > 0);

      setState(() {
        _currentReport = hasAnyData ? report : null;
        openingBalance = currentOpeningBalance;
        expectedCash = expectedCashAmount;
        totalExpenses = report.totalExpenses;
        cashExpenses = report.cashExpenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading EOD data: $e');
    }
  }


  void _calculateDifference() {
    if (_actualCashController.text.isNotEmpty) {
      final actual = double.tryParse(_actualCashController.text) ?? 0.0;
      // Expected total cash should include opening balance + cash sales - ONLY cash expenses
      // Non-cash expenses (Card/Online/Other) don't affect physical cash drawer
      final expectedTotalCash = openingBalance + expectedCash - cashExpenses;
      final difference = actual - expectedTotalCash;
      _differenceController.text = difference.toStringAsFixed(2);
    }
  }

  Future<void> _completeEndOfDay() async {
    if (_actualCashController.text.isEmpty) {
      _showError('Please enter actual cash amount');
      return;
    }

    // Check if there are any active orders remaining
    final activeOrders = await HiveOrders.getAllOrder();
    if (activeOrders.isNotEmpty) {
      // Show warning dialog asking user to clear active orders
      final shouldProceed = await _showActiveOrdersWarning(activeOrders.length);
      if (!shouldProceed) return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    // Save the actual cash amount before clearing
    final actualCashAmount = double.parse(_actualCashController.text);

    // Clear screen immediately and show loading
    setState(() {
      _isGenerating = true;
      _currentReport = null;  // Clear the report immediately
      _actualCashController.clear();
      _differenceController.clear();
    });

    try {

      // 1. Generate EOD report with current data
      final report = await EODService.generateEODReport(
        date: selectedDate,
        openingBalance: openingBalance,
        actualCash: actualCashAmount,
      );

      // 2. Save EOD report
      await EODService.saveEODReport(report);

      // 3. Clear all transactional data (orders, expenses, cart)
      // NOTE: This clears active orders and cart, but keeps past orders and expenses for reports
      await DataClearService.clearAllTransactionalData();

      // 4. DO NOT clear past orders - they are needed for reports
      // Past orders should remain for historical reporting
      // await DataClearService.clearCompletedOrders(); // REMOVED - Keep past orders for reports

      // 5. Mark day as completed
      await _markDayCompleted();

      // 6. Reset opening balance for next day
      await DayManagementService.resetDay();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('End of Day completed successfully!'), backgroundColor: Colors.green),
        );
      }

      // Navigate immediately to Welcome Admin screen without delay
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AdminWelcome()),
              (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      String errorMessage = 'Error completing End of Day';
      if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid cash amount format';
      } else if (e.toString().contains('adapter')) {
        errorMessage = 'Please restart the app to register new adapters';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      _showError(errorMessage);
    }
  }

  Future<bool> _showActiveOrdersWarning(int count) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Active Orders Found', style: GoogleFonts.poppins(fontSize: 18)),
            ],
          ),
          content: Text(
            'There are $count active order(s) remaining.\n\nThese orders should be completed, voided, or moved to past orders before ending the day.\n\nDo you want to clear them and proceed with End of Day?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Clear & Proceed', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm End of Day', style: GoogleFonts.poppins()),
          content: Text(
            'This will:\n\n• Save the End of Day report\n• Clear cart and active orders\n• Keep past orders for reports\n• Keep expenses for reports\n• Mark day as completed\n• Return to home screen\n\nContinue?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: primarycolor),
              child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _clearAllData() async {
    // Import the data clear service
    final pastOrders = await HivePastOrder.getAllPastOrderModel();
    for (final order in pastOrders) {
      await HivePastOrder.deleteOrder(order.id);
    }

    // Clear active orders
    final activeOrders = await HiveOrders.getAllOrder();
    for (final order in activeOrders) {
      await HiveOrders.deleteOrder(order.id);
    }

    // Clear cart
    await HiveCart.clearCart();
  }

  Future<void> _markDayCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_eod_date', DateTime.now().toIso8601String());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If generating EOD or no data to show
    if (_isGenerating || _currentReport == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          title: Text('End of Day Settlement', style: GoogleFonts.poppins()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating) ...[
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Processing End of Day...',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ] else ...[
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                SizedBox(height: 20),
                Text(
                  'No active transactions',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                Text(
                  'Start a new day to see EOD data',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_ios_new)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Icon(Icons.person_outline_outlined),
                Column(
                  children: [
                    Text(
                      'Admin',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    Text(
                      'Admin',
                      style:
                      GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(15),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'End of Day Settlement',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 25),
            Container(
              padding: EdgeInsets.all(10),
              width: width,
              height: height * 0.07,
              decoration:
              BoxDecoration(border: Border.all(color: primarycolor)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Opening Balance:',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          color: primarycolor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Rs. ${openingBalance.toStringAsFixed(2)}',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    )
                  ]),
            ),
            SizedBox(
              height: 25,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CommonButton(
                    bordercolor: Colors.teal.shade800,
                    bgcolor: Colors.teal.shade800,
                    bordercircular: 2,
                    width: width * 0.4,
                    height: height * 0.04,
                    onTap: () {},
                    child: Text(
                      'Print Summary',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16),
                    )),
                CommonButton(
                    bordercolor: Colors.teal.shade800,
                    bgcolor: Colors.teal.shade800,
                    bordercircular: 2,
                    width: width * 0.3,
                    height: height * 0.04,
                    onTap: ()=> _loadEODData,
                    child: Text(
                      'Refresh',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16),
                    )),
              ],
            ),
            SizedBox(height: 25),
            Text(
              'Order Type',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w500),
            ),
            // Dynamic Order Type Tiles
            if (_currentReport != null)
              ..._currentReport!.orderSummaries.map((orderSummary) {
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.symmetric(horizontal: 15),
                      childrenPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(orderSummary.orderType,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
                          Text('#${orderSummary.orderCount}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins()),
                          Text('Rs. ${orderSummary.totalAmount.toStringAsFixed(2)}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle, color: Colors.green, size: 12),
                                SizedBox(width: 10),
                                Text('Avg Order Value',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins()),
                              ],
                            ),
                            Text(
                              'Rs. ${orderSummary.averageOrderValue.toStringAsFixed(2)}',
                              textScaler: TextScaler.linear(1),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle, color: Colors.green, size: 12),
                                SizedBox(width: 10),
                                Text('Total Amount',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins()),
                              ],
                            ),
                            Text(
                              'Rs. ${orderSummary.totalAmount.toStringAsFixed(2)}',
                              textScaler: TextScaler.linear(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            SizedBox(height: 20),

            // TOTAL DISCOUNT SECTION
            Text(
              'Total Discount',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Container(
              height: height * 0.06,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              margin: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Discount Given',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  Text('Rs. ${_currentReport?.totalDiscount.toStringAsFixed(2) ?? '0.00'}',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.red)),
                ],
              ),
            ),

            SizedBox(height: 20),

            // TAX BREAKDOWN SECTION
            Text(
              'Tax Breakdown',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            if (_currentReport != null && _currentReport!.taxSummaries.isNotEmpty)
              ..._currentReport!.taxSummaries.map((tax) {
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.symmetric(horizontal: 15),
                      childrenPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tax.taxName,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                          Text('Rs. ${tax.taxAmount.toStringAsFixed(2)}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle, color: Colors.blue, size: 12),
                                SizedBox(width: 10),
                                Text('Taxable Amount',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins()),
                              ],
                            ),
                            Text(
                              'Rs. ${tax.taxableAmount.toStringAsFixed(2)}',
                              textScaler: TextScaler.linear(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            // Total Tax Summary
            Container(
              height: height * 0.06,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              margin: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL TAX',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text('Rs. ${_currentReport?.totalTax.toStringAsFixed(2) ?? '0.00'}',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue[800])),
                ],
              ),
            ),

            SizedBox(height: 20),

            Text(
              'Payment Type',
              textScaler: TextScaler.linear(1),
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 10),
            // Dynamic Payment Types
            if (_currentReport != null)
              ..._currentReport!.paymentSummaries.map((payment) {
                return Container(
                  height: height * 0.06,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  margin: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${payment.paymentType} Payment',
                          textScaler: TextScaler.linear(1),
                          style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Text('#${payment.transactionCount}',
                          textScaler: TextScaler.linear(1),
                          style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Text('Rs.${payment.totalAmount.toStringAsFixed(2)}',
                          textScaler: TextScaler.linear(1),
                          style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }),
            Container(
              height: height * 0.06,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              margin: EdgeInsets.symmetric(vertical: 6),
              // spacing between tiles
              decoration: BoxDecoration(
                color: Colors.teal[100], // light teal background
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grand Total Payment',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  Text('#${_currentReport?.totalOrderCount ?? 0}',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  Text('Rs.${_currentReport?.totalSales.toStringAsFixed(2) ?? '0.00'}',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            // Expected Cash
            SizedBox(
              height: 25,
            ),

            Container(
              margin: EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              width: width,
              // height: height * 0.8,
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(10),
                // color: Colors.teal.shade300
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected Cash (Sales Only)',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: height * 0.07,
                    child: CommonTextForm(
                      hintText: expectedCash.toStringAsFixed(2),
                      obsecureText: false,
                      BorderColor: primarycolor,
                      borderc: 0,
                      enabled: false,
                    ),
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  // Expected Total Cash calculation display
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Total Cash:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Opening Balance:',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            Text(
                              'Rs. ${openingBalance.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cash Sales:',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            Text(
                              'Rs. ${expectedCash.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cash Expenses:',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[700]),
                            ),
                            Text(
                              '- Rs. ${cashExpenses.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red[700]),
                            ),
                          ],
                        ),
                        if (totalExpenses > cashExpenses) Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(
                                  'Non-Cash Expenses:',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            Text(
                              'Rs. ${(totalExpenses - cashExpenses).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Divider(thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Expected Cash:',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Rs. ${(openingBalance + expectedCash - cashExpenses).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[800]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Text(
                    'Actual Cash',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: height * 0.07,
                    child: TextField(
                      controller: _actualCashController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      onChanged: (value) => _calculateDifference(),
                      decoration: InputDecoration(
                        hintText: 'Enter Actual Cash',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: primarycolor),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primarycolor),
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Text(
                    'Difference',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: height * 0.07,
                    child: TextField(
                      controller: _differenceController,
                      enabled: false,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: _differenceController.text.contains('-')
                                  ? Colors.red
                                  : Colors.green),
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  CommonButton(
                      height: height * 0.06,
                      bordercircular: 0,
                      onTap: _isGenerating
                          ? () {}
                          : () => _completeEndOfDay(),
                      child: _isGenerating
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'End of The Day',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                            color: Colors.white),
                      ))
                ],
              ),
            )
          ]),
        ),
      ),
    );
  }
}
