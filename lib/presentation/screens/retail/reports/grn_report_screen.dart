import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

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
        final accepted = rows.fold<int>(
          0,
          (s, r) => s + (r['acceptedQty'] as int),
        );
        final damaged = rows.fold<int>(
          0,
          (s, r) => s + (r['damagedQty'] as int),
        );

        return [
          ReportSummaryCard(
            title: 'Receipts',
            value: '${rows.length}',
            subtitle: '$accepted units accepted',
            icon: Icons.local_shipping_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Value',
            value: formatMoney(value),
            subtitle: 'accepted goods',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Damaged',
            value: '$damaged',
            subtitle: 'units rejected',
            icon: Icons.report_gmailerrorred_rounded,
            color: damaged > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ];
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
        final damaged = row['damagedQty'] as int;
        return DataRow(
          cells: [
            DataCell(Text(row['grnNumber'] as String)),
            DataCell(Text(row['poNumber'] as String)),
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text(_date(row['receivedDate'] as String))),
            DataCell(Text('${row['orderedQty']}')),
            DataCell(Text('${row['receivedQty']}')),
            DataCell(Text('${row['acceptedQty']}')),
            DataCell(
              Text(
                '$damaged',
                style: TextStyle(
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
                r['orderedQty'],
                r['receivedQty'],
                r['acceptedQty'],
                r['damagedQty'],
                ReportExportService.formatCurrency(r['totalAmount'] as double),
              ],
            )
            .toList(),
        summary: {
          'Receipts': rows.length,
          'Accepted Value': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['totalAmount'] as double)),
          ),
        },
      ),
    );
  }
}
