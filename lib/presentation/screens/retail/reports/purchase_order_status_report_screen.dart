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
import 'package:billberrylite/util/common/quantity_format.dart';

/// Purchase orders in one status, with receiving progress and period totals.
///
/// Backs three menu entries — Pending (`sent`), Partially Received and
/// Completed. One screen rather than three files: the table and totals are
/// identical and only the status differs. The totals band is what a report adds
/// over the PO list screen, which shows records without aggregates.
/// The period totals, computed ONCE from the loaded rows.
///
/// Both the summary band and the export summary read this, so the export can
/// never carry a different figure from the screen — it used to publish only the
/// order count and omit both value figures and the awaited units.
typedef POStatusTotals = ({
  double ordered,
  double received,
  double remainingQty,
});

POStatusTotals poStatusTotals(List<Map<String, dynamic>> rows) {
  double sum(String key) =>
      rows.fold<double>(0, (s, r) => s + (r[key] as num).toDouble());
  return (
    ordered: sum('estimatedTotal'),
    received: sum('receivedValue'),
    remainingQty: sum('remainingQty'),
  );
}

/// The export summary, built from the SAME totals the summary band shows.
///
/// A named function rather than an inline map so the parity is testable: the
/// export used to publish only the order count, omitting both the value figure
/// and the awaited units that the cards display.
///
/// [showsProgress] mirrors the screen exactly — Pending and Partially Received
/// report ORDERED value and units still awaited, Completed reports the value
/// actually invoiced and has nothing left to await.
Map<String, dynamic> poStatusExportSummary(
  List<Map<String, dynamic>> rows,
  bool showsProgress,
) {
  final t = poStatusTotals(rows);
  return {
    'Orders': rows.length,
    if (showsProgress)
      'Ordered Value': ReportExportService.formatCurrency(t.ordered)
    else
      'Received Value': ReportExportService.formatCurrency(t.received),
    if (showsProgress) 'Units Awaited': formatQty(t.remainingQty),
  };
}

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
        // Quantities are doubles — goods are ordered and received by weight.
        final t = poStatusTotals(rows);

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
            value: formatMoney(showsProgress ? t.ordered : t.received),
            subtitle: showsProgress ? 'estimated' : 'invoiced, damage included',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          if (showsProgress)
            ReportSummaryCard(
              title: 'Units Awaited',
              value: formatQty(t.remainingQty),
              subtitle: 'not yet received',
              icon: Icons.local_shipping_outlined,
              color: AppColors.warning,
            ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'PO'),
        ReportTable.column(context, 'Supplier'),
        // A delivery DATE. Supplier-wise uses 'Expected' for recovery
        // money, so this one says what it is. Matches the export header.
        ReportTable.column(context, 'Expected Delivery'),
        ReportTable.column(context, 'Received', numeric: true),
        ReportTable.column(context, 'Value', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['poNumber'] as String)),
          DataCell(Text(row['supplierName'] as String)),
          DataCell(Text(_date(row['expectedDeliveryDate'] as String))),
          // Both are doubles: raw interpolation rendered 4 of 10 as "4.0/10.0".
          DataCell(
            Text(
              '${formatQty((row['receivedQty'] as num).toDouble())}'
              '/${formatQty((row['orderedQty'] as num).toDouble())}',
            ),
          ),
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
      exportData: (rows) {
        return ReportExportData(
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
                  exportQty((r['orderedQty'] as num).toDouble()),
                  exportQty((r['receivedQty'] as num).toDouble()),
                  exportQty((r['remainingQty'] as num).toDouble()),
                  ReportExportService.formatCurrency(
                    r['estimatedTotal'] as double,
                  ),
                  ReportExportService.formatCurrency(
                    r['receivedValue'] as double,
                  ),
                ],
              )
              .toList(),
          summary: poStatusExportSummary(rows, showsProgress),
        );
      },
    );
  }
}
