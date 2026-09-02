import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Goods that arrived damaged, and what was decided about each.
///
/// Damaged units never entered stock, but they WERE billed: the receipt accrues
/// the full received value and `damagedHandling` does not change what is owed
/// (`grn_item_model_214.dart:24-27`). Handling only decides which document is
/// raised afterwards — a return or a settled claim carries its own credit, a
/// write-off carries none and stays a real cost. So this report measures
/// supplier quality and the value at stake, not inventory movement, and not
/// every line here is recoverable.
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
        // A double — goods are received by weight, and rows are filtered to
        // `damagedQty > 0`, so `as int` threw on every non-empty period.
        final qty = rows.fold<double>(
          0,
          (s, r) => s + (r['damagedQty'] as num).toDouble(),
        );
        final value = rows.fold<double>(
          0,
          (s, r) => s + (r['damagedAmount'] as double),
        );

        double qtyFor(String handling) => rows
            .where((r) => r['handling'] == handling)
            .fold<double>(0, (s, r) => s + (r['damagedQty'] as num).toDouble());

        return [
          ReportSummaryCard(
            title: 'Damaged',
            value: formatQty(qty),
            subtitle: '${rows.length} lines',
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.danger,
          ),
          ReportSummaryCard(
            title: 'Value',
            value: formatMoney(value),
            subtitle: 'billed, damage included',
            icon: Icons.payments_rounded,
            color: AppColors.warning,
          ),
          ReportSummaryCard(
            title: 'Written Off',
            value: formatQty(qtyFor('writeOff')),
            subtitle: 'a real loss',
            icon: Icons.delete_outline_rounded,
            color: AppColors.textSecondary,
          ),
        ];
      },
      // Damage on an unpriced line is valued at ₹0, so the Value card and any
      // return or claim raised from it understate the real exposure.
      detail: (context, rows) {
        final unpriced = rows.where((r) => r['costMissing'] == true).toList();
        if (unpriced.isEmpty) return const SizedBox.shrink();
        final names = unpriced.map((r) => r['productName']).toSet().join(', ');
        return ReportNotice(
          message: unpriced.length == 1
              ? 'One damaged line has no cost price ($names), so its value '
                    'shows ₹0.'
              : '${unpriced.length} damaged lines have no cost price ($names), '
                    'so their value shows ₹0.',
        );
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

        return DataRow(
          cells: [
            DataCell(
              Text(
                variant == null || variant.isEmpty
                    ? row['productName'] as String
                    : '${row['productName']} · $variant',
              ),
            ),
            DataCell(Text(row['supplierName'] as String)),
            DataCell(Text(row['grnNumber'] as String)),
            DataCell(Text(_date(row['receivedDate'] as String))),
            DataCell(Text(formatQty((row['damagedQty'] as num).toDouble()))),
            DataCell(Text(formatMoney(row['damagedAmount'] as double))),
            DataCell(
              AppStatusPill(
                dense: true,
                label: row['handlingDisplay'] as String,
                color: _handlingColors[handling] ?? AppColors.textSecondary,
              ),
            ),
          ],
        );
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
            .map(
              (r) => [
                r['productName'],
                r['variantInfo'] ?? '',
                r['supplierName'],
                r['grnNumber'],
                r['poNumber'],
                _date(r['receivedDate'] as String),
                exportQty((r['damagedQty'] as num).toDouble()),
                r['costPrice'] == null
                    ? ''
                    : ReportExportService.formatCurrency(
                        r['costPrice'] as double,
                      ),
                ReportExportService.formatCurrency(
                  r['damagedAmount'] as double,
                ),
                r['handlingDisplay'],
              ],
            )
            .toList(),
        summary: {
          'Damaged Units': formatQty(
            rows.fold<double>(
              0,
              (s, r) => s + (r['damagedQty'] as num).toDouble(),
            ),
          ),
          'Damaged Value': ReportExportService.formatCurrency(
            rows.fold<double>(0, (s, r) => s + (r['damagedAmount'] as double)),
          ),
        },
      ),
    );
  }
}
