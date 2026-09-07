import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:billberrylite/util/common/short_ref.dart';

/// Every credit note raised in the period, with what it was for and what
/// actually left the till.
///
/// The point of this report is accountability. Refunds are the one counter
/// operation that moves money outward on a cashier's say-so, and until now they
/// were only ever visible as a single netted total on Daily/Monthly — the Cash
/// Drawer history came closest and silently omitted card and UPI refunds.
///
/// **Returned Value and Paid Out are deliberately two different figures.** Value
/// can come back without money going out: a refund against an unpaid invoice
/// cancels a debt, and an exchange sends most of the value straight into a
/// replacement sale. Showing only one of the two would misread either the goods
/// or the cash.
class SalesRefundReportScreen extends StatelessWidget {
  const SalesRefundReportScreen({super.key});

  String _dateTime(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(d);
  }

  double _sum(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(0, (s, r) => s + ((r[key] as num?) ?? 0).toDouble());

  /// The method a refund went out by. An exchange whose money leg is the
  /// `exchange_credit` sentinel had nothing change hands, and rendering that
  /// raw would read as a payment type the shop does not have.
  String _method(Map<String, dynamic> row) {
    final method = row['refundMethod'] as String? ?? '';
    if (ExchangeService.isExchangeCredit(method)) return 'GOODS';
    return method.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Sales Refunds',
      subtitle: 'Returns, refunds and reasons',
      featureNoun: 'refunds',
      exportFileName: 'sales_refunds',
      rowUnit: 'refunds',
      emptyIcon: Icons.check_circle_outline,
      emptyTitle: 'No refunds',
      emptyMessage: 'Nothing was returned or refunded in this period.',
      loader: (start, end) =>
          service.getSalesRefundReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        // Exchange legs are listed but kept out of the money totals: their value
        // crossed to a replacement sale rather than leaving the till. Same
        // carve-out `EODReportService.cashRefundsIn` already makes, so the two
        // never disagree about what a refund was.
        final plain = rows.where((r) => !(r['isExchange'] as bool)).toList();
        final exchanges = rows.length - plain.length;

        return [
          ReportSummaryCard(
            title: 'Refunds',
            value: '${plain.length}',
            subtitle: '${formatQty(_sum(plain, 'totalItems'))} units back',
            icon: Icons.assignment_return_rounded,
            color: AppColors.danger,
          ),
          ReportSummaryCard(
            title: 'Returned Value',
            value: formatMoney(_sum(plain, 'refundValue')),
            subtitle: exchanges > 0
                ? '$exchanges exchange${exchanges == 1 ? '' : 's'} excluded'
                : 'goods came back',
            icon: Icons.inventory_2_rounded,
            color: AppColors.warning,
          ),
          ReportSummaryCard(
            title: 'Paid Out',
            value: formatMoney(_sum(plain, 'paidOut')),
            subtitle:
                '${formatMoney(_sum(plain, 'appliedToDue'))} off dues',
            icon: Icons.money_off_rounded,
            color: AppColors.info,
          ),
        ];
      },
      detail: (context, rows) {
        final exchanges = rows.where((r) => r['isExchange'] as bool).length;
        if (exchanges == 0) return const SizedBox.shrink();
        return ReportNotice(
          message:
              '$exchanges of these are exchange legs. Most of that value '
              'crossed to a replacement sale rather than leaving the till — '
              'see the Paid Out column.',
          icon: Icons.swap_horiz_rounded,
        );
      },
      columns: (context) => [
        ReportTable.column(context, 'Refund'),
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Original'),
        ReportTable.column(context, 'Customer'),
        ReportTable.column(context, 'Reason'),
        ReportTable.column(context, 'Method'),
        ReportTable.column(context, 'Type'),
        ReportTable.column(context, 'Items', numeric: true),
        ReportTable.column(context, 'Refunded', numeric: true),
        ReportTable.column(context, 'Paid Out', numeric: true),
      ],
      rowBuilder: (context, row) {
        final isExchange = row['isExchange'] as bool;
        final original = row['originalSaleId'] as String?;

        return DataRow(
          cells: [
            DataCell(Text(saleRef(row['returnSaleId'] as String))),
            DataCell(Text(_dateTime(row['date'] as String))),
            DataCell(
              Text(original == null ? '—' : saleRef(original)),
            ),
            DataCell(Text(row['customerName'] as String)),
            DataCell(Text(row['returnReasonLabel'] as String)),
            DataCell(Text(_method(row))),
            DataCell(
              AppStatusPill(
                dense: true,
                label: isExchange ? 'Exchange' : 'Refund',
                color: isExchange ? AppColors.info : AppColors.danger,
              ),
            ),
            DataCell(Text(formatQty((row['totalItems'] as num).toDouble()))),
            DataCell(Text(formatMoney(row['refundValue'] as double))),
            DataCell(Text(formatMoney(row['paidOut'] as double))),
          ],
        );
      },
      exportData: (rows) {
        final plain = rows.where((r) => !(r['isExchange'] as bool)).toList();

        return ReportExportData(
          headers: const [
            'Refund ID',
            'Date',
            'Original Sale',
            'Original Date',
            'Days To Return',
            'Customer',
            'Reason',
            'Note',
            'Method',
            'Type',
            'Items',
            'Subtotal',
            'Discount',
            'Tax',
            'Refund Value',
            'Applied To Due',
            'Paid Out',
            'Exchange Group',
            'Processed By',
          ],
          rows: rows.map((r) {
            final originalDate = r['originalSaleDate'] as String?;
            return [
              r['returnSaleId'],
              _dateTime(r['date'] as String),
              r['originalSaleId'] ?? '',
              originalDate == null ? '' : _dateTime(originalDate),
              r['daysToReturn'] ?? '',
              r['customerName'],
              r['returnReasonLabel'],
              r['returnNote'] ?? '',
              _method(r),
              (r['isExchange'] as bool) ? 'Exchange' : 'Refund',
              exportQty((r['totalItems'] as num).toDouble()),
              ReportExportService.formatCurrency(r['subtotal'] as double),
              ReportExportService.formatCurrency(r['discountAmount'] as double),
              ReportExportService.formatCurrency(r['taxAmount'] as double),
              ReportExportService.formatCurrency(r['refundValue'] as double),
              ReportExportService.formatCurrency(r['appliedToDue'] as double),
              ReportExportService.formatCurrency(r['paidOut'] as double),
              r['exchangeGroupId'] ?? '',
              r['staffName'],
            ];
          }).toList(),
          summary: {
            'Refunds': plain.length,
            'Exchange Legs': rows.length - plain.length,
            'Returned Value': ReportExportService.formatCurrency(
              _sum(plain, 'refundValue'),
            ),
            'Applied To Due': ReportExportService.formatCurrency(
              _sum(plain, 'appliedToDue'),
            ),
            'Paid Out': ReportExportService.formatCurrency(
              _sum(plain, 'paidOut'),
            ),
          },
        );
      },
    );
  }
}
