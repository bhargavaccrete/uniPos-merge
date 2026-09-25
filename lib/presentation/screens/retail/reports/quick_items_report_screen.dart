import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Everything sold that the catalogue does not carry, grouped by the name the
/// cashier typed.
///
/// The management question this answers is "how much of our trade never touched
/// the catalogue, and what keeps getting typed". A name that recurs is a
/// product worth adding properly — once it is a real product it gets a cost
/// price, a stock count and a barcode, none of which a quick item has.
///
/// Three things make these lines worth a report of their own: they are the one
/// price-setting action at the till with **no permission gate**, they **move no
/// stock**, and they carry **no cost price**, so their margin is unknown rather
/// than total.
class QuickItemsReportScreen extends StatelessWidget {
  const QuickItemsReportScreen({super.key});

  String _date(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  double _sum(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(0, (s, r) => s + ((r[key] as num?) ?? 0).toDouble());

  /// Tax rates a single typed name was sold at. More than one is worth seeing:
  /// the same thing was rung up at different rates on different days.
  String _rates(Map<String, dynamic> row) {
    final rates = (row['gstRates'] as List).cast<num>();
    if (rates.isEmpty) return '—';
    return rates.map((r) => '${r.toStringAsFixed(r % 1 == 0 ? 0 : 2)}%').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Quick Items',
      subtitle: 'Sold without a catalogue entry',
      featureNoun: 'quick items',
      exportFileName: 'quick_items',
      rowUnit: 'items',
      emptyIcon: Icons.add_shopping_cart_outlined,
      emptyTitle: 'No quick items',
      emptyMessage:
          'Everything sold in this period came from the catalogue.',
      loader: (start, end) =>
          service.getQuickItemsReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final lines = rows.fold<int>(
          0,
          (s, r) => s + ((r['lineCount'] as int?) ?? 0),
        );
        final share = _sum(rows, 'shareOfRevenuePct');

        return [
          ReportSummaryCard(
            title: 'Quick Items',
            value: '${rows.length}',
            subtitle: '$lines line${lines == 1 ? '' : 's'} rung up',
            icon: Icons.add_shopping_cart_outlined,
            color: AppColors.info,
          ),
          ReportSummaryCard(
            title: 'Revenue',
            value: formatMoney(_sum(rows, 'totalRevenue')),
            subtitle: '${formatQty(_sum(rows, 'totalQuantity'))} units',
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
          ),
          ReportSummaryCard(
            title: 'Share of Sales',
            value: '${share.toStringAsFixed(1)}%',
            subtitle: 'of takings in this period',
            // A few percent is ordinary — delivery charges, gift wrap. A large
            // share means the catalogue is incomplete or is being bypassed.
            icon: Icons.pie_chart_outline_rounded,
            color: share <= 5
                ? AppColors.success
                : share <= 15
                ? AppColors.warning
                : AppColors.danger,
          ),
        ];
      },
      detail: (context, rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return const ReportNotice(
          message:
              'Quick items move no stock and carry no cost price, so they are '
              'absent from every inventory report and their margin shows as '
              'unknown on Profit. A name that keeps appearing here is worth '
              'adding to the catalogue properly.',
          icon: Icons.inventory_2_outlined,
        );
      },
      columns: (context) => [
        ReportTable.column(context, 'Item'),
        ReportTable.column(context, 'Times Sold', numeric: true),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Avg Price', numeric: true),
        ReportTable.column(context, 'Tax'),
        ReportTable.column(context, 'Discount', numeric: true),
        ReportTable.column(context, 'Revenue', numeric: true),
        ReportTable.column(context, '% of Sales', numeric: true),
        ReportTable.column(context, 'Last Sold'),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['itemName'] as String)),
          DataCell(Text('${row['lineCount']}')),
          DataCell(Text(formatQty((row['totalQuantity'] as num).toDouble()))),
          DataCell(Text(formatMoney(row['avgPrice'] as double))),
          DataCell(Text(_rates(row))),
          DataCell(Text(formatMoney(row['totalDiscount'] as double))),
          DataCell(Text(formatMoney(row['totalRevenue'] as double))),
          DataCell(
            Text('${(row['shareOfRevenuePct'] as num).toStringAsFixed(1)}%'),
          ),
          DataCell(Text(_date(row['lastSold'] as String?))),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Item',
          'Times Sold',
          'Quantity',
          'Avg Price',
          'Tax Rates',
          'Discount',
          'Tax',
          'Revenue',
          '% of Sales',
          'First Sold',
          'Last Sold',
        ],
        rows: rows
            .map(
              (r) => [
                r['itemName'],
                r['lineCount'],
                exportQty((r['totalQuantity'] as num).toDouble()),
                ReportExportService.formatCurrency(r['avgPrice'] as double),
                _rates(r),
                ReportExportService.formatCurrency(r['totalDiscount'] as double),
                ReportExportService.formatCurrency(r['totalTax'] as double),
                ReportExportService.formatCurrency(r['totalRevenue'] as double),
                '${(r['shareOfRevenuePct'] as num).toStringAsFixed(1)}%',
                _date(r['firstSold'] as String?),
                _date(r['lastSold'] as String?),
              ],
            )
            .toList(),
        summary: {
          'Distinct Items': rows.length,
          'Lines Rung Up': rows.fold<int>(
            0,
            (s, r) => s + ((r['lineCount'] as int?) ?? 0),
          ),
          'Quantity': exportQty(_sum(rows, 'totalQuantity')),
          'Revenue': ReportExportService.formatCurrency(
            _sum(rows, 'totalRevenue'),
          ),
          'Share of Sales':
              '${_sum(rows, 'shareOfRevenuePct').toStringAsFixed(1)}%',
        },
      ),
    );
  }
}
