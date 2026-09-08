import 'package:billberrylite/domain/services/retail/eod_report_service.dart';
import 'package:billberrylite/domain/services/retail/eod_settlement_print.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
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
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

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

  /// Whether a session is open at all — the ONLY thing that should gate the
  /// empty state. A session with zero sales still needs to be closed, so this
  /// must not be conflated with "no data to show" (see [_loadEODData]).
  bool _hasActiveSession = false;
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
      // A session that is null or already closed is the ONLY "nothing to do
      // here" case. Zero sales inside an OPEN session still needs closing —
      // that used to be conflated below, and a session with no activity but
      // stuck open (e.g. past the auto-close duration) had no way to reach
      // the settlement form at all.
      final currentSession = await DayManagementService.getCurrentSession();
      if (currentSession == null || currentSession.isClosed) {
        if (!mounted) return;
        setState(() {
          _hasActiveSession = false;
          _currentReport = null;
          _isLoading = false;
        });
        return;
      }
      _hasActiveSession = true;
      // TRADING DAY, matching restaurant's `endday.dart`: a session that opens
      // 11 PM and closes at 2 AM belongs to the day it OPENED. Dating from
      // `DateTime.now()` filed such a close under the next day, and the refund
      // window below then started from the wrong date.
      selectedDate = currentSession.startTime;

      // Get opening balance with detailed error handling
      final currentOpeningBalance =
          await DayManagementService.getOpeningBalance();

      // Generate EOD report for retail
      final report = await EODService.generateRetailEODReport(
        date: selectedDate,
        openingBalance: currentOpeningBalance,
        actualCash: 0.0,
      );

      // Cash refunds for the same window. Derived through EODReportService so
      // the Cash Drawer and this screen share one definition — the settlement
      // record itself (EndOfDayReport) is left untouched.
      final dayStart =
          await DayManagementService.getDayStartTimestamp() ??
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final refundsForDay = await EODReportService.cashRefundsForRange(
        dayStart,
        DateTime.now(),
      );

      // Expected CASH only
      final expectedCashAmount = report.paymentSummaries
          .where((p) => p.paymentType.toLowerCase().trim() == 'cash')
          .fold<double>(0.0, (sum, p) => sum + p.totalAmount);

      if (!mounted) return;

      // Clear any previous error messages
      ScaffoldMessenger.of(context).clearSnackBars();

      setState(() {
        // Always the report, session-gated above — a zero-activity day still
        // has to be settled and closed, same as restaurant's EOD screen.
        _currentReport = report;
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
      } else {}
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

    // Save the actual cash amount before clearing
    final actualCashAmount = double.parse(_actualCashController.text);
    final remarks = _remarksController.text.trim().isEmpty
        ? null
        : _remarksController.text.trim();

    // Ask where the cash goes BEFORE anything is written.
    //
    // Restaurant closes the session first and only then shows this dialog,
    // which deletes the session pointer — so its own EOD cash movements land
    // with a null sessionId. Collecting the answer up front lets every write
    // below happen while the session is still open.
    final withdrawal = await _showSafeDropDialog(actualCashAmount);
    if (withdrawal == null || !mounted) return;
    final keptInDrawer =
        (actualCashAmount - withdrawal).clamp(0.0, double.infinity);
    final variance = actualCashAmount - _expectedTotalCash;
    final closerName = RestaurantSession.staffName ??
        (RestaurantSession.isAdmin ? 'Admin' : 'Staff');

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
        cashWithdrawn: withdrawal,
      );

      // 2. Save EOD report
      await EODService.saveEODReport(report);

      // 2b. Put the day's cash movements in the drawer ledger, while the
      // session is still open so they carry its id and the closer's name.
      //
      // Without this the money simply vanished from the app's point of view:
      // the till was emptied and the Cash Drawer history showed nothing.
      // Non-fatal — a ledger failure must never strand a day half-closed.
      await _recordDrawerMovements(
        counted: actualCashAmount,
        withdrawal: withdrawal,
        kept: keptInDrawer,
        variance: variance,
        closerName: closerName,
      );

      // 3. Mark day as completed
      await _markDayCompleted();

      // 4. CRITICAL: Set completion flag BEFORE resetting day
      // This prevents any widget rebuilds from trying to reload data
      if (mounted) {
        setState(() => _isCompleted = true);
      }

      // 4b. Close staff hours before the session ends.
      //
      // Mirrors restaurant's endday.dart: a stale session freezes shifts and
      // attendance at the last real business activity FIRST, so completing EOD
      // late can never stretch a shift to DateTime.now(). Anything still open
      // after the freeze is closed explicitly. Wrapped so a staff-hours failure
      // can never block the day from closing.
      await _closeStaffHours();

      // 5. Close the session, carrying the KEPT cash forward.
      //
      // Not the full count: `getLastClosingBalance()` feeds the next day's
      // opening-balance dialog, and pre-filling money that was physically taken
      // to the safe would open tomorrow with a float that is not in the till.
      // (This call also used to be `resetDay()`, which passed nothing at all and
      // wiped the closing balance on every close.)
      await DayManagementService.markDayEnded(closingBalance: keptInDrawer);

      // 6. Settlement slip. Retail printed nothing at close — the only copy of
      // this document came from the History reprint button, which a shop had no
      // reason to know existed.
      await _printSettlement(report, closerName);

      if (mounted) {
        NotificationService.instance.showSuccess(
          'Day closed. ${CurrencyHelper.currentSymbol}${keptInDrawer.toStringAsFixed(2)} left in drawer.',
        );
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

  /// Put the close on the cash-drawer ledger.
  ///
  /// Two rows, matching restaurant's `endday.dart`:
  ///  * the variance as an `'adjustment'` — audit-only by design, so it explains
  ///    the gap without moving the running balance;
  ///  * the safe drop as a real `'out'`, which is what actually empties the till.
  ///
  /// `systemClose: true` on the withdrawal: `addMovement` refuses to write once
  /// EOD is strictly pending, and a forced close of a stale session is exactly
  /// when that is true — the guard is there to stop MANUAL edits, not the close
  /// that resolves them.
  ///
  /// Non-fatal throughout: the day must still close if the ledger write fails.
  Future<void> _recordDrawerMovements({
    required double counted,
    required double withdrawal,
    required double kept,
    required double variance,
    required String closerName,
  }) async {
    final symbol = CurrencyHelper.currentSymbol;
    String money(double v) => '$symbol${v.toStringAsFixed(2)}';

    try {
      if (variance.abs() > 0.01) {
        await cashMovementStore.addAdjustment(
          signedAmount: variance,
          reason: variance < 0 ? 'EOD Shortage' : 'EOD Overage',
          note: 'Expected: ${money(_expectedTotalCash)}, '
              'Counted: ${money(counted)}',
          staffName: closerName,
        );
      }

      if (withdrawal > 0.005) {
        await cashMovementStore.addMovement(
          type: 'out',
          amount: withdrawal,
          reason: 'Safe drop - End of Day',
          note: '$closerName ended day. Counted: ${money(counted)}, '
              'Took to safe: ${money(withdrawal)}, '
              'Left in drawer: ${money(kept)}',
          systemClose: true,
        );
      }
    } catch (e) {
      debugPrint('EOD: cash movement recording failed (non-fatal): $e');
    }
  }

  /// Print the settlement slip for a just-closed day.
  ///
  /// Thermal only — there is no PDF fallback on the retail side. A shop with no
  /// printer paired must still be able to close, so a missing printer is said
  /// once as information, never as an error.
  Future<void> _printSettlement(EndOfDayReport report, String closerName) async {
    try {
      final outcome =
          await EodSettlementPrint.reprint(report, shiftUser: closerName);
      if (!mounted) return;
      switch (outcome) {
        case EodReprintOutcome.printed:
          break;
        case EodReprintOutcome.noPrinter:
          NotificationService.instance.showInfo(
            'Day closed. No thermal printer paired — reprint the settlement '
            'from EOD History once one is set up.',
          );
        case EodReprintOutcome.sendFailed:
          NotificationService.instance.showWarning(
            'Day closed, but the settlement slip could not be printed. '
            'Reprint it from EOD History.',
          );
      }
    } catch (e) {
      debugPrint('EOD: settlement print failed (non-fatal): $e');
    }
  }

  /// Back out of EOD without closing the day.
  ///
  /// Just a pop — EOD is reached from Settings, so leaving it should land back
  /// on Settings. This used to call [_exitToDashboard], which cleared the whole
  /// stack and dumped the user on the dashboard even though nothing had
  /// changed. The stack-clear is still correct AFTER the day is closed (see
  /// [_exitToDashboard]) — but not for a plain back press.
  ///
  /// Falls back to the dashboard if there is genuinely nothing to pop to, so a
  /// future entry point can't strand the user here.
  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      _exitToDashboard();
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
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.retailMenu, (route) => false);
  }

  /// Safe Drop — the one place the cashier says where the counted cash goes.
  ///
  /// Returns the amount to TAKE OUT, or null if cancelled. This replaced a plain
  /// yes/no confirm: the day closed without ever asking, so money left the till
  /// with nothing recording it and the whole count carried to the next morning
  /// as though it had stayed in the drawer.
  ///
  /// Mirrors restaurant's `endday.dart` dialog, including the pre-fill (the full
  /// count, since taking everything is the common case) and the "Leave all in
  /// drawer" escape.
  Future<double?> _showSafeDropDialog(double counted) {
    final withdrawalController = TextEditingController(
      text: counted.toStringAsFixed(2),
    );
    final symbol = CurrencyHelper.currentSymbol;
    final variance = counted - _expectedTotalCash;
    String money(double v) => '$symbol${v.toStringAsFixed(2)}';

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [withdrawalController],
        child: PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final withdrawal =
                  double.tryParse(withdrawalController.text) ?? 0.0;
              final kept = (counted - withdrawal).clamp(0.0, double.infinity);
              final tooMuch = withdrawal > counted + 0.005;

              void confirm(double amount) {
                if (amount > counted + 0.005) {
                  NotificationService.instance.showError(
                    'Cannot take out more than the counted cash',
                  );
                  return;
                }
                Navigator.pop(dialogContext, amount);
              }

              return AppDialogShell(
                title: 'End of Day — Safe Drop',
                subtitle: 'Decide where the counted cash goes',
                icon: Icons.nights_stay_rounded,
                accent: AppColors.primary,
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Same terms the Cash Reconciliation card itemises, so the
                    // dialog cannot show a different expectation to the screen.
                    _buildCashRow('Opening Balance:', openingBalance),
                    _buildCashRow('Cash Sales:', expectedCash),
                    if (cashExpenses > 0)
                      _buildCashRow(
                        'Cash Expenses:',
                        cashExpenses,
                        isNegative: true,
                      ),
                    if (cashRefunds > 0)
                      _buildCashRow(
                        'Cash Refunds:',
                        cashRefunds,
                        isNegative: true,
                      ),
                    if (_netCashMovements.abs() > 0.005)
                      _buildCashRow(
                        _netCashMovements >= 0
                            ? 'Cash In (net):'
                            : 'Cash Out (net):',
                        _netCashMovements.abs(),
                        isNegative: _netCashMovements < 0,
                      ),
                    const Divider(height: 20, thickness: 0.5),
                    _safeDropRow('Expected Cash', money(_expectedTotalCash)),
                    _safeDropRow('You counted', money(counted), bold: true),
                    if (variance.abs() > 0.005)
                      _safeDropRow(
                        variance < 0 ? 'Shortage' : 'Overage',
                        money(variance.abs()),
                        color: variance < 0
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Amount to take to safe',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: withdrawalController,
                      hint: '0.00',
                      icon: Icons.savings_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (tooMuch) ...[
                      const SizedBox(height: 6),
                      Text(
                        'More than you counted (${money(counted)})',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const Divider(height: 24, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stays in drawer',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          money(kept),
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "This becomes tomorrow's opening float",
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Second exit, matching restaurant: taking nothing out is a
                    // real choice, not a reason to retype the field to 0.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => confirm(0),
                        icon: const Icon(Icons.inbox_outlined, size: 18),
                        label: Text(
                          'Leave all in drawer',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  appDialogCancelButton(dialogContext),
                  const SizedBox(width: 12),
                  appDialogPrimaryButton(
                    label: 'Complete',
                    color: AppColors.primary,
                    // Stays tappable when over-withdrawn: `confirm` refuses and
                    // says why, rather than the button going dead with the
                    // inline hint as the only clue.
                    onPressed: () => confirm(withdrawal),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// One label/value line of the Safe Drop summary.
  Widget _safeDropRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Close every open shift and clock out every open attendance record.
  ///
  /// Non-fatal by design: EOD must complete even if staff-hours cleanup fails,
  /// exactly as `endday.dart` treats it.
  Future<void> _closeStaffHours() async {
    try {
      final stale = await DayManagementService.isEodStrictlyPending() ||
          await DayManagementService.hasPendingEOD();
      if (stale) {
        await shiftStore.freezeStaleShiftsAndAttendance();
      }
      // Staff with no matching shift survive the freeze — when the session is
      // stale they must still close at its last activity, never at now().
      final DateTime? staleClockOut = stale
          ? await DayManagementService.calculateSessionLastActivity()
          : null;

      await attendanceStore.loadTodayRecords();
      final open = attendanceStore.todayRecords.where((r) => r.isOpen).toList();
      for (final r in open) {
        DateTime? outAt = staleClockOut;
        if (outAt != null && outAt.isBefore(r.clockIn)) outAt = r.clockIn;
        await attendanceStore.clockOut(r.id, clockOutTime: outAt);
      }

      await shiftStore.loadShifts();
      for (final sh in shiftStore.shifts.where((s) => s.isOpen)) {
        final now = DateTime.now();
        final isStaleShift = stale ||
            sh.startTime.day != now.day ||
            sh.startTime.month != now.month ||
            sh.startTime.year != now.year;
        if (isStaleShift) {
          await shiftStore.closeStaleShiftWithLatestActivity(sh.id);
        } else {
          await shiftStore.closeShift(sh.id);
        }
      }
      await RestaurantSession.clearShiftSession();
    } catch (e) {
      debugPrint('EOD: staff hours cleanup failed (non-fatal): $e');
    }
  }

  Future<void> _markDayCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'retail_last_eod_date',
      DateTime.now().toIso8601String(),
    );
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
            onPressed: _handleBack,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Generating, or genuinely no session to close — NOT gated on zero
    // activity, which used to strand an open zero-sales session with no way
    // to reach the settlement form.
    if (_isGenerating || !_hasActiveSession) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: 'End of Day',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
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
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: AppColors.success,
                ),
                const SizedBox(height: 20),
                Text(
                  'No active transactions',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.headingFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start a new day to see EOD data',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textSecondary,
                  ),
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
          onPressed: _handleBack,
        ),
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxCardWidth(context),
        child: SingleChildScrollView(
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
                          '${CurrencyHelper.currentSymbol}${openingBalance.toStringAsFixed(2)}',
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
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              if (_currentReport != null)
                ..._currentReport!.paymentSummaries.map((payment) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '#${payment.transactionCount}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${CurrencyHelper.currentSymbol}${payment.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Grand Total
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                      '${CurrencyHelper.currentSymbol}${_currentReport?.totalSales.toStringAsFixed(2) ?? '0.00'}',
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
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                        '${CurrencyHelper.currentSymbol}${_currentReport?.totalDiscount.toStringAsFixed(2) ?? '0.00'}',
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
              if (_currentReport != null &&
                  _currentReport!.taxSummaries.isNotEmpty) ...[
                Text(
                  'Tax Breakdown',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ..._currentReport!.taxSummaries.map((tax) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${CurrencyHelper.currentSymbol}${tax.taxAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                        '${CurrencyHelper.currentSymbol}${_currentReport?.totalTax.toStringAsFixed(2) ?? '0.00'}',
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
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Expected Cash Calculation
                    Container(
                      padding: AppResponsive.cardPadding(context),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.06),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                        ),
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
                          _buildCashRow(
                            'Cash Expenses:',
                            cashExpenses,
                            isNegative: true,
                          ),
                          if (cashRefunds > 0)
                            _buildCashRow(
                              'Cash Refunds:',
                              cashRefunds,
                              isNegative: true,
                            ),
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
                                '${CurrencyHelper.currentSymbol}${_expectedTotalCash.toStringAsFixed(2)}',
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
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _actualCashController,
                      hint: 'Enter Actual Cash',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (value) => _calculateDifference(),
                    ),

                    const SizedBox(height: 20),

                    // Difference
                    Text(
                      'Difference',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w500,
                      ),
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
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w500,
                      ),
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
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
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
            '${isNegative ? '-' : ''} ${CurrencyHelper.currentSymbol}${amount.toStringAsFixed(2)}',
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
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
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
            '${CurrencyHelper.currentSymbol}${amount.toStringAsFixed(2)}',
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
