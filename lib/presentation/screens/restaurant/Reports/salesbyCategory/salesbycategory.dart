import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import '../../../../widget/componets/common/report_summary_card.dart';

enum CategoryPeriod { Today, ThisWeek, ThisMonth, ThisYear, Custom }

class SalesByCategory extends StatefulWidget {
  const SalesByCategory({super.key});

  @override
  State<SalesByCategory> createState() => _SalesByCategoryState();
}

class _SalesByCategoryState extends State<SalesByCategory> {
  CategoryPeriod _selectedPeriod = CategoryPeriod.Today;

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
                          'Sales By Category',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Category-wise sales breakdown',
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
                      Icons.person,
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
                  _filterButton(CategoryPeriod.Today, 'Today', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(CategoryPeriod.ThisWeek, 'This Week', Icons.view_week),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(CategoryPeriod.ThisMonth, 'This Month', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(CategoryPeriod.ThisYear, 'This Year', Icons.calendar_today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(CategoryPeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: CategoryDataView(
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(CategoryPeriod period, String title, IconData icon) {
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

class CategoryDataView extends StatefulWidget {
  final CategoryPeriod period;
  const CategoryDataView({super.key, required this.period});

  @override
  State<CategoryDataView> createState() => _CategoryDataViewState();
}

class _CategoryDataViewState extends State<CategoryDataView> {
  List<CategoryReportData> _reportData = [];
  List<CategoryReportData> _filteredData = [];
  bool _isLoading = true;
  bool _isDataLoaded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;
  final TextEditingController _searchController = TextEditingController();

  // Pre-computed summary totals — set once in _generateReport(), not per build
  int _totalCategories = 0;
  int _totalItemsSold = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant CategoryDataView oldWidget) {
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

  /// First call: loads all data from Hive via stores (once).
  /// Subsequent calls: skips the load, generates from memory (instant).
  Future<void> _loadDataAndFilter() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      await itemStore.loadItems();
      await categoryStore.loadCategories();
      _isDataLoaded = true;
    }
    _generateReport();
  }

  /// Single-pass: date filter + status exclusion + category aggregation in one loop.
  void _generateReport() {
    final now = DateTime.now();
    final isCustom = widget.period == CategoryPeriod.Custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    // Pre-compute date boundaries once
    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      switch (widget.period) {
        case CategoryPeriod.Today:
          startBound = DateTime(now.year, now.month, now.day);
          endBound = startBound.add(const Duration(days: 1));
          break;
        case CategoryPeriod.ThisWeek:
          final dayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          startBound = DateTime(dayOfWeek.year, dayOfWeek.month, dayOfWeek.day);
          endBound = startBound.add(const Duration(days: 7));
          break;
        case CategoryPeriod.ThisMonth:
          startBound = DateTime(now.year, now.month);
          endBound = DateTime(now.year, now.month + 1);
          break;
        case CategoryPeriod.ThisYear:
          startBound = DateTime(now.year);
          endBound = DateTime(now.year + 1);
          break;
        case CategoryPeriod.Custom:
          break;
      }
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    // Build fast lookups from stores (once per generate)
    final Map<String, String> categoryNameById = {
      for (final c in categoryStore.categories) c.id: c.name.trim(),
    };

    final Map<String, String> itemIdToCategoryName = {
      for (final it in itemStore.items)
        it.id: (categoryNameById[it.categoryOfItem] ?? 'Uncategorized'),
    };

    String resolveCategoryName(CartItem ci) {
      final snap = ci.categoryName?.trim();
      if (snap != null && snap.isNotEmpty && snap.toLowerCase() != 'uncategorized') {
        return snap;
      }
      final fromCatalog = itemIdToCategoryName[ci.id];
      if (fromCatalog != null && fromCatalog.trim().isNotEmpty) {
        return fromCatalog.trim();
      }
      return 'Uncategorized';
    }

    final Map<String, CategoryReportData> categorySummary = {};

    // Single pass over all orders: date + status filter + category aggregation
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

      final hasItemLevelRefunds = order.items.any((i) => (i.refundedQuantity ?? 0) > 0);
      final orderRefundRatio = (!hasItemLevelRefunds && order.totalPrice > 0 && (order.refundAmount ?? 0) > 0)
          ? (order.totalPrice - order.refundAmount!) / order.totalPrice
          : 1.0;

      final orderGrossTotal = order.items.fold(0.0, (s, i) => s + i.price * i.quantity);
      final orderDiscount = order.Discount ?? 0.0;

      for (final cartItem in order.items) {
        final effectiveQuantity = cartItem.quantity - (cartItem.refundedQuantity ?? 0);
        if (effectiveQuantity <= 0) continue;

        final unitPrice = cartItem.finalItemPrice;
        final itemBillDiscount = orderGrossTotal > 0 && orderDiscount > 0
            ? orderDiscount * (cartItem.price * effectiveQuantity) / orderGrossTotal
            : 0.0;
        final discountedRevenue = (unitPrice * effectiveQuantity) - itemBillDiscount;
        final taxRevenue = isTaxInclusive ? 0.0 : discountedRevenue * (cartItem.taxRate ?? 0.0);
        final effectiveRevenue = (discountedRevenue + taxRevenue) * orderRefundRatio;

        final cat = resolveCategoryName(cartItem);

        if (categorySummary.containsKey(cat)) {
          categorySummary[cat]!.totalItemsSold += effectiveQuantity;
          categorySummary[cat]!.totalRevenue += effectiveRevenue;
        } else {
          categorySummary[cat] = CategoryReportData(
            categoryName: cat,
            totalItemsSold: effectiveQuantity,
            totalRevenue: effectiveRevenue,
          );
        }
      }
    }

    final reportData = categorySummary.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    // Compute summary totals once here, not per build
    int totalQty = 0;
    double totalRev = 0.0;
    for (final cat in reportData) {
      totalQty += cat.totalItemsSold;
      totalRev += cat.totalRevenue;
    }

    setState(() {
      _reportData = reportData;
      _filteredData = reportData;
      _totalCategories = reportData.length;
      _totalItemsSold = totalQty;
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
        _filteredData = _reportData.where((category) {
          return category.categoryName.toLowerCase().contains(query);
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

    // Prepare headers
    final headers = ['Category Name', 'Items Sold', 'Total Revenue'];

    // Prepare data rows
    final data = _filteredData.map((category) => [
      category.categoryName,
      category.totalItemsSold.toString(),
      ReportExportService.formatCurrency(category.totalRevenue),
    ]).toList();

    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Period': periodName,
      'Total Categories': _totalCategories.toString(),
      'Total Items Sold': _totalItemsSold.toString(),
      'Total Revenue': ReportExportService.formatCurrency(_totalRevenue),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'sales_by_category_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Sales by Category - $periodName',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    switch (widget.period) {
      case CategoryPeriod.Today:
        return 'Today';
      case CategoryPeriod.ThisWeek:
        return 'This Week';
      case CategoryPeriod.ThisMonth:
        return 'This Month';
      case CategoryPeriod.ThisYear:
        return 'This Year';
      case CategoryPeriod.Custom:
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

    if (widget.period == CategoryPeriod.Custom) {
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
                        'No categories found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No categories sold in the selected date range',
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
                Icons.category_outlined,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Category Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No categories sold in this period',
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
        _buildSummaryCards(_totalCategories, _totalItemsSold, _totalRevenue),
        AppResponsive.verticalSpace(context),
        _buildSearchBar(),
        AppResponsive.verticalSpace(context),
        _buildExportButton(),
        AppResponsive.verticalSpace(context),
        _buildCategoriesTable(),
        if (_filteredData.length > _rowsPerPage)
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildSummaryCards(int totalCategories, int totalItemsSold, double totalRevenue) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Categories',
            totalCategories.toString(),
            Icons.category,
            Colors.blue,
          ),
        ),
        AppResponsive.horizontalSpace(context),
        Expanded(
          child: _buildSummaryCard(
            'Total Qty',
            totalItemsSold.toString(),
            Icons.shopping_cart,
            Colors.orange,
          ),
        ),
        AppResponsive.horizontalSpace(context),
        Expanded(
          child: _buildSummaryCard(
            'Revenue',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalRevenue)}',
            Icons.currency_rupee,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return ReportSummaryCard(title: title, value: value, icon: icon, color: color);
  }

  Widget _buildSearchBar() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return AppTextField(
          controller: _searchController,
          hint: 'Search categories...',
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
            'Showing $start–$end of ${_filteredData.length} categories',
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

  Widget _buildCategoriesTable() {
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
                    'Category',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Items Sold',
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
              rows: pageData.map((category) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        category.categoryName,
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
                          category.totalItemsSold.toString(),
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
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(category.totalRevenue)}',
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
class CategoryReportData {
  final String categoryName;
  int totalItemsSold;
  double totalRevenue;

  CategoryReportData({
    required this.categoryName,
    required this.totalItemsSold,
    required this.totalRevenue,
  });
}