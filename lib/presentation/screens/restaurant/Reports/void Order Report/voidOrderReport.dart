import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../tabbar/orderDetails.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';

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
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.fromLTRB(
              AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0),
              AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
              AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0),
              AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(
                        AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textSecondary,
                        size: AppResponsive.getValue(context, mobile: 18.0, desktop: 20.0),
                      ),
                    ),
                  ),
                  SizedBox(width: AppResponsive.getValue(context, mobile: 16.0, desktop: 20.0)),
                  // Title Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Void Order Report',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 22.0),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track and analyze void orders',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icon
                  Container(
                    padding: EdgeInsets.all(
                      AppResponsive.getValue(context, mobile: 10.0, desktop: 14.0),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppResponsive.getValue(context, mobile: 10.0, desktop: 12.0),
                      ),
                    ),
                    child: Icon(
                      Icons.cancel_outlined,
                      color: Colors.red,
                      size: AppResponsive.getValue(context, mobile: 24.0, desktop: 28.0),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Period Selection Buttons
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(
              AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodButton(
                    context,
                    'Today',
                    Icons.today,
                    VoidOrderPeriod.Today,
                  ),
                  SizedBox(width: AppResponsive.getValue(context, mobile: 8.0, tablet: 12.0)),
                  _buildPeriodButton(
                    context,
                    'This Week',
                    Icons.date_range,
                    VoidOrderPeriod.ThisWeek,
                  ),
                  SizedBox(width: AppResponsive.getValue(context, mobile: 8.0, tablet: 12.0)),
                  _buildPeriodButton(
                    context,
                    'Month',
                    Icons.calendar_month,
                    VoidOrderPeriod.Month,
                  ),
                  SizedBox(width: AppResponsive.getValue(context, mobile: 8.0, tablet: 12.0)),
                  _buildPeriodButton(
                    context,
                    'Year',
                    Icons.calendar_today,
                    VoidOrderPeriod.Year,
                  ),
                  SizedBox(width: AppResponsive.getValue(context, mobile: 8.0, tablet: 12.0)),
                  _buildPeriodButton(
                    context,
                    'Custom',
                    Icons.tune,
                    VoidOrderPeriod.Custom,
                  ),
                ],
              ),
            ),
          ),

          // Data View
          Expanded(
            child: VoidOrderDataView(period: _selectedPeriod),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidOrderPeriod period,
  ) {
    final isSelected = _selectedPeriod == period;

    return ElevatedButton.icon(
      icon: Icon(
        icon,
        size: AppResponsive.smallIconSize(context),
      ),
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
        elevation: isSelected ? 2 : 0,
        shadowColor: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppResponsive.getValue(context, mobile: 10.0, desktop: 12.0),
          ),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 0 : 1,
          ),
        ),
      ),
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
    );
  }
}

// ==================== SEPARATE DATA VIEW WIDGET ====================

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
  List<PastOrderModel> _voidOrders = [];
  double _totalVoidAmount = 0.0;
  int _totalVoidCount = 0;
  double _averageVoidAmount = 0.0;

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

  void _initializeYears() {
    final currentYear = DateTime.now().year;
    _years = List.generate(10, (index) => currentYear - index);
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

    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status != 'VOID' && status != 'VOIDED') continue;
      if (order.orderAt == null) continue;
      if (isCustom && !hasCustomRange) continue;

      if (order.orderAt!.isBefore(startBound) || !order.orderAt!.isBefore(endBound)) {
        continue;
      }

      results.add(order);
      totalAmount += order.totalPrice;
    }

    results.sort((a, b) =>
        (b.orderAt ?? DateTime(2000)).compareTo(a.orderAt ?? DateTime(2000)));

    setState(() {
      _voidOrders = results;
      _totalVoidCount = results.length;
      _totalVoidAmount = totalAmount;
      _averageVoidAmount = _totalVoidCount > 0 ? totalAmount / _totalVoidCount : 0.0;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }


  Widget _buildContent(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);
    final isTablet = AppResponsive.isTablet(context);

    return SingleChildScrollView(
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
            child: Row(
                    children: [
                      Expanded(child: ReportSummaryCard(title: 'Total Voids', value: _totalVoidCount.toString(), icon: Icons.cancel_outlined, color: Colors.red)),
                      AppResponsive.horizontalSpace(context),
                      Expanded(child: ReportSummaryCard(title: 'Total Amount', value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalVoidAmount)}', icon: Icons.attach_money, color: Colors.orange)),
                      AppResponsive.horizontalSpace(context),
                      Expanded(child: ReportSummaryCard(title: 'Average', value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageVoidAmount)}', icon: Icons.analytics, color: AppColors.primary)),
                    ],
                  ),
          ),

          // Export Button
          if (_voidOrders.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    Icons.download,
                    size: AppResponsive.getValue(context, mobile: 20.0, desktop: 22.0),
                  ),
                  label: Text(
                    'Export to CSV',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 15.0, desktop: 16.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 18 : (isTablet ? 16 : 14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _exportReport,
                ),
              ),
            ),

          SizedBox(height: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0)),

          // Orders List or Empty State
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(50.0),
              child: CircularProgressIndicator(),
            )
          else if (_voidOrders.isEmpty)
            _buildEmptyState(context)
          else
            _buildOrdersTable(context),

          if (_voidOrders.length > _rowsPerPage)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
              ),
              child: _buildPaginationControls(),
            ),

          SizedBox(height: AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0)),
        ],
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


  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          AppResponsive.getValue(context, mobile: 40.0, desktop: 60.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(
                AppResponsive.getValue(context, mobile: 24.0, desktop: 32.0),
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                size: AppResponsive.getValue(context, mobile: 60.0, desktop: 80.0),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppResponsive.getValue(context, mobile: 20.0, desktop: 24.0)),
            Text(
              'No Void Orders Found',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 18.0, desktop: 20.0),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0)),
            Text(
              'There are no void orders for the selected period',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 14.0, desktop: 15.0),
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_voidOrders.length / _rowsPerPage).ceil();
    final start = _currentPage * _rowsPerPage + 1;
    final end = ((_currentPage + 1) * _rowsPerPage).clamp(1, _voidOrders.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start–$end of ${_voidOrders.length} orders',
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

  Widget _buildOrdersTable(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);
    final isTablet = AppResponsive.isTablet(context);
    final pageOrders = _voidOrders.length <= _rowsPerPage
        ? _voidOrders
        : _voidOrders.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 24.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - (isDesktop ? 48 : (isTablet ? 48 : 32)),
              ),
              child: DataTable(
                columnSpacing: AppResponsive.tableColumnSpacing(context),
                headingRowHeight: AppResponsive.tableHeadingHeight(context),
                dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
                columns: [
                  DataColumn(
                    label: Text(
                      'Order ID',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Date',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Time',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Amount',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Payment',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, desktop: 14.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
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
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                            vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Void',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 12.0, desktop: 13.0),
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
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
      'Status'
    ];

    // Prepare data rows
    final data = _voidOrders.map((order) => [
      order.billNumber?.toString() ?? order.id.substring(0, 8),
      ReportExportService.formatDateTime(order.orderAt),
      order.customerName ?? 'Guest',
      order.paymentmode ?? 'N/A',
      ReportExportService.formatCurrency(order.totalPrice ?? 0.0),
      'Void',
    ]).toList();

    // Prepare summary
    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Period': periodName,
      'Total Void Orders': _totalVoidCount.toString(),
      'Total Void Amount': ReportExportService.formatCurrency(_totalVoidAmount),
      'Average Void Amount': ReportExportService.formatCurrency(_averageVoidAmount),
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