import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
class ComparisonByWeek extends StatefulWidget {
  const ComparisonByWeek({super.key});

  @override
  State<ComparisonByWeek> createState() => _ComparisonByWeekState();
}

class _ComparisonByWeekState extends State<ComparisonByWeek> {
  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  Future<void> _loadComparisonData() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  ComparisonData _calculateComparisonData() {
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();

    final now = DateTime.now();

    // Calculate current week (last 7 days)
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStartMidnight = DateTime(
        currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);

    // Calculate previous week (7 days before current week)
    final previousWeekStart = currentWeekStartMidnight.subtract(Duration(days: 7));
    final previousWeekEnd = currentWeekStartMidnight.subtract(Duration(seconds: 1));

    int currentOrders = 0;
    double currentAmount = 0.0;
    int previousOrders = 0;
    double previousAmount = 0.0;

    for (final order in allOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;
      if (order.orderAt == null) continue;

      final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);

      // Current week
      if (order.orderAt!.isAfter(currentWeekStartMidnight) ||
          order.orderAt!.isAtSameMomentAs(currentWeekStartMidnight)) {
        currentOrders++;
        currentAmount += netAmount;
      }
      // Previous week
      else if (order.orderAt!.isAfter(previousWeekStart) &&
          order.orderAt!.isBefore(previousWeekEnd)) {
        previousOrders++;
        previousAmount += netAmount;
      }
    }

    return ComparisonData(
      currentPeriod: 'Current Week',
      previousPeriod: 'Previous Week',
      currentOrders: currentOrders,
      currentAmount: currentAmount,
      previousOrders: previousOrders,
      previousAmount: previousAmount,
    );
  }

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
                          'Comparison By Week',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Compare sales week over week',
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
                      Icons.trending_up,
                      size: AppResponsive.iconSize(context),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: Observer(builder: (_) {
              if (pastOrderStore.isLoading){
                return Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final data = _calculateComparisonData();

              return SingleChildScrollView(
                padding: AppResponsive.padding(context),
                child: AppResponsive.constrainedContent(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Week starting ${_getCurrentWeekStart()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.subheadingFontSize(context),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _loadComparisonData,
                                  icon: Icon(Icons.refresh, color: AppColors.primary),
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            AppResponsive.verticalSpace(context, size: SpacingSize.small),
                            Text(
                              'Week-over-week sales performance analysis',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      AppResponsive.verticalSpace(context),

                      // Export Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _exportReport(data),
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
                      ),

                      AppResponsive.verticalSpace(context),

                      // Comparison Table
                      Container(
                        width: double.infinity,
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: AppResponsive.tableColumnSpacing(context),
                              headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
                              headingRowHeight: AppResponsive.tableHeadingHeight(context),
                              dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                              dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'Details',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppResponsive.bodyFontSize(context),
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Previous Week',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppResponsive.bodyFontSize(context),
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Current Week',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppResponsive.bodyFontSize(context),
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                              rows: [
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'Total Orders',
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.smallFontSize(context),
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          data.previousOrders.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.smallFontSize(context),
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          data.currentOrders.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.smallFontSize(context),
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'Total Amount (${CurrencyHelper.currentSymbol})',
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.smallFontSize(context),
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          DecimalSettings.formatAmount(data.previousAmount),
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.smallFontSize(context),
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          DecimalSettings.formatAmount(data.currentAmount),
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.smallFontSize(context),
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'Growth %',
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.smallFontSize(context),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(child: Text('-')),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          _calculateGrowth(data.previousAmount, data.currentAmount),
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.smallFontSize(context),
                                            fontWeight: FontWeight.w600,
                                            color: _getGrowthColor(data.previousAmount, data.currentAmount),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getCurrentWeekStart() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return '${weekStart.day}/${weekStart.month}/${weekStart.year}';
  }

  String _calculateGrowth(double previous, double current) {
    if (previous == 0) {
      return current > 0 ? '+100%' : '0%';
    }
    final growth = ((current - previous) / previous) * 100;
    return '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%';
  }

  Color _getGrowthColor(double previous, double current) {
    if (current > previous) return Colors.green.shade700;
    if (current < previous) return Colors.red.shade700;
    return Colors.grey;
  }

  Future<void> _exportReport(ComparisonData data) async {
    // Prepare headers
    final headers = ['Details', data.previousPeriod, data.currentPeriod];

    // Calculate growth percentages
    final orderGrowth = data.previousOrders == 0
        ? (data.currentOrders > 0 ? 100.0 : 0.0)
        : ((data.currentOrders - data.previousOrders) / data.previousOrders) * 100;
    final amountGrowth = data.previousAmount == 0
        ? (data.currentAmount > 0 ? 100.0 : 0.0)
        : ((data.currentAmount - data.previousAmount) / data.previousAmount) * 100;

    // Prepare data rows
    final dataRows = [
      ['Total Orders', data.previousOrders.toString(), data.currentOrders.toString()],
      [
        'Total Amount',
        ReportExportService.formatCurrency(data.previousAmount),
        ReportExportService.formatCurrency(data.currentAmount)
      ],
      [
        'Growth %',
        '-',
        '${amountGrowth >= 0 ? '+' : ''}${amountGrowth.toStringAsFixed(1)}%'
      ],
    ];

    // Prepare summary
    final summary = {
      'Report Type': 'Week Comparison',
      'Previous Period': data.previousPeriod,
      'Current Period': data.currentPeriod,
      'Order Growth': '${orderGrowth >= 0 ? '+' : ''}${orderGrowth.toStringAsFixed(1)}%',
      'Amount Growth': '${amountGrowth >= 0 ? '+' : ''}${amountGrowth.toStringAsFixed(1)}%',
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'sales_comparison_week_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Sales Comparison by Week',
      headers: headers,
      data: dataRows,
      summary: summary,
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

  ComparisonData({
    required this.currentPeriod,
    required this.previousPeriod,
    required this.currentOrders,
    required this.currentAmount,
    required this.previousOrders,
    required this.previousAmount,
  });
}