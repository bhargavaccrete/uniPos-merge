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
import 'package:billberrylite/util/common/quantity_format.dart';

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

  /// Only for genuine integer counts — bills and credit notes. Quantities go
  /// through [_qty]: they are `double` so loose goods can be sold by weight,
  /// and `.toInt()` reported a 2.5 kg day as "2".
  int _count(String key) => (data![key] as num?)?.toInt() ?? 0;

  double _qtyValue(String key) => (data![key] as num?)?.toDouble() ?? 0;

  String _qty(String key) => formatQty(_qtyValue(key));

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

    // Returned BEFORE ReportBody, like the branch above it. Inside a
    // SingleChildScrollView a `Center` has no bounded height to centre against,
    // so the empty state sat top-aligned here while every other report centred
    // it. Handing it straight to the parent's Expanded restores that.
    if (noActivity) {
      return const ReportEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No sales',
        message: 'Nothing was sold in this period.',
      );
    }

    return MoneyScope(
      child: ReportBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_count('skippedRows') > 0) ...[
              _skippedNotice(context),
              AppResponsive.verticalSpace(context),
            ],
            ReportSummaryRow(
              cards: [
                ReportSummaryCard(
                  title: 'Sales',
                  value: '${_count('totalSales')}',
                  // Net of returns, so it agrees with the Items Sold table
                  // below rather than contradicting it.
                  subtitle: '${_qty('totalItems')} items',
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
              ],
            ),
            AppResponsive.verticalSpace(context),
            ReportExportButton(onPressed: () => _export(context)),
            AppResponsive.verticalSpace(context),
            _statsCard(),
            if (widget.items.isNotEmpty) ...[
              AppResponsive.verticalSpace(context),
              _itemsSold(context),
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
            // ── Gross block ────────────────────────────────────────────
            // Ends in its own total under a rule, so the sum is visible:
            // Taxable Value + Tax + Round Off = Gross Revenue. Holds in both
            // tax modes because Taxable Value is derived as the residual.
            _blockLabel('Sales (before returns)'),
            _row('Items Sold', _qty('grossItems')),
            _row('Discount Given', formatMoney(_amount('totalDiscount'))),
            _row('Taxable Value', formatMoney(_amount('totalTaxable'))),
            _row('Tax', formatMoney(_amount('totalTax'))),
            // Only when it moved the total — a zero row on every bill-rounded
            // store would be noise.
            if (_amount('totalRoundOff') != 0)
              _row('Round Off', formatMoney(_amount('totalRoundOff'))),
            const Divider(height: 20, color: AppColors.divider),
            _row(
              'Gross Revenue',
              formatMoney(_amount('totalRevenue')),
              highlighted: true,
            ),

            // ── Returns, and the net position they produce ─────────────
            // Hidden entirely on a day with no refund: Net Revenue would just
            // repeat Gross Revenue, and Net Tax would repeat Tax.
            if (hasReturns) ...[
              AppResponsive.verticalSpace(context),
              _blockLabel('Returns'),
              _row('Returns', '${_count('totalReturns')}'),
              _row('Items Returned', _qty('returnedItems')),
              _row(
                'Return Amount',
                '-${formatMoney(_amount('totalReturnAmount'))}',
                color: AppColors.danger,
              ),
              AppResponsive.verticalSpace(context),
              _blockLabel('After returns'),
              const Divider(height: 20, color: AppColors.divider),
              _row(
                'Net Revenue',
                formatMoney(_amount('netRevenue')),
                highlighted: true,
                // The second identity, stated rather than left to be inferred.
                caption: 'Gross Revenue − Return Amount',
              ),
              _row('Net Tax', formatMoney(_amount('netTax'))),
            ],

            // Outside every block: gross revenue over bills rung up. Neither
            // figure counts returns, so it belongs to neither the gross nor
            // the net column.
            AppResponsive.verticalSpace(context),
            _row('Avg Bill Value', formatMoney(_amount('averageSaleValue'))),
          ],
        ),
      ),
    );
  }

  bool get hasReturns => _count('totalReturns') > 0;

  /// Sales the window had to drop because their stored date could not be read.
  ///
  /// Counted by the service since it was written; nothing rendered it, so the
  /// loss it exists to expose stayed invisible.
  Widget _skippedNotice(BuildContext context) {
    final n = _count('skippedRows');

    return ReportCard(
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: AppResponsive.iconSize(context),
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$n ${n == 1 ? 'sale' : 'sales'} skipped — unreadable date. '
              'Not included in any figure below.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context) - 1,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// What actually sold in the period, one row per variant.
  Widget _itemsSold(BuildContext context) {
    final pageRows = ReportPagination.pageSlice(
      widget.items,
      _page,
      _rowsPerPage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
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
            final qty = (row['totalQuantity'] as num).toDouble();
            final revenue = (row['totalRevenue'] as num).toDouble();
            // Returns net against sales, so a variant returned more than it
            // sold shows negative — flagged in red rather than looking like a
            // data error.
            final isNegative = qty < 0 || revenue < 0;

            return DataRow(
              cells: [
                DataCell(Text(_itemLabel(row))),
                DataCell(
                  Text(
                    formatQty(qty),
                    style: isNegative
                        ? GoogleFonts.poppins(color: AppColors.danger)
                        : null,
                  ),
                ),
                DataCell(
                  Text(
                    formatMoney(revenue),
                    style: isNegative
                        ? GoogleFonts.poppins(color: AppColors.danger)
                        : null,
                  ),
                ),
              ],
            );
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

  Widget _row(
    String label,
    String value, {
    bool highlighted = false,
    Color? color,
    String? caption,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                  color: highlighted
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              if (caption != null)
                Text(
                  caption,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context) - 2,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              // Same size as the label; the w600 weight is what separates a
              // value from its name, not half a point of size.
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color:
                  color ??
                  (highlighted ? AppColors.success : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// The headline figures, in the order the screen shows them.
  ///
  /// Both exporters render `summary` as a flat label/value list with no section
  /// headings (`report_export_service.dart:106` and `:191`), preserving
  /// insertion order — so the blocks live in the labels themselves, and the
  /// conditional rows drop out exactly as they do on screen.
  ///
  /// Every value comes from the same `data` map the card reads. Nothing is
  /// recomputed here, so an export cannot disagree with what was on screen.
  Map<String, dynamic> get _metrics => {
    'Sales': _count('totalSales'),
    'Items Sold': _qty('grossItems'),
    'Discount Given': ReportExportService.formatCurrency(
      _amount('totalDiscount'),
    ),
    'Taxable Value': ReportExportService.formatCurrency(
      _amount('totalTaxable'),
    ),
    'Tax': ReportExportService.formatCurrency(_amount('totalTax')),
    if (_amount('totalRoundOff') != 0)
      'Round Off': ReportExportService.formatCurrency(_amount('totalRoundOff')),
    'Gross Revenue': ReportExportService.formatCurrency(
      _amount('totalRevenue'),
    ),
    if (hasReturns) ...{
      'Returns': _count('totalReturns'),
      'Items Returned': _qty('returnedItems'),
      'Return Amount':
          '-${ReportExportService.formatCurrency(_amount('totalReturnAmount'))}',
      'Net Revenue': ReportExportService.formatCurrency(_amount('netRevenue')),
      'Net Tax': ReportExportService.formatCurrency(_amount('netTax')),
    },
    'Avg Bill Value': ReportExportService.formatCurrency(
      _amount('averageSaleValue'),
    ),
    if (_count('skippedRows') > 0) 'Skipped Rows': _count('skippedRows'),
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
      headers: hasItems
          ? const ['Item', 'Qty', 'Revenue']
          : const ['Metric', 'Value'],
      data: hasItems
          ? widget.items
                .map(
                  (row) => [
                    _itemLabel(row),
                    // Same helper the four line-level sales reports use, so a
                    // quantity exports identically from every sales report:
                    // still a `num`, so Excel keeps a real numeric cell
                    // (`report_export_service.dart:229`), but integral when the
                    // value is whole, so the PDF prints "3" rather than "3.0"
                    // (`:464` stringifies the cell).
                    exportQty((row['totalQuantity'] as num).toDouble()),
                    ReportExportService.formatCurrency(
                      (row['totalRevenue'] as num).toDouble(),
                    ),
                  ],
                )
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
