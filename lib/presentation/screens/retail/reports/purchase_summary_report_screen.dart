import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

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
            startDate: start, endDate: end);
        if ((data['orderCount'] as int) == 0 &&
            (data['receiptCount'] as int) == 0) {
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
            subtitle: '${d['receivedQty']} units in',
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
            subtitle: 'still expected',
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
          ),
        ];
      },
      detail: (context, rows) => _buildBreakdown(context, rows.first),
      exportData: (rows) {
        final d = rows.first;
        final counts = d['countByStatus'] as Map<String, int>;
        return ReportExportData(
          headers: const ['Metric', 'Value'],
          rows: [
            ['Purchase Orders', d['orderCount']],
            ['Goods Receipts', d['receiptCount']],
            ['Suppliers', d['supplierCount']],
            ['Units Ordered', d['orderedQty']],
            ['Units Received', d['receivedQty']],
            [
              'Ordered Value',
              ReportExportService.formatCurrency(d['orderedValue'] as double)
            ],
            [
              'Received Value',
              ReportExportService.formatCurrency(d['receivedValue'] as double)
            ],
            [
              'Damaged Value',
              ReportExportService.formatCurrency(d['damagedValue'] as double)
            ],
            [
              'Outstanding Value',
              ReportExportService.formatCurrency(
                  d['outstandingValue'] as double)
            ],
            for (final entry in counts.entries)
              ['${_statusLabels[entry.key] ?? entry.key} orders', entry.value],
          ],
        );
      },
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
              _statLine(context, _statusLabels[entry.key] ?? entry.key,
                  '${entry.value}'),
          const Divider(height: 24),
          _statLine(context, 'Goods receipts', '${d['receiptCount']}'),
          _statLine(context, 'Suppliers', '${d['supplierCount']}'),
          _statLine(
            context,
            'Damaged value',
            formatMoney(d['damagedValue'] as double),
            color: (d['damagedValue'] as double) > 0 ? AppColors.danger : null,
          ),
        ],
      ),
    );
  }

  Widget _statLine(BuildContext context, String label, String value,
      {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary),
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
