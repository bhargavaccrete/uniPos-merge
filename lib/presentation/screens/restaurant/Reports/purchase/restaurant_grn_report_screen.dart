import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

import 'purchase_reconciliation_card.dart';

/// Totals for the summary band and the export, derived once.
///
/// Top-level and named so the band and the exported summary are provably the
/// same numbers — a test can call this and compare.
({
  double billed,
  double accepted,
  double damagedValue,
  double acceptedQty,
  double damagedQty,
}) grnReportTotals(List<Map<String, dynamic>> rows) {
  var billed = 0.0;
  var accepted = 0.0;
  var damagedValue = 0.0;
  var acceptedQty = 0.0;
  var damagedQty = 0.0;
  for (final r in rows) {
    billed += (r['billedValue'] as num).toDouble();
    accepted += (r['acceptedValue'] as num).toDouble();
    damagedValue += (r['damagedValue'] as num).toDouble();
    acceptedQty += (r['acceptedQty'] as num).toDouble();
    damagedQty += (r['damagedQty'] as num).toDouble();
  }
  return (
    billed: billed,
    accepted: accepted,
    damagedValue: damagedValue,
    acceptedQty: acceptedQty,
    damagedQty: damagedQty,
  );
}

Map<String, dynamic> grnReportExportSummary(List<Map<String, dynamic>> rows) {
  final t = grnReportTotals(rows);
  return {
    'Receipts': rows.length,
    'Billed Value': ReportExportService.formatCurrency(t.billed),
    'Accepted Value': ReportExportService.formatCurrency(t.accepted),
    'Damaged Value': ReportExportService.formatCurrency(t.damagedValue),
  };
}

/// Every confirmed goods receipt, with ordered / received / accepted / damaged
/// side by side.
///
/// Draft receipts are excluded — they moved no stock and owe no money.
///
/// **Value here is the BILLED value**, `receivedQty * costPrice`, damaged units
/// included. That is what the supplier invoiced and what posted to their
/// ledger; damage is recovered afterwards by a credit note or a settled claim,
/// never by shrinking the original bill.
class RestaurantGRNReportScreen extends StatelessWidget {
  const RestaurantGRNReportScreen({super.key});

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: 'GRN Report',
      subtitle: 'Confirmed goods receipts',
      featureNoun: 'receipts',
      exportFileName: 'restaurant_grn_report',
      rowUnit: 'receipts',
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'No goods received',
      emptyMessage: 'No confirmed receipts in this period.',
      loader: (start, end) =>
          service.getGRNReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final t = grnReportTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Receipts',
            value: '${rows.length}',
            subtitle: '${formatQty(t.acceptedQty)} units accepted',
            icon: Icons.local_shipping_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Billed Value',
            value: formatMoney(t.billed),
            subtitle: 'invoiced, damage included',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Damaged',
            value: formatQty(t.damagedQty),
            subtitle: 'units rejected',
            icon: Icons.report_gmailerrorred_rounded,
            color: t.damagedQty > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ];
      },
      detail: (context, rows) {
        final t = grnReportTotals(rows);
        // Counted from the rows' own flags, so a notice can never disagree
        // with the table it sits above.
        final missing = rows.where((r) => r['amountMissing'] == true).toList();
        final unpriced =
            rows.where((r) => r['hasUnpricedLine'] == true).toList();

        String names(List<Map<String, dynamic>> rs) =>
            rs.map((r) => r['grnNumber']).join(', ');

        return Column(
          children: [
            if (t.damagedValue > 0) ...[
              // Recovery is dated by its own event, so a credit note recorded
              // in another period is not in these rows. The reconciliation
              // therefore shows what this period's receipts cost before any
              // later recovery — Purchase Summary is where the two meet.
              PurchaseReconciliationCard(
                billed: t.billed,
                accepted: t.accepted,
                recovered: 0,
                absorbed: 0,
                unrecovered: t.damagedValue,
              ),
              AppResponsive.verticalSpace(context),
            ],
            if (unpriced.isNotEmpty)
              ReportNotice(
                message: unpriced.length == 1
                    ? 'Receipt ${names(unpriced)} has an item with no cost '
                        'price, so its Billed Value is understated.'
                    : '${unpriced.length} receipts have items with no cost '
                        'price (${names(unpriced)}), so their Billed Value is '
                        'understated.',
              ),
            if (unpriced.isNotEmpty && missing.isNotEmpty)
              AppResponsive.verticalSpace(context),
            // Rare on restaurant data — confirmGRN always writes a header
            // total — so this is really a legacy/restore guard.
            if (missing.isNotEmpty)
              ReportNotice(
                message: missing.length == 1
                    ? 'Receipt ${names(missing)} has no invoice value '
                        'recorded. Its Billed Value shows zero — the '
                        'quantities are still correct.'
                    : '${missing.length} receipts have no invoice value '
                        'recorded (${names(missing)}). Their Billed Value '
                        'shows zero — the quantities are still correct.',
              ),
          ],
        );
      },
      columns: (context) => [
        ReportTable.column(context, 'GRN'),
        ReportTable.column(context, 'PO'),
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Ord', numeric: true),
        ReportTable.column(context, 'Recv', numeric: true),
        ReportTable.column(context, 'Acc', numeric: true),
        ReportTable.column(context, 'Dmg', numeric: true),
        ReportTable.column(context, 'Billed', numeric: true),
      ],
      rowBuilder: (context, row) {
        final damaged = (row['damagedQty'] as num).toDouble();
        return DataRow(
          cells: [
            DataCell(Text(row['grnNumber'] as String)),
            DataCell(Text(row['poNumber'] as String)),
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text(_date(row['receivedDate'] as String))),
            DataCell(Text(formatQty((row['orderedQty'] as num).toDouble()))),
            DataCell(Text(formatQty((row['receivedQty'] as num).toDouble()))),
            DataCell(Text(formatQty((row['acceptedQty'] as num).toDouble()))),
            DataCell(
              Text(
                formatQty(damaged),
                style: GoogleFonts.poppins(
                  color: damaged > 0 ? AppColors.danger : null,
                  fontWeight: damaged > 0 ? FontWeight.w600 : null,
                ),
              ),
            ),
            DataCell(Text(formatMoney((row['billedValue'] as num).toDouble()))),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'GRN Number',
          'PO Number',
          'Supplier',
          'Received Date',
          'Invoice',
          'Ordered',
          'Received',
          'Accepted',
          'Damaged',
          'Billed Value',
          'Accepted Value',
          'Damaged Value',
        ],
        rows: rows
            .map(
              (r) => [
                r['grnNumber'],
                r['poNumber'],
                r['supplierName'],
                _date(r['receivedDate'] as String),
                r['invoiceNumber'] ?? '',
                exportQty((r['orderedQty'] as num).toDouble()),
                exportQty((r['receivedQty'] as num).toDouble()),
                exportQty((r['acceptedQty'] as num).toDouble()),
                exportQty((r['damagedQty'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['billedValue'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['acceptedValue'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['damagedValue'] as num).toDouble()),
              ],
            )
            .toList(),
        summary: grnReportExportSummary(rows),
      ),
    );
  }
}
