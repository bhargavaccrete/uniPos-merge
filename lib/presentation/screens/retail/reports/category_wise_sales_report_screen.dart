import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

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
      emptyMessage: 'Nothing was sold in this period.',
      loader: (start, end) =>
          service.getCategoryWiseSalesReport(startDate: start, endDate: end),
      summaryCards: (rows) => [
        ReportSummaryCard(
          title: 'Revenue',
          value: formatMoney(
              rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double))),
          subtitle: '${rows.length} categories',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        ReportSummaryCard(
          title: 'Units Sold',
          value:
              '${rows.fold<int>(0, (s, r) => s + (r['totalQuantity'] as int))}',
          subtitle: 'across all categories',
          icon: Icons.inventory_2_rounded,
          color: AppColors.primary,
        ),
      ],
      columns: (context) => [
        ReportTable.column(context, 'Category'),
        ReportTable.column(context, 'Products', numeric: true),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(cells: [
        DataCell(Text(row['category'] as String)),
        DataCell(Text('${row['productCount']}')),
        DataCell(Text('${row['totalQuantity']}')),
        DataCell(Text(formatMoney(row['totalDiscount'] as double))),
        DataCell(Text(formatMoney(row['totalRevenue'] as double))),
      ]),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Category',
          'Products',
          'Qty',
          'Discount',
          'Tax',
          'Revenue'
        ],
        rows: rows
            .map((r) => [
                  r['category'],
                  r['productCount'],
                  r['totalQuantity'],
                  ReportExportService.formatCurrency(
                      r['totalDiscount'] as double),
                  ReportExportService.formatCurrency(r['totalTax'] as double),
                  ReportExportService.formatCurrency(
                      r['totalRevenue'] as double),
                ])
            .toList(),
        summary: {
          'Categories': rows.length,
          'Total Revenue': ReportExportService.formatCurrency(rows.fold<double>(
              0, (s, r) => s + (r['totalRevenue'] as double))),
        },
      ),
    );
  }
}
