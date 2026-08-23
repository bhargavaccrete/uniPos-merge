import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

/// Units and revenue per product.
class ProductWiseSalesReportScreen extends StatelessWidget {
  const ProductWiseSalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Product-wise Sales',
      subtitle: 'Revenue by product',
      featureNoun: 'sales',
      exportFileName: 'product_wise_sales',
      rowUnit: 'products',
      emptyIcon: Icons.shopping_bag_outlined,
      emptyTitle: 'No sales',
      emptyMessage: 'Nothing was sold in this period.',
      loader: (start, end) =>
          service.getProductWiseSalesReport(startDate: start, endDate: end),
      summaryCards: (rows) => [
        ReportSummaryCard(
          title: 'Revenue',
          value: formatMoney(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
          subtitle: '${rows.length} products',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        ReportSummaryCard(
          title: 'Units Sold',
          value:
              '${rows.fold<int>(0, (s, r) => s + (r['totalQuantity'] as int))}',
          subtitle: 'across all products',
          icon: Icons.inventory_2_rounded,
          color: AppColors.primary,
        ),
      ],
      columns: (context) => [
        ReportTable.column(context, 'Product'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        ReportTable.column(context, 'Tax', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['productName'] as String)),
          DataCell(Text('${row['totalQuantity']}')),
          DataCell(Text(formatMoney(row['totalDiscount'] as double))),
          DataCell(Text(formatMoney(row['totalTax'] as double))),
          DataCell(Text(formatMoney(row['totalRevenue'] as double))),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const ['Product', 'Qty', 'Discount', 'Tax', 'Revenue'],
        rows: rows
            .map(
              (r) => [
                r['productName'],
                r['totalQuantity'],
                ReportExportService.formatCurrency(
                  r['totalDiscount'] as double,
                ),
                ReportExportService.formatCurrency(r['totalTax'] as double),
                ReportExportService.formatCurrency(r['totalRevenue'] as double),
              ],
            )
            .toList(),
        summary: {
          'Products': rows.length,
          'Total Revenue': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
        },
      ),
    );
  }
}
