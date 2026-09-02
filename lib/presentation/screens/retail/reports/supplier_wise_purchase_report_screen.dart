import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// The period totals, computed ONCE from the loaded rows.
///
/// Both the summary band and the export summary read this, so an exported
/// report can never carry a different figure from the one on screen — the
/// export used to fold `totalAmount` itself and omit everything else.
typedef SupplierWiseTotals = ({
  double amount,
  double units,
  double expected,
  double recovered,
  double absorbed,
  double damaged,
});

SupplierWiseTotals supplierWiseTotals(List<Map<String, dynamic>> rows) {
  double sum(String key) =>
      rows.fold<double>(0, (s, r) => s + (r[key] as num).toDouble());
  return (
    amount: sum('totalAmount'),
    units: sum('totalItems'),
    expected: sum('damagedExpected'),
    recovered: sum('damagedRecovered'),
    absorbed: sum('damagedAbsorbed'),
    damaged: sum('damagedAmount'),
  );
}

/// The export summary, built from the SAME totals the summary band shows.
///
/// A named function rather than an inline map so the parity is testable: the
/// export used to publish only the supplier count and the received total,
/// omitting units and all three recovery figures the screen displays.
Map<String, dynamic> supplierWiseExportSummary(
  List<Map<String, dynamic>> rows,
) {
  final t = supplierWiseTotals(rows);
  return {
    'Suppliers': rows.length,
    'Total Received': ReportExportService.formatCurrency(t.amount),
    'Units': formatQty(t.units),
    'Expected Recovery': ReportExportService.formatCurrency(t.expected),
    'Recovered': ReportExportService.formatCurrency(t.recovered),
    'Absorbed': ReportExportService.formatCurrency(t.absorbed),
  };
}

/// Spend per supplier, measured on goods actually received.
///
/// Previously this summed `estimatedTotal` across every purchase order with no
/// status filter, so drafts and cancelled orders counted and the number was an
/// estimate. It now reads confirmed GRNs at the supplier's INVOICE value —
/// `GRNModel.totalAmount`, which bills the full received quantity, damaged
/// units included. Damaged value is therefore INSIDE `Amount`, not deducted
/// from it; the Expected/Recovered/Absorbed columns say what has happened to
/// that value, each dated by its own event.
class SupplierWisePurchaseReportScreen extends StatelessWidget {
  const SupplierWisePurchaseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Supplier-wise Purchases',
      subtitle: 'Based on goods received',
      featureNoun: 'purchases',
      exportFileName: 'supplier_wise_purchases',
      rowUnit: 'suppliers',
      emptyIcon: Icons.local_shipping_outlined,
      emptyTitle: 'No purchases received',
      emptyMessage:
          'Nothing has been received from any supplier in this period.',
      loader: (start, end) =>
          service.getSupplierWisePurchaseReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final t = supplierWiseTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Total Received',
            value: formatMoney(t.amount),
            subtitle: '${rows.length} suppliers',
            icon: Icons.storefront_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Damaged',
            value: formatMoney(t.damaged),
            // Since D2 this card sums all three recovery outcomes, each dated
            // by its own event — so it is NOT a slice of Amount. A supplier can
            // even have recovery here with no receipt in the window at all.
            subtitle: 'expected + recovered + absorbed',
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.danger,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'Receipts', numeric: true),
        ReportTable.column(context, 'Units', numeric: true),
        // Three outcomes, each dated by its own event: value the supplier
        // still owes, value actually credited, and value written off. Expected
        // is NOT money received.
        ReportTable.column(context, 'Expected', numeric: true),
        ReportTable.column(context, 'Recovered', numeric: true),
        ReportTable.column(context, 'Absorbed', numeric: true),
        ReportTable.column(context, 'Amount', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['supplierName'] as String)),
          DataCell(Text('${row['receiptCount']}')),
          DataCell(Text(formatQty((row['totalItems'] as num).toDouble()))),
          DataCell(Text(formatMoney(row['damagedExpected'] as double))),
          DataCell(Text(formatMoney(row['damagedRecovered'] as double))),
          DataCell(
            Text(
              formatMoney(row['damagedAbsorbed'] as double),
              style: (row['damagedAbsorbed'] as double) > 0
                  ? const TextStyle(color: AppColors.danger)
                  : null,
            ),
          ),
          DataCell(Text(formatMoney(row['totalAmount'] as double))),
        ],
      ),
      exportData: (rows) {
        return ReportExportData(
          headers: const [
            'Supplier',
            'Receipts',
            'Units',
            'Expected Recovery',
            'Recovered',
            'Damaged Absorbed',
            'Amount',
          ],
          rows: rows
              .map(
                (r) => [
                  r['supplierName'],
                  r['receiptCount'],
                  exportQty((r['totalItems'] as num).toDouble()),
                  ReportExportService.formatCurrency(
                    r['damagedExpected'] as double,
                  ),
                  ReportExportService.formatCurrency(
                    r['damagedRecovered'] as double,
                  ),
                  ReportExportService.formatCurrency(
                    r['damagedAbsorbed'] as double,
                  ),
                  ReportExportService.formatCurrency(
                    r['totalAmount'] as double,
                  ),
                ],
              )
              .toList(),
          summary: supplierWiseExportSummary(rows),
        );
      },
    );
  }
}
