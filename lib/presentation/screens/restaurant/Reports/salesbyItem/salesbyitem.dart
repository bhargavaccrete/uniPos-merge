import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';

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
              key: ValueKey(_selectedPeriod),
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
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant ItemsDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDataAndFilter();

    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndFilter() async {
    await pastOrderStore.loadPastOrders();
    _generateReport();
  }

  void _generateReport() {
    setState(() {
      _isLoading = true;
    });

    final allOrders = pastOrderStore.pastOrders.toList();
    List<pastOrderModel> filteredOrders = [];
    final now = DateTime.now();

    if (widget.period == ItemPeriod.Custom) {
      if (_startDate != null && _endDate != null) {
        filteredOrders = _filterOrdersByDateRange(allOrders, _startDate!, _endDate!);
      }
    } else {
      switch (widget.period) {
        case ItemPeriod.Today:
          filteredOrders = _filterOrdersByPeriod(allOrders, 'Today');
          break;
        case ItemPeriod.ThisWeek:
          filteredOrders = _filterOrdersByPeriod(allOrders, 'This Week');
          break;
        case ItemPeriod.ThisMonth:
          filteredOrders = _filterOrdersByPeriod(allOrders, 'This Month');
          break;
        case ItemPeriod.ThisYear:
          filteredOrders = _filterOrdersByPeriod(allOrders, 'This Year');
          break;
        case ItemPeriod.Custom:
          break;
      }
    }

    final reportData = _generateItemWiseReport(filteredOrders);

    setState(() {
      _reportData = reportData;
      _filteredData = reportData;
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
    });
  }

  List<pastOrderModel> _filterOrdersByPeriod(List<pastOrderModel> allOrders, String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Today':
        return allOrders.where((order) {
          if (order.orderAt == null) return false;
          return order.orderAt!.year == now.year &&
              order.orderAt!.month == now.month &&
              order.orderAt!.day == now.day;
        }).toList();
      case 'This Week':
        final dayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeek = DateTime(dayOfWeek.year, dayOfWeek.month, dayOfWeek.day);
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return allOrders.where((order) {
          if (order.orderAt == null) return false;
          return !order.orderAt!.isBefore(startOfWeek) && order.orderAt!.isBefore(endOfWeek);
        }).toList();
      case 'This Month':
        return allOrders.where((order) {
          if (order.orderAt == null) return false;
          return order.orderAt!.year == now.year && order.orderAt!.month == now.month;
        }).toList();
      case 'This Year':
        return allOrders.where((order) {
          if (order.orderAt == null) return false;
          return order.orderAt!.year == now.year;
        }).toList();
      default:
        return allOrders;
    }
  }

  List<pastOrderModel> _filterOrdersByDateRange(
    List<pastOrderModel> allOrders,
    DateTime startDate,
    DateTime endDate,
  ) {
    return allOrders.where((order) {
      if (order.orderAt == null) return false;
      return order.orderAt!.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          order.orderAt!.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  List<ItemReportData> _generateItemWiseReport(List<pastOrderModel> filteredOrders) {
    final Map<String, ItemReportData> itemSummary = {};

    for (final order in filteredOrders) {
      if (order.orderStatus == 'FULLY_REFUNDED') continue;

      for (final cartItem in order.items) {
        final originalQuantity = cartItem.quantity;
        final refundedQuantity = cartItem.refundedQuantity ?? 0;
        final effectiveQuantity = originalQuantity - refundedQuantity;

        if (effectiveQuantity <= 0) continue;

        final orderRefundRatio = order.totalPrice > 0
            ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
            : 1.0;
        final effectiveRevenue = cartItem.totalPrice * orderRefundRatio;

        if (itemSummary.containsKey(cartItem.title)) {
          final existingItem = itemSummary[cartItem.title]!;
          existingItem.totalQuantity += effectiveQuantity;
          existingItem.totalRevenue += effectiveRevenue;
        } else {
          itemSummary[cartItem.title] = ItemReportData(
            itemName: cartItem.title,
            totalQuantity: effectiveQuantity,
            totalRevenue: effectiveRevenue,
          );
        }
      }
    }

    final reportList = itemSummary.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return reportList;
  }

  Future<void> _exportToExcel() async {
    if (_filteredData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> headers = ['Item Name', 'Quantity Sold', 'Total Revenue'];
    List<List<dynamic>> rows = [headers];

    for (var item in _filteredData) {
      rows.add([
        item.itemName,
        item.totalQuantity.toString(),
        DecimalSettings.formatAmount(item.totalRevenue),
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getTemporaryDirectory();
      final periodName = widget.period.name;
      final path = '${directory.path}/items_${periodName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], text: "Items Report - $periodName");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            if (_filteredData.isNotEmpty) ...[
              AppResponsive.verticalSpace(context),
              _buildReportContent(),
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
    final totalItems = _filteredData.length;
    final totalRevenue = _filteredData.fold(0.0, (sum, item) => sum + item.totalRevenue);
    final totalQuantity = _filteredData.fold(0, (sum, item) => sum + item.totalQuantity);

    return Column(
      children: [
        _buildSummaryCards(totalItems, totalQuantity, totalRevenue),
        AppResponsive.verticalSpace(context),
        _buildSearchBar(),
        AppResponsive.verticalSpace(context),
        _buildExportButton(),
        AppResponsive.verticalSpace(context),
        _buildItemsTable(),
      ],
    );
  }

  Widget _buildSummaryCards(int totalItems, int totalQuantity, double totalRevenue) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Items',
            totalItems.toString(),
            Icons.inventory_2,
            Colors.blue,
          ),
        ),
        AppResponsive.horizontalSpace(context),
        Expanded(
          child: _buildSummaryCard(
            'Total Qty',
            totalQuantity.toString(),
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
    return Container(
      padding: AppResponsive.cardPadding(context),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 6.0, desktop: 8.0)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1 * color.a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: AppResponsive.smallIconSize(context),
                ),
              ),
            ],
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 24.0),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: AppResponsive.bodyFontSize(context),
          ),
          prefixIcon: Icon(Icons.search, color: AppColors.primary, size: AppResponsive.iconSize(context)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: AppResponsive.iconSize(context)),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
            vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportToExcel,
        icon: Icon(Icons.file_download_outlined, size: AppResponsive.iconSize(context)),
        label: Text(
          'Export to Excel',
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

  Widget _buildItemsTable() {
    final screenWidth = AppResponsive.screenWidth(context);
    final cellFontSize = AppResponsive.smallFontSize(context);
    final headerFontSize = AppResponsive.bodyFontSize(context);

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
              rows: _filteredData.map((item) {
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