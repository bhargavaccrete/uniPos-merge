import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

/// Retail Cash Drawer.
///
/// A lean adaptation of the restaurant Cash Drawer: it reuses the same
/// cash-movement engine (CashMovementStore) and Cash In/Out dialog, but sources
/// sales from the retail [saleStore] and drops restaurant-only concepts
/// (shifts, cash handover). The estimated drawer balance is:
///   Opening + Cash Sales + Cash In − Cash Out − Cash Expenses
/// — the exact formula retail EOD uses, so the two always agree.

class _LogEntry {
  final DateTime time;
  final String description;
  final double signedAmount; // + = cash in, − = cash out
  final _LogType type;
  double runningBalance = 0.0;

  _LogEntry({
    required this.time,
    required this.description,
    required this.signedAmount,
    required this.type,
  });
}

enum _LogType { opening, sale, expense, movement }

class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});

  @override
  State<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  double _openingBalance = 0.0;
  double _cashSales = 0.0;
  double _cashExpenses = 0.0;
  DateTime? _dayStart;
  List<_LogEntry> _log = [];

  @override
  void initState() {
    super.initState();
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

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      _openingBalance = await DayManagementService.getOpeningBalance();
      _dayStart = await DayManagementService.getDayStartTimestamp();
      final now = DateTime.now();

      // The Cash Drawer is always visible/usable. If a day is started, scope to
      // the session start; otherwise fall back to midnight today so it still
      // shows today's cash activity (mirrors the restaurant side staying open).
      final dayStart = _dayStart ?? DateTime(now.year, now.month, now.day);

      // Manual Cash In / Out movements
      await cashMovementStore.loadTodayMovements(dayStart);

      // Retail cash sales for the day
      final sales = await saleStore.getSalesByDateRange(dayStart, now);
      final saleEntries = <_LogEntry>[];
      double cashSales = 0.0;
      for (final s in sales) {
        if (s.isReturn == true) continue;
        final cash = _cashComponentOf(s);
        if (cash <= 0) continue;
        cashSales += cash;
        saleEntries.add(
          _LogEntry(
            time: DateTime.tryParse(s.date) ?? dayStart,
            description: s.isSplitPayment == true
                ? 'Sale (cash portion)'
                : 'Cash Sale',
            signedAmount: cash,
            type: _LogType.sale,
          ),
        );
      }
      _cashSales = cashSales;

      // Cash expenses for the day
      await expenseStore.loadExpenses();
      final cashExp = expenseStore.expenses.where((e) {
        final isCash = (e.paymentType ?? '').toLowerCase().trim() == 'cash';
        final inRange =
            e.dateandTime.isAfter(
              dayStart.subtract(const Duration(seconds: 1)),
            ) &&
            !e.dateandTime.isAfter(now);
        return isCash && inRange;
      }).toList();
      _cashExpenses = cashExp.fold(0.0, (sum, e) => sum + e.amount);
      final expenseEntries = cashExp
          .map(
            (e) => _LogEntry(
              time: e.dateandTime,
              description: 'Expense${e.reason != null ? ' — ${e.reason}' : ''}',
              signedAmount: -e.amount,
              type: _LogType.expense,
            ),
          )
          .toList();

      _buildLog(dayStart, saleEntries, expenseEntries);
    } catch (e) {
      // Never leave the screen stuck on the spinner — show whatever loaded.
      debugPrint('Cash Drawer load failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Net cash component of a sale. For split payments, only the cash slice
  /// counts; for single payment, the whole total if it was cash. Mirrors the
  /// EOD service so the drawer and EOD never disagree.
  double _cashComponentOf(SaleModel s) {
    if (s.isSplitPayment == true &&
        s.paymentListJson != null &&
        s.paymentListJson!.isNotEmpty) {
      return s.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (a, p) => a + ((p['amount'] as num?)?.toDouble() ?? 0.0));
    }
    if (s.paymentType.toLowerCase().trim() == 'cash') {
      return s.totalAmount;
    }
    return 0.0;
  }

  void _buildLog(
    DateTime dayStart,
    List<_LogEntry> sales,
    List<_LogEntry> expenses,
  ) {
    final entries = <_LogEntry>[
      _LogEntry(
        time: dayStart,
        description: 'Opening Balance',
        signedAmount: _openingBalance,
        type: _LogType.opening,
      ),
      ...sales,
      ...expenses,
    ];

    // Manual movements (skip 'opening' — already shown by synthetic entry above)
    for (final m in cashMovementStore.movements) {
      if (m.type == 'opening' || m.type == 'adjustment') continue;
      entries.add(
        _LogEntry(
          time: m.timestamp,
          description: m.label,
          signedAmount: m.signedAmount,
          type: _LogType.movement,
        ),
      );
    }

    entries.sort((a, b) => a.time.compareTo(b.time));

    double running = 0.0;
    for (final e in entries) {
      running += e.signedAmount;
      e.runningBalance = running;
    }
    _log = entries;
  }

  /// Live balance: Opening + Cash Sales + Cash In − Cash Out − Cash Expenses
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
    final isCashIn = type == 'in';

    const cashInReasons = [
      'Owner deposit',
      'Petty cash return',
      'Change fund',
      'Other',
    ];
    const cashOutReasons = [
      'Petty cash',
      'Supplier payment',
      'Advance to staff',
      'Other',
    ];
    final reasons = isCashIn ? cashInReasons : cashOutReasons;
    String selectedReason = reasons.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isCashIn ? Colors.green : Colors.red).withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCashIn
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: isCashIn ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCashIn ? 'Cash In' : 'Cash Out',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: amountCtrl,
                      label: 'Amount',
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      prefixWidget: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        child: Text(
                          CurrencyHelper.currentSymbol,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        prefixIcon: const Icon(
                          Icons.list_alt_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: reasons
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r,
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDs(() => selectedReason = v ?? reasons.first),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: noteCtrl,
                      label: 'Note',
                      hint: 'Add extra details... (optional)',
                      icon: Icons.notes_rounded,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                                content: Text('Enter a valid amount'),
                              ),
                            );
                            return;
                          }
                          // Warn if Cash Out would drive the drawer negative.
                          if (type == 'out' && amount > _balance) {
                            final proceed = await showDialog<bool>(
                              context: ctx,
                              builder: (warnCtx) => AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Balance Warning'),
                                  ],
                                ),
                                content: Text(
                                  'This withdrawal (${CurrencyHelper.currentSymbol}${amount.toStringAsFixed(DecimalSettings.precision)}) '
                                  'exceeds the estimated drawer balance '
                                  '(${CurrencyHelper.currentSymbol}${_balance.toStringAsFixed(DecimalSettings.precision)}). '
                                  'Proceed only if you have physically verified the cash.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(warnCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(warnCtx, true),
                                    child: const Text(
                                      'Proceed Anyway',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
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
                          if (ok) await _loadAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCashIn ? Colors.green : Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isCashIn ? 'Add Cash In' : 'Add Cash Out',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Cash Drawer',
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Observer(builder: (_) => _buildBody(context, currency)),
    );
  }

  Widget _buildBody(BuildContext context, String currency) {
    return ListView(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      children: [
        _buildBalanceCard(context, currency),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildActionButtons(context),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildBreakdownRow(context, currency),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildActivityLog(context, currency),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, String currency) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(
          AppResponsive.largeBorderRadius(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Cash in Drawer',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            '$currency ${_balance.toStringAsFixed(DecimalSettings.precision)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue<double>(
                context,
                mobile: 32,
                tablet: 38,
                desktop: 44,
              ),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            'Opening ${_openingBalance.toStringAsFixed(0)}  '
            '+ Sales ${_cashSales.toStringAsFixed(0)}  '
            '+ In ${cashMovementStore.totalCashIn.toStringAsFixed(0)}  '
            '− Out ${cashMovementStore.totalCashOut.toStringAsFixed(0)}  '
            '− Exp ${_cashExpenses.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showMovementDialog('in'),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: Text(
              'Cash In',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context) + 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showMovementDialog('out'),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            label: Text(
              'Cash Out',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context) + 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String currency) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _breakdownLine(
            context,
            'Opening Balance',
            _openingBalance,
            currency,
            Colors.blue,
            true,
          ),
          _breakdownLine(
            context,
            'Cash Sales',
            _cashSales,
            currency,
            Colors.green,
            true,
          ),
          _breakdownLine(
            context,
            'Cash In',
            cashMovementStore.totalCashIn,
            currency,
            Colors.teal,
            true,
          ),
          _breakdownLine(
            context,
            'Cash Out',
            cashMovementStore.totalCashOut,
            currency,
            Colors.orange,
            false,
          ),
          _breakdownLine(
            context,
            'Cash Expenses',
            _cashExpenses,
            currency,
            Colors.red,
            false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expected in Drawer',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$currency ${_balance.toStringAsFixed(DecimalSettings.precision)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownLine(
    BuildContext context,
    String label,
    double amount,
    String currency,
    Color color,
    bool isPositive,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            '${isPositive ? '+' : '−'} $currency ${amount.toStringAsFixed(DecimalSettings.precision)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLog(BuildContext context, String currency) {
    if (_log.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
          child: Text(
            'No activity yet today',
            style: GoogleFonts.poppins(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
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
    }

    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}';
    final isPositive = entry.signedAmount >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.largeSpacing(context),
        vertical: AppResponsive.smallSpacing(context) + 2,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              dotIcon,
              size: AppResponsive.smallIconSize(context),
              color: dotColor,
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  timeStr,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}$currency ${entry.signedAmount.abs().toStringAsFixed(DecimalSettings.precision)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.smallFontSize(context),
                  color: isPositive
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              Text(
                'Bal: $currency ${entry.runningBalance.toStringAsFixed(DecimalSettings.precision)}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
