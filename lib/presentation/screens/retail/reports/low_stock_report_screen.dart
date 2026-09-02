import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';
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

  final ReportService _reportService = ReportService();
  final StockAlertService _alertService = StockAlertService();

  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = true;

  /// Seeded from the STORED Stock Alert threshold — the same value Settings and
  /// the Stock Alerts screen write. This screen used to hard-code 10 and offer
  /// its own `[5, 10, 20]`, so a store configured at 25 opened the report at 10
  /// and could not even select 25. `StockAlertService` centralises both.
  int _threshold = StockAlertService.defaultThreshold;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final stored = await _alertService.getThreshold();
    if (!mounted) return;
    setState(() => _threshold = stored);
    await _loadReport();
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
  ///
  /// The rule is [StockAlertService.isCritical], NOT a constant of this
  /// screen's own — a third of the row's reorder point, floored at 1. The old
  /// `stock <= 3` marked a variant that reorders at 2 as critical forever and
  /// left one that reorders at 30 amber at 8, so this report and the Stock
  /// Alerts card disagreed about the very same rows.
  Color _severityColor(Map<String, dynamic> row) =>
      StockAlertService.isCritical(row)
          ? AppColors.danger
          : AppColors.warning;

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
              // The ONE list. Settings and the Stock Alerts screen already
              // share it; this screen offering a third had reintroduced the
              // exact drift that centralising it was meant to end.
              options: [
                for (final value in StockAlertService.thresholdOptions)
                  ReportFilterOption(
                    value: value,
                    label: '≤ $value',
                    icon: Icons.tune_rounded,
                  ),
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

    // `num`, not `int` — a loose-goods variant carries a fractional stock and
    // a hard int cast threw as soon as one was flagged.
    final outOfStock = _reportData.where((r) => _stockOf(r) <= 0).length;
    // Same predicate the Stock Alerts card counts with, so the two tiles can
    // never report different numbers over the same rows.
    final critical = _reportData.where(StockAlertService.isCritical).length;

    final pageRows = ReportPagination.pageSlice(
      _reportData,
      _currentPage,
      _rowsPerPage,
    );

    return ReportBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportSummaryRow(
            cards: [
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
                color: outOfStock > 0
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
              ReportSummaryCard(
                title: 'Critical',
                value: '$critical',
                subtitle: 'at a third of reorder point',
                icon: Icons.priority_high_rounded,
                color: critical > 0
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
            ],
          ),
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

  /// Reads a report row's stock as a double. One helper so no call site can
  /// reintroduce a hard `as int` and crash on a decimal variant.
  static double _stockOf(Map<String, dynamic> row) =>
      (row['currentStock'] as num?)?.toDouble() ?? 0;

  DataRow _buildRow(Map<String, dynamic> item) {
    final stock = _stockOf(item);
    final costPrice = (item['costPrice'] as num?)?.toDouble();
    final isBundle = item['isBundle'] == true;
    final color = _severityColor(item);

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  item['productName'] as String? ?? 'Unknown Product',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBundle) ...[const SizedBox(width: 6), _bundleBadge()],
            ],
          ),
        ),
        DataCell(
          Text(
            (item['variantLabel'] as String?)?.isNotEmpty == true
                ? item['variantLabel'] as String
                : '—',
          ),
        ),
        DataCell(
          Tooltip(
            message: isBundle
                ? 'Available to sell (bundle — bounded by component stock)'
                : 'Current stock',
            child: Text(
              formatQty(stock),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
        // `formatQty`, not the raw value: a variant-level reorder point is a
        // double and used to render "5.0" beside a global fallback's "10".
        DataCell(
          Text(formatQty((item['reorderPoint'] as num).toDouble())),
        ),
        DataCell(Text(costPrice == null ? '—' : formatMoney(costPrice))),
      ],
    );
  }

  /// Marks a row whose "Stock" figure is actually "Available to Sell" — a
  /// bundle has no stock of its own, so the number means something different
  /// from every other row's. See docs/retail_inventory_system_plan.md §3.3.
  Widget _bundleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Bundle',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.info,
        ),
      ),
    );
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
          .map(
            (r) => [
              r['productName'],
              r['variantLabel'] ?? '',
              r['barcode'] ?? '',
              // `exportQty`, so Excel keeps a numeric cell while the PDF —
              // which calls toString() — stops printing "3.0".
              exportQty((r['currentStock'] as num).toDouble()),
              exportQty((r['reorderPoint'] as num).toDouble()),
              r['costPrice'] == null
                  ? ''
                  : ReportExportService.formatCurrency(
                      (r['costPrice'] as num).toDouble(),
                    ),
              r['mrp'] == null
                  ? ''
                  : ReportExportService.formatCurrency(
                      (r['mrp'] as num).toDouble(),
                    ),
            ],
          )
          .toList(),
      summary: {
        'Threshold': '≤ $_threshold',
        'Variants Flagged': _reportData.length,
        'Out of Stock': _reportData.where((r) => _stockOf(r) <= 0).length,
        'Generated': ReportExportService.formatDateTime(DateTime.now()),
      },
    );
  }
}
