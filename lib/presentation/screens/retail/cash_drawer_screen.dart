import 'package:flutter/material.dart';
import 'package:billberrylite/util/retail/cash_drawer_ledger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

/// Retail Cash Drawer.
///
/// A lean adaptation of the restaurant Cash Drawer: it reuses the same
/// cash-movement engine (CashMovementStore) and Cash In/Out dialog, but sources
/// sales from the retail [saleStore] and drops restaurant-only concepts
/// (shifts, cash handover). The estimated drawer balance is:
///   Opening + Cash Sales + Cash In − Cash Out − Cash Expenses − Cash Refunds
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

enum _LogType { opening, sale, refund, expense, movement }

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
  double _cashRefunds = 0.0;

  /// Net collected per payment method (sales minus returns), for the Sales
  /// Summary card. Informational only — the drawer balance stays cash-only,
  /// because card/UPI never enter the till.
  final Map<String, double> _netByMethod = {};

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
      _netByMethod.clear();
      final saleEntries = <_LogEntry>[];
      final refundEntries = <_LogEntry>[];
      double cashSales = 0.0;
      double cashRefunds = 0.0;
      for (final s in sales) {
        // A cash refund physically empties the till, so it belongs here.
        // Derived from the return sale rather than from the audit movement
        // ReturnService writes — that movement carries a distinct 'refund'
        // type and is skipped below, which is what prevents double counting.
        // Deriving also corrects refunds taken before the audit trail existed.
        if (s.isReturn == true) {
          // Returns carry a negative totalAmount, so adding them nets the
          // method down automatically — including card/UPI refunds, which
          // belong in the summary even though they never touch the drawer.
          _addToMethod(s.paymentType, s.totalAmount);
          // The SHARED rule, not a local one. This used to read
          // `s.paymentType == 'cash' ? s.totalAmount.abs() : 0`, which ignored
          // the stored payment legs: an exchange return booked the whole value
          // of the goods handed back as cash out, when only the difference
          // left the till, and a split refund headed 'card' with a cash leg
          // was skipped entirely. The Cash Drawer History report already used
          // `cashRefundOf`, so the two screens disagreed on real money.
          final refunded = CashDrawerLedger.cashRefundOf(s);
          if (refunded <= 0) continue;
          cashRefunds += refunded;
          refundEntries.add(
            _LogEntry(
              time: DateTime.tryParse(s.date) ?? dayStart,
              description: 'Cash Refund',
              signedAmount: -refunded,
              type: _LogType.refund,
            ),
          );
          continue;
        }
        _accumulateMethods(s);
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
      _cashRefunds = cashRefunds;

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

      _buildLog(dayStart, saleEntries, refundEntries, expenseEntries);
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
  /// Shared with the Cash Drawer History report — see [CashDrawerLedger].
  double _cashComponentOf(SaleModel s) => CashDrawerLedger.cashComponentOf(s);

  void _addToMethod(String? method, double amount) {
    final key = (method ?? '').toLowerCase().trim();
    if (key.isEmpty) return;
    _netByMethod[key] = (_netByMethod[key] ?? 0) + amount;
  }

  /// Splits a sale across its payment methods. Uses `paymentListJson` when the
  /// sale was split, exactly like [_cashComponentOf], so the summary and the
  /// drawer balance can never disagree about the cash slice.
  void _accumulateMethods(SaleModel s) {
    if (s.isSplitPayment == true &&
        s.paymentListJson != null &&
        s.paymentListJson!.isNotEmpty) {
      for (final p in s.paymentList) {
        _addToMethod(
          p['method'] as String?,
          (p['amount'] as num?)?.toDouble() ?? 0.0,
        );
      }
      return;
    }
    _addToMethod(s.paymentType, s.totalAmount);
  }

  double _method(String key) => _netByMethod[key] ?? 0.0;

  /// Anything that isn't one of the named methods, so a new payment type still
  /// appears rather than silently vanishing from the summary.
  double get _otherCollected {
    const named = {'cash', 'card', 'upi', 'credit'};
    return _netByMethod.entries
        .where((e) => !named.contains(e.key))
        .fold(0.0, (sum, e) => sum + e.value);
  }

  /// Money actually taken this session. Credit is excluded — it's billed, not
  /// collected, so folding it in would overstate what came in.
  double get _collectedRevenue =>
      _method('cash') + _method('card') + _method('upi') + _otherCollected;

  void _buildLog(
    DateTime dayStart,
    List<_LogEntry> sales,
    List<_LogEntry> refunds,
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
      ...refunds,
      ...expenses,
    ];

    // Manual movements (skip 'opening' — already shown by synthetic entry above)
    for (final m in cashMovementStore.movements) {
      // 'refund' rows are audit-only; the derived Cash Refund entries above
      // already account for them.
      // Same rule the history report applies.
      if (!CashDrawerLedger.isLedgerMovement(m)) {
        continue;
      }
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

  /// Live balance:
  /// Opening + Cash Sales + Cash In − Cash Out − Cash Expenses − Cash Refunds
  double get _balance =>
      _openingBalance +
      _cashSales +
      cashMovementStore.totalCashIn -
      cashMovementStore.totalCashOut -
      _cashExpenses -
      _cashRefunds;

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

    final accent = isCashIn ? AppColors.success : AppColors.danger;

    await showDialog(
      context: context,
      // Scope disposes both controllers when the route pops — they were
      // previously created and never disposed.
      builder: (ctx) => DialogDisposeScope(
        disposables: [amountCtrl, noteCtrl],
        child: StatefulBuilder(
          builder: (ctx, setDs) => AppDialogShell(
            title: isCashIn ? 'Cash In' : 'Cash Out',
            subtitle: isCashIn
                ? 'Money added to the drawer'
                : 'Money taken out of the drawer',
            accent: accent,
            icon: isCashIn
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: amountCtrl,
                  label: 'Amount',
                  hint: '0.00',
                  required: true,
                  autofocus: true,
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
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                // Styled to match AppTextField rather than a bare
                // OutlineInputBorder, so the three fields read as one form.
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  // M3 tints dropdown menu surfaces by default, which renders
                  // the open list grey-lavender instead of white. Same override
                  // the supplier popup menu uses.
                  dropdownColor: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    labelStyle: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    prefixIcon: Icon(
                      Icons.list_alt_rounded,
                      color: AppColors.primary,
                      size: AppResponsive.iconSize(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  items: reasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDs(() => selectedReason = v ?? reasons.first),
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                AppTextField(
                  controller: noteCtrl,
                  label: 'Note',
                  hint: 'Add extra details... (optional)',
                  icon: Icons.notes_rounded,
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(ctx),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: isCashIn ? 'Add Cash In' : 'Add Cash Out',
                color: accent,
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amount <= 0) {
                    NotificationService.instance.showError(
                      'Enter a valid amount',
                    );
                    return;
                  }
                  // Warn if Cash Out would drive the drawer negative.
                  if (type == 'out' && amount > _balance) {
                    final proceed = await showAppConfirmDialog(
                      context: ctx,
                      title: 'Balance Warning',
                      message:
                          'This withdrawal (${CurrencyHelper.currentSymbol}${amount.toStringAsFixed(DecimalSettings.precision)}) '
                          'exceeds the estimated drawer balance '
                          '(${CurrencyHelper.currentSymbol}${_balance.toStringAsFixed(DecimalSettings.precision)}). '
                          'Proceed only if you have physically verified the cash.',
                      confirmLabel: 'Proceed Anyway',
                      accent: AppColors.warning,
                      icon: Icons.warning_amber_rounded,
                    );
                    if (!proceed) return;
                  }
                  // The warning dialog above is an await, so this dialog may
                  // already be gone by the time we pop it.
                  if (!ctx.mounted) return;
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
      appBar: buildPrimaryAppBar(title: 'Cash Drawer'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Observer(builder: (_) => _buildBody(context, currency)),
    );
  }

  /// Caps content width on large screens so the drawer cards don't stretch
  /// across a laptop.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxContentWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter, not Center: Center aligns on BOTH axes, so a
      // shrink-wrapping child floats in the vertical middle.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildBody(BuildContext context, String currency) {
    return _capped(
      context,
      ListView(
        padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
        children: [
          _buildBalanceCard(context, currency),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildActionButtons(context),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildBreakdownRow(context, currency),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildSalesSummaryCard(context, currency),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildActivityLog(context, currency),
        ],
      ),
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
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            'Opening ${_openingBalance.toStringAsFixed(0)}  '
            '+ Sales ${_cashSales.toStringAsFixed(0)}  '
            '+ In ${cashMovementStore.totalCashIn.toStringAsFixed(0)}  '
            '− Out ${cashMovementStore.totalCashOut.toStringAsFixed(0)}  '
            '− Exp ${_cashExpenses.toStringAsFixed(0)}'
            '${_cashRefunds > 0 ? '  − Refunds ${_cashRefunds.toStringAsFixed(0)}' : ''}',
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
          if (_cashRefunds > 0)
            _breakdownLine(
              context,
              'Cash Refunds',
              _cashRefunds,
              currency,
              AppColors.danger,
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
          // Expanded label / Flexible amount — neither was bounded, so a long
          // reason plus a five-figure amount overflowed a narrow card.
          Expanded(
            child: Row(
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
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : '−'} $currency ${amount.toStringAsFixed(DecimalSettings.precision)}',
            maxLines: 1,
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

  // ── Sales summary (all payment methods) ──────────────────────────────────

  /// Collections by payment method, in the same visual language as the drawer
  /// breakdown above — coloured rule, label, amount, then a divider before the
  /// total.
  ///
  /// Sits OUTSIDE the drawer balance on purpose: a cash drawer holds cash, so
  /// card and UPI must never move that number. The restaurant drawer makes the
  /// same split (balance card + "Shift Sales Summary"); this is its retail
  /// counterpart. Net of refunds — a card refund reduces the Card line without
  /// touching the till.
  Widget _buildSalesSummaryCard(BuildContext context, String currency) {
    final credit = _method('credit');
    final other = _otherCollected;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: AppResponsive.smallIconSize(context),
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Sales Summary',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),

          _breakdownLine(
            context,
            'Cash',
            _method('cash'),
            currency,
            Colors.green,
            true,
          ),
          _breakdownLine(
            context,
            'Card',
            _method('card'),
            currency,
            Colors.blue,
            true,
          ),
          _breakdownLine(
            context,
            'UPI',
            _method('upi'),
            currency,
            Colors.purple,
            true,
          ),
          if (other != 0)
            _breakdownLine(
              context,
              'Other',
              other,
              currency,
              Colors.teal,
              true,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collected Today',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$currency ${_collectedRevenue.toStringAsFixed(DecimalSettings.precision)}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          // Credit is billed, not collected. Kept under the total so it can
          // never be read as money in hand — retail has pay-later, which the
          // restaurant drawer never has to account for.
          if (credit != 0) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _breakdownLine(
              context,
              'Credit (unpaid)',
              credit,
              currency,
              AppColors.warning,
              true,
            ),
          ],
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
      case _LogType.refund:
        dotColor = AppColors.danger;
        dotIcon = Icons.assignment_return_outlined;
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  timeStr,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}$currency ${entry.signedAmount.abs().toStringAsFixed(DecimalSettings.precision)}',
                maxLines: 1,
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
                maxLines: 1,
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
