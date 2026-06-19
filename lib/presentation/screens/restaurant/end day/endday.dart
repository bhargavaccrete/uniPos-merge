import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/data/models/restaurant/db/attendance_model.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import '../start order/startorder.dart';
import 'package:unipos/domain/services/restaurant/data_clear_service.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/domain/services/restaurant/eod_service.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/restaurant/esc_pos_receipt_builder.dart';
import 'package:unipos/domain/services/restaurant/inventory_service.dart';
import 'package:unipos/presentation/screens/restaurant/welcome_Admin.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:unipos/core/routes/routes_name.dart';
import '../../../widget/restaurant/opening_balance_dialog.dart';

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
  bool _hasActiveSession = false;
  EndOfDayReport? _currentReport;
  DateTime selectedDate = DateTime.now();
  double openingBalance = 0.0;
  double expectedCash = 0.0;
  double totalExpenses = 0.0;
  double cashExpenses = 0.0;
  double _cashIn = 0.0;
  double _cashOut = 0.0;

  @override
  void initState() {
    super.initState();
    _loadEODData();
  }

  Future<void> _loadEODData() async {
    setState(() => _isLoading = true);

    try {
      final requiredBoxes = {
        'restaurant_eodBox': 'EOD reports',
        'dayManagementBox': 'day management',
        'pastorderBox': 'past orders',
        'restaurant_expenseCategory': 'expense categories',
        'restaurant_expenseBox': 'expenses',
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
                'Please restart the app completely (stop and relaunch).');
      }


      final today = DateTime.now();


      // Check for current session
      final currentSession = await DayManagementService.getCurrentSession();

      if (currentSession == null || currentSession.isClosed) {
        setState(() {
          _hasActiveSession = false;
          _currentReport = null;
          openingBalance = 0.0;
          expectedCash = 0.0;
          totalExpenses = 0.0;
          _isLoading = false;
        });
        return;
      }
      _hasActiveSession = true;

      selectedDate = currentSession.startTime;
      final sessionId = currentSession.sessionId;

      await pastOrderStore.loadPastOrders();
      final pastOrders = pastOrderStore.pastOrders.toList();

      final currentOpeningBalance = currentSession.openingCash;

      final report = await EODService.generateEODReport(
        date: selectedDate,
        openingBalance: currentOpeningBalance,
        actualCash: 0.0,
        sessionId: sessionId,
      );

      final expectedCashAmount = report.paymentSummaries
          .where((p) => p.paymentType.toLowerCase().trim() == 'cash')
          .fold<double>(0.0, (sum, p) => sum + p.totalAmount);

      final hasAnyData = (report.totalSales > 0) ||
          (report.totalOrderCount > 0) ||
          (report.totalDiscount > 0) ||
          (report.totalTax > 0) ||
          (report.totalExpenses > 0) ||
          (currentOpeningBalance > 0);

      final dayStart = currentSession.startTime;
      await cashMovementStore.loadTodayMovements(dayStart);

      setState(() {
        _currentReport = report;
        openingBalance = currentOpeningBalance;
        expectedCash = expectedCashAmount;
        totalExpenses = report.totalExpenses;
        cashExpenses = report.cashExpenses;
        _cashIn  = cashMovementStore.totalCashIn;
        _cashOut = cashMovementStore.totalCashOut;
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
      final expectedTotalCash = openingBalance + expectedCash + _cashIn - _cashOut - cashExpenses;
      final difference = actual - expectedTotalCash;
      _differenceController.text = difference.toStringAsFixed(2);
    } else {
      _differenceController.text = '';
    }
  }

  /// Returns true if an order is unsettled and blocks EOD.
  bool _isUnsettledOrder(dynamic o) {
    final status = o.status.toLowerCase();
    if (status == 'voided' || status == 'cancelled' || status == 'completed') return false;
    if (o.isPaid == true || o.paymentStatus?.toLowerCase() == 'paid') return false;
    return true;
  }

  Future<void> _completeEndOfDay() async {
    if (_actualCashController.text.isEmpty) {
      _showError('Please enter actual cash amount');
      return;
    }

    await orderStore.loadOrders();

    final activeOrders = orderStore.orders.where(_isUnsettledOrder).toList();

    if (activeOrders.isNotEmpty) {
      final isPendingEOD = await DayManagementService.hasPendingEOD();
      if (isPendingEOD) {
        // Previous day pending — user is stuck, offer Void All
        await _showPendingEODOrdersDialog(activeOrders);
        // Re-check after voiding (user may have voided all)
        await orderStore.loadOrders();
        final stillActive = orderStore.orders.where(_isUnsettledOrder).toList();
        if (stillActive.isNotEmpty) return;
      } else {
        // Same day — user can navigate to orders freely
        await _showActiveOrdersError(activeOrders.length);
        return;
      }
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    // --- AUTO CLOCK-OUT CHECK ---
    try {
      final attendanceBox = Hive.box<AttendanceModel>(HiveBoxNames.restaurantAttendance);
      final openAttendance = attendanceBox.values.where((r) => r.isOpen).toList();
      
      if (openAttendance.isNotEmpty) {
        // Skip the "Staff Still Clocked In" prompt when the only person still
        // clocked in is the one running EOD — just clock them out silently.
        // Resolve the current user's name exactly as login clocks them in:
        // admin → 'Admin' (admin_login.dart), staff → their name (restaurant_login.dart).
        final currentName = RestaurantSession.staffName ??
            (RestaurantSession.isAdmin ? 'Admin' : 'Staff');
        final onlySelf =
            openAttendance.every((r) => r.staffName == currentName);

        if (!onlySelf) {
        final hInset = !AppResponsive.isMobile(context)
            ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
            : 24.0;
        final confirmedAttendance = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('Staff Still Clocked In', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text('${openAttendance.length} staff member(s) are still clocked in. Do you want to automatically clock them out now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel EOD', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Clock Out All', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirmedAttendance != true) return;
        
        }

        // Clock out the remaining open staff — the self-only silent case, or
        // everyone after the confirm dialog above.
        for (final r in openAttendance) {
          await attendanceStore.clockOut(r.id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to auto clock-out staff: $e');
    }
    // ---------------------------

    final actualCashAmount = double.parse(_actualCashController.text);

    setState(() {
      _isGenerating = true;
      _currentReport = null;
      _actualCashController.clear();
      _differenceController.clear();
    });

    try {
      final report = await EODService.generateEODReport(
        date: selectedDate,
        openingBalance: openingBalance,
        actualCash: actualCashAmount,
      );

      // Save report first — if this throws, session stays open and user can retry
      await EODService.saveEODReport(report);

      // Keep the just-generated report as the current one so the Safe Drop
      // dialog's Print action can render the complete EOD (it was cleared to
      // null above while the loading spinner showed).
      _currentReport = report;

      // Report is committed. Now close session in a finally block so it ALWAYS
      // runs — prevents stuck-open session on shift/snooze cleanup failure.
      try {
        await shiftStore.loadShifts();
        final openShifts = shiftStore.shifts.where((s) => s.isOpen).toList();
        for (final s in openShifts) {
          await shiftStore.closeShift(s.id);
        }
        await RestaurantSession.clearShiftSession();
        await DayManagementService.clearEODSnooze();
      } catch (_) {
        // Shift/snooze cleanup failure is non-critical — session closure must still proceed
      } finally {
        await DayManagementService.endSession(closingCash: actualCashAmount);
      }

      final expectedTotalCash =
          openingBalance + expectedCash + _cashIn - _cashOut - cashExpenses;
      final discrepancy = actualCashAmount - expectedTotalCash;
      if (mounted) {
        await _showSafeDropDialog(actualCashAmount, discrepancy: discrepancy);
      }
    } catch (e) {
      setState(() => _isGenerating = false);

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

  Future<void> _showSafeDropDialog(double actualCash,
      {double discrepancy = 0.0}) async {
    final withdrawalController = TextEditingController(
      text: actualCash.toStringAsFixed(2),
    );
    final closerName = RestaurantSession.staffName ??
        (RestaurantSession.loginType == 'admin' ? 'Admin' : 'Staff');

    String? fieldError;
    bool isConfirming = false;

    Future<void> runConfirm(
        double w, StateSetter setDialogState, BuildContext ctx) async {
      setDialogState(() => isConfirming = true);

      final closingBalance = actualCash - w;
      final note = '$closerName ended day. '
          'Counted: Rs.${actualCash.toStringAsFixed(2)}, '
          'Took to safe: Rs.${w.toStringAsFixed(2)}, '
          'Left in drawer: Rs.${closingBalance.toStringAsFixed(2)}';

      try {
        if (discrepancy.abs() > 0.01) {
          final expectedAmt = actualCash - discrepancy;
          await cashMovementStore.addAdjustment(
            signedAmount: discrepancy,
            reason: discrepancy < 0 ? 'EOD Shortage' : 'EOD Overage',
            note: 'Expected: Rs.${expectedAmt.toStringAsFixed(2)}, '
                'Counted: Rs.${actualCash.toStringAsFixed(2)}',
            staffName: closerName,
          );
        }

        if (w > 0) {
          await cashMovementStore.addMovement(
            type: 'out',
            amount: w,
            reason: 'Safe drop - End of Day',
            note: note,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Cash movement recording failed during EOD: $e');
      }

      await DayManagementService.markDayEnded(closingBalance: closingBalance);

      NotificationService.instance
          .showSuccess('Day closed. Rs.${closingBalance.toStringAsFixed(2)} left in drawer.');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('restaurant_is_logged_in', false);
      await RestaurantSession.clearSession();

      if (ctx.mounted) Navigator.of(ctx).pop();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.restaurantLogin,
              (route) => false,
        );
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final withdrawal =
                double.tryParse(withdrawalController.text) ?? 0.0;
            final remaining =
            (actualCash - withdrawal).clamp(0.0, double.infinity);

            Future<void> confirm() async {
              if (isConfirming) return;
              final w = double.tryParse(withdrawalController.text);
              if (w == null || w < 0) {
                setDialogState(() => fieldError = 'Enter a valid amount');
                return;
              }
              if (w > actualCash) {
                setDialogState(() =>
                fieldError = 'Cannot withdraw more than counted cash');
                return;
              }
              try {
                await runConfirm(w, setDialogState, ctx);
              } catch (e) {
                setDialogState(() {
                  isConfirming = false;
                  fieldError = 'Error: $e';
                });
              }
            }

            return PopScope(
              canPop: false,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade600,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Stack(
                          children: [
                            // Full-width box keeps the title block centred even
                            // though the Stack also holds the corner print icon.
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.savings_rounded, size: 36, color: Colors.white),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'End of Day — Safe Drop',
                                    style: GoogleFonts.poppins(
                                        fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Closed by: $closerName',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            // Print the complete EOD report. Secondary action →
                            // small corner icon, not a button beside Confirm.
                            // The report is already saved at this point.
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                tooltip: 'Print EOD Report',
                                icon: const Icon(Icons.print_rounded, color: Colors.white),
                                onPressed: () => _printSummary(
                                  withdrawalCash: double.tryParse(withdrawalController.text) ?? 0,
                                  closerName: closerName,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade100),
                              ),
                              child: Column(
                                children: [
                                  _safeDropRow('Opening Balance', openingBalance, Colors.grey[700]!),
                                  const SizedBox(height: 4),
                                  _safeDropRow('Cash Sales', expectedCash, Colors.grey[700]!),
                                  if (_cashIn > 0) ...[
                                    const SizedBox(height: 4),
                                    _safeDropRow('Cash In', _cashIn, Colors.green[700]!),
                                  ],
                                  if (cashExpenses > 0) ...[
                                    const SizedBox(height: 4),
                                    _safeDropRow('Cash Expenses', -cashExpenses, Colors.red[700]!),
                                  ],
                                  if (_cashOut > 0) ...[
                                    const SizedBox(height: 4),
                                    _safeDropRow('Cash Out', -_cashOut, Colors.red[700]!),
                                  ],
                                  Divider(height: 16, color: Colors.teal.shade200),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('You counted',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal.shade800)),
                                      Text(
                                          'Rs. ${actualCash.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.teal.shade800)),
                                    ],
                                  ),
                                  if (discrepancy.abs() > 0.01) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: discrepancy < 0 ? Colors.red.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: discrepancy < 0 ? Colors.red.shade200 : Colors.green.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              size: 14,
                                              color: discrepancy < 0 ? Colors.red.shade700 : Colors.green.shade700),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              discrepancy < 0
                                                  ? 'Shortage Rs.${discrepancy.abs().toStringAsFixed(2)} — logged as ADJUSTMENT'
                                                  : 'Overage Rs.${discrepancy.toStringAsFixed(2)} — logged as ADJUSTMENT',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: discrepancy < 0 ? Colors.red.shade700 : Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              'Amount to take to safe',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: withdrawalController,
                              hint: '0.00',
                              icon: Icons.account_balance_wallet_outlined,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              onChanged: (_) => setDialogState(() => fieldError = null),
                              prefixWidget: Padding(
                                padding: const EdgeInsets.only(left: 12, right: 4),
                                child: Text('Rs. ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: remaining > 0 ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: remaining > 0 ? Colors.green.shade200 : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_outlined,
                                          size: 14,
                                          color: remaining > 0 ? Colors.green.shade600 : Colors.grey[500]!),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Stays in drawer (next opening)',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: remaining > 0 ? Colors.green.shade700 : Colors.grey[600]!),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${remaining.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: remaining > 0 ? Colors.green.shade700 : Colors.grey[600]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: isConfirming ? null : confirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isConfirming
                                    ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('Confirm & Logout',
                                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            if (!isConfirming) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: TextButton(
                                  onPressed: () async {
                                    withdrawalController.text = '0.00';
                                    await confirm();
                                  },
                                  style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Text('Leave all in drawer',
                                      style: GoogleFonts.poppins(
                                          fontSize: 14, color: Colors.grey.shade600)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    withdrawalController.dispose();
  }

  Future<void> _showPendingEODOrdersDialog(List<dynamic> activeOrders) async {
    final pendingHInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: pendingHInset, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Previous Day - ${activeOrders.length} Pending Order(s)', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('These orders were not settled. Void them to complete End of Day.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
              SizedBox(height: 12),
              ...activeOrders.take(5).map((o) => Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 14, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'KOT #${o.kotNumbers.isNotEmpty ? o.kotNumbers.first : "?"} • ${o.orderType ?? ""}${o.tableNo != null && o.tableNo!.isNotEmpty ? " • Table ${o.tableNo}" : ""}',
                      style: GoogleFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
              )),
              if (activeOrders.length > 5)
                Text('+${activeOrders.length - 5} more', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                // Get current session ID
                final currentSessionId = await DayManagementService.getCurrentSessionId();
                
                // Void all stale orders
                for (final order in activeOrders) {
                  final voidRecord = PastOrderModel(
                    id: order.id,
                    customerName: order.customerName ?? '',
                    totalPrice: order.totalPrice,
                    items: order.items,
                    orderAt: order.timeStamp,
                    orderType: order.orderType,
                    paymentmode: 'N/A',
                    subTotal: order.subTotal,
                    gstAmount: order.gstAmount,
                    tableNo: order.tableNo,
                    orderStatus: 'VOID',
                    kotNumbers: order.kotNumbers,
                    kotBoundaries: order.kotBoundaries,
                    sessionId: currentSessionId ?? order.sessionId,
                    voidedBy: 'EOD Auto-void by ${RestaurantSession.isAdmin ? 'Admin' : RestaurantSession.staffName ?? 'Staff'}',
                  );
                  await pastOrderStore.addOrder(voidRecord);

                  // Only restore stock if kitchen hadn't started (Processing = ingredients not yet used)
                  if (order.status == 'Processing') {
                    final itemsToRestock = <CartItem, int>{};
                    for (final item in order.items) {
                      if (item.quantity > 0) itemsToRestock[item] = item.quantity;
                    }
                    if (itemsToRestock.isNotEmpty) {
                      await InventoryService.restoreStockForRefund(itemsToRestock);
                    }
                  }

                  await orderStore.deleteOrder(order.id);
                  if (order.tableNo != null && order.tableNo!.isNotEmpty) {
                    await tableStore.updateTableStatus(order.tableNo!, 'Available');
                  }
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                NotificationService.instance.showSuccess('${activeOrders.length} order(s) voided');
              },
              child: Text('Void All', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _safeDropRow(String label, double amount, Color color) {
    final isNeg = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
          Text(
            '${isNeg ? '-' : '+'} Rs. ${amount.abs().toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _showActiveOrdersError(int count) async {
    final activeOrders = orderStore.orders.where(_isUnsettledOrder).toList();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final activeHInset = !AppResponsive.isMobile(context)
            ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
            : 24.0;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: activeHInset, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('$count Active Order(s)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settle or void these orders to end the day:', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
              SizedBox(height: 12),
              ...activeOrders.take(5).map((o) => Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 14, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'KOT #${o.kotNumbers.isNotEmpty ? o.kotNumbers.first : "?"} • ${o.orderType}${o.tableNo != null && o.tableNo!.isNotEmpty ? " • Table ${o.tableNo}" : ""} • ${o.status}',
                      style: GoogleFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
              )),
              if (activeOrders.length > 5)
                Text('+${activeOrders.length - 5} more', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Later', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, RouteNames.restaurantActiveOrders);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Go to Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showConfirmationDialog() async {
    // Compute cash variance
    final actual = double.tryParse(_actualCashController.text) ?? 0.0;
    final expectedTotal = openingBalance + expectedCash + _cashIn - _cashOut - cashExpenses;
    final difference = actual - expectedTotal;
    final hasVariance = difference.abs() > 50;

    // Active dine-in orders still in kitchen (not yet served — soft warning only)
    final paidNotServed = orderStore.orders
        .where((o) => _isUnsettledOrder(o) && o.orderType?.toLowerCase().contains('dine') == true)
        .length;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: Colors.orange,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'End of Day',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to close the day?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Info items
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _confirmInfoRow(Icons.save_rounded, 'Save EOD report', Colors.green),
                      const SizedBox(height: 10),
                      _confirmInfoRow(Icons.delete_sweep_rounded, 'Clear cart & active orders', Colors.red),
                      const SizedBox(height: 10),
                      _confirmInfoRow(Icons.history_rounded, 'Keep past orders & expenses', Colors.blue),
                    ],
                  ),
                ),

                // Cash variance warning
                if (hasVariance) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cash variance of ${CurrencyHelper.currentSymbol}${difference.abs().toStringAsFixed(0)} detected (${difference > 0 ? 'excess' : 'short'})',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Paid-not-served soft warning
                if (paidNotServed > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.restaurant_rounded, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$paidNotServed paid order${paidNotServed > 1 ? 's' : ''} not yet marked Served',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }

  Widget _confirmInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _markDayCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_eod_date', DateTime.now().toIso8601String());
  }

  Future<DateTime?> _getLastEODDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString('last_eod_date');
      if (dateStr != null) return DateTime.parse(dateStr);
    } catch (e) {
      debugPrint('Error getting last EOD date: $e');
    }
    return null;
  }

  void _showError(String message) {
    NotificationService.instance.showError(message);
  }

  Future<void> _printSummary({double withdrawalCash = 0, String? closerName}) async {
    if (_currentReport == null) {
      _showError('No report data to print');
      return;
    }

    final storeName = await StoreSettingsService().getStoreName() ?? 'Restaurant';
    final symbol = await CurrencyHelper.getCurrencySymbol();
    final report = _currentReport!;
    final date = report.date;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    // ── Shared settlement values (thermal + PDF render the same data) ──
    // totalSales is the grand total (incl. tax) → acts as GROSS; NET = GROSS - tax - roundOff.
    final roundOff = report.roundOff;
    final grossSale = report.totalSales;
    final tax = report.totalTax;
    final netSale = grossSale - tax - roundOff;
    final cashRecon = report.cashReconciliation;
    final shiftUser = closerName ??
        (RestaurantSession.staffName ??
            (RestaurantSession.isAdmin ? 'Admin' : 'Staff'));
    final shiftStart = selectedDate;
    final shiftEnd = DateTime.now();
    final orderTypes = report.orderSummaries
        .map((o) => (name: o.orderType, amount: o.totalAmount))
        .toList();
    final paymentMethods = report.paymentSummaries
        .map((p) => (name: p.paymentType, amount: p.totalAmount))
        .toList();
    final orderTypeTotal = orderTypes.fold<double>(0, (s, o) => s + o.amount);
    // Total Credit = sum of the 'Credit' payment method.
    final totalCredit = paymentMethods
        .where((p) => p.name.toLowerCase() == 'credit')
        .fold<double>(0, (s, p) => s + p.amount);

    // ── THERMAL SETTLEMENT RECEIPT (preferred) ──
    // Uses the saved receipt printer (or KOT printer as fallback). Falls through
    // to the PDF path below if no thermal printer is configured or the send fails.
    final printer =
        printerStore.defaultReceiptPrinter ?? printerStore.defaultKotPrinter;
    if (printer != null) {
      final bytes = EscPosReceiptBuilder.buildEodSettlementTicket(
        paperWidth: printer.paperSize,
        storeName: storeName,
        currencySymbol: symbol,
        shiftUser: shiftUser,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        orderTypes: orderTypes,
        totalSale: netSale,
        discount: report.totalDiscount,
        netSale: netSale,
        tax: tax,
        roundOff: roundOff,
        grossSale: grossSale,
        cash: cashRecon.actualCash,
        totalCredit: totalCredit,
        openingBalance: report.openingBalance,
        cashExpense: report.cashExpenses,
        totalExpense: report.totalExpenses,
        drawerBalance: report.closingBalance,
        withdrawalCash: withdrawalCash,
        cashDifference: cashRecon.difference,
        paymentMethods: paymentMethods,
        noOfBill: report.totalOrderCount,
        reprintBill: 0,
        cancelledBill: report.cancelledOrderCount,
        cancelledBillAmount: report.cancelledOrderAmount,
        cancelledProducts: 0,
        cancelledProductsAmount: 0,
        saleReturnAmount: report.totalRefunds,
        finalAmount: grossSale,
      );

      final success = await printerStore.sendBytes(bytes, printer);
      if (success) {
        NotificationService.instance
            .showSuccess('Settlement printed to ${printer.name}');
        return;
      }
      NotificationService.instance.showError(
          'Thermal print failed: ${printerStore.errorMessage ?? "Unknown error"}. Showing PDF...');
      // fall through to PDF
    }

    // ── PDF FALLBACK — same SETTLEMENT layout on an 80mm roll ──
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final df = DateFormat('dd-MM-yyyy hh:mm:ss a');
    String money(double v) => DecimalSettings.formatAmount(v);
    final dur = shiftEnd.difference(shiftStart);
    String two(int n) => n.toString().padLeft(2, '0');
    final durationStr =
        '${two(dur.inHours)}:${two(dur.inMinutes % 60)}:${two(dur.inSeconds % 60)}';

    await Printing.layoutPdf(
      name: 'EOD_Settlement_$dateStr',
      onLayout: (_) {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            margin: const pw.EdgeInsets.all(10),
            theme: pw.ThemeData.withFont(base: font, bold: boldFont),
            build: (pw.Context ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(storeName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: 15, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text('SETTLEMENT RECEIPT',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
                _pdfDash(),
                _pdfSettleRow('SHIFT USER:', shiftUser),
                _pdfSettleRow('SHIFT START:', df.format(shiftStart)),
                _pdfSettleRow('SHIFT END:', df.format(shiftEnd)),
                _pdfSettleRow('DURATION:', durationStr),
                _pdfDash(),
                ...orderTypes.map((o) =>
                    _pdfSettleRow(o.name.toUpperCase(), money(o.amount))),
                _pdfSettleRow('TOTAL (ORDER TYPE)', money(orderTypeTotal)),
                _pdfDash(),
                _pdfSettleRow('TOTAL SALE:', money(netSale)),
                _pdfSettleRow('DISCOUNT:', money(report.totalDiscount)),
                _pdfSettleRow('NET SALE:', money(netSale)),
                _pdfSettleRow('TAX:', money(tax)),
                _pdfSettleRow('ROUND OFF:', money(roundOff)),
                _pdfSettleRow('GROSS SALE:', money(grossSale), bold: true),
                _pdfDash(),
                _pdfSettleRow('CASH', money(cashRecon.actualCash)),
                _pdfSettleRow('TOTAL CREDIT:', money(totalCredit)),
                _pdfSettleRow('OPENING BALANCE:', money(report.openingBalance)),
                _pdfSettleRow('CASH EXPENSE:', money(report.cashExpenses)),
                _pdfSettleRow('TOTAL EXPENSE:', money(report.totalExpenses)),
                _pdfSettleRow('DRAWER BALANCE:', money(report.closingBalance)),
                _pdfSettleRow('WITHDRAWAL CASH:', money(withdrawalCash)),
                _pdfSettleRow('CASH DIFFERENCE:', money(cashRecon.difference)),
                _pdfDash(),
                ...paymentMethods.map((p) =>
                    _pdfSettleRow(p.name.toUpperCase(), money(p.amount))),
                if (paymentMethods.isNotEmpty) _pdfDash(),
                _pdfSettleRow('NO OF BILL:', '${report.totalOrderCount}'),
                _pdfSettleRow('REPRINT BILL:', '0'),
                _pdfSettleRow('CANCELLED BILL:', '${report.cancelledOrderCount}'),
                _pdfSettleRow('CANCELLED BILL AMOUNT:', money(report.cancelledOrderAmount)),
                _pdfSettleRow('CANCELLED PRODUCTS:', '0'),
                _pdfSettleRow('CANCELLED PRODUCTS AMOUNT:', money(0)),
                _pdfSettleRow('SALE RETURN AMOUNT:', money(report.totalRefunds)),
                _pdfDash(),
                _pdfSettleRow('FINAL AMOUNT:', '$symbol ${money(grossSale)}',
                    bold: true, large: true),
                _pdfDash(),
                pw.Center(
                  child: pw.Text('THANK YOU...!',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
        return doc.save();
      },
    );
  }

  pw.Widget _pdfSettleRow(String label, String value,
      {bool bold = false, bool large = false}) {
    final style = pw.TextStyle(
      fontSize: large ? 13 : 9.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _pdfDash() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(List.filled(60, '-').join(),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: const pw.TextStyle(fontSize: 9)),
    );
  }

  Future<void> _startDay() async {
    // promptStartDay shows the dialog AND actually starts the day (opening
    // balance + adjustment). The old inline dialog only collected the amount and
    // relied on the dashboard to start it — which no longer force-prompts.
    final started = await promptStartDay(context);
    if (started && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AdminWelcome()),
            (route) => false,
      );
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  AppBar _buildAppBar(bool isTablet) {
    return buildPrimaryAppBar(
      title: 'End of Day Settlement',
      titleFontSize: isTablet ? 20 : 18,
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    ]);
  }

  Widget _calcRow(String label, double amount, String currency, Color color) {
    final isNeg = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(
            '${isNeg ? '-' : '+'} $currency ${amount.abs().toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  IconData _paymentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cash': return Icons.money_rounded;
      case 'card':
      case 'card/online': return Icons.credit_card_rounded;
      case 'upi':
      case 'qr': return Icons.qr_code_rounded;
      default: return Icons.payment_rounded;
    }
  }

  Widget _orderTypesCard(String currency) {
    if (_currentReport == null || _currentReport!.orderSummaries.isEmpty) {
      return _sectionCard([
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No orders recorded',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
      ]);
    }

    final summaries = _currentReport!.orderSummaries;
    final children = <Widget>[];
    for (int i = 0; i < summaries.length; i++) {
      final s = summaries[i];
      children.add(Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 18, color: Colors.teal),
          ),
          title: Text(s.orderType,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          subtitle: Text('${s.orderCount} orders',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
          trailing: Text('$currency ${s.totalAmount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal.shade700)),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Avg Order Value',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                          '$currency ${s.averageOrderValue.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                const SizedBox(height: 4),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text('$currency ${s.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700)),
                    ]),
              ]),
            ),
          ],
        ),
      ));
      if (i < summaries.length - 1) {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
    }
    return _sectionCard(children);
  }

  Widget _discountTaxCard(String currency) {
    final children = <Widget>[];

    // Discount row
    children.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.local_offer_rounded,
                  size: 16, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Text('Total Discount',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ]),
          Text(
              '$currency ${_currentReport?.totalDiscount.toStringAsFixed(2) ?? '0.00'}',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red)),
        ],
      ),
    ));

    if (_currentReport != null && _currentReport!.taxSummaries.isNotEmpty) {
      children.add(Divider(height: 1, color: AppColors.divider));

      for (int i = 0; i < _currentReport!.taxSummaries.length; i++) {
        final tax = _currentReport!.taxSummaries[i];
        children.add(Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.percent_rounded,
                  size: 16, color: Colors.blue),
            ),
            title: Text(tax.taxName,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            trailing: Text(
                '$currency ${tax.taxAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700)),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Taxable Amount',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text('$currency ${tax.taxableAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
              ),
            ],
          ),
        ));
      }
    }

    // Total Tax — always show regardless of tax breakdown availability
    children.add(Divider(height: 1, color: AppColors.divider));
    children.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.percent_rounded,
                  size: 16, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Text('Total Tax',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          Text(
              '$currency ${_currentReport?.totalTax.toStringAsFixed(2) ?? '0.00'}',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade700)),
        ],
      ),
    ));

    return _sectionCard(children);
  }

  Widget _paymentsCard(String currency) {
    if (_currentReport == null ||
        _currentReport!.paymentSummaries.isEmpty) {
      return _sectionCard([
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No payments recorded',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
      ]);
    }

    final payments = _currentReport!.paymentSummaries;
    final children = <Widget>[];
    for (int i = 0; i < payments.length; i++) {
      final p = payments[i];
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(_paymentIcon(p.paymentType),
                size: 16, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.paymentType} Payment',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text('${p.transactionCount} transactions',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('$currency ${p.totalAmount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700)),
        ]),
      ));
      if (i < payments.length - 1) {
        children.add(
            Divider(height: 1, indent: 52, color: AppColors.divider));
      }
    }

    // Grand total
    children.add(Divider(height: 1, color: AppColors.divider));
    children.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Grand Total',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  '$currency ${_currentReport?.totalSales.toStringAsFixed(2) ?? '0.00'}',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              Text('${_currentReport?.totalOrderCount ?? 0} orders',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    ));

    return _sectionCard(children);
  }

  Widget _cashReconciliationCard(String currency, bool isTablet) {
    final expectedTotal =
        openingBalance + expectedCash + _cashIn - _cashOut - cashExpenses;

    return _sectionCard([
      // Breakdown summary
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expected Cash Breakdown',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            _calcRow('Opening Balance', openingBalance, currency,
                Colors.grey[700]!),
            _calcRow(
                'Cash Sales', expectedCash, currency, Colors.grey[700]!),
            if (_cashIn > 0)
              _calcRow('Cash In', _cashIn, currency, Colors.green[700]!),
            if (cashExpenses > 0)
              _calcRow('Cash Expenses', -cashExpenses, currency,
                  Colors.red[700]!),
            if (_cashOut > 0)
              _calcRow('Cash Out', -_cashOut, currency, Colors.orange[700]!),
            if (totalExpenses > cashExpenses)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Non-Cash Expenses',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ]),
                    Text(
                        '$currency ${(totalExpenses - cashExpenses).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Expected Cash',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('$currency ${expectedTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),

      Divider(height: 1, color: AppColors.divider),

      // Input section
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppTextField(
              controller: _actualCashController,
              label: 'Actual Cash in Drawer',
              hint: 'Enter counted cash amount',
              icon: Icons.payments_rounded,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              prefixWidget: Padding(
                padding:
                const EdgeInsets.only(left: 14, right: 8),
                child: Text(currency,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
              onChanged: (_) => _calculateDifference(),
            ),

            const SizedBox(height: 12),

            // Reactive difference display
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _differenceController,
              builder: (ctx, value, _) {
                final diff = double.tryParse(value.text);
                final isNeg = diff != null && diff < 0;
                final hasVal = value.text.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: !hasVal
                        ? AppColors.surfaceLight
                        : (isNeg
                        ? Colors.red.shade50
                        : Colors.green.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: !hasVal
                            ? AppColors.divider
                            : (isNeg
                            ? Colors.red.shade200
                            : Colors.green.shade200)),
                  ),
                  child: Row(children: [
                    Icon(
                      !hasVal
                          ? Icons.calculate_outlined
                          : (isNeg
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded),
                      size: 20,
                      color: !hasVal
                          ? AppColors.textSecondary
                          : (isNeg ? Colors.red : Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Difference',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text(
                          !hasVal
                              ? 'Enter actual cash above'
                              : '$currency ${value.text}',
                          style: GoogleFonts.poppins(
                            fontSize: !hasVal ? 13 : 16,
                            fontWeight: hasVal
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: !hasVal
                                ? AppColors.textSecondary
                                : (isNeg
                                ? Colors.red.shade700
                                : Colors.green.shade700),
                          ),
                        ),
                        if (hasVal && isNeg)
                          Text('Shortage — will be logged',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.red.shade400)),
                        if (hasVal && !isNeg && diff != 0)
                          Text('Overage — will be logged',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.green.shade600)),
                      ],
                    ),
                  ]),
                );
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: isTablet ? 54 : 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _completeEndOfDay,
                icon: _isGenerating
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.nightlight_round,
                    color: Colors.white),
                label: Text(
                  _isGenerating ? 'Processing...' : 'End of Day',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  disabledBackgroundColor: Colors.teal.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final currency = CurrencyHelper.currentSymbol;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: _buildAppBar(isTablet),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isGenerating || !_hasActiveSession) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: _buildAppBar(isTablet),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text('Processing End of Day...',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500)),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      size: 72, color: Colors.green),
                ),
                const SizedBox(height: 20),
                Text('No active transactions',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Start a new day to begin recording transactions',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _startDay,
                  icon: const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white),
                  label: Text('Start New Day',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
      appBar: _buildAppBar(isTablet),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opening balance + action buttons
            Row(children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 18 : 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Opening Balance',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.white70)),
                        Text('$currency ${openingBalance.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              // Print is intentionally NOT here — the day isn't closed yet, so
              // printing a draft summary is premature. Print belongs to the
              // completed-EOD flow only.
              Column(children: [
                _iconActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    color: Colors.blueGrey,
                    onTap: _loadEODData),
              ]),
            ]),

            const SizedBox(height: 20),

            _sectionLabel('Order Types', Icons.receipt_long_rounded, Colors.teal),
            const SizedBox(height: 8),
            _orderTypesCard(currency),

            const SizedBox(height: 20),

            _sectionLabel('Discounts & Tax', Icons.percent_rounded, Colors.orange),
            const SizedBox(height: 8),
            _discountTaxCard(currency),

            const SizedBox(height: 20),

            _sectionLabel('Payment Breakdown', Icons.payment_rounded, Colors.blue),
            const SizedBox(height: 8),
            _paymentsCard(currency),

            const SizedBox(height: 20),

            _sectionLabel('Cash Reconciliation',
                Icons.account_balance_wallet_rounded, AppColors.primary),
            const SizedBox(height: 8),
            _cashReconciliationCard(currency, isTablet),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ]),
      ),
    );
  }
}
