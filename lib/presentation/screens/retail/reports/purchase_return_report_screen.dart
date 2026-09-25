import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Goods sent back to suppliers, and where each credit note stands.
///
/// **This is money owed, not paperwork.** The GRN billed the full received
/// quantity, damaged units included (`purchase_return_model_174.dart:22-27`),
/// so a return is the claim to recover that value. The supplier balance moves
/// when the CREDIT NOTE is recorded, not when the return is raised — which is
/// why a return can sit here pending, be credited later, or be cancelled
/// without ever being recovered. Value returned is not value recovered.
class PurchaseReturnReportScreen extends StatelessWidget {
  const PurchaseReturnReportScreen({super.key});

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  PurchaseReturnStatus _statusOf(String raw) =>
      PurchaseReturnStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PurchaseReturnStatus.pending,
      );

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Purchase Returns',
      subtitle: 'Returned to supplier',
      featureNoun: 'returns',
      exportFileName: 'purchase_returns',
      rowUnit: 'returns',
      emptyIcon: Icons.assignment_return_outlined,
      emptyTitle: 'No purchase returns',
      emptyMessage: 'Nothing was returned to a supplier in this period.',
      loader: (start, end) =>
          service.getPurchaseReturnReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        // A cancelled return means the goods never went back —
        // `cancelPurchaseReturn` moves no supplier balance for exactly that
        // reason, and `_damagedRecoveryByGRN` treats it as absorbed cost. So
        // neither its value NOR its units were ever returned. The rows stay
        // visible as history; only the totals exclude them.
        final returned = rows
            .where((r) => r['status'] != PurchaseReturnStatus.cancelled.name)
            .toList();
        final value = returned.fold<double>(
          0,
          (s, r) => s + (r['totalAmount'] as double),
        );
        final pending = rows
            .where((r) => r['status'] == PurchaseReturnStatus.pending.name)
            .toList();
        final pendingValue = pending.fold<double>(
          0,
          (s, r) => s + (r['totalAmount'] as double),
        );

        return [
          ReportSummaryCard(
            title: 'Returns',
            value: '${rows.length}',
            subtitle:
                '${formatQty(returned.fold<double>(0, (s, r) => s + (r['totalQty'] as num).toDouble()))} units',
            icon: Icons.assignment_return_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Value',
            value: formatMoney(value),
            subtitle: 'returned goods',
            icon: Icons.payments_rounded,
            color: AppColors.info,
          ),
          ReportSummaryCard(
            title: 'Awaiting Credit',
            value: formatMoney(pendingValue),
            subtitle: '${pending.length} open',
            icon: Icons.hourglass_top_rounded,
            color: pending.isEmpty ? AppColors.success : AppColors.warning,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Return'),
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'GRN'),
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Qty', numeric: true),
        ReportTable.column(context, 'Value', numeric: true),
        ReportTable.column(context, 'Credit Note'),
        ReportTable.column(context, 'Status'),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(row['returnNumber'] as String)),
          DataCell(Text(row['supplierName'] as String)),
          DataCell(Text(row['grnNumber'] as String)),
          DataCell(Text(_date(row['returnDate'] as String))),
          DataCell(Text(formatQty((row['totalQty'] as num).toDouble()))),
          DataCell(Text(formatMoney(row['totalAmount'] as double))),
          DataCell(Text(row['creditNoteNumber'] as String? ?? '—')),
          DataCell(
            AppStatusPill(
              dense: true,
              label: row['statusDisplay'] as String,
              color: purchaseReturnStatusColor(
                _statusOf(row['status'] as String),
              ),
            ),
          ),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Return Number',
          'Supplier',
          'GRN',
          'PO',
          'Date',
          'Qty',
          'Value',
          'Status',
          'Credit Note',
          'Credit Amount',
        ],
        rows: rows
            .map(
              (r) => [
                r['returnNumber'],
                r['supplierName'],
                r['grnNumber'],
                r['poNumber'],
                _date(r['returnDate'] as String),
                exportQty((r['totalQty'] as num).toDouble()),
                ReportExportService.formatCurrency(r['totalAmount'] as double),
                r['statusDisplay'],
                r['creditNoteNumber'] ?? '',
                r['creditNoteAmount'] == null
                    ? ''
                    : ReportExportService.formatCurrency(
                        r['creditNoteAmount'] as double,
                      ),
              ],
            )
            .toList(),
        summary: {
          'Returns': rows.length,
          // Cancelled returns are listed above but never went back, so they are
          // out of the value total — see the summary card.
          'Total Value': ReportExportService.formatCurrency(
            rows
                .where(
                  (r) => r['status'] != PurchaseReturnStatus.cancelled.name,
                )
                .fold<double>(0, (s, r) => s + (r['totalAmount'] as double)),
          ),
        },
      ),
    );
  }
}
