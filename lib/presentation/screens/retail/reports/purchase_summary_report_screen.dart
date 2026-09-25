import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Headline purchasing numbers: ordered vs actually received, and what it cost.
///
/// Summary-only — no table, so the scaffold's `columns`/`rowBuilder` are left
/// null and the status breakdown goes in `detail`.
class PurchaseSummaryReportScreen extends StatelessWidget {
  const PurchaseSummaryReportScreen({super.key});

  static const _statusLabels = {
    'draft': 'Draft',
    'sent': 'Sent',
    'partiallyCompleted': 'Partially Received',
    'fullyCompleted': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Purchase Summary',
      subtitle: 'Ordered vs received',
      featureNoun: 'purchases',
      exportFileName: 'purchase_summary',
      emptyIcon: Icons.assessment_outlined,
      emptyTitle: 'No purchasing activity',
      emptyMessage: 'No purchase orders or goods receipts in this period.',
      // The service returns one Map; the scaffold works in rows, so it travels
      // as a single-row list and everything below reads rows.first.
      loader: (start, end) async {
        final data = await service.getPurchaseSummaryReport(
          startDate: start,
          endDate: end,
        );
        // `orderCount` deliberately excludes draft and cancelled orders, so
        // testing it alone declared "no purchase activity" for a period that
        // held nothing but drafts — and hid the very status breakdown that
        // exists to account for them. `countByStatus` covers all five statuses,
        // so it subsumes `orderCount`.
        final counts = data['countByStatus'] as Map<String, int>;
        final hasOrders = counts.values.any((c) => c > 0);
        if (!hasOrders && (data['receiptCount'] as int) == 0) {
          return [];
        }
        return [data];
      },
      summaryCards: (rows) {
        final d = rows.first;
        return [
          ReportSummaryCard(
            title: 'Received',
            value: formatMoney(d['receivedValue'] as double),
            // A double: goods can be received by weight. Raw interpolation
            // printed 12 units as "12.0".
            subtitle:
                '${formatQty((d['receivedQty'] as num).toDouble())} units in',
            icon: Icons.inventory_2_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Ordered',
            value: formatMoney(d['orderedValue'] as double),
            subtitle: '${d['orderCount']} orders',
            icon: Icons.assignment_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Outstanding',
            value: formatMoney(d['outstandingValue'] as double),
            // Not recovery: this is PO value not yet delivered. "Still
            // expected" collided with the Expected recovery row below.
            subtitle: 'undelivered on open POs',
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
          ),
        ];
      },
      detail: (context, rows) => _buildDetail(context, rows.first),
      exportData: (rows) {
        final d = rows.first;
        final counts = d['countByStatus'] as Map<String, int>;
        return ReportExportData(
          headers: const ['Metric', 'Value'],
          rows: [
            ['Purchase Orders', d['orderCount']],
            ['Goods Receipts', d['receiptCount']],
            ['Suppliers', d['supplierCount']],
            ['Units Ordered', exportQty((d['orderedQty'] as num).toDouble())],
            ['Units Received', exportQty((d['receivedQty'] as num).toDouble())],
            [
              'Ordered Value',
              ReportExportService.formatCurrency(d['orderedValue'] as double),
            ],
            [
              'Received Value',
              ReportExportService.formatCurrency(d['receivedValue'] as double),
            ],
            [
              'Expected Recovery',
              ReportExportService.formatCurrency(
                d['damagedExpected'] as double,
              ),
            ],
            [
              'Recovered',
              ReportExportService.formatCurrency(
                d['damagedRecovered'] as double,
              ),
            ],
            [
              'Damaged Absorbed',
              ReportExportService.formatCurrency(
                d['damagedAbsorbed'] as double,
              ),
            ],
            [
              'Outstanding Value',
              ReportExportService.formatCurrency(
                d['outstandingValue'] as double,
              ),
            ],
            for (final entry in counts.entries)
              ['${_statusLabels[entry.key] ?? entry.key} orders', entry.value],
          ],
        );
      },
    );
  }

  /// The breakdown, preceded by a data-quality notice when any receipt in the
  /// period has no recorded invoice value.
  Widget _buildDetail(BuildContext context, Map<String, dynamic> d) {
    final missing = d['grnsMissingAmount'] as int? ?? 0;
    final unpriced = d['grnsWithUnpricedLines'] as int? ?? 0;
    if (missing == 0 && unpriced == 0) return _buildBreakdown(context, d);

    return Column(
      children: [
        if (missing > 0) ...[
          ReportNotice(
            message: missing == 1
                ? '1 goods receipt in this period has no invoice value '
                      'recorded. It is counted at ₹0 here — its quantities are '
                      'still included.'
                : '$missing goods receipts in this period have no invoice '
                      'value recorded. They are counted at ₹0 here — their '
                      'quantities are still included.',
          ),
          AppResponsive.verticalSpace(context),
        ],
        if (unpriced > 0) ...[
          ReportNotice(
            message: unpriced == 1
                ? '1 goods receipt has an item with no cost price. Its value, '
                      'and any return or claim raised from it, is understated.'
                : '$unpriced goods receipts have items with no cost price. '
                      'Their value, and any returns or claims raised from them, '
                      'is understated.',
          ),
          AppResponsive.verticalSpace(context),
        ],
        _buildBreakdown(context, d),
      ],
    );
  }

  Widget _buildBreakdown(BuildContext context, Map<String, dynamic> d) {
    final counts = d['countByStatus'] as Map<String, int>;

    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orders by Status',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          for (final entry in counts.entries)
            if (entry.value > 0)
              _statLine(
                context,
                _statusLabels[entry.key] ?? entry.key,
                '${entry.value}',
              ),
          const Divider(height: 24),
          _statLine(context, 'Goods receipts', '${d['receiptCount']}'),
          _statLine(context, 'Suppliers', '${d['supplierCount']}'),
          // Three outcomes, never one number: value the supplier still owes,
          // value actually credited, and value the business keeps. Each is
          // dated by its own event, so a receipt from an earlier period can be
          // recovered in this one.
          _statLine(
            context,
            'Expected recovery',
            formatMoney(d['damagedExpected'] as double),
          ),
          _statLine(
            context,
            'Recovered',
            formatMoney(d['damagedRecovered'] as double),
          ),
          _statLine(
            context,
            'Absorbed (written off)',
            formatMoney(d['damagedAbsorbed'] as double),
            color: (d['damagedAbsorbed'] as double) > 0
                ? AppColors.danger
                : null,
          ),
        ],
      ),
    );
  }

  Widget _statLine(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
