import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Variants running low on stock.
///
/// The only retail report with **no date dimension** — stock is a level, not an
/// event — so it uses the kit pieces directly instead of [ReportPageScaffold],
/// and swaps the period bar for a generic [ReportFilterBar] over the threshold.
///
/// The threshold is only a *fallback*: `getLowStockReport` flags a variant on
/// its own `minStock` when it has one, and falls back to this number when it
/// doesn't. So changing it won't affect variants that carry their own reorder
/// point.
class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({super.key});

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  static const int _rowsPerPage = 50;

  /// Below this, a row reads as critical rather than merely low.
  static const int _criticalAt = 3;

  final ReportService _reportService = ReportService();

  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = true;
  int _threshold = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _reportService.getLowStockReport(threshold: _threshold);
    if (!mounted) return;
    setState(() {
      _reportData = data;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  void _onThresholdChanged(int value) {
    setState(() => _threshold = value);
    _loadReport();
  }

  /// Red once a variant is nearly gone, amber while it is merely low.
  Color _severityColor(int stock) =>
      stock <= _criticalAt ? AppColors.danger : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Low Stock Alert',
        subtitle: 'Threshold ≤ $_threshold',
      ),
      body: MoneyScope(
        child: Column(
          children: [
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            ReportFilterBar<int>(
              selected: _threshold,
              onSelected: _onThresholdChanged,
              options: const [
                ReportFilterOption(
                    value: 5, label: '≤ 5', icon: Icons.priority_high_rounded),
                ReportFilterOption(
                    value: 10, label: '≤ 10', icon: Icons.tune_rounded),
                ReportFilterOption(
                    value: 20, label: '≤ 20', icon: Icons.inventory_2_outlined),
              ],
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const ReportLoading();

    if (_reportData.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All products are well stocked',
        message: 'Nothing is at or below its reorder point.',
      );
    }

    final outOfStock =
        _reportData.where((r) => (r['currentStock'] as int) <= 0).length;
    final critical = _reportData
        .where((r) =>
            (r['currentStock'] as int) > 0 &&
            (r['currentStock'] as int) <= _criticalAt)
        .length;

    final pageRows =
        ReportPagination.pageSlice(_reportData, _currentPage, _rowsPerPage);

    return ReportBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportSummaryRow(cards: [
            ReportSummaryCard(
              title: 'Low Stock',
              value: '${_reportData.length}',
              subtitle: 'variants flagged',
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
            ),
            ReportSummaryCard(
              title: 'Out of Stock',
              value: '$outOfStock',
              subtitle: 'nothing left',
              icon: Icons.remove_shopping_cart_rounded,
              color: outOfStock > 0 ? AppColors.danger : AppColors.textSecondary,
            ),
            ReportSummaryCard(
              title: 'Critical',
              value: '$critical',
              subtitle: '≤ $_criticalAt left',
              icon: Icons.priority_high_rounded,
              color: critical > 0 ? AppColors.danger : AppColors.textSecondary,
            ),
          ]),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: _export),
          AppResponsive.verticalSpace(context),
          ReportTable(
            showCheckboxColumn: false,
            columns: [
              ReportTable.column(context, 'Product'),
              ReportTable.column(context, 'Variant'),
              ReportTable.column(context, 'Stock', numeric: true),
              ReportTable.column(context, 'Reorder At', numeric: true),
              ReportTable.column(context, 'Cost', numeric: true),
            ],
            rows: pageRows.map(_buildRow).toList(),
          ),
          ReportPagination(
            currentPage: _currentPage,
            rowsPerPage: _rowsPerPage,
            totalCount: _reportData.length,
            unit: 'variants',
            onPageChanged: (page) => setState(() => _currentPage = page),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> item) {
    final stock = item['currentStock'] as int;
    final costPrice = (item['costPrice'] as num?)?.toDouble();
    final color = _severityColor(stock);

    return DataRow(cells: [
      DataCell(Text(item['productName'] as String? ?? 'Unknown Product')),
      DataCell(Text((item['variantLabel'] as String?)?.isNotEmpty == true
          ? item['variantLabel'] as String
          : '—')),
      DataCell(Text(
        '$stock',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      )),
      DataCell(Text('${item['reorderPoint']}')),
      DataCell(Text(costPrice == null ? '—' : formatMoney(costPrice))),
    ]);
  }

  Future<void> _export() async {
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'low_stock_alert',
      reportTitle: 'Low Stock Alert',
      headers: const [
        'Product',
        'Variant',
        'Barcode',
        'Current Stock',
        'Reorder At',
        'Cost Price',
        'MRP',
      ],
      data: _reportData
          .map((r) => [
                r['productName'],
                r['variantLabel'] ?? '',
                r['barcode'] ?? '',
                r['currentStock'],
                r['reorderPoint'],
                r['costPrice'] == null
                    ? ''
                    : ReportExportService.formatCurrency(
                        (r['costPrice'] as num).toDouble()),
                r['mrp'] == null
                    ? ''
                    : ReportExportService.formatCurrency(
                        (r['mrp'] as num).toDouble()),
              ])
          .toList(),
      summary: {
        'Threshold': '≤ $_threshold',
        'Variants Flagged': _reportData.length,
        'Out of Stock':
            _reportData.where((r) => (r['currentStock'] as int) <= 0).length,
        'Generated': ReportExportService.formatDateTime(DateTime.now()),
      },
    );
  }
}
