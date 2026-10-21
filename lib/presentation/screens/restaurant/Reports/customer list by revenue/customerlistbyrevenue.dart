import 'package:flutter/material.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_range_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/widgets/upgrade_sheet.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

enum _RevPeriod { all, today, week, month, year, custom }

class CustomerListByRevenue extends StatefulWidget {
  const CustomerListByRevenue({super.key});

  @override
  State<CustomerListByRevenue> createState() => _CustomerListByRevenueState();
}

class _CustomerListByRevenueState extends State<CustomerListByRevenue> {
  bool _isLoading = true;
  bool _isDataLoaded = false;

  // Pre-computed state
  List<CustomerRevenueData> _customers = [];
  double _totalRevenue = 0.0;
  int _totalOrders = 0;

  // Period filter (default: all-time).
  _RevPeriod _period = _RevPeriod.all;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadCustomerRevenue();
  }

  Future<void> _loadCustomerRevenue({bool forceReload = false}) async {
    if (_isDataLoaded && !forceReload) return;
    setState(() => _isLoading = true);
    await pastOrderStore.loadPastOrders();
    _isDataLoaded = true;
    _buildCustomerData();
  }

  void _buildCustomerData() {
    final Map<String, CustomerRevenueData> customerMap = {};
    double revenueSum = 0.0;
    int orderSum = 0;

    final (start, end) = _periodBounds();

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) continue;
      if (cutoff != null &&
          order.orderAt != null &&
          order.orderAt!.isBefore(cutoff))
        continue;

      // Period filter — orders without a timestamp can't be placed in a range.
      if (start != null && end != null) {
        final at = order.orderAt;
        if (at == null || at.isBefore(start) || !at.isBefore(end)) continue;
      }

      String customerName = order.customerName.trim();
      if (customerName.isEmpty) {
        customerName = 'Walk-in Customer';
      }

      final netRevenue = order.totalPrice - (order.refundAmount ?? 0.0);
      if (netRevenue <= 0) continue;

      revenueSum += netRevenue;
      orderSum++;

      final mapKey = customerName.toLowerCase();
      if (customerMap.containsKey(mapKey)) {
        customerMap[mapKey]!.revenue += netRevenue;
        customerMap[mapKey]!.orderCount += 1;
      } else {
        customerMap[mapKey] = CustomerRevenueData(
          srNo: 0,
          name: customerName,
          revenue: netRevenue,
          orderCount: 1,
        );
      }
    }

    final customers = customerMap.values.toList();
    customers.sort((a, b) => b.revenue.compareTo(a.revenue));
    for (int i = 0; i < customers.length; i++) {
      customers[i].srNo = i + 1;
    }

    setState(() {
      _customers = customers;
      _totalRevenue = revenueSum;
      _totalOrders = orderSum;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  /// Half-open [start, end) bounds for the selected period; (null, null) for
  /// all-time or an incomplete custom range.
  /// null bounds = no date restriction ('All'; or Custom before a range is set).
  (DateTime?, DateTime?) _periodBounds() {
    final now = DateTime.now();
    final standard = _standardPeriod(_period);
    if (standard != null) {
      return (
        reportPeriodStartBound(standard, now),
        reportPeriodEndBound(standard, now),
      );
    }
    if (_period == _RevPeriod.custom && _fromDate != null && _toDate != null) {
      return (
        DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
        DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
        ).add(const Duration(days: 1)),
      );
    }
    return (null, null);
  }

  /// The kit period this maps to, or null for 'all' / 'custom' (unbounded).
  static ReportPeriod? _standardPeriod(_RevPeriod p) {
    switch (p) {
      case _RevPeriod.today:
        return ReportPeriod.today;
      case _RevPeriod.week:
        return ReportPeriod.thisWeek;
      case _RevPeriod.month:
        return ReportPeriod.thisMonth;
      case _RevPeriod.year:
        return ReportPeriod.thisYear;
      case _RevPeriod.all:
      case _RevPeriod.custom:
        return null;
    }
  }

  bool _periodAllowed(_RevPeriod p) {
    final standard = _standardPeriod(p);
    if (standard == null)
      return true; // 'all'/'custom' are clamped by the cutoff
    return ReportHistoryWindow.allows(
      reportPeriodStartBound(standard, DateTime.now()),
    );
  }

  IconData _periodIcon(_RevPeriod p) {
    switch (p) {
      case _RevPeriod.all:
        return Icons.all_inclusive;
      case _RevPeriod.today:
        return Icons.today;
      case _RevPeriod.week:
        return Icons.view_week;
      case _RevPeriod.month:
        return Icons.calendar_month;
      case _RevPeriod.year:
        return Icons.calendar_today;
      case _RevPeriod.custom:
        return Icons.date_range;
    }
  }

  void _onPeriodSelected(_RevPeriod p) {
    // Custom no longer fires a full-screen showDateRangePicker on tap — the
    // shared ReportDateRangeCard appears in the body instead, which is how the
    // other reports with a custom range do it.
    setState(() => _period = p);
    // Data is already loaded — just re-aggregate for the new period.
    _buildCustomerData();
  }

  String _periodLabel(_RevPeriod p) {
    switch (p) {
      case _RevPeriod.all:
        return 'All';
      case _RevPeriod.today:
        return 'Today';
      case _RevPeriod.week:
        return 'This Week';
      case _RevPeriod.month:
        return 'This Month';
      case _RevPeriod.year:
        return 'This Year';
      case _RevPeriod.custom:
        if (_fromDate != null && _toDate != null) {
          return '${DateFormat('dd MMM').format(_fromDate!)} – ${DateFormat('dd MMM').format(_toDate!)}';
        }
        return 'Custom';
    }
  }

  Widget _buildPeriodFilter(BuildContext context) {
    return ReportFilterBar<_RevPeriod>(
      selected: _period,
      onSelected: _onPeriodSelected,
      options: [
        for (final p in _RevPeriod.values)
          ReportFilterOption(
            value: p,
            label: _periodLabel(p),
            icon: _periodIcon(p),
            locked: !_periodAllowed(p),
            onLockedTap: () => UpgradeSheet.showHistoryLimit(
              context,
              featureName: '${_periodLabel(p)} customer revenue',
              neededDays: ReportHistoryWindow.requiredDays(
                reportPeriodStartBound(_standardPeriod(p)!, DateTime.now()),
              ),
              allowedDays: ReportHistoryWindow.limitDays ?? 0,
            ),
          ),
      ],
    );
  }

  Future<void> _exportReport() async {
    if (_customers.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = ['Rank', 'Customer Name', 'Total Orders', 'Total Revenue'];

    final data = _customers
        .map(
          (customer) => [
            customer.srNo.toString(),
            customer.name,
            customer.orderCount.toString(),
            ReportExportService.formatCurrency(customer.revenue),
          ],
        )
        .toList();

    final averageRevenue = _customers.isNotEmpty
        ? _totalRevenue / _customers.length
        : 0.0;

    final summary = {
      'Total Customers': _customers.length.toString(),
      'Total Orders': _totalOrders.toString(),
      'Total Revenue': ReportExportService.formatCurrency(_totalRevenue),
      'Average Revenue per Customer': ReportExportService.formatCurrency(
        averageRevenue,
      ),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName:
          'customer_revenue_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Customer Revenue Report',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Customer Revenue',
        subtitle: 'Top customers by revenue',
        actions: [
          IconButton(
            onPressed: () => _loadCustomerRevenue(forceReload: true),
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) return const ReportLoading();

    return Column(
      children: [
        AppResponsive.verticalSpace(context, size: SpacingSize.small),
        _buildPeriodFilter(context),
        AppResponsive.verticalSpace(context, size: SpacingSize.small),
        Expanded(
          child: ReportBody(
            child: Column(
              children: [
                // Custom period: the shared range card renders in the body,
                // same as the other reports that offer one. The report itself
                // waits until both dates are applied.
                if (_period == _RevPeriod.custom) ...[
                  ReportDateRangeCard(
                    initialStart: _fromDate,
                    initialEnd: _toDate,
                    onApply: (start, end) {
                      setState(() {
                        _fromDate = start;
                        _toDate = end;
                      });
                      _buildCustomerData();
                    },
                  ),
                  AppResponsive.verticalSpace(context),
                ],
                if (_period != _RevPeriod.custom ||
                    (_fromDate != null && _toDate != null)) ...[
                  if (_customers.isEmpty)
                    const ReportEmptyState(
                      icon: Icons.people,
                      title: 'No Customer Data',
                      message: 'No customer revenue data found',
                    )
                  else ...[
                    _buildSummaryCards(context),
                    AppResponsive.verticalSpace(context),
                    ReportExportButton(onPressed: _exportReport),
                    AppResponsive.verticalSpace(context),
                    _buildCustomersTable(context),
                    ReportPagination(
                      currentPage: _currentPage,
                      rowsPerPage: _rowsPerPage,
                      totalCount: _customers.length,
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
                      unit: 'customers',
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final averageRevenue = _customers.isNotEmpty
        ? _totalRevenue / _customers.length
        : 0.0;

    return ReportSummaryRow(
      cards: [
        ReportSummaryCard(
          title: 'Total Customers',
          value: _customers.length.toString(),
          icon: Icons.people,
          color: AppColors.primary,
        ),
        ReportSummaryCard(
          title: 'Total Revenue',
          value:
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRevenue)}',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        ReportSummaryCard(
          title: 'Avg Revenue',
          value:
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(averageRevenue)}',
          icon: Icons.analytics,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildCustomersTable(BuildContext context) {
    final cellFontSize = AppResponsive.smallFontSize(context);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Rank'),
        ReportTable.column(context, 'Customer Name'),
        ReportTable.column(context, 'Total Orders', numeric: true),
        ReportTable.column(context, 'Total Revenue', numeric: true),
      ],
      rows: ReportPagination.pageSlice(_customers, _currentPage, _rowsPerPage).map((
        customer,
      ) {
        // Medal colors for top 3
        Color? rankColor;
        IconData? medalIcon;
        if (customer.srNo == 1) {
          rankColor = Color(0xFFFFD700); // Gold
          medalIcon = Icons.workspace_premium;
        } else if (customer.srNo == 2) {
          rankColor = Color(0xFFC0C0C0); // Silver
          medalIcon = Icons.workspace_premium;
        } else if (customer.srNo == 3) {
          rankColor = Color(0xFFCD7F32); // Bronze
          medalIcon = Icons.workspace_premium;
        }

        return DataRow(
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (medalIcon != null) ...[
                    Icon(
                      medalIcon,
                      color: rankColor,
                      size: AppResponsive.getValue(
                        context,
                        mobile: 18.0,
                        desktop: 20.0,
                      ),
                    ),
                    SizedBox(width: 4),
                  ],
                  Text(
                    customer.srNo.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: cellFontSize,
                      color: AppColors.textPrimary,
                      fontWeight: customer.srNo <= 3
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            DataCell(
              Text(
                customer.name,
                style: GoogleFonts.poppins(
                  fontSize: cellFontSize,
                  color: AppColors.textPrimary,
                  fontWeight: customer.srNo <= 3
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            DataCell(
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.getValue(
                    context,
                    mobile: 8.0,
                    desktop: 12.0,
                  ),
                  vertical: AppResponsive.getValue(
                    context,
                    mobile: 4.0,
                    desktop: 6.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  customer.orderCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataCell(
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.getValue(
                    context,
                    mobile: 8.0,
                    desktop: 12.0,
                  ),
                  vertical: AppResponsive.getValue(
                    context,
                    mobile: 4.0,
                    desktop: 6.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(customer.revenue)}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class CustomerRevenueData {
  int srNo;
  final String name;
  double revenue;
  int orderCount;

  CustomerRevenueData({
    required this.srNo,
    required this.name,
    required this.revenue,
    required this.orderCount,
  });
}
