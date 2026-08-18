import 'package:billberrylite/domain/services/retail/eod_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/core/routes/routes_name.dart';

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
  bool _isCompleted = false; // NEW: Track if EOD has been completed
  EndOfDayReport? _currentReport;
  DateTime selectedDate = DateTime.now();
  double openingBalance = 0.0;
  double expectedCash = 0.0;
  double totalExpenses = 0.0;
  double cashExpenses = 0.0;
  double cashRefunds = 0.0;

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
    // CRITICAL: Don't try to load data if EOD has been completed
    // This prevents "Box not found" errors when day has been reset
    if (_isCompleted) {
      return;
    }

    setState(() => _isLoading = true);

    try {

      // Get opening balance with detailed error handling
      final currentOpeningBalance = await DayManagementService.getOpeningBalance();

      // Generate EOD report for retail
      final report = await EODService.generateRetailEODReport(
        date: selectedDate,
        openingBalance: currentOpeningBalance,
        actualCash: 0.0,
      );

      // Cash refunds for the same window. Derived through EODReportService so
      // the Cash Drawer and this screen share one definition — the settlement
      // record itself (EndOfDayReport) is left untouched.
      final dayStart = await DayManagementService.getDayStartTimestamp() ??
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final refundsForDay = await EODReportService.cashRefundsForRange(
        dayStart,
        DateTime.now(),
      );

      // Expected CASH only
      final expectedCashAmount = report.paymentSummaries
          .where((p) => p.paymentType.toLowerCase().trim() == 'cash')
          .fold<double>(0.0, (sum, p) => sum + p.totalAmount);

      // Check if there's any data to show
      final hasAnyData = (report.totalSales > 0) ||
          (report.totalOrderCount > 0) ||
          (report.totalDiscount > 0) ||
          (report.totalTax > 0) ||
          (report.totalExpenses > 0) ||
          (currentOpeningBalance > 0);

      if (!mounted) return;

      // Debug logging

      // Clear any previous error messages
      ScaffoldMessenger.of(context).clearSnackBars();

      setState(() {
        _currentReport = hasAnyData ? report : null;
        openingBalance = currentOpeningBalance;
        expectedCash = expectedCashAmount;
        totalExpenses = report.totalExpenses;
        cashExpenses = report.cashExpenses;
        cashRefunds = refundsForDay;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      // Don't show "Box not found" errors - they're expected after EOD completion
      if (!e.toString().toLowerCase().contains('box not found')) {
        _showError('Error loading EOD data: $e');
      } else {
      }
    }
  }

  /// Expected drawer cash — taken from the report the service already built,
  /// not recomputed here.
  ///
  /// The local formula was `opening + cashSales - cashExpenses - cashRefunds`:
  /// it ignored manual Cash In / Cash Out, so the variance shown to the cashier
  /// differed from the `closingBalance` stored in the archived close. Reading
  /// the service's own number means they cannot disagree.
  double get _expectedTotalCash =>
      _currentReport?.closingBalance ??
      // Only before the preview report has loaded.
      (openingBalance + expectedCash - cashExpenses - cashRefunds);

  /// Net Cash In/Out, derived rather than re-read.
  ///
  /// It is whatever the service's `closingBalance` accounts for that this screen
  /// can itemise — so the breakdown rows always reconcile to the total by
  /// construction, even if the shared formula gains another term later.
  double get _netCashMovements =>
      _expectedTotalCash -
      (openingBalance + expectedCash - cashExpenses - cashRefunds);

  void _calculateDifference() {
    if (_actualCashController.text.isNotEmpty) {
      final actual = double.tryParse(_actualCashController.text) ?? 0.0;
      final difference = actual - _expectedTotalCash;
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

      // 4. CRITICAL: Set completion flag BEFORE resetting day
      // This prevents any widget rebuilds from trying to reload data
      if (mounted) {
        setState(() => _isCompleted = true);
      }

      // 5. Close the session, carrying the counted cash forward.
      //
      // This was `resetDay()`, which calls `endSession()` with no argument —
      // so `closingCash` defaulted to 0 and the stored closing balance was
      // wiped on every close. `getLastClosingBalance()` feeds the next day's
      // opening-balance dialog, so tomorrow pre-filled 0.00 and never showed
      // the "Yesterday closed with ₹X" hint; the archived session recorded
      // zero cash too. Restaurant already passes the real amount
      // (`endday.dart:759`).
      await DayManagementService.markDayEnded(
        closingBalance: actualCashAmount,
      );

      // Show success message
      if (mounted) {
        NotificationService.instance.showSuccess('End of Day completed successfully!');
      }

      // Day is closed — go to the dashboard rather than back into a stack that
      // still describes the day we just ended.
      if (mounted) {
        _exitToDashboard();
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

  /// Leave EOD for the dashboard, clearing the stack.
  ///
  /// A blind `pop()` here lands wherever EOD happened to be pushed from, which
  /// after a fresh setup is the onboarding screen (create store / restore
  /// backup). It is also the wrong destination on principle: once the day is
  /// closed, the screens underneath (Settings, POS) describe a day that no
  /// longer exists.
  void _exitToDashboard() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.retailMenu,
      (route) => false,
    );
  }

  /// Closing the day is irreversible, so it goes through the shared confirm
  /// dialog rather than a hand-rolled AlertDialog.
  ///
  /// The message now states the two things that actually carry consequences —
  /// the variance is recorded as-is, and the counted cash becomes tomorrow's
  /// opening float. The old copy said "Reset for next day", which described the
  /// bug where the closing balance was zeroed rather than carried forward.
  Future<bool> _showConfirmationDialog() {
    final counted = double.tryParse(_actualCashController.text) ?? 0.0;
    final variance = counted - _expectedTotalCash;

    return showAppConfirmDialog(
      context: context,
      title: 'Complete End of Day?',
      message: 'The day will be closed and the report saved.\n\n'
          'Counted cash: Rs. ${counted.toStringAsFixed(2)}\n'
          'Variance: Rs. ${variance.toStringAsFixed(2)}\n\n'
          'This cash becomes tomorrow\'s opening balance. The day cannot be '
          'reopened.',
      confirmLabel: 'Complete',
      accent: AppColors.primary,
      icon: Icons.nights_stay_rounded,
    );
  }

  Future<void> _markDayCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('retail_last_eod_date', DateTime.now().toIso8601String());
  }

  void _showError(String message) {
    NotificationService.instance.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: 'End of Day',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _exitToDashboard,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If generating EOD or no data to show
    if (_isGenerating || _currentReport == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: 'End of Day',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _exitToDashboard,
          ),
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
                  style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
                ),
              ] else ...[
                const Icon(Icons.check_circle_outline, size: 80, color: AppColors.success),
                const SizedBox(height: 20),
                Text(
                  'No active transactions',
                  style: GoogleFonts.poppins(fontSize: AppResponsive.headingFontSize(context), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start a new day to see EOD data',
                  style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'End of Day Settlement',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _exitToDashboard,
        ),
      ),
      body: SingleChildScrollView(
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opening Balance
            Container(
              padding: AppResponsive.cardPadding(context),
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Opening Balance:',
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      return Text(
                        'Rs. ${openingBalance.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment Summaries
            Text(
              'Payment Summary',
              style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (_currentReport != null)
              ..._currentReport!.paymentSummaries.map((payment) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
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
                color: AppColors.primary.withValues(alpha: 0.12),
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
                style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.06),
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
                        color: AppColors.danger,
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
                style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._currentReport!.taxSummaries.map((tax) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.06),
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
                  color: AppColors.info.withValues(alpha: 0.12),
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
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Cash Reconciliation Section
            Container(
              padding: AppResponsive.cardPadding(context),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Reconciliation',
                    style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Expected Cash Calculation
                  Container(
                    padding: AppResponsive.cardPadding(context),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.06),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Total Cash:',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCashRow('Opening Balance:', openingBalance),
                        _buildCashRow('Cash Sales:', expectedCash),
                        _buildCashRow('Cash Expenses:', cashExpenses, isNegative: true),
                        if (cashRefunds > 0)
                          _buildCashRow('Cash Refunds:', cashRefunds,
                              isNegative: true),
                        // Net manual drawer movements — including cash taken
                        // against credit, which posts a Cash In. Shown so the
                        // rows above always add up to the total below; without
                        // it the figures silently disagreed by this amount.
                        if (_netCashMovements.abs() > 0.005)
                          _buildCashRow(
                            _netCashMovements >= 0
                                ? 'Cash In (net):'
                                : 'Cash Out (net):',
                            _netCashMovements.abs(),
                            isNegative: _netCashMovements < 0,
                          ),
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
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs. ${_expectedTotalCash.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
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
                    style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _actualCashController,
                    hint: 'Enter Actual Cash',
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    onChanged: (value) => _calculateDifference(),
                  ),

                  const SizedBox(height: 20),

                  // Difference
                  Text(
                    'Difference',
                    style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _differenceController,
                    readOnly: true,
                    icon: _differenceController.text.contains('-')
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                  ),

                  const SizedBox(height: 20),

                  // Remarks (Optional)
                  Text(
                    'Remarks (Optional)',
                    style: GoogleFonts.poppins(fontSize: AppResponsive.subheadingFontSize(context), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _remarksController,
                    hint: 'Add any notes or remarks...',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 24),

                  // Complete EOD Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _completeEndOfDay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
                                fontSize: AppResponsive.subheadingFontSize(context),
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
              fontSize: AppResponsive.captionFontSize(context),
              color: isNegative ? AppColors.danger : null,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''} Rs. ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w500,
              color: isNegative ? AppColors.danger : null,
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
              Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}