import 'package:flutter/material.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/widgets/upgrade_sheet.dart';

/// What length of time is being measured.
enum ComparisonScale { week, month, year }

/// What the current period is measured against.
enum ComparisonBasis { previousPeriod, sameLastYear }

enum TrendCategory { excellent, good, stable, declining }

/// The screen opens if ANY of these is granted; each scale gates itself.
const kComparisonPeriodEntitlements = <String>[
  EntKeys.reportsComparisonWeek,
  EntKeys.reportsComparisonMonth,
  EntKeys.reportsComparisonYear,
];

IconData _scaleIcon(ComparisonScale s) {
  switch (s) {
    case ComparisonScale.week:
      return Icons.view_week;
    case ComparisonScale.month:
      return Icons.calendar_month;
    case ComparisonScale.year:
      return Icons.calendar_today;
  }
}

/// A basis inherits its scale's entitlement — comparing against last year is
/// still a week/month comparison.
String _scaleEntitlement(ComparisonScale s) {
  switch (s) {
    case ComparisonScale.week:
      return EntKeys.reportsComparisonWeek;
    case ComparisonScale.month:
      return EntKeys.reportsComparisonMonth;
    case ComparisonScale.year:
      return EntKeys.reportsComparisonYear;
  }
}

/// One selectable comparison. The five offered pairs of the 3×2 matrix — the
/// sixth (year vs same-period-last-year) is the same window as
/// `year vs previous period`, so it is never offered.
class _Pair {
  final ComparisonScale scale;
  final ComparisonBasis basis;
  const _Pair(this.scale, this.basis);

  @override
  bool operator ==(Object other) =>
      other is _Pair && other.scale == scale && other.basis == basis;

  @override
  int get hashCode => Object.hash(scale, basis);
}

const _pairs = <_Pair>[
  _Pair(ComparisonScale.week, ComparisonBasis.previousPeriod),
  _Pair(ComparisonScale.week, ComparisonBasis.sameLastYear),
  _Pair(ComparisonScale.month, ComparisonBasis.previousPeriod),
  _Pair(ComparisonScale.month, ComparisonBasis.sameLastYear),
  _Pair(ComparisonScale.year, ComparisonBasis.previousPeriod),
];

String _pairLabel(_Pair p) {
  final lastYear = p.basis == ComparisonBasis.sameLastYear;
  switch (p.scale) {
    case ComparisonScale.week:
      return lastYear ? 'Week vs Last Year' : 'This Week';
    case ComparisonScale.month:
      return lastYear ? 'Month vs Last Year' : 'This Month';
    case ComparisonScale.year:
      return 'This Year';
  }
}

IconData _pairIcon(_Pair p) =>
    p.basis == ComparisonBasis.sameLastYear ? Icons.event_repeat : _scaleIcon(p.scale);

/// The date windows a comparison spans. Half-open on the previous side:
/// `[previousStart, previousEnd)`, which is what allows a non-adjacent
/// (same-period-last-year) window.
class _Window {
  final DateTime currentStart;
  final DateTime previousStart;
  final DateTime previousEnd;
  final String currentLabel;
  final String previousLabel;

  const _Window({
    required this.currentStart,
    required this.previousStart,
    required this.previousEnd,
    required this.currentLabel,
    required this.previousLabel,
  });
}

_Window _resolveWindow(ComparisonScale scale, ComparisonBasis basis, DateTime now) {
  switch (scale) {
    case ComparisonScale.week:
      final currentStart =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      if (basis == ComparisonBasis.previousPeriod) {
        final previousStart = currentStart.subtract(const Duration(days: 7));
        return _Window(
          currentStart: currentStart,
          previousStart: previousStart,
          previousEnd: currentStart,
          currentLabel: 'This Week',
          previousLabel: 'Last Week',
        );
      }
      final lastYear = DateTime(now.year - 1, now.month, now.day);
      final previousStart = DateTime(lastYear.year, lastYear.month, lastYear.day)
          .subtract(Duration(days: lastYear.weekday - 1));
      return _Window(
        currentStart: currentStart,
        previousStart: previousStart,
        previousEnd: previousStart.add(const Duration(days: 7)),
        currentLabel: 'This Week',
        previousLabel: 'Same Week Last Year',
      );

    case ComparisonScale.month:
      final currentStart = DateTime(now.year, now.month, 1);
      if (basis == ComparisonBasis.previousPeriod) {
        final previousStart = DateTime(now.year, now.month - 1, 1);
        return _Window(
          currentStart: currentStart,
          previousStart: previousStart,
          previousEnd: currentStart,
          currentLabel: DateFormat('MMMM yyyy').format(now),
          previousLabel: DateFormat('MMMM yyyy').format(previousStart),
        );
      }
      final previousStart = DateTime(now.year - 1, now.month, 1);
      return _Window(
        currentStart: currentStart,
        previousStart: previousStart,
        previousEnd: DateTime(now.year - 1, now.month + 1, 1),
        currentLabel: DateFormat('MMMM yyyy').format(now),
        previousLabel: DateFormat('MMMM yyyy').format(previousStart),
      );

    case ComparisonScale.year:
      final currentStart = DateTime(now.year, 1, 1);
      final previousStart = DateTime(now.year - 1, 1, 1);
      return _Window(
        currentStart: currentStart,
        previousStart: previousStart,
        previousEnd: currentStart,
        currentLabel: '${now.year}',
        previousLabel: '${now.year - 1}',
      );
  }
}

/// A comparison reaches back to its PREVIOUS window's start, not the current
/// one — that is the date the plan's history must cover.
DateTime _earliestDate(ComparisonScale s, ComparisonBasis b) =>
    _resolveWindow(s, b, DateTime.now()).previousStart;

bool _historyAllows(ComparisonScale s, ComparisonBasis b) =>
    ReportHistoryWindow.allows(_earliestDate(s, b));

bool _scaleEntitled(ComparisonScale s) => PlanEnforce.allows(_scaleEntitlement(s));

/// Change from `previous` → `current`. A null [percent] means the previous
/// period had no base, so a percentage is undefined — report 'New' instead of
/// a misleading +100%.
class Growth {
  final double? percent;
  final bool isNew;

  const Growth._(this.percent, this.isNew);

  factory Growth.between(num previous, num current) {
    if (previous == 0) return Growth._(null, current > 0);
    return Growth._(((current - previous) / previous) * 100, false);
  }

  bool get isPositive => percent == null ? isNew : percent! >= 0;

  String get label {
    if (percent == null) return isNew ? 'New' : '0%';
    return '${percent! >= 0 ? '+' : ''}${percent!.toStringAsFixed(1)}%';
  }

  String get arrow {
    final p = percent;
    if (p == null) return isNew ? '↑↑' : '→';
    if (p >= 50) return '↑↑';
    if (p >= 20) return '↗';
    if (p >= 5) return '↑';
    if (p <= -50) return '↓↓';
    if (p <= -20) return '↘';
    if (p <= -5) return '↓';
    return '→';
  }
}

class SalesComparison extends StatefulWidget {
  const SalesComparison({super.key});

  @override
  State<SalesComparison> createState() => _SalesComparisonState();
}

class _SalesComparisonState extends State<SalesComparison> {
  ComparisonScale _scale = ComparisonScale.month;
  ComparisonBasis _basis = ComparisonBasis.previousPeriod;
  bool _hasComputablePair = false;

  @override
  void initState() {
    super.initState();
    _selectInitial();
  }

  bool _pairAvailable(_Pair p) => _scaleEntitled(p.scale) && _historyAllows(p.scale, p.basis);

  /// Open on a pair the plan both grants and has enough history for. The route
  /// guard only proved that SOME scale is entitled — not that it's computable.
  void _selectInitial() {
    // Prefer 'This Month' (the previous default), else the first computable pair.
    final available = _pairs.where(_pairAvailable).toList();
    if (available.isEmpty) {
      _hasComputablePair = false;
      return;
    }
    final pick = available.firstWhere(
      (p) => p.scale == ComparisonScale.month && p.basis == ComparisonBasis.previousPeriod,
      orElse: () => available.first,
    );
    _hasComputablePair = true;
    _scale = pick.scale;
    _basis = pick.basis;
  }

  void _onPairTap(_Pair p) {
    if (!_scaleEntitled(p.scale)) {
      UpgradeSheet.showLocked(context, featureName: '${_pairLabel(p)} comparison');
      return;
    }
    if (!_historyAllows(p.scale, p.basis)) {
      UpgradeSheet.showHistoryLimit(
        context,
        featureName: '${_pairLabel(p)} comparison',
        neededDays: ReportHistoryWindow.requiredDays(_earliestDate(p.scale, p.basis)),
        allowedDays: ReportHistoryWindow.limitDays ?? 0,
      );
      return;
    }
    setState(() {
      _scale = p.scale;
      _basis = p.basis;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Sales Comparison',
        subtitle: 'Compare sales performance over time',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          _buildSelectors(),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(
            child: _hasComputablePair
                ? ComparisonReportView(scale: _scale, basis: _basis)
                : _buildHistoryEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return ReportFilterBar<_Pair>(
      selected: _Pair(_scale, _basis),
      onSelected: _onPairTap,
      options: [
        for (final p in _pairs)
          ReportFilterOption(
            value: p,
            label: _pairLabel(p),
            icon: _pairIcon(p),
            locked: !_pairAvailable(p),
            onLockedTap: () => _onPairTap(p),
          ),
      ],
    );
  }

  /// Entitled to a comparison, but the plan's history window is too short to
  /// compute any of them. Showing a table here would print an empty previous
  /// period and a bogus 'New' growth.
  Widget _buildHistoryEmptyState() {
    return ReportEmptyState(
      icon: Icons.history_toggle_off,
      title: 'Not enough report history',
      message: 'Your plan includes ${UpgradeSheet.formatDays(ReportHistoryWindow.limitDays ?? 0)} '
          'of report history.\nThe comparisons in your plan need more than that.',
      action: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, RouteNames.restaurantNeedHelp),
        icon: const Icon(Icons.support_agent_rounded),
        label: Text('Contact Bill Berry',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.buttonFontSize(context),
              fontWeight: FontWeight.w600,
            )),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.largeSpacing(context),
            vertical: AppResponsive.mediumSpacing(context),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class ComparisonReportView extends StatefulWidget {
  final ComparisonScale scale;
  final ComparisonBasis basis;

  const ComparisonReportView({
    super.key,
    required this.scale,
    required this.basis,
  });

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
    // Orders are already in memory — a period change only re-buckets them.
    if (widget.scale != oldWidget.scale || widget.basis != oldWidget.basis) {
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

  TrendCategory _getTrendCategory(Growth amountGrowth, double currentAmount) {
    final p = amountGrowth.percent;
    if (p == null) return currentAmount > 0 ? TrendCategory.excellent : TrendCategory.stable;
    if (p >= 50) return TrendCategory.excellent;
    if (p >= 20) return TrendCategory.good;
    if (p >= -5) return TrendCategory.stable;
    return TrendCategory.declining;
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

  /// Single-pass comparison with half-open intervals and consistent amount formula.
  void _generateComparisonData() {
    final now = DateTime.now();
    final w = _resolveWindow(widget.scale, widget.basis, now);

    int currentOrders = 0;
    double currentAmount = 0.0;
    int previousOrders = 0;
    double previousAmount = 0.0;

    // Defense-in-depth: the selectors already refuse a window the plan can't
    // cover, but a manifest can change mid-session.
    final cutoff = ReportHistoryWindow.cutoff;

    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) continue;
      if (order.orderAt == null) continue;
      if (cutoff != null && order.orderAt!.isBefore(cutoff)) continue;

      final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);

      if (!order.orderAt!.isBefore(w.currentStart)) {
        currentOrders++;
        currentAmount += netAmount;
      } else if (!order.orderAt!.isBefore(w.previousStart) &&
          order.orderAt!.isBefore(w.previousEnd)) {
        previousOrders++;
        previousAmount += netAmount;
      }
    }

    final ordersGrowth = Growth.between(previousOrders, currentOrders);
    final amountGrowth = Growth.between(previousAmount, currentAmount);

    final currentAOV = currentOrders > 0 ? currentAmount / currentOrders : 0.0;
    final previousAOV = previousOrders > 0 ? previousAmount / previousOrders : 0.0;

    final currentDays = now.difference(w.currentStart).inDays + 1;
    final previousDays = w.previousEnd.difference(w.previousStart).inDays;

    setState(() {
      _data = ComparisonData(
        currentPeriod: w.currentLabel,
        previousPeriod: w.previousLabel,
        currentOrders: currentOrders,
        currentAmount: currentAmount,
        previousOrders: previousOrders,
        previousAmount: previousAmount,
        ordersGrowth: ordersGrowth,
        amountGrowth: amountGrowth,
        currentAOV: currentAOV,
        previousAOV: previousAOV,
        currentOrdersPerDay: currentDays > 0 ? currentOrders / currentDays : 0.0,
        previousOrdersPerDay: previousDays > 0 ? previousOrders / previousDays : 0.0,
        trendCategory: _getTrendCategory(amountGrowth, currentAmount),
      );
      _isLoading = false;
    });
  }

  String get _slug =>
      _pairLabel(_Pair(widget.scale, widget.basis)).toLowerCase().replaceAll(' ', '_');

  Future<void> _exportReport() async {
    if (_data == null || _data!.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }
    final data = _data!;

    final headers = ['Metric', data.previousPeriod, data.currentPeriod, 'Growth %'];

    final dataRows = [
      [
        'Total Orders',
        data.previousOrders.toString(),
        data.currentOrders.toString(),
        data.ordersGrowth.label,
      ],
      [
        'Total Amount',
        ReportExportService.formatCurrency(data.previousAmount),
        ReportExportService.formatCurrency(data.currentAmount),
        data.amountGrowth.label,
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
      'Comparison': '${data.previousPeriod} vs ${data.currentPeriod}',
      'Performance Status': _getTrendLabel(data.trendCategory),
      'Revenue Growth': data.amountGrowth.label,
      'Order Growth': data.ordersGrowth.label,
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'sales_comparison_${_slug}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Sales Comparison - ${data.previousPeriod} vs ${data.currentPeriod}',
      headers: headers,
      data: dataRows,
      summary: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _data == null) return const ReportLoading();

    final data = _data!;

    // Neither window has orders — a table of zeros with a green "Stable" badge
    // reads as real data. Say there is none.
    if (data.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Sales Data',
        message: 'No sales found for this period',
      );
    }

    return ReportBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodCard(data),
          AppResponsive.verticalSpace(context),
          _buildSummaryCards(data),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          _buildPerformanceCard(data),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: _exportReport),
          AppResponsive.verticalSpace(context),
          _buildDataTable(data),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(ComparisonData data) {
    return ReportCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.previousPeriod,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
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
            child: Text(
              data.currentPeriod,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ComparisonData data) {
    final symbol = CurrencyHelper.currentSymbol;
    return Column(
      children: [
        ReportSummaryRow(cards: [
          ReportSummaryCard(
            title: 'Total Orders',
            value: data.currentOrders.toString(),
            subtitle: 'was ${data.previousOrders}',
            footer: _growthBadge(data.ordersGrowth),
            icon: Icons.shopping_cart_outlined,
            color: Colors.blue,
          ),
          ReportSummaryCard(
            title: 'Total Revenue',
            value: '$symbol${DecimalSettings.formatAmount(data.currentAmount)}',
            subtitle: 'was $symbol${DecimalSettings.formatAmount(data.previousAmount)}',
            footer: _growthBadge(data.amountGrowth),
            icon: Icons.monetization_on_outlined,
            color: Colors.green,
          ),
        ]),
        AppResponsive.verticalSpace(context, size: SpacingSize.small),
        ReportSummaryRow(cards: [
          ReportSummaryCard(
            title: 'Avg Order Value',
            value: '$symbol${DecimalSettings.formatAmount(data.currentAOV)}',
            subtitle: 'was $symbol${DecimalSettings.formatAmount(data.previousAOV)}',
            icon: Icons.attach_money,
            color: Colors.orange,
          ),
          ReportSummaryCard(
            title: 'Orders Per Day',
            value: data.currentOrdersPerDay.toStringAsFixed(1),
            subtitle: 'was ${data.previousOrdersPerDay.toStringAsFixed(1)}',
            icon: Icons.calendar_today,
            color: Colors.purple,
          ),
        ]),
      ],
    );
  }

  Widget _buildPerformanceCard(ComparisonData data) {
    final trendColor = _getTrendColor(data.trendCategory);
    return ReportCard(
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
              data.trendCategory == TrendCategory.excellent ||
                      data.trendCategory == TrendCategory.good
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
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTrendLabel(data.trendCategory),
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
    );
  }

  Widget _buildDataTable(ComparisonData data) {
    final symbol = CurrencyHelper.currentSymbol;

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Metric'),
        ReportTable.column(context, data.previousPeriod),
        ReportTable.column(context, data.currentPeriod),
        ReportTable.column(context, 'Growth'),
      ],
      rows: [
        _dataRow('Total Orders', data.previousOrders.toString(),
            data.currentOrders.toString(), data.ordersGrowth),
        _dataRow(
            'Total Amount',
            '$symbol${DecimalSettings.formatAmount(data.previousAmount)}',
            '$symbol${DecimalSettings.formatAmount(data.currentAmount)}',
            data.amountGrowth),
        _dataRow(
            'Avg Order Value',
            '$symbol${DecimalSettings.formatAmount(data.previousAOV)}',
            '$symbol${DecimalSettings.formatAmount(data.currentAOV)}',
            null),
        _dataRow('Orders Per Day', data.previousOrdersPerDay.toStringAsFixed(1),
            data.currentOrdersPerDay.toStringAsFixed(1), null),
      ],
    );
  }

  Widget _growthBadge(Growth growth) {
    final positive = growth.isPositive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${growth.arrow} ${growth.label}',
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: positive ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  DataRow _dataRow(String metric, String previousValue, String currentValue, Growth? growth) {
    final cellFontSize = AppResponsive.smallFontSize(context);
    return DataRow(
      cells: [
        DataCell(Text(metric,
            style: GoogleFonts.poppins(
                fontSize: cellFontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary))),
        DataCell(Text(previousValue,
            style: GoogleFonts.poppins(
                fontSize: cellFontSize, color: AppColors.textPrimary))),
        DataCell(Text(currentValue,
            style: GoogleFonts.poppins(
                fontSize: cellFontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.primary))),
        DataCell(
          growth != null
              ? _growthBadge(growth)
              : Text('-', style: GoogleFonts.poppins(fontSize: cellFontSize, color: Colors.grey)),
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
  final Growth ordersGrowth;
  final Growth amountGrowth;
  final double currentAOV;
  final double previousAOV;
  final double currentOrdersPerDay;
  final double previousOrdersPerDay;
  final TrendCategory trendCategory;

  /// Neither window has a single order.
  bool get isEmpty => currentOrders == 0 && previousOrders == 0;

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
  });
}
