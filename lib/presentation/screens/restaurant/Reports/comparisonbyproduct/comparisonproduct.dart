import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/common/app_responsive.dart';

enum ComparisonPeriod { Today, ThisWeek, MonthWise, YearWise }

class ComparisonByProduct extends StatefulWidget {
  const ComparisonByProduct({super.key});

  @override
  State<ComparisonByProduct> createState() => _ComparisonByProductState();
}

class _ComparisonByProductState extends State<ComparisonByProduct> {
  ComparisonPeriod _selectedPeriod = ComparisonPeriod.Today;

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
                              'Comparison By Product',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.headingFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Compare product sales trends',
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
      case ComparisonPeriod.Today:
        return 'Today';
      case ComparisonPeriod.ThisWeek:
        return 'This Week';
      case ComparisonPeriod.MonthWise:
        return 'Month Wise';
      case ComparisonPeriod.YearWise:
        return 'Year Wise';
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
  int _selectedYear = DateTime.now().year;
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _initializeYears();
    _loadData();
  }

  void _initializeYears() {
    final currentYear = DateTime.now().year;
    _years = List.generate(11, (index) => currentYear - index);
  }

  Future<void> _loadData() async {
    await pastOrderStore.loadPastOrders();
    if (mounted) setState(() {});
  }

  List<ProductComparisonData> _calculateComparisonData() {
    final allOrders = pastOrderStore.pastOrders.toList();
    final now = DateTime.now();

    DateTime currentStart, currentEnd, previousStart, previousEnd;
    String currentLabel, previousLabel;

    switch (widget.period) {
      case ComparisonPeriod.Today:
        currentStart = DateTime(now.year, now.month, now.day);
        currentEnd = currentStart.add(const Duration(days: 1));
        previousStart = currentStart.subtract(const Duration(days: 1));
        previousEnd = currentStart;
        currentLabel = 'Today';
        previousLabel = 'Yesterday';
        break;

      case ComparisonPeriod.ThisWeek:
        final weekDay = now.weekday;
        currentStart = now.subtract(Duration(days: weekDay - 1));
        currentStart = DateTime(currentStart.year, currentStart.month, currentStart.day);
        currentEnd = currentStart.add(const Duration(days: 7));
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart;
        currentLabel = 'This Week';
        previousLabel = 'Last Week';
        break;

      case ComparisonPeriod.MonthWise:
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime(now.year, now.month + 1, 1);
        previousStart = DateTime(now.year, now.month - 1, 1);
        previousEnd = currentStart;
        currentLabel = DateFormat('MMMM yyyy').format(now);
        previousLabel = DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1, 1));
        break;

      case ComparisonPeriod.YearWise:
        currentStart = DateTime(_selectedYear, 1, 1);
        currentEnd = DateTime(_selectedYear + 1, 1, 1);
        previousStart = DateTime(_selectedYear - 1, 1, 1);
        previousEnd = DateTime(_selectedYear, 1, 1);
        currentLabel = '$_selectedYear';
        previousLabel = '${_selectedYear - 1}';
        break;
    }

    // Maps to store quantities per item
    Map<String, int> currentQuantities = {};
    Map<String, int> previousQuantities = {};

    for (final order in allOrders) {
      final orderStatus = order.orderStatus?.toUpperCase() ?? '';
      if (orderStatus == 'FULLY_REFUNDED') continue;
      if (orderStatus == 'VOID' || orderStatus == 'VOIDED') continue;
      if (order.orderAt == null) continue;

      // Check if current period
      if (order.orderAt!.isAfter(currentStart.subtract(const Duration(seconds: 1))) &&
          order.orderAt!.isBefore(currentEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            currentQuantities[item.title] = (currentQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
      // Check if previous period
      else if (order.orderAt!.isAfter(previousStart.subtract(const Duration(seconds: 1))) &&
          order.orderAt!.isBefore(previousEnd)) {
        for (final item in order.items) {
          final effectiveQty = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
          if (effectiveQty > 0) {
            previousQuantities[item.title] = (previousQuantities[item.title] ?? 0) + effectiveQty;
          }
        }
      }
    }

    // Combine all unique products
    final allProducts = {...currentQuantities.keys, ...previousQuantities.keys};

    // Build comparison list
    final List<ProductComparisonData> comparisonList = [];
    for (final productName in allProducts) {
      final currentQty = currentQuantities[productName] ?? 0;
      final previousQty = previousQuantities[productName] ?? 0;
      final difference = currentQty - previousQty;

      // Calculate growth percentage
      double growthPercentage = 0.0;
      if (previousQty > 0) {
        growthPercentage = ((currentQty - previousQty) / previousQty) * 100;
      } else if (currentQty > 0) {
        growthPercentage = 100.0; // New product, 100% growth
      }

      comparisonList.add(ProductComparisonData(
        productName: productName,
        previousPeriodQty: previousQty,
        currentPeriodQty: currentQty,
        difference: difference,
        growthPercentage: growthPercentage,
        currentLabel: currentLabel,
        previousLabel: previousLabel,
      ));
    }

    // Sort by current period quantity (descending)
    comparisonList.sort((a, b) => b.currentPeriodQty.compareTo(a.currentPeriodQty));

    return comparisonList;
  }

  Future<void> _exportReport() async {
    final comparisonData = _calculateComparisonData();

    if (comparisonData.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Product Name',
      comparisonData.first.previousLabel,
      comparisonData.first.currentLabel,
      'Difference',
      'Growth %'
    ];

    final data = comparisonData.map((product) => [
      product.productName,
      product.previousPeriodQty.toString(),
      product.currentPeriodQty.toString(),
      '${product.difference > 0 ? '+' : ''}${product.difference}',
      '${product.growthPercentage.toStringAsFixed(1)}%',
    ]).toList();

    final totalCurrent = comparisonData.fold<int>(0, (sum, p) => sum + p.currentPeriodQty);
    final totalPrevious = comparisonData.fold<int>(0, (sum, p) => sum + p.previousPeriodQty);
    final totalDifference = totalCurrent - totalPrevious;
    final overallGrowth = totalPrevious > 0 ? ((totalCurrent - totalPrevious) / totalPrevious) * 100 : 0.0;

    final summary = {
      'Comparison Period': '${comparisonData.first.previousLabel} vs ${comparisonData.first.currentLabel}',
      'Total Products': comparisonData.length.toString(),
      'Total Previous Period': totalPrevious.toString(),
      'Total Current Period': totalCurrent.toString(),
      'Total Difference': '${totalDifference > 0 ? '+' : ''}$totalDifference',
      'Overall Growth': '${overallGrowth >= 0 ? '+' : ''}${overallGrowth.toStringAsFixed(1)}%',
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'product_comparison_${comparisonData.first.currentLabel.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Product Comparison Report - ${comparisonData.first.previousLabel} vs ${comparisonData.first.currentLabel}',
      headers: headers,
      data: data,
      summary: summary,
    );
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

        final comparisonData = _calculateComparisonData();

        // Calculate summary metrics
        final totalProducts = comparisonData.length;
        final topGainer = comparisonData.where((p) => p.difference > 0).isNotEmpty
            ? comparisonData.where((p) => p.difference > 0).reduce((a, b) => a.difference > b.difference ? a : b)
            : null;
        final topDecliner = comparisonData.where((p) => p.difference < 0).isNotEmpty
            ? comparisonData.where((p) => p.difference < 0).reduce((a, b) => a.difference < b.difference ? a : b)
            : null;

        return SingleChildScrollView(
          child: Padding(
            padding: AppResponsive.padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year Selector (for YearWise only)
                if (widget.period == ComparisonPeriod.YearWise) ...[
                  Container(
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
                      children: [
                        Text(
                          'Select Year:',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppResponsive.mediumSpacing(context),
                            vertical: AppResponsive.smallSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            underline: Container(),
                            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                            items: _years.map((year) {
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(
                                  '$year',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(context),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedYear = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                ],

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Total Products',
                        totalProducts.toString(),
                        Icons.inventory_2_outlined,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Top Gainer',
                        topGainer != null ? '+${topGainer.difference}' : 'N/A',
                        Icons.trending_up,
                        Colors.green,
                        subtitle: topGainer?.productName,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _buildSummaryCard(
                  context,
                  'Top Decliner',
                  topDecliner != null ? '${topDecliner.difference}' : 'N/A',
                  Icons.trending_down,
                  Colors.red,
                  subtitle: topDecliner?.productName,
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Export Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: comparisonData.isNotEmpty ? _exportReport : null,
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

                // Data Table or Empty State
                if (comparisonData.isEmpty)
                  _buildEmptyState(context, 'No comparison data available for selected period')
                else
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Product Comparison',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.subheadingFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppResponsive.smallSpacing(context),
                                  vertical: AppResponsive.smallSpacing(context) / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                ),
                                child: Text(
                                  '${comparisonData.length} products',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.captionFontSize(context),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    columnSpacing: AppResponsive.tableColumnSpacing(context),
                                    headingRowHeight: AppResponsive.tableHeadingHeight(context),
                                    dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                                    dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
                                    headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                    columns: [
                                      DataColumn(
                                        label: Text(
                                          'Product',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          comparisonData.first.previousLabel,
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          comparisonData.first.currentLabel,
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Difference',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Growth %',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: comparisonData.map((data) {
                                      Color differenceColor = data.difference > 0
                                          ? Colors.green
                                          : data.difference < 0
                                              ? Colors.red
                                              : Colors.grey;
                                      String differenceText = data.difference > 0
                                          ? '+${data.difference}'
                                          : '${data.difference}';

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              data.productName,
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${data.previousPeriodQty}',
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${data.currentPeriodQty}',
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: AppResponsive.smallSpacing(context),
                                                vertical: AppResponsive.smallSpacing(context) / 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: differenceColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                differenceText,
                                                style: GoogleFonts.poppins(
                                                  fontSize: AppResponsive.smallFontSize(context),
                                                  fontWeight: FontWeight.w700,
                                                  color: differenceColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${data.growthPercentage.toStringAsFixed(1)}%',
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                                fontWeight: FontWeight.w600,
                                                color: differenceColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
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

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
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
                padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
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
          SizedBox(height: AppResponsive.smallSpacing(context) / 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: AppResponsive.smallSpacing(context) / 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: AppResponsive.padding(context),
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
        children: [
          Icon(
            Icons.trending_up,
            size: AppResponsive.largeIconSize(context) * 2,
            color: Colors.grey[400],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductComparisonData {
  final String productName;
  final int previousPeriodQty;
  final int currentPeriodQty;
  final int difference;
  final double growthPercentage;
  final String currentLabel;
  final String previousLabel;

  ProductComparisonData({
    required this.productName,
    required this.previousPeriodQty,
    required this.currentPeriodQty,
    required this.difference,
    required this.growthPercentage,
    required this.currentLabel,
    required this.previousLabel,
  });
}