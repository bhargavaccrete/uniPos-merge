import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';

enum TimePeriod { Today, ThisWeek, Month, Year, Custom }

class ExpenseReport extends StatefulWidget {
  const ExpenseReport({super.key});

  @override
  State<ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends State<ExpenseReport> {
  TimePeriod _selectedPeriod = TimePeriod.Today;

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
                          'Expense Report',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Track your expenses',
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
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      size: AppResponsive.iconSize(context),
                      color: Colors.red,
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
                  _filterButton(TimePeriod.Today, 'Today', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(TimePeriod.ThisWeek, 'This Week', Icons.view_week),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(TimePeriod.Month, 'This Month', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(TimePeriod.Year, 'This Year', Icons.calendar_today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(TimePeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: ExpenseDataView(
              key: ValueKey(_selectedPeriod),
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(TimePeriod period, String title, IconData icon) {
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

class ExpenseDataView extends StatefulWidget {
  final TimePeriod period;
  const ExpenseDataView({super.key, required this.period});

  @override
  State<ExpenseDataView> createState() => _ExpenseDataViewState();
}

class _ExpenseDataViewState extends State<ExpenseDataView> {
  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  double _totalExpenses = 0.0;
  int _totalCount = 0;
  double _averageExpense = 0.0;
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant ExpenseDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDataAndFilter();

    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
    }
  }

  Future<void> _loadDataAndFilter() async {
    await expenseCategoryStore.loadCategories();
    await expenseStore.loadExpenses();
    _allExpenses = expenseStore.expenses.toList();
    _fetchAndFilterData();
  }

  Map<String, String> _getCategoryNames() {
    final categoryMap = <String, String>{};
    for (var category in expenseCategoryStore.categories) {
      categoryMap[category.id] = category.name;
    }
    return categoryMap;
  }

  void _fetchAndFilterData() {
    setState(() {
      _isLoading = true;
    });

    List<Expense> resultingList = [];
    final now = DateTime.now();

    if (widget.period == TimePeriod.Custom) {
      if (_startDate != null && _endDate != null) {
        resultingList = _allExpenses.where((expense) {
          return expense.dateandTime.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
              expense.dateandTime.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      }
    } else {
      switch (widget.period) {
        case TimePeriod.Today:
          resultingList = _allExpenses.where((expense) {
            return expense.dateandTime.year == now.year &&
                expense.dateandTime.month == now.month &&
                expense.dateandTime.day == now.day;
          }).toList();
          break;
        case TimePeriod.ThisWeek:
          final dayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek = DateTime(dayOfWeek.year, dayOfWeek.month, dayOfWeek.day);
          final endOfWeek = startOfWeek.add(const Duration(days: 7));

          resultingList = _allExpenses.where((expense) {
            return !expense.dateandTime.isBefore(startOfWeek) && expense.dateandTime.isBefore(endOfWeek);
          }).toList();
          break;
        case TimePeriod.Month:
          resultingList = _allExpenses.where((expense) {
            return expense.dateandTime.year == now.year && expense.dateandTime.month == now.month;
          }).toList();
          break;
        case TimePeriod.Year:
          resultingList = _allExpenses.where((expense) {
            return expense.dateandTime.year == now.year;
          }).toList();
          break;
        case TimePeriod.Custom:
          break;
      }
    }

    setState(() {
      _filteredExpenses = resultingList;
      _totalCount = _filteredExpenses.length;
      _totalExpenses = _filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
      _averageExpense = _totalCount > 0 ? _totalExpenses / _totalCount : 0.0;
      _isLoading = false;
    });
  }

  Future<void> _exportToExcel() async {
    if (_filteredExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final categoryNames = _getCategoryNames();

    List<String> headers = [
      'Date',
      'Category',
      'Reason',
      'Amount',
      'Payment Type',
    ];

    List<List<dynamic>> rows = [headers];

    for (var expense in _filteredExpenses) {
      rows.add([
        DateFormat('dd-MM-yyyy HH:mm').format(expense.dateandTime),
        categoryNames[expense.categoryOfExpense] ?? expense.categoryOfExpense ?? 'Uncategorized',
        expense.reason ?? '-',
        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(expense.amount)}',
        expense.paymentType ?? '-',
      ]);
    }

    rows.add([]);
    rows.add(['Summary', '', '', '', '']);
    rows.add(['Total Expenses', _totalCount.toString(), '', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalExpenses)}', '']);
    rows.add(['Average Expense', '', '', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageExpense)}', '']);

    String csv = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getTemporaryDirectory();
      final periodName = widget.period.name;
      final path = '${directory.path}/expenses_${periodName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], text: "Expense Report - $periodName");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

    if (widget.period == TimePeriod.Custom) {
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
                        onPressed: (_startDate != null && _endDate != null) ? _fetchAndFilterData : null,
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
              if (_filteredExpenses.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildReportContent(isTablet),
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
    if (_filteredExpenses.isEmpty) {
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
                Icons.receipt_long,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Expenses',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No expenses found for this period',
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
      ],
    );
  }

  Widget _buildSummaryCards(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return Row(
      children: [
        Expanded(
          flex: isDesktop ? 1 : 1,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Expenses',
                      style: GoogleFonts.poppins(fontSize: isDesktop ? 16 : (isTablet ? 14 : 13), fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.money_off, color: Colors.red, size: isDesktop ? 28 : (isTablet ? 22 : 20)),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalExpenses)}',
                  style: GoogleFonts.poppins(fontSize: isDesktop ? 32 : (isTablet ? 24 : 22), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          flex: isDesktop ? 1 : 1,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Count',
                      style: GoogleFonts.poppins(fontSize: isDesktop ? 16 : (isTablet ? 14 : 13), fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long, color: Colors.orange, size: isDesktop ? 28 : (isTablet ? 22 : 20)),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  _totalCount.toString(),
                  style: GoogleFonts.poppins(fontSize: isDesktop ? 32 : (isTablet ? 24 : 22), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          flex: isDesktop ? 1 : 1,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Average',
                      style: GoogleFonts.poppins(fontSize: isDesktop ? 16 : (isTablet ? 14 : 13), fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.analytics, color: AppColors.primary, size: isDesktop ? 28 : (isTablet ? 22 : 20)),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageExpense)}',
                  style: GoogleFonts.poppins(fontSize: isDesktop ? 32 : (isTablet ? 24 : 22), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
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
        onPressed: _exportToExcel,
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
    final screenWidth = AppResponsive.screenWidth(context);
    final cellFontSize = AppResponsive.smallFontSize(context);
    final headerFontSize = AppResponsive.bodyFontSize(context);
    final categoryNames = _getCategoryNames();

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
                DataColumn(label: Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Reason', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
              ],
              rows: _filteredExpenses.map((expense) {
                return DataRow(
                  cells: [
                    DataCell(Text(DateFormat('dd-MM-yy\nHH:mm').format(expense.dateandTime), style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryNames[expense.categoryOfExpense] ?? expense.categoryOfExpense ?? 'Uncategorized',
                          style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: AppColors.primary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    DataCell(Text(expense.reason ?? '-', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(expense.paymentType ?? '-', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: Colors.blue, fontWeight: FontWeight.w500)),
                      ),
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
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(expense.amount)}',
                          style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: Colors.red, fontWeight: FontWeight.w700),
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