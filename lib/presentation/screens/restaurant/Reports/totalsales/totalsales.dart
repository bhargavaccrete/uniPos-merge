import 'package:flutter/material.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
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
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

class Totalsales extends StatefulWidget {
  const Totalsales({super.key});

  @override
  State<Totalsales> createState() => _TotalsalesState();
}

class _TotalsalesState extends State<Totalsales> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
  return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Total Sales',
        subtitle: 'View sales across different periods',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          _buildFilterBar(),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: SalesDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return ReportPeriodFilterBar(
      selected: _selectedPeriod,
      onSelected: (p) => setState(() => _selectedPeriod = p),
      featureNoun: 'sales',
    );
  }
}

class SalesDataView extends StatefulWidget {
  final ReportPeriod period;
  const SalesDataView({super.key, required this.period});

  @override
  State<SalesDataView> createState() => _SalesDataViewState();
}

class _SalesDataViewState extends State<SalesDataView> {
  List<PastOrderModel> _filteredOrders = [];
  double _totalSales = 0.0;
  int _totalOrdersCount = 0;
  bool _isLoading = true;
  bool _isDataLoaded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadAndFilter();
  }

  @override
  void didUpdateWidget(covariant SalesDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      // Data already in memory — just re-filter, no Hive read
      _filterFromMemory();
    }
  }

  /// First call: loads all orders from Hive via the store (2-3s, once).
  /// Subsequent calls: skips the load, filters from memory (instant).
  Future<void> _loadAndFilter() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _filterFromMemory();
  }

  /// Single-pass in-memory filter over pastOrderStore.pastOrders.
  ///
  /// After the one-time Hive load, this runs in <10ms even on 30k orders
  /// because it's just iterating an in-memory list with simple comparisons.
  void _filterFromMemory() {
    final now = DateTime.now();
    final results = <PastOrderModel>[];
    double sales = 0.0;

    // Pre-compute date boundaries once. The non-custom bounds come from the
    // same helper the filter's history lock uses, so they cannot disagree.
    final isCustom = widget.period == ReportPeriod.custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      startBound = reportPeriodStartBound(widget.period, now);
      endBound = reportPeriodEndBound(widget.period, now);
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    // Single pass: window + date + status filter
    for (final order in pastOrderStore.pastOrders) {
      final orderDate = order.orderAt;
      if (orderDate == null) continue;
      if (cutoff != null && orderDate.isBefore(cutoff)) continue;
      if (isCustom && !hasCustomRange) continue;

      if (orderDate.isBefore(startBound) || !orderDate.isBefore(endBound)) {
        continue;
      }

      final status = order.orderStatus ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) {
        continue;
      }

      results.add(order);
    }

    results.sort((a, b) =>
        (b.orderAt ?? DateTime(2000)).compareTo(a.orderAt ?? DateTime(2000)));

    final capped = results;
    for (final o in capped) {
      sales += o.totalPrice - (o.refundAmount ?? 0.0);
    }

    setState(() {
      _filteredOrders = capped;
      _totalOrdersCount = capped.length;
      _totalSales = sales;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _exportReport() async {
    if (_filteredOrders.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Date',
      'Invoice',
      'Customer',
      'Payment',
      'Type',
      'Status',
      'Amount',
    ];

    // Prepare data rows — FULLY_REFUNDED already excluded during filtering
    final data = _filteredOrders.map((order) {
      final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);
      final String statusLabel;
      switch (order.orderStatus) {
        case 'PARTIALLY_REFUNDED':
          statusLabel = 'Partial Refund';
          break;
        default:
          statusLabel = 'Completed';
      }
      return [
        ReportExportService.formatDateTime(order.orderAt),
        order.billNumber != null ? 'INV ${order.billNumber}' : '#${(order.id.length > 8 ? order.id.substring(0, 8) : order.id)}',
        order.customerName,
        order.paymentDisplay.isNotEmpty ? order.paymentDisplay : 'N/A',
        order.orderType ?? 'N/A',
        statusLabel,
        ReportExportService.formatCurrency(netAmount),
      ];
    }).toList();

    // Prepare summary
    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Period': periodName,
      'Total Orders': _totalOrdersCount.toString(),
      'Total Sales': ReportExportService.formatCurrency(_totalSales),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'total_sales_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Total Sales Report - $periodName',
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
              _loadAndFilter();
            },
          ),
          if (_startDate != null && _endDate != null) ...[
            AppResponsive.verticalSpace(context),
            if (_filteredOrders.isNotEmpty)
              _buildReportContent()
            else
              const ReportEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No sales found',
                message: 'No orders found for the selected date range',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportUI() {
    if (_filteredOrders.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Sales Data',
        message: 'No sales found for this period',
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
        _buildDataTable(),
        ReportPagination(
          currentPage: _currentPage,
          rowsPerPage: _rowsPerPage,
          totalCount: _filteredOrders.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return ReportSummaryRow(cards: [
      ReportSummaryCard(
        title: 'Total Sales',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalSales)}',
        icon: Icons.currency_rupee,
        color: Colors.green,
      ),
      ReportSummaryCard(
        title: 'Total Orders',
        value: _totalOrdersCount.toString(),
        icon: Icons.receipt_long,
        color: Colors.orange,
      ),
    ]);
  }

  Widget _buildStatusBadge(String? status, double fontSize) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'PARTIALLY_REFUNDED':
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange.shade800;
        label = 'Partial Refund';
        break;
      default:
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green.shade700;
        label = 'Completed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: fontSize, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDataTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);
    final pageOrders = ReportPagination.pageSlice(_filteredOrders, _currentPage, _rowsPerPage);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Invoice ID'),
        ReportTable.column(context, 'Customer'),
        ReportTable.column(context, 'Payment'),
        ReportTable.column(context, 'Type'),
        ReportTable.column(context, 'Status'),
        ReportTable.column(context, 'Amount', numeric: true),
      ],
      rows: pageOrders.map((order) {
                final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);
                return DataRow(
                  cells: [
                    DataCell(Text(order.orderAt != null ? DateFormat('dd-MM-yy\nHH:mm').format(order.orderAt!) : 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(Text(order.billNumber != null ? 'INV ${order.billNumber}' : '#${(order.id.length > 8 ? order.id.substring(0, 8) : order.id)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                    DataCell(Text(order.customerName, style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
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
                        child: Text(order.paymentDisplay.isNotEmpty ? order.paymentDisplay : 'N/A', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    DataCell(Text(order.orderType ?? 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textSecondary))),
                    DataCell(_buildStatusBadge(order.orderStatus, cellFontSize)),
                    DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(netAmount)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                  ],
                );
      }).toList(),
    );
  }
}