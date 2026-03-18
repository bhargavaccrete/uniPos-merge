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
import '../../../../widget/componets/common/report_summary_card.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../tabbar/orderDetails.dart';

enum RefundPeriod { Today, ThisWeek, Month, Year, Custom }

class RefundDetails extends StatefulWidget {
  const RefundDetails({super.key});

  @override
  State<RefundDetails> createState() => _RefundDetailsState();
}

class _RefundDetailsState extends State<RefundDetails> {
  RefundPeriod _selectedPeriod = RefundPeriod.Today;

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
                          'Refund Details',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View refunds across different periods',
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      size: AppResponsive.iconSize(context),
                      color: AppColors.primary,
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
                  _filterButton(RefundPeriod.Today, 'Today', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(RefundPeriod.ThisWeek, 'This Week', Icons.view_week),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(RefundPeriod.Month, 'This Month', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(RefundPeriod.Year, 'This Year', Icons.calendar_today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(RefundPeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: RefundDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(RefundPeriod period, String title, IconData icon) {
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

class RefundDataView extends StatefulWidget {
  final RefundPeriod period;
  const RefundDataView({super.key, required this.period});

  @override
  State<RefundDataView> createState() => _RefundDataViewState();
}

class _RefundDataViewState extends State<RefundDataView> {
  List<PastOrderModel> _refundedOrders = [];
  double _totalRefundAmount = 0.0;
  int _totalRefundCount = 0;
  String _mostCommonReason = '-';
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
  void didUpdateWidget(covariant RefundDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _filterFromMemory();
    }
  }

  Future<void> _loadAndFilter() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _filterFromMemory();
  }

  /// Single-pass filter with pre-computed boundaries — matches total sales pattern.
  void _filterFromMemory() {
    final now = DateTime.now();
    final results = <PastOrderModel>[];
    double refundTotal = 0.0;
    final reasonCounts = <String, int>{};

    // Pre-compute date boundaries
    final isCustom = widget.period == RefundPeriod.Custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      switch (widget.period) {
        case RefundPeriod.Today:
          startBound = DateTime(now.year, now.month, now.day);
          endBound = startBound.add(const Duration(days: 1));
          break;
        case RefundPeriod.ThisWeek:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          startBound = DateTime(weekStart.year, weekStart.month, weekStart.day);
          endBound = startBound.add(const Duration(days: 7));
          break;
        case RefundPeriod.Month:
          startBound = DateTime(now.year, now.month);
          endBound = DateTime(now.year, now.month + 1);
          break;
        case RefundPeriod.Year:
          startBound = DateTime(now.year);
          endBound = DateTime(now.year + 1);
          break;
        case RefundPeriod.Custom:
          break;
      }
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    // Single pass: date filter + status filter + accumulate totals + reason counts
    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus ?? '';
      if (status != 'FULLY_REFUNDED' && status != 'PARTIALLY_REFUNDED') continue;
      if (order.refundedAt == null) continue;
      if (isCustom && !hasCustomRange) continue;

      if (order.refundedAt!.isBefore(startBound) || !order.refundedAt!.isBefore(endBound)) {
        continue;
      }

      results.add(order);
      refundTotal += order.refundAmount ?? 0.0;

      // Track reason counts for most-common computation
      if (order.refundReason != null && order.refundReason!.isNotEmpty) {
        final lines = order.refundReason!.split('\n');
        final reason = lines.isNotEmpty ? lines.last.trim() : '';
        if (reason.isNotEmpty) {
          reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        }
      }
    }

    // Sort by refund date descending
    results.sort((a, b) =>
        (b.refundedAt ?? DateTime(2000)).compareTo(a.refundedAt ?? DateTime(2000)));

    // Compute most common reason
    String topReason = '-';
    if (reasonCounts.isNotEmpty) {
      var best = reasonCounts.entries.first;
      for (final entry in reasonCounts.entries) {
        if (entry.value > best.value) best = entry;
      }
      topReason = best.key;
    }

    setState(() {
      _refundedOrders = results;
      _totalRefundCount = results.length;
      _totalRefundAmount = refundTotal;
      _mostCommonReason = topReason;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _exportReport() async {
    if (_refundedOrders.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    // Prepare headers
    final headers = [
      'Date & Time',
      'Bill #',
      'Customer',
      'Payment Method',
      'Order Type',
      'Refund Amount',
      'Reason'
    ];

    // Prepare data rows
    final data = _refundedOrders.map((order) {
      String reason = '';
      if (order.refundReason != null && order.refundReason!.isNotEmpty) {
        final lines = order.refundReason!.split('\n');
        reason = lines.isNotEmpty ? lines.last.trim() : '';
      }

      return [
        ReportExportService.formatDateTime(order.refundedAt),
        order.billNumber?.toString() ?? order.id.substring(0, 8),
        order.customerName ?? 'Guest',
        order.paymentmode ?? 'N/A',
        order.orderType ?? 'N/A',
        ReportExportService.formatCurrency(order.refundAmount ?? 0.0),
        reason,
      ];
    }).toList();

    // Prepare summary
    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Period': periodName,
      'Total Refunds': _totalRefundCount.toString(),
      'Total Refund Amount': ReportExportService.formatCurrency(_totalRefundAmount),
      'Most Common Reason': _mostCommonReason,
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'refund_details_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Refund Details - $periodName',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    switch (widget.period) {
      case RefundPeriod.Today:
        return 'Today';
      case RefundPeriod.ThisWeek:
        return 'This Week';
      case RefundPeriod.Month:
        return 'This Month';
      case RefundPeriod.Year:
        return 'This Year';
      case RefundPeriod.Custom:
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

    if (widget.period == RefundPeriod.Custom) {
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
                if (_refundedOrders.isNotEmpty)
                  _buildReportContent(isTablet)
                else
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('No refunds found', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        SizedBox(height: 4),
                        Text('No refunds found for the selected date range', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                      ],
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
    if (_refundedOrders.isEmpty) {
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
                Icons.receipt_long_outlined,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Refunds Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No refunds found for this period',
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
        if (_refundedOrders.length > _rowsPerPage)
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildSummaryCards(bool isTablet) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ReportSummaryCard(
                title: 'Total Refunds',
                value: _totalRefundCount.toString(),
                icon: Icons.receipt_long,
                color: AppColors.primary,
              ),
            ),
            AppResponsive.horizontalSpace(context),
            Expanded(
              child: ReportSummaryCard(
                title: 'Total Amount',
                value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRefundAmount)}',
                icon: Icons.monetization_on,
                color: Colors.red,
              ),
            ),
          ],
        ),
        AppResponsive.verticalSpace(context),
        ReportSummaryCard(
          title: 'Common Reason',
          value: _mostCommonReason,
          icon: Icons.info_outline,
          color: Colors.orange,
        ),
      ],
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

  Widget _buildPaginationControls() {
    final totalPages = (_refundedOrders.length / _rowsPerPage).ceil();
    final start = _currentPage * _rowsPerPage + 1;
    final end = ((_currentPage + 1) * _rowsPerPage).clamp(1, _refundedOrders.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start–$end of ${_refundedOrders.length} refunds',
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

  Widget _buildDataTable(bool isTablet) {
    final screenWidth = AppResponsive.screenWidth(context);
    final cellFontSize = AppResponsive.smallFontSize(context);
    final headerFontSize = AppResponsive.bodyFontSize(context);
    final pageOrders = _refundedOrders.length <= _rowsPerPage
        ? _refundedOrders
        : _refundedOrders.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();

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
                DataColumn(label: Text('Order ID', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Customer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Reason', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
              ],
              rows: pageOrders.map((order) {
                String reason = '-';
                if (order.refundReason != null && order.refundReason!.isNotEmpty) {
                  final lines = order.refundReason!.split('\n');
                  reason = lines.isNotEmpty ? lines.last.trim() : '-';
                }

                return DataRow(
                  onSelectChanged: (selected) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Orderdetails(Order: order),
                      ),
                    );
                  },
                  cells: [
                    DataCell(Text(order.refundedAt != null ? DateFormat('dd-MM-yy\nHH:mm').format(order.refundedAt!) : 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(Text('#${order.id?.substring(0, 8) ?? 'N/A'}...', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                    DataCell(Text(order.customerName ?? '-', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
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
                    DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(order.refundAmount ?? 0.0)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: Colors.red.shade600, fontWeight: FontWeight.w600))),
                    DataCell(
                      Container(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Text(reason, style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 2),
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