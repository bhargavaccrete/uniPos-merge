import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

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
          title: 'Revenue',
          value: formatMoney(
              rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double))),
          subtitle: '${rows.length} variants',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        ReportSummaryCard(
          title: 'Units Sold',
          value:
              '${rows.fold<int>(0, (s, r) => s + (r['totalQuantity'] as int))}',
          subtitle: 'across all variants',
          icon: Icons.inventory_2_rounded,
          color: AppColors.primary,
        ),
      ],
      columns: (context) => [
        ReportTable.column(context, 'Product'),
        ReportTable.column(context, 'Variant'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(cells: [
        DataCell(Text(row['productName'] as String)),
        DataCell(Text(row['variantLabel'] as String)),
        DataCell(Text('${row['totalQuantity']}')),
        DataCell(Text(formatMoney(row['totalDiscount'] as double))),
        DataCell(Text(formatMoney(row['totalRevenue'] as double))),
      ]),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Product',
          'Variant',
          'Qty',
          'Discount',
          'Tax',
          'Revenue'
        ],
        rows: rows
            .map((r) => [
                  r['productName'],
                  r['variantLabel'],
                  r['totalQuantity'],
                  ReportExportService.formatCurrency(
                      r['totalDiscount'] as double),
                  ReportExportService.formatCurrency(r['totalTax'] as double),
                  ReportExportService.formatCurrency(
                      r['totalRevenue'] as double),
                ])
            .toList(),
        summary: {
          'Variants': rows.length,
          'Total Revenue': ReportExportService.formatCurrency(rows.fold<double>(
              0, (s, r) => s + (r['totalRevenue'] as double))),
        },
      ),
    );
  }
}
