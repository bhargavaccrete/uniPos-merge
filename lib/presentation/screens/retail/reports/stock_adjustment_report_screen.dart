import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Every manual stock correction, with who made it and why.
///
/// The point of this report is accountability, not valuation: it answers "why
/// is stock different from what the documents say". The money side of a
/// loss-bearing adjustment shows up in the Damaged Items report instead, so the
/// two never disagree about the cost.
class StockAdjustmentReportScreen extends StatelessWidget {
  const StockAdjustmentReportScreen({super.key});

  String _dateTime(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Stock Adjustments',
      subtitle: 'Manual stock corrections',
      featureNoun: 'adjustments',
      exportFileName: 'stock_adjustments',
      rowUnit: 'adjustments',
      emptyIcon: Icons.tune_rounded,
      emptyTitle: 'No stock adjustments',
      emptyMessage:
          'Stock corrections made from a product\'s variant menu appear here.',
      loader: (start, end) =>
          service.getStockAdjustmentReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        // COUNTS, not summed quantities. Adding 2.5 kg to 3 pieces and
        // showing "5.5 units" is a figure with no meaning — the rows carry
        // whatever unit their variant uses. Counting the corrections answers
        // what this report is for: how often stock was changed by hand, and in
        // which direction.
        final added = rows.where((r) => r['isIn'] as bool).length;
        final removed = rows.where((r) => !(r['isIn'] as bool)).length;

        return [
          ReportSummaryCard(
            title: 'Adjustments',
            value: '${rows.length}',
            subtitle: 'in this period',
            icon: Icons.tune_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Adjustments Added',
            value: '$added',
            subtitle: 'stock increased',
            icon: Icons.trending_up_rounded,
            color: added > 0 ? AppColors.success : AppColors.textSecondary,
          ),
          ReportSummaryCard(
            title: 'Adjustments Removed',
            value: '$removed',
            subtitle: 'stock decreased',
            icon: Icons.trending_down_rounded,
            color: removed > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Product'),
        ReportTable.column(context, 'Reason'),
        ReportTable.column(context, 'By'),
        ReportTable.column(context, 'Before', numeric: true),
        ReportTable.column(context, 'Change', numeric: true),
        ReportTable.column(context, 'After', numeric: true),
      ],
      rowBuilder: (context, row) {
        final isIn = row['isIn'] as bool;
        // A double: a loose-goods variant is corrected by weight.
        final signed = (row['signedQuantity'] as num).toDouble();
        final unit = row['unit'] as String? ?? '';
        final note = row['note'] as String;

        return DataRow(
          cells: [
            DataCell(Text(_dateTime(row['timestamp'] as String))),
            DataCell(
              Tooltip(
                // The note is the detail behind the reason; surfacing it on
                // hover keeps the table narrow without losing it.
                message: note.isEmpty ? '' : note,
                child: Text(row['itemName'] as String),
              ),
            ),
            DataCell(Text(row['reason'] as String)),
            DataCell(Text(row['staffName'] as String)),
            DataCell(
              Text(
                formatQtyWithUnit(
                  (row['balanceBefore'] as num).toDouble(),
                  unit,
                ),
              ),
            ),
            DataCell(
              Text(
                // formatQty already carries the minus on a decrease.
                isIn
                    ? '+${formatQtyWithUnit(signed, unit)}'
                    : formatQtyWithUnit(signed, unit),
                style: GoogleFonts.poppins(
                  color: isIn ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(
              Text(
                formatQtyWithUnit(
                  (row['balanceAfter'] as num).toDouble(),
                  unit,
                ),
              ),
            ),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'Date',
          'Product',
          'Reason',
          'Adjusted By',
          'Stock Before',
          'Change',
          'Stock After',
          'Unit',
          'Note',
        ],
        rows: rows
            .map(
              (r) => [
                _dateTime(r['timestamp'] as String),
                r['itemName'],
                r['reason'],
                r['staffName'],
                exportQty((r['balanceBefore'] as num).toDouble()),
                exportQty((r['signedQuantity'] as num).toDouble()),
                exportQty((r['balanceAfter'] as num).toDouble()),
                r['unit'] ?? '',
                r['note'],
              ],
            )
            .toList(),
        summary: {
          'Adjustments': rows.length,
          // Counts, matching the cards — quantities across mixed units are not
          // summable into one figure.
          'Adjustments Added': rows.where((r) => r['isIn'] as bool).length,
          'Adjustments Removed': rows.where((r) => !(r['isIn'] as bool)).length,
        },
      ),
    );
  }
}
