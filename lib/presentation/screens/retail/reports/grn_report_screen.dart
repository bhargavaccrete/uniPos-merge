import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Every confirmed goods receipt, with ordered / received / accepted / damaged
/// side by side.
///
/// Draft GRNs are excluded — they have moved no stock and owe no money.
class GRNReportScreen extends StatelessWidget {
  const GRNReportScreen({super.key});

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'GRN Report',
      subtitle: 'Confirmed goods receipts',
      featureNoun: 'receipts',
      exportFileName: 'grn_report',
      rowUnit: 'receipts',
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'No goods received',
      emptyMessage: 'No confirmed receipts in this period.',
      loader: (start, end) =>
          service.getGRNReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final value = rows.fold<double>(
          0,
          (s, r) => s + (r['totalAmount'] as double),
        );
        // Doubles — goods are received by weight. Reading them back `as int`
        // threw on every GRN that had items, i.e. every real receipt.
        final accepted = rows.fold<double>(
          0,
          (s, r) => s + (r['acceptedQty'] as num).toDouble(),
        );
        final damaged = rows.fold<double>(
          0,
          (s, r) => s + (r['damagedQty'] as num).toDouble(),
        );

        return [
          ReportSummaryCard(
            title: 'Receipts',
            value: '${rows.length}',
            subtitle: '${formatQty(accepted)} units accepted',
            icon: Icons.local_shipping_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Value',
            value: formatMoney(value),
            // `totalAmount` is `receivedQty * costPrice` — damaged units are
            // billed too, so this is NOT an accepted-goods figure.
            subtitle: 'invoiced, damage included',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Damaged',
            value: formatQty(damaged),
            subtitle: 'units rejected',
            icon: Icons.report_gmailerrorred_rounded,
            color: damaged > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ];
      },
      // Counted from the rows' own flag rather than a separate figure, so the
      // notice can never disagree with the table it sits above.
      detail: (context, rows) {
        final missing = rows.where((r) => r['amountMissing'] == true).toList();
        final unpriced = rows
            .where((r) => r['hasUnpricedLine'] == true)
            .toList();
        if (missing.isEmpty && unpriced.isEmpty) {
          return const SizedBox.shrink();
        }

        String names(List<Map<String, dynamic>> rs) =>
            rs.map((r) => r['grnNumber']).join(', ');

        return Column(
          children: [
            if (missing.isNotEmpty)
              ReportNotice(
                message: missing.length == 1
                    ? 'Receipt ${names(missing)} has no invoice value recorded.'
                          ' Its Value shows ₹0 — the quantities are still correct.'
                    : '${missing.length} receipts have no invoice value '
                          'recorded (${names(missing)}). Their Value shows ₹0 — '
                          'the quantities are still correct.',
              ),
            if (missing.isNotEmpty && unpriced.isNotEmpty)
              AppResponsive.verticalSpace(context),
            if (unpriced.isNotEmpty)
              ReportNotice(
                message: unpriced.length == 1
                    ? 'Receipt ${names(unpriced)} has an item with no cost '
                          'price, so its Value is understated.'
                    : '${unpriced.length} receipts have items with no cost '
                          'price (${names(unpriced)}), so their Value is '
                          'understated.',
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
        ReportTable.column(context, 'Value', numeric: true),
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
            DataCell(Text(formatMoney(row['totalAmount'] as double))),
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
          'Value',
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
                ReportExportService.formatCurrency(r['totalAmount'] as double),
              ],
            )
            .toList(),
        summary: {
          'Receipts': rows.length,
          'Received Value': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['totalAmount'] as double)),
          ),
        },
      ),
    );
  }
}
