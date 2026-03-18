import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cash_handover_model.dart';
import 'package:unipos/data/models/restaurant/db/cash_movement_model.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

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
                color: Colors.grey.shade300,
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
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
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
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
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

  // ── PDF ─────────────────────────────────────────────────────────────────────
  // PDF uses fixed pt sizes — AppResponsive is screen-only.

  Future<void> _printReport() async {
    final pdf      = pw.Document();
    final currency = CurrencyHelper.currentSymbol;
    final fmt      = DateFormat('dd MMM yyyy  HH:mm');
    final dateFmt  = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text('Cash Drawer History',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('${dateFmt.format(_fromDate)}  –  ${dateFmt.format(_toDate)}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
                color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
              _pdfSummaryCol('Total In',
                  '$currency${DecimalSettings.formatAmount(_totalIn)}', PdfColors.green700),
              _pdfSummaryCol('Total Out',
                  '$currency${DecimalSettings.formatAmount(_totalOut)}', PdfColors.red700),
              _pdfSummaryCol('Net',
                  '$currency${DecimalSettings.formatAmount(_net)}',
                  _net >= 0 ? PdfColors.green700 : PdfColors.red700),
              _pdfSummaryCol('Entries', '${_filteredRows.length}', PdfColors.grey800),
            ]),
          ),
          pw.SizedBox(height: 14),

          // Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(112),
              1: const pw.FixedColumnWidth(72),
              2: const pw.FixedColumnWidth(68),
              3: const pw.FixedColumnWidth(62),
              4: const pw.FixedColumnWidth(62),
              5: const pw.FixedColumnWidth(72),
              6: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  'Date / Time', 'Type', 'Staff',
                  'IN ($currency)', 'OUT ($currency)',
                  'Balance ($currency)', 'Reason / Note',
                ]
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ))
                    .toList(),
              ),
              ..._filteredRows.map((r) => pw.TableRow(
                children: [
                  fmt.format(r.timestamp),
                  r.typeName,
                  r.staffName,
                  r.inAmount  > 0 ? DecimalSettings.formatAmount(r.inAmount)  : '—',
                  r.outAmount > 0 ? DecimalSettings.formatAmount(r.outAmount) : '—',
                  DecimalSettings.formatAmount(r.runningBalance),
                  r.note != null ? '${r.reason} — ${r.note}' : r.reason,
                ]
                    .map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8)),
                        ))
                    .toList(),
              )),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  pw.Widget _pdfSummaryCol(String label, String value, PdfColor color) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Text(value,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
    ],
  );

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(children: [
        _buildHeader(context),
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

  // ── Header ───────────────────────────────────────────────────────────────────

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
                  color: Colors.white, size: AppResponsive.iconSize(context)),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cash Drawer History',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.headingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
              Text('Full audit trail — every cash movement',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  )),
            ]),
          ),
          GestureDetector(
            onTap: _filteredRows.isEmpty ? null : _printReport,
            child: Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: _filteredRows.isEmpty
                    ? Colors.grey.shade100
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(Icons.print_outlined,
                  color: _filteredRows.isEmpty
                      ? Colors.grey.shade400
                      : AppColors.primary,
                  size: AppResponsive.iconSize(context)),
            ),
          ),
        ]),
      ),
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
          color: Colors.grey.shade300),
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
            color: Colors.grey.shade400,
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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