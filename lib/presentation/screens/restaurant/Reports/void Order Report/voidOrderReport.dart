import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import '../../../../widget/componets/common/report_app_bar.dart';
import '../../../../widget/componets/common/report_card.dart';
import '../../../../widget/componets/common/report_empty_state.dart';
import '../../../../widget/componets/common/report_export_button.dart';
import '../../../../widget/componets/common/report_filter_bar.dart';
import '../../../../widget/componets/common/report_pagination.dart';
import '../../../../widget/componets/common/report_summary_row.dart';
import '../../../../widget/componets/common/report_table.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../tabbar/orderDetails.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/refund_state.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

enum VoidOrderPeriod { Today, ThisWeek, Month, Year, Custom }

class VoidOrderReport extends StatefulWidget {
  const VoidOrderReport({super.key});

  @override
  State<VoidOrderReport> createState() => _VoidOrderReportState();
}

class _VoidOrderReportState extends State<VoidOrderReport> {
  VoidOrderPeriod _selectedPeriod = VoidOrderPeriod.Today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Void Order Report',
        subtitle: 'Orders voided across periods',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportFilterBar<VoidOrderPeriod>(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            options: const [
              ReportFilterOption(
                  value: VoidOrderPeriod.Today, label: 'Today', icon: Icons.today),
              ReportFilterOption(
                  value: VoidOrderPeriod.ThisWeek, label: 'This Week', icon: Icons.view_week),
              ReportFilterOption(
                  value: VoidOrderPeriod.Month, label: 'Month', icon: Icons.calendar_month),
              ReportFilterOption(
                  value: VoidOrderPeriod.Year, label: 'Year', icon: Icons.calendar_today),
              ReportFilterOption(
                  value: VoidOrderPeriod.Custom, label: 'Custom', icon: Icons.date_range),
            ],
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(
            child: VoidOrderDataView(period: _selectedPeriod),
          ),
        ],
      ),
    );
  }
}

class VoidOrderDataView extends StatefulWidget {
  final VoidOrderPeriod period;

  const VoidOrderDataView({
    super.key,
    required this.period,
  });

  @override
  State<VoidOrderDataView> createState() => _VoidOrderDataViewState();
}

class _VoidOrderDataViewState extends State<VoidOrderDataView> {
  String _getRefundStatusText(PastOrderModel order) {
    final state = RefundInfo.state(order);
    switch (state) {
      case RefundState.full:
        return 'Fully Refunded';
      case RefundState.partial:
        return 'Partially Refunded';
      case RefundState.none:
        final pm = order.paymentmode ?? '';
        final isPaidVoid = pm.isNotEmpty && pm != 'N/A';
        return isPaidVoid ? 'Refund Pending' : '—';
    }
  }

  Color _getRefundStatusColor(PastOrderModel order) {
    final state = RefundInfo.state(order);
    switch (state) {
      case RefundState.full:
        return Colors.red.shade700;
      case RefundState.partial:
        return Colors.orange.shade800;
      case RefundState.none:
        final pm = order.paymentmode ?? '';
        final isPaidVoid = pm.isNotEmpty && pm != 'N/A';
        return isPaidVoid ? Colors.blue.shade700 : AppColors.textSecondary;
    }
  }

  List<PastOrderModel> _voidOrders = [];
  double _totalVoidAmount = 0.0;
  int _totalVoidCount = 0;
  double _averageVoidAmount = 0.0;
  String _mostCommonReason = '—';

  // Custom date range
  DateTime? _startDate;
  DateTime? _endDate;

  // Month selection
  int _selectedMonth = DateTime.now().month;
  int _selectedMonthYear = DateTime.now().year;

  // Year selection
  int _selectedYear = DateTime.now().year;

  // Year list
  List<int> _years = [];

  // Month names
  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  bool _isLoading = true;
  bool _isDataLoaded = false;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _initializeYears();
    _loadAndFilter();
  }

  @override
  void didUpdateWidget(covariant VoidOrderDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _filterFromMemory();
    }
  }

  /// Only offer years the plan's history window can actually reach. Otherwise
  /// picking 2019 on a 30-day plan silently yields an empty table.
  void _initializeYears() {
    final currentYear = DateTime.now().year;
    final earliest = ReportHistoryWindow.cutoff?.year ?? (currentYear - 9);
    _years = [
      for (int y = currentYear; y >= earliest; y--) y,
    ];
  }

  Future<void> _loadAndFilter() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _filterFromMemory();
  }

  /// Single-pass filter: void status + date boundary in one loop.
  void _filterFromMemory() {
    final now = DateTime.now();
    final results = <PastOrderModel>[];
    double totalAmount = 0.0;

    // Pre-compute date boundaries
    final isCustom = widget.period == VoidOrderPeriod.Custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      switch (widget.period) {
        case VoidOrderPeriod.Today:
          startBound = DateTime(now.year, now.month, now.day);
          endBound = startBound.add(const Duration(days: 1));
          break;
        case VoidOrderPeriod.ThisWeek:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          startBound = DateTime(weekStart.year, weekStart.month, weekStart.day);
          endBound = startBound.add(const Duration(days: 7));
          break;
        case VoidOrderPeriod.Month:
          startBound = DateTime(_selectedMonthYear, _selectedMonth);
          endBound = DateTime(_selectedMonthYear, _selectedMonth + 1);
          break;
        case VoidOrderPeriod.Year:
          startBound = DateTime(_selectedYear);
          endBound = DateTime(_selectedYear + 1);
          break;
        case VoidOrderPeriod.Custom:
          break;
      }
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    final reasonCounts = <String, int>{};
    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status != 'VOID' && status != 'VOIDED' && status != 'CANCELLED') continue;
      if (order.orderAt == null) continue;
      if (cutoff != null && order.orderAt!.isBefore(cutoff)) continue;
      if (isCustom && !hasCustomRange) continue;

      if (order.orderAt!.isBefore(startBound) || !order.orderAt!.isBefore(endBound)) {
        continue;
      }

      results.add(order);
      totalAmount += order.totalPrice;

      final reason = (order.voidReason ?? '').trim();
      if (reason.isNotEmpty) {
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
      }
    }

    // Most frequently entered void reason (blank reasons ignored).
    String mostCommonReason = '—';
    if (reasonCounts.isNotEmpty) {
      mostCommonReason = reasonCounts.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
    }

    results.sort((a, b) =>
        (b.orderAt ?? DateTime(2000)).compareTo(a.orderAt ?? DateTime(2000)));

    setState(() {
      _voidOrders = results;
      _totalVoidCount = results.length;
      _totalVoidAmount = totalAmount;
      _averageVoidAmount = _totalVoidCount > 0 ? totalAmount / _totalVoidCount : 0.0;
      _mostCommonReason = mostCommonReason;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }


  Widget _buildContent(BuildContext context) {
    // Not ReportBody: each section carries its own horizontal padding already,
    // so only the desktop width cap is needed.
    return SingleChildScrollView(
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
        children: [
          // Date/Month/Year Selector
          if (widget.period == VoidOrderPeriod.Custom) _buildCustomDateSelector(context),
          if (widget.period == VoidOrderPeriod.Month) _buildMonthSelector(context),
          if (widget.period == VoidOrderPeriod.Year) _buildYearSelector(context),

          // Summary Cards
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
              vertical: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
            ),
            child: ReportSummaryRow(cards: [
              ReportSummaryCard(title: 'Total Voids', value: _totalVoidCount.toString(), icon: Icons.cancel_outlined, color: Colors.red),
              ReportSummaryCard(title: 'Total Amount', value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalVoidAmount)}', icon: Icons.attach_money, color: Colors.orange),
              ReportSummaryCard(title: 'Average', value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageVoidAmount)}', icon: Icons.analytics, color: AppColors.primary),
            ]),
          ),

          // Most common void reason — full width so the reason text has room.
          if (_voidOrders.isNotEmpty && _mostCommonReason != '—')
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
                0,
                AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
                AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
              ),
              child: ReportSummaryCard(
                title: 'Top Void Reason',
                value: _mostCommonReason,
                icon: Icons.report_problem_outlined,
                color: Colors.red,
              ),
            ),

          // Export Button
          if (_voidOrders.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
              ),
              child: ReportExportButton(onPressed: _exportReport),
            ),

          SizedBox(height: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0)),

          // Orders List or Empty State
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(50.0), child: ReportLoading())
          else if (_voidOrders.isEmpty)
            const ReportEmptyState(
              icon: Icons.cancel_outlined,
              title: 'No Void Orders Found',
              message: 'There are no void orders for the selected period',
            )
          else
            _buildOrdersTable(context),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
            ),
            child: ReportPagination(
              currentPage: _currentPage,
              rowsPerPage: _rowsPerPage,
              totalCount: _voidOrders.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              unit: 'void orders',
            ),
          ),

          SizedBox(height: AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0)),
        ],
        ),
      ),
    );
  }

  Widget _buildCustomDateSelector(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
        vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0),
      ),
      padding: EdgeInsets.all(
        AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date Range',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context, mobile: 15.0, desktop: 16.0),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  context,
                  label: 'From Date',
                  date: _startDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                ),
              ),
              SizedBox(width: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
              Expanded(
                child: _buildDateField(
                  context,
                  label: 'To Date',
                  date: _endDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_startDate != null && _endDate != null) ? _filterFromMemory : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue(context, mobile: 12.0, desktop: 14.0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Apply Filter',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 14.0, desktop: 15.0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(BuildContext context, {required String label, DateTime? date, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppResponsive.getValue(context, mobile: 6.0, desktop: 8.0)),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0),
              vertical: AppResponsive.getValue(context, mobile: 12.0, desktop: 14.0),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select Date',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                    color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                Icon(Icons.calendar_today, size: AppResponsive.getValue(context, mobile: 18.0, desktop: 20.0), color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
        vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0),
      ),
      padding: EdgeInsets.all(
        AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Month',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context, mobile: 15.0, desktop: 16.0),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppResponsive.getValue(context, mobile: 6.0, desktop: 8.0)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0),
                        vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          isExpanded: true,
                          items: List.generate(12, (index) {
                            final monthValue = index + 1;
                            final isFuture = _selectedMonthYear == currentYear && monthValue > currentMonth;
                            return DropdownMenuItem(
                              value: monthValue,
                              enabled: !isFuture,
                              child: Text(
                                _monthNames[index],
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                                  color: isFuture ? AppColors.textSecondary.withValues(alpha: 0.4) : AppColors.textPrimary,
                                ),
                              ),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMonth = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Year',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppResponsive.getValue(context, mobile: 6.0, desktop: 8.0)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0),
                        vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMonthYear,
                          isExpanded: true,
                          items: _years.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(
                                year.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMonthYear = value;
                                // Reset to current month if switching to current year and selected month is in future
                                if (value == currentYear && _selectedMonth > currentMonth) {
                                  _selectedMonth = currentMonth;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _filterFromMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue(context, mobile: 12.0, desktop: 14.0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Apply Filter',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 14.0, desktop: 15.0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
        vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0),
      ),
      padding: EdgeInsets.all(
        AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Year',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context, mobile: 15.0, desktop: 16.0),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0),
              vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                items: _years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(
                      year.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedYear = value);
                  }
                },
              ),
            ),
          ),
          SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, desktop: 16.0)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _filterFromMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue(context, mobile: 12.0, desktop: 14.0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Apply Filter',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 14.0, desktop: 15.0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOrdersTable(BuildContext context) {
    final pageOrders = ReportPagination.pageSlice(_voidOrders, _currentPage, _rowsPerPage);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
      ),
      child: ReportTable(
        showCheckboxColumn: false,
        columns: [
          ReportTable.column(context, 'Order ID'),
          ReportTable.column(context, 'Date'),
          ReportTable.column(context, 'Time'),
          ReportTable.column(context, 'Amount', numeric: true),
          ReportTable.column(context, 'Payment'),
          ReportTable.column(context, 'Refund Status'),
          ReportTable.column(context, 'Voided By'),
          ReportTable.column(context, 'Reason'),
        ],
        rows: pageOrders.map((order) {
                  // FIX 1 & 3: orderAt guarded; totalPrice used directly.
                  final orderDate = order.orderAt ?? DateTime.now();
                  final formattedDate = DateFormat('dd/MM/yyyy').format(orderDate);
                  final formattedTime = DateFormat('hh:mm a').format(orderDate);
                  final amount = order.totalPrice;

                  return DataRow(
                    onSelectChanged: (_) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Orderdetails(Order: order),
                        ),
                      );
                    },
                    cells: [
                      DataCell(
                        Text(
                          order.billNumber != null ? 'INV ${order.billNumber}' : '#${order.id.substring(0, 8)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formattedTime,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(amount)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Builder(builder: (context) {
                          final pm = order.paymentmode;
                          final isUnpaid = pm == null || pm == 'N/A';
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                              vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                            ),
                            decoration: BoxDecoration(
                              color: isUnpaid
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isUnpaid ? 'Unpaid' : pm!,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(context, mobile: 12.0, desktop: 13.0),
                                fontWeight: FontWeight.w500,
                                color: isUnpaid ? Colors.grey.shade600 : AppColors.primary,
                              ),
                            ),
                          );
                         }),
                       ),
                       DataCell(
                         Text(
                           _getRefundStatusText(order),
                           style: GoogleFonts.poppins(
                             fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                             fontWeight: FontWeight.w500,
                             color: _getRefundStatusColor(order),
                           ),
                         ),
                       ),
                      DataCell(
                        Text(
                          order.voidedBy ?? '—',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            order.voidReason ?? '—',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
        }).toList(),
      ),
    );
  }

  Future<void> _exportReport() async {
    if (_voidOrders.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    // Prepare headers
    final headers = [
      'Bill #',
      'Date & Time',
      'Customer',
      'Payment Method',
      'Amount',
      'Refund Status',
      'Voided By',
      'Reason',
    ];

    // Prepare data rows
    final data = _voidOrders.map((order) => [
      order.billNumber?.toString() ?? order.id.substring(0, 8),
      ReportExportService.formatDateTime(order.orderAt),
      order.customerName ?? 'Guest',
      order.paymentmode ?? 'N/A',
      ReportExportService.formatCurrency(order.totalPrice ?? 0.0),
      _getRefundStatusText(order),
      order.voidedBy ?? '—',
      order.voidReason ?? '—',
    ]).toList();

    // Prepare summary
    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Period': periodName,
      'Total Void Orders': _totalVoidCount.toString(),
      'Total Void Amount': ReportExportService.formatCurrency(_totalVoidAmount),
      'Average Void Amount': ReportExportService.formatCurrency(_averageVoidAmount),
      'Top Void Reason': _mostCommonReason,
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'void_orders_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Void Orders Report - $periodName',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    switch (widget.period) {
      case VoidOrderPeriod.Today:
        return 'Today';
      case VoidOrderPeriod.ThisWeek:
        return 'This Week';
      case VoidOrderPeriod.Month:
        // FIX 4: Use month name instead of raw integer.
        return '${_monthNames[_selectedMonth - 1]} $_selectedMonthYear';
      case VoidOrderPeriod.Year:
        return '$_selectedYear';
      case VoidOrderPeriod.Custom:
        if (_startDate != null && _endDate != null) {
          return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
        }
        return 'Custom Period';
    }
  }
}