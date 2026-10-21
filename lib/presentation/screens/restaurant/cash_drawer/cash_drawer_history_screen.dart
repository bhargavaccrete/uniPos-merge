import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_handover_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_step_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';

// ─── Draft model (pre-sort, no running balance yet) ──────────────────────────

class _RowDraft {
  final DateTime timestamp;
  final String typeName;
  final Color typeColor;
  final String staffName;
  final double inAmount;
  final double outAmount;
  final String reason;
  final String? note;
  final bool isAuditOnly;

  _RowDraft({
    required this.timestamp,
    required this.typeName,
    required this.typeColor,
    required this.staffName,
    required this.inAmount,
    required this.outAmount,
    required this.reason,
    this.note,
    this.isAuditOnly = false,
  });
}

// ─── Row model ────────────────────────────────────────────────────────────────

class _HistoryRow {
  final DateTime timestamp;
  final String typeName;
  final Color typeColor;
  final String staffName;
  final double inAmount; // positive = cash added
  final double outAmount; // positive = cash removed
  final double runningBalance; // drawer total AFTER this entry
  final String reason;
  final String? note;
  final bool isAuditOnly; // true for adjustments / discrepancies

  const _HistoryRow({
    required this.timestamp,
    required this.typeName,
    required this.typeColor,
    required this.staffName,
    required this.inAmount,
    required this.outAmount,
    required this.runningBalance,
    required this.reason,
    this.note,
    this.isAuditOnly = false,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CashDrawerHistoryScreen extends StatefulWidget {
  const CashDrawerHistoryScreen({super.key});

  @override
  State<CashDrawerHistoryScreen> createState() =>
      _CashDrawerHistoryScreenState();
}

class _CashDrawerHistoryScreenState extends State<CashDrawerHistoryScreen> {
  bool _isLoading = true;
  bool _isDataLoaded = false;

  List<_HistoryRow> _allRows = [];
  List<_HistoryRow> _filteredRows = [];

  /// This ledger reads one day at a time — a drawer is opened, worked and
  /// closed within a day, and the running balance only means anything inside
  /// one. A from/to pair implied a range the report never really wanted.
  DateTime _selectedDate = DateTime.now();
  String _typeFilter = 'All';

  /// Movement types, not reporting periods — this ledger filters by what the
  /// cash did, so it feeds the generic ReportFilterBar rather than adopting
  /// ReportPeriodFilterBar. The day stays on its own step bar above.
  static const _typeOptions = [
    ReportFilterOption(
      value: 'All',
      label: 'All',
      icon: Icons.list_alt_rounded,
    ),
    ReportFilterOption(
      value: 'Opening',
      label: 'Opening',
      icon: Icons.play_circle_outline,
    ),
    ReportFilterOption(value: 'Sale', label: 'Sale', icon: Icons.point_of_sale),
    ReportFilterOption(
      value: 'Refund',
      label: 'Refund',
      icon: Icons.undo_rounded,
    ),
    ReportFilterOption(
      value: 'Expense',
      label: 'Expense',
      icon: Icons.receipt_long_outlined,
    ),
    ReportFilterOption(
      value: 'Cash In',
      label: 'Cash In',
      icon: Icons.arrow_downward_rounded,
    ),
    ReportFilterOption(
      value: 'Cash Out',
      label: 'Cash Out',
      icon: Icons.arrow_upward_rounded,
    ),
    ReportFilterOption(
      value: 'Withdrawal',
      label: 'Withdrawal',
      icon: Icons.account_balance_outlined,
    ),
    ReportFilterOption(
      value: 'Adjustment',
      label: 'Adjustment',
      icon: Icons.tune_rounded,
    ),
    ReportFilterOption(
      value: 'Shift End',
      label: 'Shift End',
      icon: Icons.stop_circle_outlined,
    ),
  ];

  // Pre-computed summary totals
  double _totalIn = 0.0;
  double _totalOut = 0.0;
  double _net = 0.0;

  // ── Init ────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadHistory({bool forceReload = false}) async {
    if (_isDataLoaded && !forceReload) {
      _applyFilter();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final drafts = <_RowDraft>[];

      // ── Source 1: Manual cash movements (opening, cash in/out, adjustments) ─
      final box = Hive.box<CashMovementModel>(
        HiveBoxNames.restaurantCashMovements,
      );
      for (final m in box.values) {
        String typeName;
        Color typeColor;
        double inAmt = 0.0;
        double outAmt = 0.0;
        bool auditOnly = false;

        switch (m.type) {
          case 'opening':
            typeName = 'Opening';
            typeColor = Colors.blue.shade700;
            inAmt = m.amount;
          case 'in':
            typeName = 'Cash In';
            typeColor = Colors.green.shade700;
            inAmt = m.amount;
          case 'out':
            final isEOD =
                m.reason.toLowerCase().contains('safe drop') ||
                m.reason.toLowerCase().contains('end of day');
            typeName = isEOD ? 'Withdrawal' : 'Cash Out';
            typeColor = Colors.red.shade700;
            outAmt = m.amount;
          case 'adjustment':
            final isDiscrepancy =
                m.reason.toLowerCase().contains('shortage') ||
                m.reason.toLowerCase().contains('overage') ||
                m.reason.toLowerCase().contains('discrepancy');
            typeName = isDiscrepancy ? 'Discrepancy' : 'Adjustment';
            typeColor = Colors.orange.shade700;
            auditOnly = true;
            if (m.amount >= 0) {
              inAmt = m.amount;
            } else {
              outAmt = m.amount.abs();
            }
          default:
            typeName = m.type;
            typeColor = Colors.grey;
            if (m.amount >= 0) {
              inAmt = m.amount;
            } else {
              outAmt = m.amount.abs();
            }
        }

        drafts.add(
          _RowDraft(
            timestamp: m.timestamp,
            typeName: typeName,
            typeColor: typeColor,
            staffName: m.staffName,
            inAmount: inAmt,
            outAmount: outAmt,
            reason: m.reason,
            note: m.note,
            isAuditOnly: auditOnly,
          ),
        );
      }

      // ── Source 2: Cash sales from orders ──────────────────────────────────
      await pastOrderStore.loadPastOrders();
      await shiftStore.loadShifts();

      // Build lookup maps for resolving staff names
      final shiftIdToName = <String, String>{
        for (final s in shiftStore.shifts) s.id: s.staffName,
      };
      // Time-window fallback: find which shift was active at a given time
      String staffAtTime(DateTime time) {
        for (final s in shiftStore.shifts) {
          final end = s.endTime ?? DateTime.now();
          // Half-open: [startTime, end]
          if (!time.isBefore(s.startTime) && !time.isAfter(end)) {
            return s.staffName;
          }
        }
        return '';
      }

      for (final o in pastOrderStore.pastOrders) {
        final status = (o.orderStatus ?? '').toUpperCase();
        if (status == 'VOID' || status == 'CANCELLED') continue;
        if (o.orderAt == null) continue;

        final originalCash = _originalCashComponentOf(o);
        if (originalCash <= 0) continue;

        final billNo = o.billNumber ?? o.id.substring(0, 6);
        final saleStaff =
            (o.shiftId != null ? shiftIdToName[o.shiftId] : null) ??
            staffAtTime(o.orderAt!);

        // 1. Add Sale entry
        final saleLabel = o.isSplitPayment == true
            ? 'Bill #$billNo (cash portion)'
            : 'Bill #$billNo';
        drafts.add(
          _RowDraft(
            timestamp: o.orderAt!,
            typeName: 'Sale',
            typeColor: Colors.green.shade600,
            staffName: saleStaff,
            inAmount: originalCash,
            outAmount: 0.0,
            reason: saleLabel,
          ),
        );

        // 2. Add Refund entry if there is a refund
        final refundCash = _cashRefundComponentOf(o);
        if (refundCash > 0) {
          final refundLabel = o.isSplitPayment == true
              ? 'Refund for Bill #$billNo (cash portion)'
              : 'Refund for Bill #$billNo';
          final refundTime = o.refundedAt ?? o.orderAt!;
          final refundStaff = o.refundedAt != null
              ? staffAtTime(o.refundedAt!)
              : saleStaff;

          drafts.add(
            _RowDraft(
              timestamp: refundTime,
              typeName: 'Refund',
              typeColor: Colors.red.shade700,
              staffName: refundStaff,
              inAmount: 0.0,
              outAmount: refundCash,
              reason: refundLabel,
            ),
          );
        }
      }

      // ── Source 3: Cash expenses ────────────────────────────────────────────
      await expenseStore.loadExpenses();
      await expenseCategoryStore.loadCategories();
      final categoryIdToName = <String, String>{
        for (final c in expenseCategoryStore.categories) c.id: c.name,
      };

      for (final e in expenseStore.expenses) {
        if ((e.paymentType ?? '').toLowerCase().trim() != 'cash') continue;
        final catName = categoryIdToName[e.categoryOfExpense] ?? 'Expense';
        final desc = e.reason != null && e.reason!.isNotEmpty
            ? 'Expense — $catName (${e.reason})'
            : 'Expense — $catName';

        drafts.add(
          _RowDraft(
            timestamp: e.dateandTime,
            typeName: 'Expense',
            typeColor: Colors.deepOrange.shade600,
            staffName: staffAtTime(e.dateandTime),
            inAmount: 0.0,
            outAmount: e.amount,
            reason: desc,
          ),
        );
      }

      // ── Source 4: Shift-end handover records ──────────────────────────────
      final handoverBox = Hive.box<CashHandoverModel>(
        HiveBoxNames.restaurantCashHandovers,
      );
      final currency = CurrencyHelper.currentSymbol;
      for (final h in handoverBox.values) {
        if (h.status == 'PENDING') continue; // skip incomplete legacy records
        final isSystem = h.receivedBy == 'System';
        final isMismatch = h.status == 'DISCREPANCY';
        final variance = h.variance ?? 0.0;
        String reason;
        if (isSystem) {
          // Single-step record
          final counted = '$currency${h.closedAmount.toStringAsFixed(2)}';
          final expected =
              '$currency${(h.receivedAmount ?? 0).toStringAsFixed(2)}';
          reason = isMismatch
              ? 'Shift end — ${h.closedBy} counted $counted, POS expected $expected'
              : 'Shift end — ${h.closedBy} counted $counted ✓ matches POS';
        } else {
          // Legacy 2-step record
          final v = variance >= 0
              ? '+$currency${variance.toStringAsFixed(2)}'
              : '-$currency${variance.abs().toStringAsFixed(2)}';
          reason = isMismatch
              ? 'Handover ${h.closedBy}→${h.receivedBy} — variance $v'
              : 'Handover ${h.closedBy}→${h.receivedBy} ✓ matched';
        }
        drafts.add(
          _RowDraft(
            timestamp: h.closedAt,
            typeName: 'Shift End',
            typeColor: isMismatch
                ? Colors.orange.shade700
                : Colors.teal.shade600,
            staffName: h.closedBy,
            inAmount: 0.0,
            outAmount: 0.0,
            reason: reason,
            note: h.closedNote,
            isAuditOnly: true,
          ),
        );
      }

      // ── Sort all events chronologically ───────────────────────────────────
      drafts.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // ── Single pass: compute running balance ──────────────────────────────
      // Adjustments are audit-only — they do NOT move the drawer balance.
      double running = 0.0;
      final rows = <_HistoryRow>[];
      for (final d in drafts) {
        if (!d.isAuditOnly) {
          running += d.inAmount - d.outAmount;
        }
        rows.add(
          _HistoryRow(
            timestamp: d.timestamp,
            typeName: d.typeName,
            typeColor: d.typeColor,
            staffName: d.staffName,
            inAmount: d.inAmount,
            outAmount: d.outAmount,
            runningBalance: running,
            reason: d.reason,
            note: d.note,
            isAuditOnly: d.isAuditOnly,
          ),
        );
      }

      _allRows = rows.reversed.toList(); // newest first
      _isDataLoaded = true;
      _applyFilter();
    } catch (e) {
      debugPrint('Cash drawer history load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Returns the original cash component of an order (before refund).
  double _originalCashComponentOf(PastOrderModel o) {
    if (o.isSplitPayment == true) {
      return o.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));
    }
    final method = (o.paymentmode ?? '').toLowerCase().trim();
    if (method == 'cash') {
      return o.totalPrice;
    }
    return 0.0;
  }

  /// Returns the cash portion of the refund for an order.
  double _cashRefundComponentOf(PastOrderModel o) {
    final refund = o.refundAmount ?? 0.0;
    if (refund <= 0) return 0.0;
    if (o.isSplitPayment == true) {
      final rawCash = o.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));
      if (o.totalPrice > 0) {
        return refund * (rawCash / o.totalPrice);
      }
    }
    final method = (o.paymentmode ?? '').toLowerCase().trim();
    if (method == 'cash') {
      return refund;
    }
    return 0.0;
  }

  // ── Day selection ───────────────────────────────────────────────────────────

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _stepDay(int delta) {
    final next = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + delta,
    );
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = next);
    _applyFilter();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      // The picker's colours come from Theme.datePickerTheme, which main.dart
      // never sets — so by default it renders in Material 3's own palette, a
      // lavender-tinted surface under a blue-violet header. A ColorScheme
      // override alone does NOT fix that: M3 tints the surface by elevation,
      // so surfaceTintColor has to be cleared explicitly.
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppColors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: AppColors.primary,
            headerForegroundColor: AppColors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            todayBorder: const BorderSide(color: AppColors.primary),
            dayBackgroundColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.selected) ? AppColors.primary : null,
            ),
            dayForegroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.white
                  : AppColors.textPrimary,
            ),
            todayForegroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.white
                  : AppColors.primary,
            ),
            yearBackgroundColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.selected) ? AppColors.primary : null,
            ),
            yearForegroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.white
                  : AppColors.textPrimary,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    _applyFilter();
  }

  void _applyFilter() {
    // Half-open: [from, toExclusive) — the selected day, midnight to midnight.
    final d = _selectedDate;
    final from = DateTime(d.year, d.month, d.day);
    final toExclusive = DateTime(d.year, d.month, d.day + 1);

    final results = <_HistoryRow>[];
    double inSum = 0.0;
    double outSum = 0.0;

    for (final r in _allRows) {
      if (r.timestamp.isBefore(from) || !r.timestamp.isBefore(toExclusive)) {
        continue;
      }
      if (_typeFilter != 'All') {
        if (_typeFilter == 'Adjustment') {
          if (r.typeName != 'Adjustment' && r.typeName != 'Discrepancy') {
            continue;
          }
        } else if (r.typeName != _typeFilter) {
          continue;
        }
      }
      results.add(r);
      inSum += r.inAmount;
      outSum += r.outAmount;
    }

    setState(() {
      _filteredRows = results;
      _totalIn = inSum;
      _totalOut = outSum;
      _net = inSum - outSum;
    });
  }

  // ── Export (Excel + PDF via the shared report service) ──────────────────────
  // Routes through ReportExportService so the drawer ledger exports to BOTH
  // Excel and PDF, consistent with every other report.

  Future<void> _exportReport() async {
    final fmt = DateFormat('dd MMM yyyy  HH:mm');
    final dateFmt = DateFormat('dd MMM yyyy');

    final headers = [
      'Date / Time',
      'Type',
      'Staff',
      'In',
      'Out',
      'Balance',
      'Reason / Note',
    ];

    final data = _filteredRows
        .map(
          (r) => [
            fmt.format(r.timestamp),
            r.typeName,
            r.staffName,
            r.inAmount > 0
                ? ReportExportService.formatCurrency(r.inAmount)
                : '—',
            r.outAmount > 0
                ? ReportExportService.formatCurrency(r.outAmount)
                : '—',
            ReportExportService.formatCurrency(r.runningBalance),
            (r.note != null && r.note!.isNotEmpty)
                ? '${r.reason} — ${r.note}'
                : r.reason,
          ],
        )
        .toList();

    final periodName = dateFmt.format(_selectedDate);
    final summary = {
      'Report Period': periodName,
      'Total In': ReportExportService.formatCurrency(_totalIn),
      'Total Out': ReportExportService.formatCurrency(_totalOut),
      'Net': ReportExportService.formatCurrency(_net),
      'Entries': _filteredRows.length.toString(),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName:
          'cash_drawer_history_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Cash Drawer History - $periodName',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Cash Drawer History',
        subtitle: 'Full audit trail — every cash movement',
      ),
      body: Column(
        children: [
          if (!_isLoading) ...[
            // The day comes first — it's this ledger's scope; the type chips
            // below only refine what's already in that day. Stepping matters
            // here: checking yesterday's drawer is one tap, not a dialog.
            ReportDateStepBar(
              value: _selectedDate,
              label: DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
              onPrevious: () => _stepDay(-1),
              // Null at today so the ledger can't run into the future.
              onNext: _isToday(_selectedDate) ? null : () => _stepDay(1),
              onPick: _pickDay,
            ),
            ReportFilterBar<String>(
              options: _typeOptions,
              selected: _typeFilter,
              onSelected: (option) {
                setState(() => _typeFilter = option);
                _applyFilter();
              },
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ],
          Expanded(child: _buildContent(context, currency)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, String currency) {
    if (_isLoading) return const ReportLoading();
    if (_filteredRows.isEmpty) return _buildEmpty(context);

    return ReportBody(
      child: Column(
        children: [
          _buildSummaryCards(context, currency),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: _exportReport),
          AppResponsive.verticalSpace(context),
          _buildTable(context, currency),
        ],
      ),
    );
  }

  // ── Summary bar ──────────────────────────────────────────────────────────────

  /// Two rows of two, as in totalsales/refunddetails — four cards abreast
  /// leaves each ~78px on a 360px phone and ellipsises every title.
  Widget _buildSummaryCards(BuildContext context, String currency) {
    final netColor = _net >= 0 ? Colors.teal.shade700 : Colors.red.shade700;
    return Column(
      children: [
        ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Total In',
              value: '$currency${DecimalSettings.formatAmount(_totalIn)}',
              icon: Icons.arrow_downward_rounded,
              color: Colors.green.shade700,
            ),
            ReportSummaryCard(
              title: 'Total Out',
              value: '$currency${DecimalSettings.formatAmount(_totalOut)}',
              icon: Icons.arrow_upward_rounded,
              color: Colors.red.shade700,
            ),
          ],
        ),
        AppResponsive.verticalSpace(context),
        ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Net',
              value: '$currency${DecimalSettings.formatAmount(_net)}',
              icon: Icons.account_balance_wallet_outlined,
              color: netColor,
            ),
            ReportSummaryCard(
              title: 'Entries',
              value: '${_filteredRows.length}',
              icon: Icons.list_alt_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) => const ReportEmptyState(
    icon: Icons.history_outlined,
    title: 'No transactions found',
    message: 'Try widening the date range or changing the filter',
  );

  // ── Table ────────────────────────────────────────────────────────────────────

  Widget _buildTable(BuildContext context, String currency) {
    final dateFmt = DateFormat('dd MMM');
    final timeFmt = DateFormat('HH:mm');
    final isMobile =
        !AppResponsive.isTablet(context) && !AppResponsive.isDesktop(context);

    return isMobile
        ? _buildMobileList(context, currency, dateFmt, timeFmt)
        : _buildDesktopTable(context, currency, dateFmt, timeFmt);
  }

  // ── Mobile card list ─────────────────────────────────────────────────────────

  Widget _buildMobileList(
    BuildContext context,
    String currency,
    DateFormat dateFmt,
    DateFormat timeFmt,
  ) {
    // A plain Column, not a ListView: ReportBody already scrolls and supplies
    // the padding + width cap, so a nested scrollable would fight it.
    return Column(
      children: _filteredRows
          .map((r) => _mobileCard(context, r, currency, dateFmt, timeFmt))
          .toList(),
    );
  }

  Widget _mobileCard(
    BuildContext context,
    _HistoryRow r,
    String currency,
    DateFormat dateFmt,
    DateFormat timeFmt,
  ) {
    final inColor = r.isAuditOnly
        ? Colors.orange.shade700
        : Colors.green.shade700;
    final outColor = r.isAuditOnly
        ? Colors.orange.shade700
        : Colors.red.shade700;
    final balColor = r.isAuditOnly
        ? Colors.orange.shade700
        : r.runningBalance < 0
        ? Colors.red.shade700
        : AppColors.textPrimary;

    return GestureDetector(
      onTap: r.note != null ? () => _showNote(context, r) : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: r.isAuditOnly ? Colors.orange.shade200 : AppColors.divider,
          ),
        ),
        color: r.isAuditOnly ? Colors.orange.shade50 : AppColors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: badge + date/time ──────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: r.typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.typeName,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: r.typeColor,
                      ),
                    ),
                  ),
                  if (r.isAuditOnly) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'audit',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (r.staffName.isNotEmpty) ...[
                    Icon(
                      Icons.person_outline,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${r.staffName}  ',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  Text(
                    '${dateFmt.format(r.timestamp)}  ${timeFmt.format(r.timestamp)}',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (r.note != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.blue.shade400,
                    ),
                  ],
                ],
              ),

              if (r.reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  r.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Amounts row ─────────────────────────────────────────────
              Row(
                children: [
                  _amountBlock(
                    context,
                    'IN',
                    r.inAmount > 0
                        ? '+$currency${DecimalSettings.formatAmount(r.inAmount)}'
                        : '—',
                    r.inAmount > 0 ? inColor : AppColors.textSecondary,
                  ),
                  _amountBlock(
                    context,
                    'OUT',
                    r.outAmount > 0
                        ? '−$currency${DecimalSettings.formatAmount(r.outAmount)}'
                        : '—',
                    r.outAmount > 0 ? outColor : AppColors.textSecondary,
                  ),
                  _amountBlock(
                    context,
                    'Balance',
                    '$currency${DecimalSettings.formatAmount(r.runningBalance)}',
                    balColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountBlock(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop table ────────────────────────────────────────────────────────────

  Widget _buildDesktopTable(
    BuildContext context,
    String currency,
    DateFormat dateFmt,
    DateFormat timeFmt,
  ) {
    // No SingleChildScrollView here — ReportBody supplies the scroll, padding
    // and width cap.
    return Column(
      children: [
        _tableHeader(context, currency),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredRows.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) => _tableRow(
              context,
              _filteredRows[i],
              currency,
              dateFmt,
              timeFmt,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(BuildContext context, String currency) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: AppResponsive.mediumSpacing(context),
      vertical: AppResponsive.smallSpacing(context) + 2,
    ),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
    ),
    child: Row(
      children: [
        _hCell(context, 'Date/Time', flex: 3),
        _hCell(context, 'Type', flex: 2),
        _hCell(context, 'Staff', flex: 2),
        _hCell(context, 'IN', flex: 2, align: TextAlign.right),
        _hCell(context, 'OUT', flex: 2, align: TextAlign.right),
        _hCell(context, 'Balance', flex: 2, align: TextAlign.right),
        _hCell(context, 'Reason', flex: 4),
      ],
    ),
  );

  Widget _hCell(
    BuildContext context,
    String t, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) => Expanded(
    flex: flex,
    child: Text(
      t,
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.captionFontSize(context),
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  Widget _tableRow(
    BuildContext context,
    _HistoryRow r,
    String currency,
    DateFormat dateFmt,
    DateFormat timeFmt,
  ) {
    return GestureDetector(
      onTap: r.note != null ? () => _showNote(context, r) : null,
      child: Container(
        color: r.isAuditOnly ? Colors.orange.shade50 : AppColors.white,
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.smallSpacing(context) + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date / Time
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFmt.format(r.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    timeFmt.format(r.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Type badge
            Expanded(
              flex: 2,
              child: Container(
                margin: EdgeInsets.only(
                  right: AppResponsive.smallSpacing(context),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.smallSpacing(context),
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: r.typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                ),
                child: Text(
                  r.typeName,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: r.typeColor,
                  ),
                ),
              ),
            ),
            // Staff
            Expanded(
              flex: 2,
              child: Text(
                r.staffName,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // IN
            Expanded(
              flex: 2,
              child: Text(
                r.inAmount > 0
                    ? '+$currency${DecimalSettings.formatAmount(r.inAmount)}'
                    : '—',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: r.inAmount > 0
                      ? (r.isAuditOnly
                            ? Colors.orange.shade700
                            : Colors.green.shade700)
                      : AppColors.textSecondary,
                ),
              ),
            ),
            // OUT
            Expanded(
              flex: 2,
              child: Text(
                r.outAmount > 0
                    ? '−$currency${DecimalSettings.formatAmount(r.outAmount)}'
                    : '—',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: r.outAmount > 0
                      ? (r.isAuditOnly
                            ? Colors.orange.shade700
                            : Colors.red.shade700)
                      : AppColors.textSecondary,
                ),
              ),
            ),
            // Running balance
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency${DecimalSettings.formatAmount(r.runningBalance)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: r.isAuditOnly
                          ? Colors.orange.shade700
                          : r.runningBalance < 0
                          ? Colors.red.shade700
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (r.isAuditOnly)
                    Text(
                      'audit only',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context) * 0.85,
                        color: Colors.orange.shade500,
                      ),
                    ),
                ],
              ),
            ),
            // Reason
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppResponsive.smallSpacing(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (r.note != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: AppResponsive.smallIconSize(context) * 0.85,
                        color: Colors.blue.shade400,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNote(BuildContext context, _HistoryRow r) {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                      AppResponsive.dialogWidth(context)) /
                  2)
              .clamp(40.0, double.infinity)
        : 24.0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        title: Text(
          r.typeName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: AppResponsive.bodyFontSize(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _noteRow('Type', r.typeName),
            _noteRow('Staff', r.staffName),
            _noteRow('Reason', r.reason),
            if (r.note != null) _noteRow('Note', r.note!),
            _noteRow(
              'Time',
              DateFormat('dd MMM yyyy  HH:mm').format(r.timestamp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _noteRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      // Poppins is set once on the parent span; the children inherit it and
      // override only weight/colour, so their plain TextStyle is deliberate.
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          color: AppColors.textPrimary,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
