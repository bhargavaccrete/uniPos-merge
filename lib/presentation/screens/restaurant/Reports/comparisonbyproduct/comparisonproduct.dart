import 'package:flutter/material.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/widgets/upgrade_sheet.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

enum ComparisonPeriod { Today, ThisWeek, MonthWise, YearWise }

class ComparisonByProduct extends StatefulWidget {
  const ComparisonByProduct({super.key});

  @override
  State<ComparisonByProduct> createState() => _ComparisonByProductState();
}

class _ComparisonByProductState extends State<ComparisonByProduct> {
  ComparisonPeriod _selectedPeriod = ComparisonPeriod.Today;

  /// A product comparison reaches back to its PREVIOUS window's start — that is
  /// the date the plan's history must cover.
  static DateTime _earliestDate(ComparisonPeriod p) {
    final now = DateTime.now();
    switch (p) {
      case ComparisonPeriod.Today:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      case ComparisonPeriod.ThisWeek:
        final weekStart =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        return weekStart.subtract(const Duration(days: 7));
      case ComparisonPeriod.MonthWise:
        return DateTime(now.year, now.month - 1, 1);
      case ComparisonPeriod.YearWise:
        return DateTime(now.year - 1, 1, 1);
    }
  }

  static IconData _periodIcon(ComparisonPeriod p) {
    switch (p) {
      case ComparisonPeriod.Today:
        return Icons.today;
      case ComparisonPeriod.ThisWeek:
        return Icons.view_week;
      case ComparisonPeriod.MonthWise:
        return Icons.calendar_month;
      case ComparisonPeriod.YearWise:
        return Icons.calendar_today;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Comparison By Product',
        subtitle: 'Compare product sales trends',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportFilterBar<ComparisonPeriod>(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            options: [
              for (final p in ComparisonPeriod.values)
                ReportFilterOption(
                  value: p,
                  label: _getPeriodLabel(p),
                  icon: _periodIcon(p),
                  locked: !ReportHistoryWindow.allows(_earliestDate(p)),
                  onLockedTap: () => UpgradeSheet.showHistoryLimit(
                    context,
                    featureName: '${_getPeriodLabel(p)} product comparison',
                    neededDays: ReportHistoryWindow.requiredDays(_earliestDate(p)),
                    allowedDays: ReportHistoryWindow.limitDays ?? 0,
                  ),
                ),
            ],
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(
            child: ComparisonReportView(
              key: ValueKey(_selectedPeriod),
              period: _selectedPeriod,
            ),
          ),
        ],
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

  /// Computed once per data/year change and shared by the table and the export.
  List<ProductComparisonData> _comparisonData = const [];
  int _recalcCount = 0;
  late final ReactionDisposer _dataReaction;

  @override
  void initState() {
    super.initState();
    _initializeYears();
    // Fires once per MobX batch that touches the orders list or the loading
    // flag — the same signals the Observer used to recompute on.
    _dataReaction = reaction<bool>(
      (_) {
        pastOrderStore.pastOrders.length;
        return pastOrderStore.isLoading;
      },
      (_) => _recalculate(),
      equals: (previous, next) => false,
    );
    _loadData();
  }

  @override
  void dispose() {
    _dataReaction();
    super.dispose();
  }

  /// Only offer years the plan's history window can reach — the comparison also
  /// needs the year BEFORE the selected one.
  void _initializeYears() {
    final currentYear = DateTime.now().year;
    final cutoffYear = ReportHistoryWindow.cutoff?.year;
    final earliest = cutoffYear == null ? currentYear - 10 : cutoffYear + 1;
    _years = [
      for (int y = currentYear; y >= earliest; y--) y,
    ];
    if (_years.isEmpty) _years = [currentYear];
  }

  Future<void> _loadData() async {
    final before = _recalcCount;
    await pastOrderStore.loadPastOrders();
    if (_recalcCount == before) _recalculate();
  }

  void _recalculate() {
    if (!mounted || pastOrderStore.isLoading) return;
    _recalcCount++;
    setState(() {
      _comparisonData = calculateProductComparison(
        orders: pastOrderStore.pastOrders,
        period: widget.period,
        selectedYear: _selectedYear,
        now: DateTime.now(),
        cutoff: ReportHistoryWindow.cutoff,
      );
    });
  }

  Future<void> _exportReport() async {
    final comparisonData = _comparisonData;

    if (comparisonData.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final export = productComparisonExport(comparisonData);

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'product_comparison_${comparisonData.first.currentLabel.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Product Comparison Report - ${comparisonData.first.previousLabel} vs ${comparisonData.first.currentLabel}',
      headers: export.headers,
      data: export.rows,
      summary: {
        ...export.summary,
        'Generated': ReportExportService.formatDateTime(DateTime.now()),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (pastOrderStore.isLoading) return const ReportLoading();

        final comparisonData = _comparisonData;

        // Calculate summary metrics
        final totalProducts = comparisonData.length;
        final topGainer = comparisonData.where((p) => p.difference > 0).isNotEmpty
            ? comparisonData.where((p) => p.difference > 0).reduce((a, b) => a.difference > b.difference ? a : b)
            : null;
        final topDecliner = comparisonData.where((p) => p.difference < 0).isNotEmpty
            ? comparisonData.where((p) => p.difference < 0).reduce((a, b) => a.difference < b.difference ? a : b)
            : null;

        return ReportBody(
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
                                _recalculate();
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
                      child: ReportSummaryCard(
                        title: 'Total Products',
                        value: totalProducts.toString(),
                        icon: Icons.inventory_2_outlined,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: ReportSummaryCard(
                        title: 'Top Gainer',
                        value: topGainer != null ? '+${topGainer.difference}' : 'N/A',
                        icon: Icons.trending_up,
                        color: Colors.green,
                        subtitle: topGainer?.productName,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                ReportSummaryCard(
                  title: 'Top Decliner',
                  value: topDecliner != null ? '${topDecliner.difference}' : 'N/A',
                  icon: Icons.trending_down,
                  color: Colors.red,
                  subtitle: topDecliner?.productName,
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Export Button
                ReportExportButton(onPressed: _exportReport),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Data Table or Empty State
                if (comparisonData.isEmpty)
                  const ReportEmptyState(
                    icon: Icons.trending_up,
                    title: 'No Comparison Data',
                    message: 'No comparison data available for selected period',
                  )
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
                                    headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
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
                                                data.differenceLabel,
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
                                              data.growthLabel,
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
        );
      },
    );
  }
}

/// Current vs previous period quantities per product.
///
/// A period's lower bound is `isAfter(start - 1s)`, so an order in the final
/// second before [start] lands in that period. Kept deliberately — changing it
/// would move orders between the two columns.
List<ProductComparisonData> calculateProductComparison({
  required Iterable<PastOrderModel> orders,
  required ComparisonPeriod period,
  required int selectedYear,
  required DateTime now,
  required DateTime? cutoff,
}) {
    final allOrders = orders;

    DateTime currentStart, currentEnd, previousStart, previousEnd;
    String currentLabel, previousLabel;

    switch (period) {
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
        currentStart = DateTime(selectedYear, 1, 1);
        currentEnd = DateTime(selectedYear + 1, 1, 1);
        previousStart = DateTime(selectedYear - 1, 1, 1);
        previousEnd = DateTime(selectedYear, 1, 1);
        currentLabel = '$selectedYear';
        previousLabel = '${selectedYear - 1}';
        break;
    }

    // Maps to store quantities per item
    Map<String, int> currentQuantities = {};
    Map<String, int> previousQuantities = {};

    // [cutoff] is the plan data-scope clamp (reports.history_limit_days).
    for (final order in allOrders) {
      final orderStatus = order.orderStatus?.toUpperCase() ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(orderStatus)) continue;
      if (order.orderAt == null) continue;
      if (cutoff != null && order.orderAt!.isBefore(cutoff)) continue;

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

      // Calculate growth percentage.
      // FIX 1: Use double.infinity as a sentinel for "New" (no previous data).
      // Displaying 100% growth when previous=0 is mathematically wrong.
      double growthPercentage = 0.0;
      if (previousQty > 0) {
        growthPercentage = ((currentQty - previousQty) / previousQty) * 100;
      } else if (currentQty > 0) {
        growthPercentage = double.infinity; // sentinel: product is new this period
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

  /// Shown in the table and written to the export — one definition for both.
  String get differenceLabel => difference > 0 ? '+$difference' : '$difference';

  /// 'New' for the no-previous-data sentinel; '+' prefix for positive growth.
  String get growthLabel => growthPercentage.isInfinite
      ? 'New'
      : '${growthPercentage >= 0 ? '+' : ''}${growthPercentage.toStringAsFixed(1)}%';
}

class ProductComparisonExport {
  final List<String> headers;
  final List<List<String>> rows;

  /// Everything except 'Generated', which the caller stamps at export time.
  final Map<String, String> summary;

  const ProductComparisonExport({
    required this.headers,
    required this.rows,
    required this.summary,
  });
}

/// Export payload for [data] — the same list, in the same order, the table shows.
ProductComparisonExport productComparisonExport(List<ProductComparisonData> data) {
  final headers = [
    'Product Name',
    data.first.previousLabel,
    data.first.currentLabel,
    'Difference',
    'Growth %'
  ];

  final rows = data.map((product) => [
    product.productName,
    product.previousPeriodQty.toString(),
    product.currentPeriodQty.toString(),
    product.differenceLabel,
    product.growthLabel,
  ]).toList();

  final totalCurrent = data.fold<int>(0, (sum, p) => sum + p.currentPeriodQty);
  final totalPrevious = data.fold<int>(0, (sum, p) => sum + p.previousPeriodQty);
  final totalDifference = totalCurrent - totalPrevious;
  // 'New' when totalPrevious=0 — '+0.0%' is misleading when base is zero.
  final overallGrowthStr = totalPrevious == 0
      ? (totalCurrent > 0 ? 'New' : '0%')
      : () {
          final g = ((totalCurrent - totalPrevious) / totalPrevious) * 100;
          return '${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)}%';
        }();

  return ProductComparisonExport(
    headers: headers,
    rows: rows,
    summary: {
      'Comparison Period': '${data.first.previousLabel} vs ${data.first.currentLabel}',
      'Total Products': data.length.toString(),
      'Total Previous Period': totalPrevious.toString(),
      'Total Current Period': totalCurrent.toString(),
      'Total Difference': '${totalDifference > 0 ? '+' : ''}$totalDifference',
      'Overall Growth': overallGrowthStr,
    },
  );
}