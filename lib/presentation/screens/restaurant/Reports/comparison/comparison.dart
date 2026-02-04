import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
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
  void initState() {
    super.initState();
    pastOrderStore.loadPastOrders();
  }

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
                    color: Colors.black.withOpacity(0.05),
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
                            color: AppColors.primary.withOpacity(0.1),
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
                key: ValueKey(_selectedPeriod),
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
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await pastOrderStore.loadPastOrders();
    if (mounted) setState(() {});
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

  ComparisonData _calculateComparisonData() {
    final allOrders = pastOrderStore.pastOrders.toList();
    final now = DateTime.now();

    DateTime currentStart, currentEnd, previousStart, previousEnd;
    String currentLabel, previousLabel;

    switch (widget.period) {
      case ComparisonPeriod.Week:
        final weekDay = now.weekday;
        currentStart = now.subtract(Duration(days: weekDay - 1));
        currentStart = DateTime(currentStart.year, currentStart.month, currentStart.day);
        currentEnd = DateTime.now();
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart.subtract(const Duration(seconds: 1));
        currentLabel = 'This Week';
        previousLabel = 'Last Week';
        break;

      case ComparisonPeriod.WeekYoY:
        final weekDay = now.weekday;
        currentStart = now.subtract(Duration(days: weekDay - 1));
        currentStart = DateTime(currentStart.year, currentStart.month, currentStart.day);
        currentEnd = DateTime.now();

        final lastYearSameDate = DateTime(now.year - 1, now.month, now.day);
        final lastYearWeekDay = lastYearSameDate.weekday;
        previousStart = lastYearSameDate.subtract(Duration(days: lastYearWeekDay - 1));
        previousStart = DateTime(previousStart.year, previousStart.month, previousStart.day);
        previousEnd = previousStart.add(Duration(days: DateTime.now().difference(currentStart).inDays));

        currentLabel = 'This Week';
        previousLabel = 'Same Week Last Year';
        break;

      case ComparisonPeriod.Month:
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime.now();
        previousStart = DateTime(now.year, now.month - 1, 1);
        previousEnd = currentStart.subtract(const Duration(seconds: 1));
        currentLabel = DateFormat('MMMM yyyy').format(now);
        previousLabel = DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1, 1));
        break;

      case ComparisonPeriod.MonthYoY:
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime.now();
        previousStart = DateTime(now.year - 1, now.month, 1);
        previousEnd = DateTime(now.year - 1, now.month, now.day, 23, 59, 59);
        currentLabel = DateFormat('MMMM yyyy').format(now);
        previousLabel = DateFormat('MMMM yyyy').format(DateTime(now.year - 1, now.month, 1));
        break;

      case ComparisonPeriod.Year:
        currentStart = DateTime(now.year, 1, 1);
        currentEnd = DateTime.now();
        previousStart = DateTime(now.year - 1, 1, 1);
        previousEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        currentLabel = '${now.year}';
        previousLabel = '${now.year - 1}';
        break;
    }

    int currentOrders = 0;
    double currentAmount = 0.0;
    int previousOrders = 0;
    double previousAmount = 0.0;

    for (final order in allOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      final netAmount = (order.totalPrice ?? 0.0) - (order.refundAmount ?? 0.0);

      // Current period
      if (order.orderAt!.isAfter(currentStart.subtract(const Duration(seconds: 1))) &&
          order.orderAt!.isBefore(currentEnd.add(const Duration(seconds: 1)))) {
        currentOrders++;
        currentAmount += netAmount;
      }
      // Previous period
      else if (order.orderAt!.isAfter(previousStart.subtract(const Duration(seconds: 1))) &&
          order.orderAt!.isBefore(previousEnd.add(const Duration(seconds: 1)))) {
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

    // Calculate average order value
    final currentAOV = currentOrders > 0 ? currentAmount / currentOrders : 0.0;
    final previousAOV = previousOrders > 0 ? previousAmount / previousOrders : 0.0;

    // Calculate days in period
    final currentDays = currentEnd.difference(currentStart).inDays + 1;
    final previousDays = previousEnd.difference(previousStart).inDays + 1;

    // Calculate orders per day
    final currentOrdersPerDay = currentDays > 0 ? currentOrders / currentDays : 0.0;
    final previousOrdersPerDay = previousDays > 0 ? previousOrders / previousDays : 0.0;

    return ComparisonData(
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
  }

  Future<void> _exportToExcel() async {
    final data = _calculateComparisonData();

    try {
      // Prepare CSV data
      List<List<dynamic>> rows = [];

      // Header
      rows.add(['Sales Comparison Report']);
      rows.add(['Period', data.currentPeriod, 'vs', data.previousPeriod]);
      rows.add([]);

      // Data rows
      rows.add(['Metric', data.previousPeriod, data.currentPeriod, 'Growth %']);
      rows.add([
        'Total Orders',
        data.previousOrders,
        data.currentOrders,
        '${data.ordersGrowth >= 0 ? '+' : ''}${data.ordersGrowth.toStringAsFixed(1)}%'
      ]);
      rows.add([
        'Total Amount',
        DecimalSettings.formatAmount(data.previousAmount),
        DecimalSettings.formatAmount(data.currentAmount),
        '${data.amountGrowth >= 0 ? '+' : ''}${data.amountGrowth.toStringAsFixed(1)}%'
      ]);
      rows.add([
        'Average Order Value',
        DecimalSettings.formatAmount(data.previousAOV),
        DecimalSettings.formatAmount(data.currentAOV),
        '-'
      ]);
      rows.add([
        'Orders Per Day',
        data.previousOrdersPerDay.toStringAsFixed(1),
        data.currentOrdersPerDay.toStringAsFixed(1),
        '-'
      ]);

      rows.add([]);
      rows.add(['Performance', _getTrendLabel(data.trendCategory)]);

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/sales_comparison_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Write to file
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Sales Comparison Report - ${data.currentPeriod}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (pastOrderStore.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final data = _calculateComparisonData();
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
                        color: Colors.black.withOpacity(0.05),
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
                        color: Colors.black.withOpacity(0.05),
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
                          color: trendColor.withOpacity(0.1),
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
                    onPressed: _exportToExcel,
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
                        color: Colors.black.withOpacity(0.05),
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
            color: Colors.black.withOpacity(0.05),
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
                  color: color.withOpacity(0.1),
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
                    color: growthPercentage >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
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
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
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