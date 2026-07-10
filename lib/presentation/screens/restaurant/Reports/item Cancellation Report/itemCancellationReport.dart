import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/repositories/restaurant/item_cancellation_repository.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_range_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';

/// Report of individual items cancelled from already-placed orders, with reason.
class ItemCancellationReport extends StatefulWidget {
  const ItemCancellationReport({super.key});

  @override
  State<ItemCancellationReport> createState() => _ItemCancellationReportState();
}

class _ItemCancellationReportState extends State<ItemCancellationReport> {
  /// No 'This Year' — cancellations are an operational, short-window report.
  static const _periods = [
    ReportPeriod.today,
    ReportPeriod.thisWeek,
    ReportPeriod.thisMonth,
    ReportPeriod.custom,
  ];

  ReportPeriod _period = ReportPeriod.today;
  DateTime? _startDate;
  DateTime? _endDate;

  List<ItemCancellationModel> _all = [];
  List<ItemCancellationModel> _filtered = [];
  bool _loaded = false;

  int _totalCount = 0;
  int _totalQty = 0;
  double _totalAmount = 0;
  String _topReason = '—';

  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _all = locator<ItemCancellationRepository>().getAll();
    _loaded = true;
    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    if (_period == ReportPeriod.custom) {
      if (_startDate != null && _endDate != null) {
        start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
            .add(const Duration(days: 1));
      }
    } else {
      // Same helper the filter's history lock uses — they cannot disagree.
      start = reportPeriodStartBound(_period, now);
      end = reportPeriodEndBound(_period, now);
    }

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    final results = (start == null || end == null)
        ? <ItemCancellationModel>[]
        : _all.where((r) {
            if (cutoff != null && r.timestamp.isBefore(cutoff)) return false;
            return !r.timestamp.isBefore(start!) && r.timestamp.isBefore(end!);
          }).toList();

    final reasonCounts = <String, int>{};
    int qty = 0;
    double amount = 0;
    for (final r in results) {
      qty += r.quantity;
      amount += r.amount;
      final reason = r.reason.trim();
      if (reason.isNotEmpty && reason != 'No reason given') {
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
      }
    }
    String top = '—';
    if (reasonCounts.isNotEmpty) {
      top = reasonCounts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    setState(() {
      _filtered = results;
      _totalCount = results.length;
      _totalQty = qty;
      _totalAmount = amount;
      _topReason = top;
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Item Cancellation Report',
        subtitle: 'Items cancelled from placed orders, with reason',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportPeriodFilterBar(
            selected: _period,
            periods: _periods,
            featureNoun: 'cancellations',
            onSelected: (p) {
              setState(() => _period = p);
              _applyFilter();
            },
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(child: !_loaded ? const ReportLoading() : _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_period == ReportPeriod.custom) {
      return ReportBody(
        child: Column(
          children: [
            ReportDateRangeCard(
              initialStart: _startDate,
              initialEnd: _endDate,
              onApply: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = end;
                });
                _applyFilter();
              },
            ),
            if (_startDate != null && _endDate != null) ...[
              AppResponsive.verticalSpace(context),
              if (_filtered.isNotEmpty) _buildContent() else _emptyState,
            ],
          ],
        ),
      );
    }

    if (_filtered.isEmpty) return _emptyState;
    return ReportBody(child: _buildContent());
  }

  Widget get _emptyState => const ReportEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No item cancellations',
        message: 'No items were cancelled in this period',
      );

  Widget _buildContent() {
    return Column(
      children: [
        ReportSummaryRow(cards: [
          ReportSummaryCard(
            title: 'Cancellations',
            value: '$_totalCount',
            icon: Icons.remove_circle_outline,
            color: Colors.red,
          ),
          ReportSummaryCard(
            title: 'Items Qty',
            value: '$_totalQty',
            icon: Icons.numbers,
            color: Colors.orange,
          ),
          ReportSummaryCard(
            title: 'Amount',
            value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalAmount)}',
            icon: Icons.attach_money,
            color: AppColors.primary,
          ),
        ]),
        if (_topReason != '—') ...[
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportSummaryCard(
            title: 'Top Reason',
            value: _topReason,
            icon: Icons.report_problem_outlined,
            color: Colors.red,
          ),
        ],
        AppResponsive.verticalSpace(context),
        ReportExportButton(onPressed: _export),
        AppResponsive.verticalSpace(context),
        _buildTable(),
        ReportPagination(
          currentPage: _currentPage,
          rowsPerPage: _rowsPerPage,
          totalCount: _filtered.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
          unit: 'cancellations',
        ),
      ],
    );
  }

  Widget _buildTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);
    final pageRows = ReportPagination.pageSlice(_filtered, _currentPage, _rowsPerPage);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Item'),
        ReportTable.column(context, 'Qty'),
        ReportTable.column(context, 'Amount', numeric: true),
        ReportTable.column(context, 'Reason'),
        ReportTable.column(context, 'Staff'),
      ],
      rows: pageRows.map((r) {
        final name = r.variantName != null && r.variantName!.isNotEmpty
            ? '${r.itemName} (${r.variantName})'
            : r.itemName;
        return DataRow(cells: [
          DataCell(Text(DateFormat('dd/MM hh:mm a').format(r.timestamp),
              style: GoogleFonts.poppins(fontSize: cellFontSize))),
          DataCell(ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: cellFontSize, fontWeight: FontWeight.w500)),
          )),
          DataCell(Text('${r.quantity}', style: GoogleFonts.poppins(fontSize: cellFontSize))),
          DataCell(Text(
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(r.amount)}',
              style: GoogleFonts.poppins(fontSize: cellFontSize, fontWeight: FontWeight.w600))),
          DataCell(ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(r.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: cellFontSize)),
          )),
          DataCell(Text(r.staffName ?? '—', style: GoogleFonts.poppins(fontSize: cellFontSize))),
        ]);
      }).toList(),
    );
  }

  Future<void> _export() async {
    if (_filtered.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }
    final headers = ['Date & Time', 'Item', 'Qty', 'Amount', 'Reason', 'Staff', 'KOT'];
    final data = _filtered
        .map((r) => [
              ReportExportService.formatDateTime(r.timestamp),
              r.variantName != null && r.variantName!.isNotEmpty
                  ? '${r.itemName} (${r.variantName})'
                  : r.itemName,
              r.quantity.toString(),
              ReportExportService.formatCurrency(r.amount),
              r.reason,
              r.staffName ?? '—',
              r.kotNumber?.toString() ?? '—',
            ])
        .toList();
    final summary = {
      'Total Cancellations': _totalCount.toString(),
      'Total Items Qty': _totalQty.toString(),
      'Total Amount': ReportExportService.formatCurrency(_totalAmount),
      'Top Reason': _topReason,
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'item_cancellations_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Item Cancellation Report',
      headers: headers,
      data: data,
      summary: summary,
    );
  }
}
