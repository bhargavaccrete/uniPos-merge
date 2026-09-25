import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

({double orderedValue, double receivedValue, double awaited}) poStatusTotals(
  List<Map<String, dynamic>> rows,
) {
  var orderedValue = 0.0;
  var receivedValue = 0.0;
  var awaited = 0.0;
  for (final r in rows) {
    orderedValue += (r['estimatedTotal'] as num).toDouble();
    receivedValue += (r['receivedValue'] as num).toDouble();
    awaited += (r['remainingQty'] as num).toDouble();
  }
  return (
    orderedValue: orderedValue,
    receivedValue: receivedValue,
    awaited: awaited,
  );
}

Map<String, dynamic> poStatusExportSummary(List<Map<String, dynamic>> rows) {
  final t = poStatusTotals(rows);
  return {
    'Orders': rows.length,
    'Ordered Value': ReportExportService.formatCurrency(t.orderedValue),
    'Received Value': ReportExportService.formatCurrency(t.receivedValue),
    'Units Awaited': exportQty(t.awaited),
  };
}

/// Purchase orders in one status, with receiving progress.
///
/// One screen, three entry points — Pending, Partially Received and Completed
/// are the same table over a different status, so they are named constructors
/// rather than three copies.
///
/// **The status names are restaurant's**: `sent`, `partiallyReceived`,
/// `completed`. Retail says `partiallyCompleted`/`fullyCompleted`, and copying
/// those across fails silently — the report simply comes back empty.
class RestaurantPurchaseOrderStatusReportScreen extends StatelessWidget {
  final RestaurantPOStatus status;
  final String title;
  final String subtitle;

  /// Sent to the supplier, nothing received yet.
  const RestaurantPurchaseOrderStatusReportScreen.pending({super.key})
      : status = RestaurantPOStatus.sent,
        title = 'Pending Purchase Orders',
        subtitle = 'Sent to the supplier, nothing received yet';

  const RestaurantPurchaseOrderStatusReportScreen.partiallyReceived({
    super.key,
  })  : status = RestaurantPOStatus.partiallyReceived,
        title = 'Partially Received Orders',
        subtitle = 'Some goods in, some still outstanding';

  const RestaurantPurchaseOrderStatusReportScreen.completed({super.key})
      : status = RestaurantPOStatus.completed,
        title = 'Completed Orders',
        subtitle = 'Fully received against the order';

  /// Completed orders have nothing left to await, so the progress cards are
  /// replaced with the value actually received.
  bool get _showsProgress => status != RestaurantPOStatus.completed;

  /// Only Completed is a period question — "what did we finish receiving in
  /// March" is meaningful. Pending and Partially Received are **outstanding**
  /// orders, and whether an order is still outstanding is a fact about the
  /// order, not about the month being viewed. Windowing them on `createdAt`
  /// hid an order sent before the 1st and still undelivered from the default
  /// This Month view — exactly the order most worth chasing. Same reasoning
  /// the service already applies to receipts, which it counts across all time.
  bool get _isPeriodQuestion => status == RestaurantPOStatus.completed;

  String _date(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: title,
      subtitle: subtitle,
      featureNoun: 'orders',
      exportFileName: 'restaurant_po_${status.name}',
      rowUnit: 'orders',
      emptyIcon: Icons.assignment_outlined,
      emptyTitle: 'No orders here',
      emptyMessage: _isPeriodQuestion
          ? 'No purchase orders with this status in the period.'
          : 'No purchase orders with this status.',
      showDateRange: _isPeriodQuestion,
      loader: (start, end) => service.getPurchaseOrderStatusReport(
        status,
        startDate: start,
        endDate: end,
      ),
      summaryCards: (rows) {
        final t = poStatusTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Orders',
            value: '${rows.length}',
            icon: Icons.assignment_outlined,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: _showsProgress ? 'Ordered Value' : 'Received Value',
            value: formatMoney(
              _showsProgress ? t.orderedValue : t.receivedValue,
            ),
            subtitle: _showsProgress ? 'estimated' : 'invoiced',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          if (_showsProgress)
            ReportSummaryCard(
              title: 'Units Awaited',
              value: formatQty(t.awaited),
              subtitle: 'still to arrive',
              icon: Icons.pending_actions_rounded,
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
      rowBuilder: (context, row) {
        final ordered = (row['orderedQty'] as num).toDouble();
        final received = (row['receivedQty'] as num).toDouble();
        return DataRow(
          cells: [
            DataCell(Text(row['poNumber'] as String)),
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text(_date(row['expectedDeliveryDate'] as String?))),
            DataCell(Text('${formatQty(received)} / ${formatQty(ordered)}')),
            DataCell(
              Text(
                formatMoney(
                  (_showsProgress
                          ? row['estimatedTotal'] as num
                          : row['receivedValue'] as num)
                      .toDouble(),
                ),
              ),
            ),
          ],
        );
      },
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
                _date(r['createdAt'] as String?),
                _date(r['expectedDeliveryDate'] as String?),
                exportQty((r['orderedQty'] as num).toDouble()),
                exportQty((r['receivedQty'] as num).toDouble()),
                exportQty((r['remainingQty'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['estimatedTotal'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['receivedValue'] as num).toDouble()),
              ],
            )
            .toList(),
        summary: poStatusExportSummary(rows),
      ),
    );
  }
}
