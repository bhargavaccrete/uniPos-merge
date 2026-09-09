import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

/// Every movement of cash through the drawer over a period.
///
/// The live Cash Drawer screen only ever shows today; once a day closes there
/// was no way to look back at its ledger. Both build the ledger from
/// `CashDrawerLedger`, so a row here means exactly what it meant there.
class CashDrawerHistoryReportScreen extends StatelessWidget {
  const CashDrawerHistoryReportScreen({super.key});

  static const _typeColors = {
    'Sale': AppColors.success,
    'Cash In': AppColors.success,
    'Refund': AppColors.danger,
    'Cash Out': AppColors.danger,
    'Expense': AppColors.warning,
  };

  double _sumOf(List<Map<String, dynamic>> rows, bool Function(double) keep) =>
      rows.fold<double>(0, (sum, r) {
        final amount = (r['amount'] as num).toDouble();
        return keep(amount) ? sum + amount : sum;
      });

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Cash Drawer History',
      subtitle: 'Cash in and out over time',
      featureNoun: 'drawer activity',
      exportFileName: 'cash_drawer_history',
      rowUnit: 'movements',
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyTitle: 'No drawer activity',
      emptyMessage: 'No cash moved through the drawer in this period.',
      loader: (start, end) =>
          service.getCashDrawerReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final moneyIn = _sumOf(rows, (a) => a > 0);
        // Stored negative, shown positive — "Cash Out ₹500" reads better than
        // "Cash Out −₹500" next to a Cash In of the same sign convention.
        final moneyOut = _sumOf(rows, (a) => a < 0).abs();
        final net = moneyIn - moneyOut;

        return [
          ReportSummaryCard(
            title: 'Cash In',
            value: formatMoney(moneyIn),
            subtitle: 'sales, collections, pay-ins',
            icon: Icons.south_west_rounded,
            color: AppColors.success,
          ),
          ReportSummaryCard(
            title: 'Cash Out',
            value: formatMoney(moneyOut),
            subtitle: 'refunds, expenses, pay-outs',
            icon: Icons.north_east_rounded,
            color: AppColors.danger,
          ),
          ReportSummaryCard(
            title: 'Net Movement',
            value: formatMoney(net),
            subtitle: 'excludes opening float',
            icon: Icons.account_balance_wallet_rounded,
            color: net >= 0 ? AppColors.primary : AppColors.danger,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'When'),
        ReportTable.column(context, 'Type'),
        ReportTable.column(context, 'Details'),
        ReportTable.column(context, 'Amount', numeric: true),
      ],
      rowBuilder: (context, row) {
        final amount = (row['amount'] as num).toDouble();
        final type = row['type'] as String;
        final isOut = amount < 0;

        return DataRow(
          cells: [
            DataCell(
              Text(DateFormat('dd MMM, h:mm a').format(row['at'] as DateTime)),
            ),
            DataCell(
              AppStatusPill(
                label: type,
                color: _typeColors[type] ?? AppColors.textSecondary,
                dense: true,
              ),
            ),
            DataCell(Text(row['description'] as String)),
            DataCell(
              Text(
                formatMoney(amount.abs()),
                style: GoogleFonts.poppins(
                  color: isOut ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
          ],
        );
      },
      exportData: (rows) {
        final moneyIn = _sumOf(rows, (a) => a > 0);
        final moneyOut = _sumOf(rows, (a) => a < 0).abs();

        return ReportExportData(
          headers: const ['When', 'Type', 'Details', 'Reference', 'Amount'],
          // Signed in the export so a spreadsheet can total the column
          // directly, unlike the screen where direction is carried by colour.
          rows: rows
              .map(
                (r) => [
                  ReportExportService.formatDateTime(r['at'] as DateTime),
                  r['type'],
                  r['description'],
                  r['reference'],
                  ReportExportService.formatCurrency(
                    (r['amount'] as num).toDouble(),
                  ),
                ],
              )
              .toList(),
          summary: {
            'Movements': rows.length,
            'Cash In': ReportExportService.formatCurrency(moneyIn),
            'Cash Out': ReportExportService.formatCurrency(moneyOut),
            'Net Movement': ReportExportService.formatCurrency(
              moneyIn - moneyOut,
            ),
          },
        );
      },
    );
  }
}
