import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/domain/services/restaurant/data_clear_service.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/domain/services/restaurant/eod_service.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/screens/restaurant/welcome_Admin.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
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

      print('✅ All boxes reported as open, attempting to access data...');

      final lastEODDate = await _getLastEODDate();
      final dayStartTimestamp = await DayManagementService.getDayStartTimestamp();
      final today = DateTime.now();

      print('🔍 Last EOD date: $lastEODDate');
      print('🔍 Day start timestamp: $dayStartTimestamp');
      print('🔍 Today date: $today');

      final isEODCompletedAfterDayStart = lastEODDate != null &&
          dayStartTimestamp != null &&
          lastEODDate.isAfter(dayStartTimestamp);

      print('🔍 Is EOD completed after day start: $isEODCompletedAfterDayStart');

      if (isEODCompletedAfterDayStart) {
        print('ℹ️ EOD already completed for the current day - showing empty state');
        setState(() {
          _currentReport = null;
          openingBalance = 0.0;
          expectedCash = 0.0;
          totalExpenses = 0.0;
          _isLoading = false;
        });
        return;
      }

      final dayStarted = await DayManagementService.isDayStarted();
      print('🔍 Day started: $dayStarted');

      if (!dayStarted) {
        print('ℹ️ Day not started - showing empty state');
        setState(() {
          _currentReport = null;
          openingBalance = 0.0;
          expectedCash = 0.0;
          totalExpenses = 0.0;
          _isLoading = false;
        });
        return;
      }

      print('📦 Fetching past orders...');
      await pastOrderStore.loadPastOrders();
      final pastOrders = pastOrderStore.pastOrders.toList();
      print('✅ Got ${pastOrders.length} past orders in total');

      print('📊 Getting opening balance...');
      final currentOpeningBalance = await DayManagementService.getOpeningBalance();
      print('✅ Opening balance: $currentOpeningBalance');

      print('📋 Generating EOD report...');
      final report = await EODService.generateEODReport(
        date: selectedDate,
        openingBalance: currentOpeningBalance,
        actualCash: 0.0,
      );
      print('✅ EOD report generated');

      final expectedCashAmount = report.paymentSummaries
          .where((p) => p.paymentType.toLowerCase().trim() == 'cash')
          .fold<double>(0.0, (sum, p) => sum + p.totalAmount);

      final hasAnyData = (report.totalSales > 0) ||
          (report.totalOrderCount > 0) ||
          (report.totalDiscount > 0) ||
          (report.totalTax > 0) ||
          (report.totalExpenses > 0) ||
          (currentOpeningBalance > 0);

      final dayStart = await DayManagementService.getDayStartTimestamp()
          ?? DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      await cashMovementStore.loadTodayMovements(dayStart);

      setState(() {
        _currentReport = hasAnyData ? report : null;
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

  Future<void> _completeEndOfDay() async {
    if (_actualCashController.text.isEmpty) {
      _showError('Please enter actual cash amount');
      return;
    }

    await orderStore.loadOrders();

    print('🔍 DEBUG: Checking for active orders before End Day...');
    print('   Total Orders in Active Store: ${orderStore.orders.length}');

    final activeOrders = orderStore.orders.where((o) {
      final status = o.status.toLowerCase();
      final isVoided = status == 'voided' || status == 'cancelled';
      final isPaid = o.isPaid == true || o.paymentStatus?.toLowerCase() == 'paid';
      if (isVoided) return false;
      if (isPaid) return false;
      return true;
    }).toList();

    print('   Detected Active Orders: ${activeOrders.length}');

    if (activeOrders.isNotEmpty) {
      await _showActiveOrdersError(activeOrders.length);
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

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

      await EODService.saveEODReport(report);
      await DataClearService.clearAllTransactionalData();

      await shiftStore.loadShifts();
      final openShifts = shiftStore.shifts.where((s) => s.isOpen).toList();
      for (final s in openShifts) {
        await shiftStore.closeShift(s.id);
      }
      await RestaurantSession.clearShiftSession();

      await _markDayCompleted();

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
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade600, Colors.teal.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
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
                            TextField(
                              controller: withdrawalController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                              onChanged: (_) => setDialogState(() => fieldError = null),
                              decoration: InputDecoration(
                                prefixText: 'Rs. ',
                                prefixStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.teal.shade700),
                                hintText: '0.00',
                                errorText: fieldError,
                                filled: true,
                                fillColor: Colors.teal.shade50,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.teal.shade200)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.teal.shade200)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.teal.shade600, width: 2)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Cannot End Day', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text(
            'There are $count active order(s) currently running.\n\nYou must complete or void all active orders before you can perform End of Day.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Confirm End of Day', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text(
            'This will:\n\n• Save the End of Day report\n• Clear cart and active orders\n• Keep past orders for reports\n• Keep expenses for reports\n• Mark day as completed\n• Return to home screen\n\nContinue?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Confirm', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    ) ?? false;
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

  Future<void> _printSummary() async {
    if (_currentReport == null) {
      _showError('No report data to print');
      return;
    }

    final storeName = await StoreSettingsService().getStoreName() ?? 'Restaurant';
    final symbol = await CurrencyHelper.getCurrencySymbol();
    final report = _currentReport!;
    final date = report.date;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    final font     = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();

    await Printing.layoutPdf(
      name: 'EOD_Summary_$dateStr',
      onLayout: (_) {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: font, bold: boldFont),
            build: (pw.Context ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(storeName,
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(child: pw.Text('End of Day Summary – $dateStr')),
                pw.SizedBox(height: 4),
                pw.Divider(),
                pw.SizedBox(height: 8),
                _pdfRow('Opening Balance', '$symbol ${report.openingBalance.toStringAsFixed(2)}'),
                pw.SizedBox(height: 12),
                pw.Text('Order Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.SizedBox(height: 4),
                ...report.orderSummaries.map((o) =>
                    _pdfRow('${o.orderType} (${o.orderCount} orders)',
                        '$symbol ${o.totalAmount.toStringAsFixed(2)}')),
                pw.SizedBox(height: 12),
                pw.Text('Payment Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.SizedBox(height: 4),
                ...report.paymentSummaries.map((p) =>
                    _pdfRow('${p.paymentType} (${p.transactionCount} txns)',
                        '$symbol ${p.totalAmount.toStringAsFixed(2)}')),
                pw.SizedBox(height: 12),
                if (report.taxSummaries.isNotEmpty) ...[
                  pw.Text('Tax Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.SizedBox(height: 4),
                  ...report.taxSummaries.map((t) =>
                      _pdfRow('${t.taxName} (${t.taxRate}%)', '$symbol ${t.taxAmount.toStringAsFixed(2)}')),
                  pw.SizedBox(height: 12),
                ],
                pw.Divider(),
                _pdfRow('Total Discount', '$symbol ${report.totalDiscount.toStringAsFixed(2)}'),
                _pdfRow('Total Tax', '$symbol ${report.totalTax.toStringAsFixed(2)}'),
                _pdfRow('Total Expenses', '$symbol ${report.totalExpenses.toStringAsFixed(2)}'),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 4),
                _pdfRow('TOTAL SALES',
                    '$symbol ${report.totalSales.toStringAsFixed(2)}',
                    bold: true),
                pw.SizedBox(height: 4),
                _pdfRow('Expected Cash',
                    '$symbol ${(report.openingBalance + expectedCash - cashExpenses).toStringAsFixed(2)}'),
                pw.SizedBox(height: 16),
                pw.Center(child: pw.Text('Generated by UniPOS', style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          ),
        );
        return doc.save();
      },
    );
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)
        : const pw.TextStyle(fontSize: 12);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  Future<void> _startDay() async {
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OpeningBalanceDialog(),
    );
    if (result != null && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AdminWelcome()),
        (route) => false,
      );
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  AppBar _buildAppBar(bool isTablet) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.white,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      title: Text(
        'End of Day Settlement',
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 22 : 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_outline_rounded,
                    size: isTablet ? 22 : 20, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
                    style: GoogleFonts.poppins(
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    RestaurantSession.effectiveRole,
                    style: GoogleFonts.poppins(
                        fontSize: isTablet ? 11 : 10,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
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

      children.add(Divider(height: 1, color: AppColors.divider));
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Tax',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(
                '$currency ${_currentReport?.totalTax.toStringAsFixed(2) ?? '0.00'}',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700)),
          ],
        ),
      ));
    }

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
    final isTablet = MediaQuery.of(context).size.width > 600;
    final currency = CurrencyHelper.currentSymbol;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: _buildAppBar(isTablet),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isGenerating || _currentReport == null) {
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
              Column(children: [
                _iconActionButton(
                    icon: Icons.print_rounded,
                    label: 'Print',
                    color: Colors.teal,
                    onTap: _printSummary),
                const SizedBox(height: 8),
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
