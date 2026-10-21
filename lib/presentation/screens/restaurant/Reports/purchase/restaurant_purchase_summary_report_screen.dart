import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

import 'purchase_reconciliation_card.dart';

/// Human labels for `RestaurantPOStatus`.
///
/// Keyed on the **restaurant** enum names. Retail's `partiallyCompleted` /
/// `fullyCompleted` would render as raw enum text here.
const Map<String, String> _statusLabels = {
  'draft': 'Draft',
  'sent': 'Sent',
  'partiallyReceived': 'Partially Received',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};

Map<String, dynamic> purchaseSummaryExportSummary(Map<String, dynamic> d) {
  String money(String key) =>
      ReportExportService.formatCurrency((d[key] as num).toDouble());
  return {
    'Orders': d['orderCount'],
    'Receipts': d['receiptCount'],
    'Ordered Value': money('orderedValue'),
    'Outstanding Value': money('outstandingValue'),
    'Billed Value': money('billedValue'),
    'Accepted Value': money('acceptedValue'),
    'Damaged Value': money('damagedValue'),
    'Damage Expected': money('damagedExpected'),
    'Damage Recovered': money('damagedRecovered'),
    'Damage Absorbed': money('damagedAbsorbed'),
    'Damage Unrecovered': money('damagedUnrecovered'),
    'Net Cost': money('netCost'),
    'Suppliers': d['supplierCount'],
  };
}

/// What was ordered, what arrived, what it actually cost.
///
/// A summary-only report — there is no row-per-thing to show, so `columns` is
/// null and everything lives in the cards and the detail panel.
class RestaurantPurchaseSummaryReportScreen extends StatelessWidget {
  const RestaurantPurchaseSummaryReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: 'Purchase Summary',
      subtitle: 'Ordered vs received, and what it cost',
      featureNoun: 'purchases',
      exportFileName: 'restaurant_purchase_summary',
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
        // countByStatus covers all five statuses, so a period holding nothing
        // but drafts still counts as activity — and still shows the status
        // breakdown that exists to account for them.
        final counts = data['countByStatus'] as Map<String, int>;
        final hasOrders = counts.values.any((c) => c > 0);
        if (!hasOrders && (data['receiptCount'] as int) == 0) return [];
        return [data];
      },
      // Summary-only: no table.
      columns: null,
      summaryCards: (rows) {
        final d = rows.first;
        double money(String k) => (d[k] as num).toDouble();
        return [
          ReportSummaryCard(
            title: 'Received',
            value: formatMoney(money('billedValue')),
            subtitle: '${formatQty(money('receivedQty'))} units in',
            icon: Icons.local_shipping_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Ordered',
            value: formatMoney(money('orderedValue')),
            subtitle: '${d['orderCount']} orders',
            icon: Icons.assignment_outlined,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Outstanding',
            value: formatMoney(money('outstandingValue')),
            subtitle: 'undelivered on open orders',
            icon: Icons.pending_actions_rounded,
            color: AppColors.warning,
          ),
        ];
      },
      detail: (context, rows) {
        final d = rows.first;
        double money(String k) => (d[k] as num).toDouble();
        final counts = d['countByStatus'] as Map<String, int>;
        final missing = d['grnsMissingAmount'] as int;
        final unpriced = d['grnsWithUnpricedLines'] as int;

        return Column(
          children: [
            PurchaseReconciliationCard(
              billed: money('billedValue'),
              accepted: money('acceptedValue'),
              recovered: money('damagedRecovered'),
              absorbed: money('damagedAbsorbed'),
              unrecovered: money('damagedUnrecovered'),
              expected: money('damagedExpected'),
            ),
            AppResponsive.verticalSpace(context),
            ReportCard(
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
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  // Folded from the enum, so a new status can never be
                  // silently dropped from this list.
                  for (final s in RestaurantPOStatus.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _statusLabels[s.name] ?? s.name,
                              style: GoogleFonts.poppins(
                                fontSize:
                                    AppResponsive.smallFontSize(context),
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${counts[s.name] ?? 0}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 18, color: AppColors.divider),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Suppliers delivered from',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${d['supplierCount']}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (unpriced > 0) ...[
              AppResponsive.verticalSpace(context),
              ReportNotice(
                message: '$unpriced receipt${unpriced == 1 ? '' : 's'} '
                    'had items with no cost price, so Billed Value is '
                    'understated.',
              ),
            ],
            if (missing > 0) ...[
              AppResponsive.verticalSpace(context),
              ReportNotice(
                message: '$missing receipt${missing == 1 ? '' : 's'} had no '
                    'invoice value recorded. Quantities are still correct.',
              ),
            ],
          ],
        );
      },
      exportData: (rows) {
        final summary = purchaseSummaryExportSummary(rows.first);
        return ReportExportData(
          headers: const ['Metric', 'Value'],
          rows: summary.entries.map((e) => [e.key, e.value]).toList(),
          summary: summary,
        );
      },
    );
  }
}
