import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

/// Goods that arrived damaged, and what was decided about each.
///
/// Damaged units never entered stock and were never billed — this report is
/// about supplier quality and what is owed back, not about inventory movement.
class DamagedItemsReportScreen extends StatelessWidget {
  const DamagedItemsReportScreen({super.key});

  static const _handlingColors = {
    'returnToSupplier': AppColors.info,
    'keepForClaim': AppColors.warning,
    'writeOff': AppColors.danger,
  };

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Damaged Items',
      subtitle: 'Received damaged, by outcome',
      featureNoun: 'receipts',
      exportFileName: 'damaged_items',
      rowUnit: 'lines',
      emptyIcon: Icons.verified_outlined,
      emptyTitle: 'No damaged goods',
      emptyMessage: 'Everything received in this period was accepted.',
      loader: (start, end) =>
          service.getDamagedItemsReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final qty = rows.fold<int>(0, (s, r) => s + (r['damagedQty'] as int));
        final value =
            rows.fold<double>(0, (s, r) => s + (r['damagedAmount'] as double));

        int qtyFor(String handling) => rows
            .where((r) => r['handling'] == handling)
            .fold<int>(0, (s, r) => s + (r['damagedQty'] as int));

        return [
          ReportSummaryCard(
            title: 'Damaged',
            value: '$qty',
            subtitle: '${rows.length} lines',
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.danger,
          ),
          ReportSummaryCard(
            title: 'Value',
            value: formatMoney(value),
            subtitle: 'not billed',
            icon: Icons.payments_rounded,
            color: AppColors.warning,
          ),
          ReportSummaryCard(
            title: 'Written Off',
            value: '${qtyFor('writeOff')}',
            subtitle: 'a real loss',
            icon: Icons.delete_outline_rounded,
            color: AppColors.textSecondary,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Product'),
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'GRN'),
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Value', numeric: true),
        ReportTable.column(context, 'Outcome'),
      ],
      rowBuilder: (context, row) {
        final variant = row['variantInfo'] as String?;
        final handling = row['handling'] as String?;

        return DataRow(cells: [
          DataCell(Text(
            variant == null || variant.isEmpty
                ? row['productName'] as String
                : '${row['productName']} · $variant',
          )),
          DataCell(Text(row['supplierName'] as String)),
          DataCell(Text(row['grnNumber'] as String)),
          DataCell(Text(_date(row['receivedDate'] as String))),
          DataCell(Text('${row['damagedQty']}')),
          DataCell(Text(formatMoney(row['damagedAmount'] as double))),
          DataCell(AppStatusPill(
            dense: true,
            label: row['handlingDisplay'] as String,
            color: _handlingColors[handling] ?? AppColors.textSecondary,
          )),
        ]);
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'Product',
          'Variant',
          'Supplier',
          'GRN',
          'PO',
          'Date',
          'Damaged Qty',
          'Cost Price',
          'Damaged Value',
          'Outcome',
        ],
        rows: rows
            .map((r) => [
                  r['productName'],
                  r['variantInfo'] ?? '',
                  r['supplierName'],
                  r['grnNumber'],
                  r['poNumber'],
                  _date(r['receivedDate'] as String),
                  r['damagedQty'],
                  r['costPrice'] == null
                      ? ''
                      : ReportExportService.formatCurrency(
                          r['costPrice'] as double),
                  ReportExportService.formatCurrency(
                      r['damagedAmount'] as double),
                  r['handlingDisplay'],
                ])
            .toList(),
        summary: {
          'Damaged Units':
              rows.fold<int>(0, (s, r) => s + (r['damagedQty'] as int)),
          'Damaged Value': ReportExportService.formatCurrency(rows.fold<double>(
              0, (s, r) => s + (r['damagedAmount'] as double))),
        },
      ),
    );
  }
}
