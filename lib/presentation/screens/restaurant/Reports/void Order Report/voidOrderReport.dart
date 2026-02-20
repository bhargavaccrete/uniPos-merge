import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeYears();
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant VoidOrderDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDataAndFilter();

    // Reset custom dates when switching periods
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
    }
  }

  void _initializeYears() {
    final currentYear = DateTime.now().year;
    _years = List.generate(10, (index) => currentYear - index);
  }

  Future<void> _loadDataAndFilter() async {
    setState(() => _isLoading = true);

    try {
      await pastOrderStore.loadPastOrders();
      final allOrders = pastOrderStore.pastOrders
          .where((order) {
            final status = order.orderStatus?.toUpperCase() ?? '';
            return status == 'VOID' || status == 'VOIDED';
          })
          .toList();

      _filterOrdersByPeriod(allOrders);
    } catch (e) {
      debugPrint('Error loading void orders: $e');
      setState(() {
        _voidOrders = [];
        _calculateSummary();
        _isLoading = false;
      });
    }
  }

  void _filterOrdersByPeriod(List<PastOrderModel> orders) {
    final now = DateTime.now();
    List<PastOrderModel> filtered = [];

    switch (widget.period) {
      case VoidOrderPeriod.Today:
        final today = DateTime(now.year, now.month, now.day);
        filtered = orders.where((order) {
          final orderDate = order.orderAt!;
          final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);
          return orderDay == today;
        }).toList();
        break;

      case VoidOrderPeriod.ThisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        filtered = orders.where((order) {
          final orderDate = order.orderAt!;
          return orderDate.isAfter(startOfWeekDate.subtract(const Duration(days: 1)));
        }).toList();
        break;

      case VoidOrderPeriod.Month:
        filtered = orders.where((order) {
          final orderDate = order.orderAt!;
          return orderDate.year == _selectedMonthYear && orderDate.month == _selectedMonth;
        }).toList();
        break;

      case VoidOrderPeriod.Year:
        filtered = orders.where((order) {
          final orderDate = order.orderAt!;
          return orderDate.year == _selectedYear;
        }).toList();
        break;

      case VoidOrderPeriod.Custom:
        if (_startDate != null && _endDate != null) {
          final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

          filtered = orders.where((order) {
            final orderDate = order.orderAt!;
            return orderDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                   orderDate.isBefore(end.add(const Duration(seconds: 1)));
          }).toList();
        }
        break;
    }

    setState(() {
      _voidOrders = filtered;
      _calculateSummary();
      _isLoading = false;
    });
  }

  void _calculateSummary() {
    _totalVoidCount = _voidOrders.length;
    _totalVoidAmount = _voidOrders.fold(0.0, (sum, order) {
      final amount = double.tryParse(order.totalPrice.toString()) ?? 0.0;
      return sum + amount;
    });
    _averageVoidAmount = _totalVoidCount > 0 ? _totalVoidAmount / _totalVoidCount : 0.0;
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
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSummaryCard(context, 'Total Voids', _totalVoidCount.toString(), Icons.cancel_outlined, Colors.red)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildSummaryCard(context, 'Total Amount', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalVoidAmount)}', Icons.attach_money, Colors.orange)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildSummaryCard(context, 'Average', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageVoidAmount)}', Icons.analytics, AppColors.primary)),
                    ],
                  )
                : Column(
                    children: [
                      _buildSummaryCard(context, 'Total Voids', _totalVoidCount.toString(), Icons.cancel_outlined, Colors.red),
                      const SizedBox(height: 16),
                      _buildSummaryCard(context, 'Total Amount', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalVoidAmount)}', Icons.attach_money, Colors.orange),
                      const SizedBox(height: 16),
                      _buildSummaryCard(context, 'Average', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageVoidAmount)}', Icons.analytics, AppColors.primary),
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
              onPressed: (_startDate != null && _endDate != null) ? _loadDataAndFilter : null,
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
              onPressed: _loadDataAndFilter,
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
              onPressed: _loadDataAndFilter,
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

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color iconColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = AppResponsive.isDesktop(context);
    final isTablet = AppResponsive.isTablet(context);

    return Container(
      width: isDesktop ? (screenWidth - 88) / 3 : (screenWidth - 48),
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 16 : (isTablet ? 14 : 12),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : (isTablet ? 8 : 6)),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isDesktop ? 28 : (isTablet ? 22 : 16),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 32 : (isTablet ? 24 : 22),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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

  Widget _buildOrdersTable(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);
    final isTablet = AppResponsive.isTablet(context);

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
                rows: _voidOrders.map((order) {
                  final orderDate = order.orderAt!;
                  final formattedDate = DateFormat('dd/MM/yyyy').format(orderDate);
                  final formattedTime = DateFormat('hh:mm a').format(orderDate);
                  final amount = double.tryParse(order.totalPrice.toString()) ?? 0.0;

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
        return '$_selectedMonth $_selectedMonthYear';
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