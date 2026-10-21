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

class DiscountOrderReport extends StatefulWidget {
  const DiscountOrderReport({super.key});

  @override
  State<DiscountOrderReport> createState() => _DiscountOrderReportState();
}

class _DiscountOrderReportState extends State<DiscountOrderReport> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Discount Order Report',
        subtitle: 'Orders with discounts applied',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportPeriodFilterBar(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            featureNoun: 'discount orders',
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(child: DiscountDataView(period: _selectedPeriod)),
        ],
      ),
    );
  }
}

class DiscountDataView extends StatefulWidget {
  final ReportPeriod period;
  const DiscountDataView({super.key, required this.period});

  @override
  State<DiscountDataView> createState() => _DiscountDataViewState();
}

class _DiscountDataViewState extends State<DiscountDataView> {
  List<PastOrderModel> _filteredOrders = [];
  double _totalDiscountAmount = 0.0;
  double _totalSubtotal = 0.0;
  double _totalNetAmount = 0.0;
  int _totalOrdersCount = 0;
  double _averageDiscount = 0.0;
  bool _isLoading = true;
  bool _isDataLoaded = false;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadAndFilter();
  }

  @override
  void didUpdateWidget(covariant DiscountDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _filterFromMemory();
    }
  }

  Future<void> _loadAndFilter() async {
    if (!_isDataLoaded) {
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _filterFromMemory();
  }

  void _filterFromMemory() {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    late DateTime rangeStart;
    late DateTime rangeEnd;

    if (widget.period == ReportPeriod.custom) {
      if (_startDate == null || _endDate == null) {
        setState(() {
          _filteredOrders = [];
          _totalOrdersCount = 0;
          _totalDiscountAmount = 0.0;
          _totalSubtotal = 0.0;
          _totalNetAmount = 0.0;
          _averageDiscount = 0.0;
          _currentPage = 0;
          _isLoading = false;
        });
        return;
      }
      rangeStart = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      rangeEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1);
    } else {
      // Same helper the filter's history lock uses - they cannot disagree.
      rangeStart = reportPeriodStartBound(widget.period, now);
      rangeEnd = reportPeriodEndBound(widget.period, now);
    }

    final List<PastOrderModel> results = [];
    double discountSum = 0.0;
    double subtotalSum = 0.0;
    double netAmountSum = 0.0;

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    for (final order in pastOrderStore.pastOrders) {
      if ((order.Discount ?? 0) <= 0) continue;

      final status = order.orderStatus?.toUpperCase() ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) continue;

      final orderDate = order.orderAt;
      if (orderDate == null) continue;
      if (cutoff != null && orderDate.isBefore(cutoff)) continue;
      if (orderDate.isBefore(rangeStart) || !orderDate.isBefore(rangeEnd)) continue;

      results.add(order);
      discountSum += order.Discount ?? 0.0;
      subtotalSum += order.subTotal ?? 0.0;
      netAmountSum += order.totalPrice - (order.refundAmount ?? 0.0);
    }

    results.sort((a, b) => (b.orderAt ?? DateTime(0)).compareTo(a.orderAt ?? DateTime(0)));

    setState(() {
      _filteredOrders = results;
      _totalOrdersCount = results.length;
      _totalDiscountAmount = discountSum;
      _totalSubtotal = subtotalSum;
      _totalNetAmount = netAmountSum;
      _averageDiscount = _totalOrdersCount > 0 ? discountSum / _totalOrdersCount : 0.0;
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
      'Original',
      'Discount',
      'Final'
    ];

    final data = _filteredOrders.map((order) {
      final discount = order.Discount ?? 0.0;
      final netTotal = order.totalPrice - (order.refundAmount ?? 0.0);
      final original = netTotal + discount;
      return [
        ReportExportService.formatDateTime(order.orderAt),
        order.billNumber != null ? 'INV ${order.billNumber}' : '#${(order.id.length > 8 ? order.id.substring(0, 8) : order.id)}',
        order.customerName.isNotEmpty ? order.customerName : 'Guest',
        order.paymentmode ?? 'N/A',
        order.orderType ?? 'N/A',
        ReportExportService.formatCurrency(original),
        ReportExportService.formatCurrency(discount),
        ReportExportService.formatCurrency(netTotal),
      ];
    }).toList();

    final periodDisplay = _getPeriodDisplayName();

    final summary = {
      'Report Period': periodDisplay,
      'Total Orders': _totalOrdersCount.toString(),
      'Total Subtotal': ReportExportService.formatCurrency(_totalSubtotal),
      'Total Discount': ReportExportService.formatCurrency(_totalDiscountAmount),
      'Total Amount': ReportExportService.formatCurrency(_totalNetAmount),
      'Average Discount': ReportExportService.formatCurrency(_averageDiscount),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'discount_orders_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Discount Orders Report - $periodDisplay',
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
                icon: Icons.discount,
                title: 'No Discount Orders',
                message: 'No discount orders found for the selected date range',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportUI() {
    if (_filteredOrders.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.discount,
        title: 'No Discount Orders',
        message: 'No discount orders found for this period',
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
        title: 'Total Orders',
        value: _totalOrdersCount.toString(),
        icon: Icons.shopping_cart,
        color: AppColors.primary,
      ),
      ReportSummaryCard(
        title: 'Total Discount',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalDiscountAmount)}',
        icon: Icons.discount,
        color: Colors.orange,
      ),
      ReportSummaryCard(
        title: 'Avg Discount',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageDiscount)}',
        icon: Icons.analytics,
        color: Colors.green,
      ),
    ]);
  }

  Widget _buildDataTable() {
    final pageOrders = ReportPagination.pageSlice(_filteredOrders, _currentPage, _rowsPerPage);
    final cellFontSize = AppResponsive.smallFontSize(context);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Invoice'),
        ReportTable.column(context, 'Customer'),
        ReportTable.column(context, 'Payment'),
        ReportTable.column(context, 'Type'),
        ReportTable.column(context, 'Discount', numeric: true),
        ReportTable.column(context, 'Total', numeric: true),
      ],
      rows: pageOrders.map((order) {
                final discount = order.Discount ?? 0.0;
                // FIX 2: Net amount deducts any partial refund from totalPrice.
                final netTotal = order.totalPrice - (order.refundAmount ?? 0.0);
                return DataRow(
                  cells: [
                    DataCell(Text(order.orderAt != null ? DateFormat('dd-MM-yy\nHH:mm').format(order.orderAt!) : 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(Text(order.billNumber != null ? 'INV ${order.billNumber}' : '#${(order.id.length > 8 ? order.id.substring(0, 8) : order.id)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                    DataCell(Text(order.customerName.isNotEmpty ? order.customerName : 'Guest', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
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
                        child: Text(order.paymentmode ?? 'N/A', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    DataCell(Text(order.orderType ?? 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textSecondary))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(discount)}', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(netTotal)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                  ],
                );
      }).toList(),
    );
  }
}