import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Outcome colours. Written off is the only one that costs the business money
/// outright, so it is the only one in danger red.
const Map<String, Color> _outcomeColors = {
  'returnToSupplier': AppColors.info,
  'keepForClaim': AppColors.warning,
  'writeOff': AppColors.danger,
};

({double qty, double value, double writtenOff}) damagedItemsTotals(
  List<Map<String, dynamic>> rows,
) {
  var qty = 0.0;
  var value = 0.0;
  var writtenOff = 0.0;
  for (final r in rows) {
    qty += (r['damagedQty'] as num).toDouble();
    final v = (r['damagedValue'] as num).toDouble();
    value += v;
    if (r['handling'] == 'writeOff') writtenOff += v;
  }
  return (qty: qty, value: value, writtenOff: writtenOff);
}

Map<String, dynamic> damagedItemsExportSummary(
  List<Map<String, dynamic>> rows,
) {
  final t = damagedItemsTotals(rows);
  return {
    'Damaged Lines': rows.length,
    'Damaged Units': exportQty(t.qty),
    'Damaged Value': ReportExportService.formatCurrency(t.value),
    'Written Off': ReportExportService.formatCurrency(t.writtenOff),
  };
}

/// What arrived damaged, from whom, and what was decided about it.
///
/// Dated by the **receipt** — this answers "what arrived broken this period".
/// Whether the supplier later credited any of it is a different question,
/// answered by Supplier-wise Purchases and Purchase Summary, because recovery
/// is dated by its own event.
///
/// Damaged units never entered stock, so nothing here appears in the item's
/// Stock History — this register is the only place they are visible.
class RestaurantDamagedItemsReportScreen extends StatelessWidget {
  const RestaurantDamagedItemsReportScreen({super.key});

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: 'Damaged Items',
      subtitle: 'Damage found on delivery',
      featureNoun: 'damaged items',
      exportFileName: 'restaurant_damaged_items',
      rowUnit: 'lines',
      emptyIcon: Icons.verified_outlined,
      emptyTitle: 'No damage recorded',
      emptyMessage: 'Every receipt in this period arrived intact.',
      loader: (start, end) =>
          service.getDamagedItemsReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final t = damagedItemsTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Damaged',
            value: formatQty(t.qty),
            subtitle: '${rows.length} line${rows.length == 1 ? '' : 's'}',
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.danger,
          ),
          ReportSummaryCard(
            title: 'Damaged Value',
            value: formatMoney(t.value),
            subtitle: 'billed, damage included',
            icon: Icons.payments_rounded,
            color: AppColors.warning,
          ),
          ReportSummaryCard(
            title: 'Written Off',
            value: formatMoney(t.writtenOff),
            subtitle: 'absorbed, not recoverable',
            icon: Icons.delete_outline_rounded,
            color: t.writtenOff > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ];
      },
      detail: (context, rows) {
        final missing = rows.where((r) => r['costMissing'] == true).toList();
        if (missing.isEmpty) return const SizedBox.shrink();
        return ReportNotice(
          message: missing.length == 1
              ? '1 damaged line has no cost price, so Damaged Value is '
                  'understated.'
              : '${missing.length} damaged lines have no cost price, so '
                  'Damaged Value is understated.',
        );
      },
      columns: (context) => [
        ReportTable.column(context, 'Item'),
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'GRN'),
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Value', numeric: true),
        ReportTable.column(context, 'Outcome'),
      ],
      rowBuilder: (context, row) {
        final handling = row['handling'] as String?;
        return DataRow(
          cells: [
            DataCell(Text(row['itemName'] as String)),
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text(row['grnNumber'] as String)),
            DataCell(Text(_date(row['receivedDate'] as String))),
            DataCell(Text(formatQty((row['damagedQty'] as num).toDouble()))),
            DataCell(
              Text(formatMoney((row['damagedValue'] as num).toDouble())),
            ),
            DataCell(
              handling == null
                  ? const Text('—')
                  : AppStatusPill(
                      dense: true,
                      label: row['handlingDisplay'] as String,
                      color:
                          _outcomeColors[handling] ?? AppColors.textSecondary,
                    ),
            ),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'Item',
          'Supplier',
          'GRN',
          'PO',
          'Date',
          'Damaged Qty',
          'Cost Price',
          'Damaged Value',
          'Outcome',
        ],
        rows: rows
            .map(
              (r) => [
                r['itemName'],
                r['supplierName'],
                r['grnNumber'],
                r['poNumber'],
                _date(r['receivedDate'] as String),
                exportQty((r['damagedQty'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['costPrice'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['damagedValue'] as num).toDouble()),
                r['handlingDisplay'],
              ],
            )
            .toList(),
        summary: damagedItemsExportSummary(rows),
      ),
    );
  }
}
