import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Totals for the summary band and the export, derived once so the two can
/// never disagree.
({
  double billed,
  double expected,
  double recovered,
  double absorbed,
  double netCost,
  double units,
  int receipts,
}) supplierWiseTotals(List<Map<String, dynamic>> rows) {
  var billed = 0.0;
  var expected = 0.0;
  var recovered = 0.0;
  var absorbed = 0.0;
  var netCost = 0.0;
  var units = 0.0;
  var receipts = 0;
  for (final r in rows) {
    billed += (r['billedValue'] as num).toDouble();
    expected += (r['damagedExpected'] as num).toDouble();
    recovered += (r['damagedRecovered'] as num).toDouble();
    absorbed += (r['damagedAbsorbed'] as num).toDouble();
    netCost += (r['netCost'] as num).toDouble();
    units += (r['receivedQty'] as num).toDouble();
    receipts += r['receiptCount'] as int;
  }
  return (
    billed: billed,
    expected: expected,
    recovered: recovered,
    absorbed: absorbed,
    netCost: netCost,
    units: units,
    receipts: receipts,
  );
}

Map<String, dynamic> supplierWiseExportSummary(
  List<Map<String, dynamic>> rows,
) {
  final t = supplierWiseTotals(rows);
  return {
    'Suppliers': rows.length,
    'Receipts': t.receipts,
    'Billed Value': ReportExportService.formatCurrency(t.billed),
    'Damage Expected': ReportExportService.formatCurrency(t.expected),
    'Damage Recovered': ReportExportService.formatCurrency(t.recovered),
    'Damage Absorbed': ReportExportService.formatCurrency(t.absorbed),
    'Net Cost': ReportExportService.formatCurrency(t.netCost),
  };
}

/// Spend per supplier, measured on **confirmed receipts** rather than on
/// orders — an order is intent, a receipt is money owed.
///
/// Grouped by supplier id, never by name, so two suppliers sharing a name do
/// not merge and a rename does not split one supplier's history.
///
/// A supplier whose only activity this period was a credit note still appears,
/// with a negative Net Cost — money came back without anything being bought.
class RestaurantSupplierWisePurchaseReportScreen extends StatelessWidget {
  const RestaurantSupplierWisePurchaseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: 'Supplier-wise Purchases',
      subtitle: 'What each supplier delivered and billed',
      featureNoun: 'purchases',
      exportFileName: 'restaurant_supplier_wise_purchases',
      rowUnit: 'suppliers',
      emptyIcon: Icons.local_shipping_outlined,
      emptyTitle: 'No supplier activity',
      emptyMessage: 'No confirmed receipts or credits in this period.',
      loader: (start, end) =>
          service.getSupplierWisePurchaseReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final t = supplierWiseTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Billed Value',
            value: formatMoney(t.billed),
            subtitle: '${rows.length} supplier${rows.length == 1 ? '' : 's'}',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Net Cost',
            value: formatMoney(t.netCost),
            subtitle: 'after supplier credits',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Damage Absorbed',
            value: formatMoney(t.absorbed),
            subtitle: t.expected > 0
                ? '${formatMoney(t.expected)} still claimed'
                : 'written off',
            icon: Icons.report_gmailerrorred_rounded,
            color: t.absorbed > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'Receipts', numeric: true),
        ReportTable.column(context, 'Units', numeric: true),
        ReportTable.column(context, 'Billed', numeric: true),
        ReportTable.column(context, 'Expected', numeric: true),
        ReportTable.column(context, 'Recovered', numeric: true),
        ReportTable.column(context, 'Absorbed', numeric: true),
        ReportTable.column(context, 'Net Cost', numeric: true),
      ],
      rowBuilder: (context, row) {
        final absorbed = (row['damagedAbsorbed'] as num).toDouble();
        return DataRow(
          cells: [
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text('${row['receiptCount']}')),
            DataCell(Text(formatQty((row['receivedQty'] as num).toDouble()))),
            DataCell(Text(formatMoney((row['billedValue'] as num).toDouble()))),
            DataCell(
              Text(formatMoney((row['damagedExpected'] as num).toDouble())),
            ),
            DataCell(
              Text(formatMoney((row['damagedRecovered'] as num).toDouble())),
            ),
            DataCell(
              Text(
                formatMoney(absorbed),
                style: GoogleFonts.poppins(
                  color: absorbed > 0 ? AppColors.danger : null,
                  fontWeight: absorbed > 0 ? FontWeight.w600 : null,
                ),
              ),
            ),
            DataCell(Text(formatMoney((row['netCost'] as num).toDouble()))),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'Supplier',
          'Receipts',
          'Units',
          'Billed Value',
          'Accepted Value',
          'Damage Expected',
          'Damage Recovered',
          'Damage Absorbed',
          'Net Cost',
        ],
        rows: rows
            .map(
              (r) => [
                r['supplierName'],
                r['receiptCount'],
                exportQty((r['receivedQty'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['billedValue'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['acceptedValue'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['damagedExpected'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['damagedRecovered'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['damagedAbsorbed'] as num).toDouble()),
                ReportExportService.formatCurrency(
                    (r['netCost'] as num).toDouble()),
              ],
            )
            .toList(),
        summary: supplierWiseExportSummary(rows),
      ),
    );
  }
}
