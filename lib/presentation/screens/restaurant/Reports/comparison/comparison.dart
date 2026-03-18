import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

enum ComparisonPeriod { Week, WeekYoY, Month, MonthYoY, Year }

enum TrendCategory { excellent, good, stable, declining }

class SalesComparison extends StatefulWidget {
  const SalesComparison({super.key});

  @override
  State<SalesComparison> createState() => _SalesComparisonState();
}

class _SalesComparisonState extends State<SalesComparison> {
  ComparisonPeriod _selectedPeriod = ComparisonPeriod.Month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              width: double.infinity,
              padding: AppResponsive.padding(context),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: AppResponsive.iconSize(context),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales Comparison',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.headingFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Compare sales performance over time',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.mediumSpacing(context),
                          vertical: AppResponsive.smallSpacing(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                        ),
                        child: Text(
                          'ADMIN',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  // Period Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ComparisonPeriod.values.map((period) {
                        final isSelected = _selectedPeriod == period;
                        return Padding(
                          padding: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
                          child: FilterChip(
                            selected: isSelected,
                            label: Center(
                              child: Text(
                                _getPeriodLabel(period),
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedPeriod = period;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ComparisonReportView(
                period: _selectedPeriod,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel(ComparisonPeriod period) {
    switch (period) {
      case ComparisonPeriod.Week:
        return 'This Week';
      case ComparisonPeriod.WeekYoY:
        return 'Week YoY';
      case ComparisonPeriod.Month:
        return 'This Month';
      case ComparisonPeriod.MonthYoY:
        return 'Month YoY';
      case ComparisonPeriod.Year:
        return 'This Year';
    }
  }
}

class ComparisonReportView extends StatefulWidget {
  final ComparisonPeriod period;

  const ComparisonReportView({super.key, required this.period});

  @override
  State<ComparisonReportView> createState() => _ComparisonReportViewState();
}

class _ComparisonReportViewState extends State<ComparisonReportView> {
  bool _isLoading = true;
  bool _isDataLoaded = false;
  ComparisonData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ComparisonReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _generateComparisonData();
    }
  }

  Future<void> _loadData() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _generateComparisonData();
  }

  TrendCategory _getTrendCategory(double growthPercentage) {
    if (growthPercentage >= 50) return TrendCategory.excellent;
    if (growthPercentage >= 20) return TrendCategory.good;
    if (growthPercentage >= -5) return TrendCategory.stable;
    return TrendCategory.declining;
  }

  String _getTrendArrow(double growthPercentage) {
    if (growthPercentage >= 50) return '↑↑';
    if (growthPercentage >= 20) return '↗';
    if (growthPercentage >= 5) return '↑';
    if (growthPercentage <= -50) return '↓↓';
    if (growthPercentage <= -20) return '↘';
    if (growthPercentage <= -5) return '↓';
    return '→';
  }

  String _getTrendLabel(TrendCategory category) {
    switch (category) {
      case TrendCategory.excellent:
        return 'Excellent';
      case TrendCategory.good:
        return 'Good';
      case TrendCategory.stable:
        return 'Stable';
      case TrendCategory.declining:
        return 'Declining';
    }
  }

  Color _getTrendColor(TrendCategory category) {
    switch (category) {
      case TrendCategory.excellent:
        return Colors.green[700]!;
      case TrendCategory.good:
        return Colors.green;
      case TrendCategory.stable:
        return Colors.orange;
      case TrendCategory.declining:
        return Colors.red;
    }
  }

  /// Single-pass comparison with half-open intervals [start, end) and consistent amount formula.
  void _generateComparisonData() {
    final now = DateTime.now();

    late final DateTime currentStart;
    late final DateTime previousStart;
    late final DateTime previousEnd; // half-open: previousEnd == currentStart for adjacent periods
    String currentLabel, previousLabel;

    switch (widget.period) {
      case ComparisonPeriod.Week:
        currentStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart;
        currentLabel = 'This Week';
        previousLabel = 'Last Week';
        break;

      case ComparisonPeriod.WeekYoY:
        currentStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final lastYearSameDate = DateTime(now.year - 1, now.month, now.day);
        previousStart = DateTime(lastYearSameDate.year, lastYearSameDate.month, lastYearSameDate.day)
            .subtract(Duration(days: lastYearSameDate.weekday - 1));
        previousEnd = previousStart.add(const Duration(days: 7));
        currentLabel = 'This Week';
        previousLabel = 'Same Week Last Year';
        break;

      case ComparisonPeriod.Month:
        currentStart = DateTime(now.year, now.month, 1);
        previousStart = DateTime(now.year, now.month - 1, 1);
        previousEnd = currentStart;
        currentLabel = DateFormat('MMMM yyyy').format(now);
        previousLabel = DateFormat('MMMM yyyy').format(previousStart);
        break;

      case ComparisonPeriod.MonthYoY:
        currentStart = DateTime(now.year, now.month, 1);
        previousStart = DateTime(now.year - 1, now.month, 1);
        previousEnd = DateTime(now.year - 1, now.month + 1, 1);
        currentLabel = DateFormat('MMMM yyyy').format(now);
        previousLabel = DateFormat('MMMM yyyy').format(previousStart);
        break;

      case ComparisonPeriod.Year:
        currentStart = DateTime(now.year, 1, 1);
        previousStart = DateTime(now.year - 1, 1, 1);
        previousEnd = currentStart;
        currentLabel = '${now.year}';
        previousLabel = '${now.year - 1}';
        break;
    }

    int currentOrders = 0;
    double currentAmount = 0.0;
    int previousOrders = 0;
    double previousAmount = 0.0;

    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus ?? '';
      if (status == 'VOID' || status == 'VOIDED' || status == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);

      // Current period [currentStart, now]
      if (!order.orderAt!.isBefore(currentStart)) {
        currentOrders++;
        currentAmount += netAmount;
      }
      // Previous period [previousStart, previousEnd)
      else if (!order.orderAt!.isBefore(previousStart) && order.orderAt!.isBefore(previousEnd)) {
        previousOrders++;
        previousAmount += netAmount;
      }
    }

    // Calculate growth
    double ordersGrowth = 0.0;
    if (previousOrders > 0) {
      ordersGrowth = ((currentOrders - previousOrders) / previousOrders) * 100;
    } else if (currentOrders > 0) {
      ordersGrowth = 100.0;
    }

    double amountGrowth = 0.0;
    if (previousAmount > 0) {
      amountGrowth = ((currentAmount - previousAmount) / previousAmount) * 100;
    } else if (currentAmount > 0) {
      amountGrowth = 100.0;
    }

    final currentAOV = currentOrders > 0 ? currentAmount / currentOrders : 0.0;
    final previousAOV = previousOrders > 0 ? previousAmount / previousOrders : 0.0;

    final currentDays = now.difference(currentStart).inDays + 1;
    final previousDays = previousEnd.difference(previousStart).inDays;

    final currentOrdersPerDay = currentDays > 0 ? currentOrders / currentDays : 0.0;
    final previousOrdersPerDay = previousDays > 0 ? previousOrders / previousDays : 0.0;

    setState(() {
      _data = ComparisonData(
        currentPeriod: currentLabel,
        previousPeriod: previousLabel,
        currentOrders: currentOrders,
        currentAmount: currentAmount,
        previousOrders: previousOrders,
        previousAmount: previousAmount,
        ordersGrowth: ordersGrowth,
        amountGrowth: amountGrowth,
        currentAOV: currentAOV,
        previousAOV: previousAOV,
        currentOrdersPerDay: currentOrdersPerDay,
        previousOrdersPerDay: previousOrdersPerDay,
        trendCategory: _getTrendCategory(amountGrowth),
        trendArrow: _getTrendArrow(amountGrowth),
      );
      _isLoading = false;
    });
  }

  Future<void> _exportReport() async {
    if (_data == null) return;
    final data = _data!;

    final headers = ['Metric', data.previousPeriod, data.currentPeriod, 'Growth %'];

    final dataRows = [
      [
        'Total Orders',
        data.previousOrders.toString(),
        data.currentOrders.toString(),
        '${data.ordersGrowth >= 0 ? '+' : ''}${data.ordersGrowth.toStringAsFixed(1)}%'
      ],
      [
        'Total Amount',
        ReportExportService.formatCurrency(data.previousAmount),
        ReportExportService.formatCurrency(data.currentAmount),
        '${data.amountGrowth >= 0 ? '+' : ''}${data.amountGrowth.toStringAsFixed(1)}%'
      ],
      [
        'Average Order Value',
        ReportExportService.formatCurrency(data.previousAOV),
        ReportExportService.formatCurrency(data.currentAOV),
        '-'
      ],
      [
        'Orders Per Day',
        data.previousOrdersPerDay.toStringAsFixed(1),
        data.currentOrdersPerDay.toStringAsFixed(1),
        '-'
      ],
    ];

    final summary = {
      'Comparison Period': '${data.previousPeriod} vs ${data.currentPeriod}',
      'Performance Status': _getTrendLabel(data.trendCategory),
      'Revenue Growth': '${data.amountGrowth >= 0 ? '+' : ''}${data.amountGrowth.toStringAsFixed(1)}%',
      'Order Growth': '${data.ordersGrowth >= 0 ? '+' : ''}${data.ordersGrowth.toStringAsFixed(1)}%',
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'sales_comparison_${data.currentPeriod.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Sales Comparison Report - ${data.previousPeriod} vs ${data.currentPeriod}',
      headers: headers,
      data: dataRows,
      summary: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _data == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Builder(
      builder: (_) {
        final data = _data!;
        final trendColor = _getTrendColor(data.trendCategory);
        final trendLabel = _getTrendLabel(data.trendCategory);

        return SingleChildScrollView(
          child: Padding(
            padding: AppResponsive.padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Info Card
                Container(
                  width: double.infinity,
                  padding: AppResponsive.cardPadding(context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              data.previousPeriod,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppResponsive.smallSpacing(context)),
                        child: Text(
                          'vs',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              data.currentPeriod,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Summary Cards - Row 1
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'Total Orders',
                        data.currentOrders.toString(),
                        data.previousOrders.toString(),
                        data.ordersGrowth,
                        Icons.shopping_cart_outlined,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'Total Revenue',
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.currentAmount)}',
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.previousAmount)}',
                        data.amountGrowth,
                        Icons.monetization_on_outlined,
                        Colors.green,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppResponsive.smallSpacing(context)),

                // Summary Cards - Row 2
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'Avg Order Value',
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.currentAOV)}',
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.previousAOV)}',
                        null,
                        Icons.attach_money,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'Orders Per Day',
                        data.currentOrdersPerDay.toStringAsFixed(1),
                        data.previousOrdersPerDay.toStringAsFixed(1),
                        null,
                        Icons.calendar_today,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppResponsive.smallSpacing(context)),

                // Performance Badge Card
                Container(
                  width: double.infinity,
                  padding: AppResponsive.cardPadding(context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                        ),
                        child: Icon(
                          data.trendCategory == TrendCategory.excellent || data.trendCategory == TrendCategory.good
                              ? Icons.trending_up
                              : data.trendCategory == TrendCategory.declining
                                  ? Icons.trending_down
                                  : Icons.trending_flat,
                          color: trendColor,
                          size: AppResponsive.largeIconSize(context),
                        ),
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Status',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            trendLabel,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(context),
                              fontWeight: FontWeight.w700,
                              color: trendColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Export Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exportReport,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(
                      'Export to Excel',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.buttonFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: AppResponsive.mediumSpacing(context),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Detailed Comparison Table
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: AppResponsive.cardPadding(context),
                        child: Text(
                          'Detailed Comparison',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: AppResponsive.tableColumnSpacing(context),
                          headingRowHeight: AppResponsive.tableHeadingHeight(context),
                          dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                          dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
                          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                          columns: [
                            DataColumn(
                              label: Text(
                                'Metric',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                data.previousPeriod,
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                data.currentPeriod,
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Growth',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          rows: [
                            _buildDataRow(
                              context,
                              'Total Orders',
                              data.previousOrders.toString(),
                              data.currentOrders.toString(),
                              data.ordersGrowth,
                            ),
                            _buildDataRow(
                              context,
                              'Total Amount',
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.previousAmount)}',
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.currentAmount)}',
                              data.amountGrowth,
                            ),
                            _buildDataRow(
                              context,
                              'Avg Order Value',
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.previousAOV)}',
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(data.currentAOV)}',
                              null,
                            ),
                            _buildDataRow(
                              context,
                              'Orders Per Day',
                              data.previousOrdersPerDay.toStringAsFixed(1),
                              data.currentOrdersPerDay.toStringAsFixed(1),
                              null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String currentValue,
    String previousValue,
    double? growthPercentage,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppResponsive.smallSpacing(context) / 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: AppResponsive.iconSize(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            currentValue,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                'was $previousValue',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: Colors.grey[500],
                ),
              ),
              if (growthPercentage != null) ...[
                SizedBox(width: 4),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: growthPercentage >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_getTrendArrow(growthPercentage)} ${growthPercentage >= 0 ? '+' : ''}${growthPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: growthPercentage >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    String metric,
    String previousValue,
    String currentValue,
    double? growthPercentage,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            metric,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            previousValue,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
            ),
          ),
        ),
        DataCell(
          Text(
            currentValue,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        DataCell(
          growthPercentage != null
              ? Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.smallSpacing(context),
                    vertical: AppResponsive.smallSpacing(context) / 2,
                  ),
                  decoration: BoxDecoration(
                    color: growthPercentage >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_getTrendArrow(growthPercentage)} ${growthPercentage >= 0 ? '+' : ''}${growthPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: growthPercentage >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                )
              : Text(
                  '-',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: Colors.grey,
                  ),
                ),
        ),
      ],
    );
  }
}

class ComparisonData {
  final String currentPeriod;
  final String previousPeriod;
  final int currentOrders;
  final double currentAmount;
  final int previousOrders;
  final double previousAmount;
  final double ordersGrowth;
  final double amountGrowth;
  final double currentAOV;
  final double previousAOV;
  final double currentOrdersPerDay;
  final double previousOrdersPerDay;
  final TrendCategory trendCategory;
  final String trendArrow;

  ComparisonData({
    required this.currentPeriod,
    required this.previousPeriod,
    required this.currentOrders,
    required this.currentAmount,
    required this.previousOrders,
    required this.previousAmount,
    required this.ordersGrowth,
    required this.amountGrowth,
    required this.currentAOV,
    required this.previousAOV,
    required this.currentOrdersPerDay,
    required this.previousOrdersPerDay,
    required this.trendCategory,
    required this.trendArrow,
  });
}