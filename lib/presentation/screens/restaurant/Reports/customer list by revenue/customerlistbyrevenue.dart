import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
import '../../../../widget/componets/common/report_summary_card.dart';

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

    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status == 'VOID' || status == 'VOIDED' || status == 'FULLY_REFUNDED') continue;

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
  (DateTime?, DateTime?) _periodBounds() {
    final now = DateTime.now();
    switch (_period) {
      case _RevPeriod.all:
        return (null, null);
      case _RevPeriod.today:
        final s = DateTime(now.year, now.month, now.day);
        return (s, s.add(const Duration(days: 1)));
      case _RevPeriod.week:
        final s = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return (s, s.add(const Duration(days: 7)));
      case _RevPeriod.month:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
      case _RevPeriod.year:
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
      case _RevPeriod.custom:
        if (_fromDate == null || _toDate == null) return (null, null);
        return (
          DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day)
              .add(const Duration(days: 1)),
        );
    }
  }

  Future<void> _onPeriodSelected(_RevPeriod p) async {
    if (p == _RevPeriod.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: (_fromDate != null && _toDate != null)
            ? DateTimeRange(start: _fromDate!, end: _toDate!)
            : null,
      );
      if (range == null) return;
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
        _period = p;
      });
    } else {
      setState(() => _period = p);
    }
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
    Widget chip(_RevPeriod p) {
      final selected = _period == p;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(_periodLabel(p)),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => _onPeriodSelected(p),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.white,
          labelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(_RevPeriod.all),
            chip(_RevPeriod.today),
            chip(_RevPeriod.week),
            chip(_RevPeriod.month),
            chip(_RevPeriod.year),
            chip(_RevPeriod.custom),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport() async {
    if (_customers.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Rank',
      'Customer Name',
      'Total Orders',
      'Total Revenue',
    ];

    final data = _customers.map((customer) => [
      customer.srNo.toString(),
      customer.name,
      customer.orderCount.toString(),
      ReportExportService.formatCurrency(customer.revenue),
    ]).toList();

    final averageRevenue = _customers.isNotEmpty ? _totalRevenue / _customers.length : 0.0;

    final summary = {
      'Total Customers': _customers.length.toString(),
      'Total Orders': _totalOrders.toString(),
      'Total Revenue': ReportExportService.formatCurrency(_totalRevenue),
      'Average Revenue per Customer': ReportExportService.formatCurrency(averageRevenue),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'customer_revenue_${DateFormat('yyyyMMdd').format(DateTime.now())}',
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
      appBar: buildPrimaryAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customer Revenue',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            Text(
              'Top customers by revenue',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
          children: [
            _buildPeriodFilter(context),
            const SizedBox(height: 16),
            if (_customers.isEmpty)
              _buildEmptyState(context)
            else ...[
              _buildSummaryCards(context),
              SizedBox(height: 16),
              _buildRefreshButton(context, isTablet),
              SizedBox(height: 16),
              _buildExportButton(context, isTablet),
              SizedBox(height: 16),
              _buildCustomersTable(context, isTablet),
              if (_customers.length > _rowsPerPage) ...[
                SizedBox(height: 16),
                _buildPaginationControls(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 40.0, desktop: 60.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0)),
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Customer Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No customer revenue data found',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final averageRevenue = _customers.isNotEmpty ? _totalRevenue / _customers.length : 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ReportSummaryCard(
              title: 'Total Customers',
              value: _customers.length.toString(),
              icon: Icons.people,
              color: AppColors.primary,
            ),
          ),
          AppResponsive.horizontalSpace(context),
          Expanded(
            child: ReportSummaryCard(
              title: 'Total Revenue',
              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRevenue)}',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
          ),
          AppResponsive.horizontalSpace(context),
          Expanded(
            child: ReportSummaryCard(
              title: 'Avg Revenue',
              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(averageRevenue)}',
              icon: Icons.analytics,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, bool isTablet) {
    final isDesktop = AppResponsive.isDesktop(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _loadCustomerRevenue(forceReload: true),
        icon: Icon(Icons.refresh, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Refresh Data',
          style: GoogleFonts.poppins(
            fontSize: isDesktop ? 17 : (isTablet ? 16 : 15),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 18 : (isTablet ? 16 : 14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, bool isTablet) {
    final isDesktop = AppResponsive.isDesktop(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportReport,
        icon: Icon(Icons.file_download_outlined, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Export Report',
          style: GoogleFonts.poppins(
            fontSize: isDesktop ? 17 : (isTablet ? 16 : 15),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 18 : (isTablet ? 16 : 14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_customers.length / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          icon: Icon(Icons.chevron_left),
          color: AppColors.primary,
        ),
        Text(
          'Page ${_currentPage + 1} of $totalPages',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
          icon: Icon(Icons.chevron_right),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildCustomersTable(BuildContext context, bool isTablet) {
    final screenWidth = AppResponsive.screenWidth(context);
    final cellFontSize = AppResponsive.smallFontSize(context);
    final headerFontSize = AppResponsive.bodyFontSize(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth - AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0),
            ),
            child: DataTable(
              columnSpacing: AppResponsive.tableColumnSpacing(context),
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
              headingRowHeight: AppResponsive.tableHeadingHeight(context),
              dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
              dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
              columns: [
                DataColumn(
                  label: Text(
                    'Rank',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Customer Name',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Total Orders',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Total Revenue',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: _customers.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).map((customer) {
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
                            Icon(medalIcon, color: rankColor, size: AppResponsive.getValue(context, mobile: 18.0, desktop: 20.0)),
                            SizedBox(width: 4),
                          ],
                          Text(
                            customer.srNo.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: cellFontSize,
                              color: AppColors.textPrimary,
                              fontWeight: customer.srNo <= 3 ? FontWeight.w700 : FontWeight.w500,
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
                          fontWeight: customer.srNo <= 3 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
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
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
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
            ),
          ),
        ),
      ),
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