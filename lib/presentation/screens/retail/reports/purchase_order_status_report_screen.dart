import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

/// Purchase orders in one status, with receiving progress and period totals.
///
/// Backs three menu entries — Pending (`sent`), Partially Received and
/// Completed. One screen rather than three files: the table and totals are
/// identical and only the status differs. The totals band is what a report adds
/// over the PO list screen, which shows records without aggregates.
class PurchaseOrderStatusReportScreen extends StatelessWidget {
  final POStatus status;
  final String title;
  final String subtitle;

  const PurchaseOrderStatusReportScreen({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
  });

  /// POs sent to the supplier with nothing received yet.
  const PurchaseOrderStatusReportScreen.pending({Key? key})
    : this(
        key: key,
        status: POStatus.sent,
        title: 'Pending Purchase Orders',
        subtitle: 'Sent, awaiting delivery',
      );

  const PurchaseOrderStatusReportScreen.partiallyReceived({Key? key})
    : this(
        key: key,
        status: POStatus.partiallyCompleted,
        title: 'Partially Received Orders',
        subtitle: 'Some goods still outstanding',
      );

  const PurchaseOrderStatusReportScreen.completed({Key? key})
    : this(
        key: key,
        status: POStatus.fullyCompleted,
        title: 'Completed Orders',
        subtitle: 'Fully received',
      );

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();
    final showsProgress = status != POStatus.fullyCompleted;

    return ReportPageScaffold(
      title: title,
      subtitle: subtitle,
      featureNoun: 'orders',
      exportFileName: 'po_${status.name}',
      rowUnit: 'orders',
      emptyIcon: Icons.assignment_outlined,
      emptyTitle: 'No ${title.toLowerCase()}',
      emptyMessage: 'Nothing in this status for the selected period.',
      loader: (start, end) => service.getPurchaseOrderStatusReport(
        status,
        startDate: start,
        endDate: end,
      ),
      summaryCards: (rows) {
        final ordered = rows.fold<double>(
          0,
          (s, r) => s + (r['estimatedTotal'] as double),
        );
        final received = rows.fold<double>(
          0,
          (s, r) => s + (r['receivedValue'] as double),
        );
        final remainingQty = rows.fold<int>(
          0,
          (s, r) => s + (r['remainingQty'] as int),
        );

        return [
          ReportSummaryCard(
            title: 'Orders',
            value: '${rows.length}',
            subtitle: subtitle.toLowerCase(),
            icon: Icons.assignment_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: showsProgress ? 'Ordered Value' : 'Received Value',
            value: formatMoney(showsProgress ? ordered : received),
            subtitle: showsProgress ? 'estimated' : 'accepted',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          if (showsProgress)
            ReportSummaryCard(
              title: 'Units Awaited',
              value: '$remainingQty',
              subtitle: 'not yet received',
              icon: Icons.local_shipping_outlined,
              color: AppColors.warning,
            ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'PO'),
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'Expected'),
        ReportTable.column(context, 'Received', numeric: true),
        ReportTable.column(context, 'Value', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['poNumber'] as String)),
          DataCell(Text(row['supplierName'] as String)),
          DataCell(Text(_date(row['expectedDeliveryDate'] as String))),
          DataCell(Text('${row['receivedQty']}/${row['orderedQty']}')),
          DataCell(
            Text(
              formatMoney(
                showsProgress
                    ? row['estimatedTotal'] as double
                    : row['receivedValue'] as double,
              ),
            ),
          ),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'PO Number',
          'Supplier',
          'Created',
          'Expected Delivery',
          'Ordered Qty',
          'Received Qty',
          'Remaining Qty',
          'Estimated Value',
          'Received Value',
        ],
        rows: rows
            .map(
              (r) => [
                r['poNumber'],
                r['supplierName'],
                _date(r['createdAt'] as String),
                _date(r['expectedDeliveryDate'] as String),
                r['orderedQty'],
                r['receivedQty'],
                r['remainingQty'],
                ReportExportService.formatCurrency(
                  r['estimatedTotal'] as double,
                ),
                ReportExportService.formatCurrency(
                  r['receivedValue'] as double,
                ),
              ],
            )
            .toList(),
        summary: {'Orders': rows.length},
      ),
    );
  }
}
