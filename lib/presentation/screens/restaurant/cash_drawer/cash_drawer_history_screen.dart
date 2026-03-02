import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/data/models/restaurant/db/cash_movement_model.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';

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

  // Full history with running balances computed from the beginning of time.
  List<_HistoryRow> _allRows = [];
  // Subset shown after filter.
  List<_HistoryRow> _filteredRows = [];

  // Filter state
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _typeFilter = 'All';

  static const _typeOptions = ['All', 'Opening', 'Cash In', 'Cash Out', 'Withdrawal', 'Adjustment'];

  // Summaries derived from filtered rows
  double get _totalIn  => _filteredRows.fold(0.0, (s, r) => s + r.inAmount);
  double get _totalOut => _filteredRows.fold(0.0, (s, r) => s + r.outAmount);
  double get _net      => _totalIn - _totalOut;

  // ── Init ────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final box = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
      final all = box.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Single pass: compute running balance across ALL movements in chronological order.
      // Adjustments are audit-only — they do NOT move the drawer balance.
      double running = 0.0;
      final rows = <_HistoryRow>[];

      for (final m in all) {
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
            running += m.amount;

          case 'in':
            typeName = 'Cash In';
            typeColor = Colors.green.shade700;
            inAmt = m.amount;
            running += m.amount;

          case 'out':
            final isEOD = m.reason.toLowerCase().contains('safe drop') ||
                m.reason.toLowerCase().contains('end of day');
            typeName = isEOD ? 'Withdrawal' : 'Cash Out';
            typeColor = Colors.red.shade700;
            outAmt = m.amount;
            running -= m.amount;

          case 'adjustment':
            final isDiscrepancy = m.reason.toLowerCase().contains('shortage') ||
                m.reason.toLowerCase().contains('overage') ||
                m.reason.toLowerCase().contains('discrepancy');
            typeName = isDiscrepancy ? 'Discrepancy' : 'Adjustment';
            typeColor = Colors.orange.shade700;
            auditOnly = true;
            // Show in IN or OUT column for visual clarity; does NOT move running balance.
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
              running += m.amount;
            } else {
              outAmt = m.amount.abs();
              running -= m.amount.abs();
            }
        }

        rows.add(_HistoryRow(
          timestamp: m.timestamp,
          typeName: typeName,
          typeColor: typeColor,
          staffName: m.staffName,
          inAmount: inAmt,
          outAmount: outAmt,
          runningBalance: running,
          reason: m.reason,
          note: m.note,
          isAuditOnly: auditOnly,
        ));
      }

      _allRows = rows;
      _applyFilter();
    } catch (e) {
      debugPrint('Cash drawer history load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to   = DateTime(_toDate.year,   _toDate.month,   _toDate.day, 23, 59, 59);

    _filteredRows = _allRows.where((r) {
      final inRange = !r.timestamp.isBefore(from) && !r.timestamp.isAfter(to);
      if (!inRange) return false;
      if (_typeFilter == 'All') return true;
      if (_typeFilter == 'Adjustment') {
        return r.typeName == 'Adjustment' || r.typeName == 'Discrepancy';
      }
      return r.typeName == _typeFilter;
    }).toList();

    setState(() {});
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
      _fromDate = range.start;
      _toDate   = range.end;
      _applyFilter();
    }
  }

  // ── PDF ─────────────────────────────────────────────────────────────────────

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
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
              _pdfSummaryCol('Total In', '$currency ${_totalIn.toStringAsFixed(2)}', PdfColors.green700),
              _pdfSummaryCol('Total Out', '$currency ${_totalOut.toStringAsFixed(2)}', PdfColors.red700),
              _pdfSummaryCol('Net', '$currency ${_net.toStringAsFixed(2)}',
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
                children: ['Date / Time', 'Type', 'Staff', 'IN ($currency)', 'OUT ($currency)',
                           'Balance ($currency)', 'Reason / Note']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                          child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ))
                    .toList(),
              ),
              ..._filteredRows.map((r) => pw.TableRow(
                children: [
                  fmt.format(r.timestamp),
                  r.typeName,
                  r.staffName,
                  r.inAmount  > 0 ? r.inAmount.toStringAsFixed(2)  : '—',
                  r.outAmount > 0 ? r.outAmount.toStringAsFixed(2) : '—',
                  r.runningBalance.toStringAsFixed(2),
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
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cash Drawer History',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('Full audit trail — every cash movement',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          GestureDetector(
            onTap: _filteredRows.isEmpty ? null : _printReport,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _filteredRows.isEmpty
                    ? Colors.grey.shade100
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.print_outlined,
                  color: _filteredRows.isEmpty ? Colors.grey.shade400 : AppColors.primary,
                  size: 22),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yy');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: date range button + entry count
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${dateFmt.format(_fromDate)}  –  ${dateFmt.format(_toDate)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Row 2: type filter chips (scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _typeOptions.map((option) {
                final isSelected = _typeFilter == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _typeFilter = option);
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        _summaryTile('Total In',  _totalIn,  Colors.green.shade700, currency),
        _vDivider(),
        _summaryTile('Total Out', _totalOut, Colors.red.shade700,   currency),
        _vDivider(),
        _summaryTile('Net', _net, _net >= 0 ? Colors.teal.shade700 : Colors.red.shade700, currency),
        const Spacer(),
        Text('${_filteredRows.length} entries',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _summaryTile(String label, double amount, Color color, String currency) =>
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
          Text('$currency ${amount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1, height: 36, color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history_outlined, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No transactions found',
          style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Text('Try widening the date range or changing the filter',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
    ]),
  );

  // ── Table ────────────────────────────────────────────────────────────────────

  Widget _buildTable(BuildContext context, String currency) {
    final dateFmt = DateFormat('dd MMM');
    final timeFmt = DateFormat('HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(children: [
        // Sticky header
        _tableHeader(currency),
        // Rows
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredRows.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) => _tableRow(context, _filteredRows[i], currency, dateFmt, timeFmt),
          ),
        ),
      ]),
    );
  }

  Widget _tableHeader(String currency) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12), topRight: Radius.circular(12),
      ),
    ),
    child: Row(children: [
      _hCell('Date/Time', flex: 3),
      _hCell('Type',      flex: 2),
      _hCell('Staff',     flex: 2),
      _hCell('IN',        flex: 2, align: TextAlign.right),
      _hCell('OUT',       flex: 2, align: TextAlign.right),
      _hCell('Balance',   flex: 2, align: TextAlign.right),
      _hCell('Reason',    flex: 4),
    ]),
  );

  Widget _hCell(String t, {int flex = 1, TextAlign align = TextAlign.left}) => Expanded(
    flex: flex,
    child: Text(t,
        textAlign: align,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );

  Widget _tableRow(BuildContext context, _HistoryRow r, String currency,
      DateFormat dateFmt, DateFormat timeFmt) {
    return GestureDetector(
      onTap: r.note != null ? () => _showNote(context, r) : null,
      child: Container(
        color: r.isAuditOnly ? Colors.orange.shade50 : AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Date / Time
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dateFmt.format(r.timestamp),
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(timeFmt.format(r.timestamp),
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          // Type badge
          Expanded(flex: 2, child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: r.typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(r.typeName,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: r.typeColor)),
          )),
          // Staff
          Expanded(flex: 2, child: Text(r.staffName,
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary))),
          // IN
          Expanded(flex: 2, child: Text(
            r.inAmount > 0 ? '+$currency ${r.inAmount.toStringAsFixed(2)}' : '—',
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: r.inAmount > 0
                  ? (r.isAuditOnly ? Colors.orange.shade700 : Colors.green.shade700)
                  : AppColors.textSecondary,
            ),
          )),
          // OUT
          Expanded(flex: 2, child: Text(
            r.outAmount > 0 ? '−$currency ${r.outAmount.toStringAsFixed(2)}' : '—',
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: r.outAmount > 0
                  ? (r.isAuditOnly ? Colors.orange.shade700 : Colors.red.shade700)
                  : AppColors.textSecondary,
            ),
          )),
          // Running balance — shows state of drawer after this entry
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$currency ${r.runningBalance.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: r.isAuditOnly
                      ? Colors.orange.shade700
                      : r.runningBalance < 0 ? Colors.red.shade700 : AppColors.textPrimary,
                )),
            if (r.isAuditOnly)
              Text('audit only',
                  style: GoogleFonts.poppins(
                      fontSize: 9, fontStyle: FontStyle.italic, color: Colors.orange.shade500)),
          ])),
          // Reason
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              Expanded(child: Text(r.reason,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary))),
              if (r.note != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 13, color: Colors.blue.shade400),
              ],
            ]),
          )),
        ]),
      ),
    );
  }

  void _showNote(BuildContext context, _HistoryRow r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(r.typeName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _noteRow('Type',   r.typeName),
          _noteRow('Staff',  r.staffName),
          _noteRow('Reason', r.reason),
          if (r.note != null) _noteRow('Note', r.note!),
          _noteRow('Time',   DateFormat('dd MMM yyyy  HH:mm').format(r.timestamp)),
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
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}
