import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
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
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:billberrylite/util/restaurant/payment_mode_summary.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

class PaymentModeReport extends StatefulWidget {
  const PaymentModeReport({super.key});

  @override
  State<PaymentModeReport> createState() => _PaymentModeReportState();
}

class _PaymentModeReportState extends State<PaymentModeReport> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Sales by Payment Mode',
        subtitle: 'Cash, UPI, Card and more',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          ReportPeriodFilterBar(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            featureNoun: 'payment collections',
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: PaymentModeDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentModeDataView extends StatefulWidget {
  final ReportPeriod period;
  const PaymentModeDataView({super.key, required this.period});

  @override
  State<PaymentModeDataView> createState() => _PaymentModeDataViewState();
}

class _PaymentModeDataViewState extends State<PaymentModeDataView> {
  List<PastOrderModel> _filteredOrders = [];
  List<PaymentSummary> _summaries = [];
  double _totalCollected = 0.0;
  int _totalTransactions = 0;
  bool _isLoading = true;
  bool _isDataLoaded = false;
  DateTime? _startDate;
  DateTime? _endDate;

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant PaymentModeDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _filterFromMemory();
    }
  }

  Future<void> _loadDataAndFilter() async {
    if (_isDataLoaded) {
      _filterFromMemory();
      return;
    }
    setState(() => _isLoading = true);
    await pastOrderStore.loadPastOrders();
    _isDataLoaded = true;
    _filterFromMemory();
  }

  void _clearResults() {
    setState(() {
      _filteredOrders = [];
      _summaries = [];
      _totalCollected = 0.0;
      _totalTransactions = 0;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  void _filterFromMemory() {
    final now = DateTime.now();
    final isCustom = widget.period == ReportPeriod.custom;
    final hasCustomRange = _startDate != null && _endDate != null;

    if (isCustom && hasCustomRange && _startDate!.isAfter(_endDate!)) {
      NotificationService.instance.showError('Start date must be before end date');
      setState(() => _isLoading = false);
      return;
    }

    // Pre-compute date boundaries
    late final DateTime startBound;
    late final DateTime endBound;

    if (isCustom) {
      if (!hasCustomRange) {
        _clearResults();
        return;
      }
      startBound = _startDate!;
      endBound = DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1);
    } else {
      // Same helper the filter's history lock uses — they cannot disagree.
      startBound = reportPeriodStartBound(widget.period, now);
      endBound = reportPeriodEndBound(widget.period, now);
    }

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    final results = <PastOrderModel>[];

    for (final order in pastOrderStore.pastOrders) {
      final orderAt = order.orderAt;
      if (orderAt == null) continue;
      if (cutoff != null && orderAt.isBefore(cutoff)) continue;
      if (orderAt.isBefore(startBound) || !orderAt.isBefore(endBound)) continue;

      final status = order.orderStatus?.toUpperCase() ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) continue;

      results.add(order);
    }

    results.sort((a, b) => b.orderAt!.compareTo(a.orderAt!));

    // Same aggregation End of Day uses — split legs, proportional refunds,
    // case-normalised method names.
    final summaries = PaymentModeSummary.summarize(results);

    setState(() {
      _filteredOrders = results;
      _summaries = summaries;
      _totalCollected = summaries.fold(0.0, (sum, s) => sum + s.totalAmount);
      _totalTransactions = results.length;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  double _netAmountOf(PastOrderModel order) =>
      order.totalPrice - (order.refundAmount ?? 0.0);

  String _invoiceOf(PastOrderModel order) => order.billNumber != null
      ? 'INV ${order.billNumber}'
      : '#${order.id.length > 8 ? order.id.substring(0, 8) : order.id}';

  Future<void> _exportReport() async {
    if (_filteredOrders.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Date & Time',
      'Invoice',
      'Payment Mode',
      'Amount',
    ];

    final data = _filteredOrders.map((order) => [
      ReportExportService.formatDateTime(order.orderAt!),
      _invoiceOf(order),
      PaymentModeSummary.methodLabel(order),
      ReportExportService.formatCurrency(_netAmountOf(order)),
    ]).toList();

    final periodDisplay = _getPeriodDisplayName();

    final summary = <String, String>{
      'Report Period': periodDisplay,
      'Total Collected': ReportExportService.formatCurrency(_totalCollected),
      'Total Transactions': _totalTransactions.toString(),
      for (final s in _summaries)
        s.paymentType:
            '${ReportExportService.formatCurrency(s.totalAmount)} (${s.transactionCount} txns, ${s.percentage.toStringAsFixed(1)}%)',
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'payment_mode_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Sales by Payment Mode - $periodDisplay',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    if (widget.period != ReportPeriod.custom) return widget.period.label;
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }
    return 'Custom Period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ReportLoading();

    if (widget.period == ReportPeriod.custom) {
      return _buildCustomDateSelector();
    }

    return _buildReportUI();
  }

  Widget _buildCustomDateSelector() {
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
              _loadDataAndFilter();
            },
          ),
          if (_startDate != null && _endDate != null) ...[
            AppResponsive.verticalSpace(context),
            if (_filteredOrders.isNotEmpty)
              _buildReportContent()
            else
              const ReportEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Collections',
                message: 'No payments found for the selected date range',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportUI() {
    if (_filteredOrders.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No Collections',
        message: 'No payments found for this period',
      );
    }

    return ReportBody(child: _buildReportContent());
  }

  Widget _buildReportContent() {
    return Column(
      children: [
        _buildSummaryCards(),
        AppResponsive.verticalSpace(context),
        ReportExportButton(onPressed: _exportReport),
        AppResponsive.verticalSpace(context),
        _buildMethodTable(),
        AppResponsive.verticalSpace(context),
        _buildOrdersTable(),
        ReportPagination(
          currentPage: _currentPage,
          rowsPerPage: _rowsPerPage,
          totalCount: _filteredOrders.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
          unit: 'orders',
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final topMethod = _summaries.isNotEmpty ? _summaries.first.paymentType : '-';

    return ReportSummaryRow(cards: [
      ReportSummaryCard(
        title: 'Total Collected',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalCollected)}',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.primary,
      ),
      ReportSummaryCard(
        title: 'Transactions',
        value: _totalTransactions.toString(),
        icon: Icons.receipt_long,
        color: Colors.orange,
      ),
      ReportSummaryCard(
        title: 'Top Method',
        value: topMethod,
        icon: Icons.trending_up,
        color: Colors.green,
      ),
    ]);
  }

  Widget _buildMethodTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Payment Mode'),
        ReportTable.column(context, 'Transactions', numeric: true),
        ReportTable.column(context, 'Amount', numeric: true),
        ReportTable.column(context, '% of Total', numeric: true),
      ],
      rows: _summaries.map((s) {
        return DataRow(
          cells: [
            DataCell(
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                  vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.paymentType,
                  style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            DataCell(Text(s.transactionCount.toString(), style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
            DataCell(Text(
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(s.totalAmount)}',
              style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            )),
            DataCell(Text('${s.percentage.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textSecondary))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOrdersTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Invoice'),
        ReportTable.column(context, 'Payment'),
        ReportTable.column(context, 'Amount', numeric: true),
      ],
      rows: ReportPagination.pageSlice(_filteredOrders, _currentPage, _rowsPerPage).map((order) {
        return DataRow(
          cells: [
            DataCell(Text(DateFormat('dd-MM-yy\nHH:mm').format(order.orderAt!), style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
            DataCell(Text(_invoiceOf(order), style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
            DataCell(
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                  vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(PaymentModeSummary.methodLabel(order), style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: Colors.blue, fontWeight: FontWeight.w500)),
              ),
            ),
            DataCell(Text(
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_netAmountOf(order))}',
              style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            )),
          ],
        );
      }).toList(),
    );
  }
}
