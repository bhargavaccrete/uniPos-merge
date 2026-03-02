
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cash_handover_model.dart';
import 'package:unipos/data/repositories/restaurant/cash_handover_repository.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';

// ─── Entry type for the merged activity log ───────────────────────────────────

/// A single row in the Cash Drawer activity log.
/// We merge 4 data sources (opening balance, cash sales, cash expenses,
/// manual movements) into this common shape for display.
class _LogEntry {
  final DateTime time;
  final String description;
  final double signedAmount; // positive = cash added, negative = cash removed
  final String staffName;
  final _LogType type;
  // Computed after sort — running drawer total AFTER this entry.
  // Adjustments do NOT move the running balance (audit-only).
  double runningBalance = 0.0;

  _LogEntry({
    required this.time,
    required this.description,
    required this.signedAmount,
    required this.staffName,
    required this.type,
  });
}

enum _LogType {
  opening,    // 🔵 Opening balance
  sale,       // 🟢 Cash sale
  expense,    // 🔴 Cash expense
  movement,   // 🟣 Manual Cash In / Cash Out
  adjustment, // 🟠 System adjustment (EOD discrepancy / opening balance change)
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});

  @override
  State<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _dayEnded = false; // true after EOD — show read-only banner
  double _openingBalance = 0.0;
  double _cashSales = 0.0;
  double _cashExpenses = 0.0;
  DateTime? _dayStart;
  List<_LogEntry> _log = [];
  List<CashHandoverModel> _handovers = [];

  @override
  void initState() {
    super.initState();
    // Reload whenever the app comes back to foreground (e.g. after adding expense)
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAll();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  /// Loads all 4 data sources and rebuilds the merged log + balance.
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    // 1. Opening balance and day start time
    _openingBalance = await DayManagementService.getOpeningBalance();
    final dayStarted = await DayManagementService.isDayStarted();
    _dayStart = await DayManagementService.getDayStartTimestamp();

    // If day has never been started (no timestamp), show "Day not started" UI
    if (!dayStarted && _dayStart == null) {
      setState(() { _isLoading = false; _dayEnded = false; });
      return;
    }

    // Day was started but has since ended — show read-only view with banner
    _dayEnded = !dayStarted;

    final dayStart = _dayStart ?? DateTime.now().copyWith(hour: 0, minute: 0, second: 0);

    // 2. Load manual Cash In/Out movements for today
    await cashMovementStore.loadTodayMovements(dayStart);

    // 3. Load cash sales from past orders (today only, cash payment method)
    await pastOrderStore.loadPastOrders();
    final cashOrders = pastOrderStore.pastOrders.where((o) {
      // Skip voided orders — no money changed hands
      final status = (o.orderStatus ?? '').toUpperCase();
      if (status == 'VOIDED') return false;

      // Must be a today order
      final isToday = o.orderAt != null &&
          o.orderAt!.isAfter(dayStart.subtract(const Duration(seconds: 1)));
      if (!isToday) return false;

      // Pure cash payment
      final method = (o.paymentmode ?? '').toLowerCase().trim();
      if (method == 'cash') return true;

      // Split payment with a cash component
      if (o.isSplitPayment == true) {
        return o.paymentList.any(
            (p) => (p['method'] as String? ?? '').toLowerCase() == 'cash');
      }

      return false;
    }).toList();
    _cashSales = cashOrders.fold(0.0, (s, o) => s + _cashComponentOf(o));

    // 4. Load cash expenses (today only, paymentType == 'cash')
    await expenseStore.loadExpenses();
    final cashExp = expenseStore.expenses.where((e) {
      final isC = (e.paymentType ?? '').toLowerCase().trim() == 'cash';
      final isToday = e.dateandTime
          .isAfter(dayStart.subtract(const Duration(seconds: 1)));
      return isC && isToday;
    }).toList();
    _cashExpenses = cashExp.fold(0.0, (s, e) => s + e.amount);

    // 5. Load shifts + expense categories for activity log display
    await shiftStore.loadShifts();
    await expenseCategoryStore.loadCategories();

    // 6. Build the merged log
    _buildLog(dayStart, cashOrders, cashExp);

    // 6. Load all handover records (for the Handover History section)
    final handovers = await locator<CashHandoverRepository>().getAllHandovers();

    setState(() {
      _handovers = handovers;
      _isLoading = false;
    });
  }

  /// Returns the net cash component of an order:
  /// - Pure cash order  → totalPrice − refundAmount
  /// - Split order      → sum of cash entries in paymentList
  /// - Any other method → 0.0
  /// Voided orders should be excluded before calling this.
  double _cashComponentOf(PastOrderModel o) {
    if (o.isSplitPayment == true) {
      final rawCash = o.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));
      // Deduct refunds proportionally: refund is spread across all payment methods
      // by the same ratio as each method's share of the total.
      final refund = o.refundAmount ?? 0.0;
      if (refund > 0 && o.totalPrice > 0) {
        final cashRatio = rawCash / o.totalPrice;
        return (rawCash - refund * cashRatio).clamp(0.0, double.infinity);
      }
      return rawCash;
    }
    final method = (o.paymentmode ?? '').toLowerCase().trim();
    if (method == 'cash') {
      return (o.totalPrice - (o.refundAmount ?? 0.0)).clamp(0.0, double.infinity);
    }
    return 0.0;
  }

  /// Returns the staff name whose shift was active at [time].
  String _staffNameForTime(DateTime time) {
    for (final s in shiftStore.shifts) {
      final end = s.endTime ?? DateTime.now();
      if (time.isAfter(s.startTime.subtract(const Duration(seconds: 1))) &&
          time.isBefore(end.add(const Duration(seconds: 1)))) {
        return s.staffName;
      }
    }
    return '';
  }

  /// Merges all cash events into one time-sorted list for the activity log.
  void _buildLog(DateTime dayStart, List<PastOrderModel> cashOrders, List<Expense> cashExp) {
    // shiftId → staffName for direct lookup on orders
    final shiftIdToName = <String, String>{
      for (final s in shiftStore.shifts) s.id: s.staffName,
    };
    // categoryId → category name for readable expense descriptions
    final categoryIdToName = <String, String>{
      for (final c in expenseCategoryStore.categories) c.id: c.name,
    };

    final entries = <_LogEntry>[];

    // Opening balance entry (pinned to day start time)
    entries.add(_LogEntry(
      time: dayStart,
      description: 'Opening Balance',
      signedAmount: _openingBalance,
      staffName: 'Admin',
      type: _LogType.opening,
    ));

    // Cash sales (each order is one entry)
    for (final o in cashOrders) {
      if (o.orderAt == null) continue;
      // Prefer direct shiftId lookup; fall back to time-window match
      final saleStaff = (o.shiftId != null ? shiftIdToName[o.shiftId] : null)
          ?? _staffNameForTime(o.orderAt!);
      final cashAmt = _cashComponentOf(o);
      final hasSplitCash = o.isSplitPayment == true;
      final hasRefund = (o.refundAmount ?? 0.0) > 0;
      final label = hasSplitCash
          ? 'Sale #${o.billNumber ?? o.id.substring(0, 6)} (cash portion)'
          : hasRefund
              ? 'Sale #${o.billNumber ?? o.id.substring(0, 6)} (net of refund)'
              : 'Sale #${o.billNumber ?? o.id.substring(0, 6)}';
      entries.add(_LogEntry(
        time: o.orderAt!,
        description: label,
        signedAmount: cashAmt,
        staffName: saleStaff,
        type: _LogType.sale,
      ));
    }

    // Cash expenses — resolve category name and staff from shift time window
    for (final e in cashExp) {
      final catName = categoryIdToName[e.categoryOfExpense] ?? 'Misc';
      entries.add(_LogEntry(
        time: e.dateandTime,
        description: 'Expense — $catName',
        signedAmount: -(e.amount),
        staffName: _staffNameForTime(e.dateandTime),
        type: _LogType.expense,
      ));
    }

    // Manual Cash In / Cash Out movements + system adjustments.
    // 'opening' type movements are already shown by the synthetic entry above — skip them.
    for (final m in cashMovementStore.movements) {
      if (m.type == 'opening') continue; // covered by synthetic opening entry
      final isAdj = m.type == 'adjustment';
      entries.add(_LogEntry(
        time: m.timestamp,
        description: isAdj
            ? '${m.reason}${m.note != null ? ' — ${m.note}' : ''}'
            : m.label,
        signedAmount: isAdj
            // amount is already signed (negative = shortage/reduction, positive = overage/increase)
            ? m.amount
            : m.signedAmount,
        staffName: m.staffName,
        type: isAdj ? _LogType.adjustment : _LogType.movement,
      ));
    }

    // Sort by time ascending so the log reads oldest → newest
    entries.sort((a, b) => a.time.compareTo(b.time));

    // Second pass: compute running drawer balance.
    // Adjustments are audit-only — they do NOT move the running balance.
    double running = 0.0;
    for (final e in entries) {
      if (e.type != _LogType.adjustment) {
        running += e.signedAmount;
      }
      e.runningBalance = running;
    }

    _log = entries;
  }

  // ── Computed balance ─────────────────────────────────────────────────────

  /// Live estimated balance:
  ///   Opening + Cash Sales + Cash In − Cash Out − Cash Expenses
  double get _balance =>
      _openingBalance +
      _cashSales +
      cashMovementStore.totalCashIn -
      cashMovementStore.totalCashOut -
      _cashExpenses;

  // ── Cash In / Cash Out dialog ────────────────────────────────────────────

  Future<void> _showMovementDialog(String type) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    // Fixed reason options — keeps data clean for reporting
    const reasons = [
      'Owner deposit',
      'Safe drop',
      'Petty cash',
      'Advance to staff',
      'Supplier payment',
      'Other',
    ];
    String selectedReason = reasons.first;
    final isCashIn = type == 'in';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isCashIn
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isCashIn ? Colors.green : Colors.red)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCashIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: isCashIn ? Colors.green : Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isCashIn ? 'Cash In' : 'Cash Out',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),

              // Form fields
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount
                    Text('Amount',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: InputDecoration(
                        prefixText: '${CurrencyHelper.currentSymbol} ',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: isCashIn ? Colors.green : Colors.red,
                              width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reason dropdown
                    Text('Reason',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: reasons
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setDs(() => selectedReason = v ?? reasons.first),
                    ),
                    const SizedBox(height: 16),

                    // Optional note
                    Text('Note (optional)',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText: 'Add extra details...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountCtrl.text.trim()) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Enter a valid amount')),
                          );
                          return;
                        }
                        // Guard: warn if Cash Out would make the drawer go negative.
                        if (type == 'out' && amount > _balance) {
                          final proceed = await showDialog<bool>(
                            context: ctx,
                            builder: (warnCtx) => AlertDialog(
                              title: Row(children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                const Text('Balance Warning'),
                              ]),
                              content: Text(
                                'This withdrawal (${CurrencyHelper.currentSymbol} ${amount.toStringAsFixed(2)}) '
                                'exceeds the estimated drawer balance '
                                '(${CurrencyHelper.currentSymbol} ${_balance.toStringAsFixed(2)}).\n\n'
                                'The drawer balance would go negative. '
                                'Proceed only if you have physically verified the cash.',
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(warnCtx, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade700),
                                    onPressed: () => Navigator.pop(warnCtx, true),
                                    child: const Text('Proceed Anyway',
                                        style: TextStyle(color: Colors.white))),
                              ],
                            ),
                          );
                          if (proceed != true) return;
                        }
                        Navigator.pop(ctx);
                        final ok = await cashMovementStore.addMovement(
                          type: type,
                          amount: amount,
                          reason: selectedReason,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        );
                        if (ok) {
                          // Rebuild the log to include the new entry
                          await _loadAll();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCashIn ? Colors.green : Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isCashIn ? 'Add Cash In' : 'Add Cash Out',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _dayStart == null
                  ? _buildNoDayState(context)
                  : Observer(
                      // Observer wraps the body so it rebuilds when
                      // cashMovementStore.movements changes (new Cash In/Out)
                      builder: (_) => _buildBody(context, currency),
                    ),
        ),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(Icons.arrow_back,
                  color: Colors.white,
                  size: AppResponsive.iconSize(context)),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cash Drawer',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.headingFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: _loadAll,
            child: Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(Icons.refresh,
                  color: AppColors.primary,
                  size: AppResponsive.iconSize(context)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, String currency) {
    return ListView(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      children: [
        if (_dayEnded) _buildDayEndedBanner(context),
        if (_dayEnded) SizedBox(height: AppResponsive.mediumSpacing(context)),
        _buildBalanceCard(context, currency),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        if (!_dayEnded) _buildActionButtons(context),
        if (!_dayEnded) SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildBreakdownRow(context, currency),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildActivityLog(context, currency),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildHandoverHistory(context, currency),
      ],
    );
  }

  Widget _buildDayEndedBanner(BuildContext context) {
    final closingBalance = _balance;
    final currency = CurrencyHelper.currentSymbol;
    return Container(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_clock_rounded, color: Colors.amber.shade700,
              size: AppResponsive.iconSize(context)),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Text(
              'Day Ended — Read-only view',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: Colors.amber.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        // Show how much cash should still be in drawer
        Container(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cash still in drawer:',
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: Colors.amber.shade800)),
              Text('$currency${closingBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: closingBalance > 0 ? Colors.teal.shade700 : Colors.grey)),
            ],
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text(
          closingBalance > 0
              ? 'Safe-drop $currency${closingBalance.toStringAsFixed(2)} or use it as tomorrow\'s opening balance.'
              : 'Start a new day when ready.',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: Colors.amber.shade700,
          ),
        ),
      ]),
    );
  }

  // ── Balance card ─────────────────────────────────────────────────────────

  Widget _buildBalanceCard(BuildContext context, String currency) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppResponsive.largeBorderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Estimated Cash in Drawer',
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: Colors.white.withValues(alpha: 0.8))),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        // The balance rebuilds automatically via Observer when movements change
        Text(
          '$currency ${_balance.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue<double>(context,
                mobile: 32, tablet: 38, desktop: 44),
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        // Formula hint so staff understands the number
        Text(
          'Opening $_openingBalance  '
          '+ Sales ${_cashSales.toStringAsFixed(0)}  '
          '+ In ${cashMovementStore.totalCashIn.toStringAsFixed(0)}  '
          '− Out ${cashMovementStore.totalCashOut.toStringAsFixed(0)}  '
          '− Exp ${_cashExpenses.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: Colors.white.withValues(alpha: 0.7)),
        ),
      ]),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _showMovementDialog('in'),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: Text('Cash In',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context) + 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context))),
          ),
        ),
      ),
      SizedBox(width: AppResponsive.mediumSpacing(context)),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _showMovementDialog('out'),
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
          label: Text('Cash Out',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context) + 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context))),
          ),
        ),
      ),
    ]);
  }

  // ── Balance breakdown row ─────────────────────────────────────────────────

  Widget _buildBreakdownRow(BuildContext context, String currency) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        _breakdownLine(context, 'Opening Balance', _openingBalance, currency,
            Colors.blue, true),
        _breakdownLine(context, 'Cash Sales', _cashSales, currency,
            Colors.green, true),
        _breakdownLine(context, 'Cash In (movements)',
            cashMovementStore.totalCashIn, currency, Colors.teal, true),
        _breakdownLine(context, 'Cash Out (movements)',
            cashMovementStore.totalCashOut, currency, Colors.orange, false),
        _breakdownLine(context, 'Cash Expenses', _cashExpenses, currency,
            Colors.red, false),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Expected in Drawer',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textPrimary)),
          Text('$currency ${_balance.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.primary)),
        ]),
      ]),
    );
  }

  Widget _breakdownLine(BuildContext context, String label, double amount,
      String currency, Color color, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary)),
          ]),
          Text(
            '${isPositive ? '+' : '−'} $currency ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }

  // ── Activity log ──────────────────────────────────────────────────────────

  Widget _buildActivityLog(BuildContext context, String currency) {
    if (_log.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
          child: Text('No activity yet today',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: AppResponsive.bodyFontSize(context))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Activity",
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius:
                BorderRadius.circular(AppResponsive.borderRadius(context)),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _log.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) => _buildLogRow(context, _log[i], currency),
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow(BuildContext context, _LogEntry entry, String currency) {
    // Color and icon based on entry type
    final Color dotColor;
    final IconData dotIcon;
    switch (entry.type) {
      case _LogType.opening:
        dotColor = Colors.blue;
        dotIcon = Icons.play_circle_outline;
        break;
      case _LogType.sale:
        dotColor = Colors.green;
        dotIcon = Icons.shopping_bag_outlined;
        break;
      case _LogType.expense:
        dotColor = Colors.red;
        dotIcon = Icons.receipt_long_outlined;
        break;
      case _LogType.movement:
        dotColor = Colors.purple;
        dotIcon = entry.signedAmount >= 0
            ? Icons.arrow_circle_down_outlined
            : Icons.arrow_circle_up_outlined;
        break;
      case _LogType.adjustment:
        dotColor = Colors.orange;
        dotIcon = Icons.warning_amber_rounded;
    }

    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}';
    final isPositive = entry.signedAmount >= 0;
    final isAdj = entry.type == _LogType.adjustment;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.largeSpacing(context),
        vertical: AppResponsive.smallSpacing(context) + 2,
      ),
      child: Row(children: [
        // Dot icon
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(dotIcon, size: AppResponsive.smallIconSize(context), color: dotColor),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),

        // Time + description + staff
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.description,
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: isAdj ? Colors.orange.shade800 : AppColors.textPrimary)),
              if (isAdj)
                Text('audit only — does not affect balance',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade600))
              else if (entry.staffName.isNotEmpty)
                Text('$timeStr  ·  ${entry.staffName}',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary))
              else
                Text(timeStr,
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary)),
            ],
          ),
        ),

        // Amount + running balance
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : ''}$currency ${entry.signedAmount.abs().toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.smallFontSize(context),
                  color: isAdj
                      ? Colors.orange.shade700
                      : isPositive ? Colors.green.shade700 : Colors.red.shade700),
            ),
            if (!isAdj)
              Text(
                'Bal: $currency ${entry.runningBalance.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary),
              ),
            if (isAdj)
              Text(
                '$timeStr  ·  ${entry.staffName}',
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary),
              ),
          ],
        ),
      ]),
    );
  }

  // ── Handover History ──────────────────────────────────────────────────────

  Widget _buildHandoverHistory(BuildContext context, String currency) {
    if (_handovers.isEmpty) return const SizedBox.shrink();

    final fmt = DateFormat('dd MMM  HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.largeBorderRadius(context)),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          child: Row(children: [
            const Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.indigo),
            const SizedBox(width: 8),
            Text('Handover History',
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
        ),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _handovers.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (_, i) {
            final h = _handovers[i];
            final isDiscrepancy = h.status == 'DISCREPANCY';
            final isPending = h.status == 'PENDING';
            final statusColor = isPending ? Colors.orange : isDiscrepancy ? Colors.red : Colors.green;
            final statusLabel = isPending ? 'PENDING' : isDiscrepancy ? 'DISCREPANCY' : 'MATCHED';

            return Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.mediumSpacing(context),
                  vertical: AppResponsive.smallSpacing(context)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmt.format(h.closedAt),
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.arrow_upward, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('${h.closedBy} reported ',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                  Text('$currency ${h.closedAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
                if (h.receivedBy != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.arrow_downward, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('${h.receivedBy} received ',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                    Text('$currency ${h.receivedAmount!.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ],
                if (isDiscrepancy && h.variance != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        h.variance! < 0
                            ? 'Shortage: $currency ${h.variance!.abs().toStringAsFixed(2)}'
                            : 'Overage: $currency ${h.variance!.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                      ),
                    ]),
                  ),
                ],
              ]),
            );
          },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── No-day state ──────────────────────────────────────────────────────────

  Widget _buildNoDayState(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.point_of_sale_outlined,
            size: AppResponsive.largeIconSize(context) * 2,
            color: Colors.grey.shade300),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        Text('Day not started',
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary)),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text('Start the day from the Home screen to use Cash Drawer',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary.withValues(alpha: 0.6))),
      ]),
    );
  }
}

// ─── Handover Dialogs ─────────────────────────────────────────────────────────

/// Step 1: Outgoing staff counts cash and creates a PENDING handover.
/// Shown after "End Shift" is confirmed in drawermanage.dart.
class CashHandoverCloseDialog extends StatefulWidget {
  final String staffName;
  const CashHandoverCloseDialog({super.key, required this.staffName});

  @override
  State<CashHandoverCloseDialog> createState() =>
      _CashHandoverCloseDialogState();
}

class _CashHandoverCloseDialogState extends State<CashHandoverCloseDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      // barrierDismissible: false is set by the caller
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3E0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash Handover',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Count the drawer before you leave',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Context info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Handing over as: ${widget.staffName}',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 16),

              // Cash count input
              Text('Cash counted in drawer',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'))
                ],
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.orange.shade700, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Optional note
              Text('Note (optional)',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. "Left ₹1500, all good"',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Skip',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Confirm Handover',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the cash amount')));
      return;
    }
    setState(() => _isSaving = true);
    await cashHandoverStore.createHandover(
      closedBy: widget.staffName,
      closedAmount: amount,
      closedNote:
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }
}

// ─── Handover Receive Dialog ──────────────────────────────────────────────────

/// Step 2: Incoming staff confirms how much cash they see in the drawer.
/// Shown automatically when a pending handover is detected on login.
class HandoverReceiveDialog extends StatefulWidget {
  // Passed from welcome_Admin.dart after cashHandoverStore.loadPendingHandover()
  final String handoverId;
  final String closedBy;
  final DateTime closedAt;
  final double closedAmount;
  final String? closedNote;

  const HandoverReceiveDialog({
    super.key,
    required this.handoverId,
    required this.closedBy,
    required this.closedAt,
    required this.closedAmount,
    this.closedNote,
  });

  @override
  State<HandoverReceiveDialog> createState() =>
      _HandoverReceiveDialogState();
}

class _HandoverReceiveDialogState extends State<HandoverReceiveDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;
  // After completion, show result before closing
  String? _resultStatus;
  double? _variance;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;
    final fmt = DateFormat('dd MMM  HH:mm');

    // After confirming, show result screen before letting user proceed
    if (_resultStatus != null) return _buildResult(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pending_actions_rounded,
                    color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Cash Handover',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Confirm the cash you received',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Previous staff info — the accountability record
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Left by ${widget.closedBy}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(fmt.format(widget.closedAt),
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('Reported:  ',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        Text(
                          '$currency ${widget.closedAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary),
                        ),
                      ]),
                      if (widget.closedNote != null) ...[
                        const SizedBox(height: 4),
                        Text('"${widget.closedNote}"',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Incoming staff counts
                Text('Count the cash now',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  decoration: InputDecoration(
                    prefixText: '$currency ',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Note (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Any remarks...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Confirm Receipt',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Result screen (shown after confirming) ────────────────────────────────

  Widget _buildResult(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;
    final isMatched = _resultStatus == 'MATCHED';
    final color = isMatched ? Colors.green : Colors.orange;
    final icon =
        isMatched ? Icons.check_circle_outline : Icons.warning_amber_rounded;
    final title = isMatched ? 'Amounts Match ✓' : 'Discrepancy Found';
    final msg = isMatched
        ? 'Handover confirmed. Both counts agree.'
        : 'Variance: $currency ${_variance!.abs().toStringAsFixed(2)}'
            ' ${_variance! < 0 ? '(Shortage)' : '(Overage)'}.\n'
            'This has been recorded and the manager has been notified.';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 16),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Continue',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter the cash amount')));
      return;
    }
    setState(() => _isSaving = true);

    final receiverName = RestaurantSession.isAdmin
        ? 'Admin'
        : (RestaurantSession.staffName ?? 'Staff');

    final result = await cashHandoverStore.receiveHandover(
      handoverId: widget.handoverId,
      receivedBy: receiverName,
      receivedAmount: amount,
      receivedNote:
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    setState(() {
      _isSaving = false;
      _resultStatus = result?.status ?? 'MATCHED';
      _variance = result?.variance;
    });
  }
}
