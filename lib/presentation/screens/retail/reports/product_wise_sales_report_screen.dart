import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

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
      emptyMessage: 'No products were sold in this period.',
      loader: (start, end) =>
          service.getProductWiseSalesReport(startDate: start, endDate: end),
      summaryCards: (rows) => [
        ReportSummaryCard(
          title: 'Net Revenue',
          value: formatMoney(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
          subtitle: 'after returns, ${rows.length} products',
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
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        // 'of which': Revenue already CONTAINS this tax, it is not an addend.
        ReportTable.column(context, 'of which Tax', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['productName'] as String? ?? 'Unknown')),
          DataCell(Text(formatQty((row['totalQuantity'] as num).toDouble()))),
          DataCell(Text(formatMoney(row['totalDiscount'] as double))),
          DataCell(Text(formatMoney(row['totalTax'] as double))),
          DataCell(Text(formatMoney(row['totalRevenue'] as double))),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Product',
          'Qty',
          'Discount',
          'of which Tax',
          'Revenue',
        ],
        rows: rows
            .map(
              (r) => [
                r['productName'] ?? 'Unknown',
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
          'Products': rows.length,
          'Total Revenue': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
        },
      ),
    );
  }
}
