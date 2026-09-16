import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/eod_history_export.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/presentation/screens/retail/eod_report_detail_screen.dart';

/// EOD Reports List Screen - Shows all saved EOD reports
class EODReportsListScreen extends StatefulWidget {
  const EODReportsListScreen({super.key});

  @override
  State<EODReportsListScreen> createState() => _EODReportsListScreenState();
}

class _EODReportsListScreenState extends State<EODReportsListScreen> {
  /// Every retail close, loaded once. The period filter narrows this in memory
  /// rather than re-querying — a close list is small and already sorted.
  List<EndOfDayReport> _allReports = [];
  bool _isLoading = true;

  /// Set when the load itself failed. Kept apart from "no reports" because an
  /// empty list used to render the SUCCESS state ("No EOD Reports Yet") behind
  /// a red toast — a failure was indistinguishable from a quiet shop.
  String? _error;

  /// `null` = all time, which is what this screen has always shown.
  ReportPeriod? _period;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  /// The closes the period covers. Bounds come from the shared report kit, so
  /// "This Month" means here exactly what it means on every other report —
  /// inclusive start, EXCLUSIVE end.
  List<EndOfDayReport> get _visibleReports {
    final period = _period;
    if (period == null) return _allReports;
    final now = DateTime.now();
    final start = reportPeriodStartBound(period, now);
    final end = reportPeriodEndBound(period, now);
    return _allReports
        .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
        .toList();
  }

  String get _periodLabel => _period?.label ?? 'All time';

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final allReports = await EODService.getAllEODReports();
      // Retail closes only: `mode` is null on legacy records, and null means
      // RESTAURANT (`EndOfDayReport.mode`, "nullable for backward
      // compatibility"). So an exact match on 'retail' is correct — do not
      // widen this to include nulls, or restaurant closes appear here.
      final retailReports = allReports.where((report) {
        return report.mode == 'retail';
      }).toList();

      if (!mounted) return;
      setState(() {
        _allReports = retailReports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _export() async {
    final export = EodHistoryExport.list(
      reports: _visibleReports,
      period: _periodLabel,
    );
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'eod_history',
      reportTitle: 'End of Day History',
      headers: export.headers,
      data: export.rows,
      summary: export.summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'EOD Reports',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadReports,
          ),
        ],
      ),
      // Every amount here goes through formatMoney; MoneyScope is the single
      // subscription that re-renders them when the store's currency or decimal
      // precision changes. These two screens were the last holdouts still
      // hard-coding the symbol and two decimals.
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxContentWidth(context),
          child: Column(
            children: [
              // The shared period bar, so "This Month" means here what it means
              // on every other retail report. `null` is All time, which is what
              // this screen has always shown.
              ReportFilterBar<ReportPeriod?>(
                selected: _period,
                onSelected: (value) => setState(() => _period = value),
                options: [
                  const ReportFilterOption<ReportPeriod?>(
                    value: null,
                    label: 'All',
                    icon: Icons.all_inclusive,
                  ),
                  for (final period in const [
                    ReportPeriod.today,
                    ReportPeriod.thisWeek,
                    ReportPeriod.thisMonth,
                    ReportPeriod.thisYear,
                  ])
                    ReportFilterOption<ReportPeriod?>(
                      value: period,
                      label: period.label,
                      icon: period.icon,
                    ),
                ],
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const ReportLoading();

    // A FAILED load is not an empty shop. This used to fall through to the
    // success state below, so the screen cheerfully announced "No EOD Reports
    // Yet" over a load that had thrown.
    if (_error != null) {
      return _buildMessage(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        title: 'Could not load reports',
        message: _error!,
        action: TextButton.icon(
          onPressed: _loadReports,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    final reports = _visibleReports;
    if (reports.isEmpty) {
      // Two different empty states: nothing has ever been closed, versus
      // nothing was closed in the period the user picked.
      return _period == null
          ? _buildMessage(
              icon: Icons.receipt_long,
              iconColor: Colors.grey[300]!,
              title: 'No EOD Reports Yet',
              message: 'Complete your first End of Day to see reports here',
            )
          : _buildMessage(
              icon: Icons.event_busy,
              iconColor: Colors.grey[300]!,
              title: 'No closes in this period',
              message: 'Nothing was closed during $_periodLabel.',
            );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppResponsive.cardPadding(context).left,
            AppResponsive.largeSpacing(context),
            AppResponsive.cardPadding(context).left,
            0,
          ),
          child: ReportExportButton(onPressed: _export),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReports,
            child: ListView.builder(
              padding: AppResponsive.cardPadding(context),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return _buildReportCard(reports[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: iconColor),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: Colors.grey[500],
              ),
            ),
            if (action != null) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(EndOfDayReport report) {
    // Date AND time: two closes on one day used to render as identical cards.
    final dateFormat = DateFormat('dd MMM yyyy, EEEE');
    final timeFormat = DateFormat('hh:mm a');
    final sessionId = report.sessionId;
    final isBalanced =
        report.cashReconciliation.reconciliationStatus == 'Balanced';
    final isOverage =
        report.cashReconciliation.reconciliationStatus == 'Overage';

    return Card(
      // Explicit white + no surface tint. Material 3 tints a Card's
      // default surface by elevation, and main.dart sets no colorScheme,
      // so an untinted Card picked up M3's default lavender at
      // elevation 2 while every neighbouring surface stayed white.
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EODReportDetailScreen(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        child: Padding(
          padding: AppResponsive.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: AppResponsive.smallIconSize(context),
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFormat.format(report.date),
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            // Retail carries no sessionId (the model documents
                            // null = retail/legacy), so the TIME is what tells
                            // two closes on one date apart. The session is
                            // shown as well whenever a record has one.
                            sessionId == null || sessionId.isEmpty
                                ? timeFormat.format(report.date)
                                : '${timeFormat.format(report.date)} · '
                                      'Session ${shortRef(sessionId)}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isBalanced
                          ? Colors.green[50]
                          : isOverage
                          ? Colors.blue[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context),
                      ),
                    ),
                    child: Text(
                      report.cashReconciliation.reconciliationStatus,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: isBalanced
                            ? Colors.green[700]
                            : isOverage
                            ? Colors.blue[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppResponsive.mediumSpacing(context)),
              const Divider(height: 1),
              SizedBox(height: AppResponsive.mediumSpacing(context)),

              // Sales Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn(
                    'Total Sales',
                    formatMoney(report.totalSales),
                    Colors.green,
                  ),
                  _buildStatColumn(
                    'Transactions',
                    '${report.totalOrderCount}',
                    Colors.blue,
                  ),
                ],
              ),

              SizedBox(height: AppResponsive.mediumSpacing(context)),

              // Cash Reconciliation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn(
                    'Expected Cash',
                    formatMoney(report.cashReconciliation.systemExpectedCash),
                    Colors.orange,
                  ),
                  _buildStatColumn(
                    'Actual Cash',
                    formatMoney(report.cashReconciliation.actualCash),
                    Colors.teal,
                  ),
                ],
              ),

              // The SAME tolerance that decided the status. `!= 0` drew an
              // amber banner reading "Difference: ₹0.00" over a residual of
              // 1e-13.
              if (report.cashReconciliation.difference.abs() >=
                  kCashReconciliationTolerance) ...[
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: isBalanced
                        ? Colors.green[50]
                        : isOverage
                        ? Colors.blue[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOverage ? Icons.arrow_upward : Icons.arrow_downward,
                        size: AppResponsive.smallIconSize(context),
                        color: isOverage
                            ? Colors.blue[700]
                            : Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Difference: ${formatMoney(report.cashReconciliation.difference.abs())}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: isOverage
                              ? Colors.blue[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: AppResponsive.mediumSpacing(context)),

              // View Details Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EODReportDetailScreen(report: report),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      'View Details',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
