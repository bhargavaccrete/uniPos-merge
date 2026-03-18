import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

enum ItemPeriod { Today, ThisWeek, ThisMonth, ThisYear, Custom }

class Salesbyitem extends StatefulWidget {
  const Salesbyitem({super.key});

  @override
  State<Salesbyitem> createState() => _SalesbyitemState();
}

class _SalesbyitemState extends State<Salesbyitem> {
  ItemPeriod _selectedPeriod = ItemPeriod.Today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Modern Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back, color: AppColors.white, size: 24),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales By Items',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Item-wise sales breakdown',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: AppResponsive.iconSize(context),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          // Filter Buttons
          Container(
            color: AppColors.white,
            padding: AppResponsive.horizontalPadding(context).copyWith(top: 12, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton(ItemPeriod.Today, 'Today', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(ItemPeriod.ThisWeek, 'This Week', Icons.view_week),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(ItemPeriod.ThisMonth, 'This Month', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(ItemPeriod.ThisYear, 'This Year', Icons.calendar_today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(ItemPeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: ItemsDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(ItemPeriod period, String title, IconData icon) {
    bool isSelected = _selectedPeriod == period;
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      icon: Icon(icon, size: AppResponsive.smallIconSize(context)),
      label: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
          vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0),
        ),
        backgroundColor: isSelected ? AppColors.primary : AppColors.white,
        foregroundColor: isSelected ? AppColors.white : AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1,
          ),
        ),
      ),
    );
  }
}

class ItemsDataView extends StatefulWidget {
  final ItemPeriod period;
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
    final isCustom = widget.period == ItemPeriod.Custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    // Pre-compute date boundaries once
    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      switch (widget.period) {
        case ItemPeriod.Today:
          startBound = DateTime(now.year, now.month, now.day);
          endBound = startBound.add(const Duration(days: 1));
          break;
        case ItemPeriod.ThisWeek:
          final dayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          startBound = DateTime(dayOfWeek.year, dayOfWeek.month, dayOfWeek.day);
          endBound = startBound.add(const Duration(days: 7));
          break;
        case ItemPeriod.ThisMonth:
          startBound = DateTime(now.year, now.month);
          endBound = DateTime(now.year, now.month + 1);
          break;
        case ItemPeriod.ThisYear:
          startBound = DateTime(now.year);
          endBound = DateTime(now.year + 1);
          break;
        case ItemPeriod.Custom:
          break;
      }
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    final Map<String, ItemReportData> itemSummary = {};

    // Single pass over all orders: date + status filter + item aggregation
    for (final order in pastOrderStore.pastOrders) {
      final orderDate = order.orderAt;
      if (orderDate == null) continue;
      if (isCustom && !hasCustomRange) continue;

      if (orderDate.isBefore(startBound) || !orderDate.isBefore(endBound)) {
        continue;
      }

      // Skip voided and fully refunded orders
      final status = order.orderStatus ?? '';
      if (status == 'FULLY_REFUNDED' || status == 'VOIDED' || status == 'VOID') continue;

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

    final reportData = itemSummary.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

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
    switch (widget.period) {
      case ItemPeriod.Today:
        return 'Today';
      case ItemPeriod.ThisWeek:
        return 'This Week';
      case ItemPeriod.ThisMonth:
        return 'This Month';
      case ItemPeriod.ThisYear:
        return 'This Year';
      case ItemPeriod.Custom:
        if (_startDate != null && _endDate != null) {
          return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
        }
        return 'Custom Period';
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) {
    return showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    ).then((picked) {
      if (picked != null) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
          } else {
            _endDate = picked;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (widget.period == ItemPeriod.Custom) {
      return _buildCustomDateSelector();
    }

    return _buildReportUI();
  }

  Widget _buildCustomDateSelector() {
    String formatDate(DateTime? date) {
      if (date == null) return 'Select Date';
      return DateFormat('dd MMM, yyyy').format(date);
    }

    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
          children: [
            Container(
              padding: AppResponsive.cardPadding(context),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Date Range',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  AppResponsive.verticalSpace(context),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerButton(
                          'Start Date',
                          formatDate(_startDate),
                          () => _selectDate(context, true),
                        ),
                      ),
                      AppResponsive.horizontalSpace(context),
                      Expanded(
                        child: _buildDatePickerButton(
                          'End Date',
                          formatDate(_endDate),
                          () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                  AppResponsive.verticalSpace(context),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_startDate != null && _endDate != null) ? _generateReport : null,
                      icon: Icon(Icons.filter_list, size: AppResponsive.smallIconSize(context)),
                      label: Text(
                        'Apply Filter',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.buttonFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: AppColors.divider,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_startDate != null && _endDate != null) ...[
              AppResponsive.verticalSpace(context),
              if (_filteredData.isNotEmpty)
                _buildReportContent()
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No items found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No items sold in the selected date range',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(String label, String value, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.small),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0)),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: value == 'Select Date' ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportUI() {
    if (_reportData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0)),
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Items Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No items sold in this period',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: _buildReportContent(),
      ),
    );
  }

  Widget _buildReportContent() {
    return Column(
      children: [
        _buildSummaryCards(_totalItems, _totalQuantity, _totalRevenue),
        AppResponsive.verticalSpace(context),
        _buildSearchBar(),
        AppResponsive.verticalSpace(context),
        _buildExportButton(),
        AppResponsive.verticalSpace(context),
        _buildItemsTable(),
        if (_filteredData.length > _rowsPerPage)
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildSummaryCards(int totalItems, int totalQuantity, double totalRevenue) {
    return Row(
      children: [
        Expanded(
          child: ReportSummaryCard(
            title: 'Total Items',
            value: totalItems.toString(),
            icon: Icons.inventory_2,
            color: Colors.blue,
          ),
        ),
        AppResponsive.horizontalSpace(context),
        Expanded(
          child: ReportSummaryCard(
            title: 'Total Qty',
            value: totalQuantity.toString(),
            icon: Icons.shopping_cart,
            color: Colors.orange,
          ),
        ),
        AppResponsive.horizontalSpace(context),
        Expanded(
          child: ReportSummaryCard(
            title: 'Revenue',
            value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalRevenue)}',
            icon: Icons.currency_rupee,
            color: Colors.green,
          ),
        ),
      ],
    );
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

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportReport,
        icon: Icon(Icons.file_download_outlined, size: AppResponsive.iconSize(context)),
        label: Text(
          'Export Report',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.buttonFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_filteredData.length / _rowsPerPage).ceil();
    final start = _currentPage * _rowsPerPage + 1;
    final end = ((_currentPage + 1) * _rowsPerPage).clamp(1, _filteredData.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start–$end of ${_filteredData.length} items',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 24,
                color: AppColors.primary,
                disabledColor: AppColors.divider,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 24,
                color: AppColors.primary,
                disabledColor: AppColors.divider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    final screenWidth = AppResponsive.screenWidth(context);
    final cellFontSize = AppResponsive.smallFontSize(context);
    final headerFontSize = AppResponsive.bodyFontSize(context);
    final pageData = _filteredData.length <= _rowsPerPage
        ? _filteredData
        : _filteredData.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth - AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0),
            ),
            child: DataTable(
              columnSpacing: AppResponsive.tableColumnSpacing(context),
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
              headingRowHeight: AppResponsive.tableHeadingHeight(context),
              dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
              dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
              columns: [
                DataColumn(
                  label: Text(
                    'Item Name',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Quantity',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Revenue',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  numeric: true,
                ),
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
            ),
          ),
        ),
      ),
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