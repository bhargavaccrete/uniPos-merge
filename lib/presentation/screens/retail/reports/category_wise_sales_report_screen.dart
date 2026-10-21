import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Revenue grouped by product category.
class CategoryWiseSalesReportScreen extends StatelessWidget {
  const CategoryWiseSalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Category-wise Sales',
      subtitle: 'Revenue by category',
      featureNoun: 'sales',
      exportFileName: 'category_wise_sales',
      rowUnit: 'categories',
      emptyIcon: Icons.category_outlined,
      emptyTitle: 'No sales',
      emptyMessage: 'No categories had sales in this period.',
      loader: (start, end) =>
          service.getCategoryWiseSalesReport(startDate: start, endDate: end),
      summaryCards: (rows) => [
        ReportSummaryCard(
          title: 'Net Revenue',
          value: formatMoney(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
          subtitle: 'after returns, ${rows.length} categories',
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
        ReportTable.column(context, 'Category'),
        ReportTable.column(context, 'Products', numeric: true),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        // 'of which': Revenue already CONTAINS this tax, it is not an addend.
        // Added so the screen matches the six columns the export already wrote.
        ReportTable.column(context, 'of which Tax', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['category'] as String? ?? 'Uncategorized')),
          DataCell(Text('${row['productCount']}')),
          DataCell(Text(formatQty((row['totalQuantity'] as num).toDouble()))),
          DataCell(Text(formatMoney(row['totalDiscount'] as double))),
          DataCell(Text(formatMoney(row['totalTax'] as double))),
          DataCell(Text(formatMoney(row['totalRevenue'] as double))),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Category',
          'Products',
          'Qty',
          'Discount',
          'of which Tax',
          'Revenue',
        ],
        rows: rows
            .map(
              (r) => [
                r['category'] ?? 'Uncategorized',
                r['productCount'],
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
          'Categories': rows.length,
          'Total Revenue': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
        },
      ),
    );
  }
}
