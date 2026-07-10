import 'package:flutter/material.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_range_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

class Salesbyitem extends StatefulWidget {
  const Salesbyitem({super.key});

  @override
  State<Salesbyitem> createState() => _SalesbyitemState();
}

class _SalesbyitemState extends State<Salesbyitem> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Sales By Items',
        subtitle: 'Item-wise sales breakdown',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportPeriodFilterBar(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            featureNoun: 'item sales',
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(child: ItemsDataView(period: _selectedPeriod)),
        ],
      ),
    );
  }
}

class ItemsDataView extends StatefulWidget {
  final ReportPeriod period;
  const ItemsDataView({super.key, required this.period});

  @override
  State<ItemsDataView> createState() => _ItemsDataViewState();
}

class _ItemsDataViewState extends State<ItemsDataView> {
  List<ItemReportData> _reportData = [];
  List<ItemReportData> _filteredData = [];
  bool _isLoading = true;
  bool _isDataLoaded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;
  final TextEditingController _searchController = TextEditingController();

  // Pre-computed summary totals — set once in _generateReport(), not per build
  int _totalItems = 0;
  int _totalQuantity = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant ItemsDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _searchController.clear();
      // Data already in memory — just re-generate, no Hive read
      _generateReport();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  /// First call: loads all orders from Hive via the store (2-3s, once).
  /// Subsequent calls: skips the load, generates from memory (instant).
  Future<void> _loadDataAndFilter() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _generateReport();
  }

  /// Single-pass: date filter + status exclusion + item aggregation in one loop.
  void _generateReport() {
    final now = DateTime.now();
    final isCustom = widget.period == ReportPeriod.custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    // Pre-compute date boundaries once
    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      // Same helper the filter's history lock uses - they cannot disagree.
      startBound = reportPeriodStartBound(widget.period, now);
      endBound = reportPeriodEndBound(widget.period, now);
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    final cutoff = ReportHistoryWindow.cutoff;
    final Map<String, ItemReportData> itemSummary = {};

    // Single pass over all orders: date + status filter + item aggregation
    for (final order in pastOrderStore.pastOrders) {
      final orderDate = order.orderAt;
      if (orderDate == null) continue;
      if (cutoff != null && orderDate.isBefore(cutoff)) continue;
      if (isCustom && !hasCustomRange) continue;

      if (orderDate.isBefore(startBound) || !orderDate.isBefore(endBound)) {
        continue;
      }

      // Skip voided and fully refunded orders
      final status = order.orderStatus ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) continue;

      final isTaxInclusive = order.isTaxInclusive ?? false;

      // For PARTIALLY_REFUNDED orders: only apply order-level ratio when the
      // refund was not captured at the individual item level (refundedQuantity).
      final hasItemLevelRefunds = order.items.any((i) => (i.refundedQuantity ?? 0) > 0);
      final orderRefundRatio = (!hasItemLevelRefunds && order.totalPrice > 0 && (order.refundAmount ?? 0) > 0)
          ? (order.totalPrice - order.refundAmount!) / order.totalPrice
          : 1.0;

      // Pre-discount gross total — weights for bill-level discount distribution.
      final orderGrossTotal = order.items.fold(0.0, (s, i) => s + i.price * i.quantity);
      final orderDiscount = order.Discount ?? 0.0;

      for (final cartItem in order.items) {
        // Use effectiveQuantity so refunded units don't contribute revenue.
        final effectiveQuantity = cartItem.quantity - (cartItem.refundedQuantity ?? 0);
        if (effectiveQuantity <= 0) continue;

        // Base revenue = finalItemPrice (already has per-item discount) × effectiveQuantity.
        final unitPrice = cartItem.finalItemPrice;
        // Proportional share of the bill-level discount for this item's effective quantity.
        final itemBillDiscount = orderGrossTotal > 0 && orderDiscount > 0
            ? orderDiscount * (cartItem.price * effectiveQuantity) / orderGrossTotal
            : 0.0;
        final discountedRevenue = (unitPrice * effectiveQuantity) - itemBillDiscount;

        // Add tax on the discounted base (exclusive) or already included (inclusive).
        final taxRevenue = isTaxInclusive ? 0.0 : discountedRevenue * (cartItem.taxRate ?? 0.0);

        final effectiveRevenue = (discountedRevenue + taxRevenue) * orderRefundRatio;

        // Include variantName in the key so variants appear as separate rows.
        final itemKey = (cartItem.variantName != null && cartItem.variantName!.isNotEmpty)
            ? '${cartItem.title} (${cartItem.variantName})'
            : cartItem.title;

        if (itemSummary.containsKey(itemKey)) {
          itemSummary[itemKey]!.totalQuantity += effectiveQuantity;
          itemSummary[itemKey]!.totalRevenue += effectiveRevenue;
        } else {
          itemSummary[itemKey] = ItemReportData(
            itemName: itemKey,
            totalQuantity: effectiveQuantity,
            totalRevenue: effectiveRevenue,
          );
        }
      }
    }

    final sorted = itemSummary.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    final reportData = sorted;

    // Compute summary totals once here, not per build
    int totalQty = 0;
    double totalRev = 0.0;
    for (final item in reportData) {
      totalQty += item.totalQuantity;
      totalRev += item.totalRevenue;
    }

    setState(() {
      _reportData = reportData;
      _filteredData = reportData;
      _totalItems = reportData.length;
      _totalQuantity = totalQty;
      _totalRevenue = totalRev;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredData = _reportData;
      } else {
        _filteredData = _reportData.where((item) {
          return item.itemName.toLowerCase().contains(query);
        }).toList();
      }
      _currentPage = 0;
    });
  }

  Future<void> _exportReport() async {
    if (_filteredData.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = ['Item Name', 'Quantity Sold', 'Total Revenue'];
    final data = _filteredData.map((item) => [
      item.itemName,
      item.totalQuantity.toString(),
      ReportExportService.formatCurrency(item.totalRevenue),
    ]).toList();

    final summary = {
      'Report Period': _getPeriodDisplayName(),
      'Total Items': _totalItems.toString(),
      'Total Quantity Sold': _totalQuantity.toString(),
      'Total Revenue': ReportExportService.formatCurrency(_totalRevenue),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'sales_by_items_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Sales by Items Report',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    if (widget.period != ReportPeriod.custom) return widget.period.label;
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }
    return 'Custom Period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ReportLoading();

    if (widget.period == ReportPeriod.custom) {
      return _buildCustomDateSelector();
    }

    return _buildReportUI();
  }

  Widget _buildCustomDateSelector() {
    return ReportBody(
      child: Column(
        children: [
          ReportDateRangeCard(
            initialStart: _startDate,
            initialEnd: _endDate,
            onApply: (start, end) {
              setState(() {
                _startDate = start;
                _endDate = end;
              });
              _loadDataAndFilter();
            },
          ),
          if (_startDate != null && _endDate != null) ...[
            AppResponsive.verticalSpace(context),
            if (_reportData.isNotEmpty)
              _buildReportContent()
            else
              const ReportEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No Items Sold',
                message: 'No item sales found for the selected date range',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportUI() {
    if (_reportData.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Items Sold',
        message: 'No item sales found for this period',
      );
    }

    return ReportBody(child: _buildReportContent());
  }

  Widget _buildReportContent() {
    return Column(
      children: [
        _buildSummaryCards(_totalItems, _totalQuantity, _totalRevenue),
        AppResponsive.verticalSpace(context),
        _buildSearchBar(),
        AppResponsive.verticalSpace(context),
        ReportExportButton(onPressed: _exportReport),
        AppResponsive.verticalSpace(context),
        _buildItemsTable(),
        ReportPagination(
          currentPage: _currentPage,
          rowsPerPage: _rowsPerPage,
          totalCount: _filteredData.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
          unit: 'items',
        ),
      ],
    );
  }

  Widget _buildSummaryCards(int totalItems, int totalQuantity, double totalRevenue) {
    return ReportSummaryRow(cards: [
      ReportSummaryCard(
        title: 'Total Items',
        value: totalItems.toString(),
        icon: Icons.inventory_2,
        color: Colors.blue,
      ),
      ReportSummaryCard(
        title: 'Total Qty',
        value: totalQuantity.toString(),
        icon: Icons.shopping_cart,
        color: Colors.orange,
      ),
      ReportSummaryCard(
        title: 'Revenue',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalRevenue)}',
        icon: Icons.currency_rupee,
        color: Colors.green,
      ),
    ]);
  }

  Widget _buildSearchBar() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return AppTextField(
          controller: _searchController,
          hint: 'Search items...',
          icon: Icons.search,
          suffixIcon: value.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: AppResponsive.iconSize(context)),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        );
      },
    );
  }

  Widget _buildItemsTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);
    final pageData = ReportPagination.pageSlice(_filteredData, _currentPage, _rowsPerPage);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Item Name'),
        ReportTable.column(context, 'Quantity'),
        ReportTable.column(context, 'Revenue'),
      ],
      rows: pageData.map((item) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        item.itemName,
                        style: GoogleFonts.poppins(
                          fontSize: cellFontSize,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1 * Colors.orange.a),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.totalQuantity.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.totalRevenue)}',
                        style: GoogleFonts.poppins(
                          fontSize: cellFontSize,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
      }).toList(),
    );
  }
}

// Data model class
class ItemReportData {
  final String itemName;
  int totalQuantity;
  double totalRevenue;

  ItemReportData({
    required this.itemName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}