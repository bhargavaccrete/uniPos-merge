import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

({int added, int removed, int losses}) stockAdjustmentTotals(
  List<Map<String, dynamic>> rows,
) {
  var added = 0;
  var removed = 0;
  var losses = 0;
  for (final r in rows) {
    if (r['isIn'] == true) {
      added++;
    } else {
      removed++;
      if (r['isLossReason'] == true) losses++;
    }
  }
  return (added: added, removed: removed, losses: losses);
}

Map<String, dynamic> stockAdjustmentExportSummary(
  List<Map<String, dynamic>> rows,
) {
  final t = stockAdjustmentTotals(rows);
  return {
    'Adjustments': rows.length,
    'Stock Added': t.added,
    'Stock Removed': t.removed,
    'Loss-bearing Removals': t.losses,
  };
}

/// Every manual stock correction — who changed what, why, and by how much.
///
/// **Accountability, not valuation.** The cards count adjustments rather than
/// summing quantities: rows mix units, and "5.5 units" across kg and pcs is a
/// meaningless figure. Value belongs to the Food Cost report.
///
/// "Manual" is defined by exclusion in
/// `RestaurantPurchaseReportService.isManualAdjustment` — anything not written
/// by a sale, production run, receipt, void or opening balance. That way a new
/// reason added to the adjust dialog shows up here automatically instead of
/// silently going missing.
class RestaurantStockAdjustmentReportScreen extends StatelessWidget {
  const RestaurantStockAdjustmentReportScreen({super.key});

  String _dateTime(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy, HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final service = RestaurantPurchaseReportService();

    return ReportPageScaffold(
      title: 'Stock Adjustments',
      subtitle: 'Manual corrections to stock on hand',
      featureNoun: 'adjustments',
      exportFileName: 'restaurant_stock_adjustments',
      rowUnit: 'adjustments',
      emptyIcon: Icons.tune_rounded,
      emptyTitle: 'No adjustments',
      emptyMessage: 'Stock was not corrected by hand in this period.',
      loader: (start, end) =>
          service.getStockAdjustmentReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final t = stockAdjustmentTotals(rows);
        return [
          ReportSummaryCard(
            title: 'Adjustments',
            value: '${rows.length}',
            icon: Icons.tune_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Stock Added',
            value: '${t.added}',
            // Counts, not quantities — see the class doc.
            subtitle: 'corrections up',
            icon: Icons.add_circle_outline_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Stock Removed',
            value: '${t.removed}',
            subtitle: t.losses > 0
                ? '${t.losses} recorded as loss'
                : 'corrections down',
            icon: Icons.remove_circle_outline_rounded,
            color: t.removed > 0 ? AppColors.warning : AppColors.textSecondary,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Item'),
        ReportTable.column(context, 'Reason'),
        ReportTable.column(context, 'By'),
        ReportTable.column(context, 'Before', numeric: true),
        ReportTable.column(context, 'Change', numeric: true),
        ReportTable.column(context, 'After', numeric: true),
      ],
      rowBuilder: (context, row) {
        final isIn = row['isIn'] == true;
        final qty = (row['quantity'] as num).toDouble();
        final unit = row['unit'] as String;
        final note = row['note'] as String?;

        return DataRow(
          cells: [
            DataCell(Text(_dateTime(row['timestamp'] as String))),
            DataCell(
              // The note explains the correction, so it rides along as a
              // tooltip rather than stealing a column.
              Tooltip(
                message: note == null || note.isEmpty ? '' : note,
                child: Text(row['itemName'] as String),
              ),
            ),
            DataCell(Text(row['reason'] as String)),
            DataCell(Text(row['staffName'] as String)),
            DataCell(
              Text(formatQtyWithUnit(
                  (row['balanceBefore'] as num).toDouble(), unit)),
            ),
            DataCell(
              Text(
                '${isIn ? '+' : '-'}${formatQtyWithUnit(qty, unit)}',
                style: GoogleFonts.poppins(
                  color: isIn ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(
              Text(formatQtyWithUnit(
                  (row['balanceAfter'] as num).toDouble(), unit)),
            ),
          ],
        );
      },
      exportData: (rows) => ReportExportData(
        headers: const [
          'Date',
          'Item',
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
                r['unit'],
                r['note'] ?? '',
              ],
            )
            .toList(),
        summary: stockAdjustmentExportSummary(rows),
      ),
    );
  }
}
