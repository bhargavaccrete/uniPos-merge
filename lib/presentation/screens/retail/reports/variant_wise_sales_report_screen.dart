import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Units and revenue per product variant (size / colour / attribute combo).
class VariantWiseSalesReportScreen extends StatelessWidget {
  const VariantWiseSalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Variant-wise Sales',
      subtitle: 'Revenue by variant',
      featureNoun: 'sales',
      exportFileName: 'variant_wise_sales',
      rowUnit: 'variants',
      emptyIcon: Icons.tune_rounded,
      emptyTitle: 'No sales',
      emptyMessage: 'No variants were sold in this period.',
      loader: (start, end) =>
          service.getVariantWiseSalesReport(startDate: start, endDate: end),
      summaryCards: (rows) => [
        ReportSummaryCard(
          title: 'Net Revenue',
          value: formatMoney(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
          subtitle: 'after returns, ${rows.length} variants',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        ReportSummaryCard(
          title: 'Net Units',
          // `totalQuantity` is a DOUBLE — retail sells by weight. Reading it
          // back `as int` threw on every non-empty period.
          value: formatQty(
            rows.fold<double>(
              0,
              (s, r) => s + (r['totalQuantity'] as num).toDouble(),
            ),
          ),
          subtitle: 'after returns',
          icon: Icons.inventory_2_rounded,
          color: AppColors.primary,
        ),
      ],
      columns: (context) => [
        ReportTable.column(context, 'Product'),
        ReportTable.column(context, 'Variant'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        // 'of which': Revenue already CONTAINS this tax, it is not an addend.
        // Added so the screen matches the six columns the export already wrote.
        ReportTable.column(context, 'of which Tax', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['productName'] as String? ?? 'Unknown')),
          DataCell(Text(row['variantLabel'] as String? ?? '')),
          DataCell(Text(formatQty((row['totalQuantity'] as num).toDouble()))),
          DataCell(Text(formatMoney(row['totalDiscount'] as double))),
          DataCell(Text(formatMoney(row['totalTax'] as double))),
          DataCell(Text(formatMoney(row['totalRevenue'] as double))),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Product',
          'Variant',
          'Qty',
          'Discount',
          'of which Tax',
          'Revenue',
        ],
        rows: rows
            .map(
              (r) => [
                r['productName'] ?? 'Unknown',
                r['variantLabel'] ?? '',
                exportQty((r['totalQuantity'] as num).toDouble()),
                ReportExportService.formatCurrency(
                  r['totalDiscount'] as double,
                ),
                ReportExportService.formatCurrency(r['totalTax'] as double),
                ReportExportService.formatCurrency(r['totalRevenue'] as double),
              ],
            )
            .toList(),
        summary: {
          'Variants': rows.length,
          'Total Revenue': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
        },
      ),
    );
  }
}
