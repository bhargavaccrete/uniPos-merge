import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_handover_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
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
  final double inAmount;       // positive = cash added
  final double outAmount;      // positive = cash removed
  final double runningBalance; // drawer total AFTER this entry
  final String reason;
  final String? note;
  final bool isAuditOnly;      // true for adjustments / discrepancies

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
  State<CashDrawerHistoryScreen> createState() => _CashDrawerHistoryScreenState();
}

class _CashDrawerHistoryScreenState extends State<CashDrawerHistoryScreen> {
  bool _isLoading = true;
  bool _isDataLoaded = false;

  List<_HistoryRow> _allRows = [];
  List<_HistoryRow> _filteredRows = [];

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _typeFilter = 'All';

  static const _typeOptions = ['All', 'Opening', 'Sale', 'Expense', 'Cash In', 'Cash Out', 'Withdrawal', 'Adjustment', 'Shift End'];

  // Pre-computed summary totals
  double _totalIn  = 0.0;
  double _totalOut = 0.0;
  double _net      = 0.0;

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
      final box = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
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
            final isEOD = m.reason.toLowerCase().contains('safe drop') ||
                m.reason.toLowerCase().contains('end of day');
            typeName = isEOD ? 'Withdrawal' : 'Cash Out';
            typeColor = Colors.red.shade700;
            outAmt = m.amount;
          case 'adjustment':
            final isDiscrepancy = m.reason.toLowerCase().contains('shortage') ||
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

        drafts.add(_RowDraft(
          timestamp: m.timestamp,
          typeName: typeName,
          typeColor: typeColor,
          staffName: m.staffName,
          inAmount: inAmt,
          outAmount: outAmt,
          reason: m.reason,
          note: m.note,
          isAuditOnly: auditOnly,
        ));
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
        if (status == 'VOID' || status == 'VOIDED' ||
            status == 'FULLY_REFUNDED' || status == 'PARTIALLY_REFUNDED') continue;
        if (o.orderAt == null) continue;

        final method = (o.paymentmode ?? '').toLowerCase().trim();
        bool hasCash = method == 'cash';
        if (!hasCash && o.isSplitPayment == true) {
          hasCash = o.paymentList
              .any((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash');
        }
        if (!hasCash) continue;

        final cashAmt = _cashComponentOf(o);
        if (cashAmt <= 0) continue;

        final billNo = o.billNumber ?? o.id.substring(0, 6);
        final label = o.isSplitPayment == true
            ? 'Bill #$billNo (cash portion)'
            : (o.refundAmount ?? 0.0) > 0
                ? 'Bill #$billNo (net of refund)'
                : 'Bill #$billNo';

        final saleStaff = (o.shiftId != null ? shiftIdToName[o.shiftId] : null)
            ?? staffAtTime(o.orderAt!);

        drafts.add(_RowDraft(
          timestamp: o.orderAt!,
          typeName: 'Sale',
          typeColor: Colors.green.shade600,
          staffName: saleStaff,
          inAmount: cashAmt,
          outAmount: 0.0,
          reason: label,
        ));
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

        drafts.add(_RowDraft(
          timestamp: e.dateandTime,
          typeName: 'Expense',
          typeColor: Colors.deepOrange.shade600,
          staffName: staffAtTime(e.dateandTime),
          inAmount: 0.0,
          outAmount: e.amount,
          reason: desc,
        ));
      }

      // ── Source 4: Shift-end handover records ──────────────────────────────
      final handoverBox = Hive.box<CashHandoverModel>(HiveBoxNames.restaurantCashHandovers);
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
          final expected = '$currency${(h.receivedAmount ?? 0).toStringAsFixed(2)}';
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
        drafts.add(_RowDraft(
          timestamp: h.closedAt,
          typeName: 'Shift End',
          typeColor: isMismatch ? Colors.orange.shade700 : Colors.teal.shade600,
          staffName: h.closedBy,
          inAmount: 0.0,
          outAmount: 0.0,
          reason: reason,
          note: h.closedNote,
          isAuditOnly: true,
        ));
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
        rows.add(_HistoryRow(
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
        ));
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

  /// Returns the net cash component of an order (pure cash or split payment cash portion).
  double _cashComponentOf(PastOrderModel o) {
    if (o.isSplitPayment == true) {
      final rawCash = o.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));
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

  void _applyFilter() {
    // Half-open: [from, toExclusive)
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toExclusive = DateTime(_toDate.year, _toDate.month, _toDate.day + 1);

    final results = <_HistoryRow>[];
    double inSum = 0.0;
    double outSum = 0.0;

    for (final r in _allRows) {
      if (r.timestamp.isBefore(from) || !r.timestamp.isBefore(toExclusive)) continue;
      if (_typeFilter != 'All') {
        if (_typeFilter == 'Adjustment') {
          if (r.typeName != 'Adjustment' && r.typeName != 'Discrepancy') continue;
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

  Future<void> _showDateOptions() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.today_outlined, color: AppColors.primary, size: 20),
              ),
              title: Text('Single Day',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('View one specific day',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickSingleDay();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.date_range_outlined, color: AppColors.primary, size: 20),
              ),
              title: Text('Date Range',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('View multiple days',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickDateRange();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSingleDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _toDate   = picked;
      });
      _applyFilter();
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate   = range.end;
      });
      _applyFilter();
    }
  }

  // ── Export (Excel + PDF via the shared report service) ──────────────────────
  // Routes through ReportExportService so the drawer ledger exports to BOTH
  // Excel and PDF, consistent with every other report.

  Future<void> _exportReport() async {
    final fmt     = DateFormat('dd MMM yyyy  HH:mm');
    final dateFmt = DateFormat('dd MMM yyyy');

    final headers = [
      'Date / Time', 'Type', 'Staff', 'In', 'Out', 'Balance', 'Reason / Note',
    ];

    final data = _filteredRows.map((r) => [
      fmt.format(r.timestamp),
      r.typeName,
      r.staffName,
      r.inAmount  > 0 ? ReportExportService.formatCurrency(r.inAmount)  : '—',
      r.outAmount > 0 ? ReportExportService.formatCurrency(r.outAmount) : '—',
      ReportExportService.formatCurrency(r.runningBalance),
      (r.note != null && r.note!.isNotEmpty) ? '${r.reason} — ${r.note}' : r.reason,
    ]).toList();

    final periodName = '${dateFmt.format(_fromDate)} – ${dateFmt.format(_toDate)}';
    final summary = {
      'Report Period': periodName,
      'Total In':  ReportExportService.formatCurrency(_totalIn),
      'Total Out': ReportExportService.formatCurrency(_totalOut),
      'Net':       ReportExportService.formatCurrency(_net),
      'Entries':   _filteredRows.length.toString(),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'cash_drawer_history_${DateFormat('yyyyMMdd').format(DateTime.now())}',
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
      appBar: buildPrimaryAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cash Drawer History',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: AppResponsive.headingFontSize(context))),
            Text('Full audit trail — every cash movement',
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: AppResponsive.smallFontSize(context))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Report',
            onPressed: _filteredRows.isEmpty ? null : _exportReport,
          ),
        ],
      ),
      body: Column(children: [
        if (!_isLoading) ...[
          _buildFilterBar(context),
          _buildSummaryBar(context, currency),
        ],
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredRows.isEmpty
                  ? _buildEmpty(context)
                  : _buildTable(context, currency),
        ),
      ]),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yy');
    final isSingleDay = _fromDate.year == _toDate.year &&
        _fromDate.month == _toDate.month &&
        _fromDate.day == _toDate.day;
    final dateLabel = isSingleDay
        ? dateFmt.format(_fromDate)
        : '${dateFmt.format(_fromDate)}  –  ${dateFmt.format(_toDate)}';

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        0,
      ),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker button
          GestureDetector(
            onTap: _showDateOptions,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context) + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isSingleDay ? Icons.today_outlined : Icons.date_range_outlined,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text(
                  dateLabel,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Icon(Icons.arrow_drop_down,
                    size: AppResponsive.iconSize(context),
                    color: AppColors.primary),
              ]),
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _typeOptions.map((option) {
                final isSelected = _typeFilter == option;
                return Padding(
                  padding:
                      EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _typeFilter = option);
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.largeSpacing(context),
                        vertical: AppResponsive.smallSpacing(context),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary bar ──────────────────────────────────────────────────────────────

  Widget _buildSummaryBar(BuildContext context, String currency) {
    final netColor = _net >= 0 ? Colors.teal.shade700 : Colors.red.shade700;
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.smallSpacing(context),
        AppResponsive.largeSpacing(context),
        0,
      ),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        _summaryTile(context, 'Total In',  _totalIn,  Colors.green.shade700, currency),
        _vDivider(),
        _summaryTile(context, 'Total Out', _totalOut, Colors.red.shade700,   currency),
        _vDivider(),
        _summaryTile(context, 'Net',       _net,      netColor,              currency),
        _vDivider(),
        _summaryTile(context, 'Entries',   _filteredRows.length.toDouble(),
            AppColors.textSecondary, '', isCount: true),
      ]),
    );
  }

  Widget _summaryTile(BuildContext context, String label, double amount,
      Color color, String currency, {bool isCount = false}) =>
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isCount
                  ? '${amount.toInt()}'
                  : '$currency${DecimalSettings.formatAmount(amount)}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history_outlined,
          size: AppResponsive.largeIconSize(context) * 1.5,
          color: AppColors.divider),
      SizedBox(height: AppResponsive.mediumSpacing(context)),
      Text('No transactions found',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            color: AppColors.textSecondary,
          )),
      SizedBox(height: AppResponsive.smallSpacing(context)),
      Text('Try widening the date range or changing the filter',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          )),
    ]),
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

  Widget _buildMobileList(BuildContext context, String currency,
      DateFormat dateFmt, DateFormat timeFmt) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.largeSpacing(context),
      ),
      itemCount: _filteredRows.length,
      itemBuilder: (_, i) =>
          _mobileCard(context, _filteredRows[i], currency, dateFmt, timeFmt),
    );
  }

  Widget _mobileCard(BuildContext context, _HistoryRow r, String currency,
      DateFormat dateFmt, DateFormat timeFmt) {
    final inColor  = r.isAuditOnly ? Colors.orange.shade700 : Colors.green.shade700;
    final outColor = r.isAuditOnly ? Colors.orange.shade700 : Colors.red.shade700;
    final balColor = r.isAuditOnly
        ? Colors.orange.shade700
        : r.runningBalance < 0 ? Colors.red.shade700 : AppColors.textPrimary;

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top row: badge + date/time ──────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(r.typeName,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: r.typeColor,
                    )),
              ),
              if (r.isAuditOnly) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('audit',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade700,
                      )),
                ),
              ],
              const Spacer(),
              if (r.staffName.isNotEmpty) ...[
                Icon(Icons.person_outline, size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text('${r.staffName}  ',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    )),
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
                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade400),
              ],
            ]),

            if (r.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  )),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── Amounts row ─────────────────────────────────────────────
            Row(children: [
              _amountBlock(context, 'IN',
                r.inAmount > 0
                    ? '+$currency${DecimalSettings.formatAmount(r.inAmount)}'
                    : '—',
                r.inAmount > 0 ? inColor : AppColors.textSecondary,
              ),
              _amountBlock(context, 'OUT',
                r.outAmount > 0
                    ? '−$currency${DecimalSettings.formatAmount(r.outAmount)}'
                    : '—',
                r.outAmount > 0 ? outColor : AppColors.textSecondary,
              ),
              _amountBlock(context, 'Balance',
                '$currency${DecimalSettings.formatAmount(r.runningBalance)}',
                balColor,
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _amountBlock(
      BuildContext context, String label, String value, Color valueColor) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w700,
                color: valueColor,
              )),
        ),
      ]),
    );
  }

  // ── Desktop table ────────────────────────────────────────────────────────────

  Widget _buildDesktopTable(BuildContext context, String currency,
      DateFormat dateFmt, DateFormat timeFmt) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.largeSpacing(context),
      ),
      child: Column(children: [
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
                context, _filteredRows[i], currency, dateFmt, timeFmt),
          ),
        ),
      ]),
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
        topLeft: Radius.circular(12), topRight: Radius.circular(12),
      ),
    ),
    child: Row(children: [
      _hCell(context, 'Date/Time', flex: 3),
      _hCell(context, 'Type',      flex: 2),
      _hCell(context, 'Staff',     flex: 2),
      _hCell(context, 'IN',        flex: 2, align: TextAlign.right),
      _hCell(context, 'OUT',       flex: 2, align: TextAlign.right),
      _hCell(context, 'Balance',   flex: 2, align: TextAlign.right),
      _hCell(context, 'Reason',    flex: 4),
    ]),
  );

  Widget _hCell(BuildContext context, String t,
          {int flex = 1, TextAlign align = TextAlign.left}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            textAlign: align,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
      );

  Widget _tableRow(BuildContext context, _HistoryRow r, String currency,
      DateFormat dateFmt, DateFormat timeFmt) {
    return GestureDetector(
      onTap: r.note != null ? () => _showNote(context, r) : null,
      child: Container(
        color: r.isAuditOnly ? Colors.orange.shade50 : AppColors.white,
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.smallSpacing(context) + 2,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Date / Time
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateFmt.format(r.timestamp),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                  )),
              Text(timeFmt.format(r.timestamp),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  )),
            ]),
          ),
          // Type badge
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.smallSpacing(context),
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: r.typeColor.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Text(r.typeName,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: r.typeColor,
                  )),
            ),
          ),
          // Staff
          Expanded(
            flex: 2,
            child: Text(r.staffName,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textPrimary,
                )),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
                Text('audit only',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context) * 0.85,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange.shade500,
                    )),
            ]),
          ),
          // Reason
          Expanded(
            flex: 4,
            child: Padding(
              padding:
                  EdgeInsets.only(left: AppResponsive.smallSpacing(context)),
              child: Row(children: [
                Expanded(
                  child: Text(r.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      )),
                ),
                if (r.note != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline,
                      size: AppResponsive.smallIconSize(context) * 0.85,
                      color: Colors.blue.shade400),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _showNote(BuildContext context, _HistoryRow r) {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        title: Text(r.typeName,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: AppResponsive.bodyFontSize(context))),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _noteRow('Type',   r.typeName),
              _noteRow('Staff',  r.staffName),
              _noteRow('Reason', r.reason),
              if (r.note != null) _noteRow('Note', r.note!),
              _noteRow('Time',
                  DateFormat('dd MMM yyyy  HH:mm').format(r.timestamp)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  Widget _noteRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(
              text: value,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}