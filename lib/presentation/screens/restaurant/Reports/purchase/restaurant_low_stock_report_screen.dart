import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// Items at or below their reorder point, right now.
///
/// **Composed from the report kit rather than `ReportPageScaffold`**, which is
/// for range-based reports. Stock is a level, not an event: there is no period
/// to filter by, and the plan's history window deliberately does not apply.
///
/// Recipe-Based items are measured on how many their ingredients can make —
/// a Burger with a full pantry is not low, whatever its unused
/// `stockQuantity` says.
///
/// Read-only. The **Low Stock screen** under Inventory
/// (`inventory/low_stock_screen.dart`) is the one that restocks; this is its
/// reporting counterpart, so neither is a duplicate of the other.
class RestaurantLowStockReportScreen extends StatefulWidget {
  const RestaurantLowStockReportScreen({super.key});

  @override
  State<RestaurantLowStockReportScreen> createState() =>
      _RestaurantLowStockReportScreenState();
}

class _RestaurantLowStockReportScreenState
    extends State<RestaurantLowStockReportScreen> {
  static const int _rowsPerPage = 50;

  final _service = RestaurantPurchaseReportService();
  List<Map<String, dynamic>>? _rows;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _service.getLowStockReport();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _page = 0;
    });
  }

  void _export(List<Map<String, dynamic>> rows) {
    ReportExportService.showExportDialog(
      context: context,
      fileName: 'restaurant_low_stock',
      reportTitle: 'Low Stock Report',
      headers: const [
        'Item',
        'Variant',
        'Current Stock',
        'Reorder At',
        'Unit',
        'Cost',
        'Status',
      ],
      data: rows
          .map(
            (r) => [
              r['itemName'],
              r['variantName'] ?? '',
              exportQty((r['currentStock'] as num).toDouble()),
              exportQty((r['reorderPoint'] as num).toDouble()),
              r['unit'],
              ReportExportService.formatCurrency(
                  (r['costPrice'] as num).toDouble()),
              r['isOut'] == true ? 'Out of Stock' : 'Low',
            ],
          )
          .toList(),
      summary: {
        'Items Flagged': rows.length,
        'Out of Stock': rows.where((r) => r['isOut'] == true).length,
        'Recipe-Based': rows.where((r) => r['isRecipeBased'] == true).length,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: reportAppBar(
          title: 'Low Stock Report',
          subtitle: 'At or below the reorder point',
        ),
        body: rows == null
            ? const ReportLoading()
            : rows.isEmpty
                ? ReportBody(
                    child: Column(
                      children: [
                        if (!AppSettings.lowStockAlertsEnabled) ...[
                          const ReportNotice(
                            message: 'Low-stock alerts are switched off in '
                                'Settings, so nothing is being measured. '
                                'Turn them on to populate this report.',
                          ),
                          AppResponsive.verticalSpace(context),
                        ],
                        const ReportEmptyState(
                          icon: Icons.verified_outlined,
                          title: 'Nothing is low',
                          message:
                              'Every tracked item is above its reorder point.',
                        ),
                      ],
                    ),
                  )
                : _buildContent(rows),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> rows) {
    final out = rows.where((r) => r['isOut'] == true).length;
    final recipe = rows.where((r) => r['isRecipeBased'] == true).length;
    final page = ReportPagination.pageSlice(rows, _page, _rowsPerPage);

    return ReportBody(
      child: Column(
        children: [
          ReportSummaryRow(
            cards: [
              ReportSummaryCard(
                title: 'Low Stock',
                value: '${rows.length}',
                subtitle: 'items flagged',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
              ReportSummaryCard(
                title: 'Out of Stock',
                value: '$out',
                subtitle: 'nothing left',
                icon: Icons.remove_shopping_cart_rounded,
                color: out > 0 ? AppColors.danger : AppColors.textSecondary,
              ),
              ReportSummaryCard(
                title: 'Recipe-Based',
                value: '$recipe',
                subtitle: 'limited by ingredients',
                icon: Icons.lunch_dining_rounded,
                color: AppColors.info,
              ),
            ],
          ),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: () => _export(rows)),
          AppResponsive.verticalSpace(context),
          ReportCard(
            child: ReportTable(
              columns: [
                ReportTable.column(context, 'Item'),
                ReportTable.column(context, 'Variant'),
                ReportTable.column(context, 'Stock', numeric: true),
                ReportTable.column(context, 'Reorder At', numeric: true),
                ReportTable.column(context, 'Cost', numeric: true),
              ],
              rows: page.map(_row).toList(),
            ),
          ),
          ReportPagination(
            currentPage: _page,
            rowsPerPage: _rowsPerPage,
            totalCount: rows.length,
            unit: 'items',
            onPageChanged: (p) => setState(() => _page = p),
          ),
        ],
      ),
    );
  }

  DataRow _row(Map<String, dynamic> r) {
    final isOut = r['isOut'] == true;
    final stock = (r['currentStock'] as num).toDouble();
    final unit = r['unit'] as String;

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r['itemName'] as String),
              if (r['isRecipeBased'] == true) ...[
                const SizedBox(width: 6),
                // Its number is "can make", not a counted shelf quantity.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Recipe',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        DataCell(Text((r['variantName'] as String?) ?? '—')),
        DataCell(
          Text(
            formatQtyWithUnit(stock, unit),
            style: GoogleFonts.poppins(
              color: isOut ? AppColors.danger : AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataCell(
          Text(formatQtyWithUnit(
              (r['reorderPoint'] as num).toDouble(), unit)),
        ),
        DataCell(Text(formatMoney((r['costPrice'] as num).toDouble()))),
      ],
    );
  }
}
