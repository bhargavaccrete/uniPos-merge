import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';

/// Spend per supplier, measured on goods actually received.
///
/// Previously this summed `estimatedTotal` across every purchase order with no
/// status filter, so drafts and cancelled orders counted and the number was an
/// estimate. It now reads confirmed GRNs at accepted value.
class SupplierWisePurchaseReportScreen extends StatelessWidget {
  const SupplierWisePurchaseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Supplier-wise Purchases',
      subtitle: 'Based on goods received',
      featureNoun: 'purchases',
      exportFileName: 'supplier_wise_purchases',
      rowUnit: 'suppliers',
      emptyIcon: Icons.local_shipping_outlined,
      emptyTitle: 'No purchases received',
      emptyMessage:
          'Nothing has been received from any supplier in this period.',
      loader: (start, end) =>
          service.getSupplierWisePurchaseReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final total =
            rows.fold<double>(0, (s, r) => s + (r['totalAmount'] as double));
        final damaged =
            rows.fold<double>(0, (s, r) => s + (r['damagedAmount'] as double));
        return [
          ReportSummaryCard(
            title: 'Total Received',
            value: formatMoney(total),
            subtitle: '${rows.length} suppliers',
            icon: Icons.storefront_rounded,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Damaged',
            value: formatMoney(damaged),
            subtitle: 'excluded from spend',
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.danger,
          ),
        ];
      },
      columns: (context) => [
        ReportTable.column(context, 'Supplier'),
        ReportTable.column(context, 'Receipts', numeric: true),
        ReportTable.column(context, 'Units', numeric: true),
        ReportTable.column(context, 'Damaged', numeric: true),
        ReportTable.column(context, 'Amount', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(cells: [
        DataCell(Text(row['supplierName'] as String)),
        DataCell(Text('${row['receiptCount']}')),
        DataCell(Text('${row['totalItems']}')),
        DataCell(Text(formatMoney(row['damagedAmount'] as double))),
        DataCell(Text(formatMoney(row['totalAmount'] as double))),
      ]),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Supplier',
          'Receipts',
          'Units',
          'Damaged Value',
          'Amount'
        ],
        rows: rows
            .map((r) => [
                  r['supplierName'],
                  r['receiptCount'],
                  r['totalItems'],
                  ReportExportService.formatCurrency(
                      r['damagedAmount'] as double),
                  ReportExportService.formatCurrency(
                      r['totalAmount'] as double),
                ])
            .toList(),
        summary: {
          'Suppliers': rows.length,
          'Total Received': ReportExportService.formatCurrency(
              rows.fold<double>(0, (s, r) => s + (r['totalAmount'] as double))),
        },
      ),
    );
  }
}
