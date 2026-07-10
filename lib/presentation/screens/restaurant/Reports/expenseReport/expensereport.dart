import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
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
import 'package:billberrylite/util/restaurant/report_history_window.dart';

class ExpenseReport extends StatefulWidget {
  const ExpenseReport({super.key});

  @override
  State<ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends State<ExpenseReport> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Expense Report',
        subtitle: 'Track your expenses',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          ReportPeriodFilterBar(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            featureNoun: 'expenses',
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: ExpenseDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseDataView extends StatefulWidget {
  final ReportPeriod period;
  const ExpenseDataView({super.key, required this.period});

  @override
  State<ExpenseDataView> createState() => _ExpenseDataViewState();
}

class _ExpenseDataViewState extends State<ExpenseDataView> {
  List<Expense> _filteredExpenses = [];
  double _totalExpenses = 0.0;
  int _totalCount = 0;
  double _averageExpense = 0.0;
  bool _isLoading = true;
  bool _isDataLoaded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, String> _categoryNames = {};

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant ExpenseDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _filterFromMemory();
    }
  }

  Future<void> _loadDataAndFilter() async {
    if (_isDataLoaded) {
      _filterFromMemory();
      return;
    }
    setState(() => _isLoading = true);
    await expenseCategoryStore.loadCategories();
    await expenseStore.loadExpenses();
    _isDataLoaded = true;
    _buildCategoryNames();
    _filterFromMemory();
  }

  void _buildCategoryNames() {
    final categoryMap = <String, String>{};
    for (var category in expenseCategoryStore.categories) {
      categoryMap[category.id] = category.name;
    }
    _categoryNames = categoryMap;
  }

  void _filterFromMemory() {
    final now = DateTime.now();
    final isCustom = widget.period == ReportPeriod.custom;
    final hasCustomRange = _startDate != null && _endDate != null;

    if (isCustom && hasCustomRange && _startDate!.isAfter(_endDate!)) {
      NotificationService.instance.showError('Start date must be before end date');
      setState(() => _isLoading = false);
      return;
    }

    // Pre-compute date boundaries
    late final DateTime startBound;
    late final DateTime endBound;

    if (isCustom) {
      if (!hasCustomRange) {
        setState(() {
          _filteredExpenses = [];
          _totalExpenses = 0.0;
          _totalCount = 0;
          _averageExpense = 0.0;
          _currentPage = 0;
          _isLoading = false;
        });
        return;
      }
      startBound = _startDate!;
      endBound = DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1);
    } else {
      // Same helper the filter's history lock uses — they cannot disagree.
      startBound = reportPeriodStartBound(widget.period, now);
      endBound = reportPeriodEndBound(widget.period, now);
    }

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    // Single-pass: filter + accumulate totals
    final results = <Expense>[];
    double totalAmount = 0.0;

    for (final expense in expenseStore.expenses) {
      if (cutoff != null && expense.dateandTime.isBefore(cutoff)) continue;
      if (expense.dateandTime.isBefore(startBound) || !expense.dateandTime.isBefore(endBound)) {
        continue;
      }
      results.add(expense);
      totalAmount += expense.amount;
    }

    results.sort((a, b) => b.dateandTime.compareTo(a.dateandTime));

    setState(() {
      _filteredExpenses = results;
      _totalCount = results.length;
      _totalExpenses = totalAmount;
      _averageExpense = _totalCount > 0 ? _totalExpenses / _totalCount : 0.0;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _exportReport() async {
    if (_filteredExpenses.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Date & Time',
      'Category',
      'Reason',
      'Payment Type',
      'Amount',
    ];

    final data = _filteredExpenses.map((expense) => [
      ReportExportService.formatDateTime(expense.dateandTime),
      _categoryNames[expense.categoryOfExpense] ?? expense.categoryOfExpense ?? 'Uncategorized',
      expense.reason ?? '-',
      expense.paymentType ?? '-',
      ReportExportService.formatCurrency(expense.amount),
    ]).toList();

    String periodDisplay = _getPeriodDisplayName();

    final summary = {
      'Report Period': periodDisplay,
      'Total Expenses Count': _totalCount.toString(),
      'Total Expenses Amount': ReportExportService.formatCurrency(_totalExpenses),
      'Average Expense': ReportExportService.formatCurrency(_averageExpense),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'expenses_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Expense Report - $periodDisplay',
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
              _loadDataAndFilter();
            },
          ),
          if (_startDate != null && _endDate != null) ...[
            AppResponsive.verticalSpace(context),
            if (_filteredExpenses.isNotEmpty)
              _buildReportContent()
            else
              const ReportEmptyState(
                icon: Icons.receipt_long,
                title: 'No Expenses',
                message: 'No expenses found for the selected date range',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportUI() {
    if (_filteredExpenses.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.receipt_long,
        title: 'No Expenses',
        message: 'No expenses found for this period',
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
          totalCount: _filteredExpenses.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
          unit: 'expenses',
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return ReportSummaryRow(cards: [
      ReportSummaryCard(
        title: 'Total Expenses',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalExpenses)}',
        icon: Icons.money_off,
        color: Colors.red,
      ),
      ReportSummaryCard(
        title: 'Total Count',
        value: _totalCount.toString(),
        icon: Icons.receipt_long,
        color: Colors.orange,
      ),
      ReportSummaryCard(
        title: 'Average',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageExpense)}',
        icon: Icons.analytics,
        color: AppColors.primary,
      ),
    ]);
  }

  Widget _buildDataTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Category'),
        ReportTable.column(context, 'Reason'),
        ReportTable.column(context, 'Payment'),
        ReportTable.column(context, 'Amount', numeric: true),
      ],
      rows: ReportPagination.pageSlice(_filteredExpenses, _currentPage, _rowsPerPage).map((expense) {
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
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _categoryNames[expense.categoryOfExpense] ?? expense.categoryOfExpense ?? 'Uncategorized',
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
    );
  }
}