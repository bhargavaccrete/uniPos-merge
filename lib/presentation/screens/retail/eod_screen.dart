import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/domain/services/restaurant/eod_service.dart';

class RetailEODScreen extends StatefulWidget {
  const RetailEODScreen({super.key});

  @override
  State<RetailEODScreen> createState() => _RetailEODScreenState();
}

class _RetailEODScreenState extends State<RetailEODScreen> {
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _differenceController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

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

  @override
  void dispose() {
    _actualCashController.dispose();
    _differenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadEODData() async {
    setState(() => _isLoading = true);

    try {
      // Get opening balance
      final currentOpeningBalance = await DayManagementService.getOpeningBalance();

      // Generate EOD report for retail
      final report = await EODService.generateRetailEODReport(
        date: selectedDate,
        openingBalance: currentOpeningBalance,
        actualCash: 0.0,
      );

      // Expected CASH only
      final expectedCashAmount = report.paymentSummaries
          .where((p) => (p.paymentType ?? '').toLowerCase().trim() == 'cash')
          .fold<double>(0.0, (sum, p) => sum + p.totalAmount);

      // Check if there's any data to show
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

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    // Save the actual cash amount before clearing
    final actualCashAmount = double.parse(_actualCashController.text);
    final remarks = _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim();

    // Clear screen immediately and show loading
    setState(() {
      _isGenerating = true;
      _currentReport = null;
      _actualCashController.clear();
      _differenceController.clear();
      _remarksController.clear();
    });

    try {
      // 1. Generate retail EOD report with actual cash
      final report = await EODService.generateRetailEODReport(
        date: selectedDate,
        openingBalance: openingBalance,
        actualCash: actualCashAmount,
        remarks: remarks,
      );

      // 2. Save EOD report
      await EODService.saveEODReport(report);

      // 3. Mark day as completed
      await _markDayCompleted();

      // 4. Reset opening balance for next day
      await DayManagementService.resetDay();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End of Day completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      String errorMessage = 'Error completing End of Day';
      if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid cash amount format';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      _showError(errorMessage);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm End of Day', style: GoogleFonts.poppins()),
              content: Text(
                'This will:\n\n• Save the End of Day report\n• Mark day as completed\n• Reset for next day\n\nContinue?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _markDayCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('retail_last_eod_date', DateTime.now().toIso8601String());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('End of Day', style: GoogleFonts.poppins()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If generating EOD or no data to show
    if (_isGenerating || _currentReport == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('End of Day', style: GoogleFonts.poppins()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'Processing End of Day...',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ] else ...[
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                Text(
                  'No active transactions',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
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
        title: Text('End of Day Settlement', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opening Balance
            Container(
              padding: const EdgeInsets.all(16),
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Opening Balance:',
                    style: GoogleFonts.poppins(
                      color: Colors.teal,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Rs. ${openingBalance.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment Summaries
            Text(
              'Payment Summary',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (_currentReport != null)
              ..._currentReport!.paymentSummaries.map((payment) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${payment.paymentType} Payment',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '#${payment.transactionCount}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Rs. ${payment.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),

            // Grand Total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.teal[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '#${_currentReport?.totalOrderCount ?? 0}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Rs. ${_currentReport?.totalSales.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Discount Section
            if ((_currentReport?.totalDiscount ?? 0) > 0) ...[
              Text(
                'Total Discount',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Discount Given',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Rs. ${_currentReport?.totalDiscount.toStringAsFixed(2) ?? '0.00'}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tax Breakdown
            if (_currentReport != null && _currentReport!.taxSummaries.isNotEmpty) ...[
              Text(
                'Tax Breakdown',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._currentReport!.taxSummaries.map((tax) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tax.taxName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Rs. ${tax.taxAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL TAX',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Rs. ${_currentReport?.totalTax.toStringAsFixed(2) ?? '0.00'}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Cash Reconciliation Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Reconciliation',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Expected Cash Calculation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue.shade200),
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
                        const SizedBox(height: 8),
                        _buildCashRow('Opening Balance:', openingBalance),
                        _buildCashRow('Cash Sales:', expectedCash),
                        _buildCashRow('Cash Expenses:', cashExpenses, isNegative: true),
                        if (totalExpenses > cashExpenses)
                          _buildInfoRow(
                            'Non-Cash Expenses:',
                            totalExpenses - cashExpenses,
                          ),
                        const Divider(thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Expected Cash:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs. ${(openingBalance + expectedCash - cashExpenses).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actual Cash Input
                  Text(
                    'Actual Cash',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _actualCashController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    onChanged: (value) => _calculateDifference(),
                    decoration: InputDecoration(
                      hintText: 'Enter Actual Cash',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.teal),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Difference
                  Text(
                    'Difference',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _differenceController,
                    enabled: false,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _differenceController.text.contains('-')
                              ? Colors.red
                              : Colors.green,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Remarks (Optional)
                  Text(
                    'Remarks (Optional)',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add any notes or remarks...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.teal),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Complete EOD Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _completeEndOfDay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isGenerating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Complete End of Day',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashRow(String label, double amount, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isNegative ? Colors.red[700] : null,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''} Rs. ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isNegative ? Colors.red[700] : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}