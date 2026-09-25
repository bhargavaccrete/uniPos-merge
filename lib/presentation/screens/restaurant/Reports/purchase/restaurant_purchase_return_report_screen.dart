import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/damaged_goods/restaurant_purchase_return_list_screen.dart'
    show restaurantPurchaseReturnStatusColor;
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Totals for the band and the export.
///
/// Cancelled returns are counted as rows but excluded from every value —
/// the goods never went back, so nothing is owed back.
({double qty, double value, double awaiting, int open, int counted})
    purchaseReturnTotals(List<Map<String, dynamic>> rows) {
  var qty = 0.0;
  var value = 0.0;
  var awaiting = 0.0;
  var open = 0;
  var counted = 0;
  for (final r in rows) {
    if (r['countsTowardValue'] != true) continue;
    counted++;
    qty += (r['totalQty'] as num).toDouble();
    value += (r['totalAmount'] as num).toDouble();
    if (r['isOpen'] == true) {
      open++;
      awaiting += (r['totalAmount'] as num).toDouble();
    }
  }
  return (qty: qty, value: value, awaiting: awaiting, open: open, counted: counted);
}

Map<String, dynamic> purchaseReturnExportSummary(
  List<Map<String, dynamic>> rows,
) {
  final t = purchaseReturnTotals(rows);
  return {
    'Returns': rows.length,
    'Counted Toward Value': t.counted,
    'Units Returned': exportQty(t.qty),
    'Return Value': ReportExportService.formatCurrency(t.value),
    'Awaiting Credit': ReportExportService.formatCurrency(t.awaiting),
  };
}

/// Goods sent back to suppliers, and where each credit note stands.
///
/// A return is raised automatically when a damaged line is received with
/// "Return to Supplier" — there is no way to raise one by hand, and accepted
/// stock cannot be returned at all.
///
/// **Cancelled returns are listed but contribute no value.** Cancelling only
/// stops the business waiting for a credit note that isn't coming; the
/// liability the GRN accrued still stands, which is exactly why the row stays
/// visible.
class RestaurantPurchaseReturnReportScreen extends StatelessWidget {
  const RestaurantPurchaseReturnReportScreen({super.key});

  String _date(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: 'Purchase Returns',
      subtitle: 'Goods sent back, and their credit notes',
      featureNoun: 'returns',
      exportFileName: 'restaurant_purchase_returns',
      rowUnit: 'returns',
      emptyIcon: Icons.assignment_return_outlined,
      emptyTitle: 'No returns raised',
      emptyMessage: 'Nothing was sent back to a supplier in this period.',
      loader: (start, end) =>
          service.getPurchaseReturnReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final t = purchaseReturnTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Returns',
            value: '${rows.length}',
            subtitle: '${formatQty(t.qty)} units, cancelled excluded',
            icon: Icons.assignment_return_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Return Value',
            value: formatMoney(t.value),
            subtitle: 'recoverable from suppliers',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Awaiting Credit',
            value: formatMoney(t.awaiting),
            subtitle: '${t.open} still open',
            icon: Icons.hourglass_bottom_rounded,
            color: t.open > 0 ? AppColors.warning : AppColors.textSecondary,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Return'),
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'GRN'),
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Value', numeric: true),
        ReportTable.column(context, 'Credit Note'),
        ReportTable.column(context, 'Status'),
      ],
      rowBuilder: (context, row) {
        final status = RestaurantPurchaseReturnStatus.values.firstWhere(
          (s) => s.name == row['status'],
          orElse: () => RestaurantPurchaseReturnStatus.pending,
        );
        final credit = (row['creditNoteAmount'] as num).toDouble();
        final note = row['creditNoteNumber'] as String?;

        return DataRow(
          cells: [
            DataCell(Text(row['returnNumber'] as String)),
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text(row['grnNumber'] as String)),
            DataCell(Text(_date(row['returnDate'] as String))),
            DataCell(Text(formatQty((row['totalQty'] as num).toDouble()))),
            DataCell(Text(formatMoney((row['totalAmount'] as num).toDouble()))),
            DataCell(
              Text(
                note == null || note.isEmpty
                    ? '—'
                    // The note's face value can be less than the return total,
                    // so show what was actually credited beside its number.
                    : '$note · ${formatMoney(credit)}',
              ),
            ),
            DataCell(
              AppStatusPill(
                dense: true,
                label: row['statusDisplay'] as String,
                color: restaurantPurchaseReturnStatusColor(status),
              ),
            ),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'Return Number',
          'Supplier',
          'GRN',
          'PO',
          'Date',
          'Qty',
          'Value',
          'Status',
          'Credit Note',
          'Credit Amount',
          'Credit Date',
        ],
        rows: rows
            .map(
              (r) => [
                r['returnNumber'],
                r['supplierName'],
                r['grnNumber'],
                r['poNumber'],
                _date(r['returnDate'] as String),
                exportQty((r['totalQty'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['totalAmount'] as num).toDouble()),
                r['statusDisplay'],
                r['creditNoteNumber'] ?? '',
                ReportExportService.formatCurrency(
                    (r['creditNoteAmount'] as num).toDouble()),
                _date(r['creditNoteDate'] as String?),
              ],
            )
            .toList(),
        summary: purchaseReturnExportSummary(rows),
      ),
    );
  }
}
