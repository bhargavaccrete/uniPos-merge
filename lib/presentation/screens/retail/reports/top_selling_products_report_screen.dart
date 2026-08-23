import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

/// Best performers by revenue.
///
/// Same data as Product-wise Sales, capped at [_limit] — the service already
/// returns it sorted by revenue.
class TopSellingProductsReportScreen extends StatelessWidget {
  const TopSellingProductsReportScreen({super.key});

  static const int _limit = 20;

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Top Selling Products',
      subtitle: 'Top $_limit by revenue',
      featureNoun: 'sales',
      exportFileName: 'top_selling_products',
      rowUnit: 'products',
      emptyIcon: Icons.trending_up_rounded,
      emptyTitle: 'No sales',
      emptyMessage: 'Nothing was sold in this period.',
      loader: (start, end) async {
        final rows = await service.getTopSellingProductsReport(
          limit: _limit,
          startDate: start,
          endDate: end,
        );
        // Stamp the rank now, while the revenue-desc order from the service is
        // still intact — the table paginates, so index-in-page would be wrong.
        return [
          for (var i = 0; i < rows.length; i++) {...rows[i], '__rank': i + 1},
        ];
      },
      summaryCards: (rows) => [
        ReportSummaryCard(
          title: 'Top Product',
          value: rows.first['productName'] as String,
          subtitle: formatMoney(rows.first['totalRevenue'] as double),
          icon: Icons.emoji_events_rounded,
          color: AppColors.accent,
        ),
        ReportSummaryCard(
          title: 'Revenue',
          value: formatMoney(
            rows.fold<double>(0, (s, r) => s + (r['totalRevenue'] as double)),
          ),
          subtitle: 'from top ${rows.length}',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
      ],
      columns: (context) => [
        ReportTable.column(context, '#'),
        ReportTable.column(context, 'Product'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
      ],
      rowBuilder: (context, row) {
        // Rank comes from the service's revenue-desc order, so it survives
        // pagination.
        final rank = row['__rank'] as int?;
        return DataRow(
          cells: [
            DataCell(
              Text(
                rank == null ? '' : '$rank',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: rank != null && rank <= 3
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ),
            DataCell(Text(row['productName'] as String)),
            DataCell(Text('${row['totalQuantity']}')),
            DataCell(Text(formatMoney(row['totalRevenue'] as double))),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const ['Rank', 'Product', 'Qty', 'Revenue'],
        rows: rows
            .map(
              (r) => [
                r['__rank'],
                r['productName'],
                r['totalQuantity'],
                ReportExportService.formatCurrency(r['totalRevenue'] as double),
              ],
            )
            .toList(),
        summary: {'Products': rows.length},
      ),
    );
  }
}
