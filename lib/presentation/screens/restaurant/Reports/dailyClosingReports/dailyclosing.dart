import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';

enum ClosingPeriod { DayWise, MonthWise, Custom }

class DailyClosingReport extends StatefulWidget {
  const DailyClosingReport({super.key});

  @override
  State<DailyClosingReport> createState() => _DailyClosingReportState();
}

class _DailyClosingReportState extends State<DailyClosingReport> {
  ClosingPeriod _selectedPeriod = ClosingPeriod.DayWise;

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
                          'Daily Closing Report',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'End of day financial summary',
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
                      color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
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
                  _filterButton(ClosingPeriod.DayWise, 'Day Wise', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(ClosingPeriod.MonthWise, 'Month Wise', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(ClosingPeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: ClosingReportView(
              key: ValueKey(_selectedPeriod),
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(ClosingPeriod period, String title, IconData icon) {
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

class ClosingReportView extends StatefulWidget {
  final ClosingPeriod period;
  const ClosingReportView({super.key, required this.period});

  @override
  State<ClosingReportView> createState() => _ClosingReportViewState();
}

class _ClosingReportViewState extends State<ClosingReportView> {
  bool _isLoading = true;
  DateTime? _selectedDate;
  String? _selectedMonth;
  int? _selectedYear;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Aggregated data
  Map<String, double> _orderTypeTotals = {};
  Map<String, int> _orderTypeCounts = {};
  Map<String, double> _paymentTypeTotals = {};
  double _totalSales = 0.0;
  double _totalExpenses = 0.0;
  double _totalOpeningBalance = 0.0;
  double _totalClosingBalance = 0.0;
  int _reportCount = 0;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _initializeYears();
    _initializeDefaults();
    _loadDataAndFilter();
  }

  void _initializeYears() {
    // Generate years dynamically: current year, down to 10 years ago
    final currentYear = DateTime.now().year;
    _years = List.generate(11, (index) => currentYear - index);
  }

  void _initializeDefaults() {
    final now = DateTime.now();
    _selectedDate = now;
    _selectedMonth = _months[now.month - 1];
    _selectedYear = now.year;
  }

  // Check if a month is valid (not in the future)
  bool _isMonthValid(String month, int year) {
    final now = DateTime.now();
    final monthIndex = _months.indexOf(month) + 1;

    if (year > now.year) return false;
    if (year < now.year) return true;

    // Same year: check if month is not in future
    return monthIndex <= now.month;
  }

  @override
  void didUpdateWidget(covariant ClosingReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _loadDataAndFilter();
    }
  }

  Future<void> _loadDataAndFilter() async {
    setState(() => _isLoading = true);
    await eodStore.loadEODReports();
    _generateReport();
  }

  void _generateReport() {
    final reports = _getFilteredReports();
    _aggregateReports(reports);
    setState(() => _isLoading = false);
  }

  List<EndOfDayReport> _getFilteredReports() {
    switch (widget.period) {
      case ClosingPeriod.DayWise:
        return _getDayReports();
      case ClosingPeriod.MonthWise:
        return _getMonthReports();
      case ClosingPeriod.Custom:
        return _getCustomReports();
    }
  }

  List<EndOfDayReport> _getDayReports() {
    if (_selectedDate == null) return [];
    return eodStore.eodReports.where((report) {
      return report.date.year == _selectedDate!.year &&
          report.date.month == _selectedDate!.month &&
          report.date.day == _selectedDate!.day;
    }).toList();
  }

  List<EndOfDayReport> _getMonthReports() {
    if (_selectedMonth == null || _selectedYear == null) return [];
    final monthIndex = _months.indexOf(_selectedMonth!) + 1;
    return eodStore.eodReports.where((report) {
      return report.date.year == _selectedYear! &&
          report.date.month == monthIndex;
    }).toList();
  }

  List<EndOfDayReport> _getCustomReports() {
    if (_fromDate == null || _toDate == null) return [];
    return eodStore.eodReports.where((report) {
      final reportDate = DateTime(report.date.year, report.date.month, report.date.day);
      final fromDate = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final toDate = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
      return (reportDate.isAfter(fromDate) || reportDate.isAtSameMomentAs(fromDate)) &&
          (reportDate.isBefore(toDate) || reportDate.isAtSameMomentAs(toDate));
    }).toList();
  }

  void _aggregateReports(List<EndOfDayReport> reports) {
    _orderTypeTotals.clear();
    _orderTypeCounts.clear();
    _paymentTypeTotals.clear();
    _totalSales = 0.0;
    _totalExpenses = 0.0;
    _totalOpeningBalance = 0.0;
    _totalClosingBalance = 0.0;
    _reportCount = reports.length;

    for (final report in reports) {
      // Aggregate order types
      for (final order in report.orderSummaries) {
        _orderTypeTotals[order.orderType] =
            (_orderTypeTotals[order.orderType] ?? 0.0) + order.totalAmount;
        _orderTypeCounts[order.orderType] =
            (_orderTypeCounts[order.orderType] ?? 0) + order.orderCount;
      }

      // Aggregate payment types
      for (final payment in report.paymentSummaries) {
        _paymentTypeTotals[payment.paymentType] =
            (_paymentTypeTotals[payment.paymentType] ?? 0.0) + payment.totalAmount;
      }

      _totalSales += report.totalSales;
      _totalExpenses += report.totalExpenses;
      _totalOpeningBalance += report.openingBalance;
      _totalClosingBalance += report.closingBalance;
    }
  }

  Future<void> _exportReport() async {
    if (_reportCount == 0) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    // Prepare main data rows
    final dataRows = <List<dynamic>>[];

    // Add financial summary
    dataRows.add(['Total Sales', ReportExportService.formatCurrency(_totalSales)]);
    dataRows.add(['Total Expenses', ReportExportService.formatCurrency(_totalExpenses)]);
    dataRows.add(['Net Amount', ReportExportService.formatCurrency(_totalSales - _totalExpenses)]);
    dataRows.add(['', '']); // Empty row separator

    // Add order breakdown
    for (var entry in _orderTypeTotals.entries) {
      dataRows.add([
        '${entry.key} Orders (${_orderTypeCounts[entry.key]} count)',
        ReportExportService.formatCurrency(entry.value)
      ]);
    }
    dataRows.add(['', '']); // Empty row separator

    // Add payment breakdown
    for (var entry in _paymentTypeTotals.entries) {
      dataRows.add([
        '$entry.key} Payments',
        ReportExportService.formatCurrency(entry.value)
      ]);
    }

    // Prepare summary
    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Type': 'Daily Closing Report',
      'Period': periodName,
      'Days Covered': _reportCount.toString(),
      'Total Sales': ReportExportService.formatCurrency(_totalSales),
      'Total Expenses': ReportExportService.formatCurrency(_totalExpenses),
      'Net Amount': ReportExportService.formatCurrency(_totalSales - _totalExpenses),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'daily_closing_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Daily Closing Report - $periodName',
      headers: ['Description', 'Amount'],
      data: dataRows,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    switch (widget.period) {
      case ClosingPeriod.DayWise:
        if (_selectedDate != null) {
          return DateFormat('dd MMM yyyy').format(_selectedDate!);
        }
        return 'Day Wise';
      case ClosingPeriod.MonthWise:
        if (_selectedMonth != null && _selectedYear != null) {
          return '$_selectedMonth $_selectedYear';
        }
        return 'Month Wise';
      case ClosingPeriod.Custom:
        if (_fromDate != null && _toDate != null) {
          return '${DateFormat('dd MMM yyyy').format(_fromDate!)} - ${DateFormat('dd MMM yyyy').format(_toDate!)}';
        }
        return 'Custom Period';
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now, // Cannot select future dates
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
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _generateReport();
    }
  }

  Future<void> _pickFromDate(BuildContext context) async {
    final now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now, // Cannot select future dates
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
    );

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = null;
        }
      });
    }
  }

  Future<void> _pickToDate(BuildContext context) async {
    final now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? now,
      firstDate: _fromDate ?? DateTime(2000),
      lastDate: now, // Cannot select future dates
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
    );

    if (pickedDate != null) {
      setState(() {
        _toDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (_isLoading || eodStore.isLoading) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (widget.period == ClosingPeriod.MonthWise) {
          return _buildMonthWiseSelector();
        }

        if (widget.period == ClosingPeriod.Custom) {
          return _buildCustomSelector();
        }

        return _buildDayWiseView();
      },
    );
  }

  Widget _buildDayWiseView() {
    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(),
            AppResponsive.verticalSpace(context),
            if (_reportCount > 0) ...[
              _buildSummaryCards(),
              AppResponsive.verticalSpace(context),
              _buildExportButton(),
              AppResponsive.verticalSpace(context),
              _buildOrderTable(),
              AppResponsive.verticalSpace(context),
              _buildPaymentTable(),
              AppResponsive.verticalSpace(context),
              _buildFinancialSummary(),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthWiseSelector() {
    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Month',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      AppResponsive.verticalSpace(context, size: SpacingSize.small),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMonth,
                            isExpanded: true,
                            items: _months.map((String month) {
                              final isValid = _isMonthValid(month, _selectedYear!);
                              return DropdownMenuItem(
                                value: month,
                                enabled: isValid,
                                child: Text(
                                  month,
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(context),
                                    color: isValid ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null && _isMonthValid(newValue, _selectedYear!)) {
                                setState(() {
                                  _selectedMonth = newValue;
                                });
                                _generateReport();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppResponsive.horizontalSpace(context),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Year',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      AppResponsive.verticalSpace(context, size: SpacingSize.small),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            isExpanded: true,
                            items: _years.map((int year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(context),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedYear = newValue;
                                  // Auto-adjust month if current selection becomes invalid
                                  if (!_isMonthValid(_selectedMonth!, newValue)) {
                                    final now = DateTime.now();
                                    if (newValue == now.year) {
                                      // Set to current month for current year
                                      _selectedMonth = _months[now.month - 1];
                                    } else {
                                      // Set to December for past years
                                      _selectedMonth = 'December';
                                    }
                                  }
                                });
                                _generateReport();
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
            AppResponsive.verticalSpace(context),
            if (_reportCount > 0) ...[
              _buildSummaryCards(),
              AppResponsive.verticalSpace(context),
              _buildExportButton(),
              AppResponsive.verticalSpace(context),
              _buildOrderTable(),
              AppResponsive.verticalSpace(context),
              _buildPaymentTable(),
              AppResponsive.verticalSpace(context),
              _buildFinancialSummary(),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSelector() {
    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: AppResponsive.cardPadding(context),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  AppResponsive.verticalSpace(context),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerButton(
                          'From Date',
                          _fromDate,
                          () => _pickFromDate(context),
                        ),
                      ),
                      AppResponsive.horizontalSpace(context),
                      Expanded(
                        child: _buildDatePickerButton(
                          'To Date',
                          _toDate,
                          () => _pickToDate(context),
                        ),
                      ),
                    ],
                  ),
                  AppResponsive.verticalSpace(context),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_fromDate != null && _toDate != null) ? _generateReport : null,
                      icon: Icon(Icons.filter_list, size: AppResponsive.smallIconSize(context)),
                      label: Text(
                        'Apply Filter',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.buttonFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: AppColors.divider,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_reportCount > 0) ...[
              AppResponsive.verticalSpace(context),
              _buildSummaryCards(),
              AppResponsive.verticalSpace(context),
              _buildExportButton(),
              AppResponsive.verticalSpace(context),
              _buildOrderTable(),
              AppResponsive.verticalSpace(context),
              _buildPaymentTable(),
              AppResponsive.verticalSpace(context),
              _buildFinancialSummary(),
            ] else if (_fromDate != null && _toDate != null) ...[
              AppResponsive.verticalSpace(context),
              _buildEmptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.small),
        InkWell(
          onTap: () => _pickDate(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0)),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'DD/MM/YYYY'
                        : DateFormat('dd MMM yyyy').format(_selectedDate!),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: _selectedDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerButton(String label, DateTime? date, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.small),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0)),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(date),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: date == null ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final netAmount = _totalSales - _totalExpenses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_reportCount > 1)
          Padding(
            padding: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
            child: Text(
              'Showing $_reportCount day${_reportCount > 1 ? 's' : ''} of data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Sales',
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalSales)}',
                Icons.trending_up,
                Colors.green,
              ),
            ),
            AppResponsive.horizontalSpace(context),
            Expanded(
              child: _buildSummaryCard(
                'Total Expenses',
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalExpenses)}',
                Icons.trending_down,
                Colors.red,
              ),
            ),
            AppResponsive.horizontalSpace(context),
            Expanded(
              child: _buildSummaryCard(
                'Net Amount',
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(netAmount)}',
                Icons.account_balance_wallet,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: AppResponsive.cardPadding(context),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 6.0, desktop: 8.0)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1 * color.a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: AppResponsive.smallIconSize(context),
                ),
              ),
            ],
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 18.0, desktop: 22.0),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportReport,
        icon: Icon(Icons.file_download_outlined, size: AppResponsive.iconSize(context)),
        label: Text(
          'Export Report',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.buttonFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTable() {
    if (_orderTypeTotals.isEmpty) return SizedBox.shrink();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.cardPadding(context),
            child: Text(
              'Order Summary',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: AppResponsive.screenWidth(context) - AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0),
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
                      'Order Type',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Count',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Amount',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    numeric: true,
                  ),
                ],
                rows: _orderTypeTotals.entries.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
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
                            color: Colors.blue.withValues(alpha: 0.1 * Colors.blue.a),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_orderTypeCounts[entry.key] ?? 0}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(entry.value)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTable() {
    if (_paymentTypeTotals.isEmpty) return SizedBox.shrink();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.cardPadding(context),
            child: Text(
              'Payment Summary',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: AppResponsive.screenWidth(context) - AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0),
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
                      'Payment Type',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Amount',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    numeric: true,
                  ),
                ],
                rows: _paymentTypeTotals.entries.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(entry.value)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          AppResponsive.verticalSpace(context),
          _buildFinancialRow('Total Sales:', _totalSales, Colors.green.shade700),
          SizedBox(height: 8),
          _buildFinancialRow('Total Expenses:', _totalExpenses, Colors.red.shade700, isNegative: true),
          Divider(thickness: 1, height: 20),
          _buildFinancialRow('Net Amount:', _totalSales - _totalExpenses, Colors.blue.shade800, isBold: true),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, double amount, Color color, {bool isNegative = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isBold ? AppResponsive.bodyFontSize(context) : AppResponsive.smallFontSize(context),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          '${isNegative ? '- ' : ''}${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(amount)}',
          style: GoogleFonts.poppins(
            fontSize: isBold ? AppResponsive.bodyFontSize(context) : AppResponsive.smallFontSize(context),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(
          AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0, desktop: 48.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: AppResponsive.getValue(context, mobile: 64.0, tablet: 80.0, desktop: 96.0),
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            AppResponsive.verticalSpace(context),
            Text(
              'No Report Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No closing report found for selected period',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}