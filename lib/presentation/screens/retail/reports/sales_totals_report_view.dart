import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Body shared by the Daily and Monthly sales reports.
///
/// Both are *point-in-time* reports — one day, one month — rather than range
/// reports, so they keep their own pickers instead of using
/// [ReportPageScaffold]'s period bar. Putting them on that bar would have made
/// "Daily Sales / This Month" and "Monthly Sales" the same screen.
///
/// `getDailySalesReport` and `getMonthlySalesReport` return the same keys, so
/// the entire body is shared and each screen only supplies its picker.
class SalesTotalsReportView extends StatefulWidget {
  final bool isLoading;

  /// Totals map from the service; null while nothing has loaded.
  final Map<String, dynamic>? data;

  /// Variant rows for the same window, from `getVariantWiseSalesReport`.
  ///
  /// The totals above answer "how much sold"; this answers "what sold" — the
  /// report used to give a bare `Items Sold: 42` with no way to see which.
  final List<Map<String, dynamic>> items;

  /// Human label for the selected day/month, used on the export sheet.
  ///
  /// Not rendered on screen: [ReportDateStepBar] above this body already shows
  /// the period, and a hero card repeating it 60px lower was the same fact
  /// twice.
  final String periodLabel;

  final String reportTitle;
  final String exportFileName;

  const SalesTotalsReportView({
    super.key,
    required this.isLoading,
    required this.data,
    this.items = const [],
    required this.periodLabel,
    required this.reportTitle,
    required this.exportFileName,
  });

  @override
  State<SalesTotalsReportView> createState() => _SalesTotalsReportViewState();
}

class _SalesTotalsReportViewState extends State<SalesTotalsReportView> {
  /// A month can sell hundreds of variants, so the breakdown pages like every
  /// other retail table.
  static const int _rowsPerPage = 50;
  int _page = 0;

  @override
  void didUpdateWidget(covariant SalesTotalsReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New period → page 3 of the old list would be out of range.
    if (!identical(oldWidget.items, widget.items)) _page = 0;
  }

  Map<String, dynamic>? get data => widget.data;
  String get periodLabel => widget.periodLabel;

  double _amount(String key) => (data![key] as num?)?.toDouble() ?? 0;
  int _count(String key) => (data![key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const ReportLoading();
    if (data == null) {
      return const ReportEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Nothing loaded',
        message: 'Pick a period to see sales.',
      );
    }

    // An empty day still renders an empty state rather than a blank body —
    // the date bar sits outside this widget, so stepping to another day stays
    // reachable either way.
    final noActivity = _count('totalSales') == 0 && _count('totalReturns') == 0;

    return MoneyScope(
      child: ReportBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noActivity)
              const ReportEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No sales',
                message: 'Nothing was sold in this period.',
              )
            else ...[
              ReportSummaryRow(cards: [
                ReportSummaryCard(
                  title: 'Sales',
                  value: '${_count('totalSales')}',
                  subtitle: '${_count('totalItems')} items',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
                ReportSummaryCard(
                  title: 'Net Revenue',
                  value: formatMoney(_amount('netRevenue')),
                  subtitle: 'after returns',
                  icon: Icons.payments_rounded,
                  color: AppColors.success,
                ),
              ]),
              AppResponsive.verticalSpace(context),
              ReportExportButton(onPressed: () => _export(context)),
              AppResponsive.verticalSpace(context),
              _statsCard(),
              if (widget.items.isNotEmpty) ...[
                AppResponsive.verticalSpace(context),
                _itemsSold(context),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Collapsed by default — the headline numbers are already on the summary
  /// cards above, so this is the detail you open only when you want it, and
  /// keeping it shut puts the items table within reach without scrolling.
  ///
  /// [ExpansionTile] keeps its own open/closed state across rebuilds, so once
  /// opened it stays open while you change the date.
  Widget _statsCard() {
    return ReportCard(
      // Transparent divider: ExpansionTile draws its own top/bottom rules,
      // which double up against the card's edge. Same treatment as
      // `bulk_import_screen`.
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            'Detailed Statistics',
            style: GoogleFonts.poppins(
              // Same weight and size as ReportTable's header cells, so section
              // titles and the table they sit above read as one level.
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            _row('Gross Revenue', formatMoney(_amount('totalRevenue'))),
            _row('Items Sold', '${_count('totalItems')}'),
            _row('Discount', formatMoney(_amount('totalDiscount'))),
            _row('Tax', formatMoney(_amount('totalTax'))),
            _row('Returns', '${_count('totalReturns')}'),
            _row('Return Amount', formatMoney(_amount('totalReturnAmount')),
                color:
                    _amount('totalReturnAmount') > 0 ? AppColors.danger : null),
            const Divider(height: 24, color: AppColors.divider),
            _row('Net Revenue', formatMoney(_amount('netRevenue')),
                highlighted: true),
            _row('Avg Sale Value', formatMoney(_amount('averageSaleValue'))),
          ],
        ),
      ),
    );
  }

  /// What actually sold in the period, one row per variant.
  Widget _itemsSold(BuildContext context) {
    final pageRows =
        ReportPagination.pageSlice(widget.items, _page, _rowsPerPage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
          child: Text(
            'Items Sold',
            style: GoogleFonts.poppins(
              // Same weight and size as ReportTable's header cells, so section
              // titles and the table they sit above read as one level.
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ReportTable(
          showCheckboxColumn: false,
          columns: [
            ReportTable.column(context, 'Item'),
            ReportTable.column(context, 'Qty', numeric: true),
            ReportTable.column(context, 'Revenue', numeric: true),
          ],
          rows: pageRows.map((row) {
            final qty = (row['totalQuantity'] as num).toInt();
            final revenue = (row['totalRevenue'] as num).toDouble();
            // Returns net against sales, so a variant returned more than it
            // sold shows negative — flagged in red rather than looking like a
            // data error.
            final isNegative = qty < 0 || revenue < 0;

            return DataRow(cells: [
              DataCell(Text(_itemLabel(row))),
              DataCell(Text(
                '$qty',
                style: isNegative
                    ? const TextStyle(color: AppColors.danger)
                    : null,
              )),
              DataCell(Text(
                formatMoney(revenue),
                style: isNegative
                    ? const TextStyle(color: AppColors.danger)
                    : null,
              )),
            ]);
          }).toList(),
        ),
        ReportPagination(
          currentPage: _page,
          rowsPerPage: _rowsPerPage,
          totalCount: widget.items.length,
          unit: 'variants',
          onPageChanged: (page) => setState(() => _page = page),
        ),
      ],
    );
  }

  /// "T-Shirt • M / Blue", or just the product when it has no variant
  /// descriptors to show.
  String _itemLabel(Map<String, dynamic> row) {
    final product = (row['productName'] as String?) ?? 'Unknown';
    final variant = (row['variantLabel'] as String?)?.trim() ?? '';
    return variant.isEmpty ? product : '$product • $variant';
  }

  Widget _row(String label, String value,
      {bool highlighted = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
              color:
                  highlighted ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              // Same size as the label; the w600 weight is what separates a
              // value from its name, not half a point of size.
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: color ??
                  (highlighted ? AppColors.success : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// The nine headline figures, as a summary block.
  Map<String, dynamic> get _metrics => {
        'Sales': _count('totalSales'),
        'Items Sold': _count('totalItems'),
        'Gross Revenue':
            ReportExportService.formatCurrency(_amount('totalRevenue')),
        'Discount':
            ReportExportService.formatCurrency(_amount('totalDiscount')),
        'Tax': ReportExportService.formatCurrency(_amount('totalTax')),
        'Returns': _count('totalReturns'),
        'Return Amount':
            ReportExportService.formatCurrency(_amount('totalReturnAmount')),
        'Net Revenue':
            ReportExportService.formatCurrency(_amount('netRevenue')),
        'Avg Sale Value':
            ReportExportService.formatCurrency(_amount('averageSaleValue')),
      };

  Future<void> _export(BuildContext context) async {
    // With a breakdown, the sheet carries the ITEMS as rows and the totals as
    // the summary block — the same shape every scaffold-based retail report
    // exports, and it means what you exported matches what you were looking at.
    // Without one, the metrics stay the rows so the sheet is never empty.
    final hasItems = widget.items.isNotEmpty;

    await ReportExportService.showExportDialog(
      context: context,
      fileName:
          '${widget.exportFileName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: widget.reportTitle,
      headers:
          hasItems ? const ['Item', 'Qty', 'Revenue'] : const ['Metric', 'Value'],
      data: hasItems
          ? widget.items
              .map((row) => [
                    _itemLabel(row),
                    (row['totalQuantity'] as num).toInt(),
                    ReportExportService.formatCurrency(
                        (row['totalRevenue'] as num).toDouble()),
                  ])
              .toList()
          : _metrics.entries.map((e) => [e.key, e.value]).toList(),
      summary: {
        'Report Period': periodLabel,
        if (hasItems) ..._metrics,
        'Generated': ReportExportService.formatDateTime(DateTime.now()),
      },
    );
  }
}
