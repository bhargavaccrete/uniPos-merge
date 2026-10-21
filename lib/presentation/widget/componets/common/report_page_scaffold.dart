import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_range_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Rows plus headers ready for the Excel/PDF exporter.
class ReportExportData {
  final List<String> headers;
  final List<List<dynamic>> rows;
  final Map<String, dynamic> summary;

  const ReportExportData({
    required this.headers,
    required this.rows,
    this.summary = const {},
  });
}

/// Shared shell for every range-based report — retail and restaurant,
/// purchasing and sales alike.
///
/// They all need the same machinery — period selection, custom date range,
/// loading, empty state, summary band, table, pagination and export — and
/// differ only in the data and the columns. This owns the machinery; each
/// screen supplies the parts that are actually different.
///
/// Reports without a date dimension (Low Stock) or with several datasets
/// (Profit) don't fit here and should use the kit components directly.
///
/// Layout order matches the restaurant reference (`totalsales.dart`):
/// summary row → export button → table → pagination.
class ReportPageScaffold extends StatefulWidget {
  final String title;
  final String? subtitle;

  /// Reads in the period pill labels, e.g. 'purchases' → "This Month purchases".
  final String featureNoun;

  /// Resolved window; both null means "all time".
  final Future<List<Map<String, dynamic>>> Function(
    DateTime? start,
    DateTime? end,
  )
  loader;

  /// Metric cards shown above the table. Empty list hides the band.
  final List<Widget> Function(List<Map<String, dynamic>> rows) summaryCards;

  /// Null renders a summary-only report with no table (Purchase Summary).
  final List<DataColumn> Function(BuildContext context)? columns;
  final DataRow Function(BuildContext context, Map<String, dynamic> row)?
  rowBuilder;

  /// Extra content between the summary band and the table.
  ///
  /// Takes a context like [columns] and [rowBuilder] do, so a detail panel can
  /// size its own text off `AppResponsive` instead of hardcoding it.
  final Widget Function(BuildContext context, List<Map<String, dynamic>> rows)?
  detail;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  /// Plural noun for the pagination footer, e.g. 'receipts'.
  final String rowUnit;

  /// Export payload; null hides the export button.
  final ReportExportData Function(List<Map<String, dynamic>> rows)? exportData;

  /// Base file name; the period and date are appended.
  final String exportFileName;

  /// Whether the period filter bar is shown and a date window is passed to
  /// [loader].
  ///
  /// False for reports that answer "what is true right now" rather than "what
  /// happened in a period" — outstanding purchase orders, for example. Asking
  /// those a date question is worse than useless: an order sent last month and
  /// still undelivered would drop out of the default This Month view precisely
  /// when chasing it matters most. With this false, [loader] is always called
  /// with `(null, null)`.
  final bool showDateRange;

  const ReportPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.featureNoun,
    required this.loader,
    required this.summaryCards,
    this.columns,
    this.rowBuilder,
    this.detail,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.rowUnit = 'rows',
    this.exportData,
    required this.exportFileName,
    this.showDateRange = true,
  });

  @override
  State<ReportPageScaffold> createState() => _ReportPageScaffoldState();
}

class _ReportPageScaffoldState extends State<ReportPageScaffold> {
  static const int _rowsPerPage = 50;

  ReportPeriod _period = ReportPeriod.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Resolved window for the current selection.
  ///
  /// End is EXCLUSIVE throughout — `reportPeriodEndBound` returns the start of
  /// the following day, and a custom end date gets +1 day for the same reason.
  /// Without that the last day of a range silently drops out.
  (DateTime?, DateTime?) get _bounds {
    // No date dimension: the loader sees the whole book.
    if (!widget.showDateRange) return (null, null);
    if (_period == ReportPeriod.custom) {
      if (_customStart == null || _customEnd == null) return (null, null);
      final start = DateTime(
        _customStart!.year,
        _customStart!.month,
        _customStart!.day,
      );
      final end = DateTime(
        _customEnd!.year,
        _customEnd!.month,
        _customEnd!.day,
      ).add(const Duration(days: 1));
      return (start, end);
    }
    final now = DateTime.now();
    return (
      reportPeriodStartBound(_period, now),
      reportPeriodEndBound(_period, now),
    );
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final (start, end) = _bounds;
    final rows = await widget.loader(start, end);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  void _onPeriodChanged(ReportPeriod period) {
    setState(() {
      _period = period;
      // A fresh custom selection starts blank so the range card is shown.
      _customStart = null;
      _customEnd = null;
    });
    if (period != ReportPeriod.custom) _load();
  }

  String get _periodLabel {
    if (_period != ReportPeriod.custom) return _period.label;
    if (_customStart == null || _customEnd == null) return 'Custom Period';
    final fmt = DateFormat('dd MMM yyyy');
    return '${fmt.format(_customStart!)} - ${fmt.format(_customEnd!)}';
  }

  Future<void> _export() async {
    final payload = widget.exportData?.call(_rows);
    if (payload == null || payload.rows.isEmpty) return;

    await ReportExportService.showExportDialog(
      context: context,
      fileName:
          '${widget.exportFileName}_'
          '${widget.showDateRange ? _period.name.toLowerCase() : 'all'}_'
          '${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: widget.title,
      headers: payload.headers,
      data: payload.rows,
      summary: {
        'Report Period': widget.showDateRange ? _periodLabel : 'All time',
        ...payload.summary,
        'Generated': ReportExportService.formatDateTime(DateTime.now()),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(title: widget.title, subtitle: widget.subtitle),
      body: MoneyScope(
        child: Column(
          children: [
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            if (widget.showDateRange) ...[
              ReportPeriodFilterBar(
                selected: _period,
                onSelected: _onPeriodChanged,
                featureNoun: widget.featureNoun,
              ),
              AppResponsive.verticalSpace(context, size: SpacingSize.small),
            ],
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.showDateRange && _period == ReportPeriod.custom) {
      return _buildCustomRange();
    }
    if (_isLoading) return const ReportLoading();
    if (_rows.isEmpty) return _emptyState();
    return ReportBody(child: _buildReport());
  }

  /// Custom keeps the range card visible above the result, so the dates stay
  /// changeable without losing the report.
  Widget _buildCustomRange() {
    final hasRange = _customStart != null && _customEnd != null;

    return ReportBody(
      child: Column(
        children: [
          ReportDateRangeCard(
            initialStart: _customStart,
            initialEnd: _customEnd,
            onApply: (start, end) {
              setState(() {
                _customStart = start;
                _customEnd = end;
              });
              _load();
            },
          ),
          if (hasRange) ...[
            AppResponsive.verticalSpace(context),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: ReportLoading(),
              )
            else if (_rows.isEmpty)
              _emptyState()
            else
              _buildReport(),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() => ReportEmptyState(
    icon: widget.emptyIcon,
    title: widget.emptyTitle,
    message: widget.emptyMessage,
  );

  Widget _buildReport() {
    final cards = widget.summaryCards(_rows);
    final hasTable = widget.columns != null && widget.rowBuilder != null;
    final pageRows = ReportPagination.pageSlice(
      _rows,
      _currentPage,
      _rowsPerPage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cards.isNotEmpty) ...[
          ReportSummaryRow(cards: cards),
          AppResponsive.verticalSpace(context),
        ],
        if (widget.detail != null) ...[
          widget.detail!(context, _rows),
          AppResponsive.verticalSpace(context),
        ],
        if (widget.exportData != null) ...[
          ReportExportButton(onPressed: _export),
          AppResponsive.verticalSpace(context),
        ],
        if (hasTable) ...[
          ReportTable(
            showCheckboxColumn: false,
            columns: widget.columns!(context),
            rows: pageRows.map((r) => widget.rowBuilder!(context, r)).toList(),
          ),
          ReportPagination(
            currentPage: _currentPage,
            rowsPerPage: _rowsPerPage,
            totalCount: _rows.length,
            unit: widget.rowUnit,
            onPageChanged: (page) => setState(() => _currentPage = page),
          ),
        ],
      ],
    );
  }
}
