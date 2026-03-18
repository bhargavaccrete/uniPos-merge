import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';

enum DiscountPeriod { Today, ThisWeek, Month, Year, Custom }

class DiscountOrderReport extends StatefulWidget {
  const DiscountOrderReport({super.key});

  @override
  State<DiscountOrderReport> createState() => _DiscountOrderReportState();
}

class _DiscountOrderReportState extends State<DiscountOrderReport> {
  DiscountPeriod _selectedPeriod = DiscountPeriod.Today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Modern Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back, color: AppColors.white, size: 24),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discount Orders',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Track orders with discounts',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0)),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.discount,
                      size: AppResponsive.iconSize(context),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          // Filter Buttons
          Container(
            color: AppColors.white,
            padding: AppResponsive.horizontalPadding(context).copyWith(top: 12, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton(DiscountPeriod.Today, 'Today', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.ThisWeek, 'This Week', Icons.view_week),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.Month, 'This Month', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.Year, 'This Year', Icons.calendar_today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: DiscountDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(DiscountPeriod period, String title, IconData icon) {
    bool isSelected = _selectedPeriod == period;
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      icon: Icon(icon, size: AppResponsive.smallIconSize(context)),
      label: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
          vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0),
        ),
        backgroundColor: isSelected ? AppColors.primary : AppColors.white,
        foregroundColor: isSelected ? AppColors.white : AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1,
          ),
        ),
      ),
    );
  }
}

class DiscountDataView extends StatefulWidget {
  final DiscountPeriod period;
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

    if (widget.period == DiscountPeriod.Custom) {
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
      switch (widget.period) {
        case DiscountPeriod.Today:
          rangeStart = DateTime(now.year, now.month, now.day);
          rangeEnd = DateTime(now.year, now.month, now.day + 1);
          break;
        case DiscountPeriod.ThisWeek:
          final weekDay = now.subtract(Duration(days: now.weekday - 1));
          rangeStart = DateTime(weekDay.year, weekDay.month, weekDay.day);
          rangeEnd = rangeStart.add(const Duration(days: 7));
          break;
        case DiscountPeriod.Month:
          rangeStart = DateTime(now.year, now.month, 1);
          rangeEnd = DateTime(now.year, now.month + 1, 1);
          break;
        case DiscountPeriod.Year:
          rangeStart = DateTime(now.year, 1, 1);
          rangeEnd = DateTime(now.year + 1, 1, 1);
          break;
        case DiscountPeriod.Custom:
          break;
      }
    }

    final List<PastOrderModel> results = [];
    double discountSum = 0.0;
    double subtotalSum = 0.0;
    double netAmountSum = 0.0;

    for (final order in pastOrderStore.pastOrders) {
      if ((order.Discount ?? 0) <= 0) continue;

      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status == 'VOID' || status == 'VOIDED' || status == 'FULLY_REFUNDED') continue;

      final orderDate = order.orderAt;
      if (orderDate == null) continue;
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
      'Date & Time',
      'Invoice ID',
      'Customer',
      'Payment Method',
      'Order Type',
      'Subtotal',
      'Discount',
      'Total Amount'
    ];

    final data = _filteredOrders.map((order) => [
      ReportExportService.formatDateTime(order.orderAt),
      order.billNumber != null ? 'INV ${order.billNumber}' : '#${order.id.substring(0, 8)}',
      order.customerName.isNotEmpty ? order.customerName : 'Guest',
      order.paymentmode ?? 'N/A',
      order.orderType ?? 'N/A',
      ReportExportService.formatCurrency(order.subTotal ?? 0.0),
      ReportExportService.formatCurrency(order.Discount ?? 0.0),
      // FIX 2: Use net amount in export to match the table display.
      ReportExportService.formatCurrency(order.totalPrice - (order.refundAmount ?? 0.0)),
    ]).toList();

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
    switch (widget.period) {
      case DiscountPeriod.Today:
        return 'Today';
      case DiscountPeriod.ThisWeek:
        return 'This Week';
      case DiscountPeriod.Month:
        return 'This Month';
      case DiscountPeriod.Year:
        return 'This Year';
      case DiscountPeriod.Custom:
        if (_startDate != null && _endDate != null) {
          return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
        }
        return 'Custom Period';
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) {
    return showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    ).then((picked) {
      if (picked != null) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
          } else {
            _endDate = picked;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (widget.period == DiscountPeriod.Custom) {
      return _buildCustomDateSelector(isTablet);
    }

    return _buildReportUI(isTablet);
  }

  Widget _buildCustomDateSelector(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    String formatDate(DateTime? date) {
      if (date == null) return 'Select Date';
      return DateFormat('dd MMM, yyyy').format(date);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1400 : 1000),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Date Range',
                      style: GoogleFonts.poppins(
                        fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDatePickerButton('Start Date', formatDate(_startDate), () => _selectDate(context, true), isTablet)),
                        SizedBox(width: 16),
                        Expanded(child: _buildDatePickerButton('End Date', formatDate(_endDate), () => _selectDate(context, false), isTablet)),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_startDate != null && _endDate != null) ? _filterFromMemory : null,
                        icon: Icon(Icons.filter_list, size: isTablet ? 20 : 18),
                        label: Text(
                          'Apply Filter',
                          style: GoogleFonts.poppins(fontSize: isTablet ? 16 : 15, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          disabledBackgroundColor: AppColors.divider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_startDate != null && _endDate != null) ...[
                SizedBox(height: 16),
                _filteredOrders.isNotEmpty
                    ? _buildReportContent(isTablet)
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No discount orders found for this period',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(String label, String value, VoidCallback onPressed, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: isTablet ? 14 : 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 14 : 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 14 : 13,
                    color: value == 'Select Date' ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                Icon(Icons.calendar_today, size: isTablet ? 20 : 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportUI(bool isTablet) {
    if (_filteredOrders.isEmpty) {
      return Center(
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
                Icons.discount,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Discount Orders',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No discount orders found for this period',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: _buildReportContent(isTablet),
      ),
    );
  }

  Widget _buildReportContent(bool isTablet) {
    return Column(
      children: [
        _buildSummaryCards(isTablet),
        SizedBox(height: 16),
        _buildExportButton(isTablet),
        SizedBox(height: 16),
        _buildDataTable(isTablet),
        if (_filteredOrders.length > _rowsPerPage) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_filteredOrders.length / _rowsPerPage).ceil();
    final start = _currentPage * _rowsPerPage + 1;
    final end = ((_currentPage + 1) * _rowsPerPage).clamp(1, _filteredOrders.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start\u2013$end of ${_filteredOrders.length} orders',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 24,
                color: AppColors.primary,
                disabledColor: AppColors.divider,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 24,
                color: AppColors.primary,
                disabledColor: AppColors.divider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isTablet) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ReportSummaryCard(
              title: 'Total Orders',
              value: _totalOrdersCount.toString(),
              icon: Icons.shopping_cart,
              color: AppColors.primary,
            ),
          ),
          AppResponsive.horizontalSpace(context),
          Expanded(
            child: ReportSummaryCard(
              title: 'Total Discount',
              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalDiscountAmount)}',
              icon: Icons.discount,
              color: Colors.orange,
            ),
          ),
          AppResponsive.horizontalSpace(context),
          Expanded(
            child: ReportSummaryCard(
              title: 'Avg Discount',
              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageDiscount)}',
              icon: Icons.analytics,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportReport,
        icon: Icon(Icons.file_download_outlined, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Export to Excel',
          style: GoogleFonts.poppins(fontSize: isDesktop ? 17 : (isTablet ? 16 : 15), fontWeight: FontWeight.w600),
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

  Widget _buildDataTable(bool isTablet) {
    final pageOrders = _filteredOrders.length <= _rowsPerPage
        ? _filteredOrders
        : _filteredOrders.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
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
                DataColumn(label: Text('Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Invoice ID', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Customer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Discount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
              ],
              rows: pageOrders.map((order) {
                final discount = order.Discount ?? 0.0;
                // FIX 2: Net amount deducts any partial refund from totalPrice.
                final netTotal = order.totalPrice - (order.refundAmount ?? 0.0);
                return DataRow(
                  cells: [
                    DataCell(Text(order.orderAt != null ? DateFormat('dd-MM-yy\nHH:mm').format(order.orderAt!) : 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(Text(order.billNumber != null ? 'INV ${order.billNumber}' : '#${order.id.substring(0, 8)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
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
            ),
          ),
        ),
      ),
    );
  }
}