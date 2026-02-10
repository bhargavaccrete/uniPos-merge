import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

enum TopSellingPeriod { Today, ThisWeek, DayWise, MonthWise, YearWise }

class SalesByTopSelling extends StatefulWidget {
  const SalesByTopSelling({super.key});

  @override
  State<SalesByTopSelling> createState() => _SalesByTopSellingState();
}

class _SalesByTopSellingState extends State<SalesByTopSelling> {
  TopSellingPeriod _selectedPeriod = TopSellingPeriod.Today;

  @override
  void initState() {
    super.initState();
    pastOrderStore.loadPastOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              width: double.infinity,
              padding: AppResponsive.padding(context),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: AppResponsive.iconSize(context),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales By Top Selling',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.headingFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Track your best selling items',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.mediumSpacing(context),
                          vertical: AppResponsive.smallSpacing(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                        ),
                        child: Text(
                          'ADMIN',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  // Period Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TopSellingPeriod.values.map((period) {
                        final isSelected = _selectedPeriod == period;
                        return Padding(
                          padding: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(
                              _getPeriodLabel(period),
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedPeriod = period;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: TopSellingReportView(
                key: ValueKey(_selectedPeriod),
                period: _selectedPeriod,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel(TopSellingPeriod period) {
    switch (period) {
      case TopSellingPeriod.Today:
        return 'Today';
      case TopSellingPeriod.ThisWeek:
        return 'This Week';
      case TopSellingPeriod.DayWise:
        return 'Day Wise';
      case TopSellingPeriod.MonthWise:
        return 'Month Wise';
      case TopSellingPeriod.YearWise:
        return 'Year Wise';
    }
  }
}

class TopSellingReportView extends StatefulWidget {
  final TopSellingPeriod period;

  const TopSellingReportView({super.key, required this.period});

  @override
  State<TopSellingReportView> createState() => _TopSellingReportViewState();
}

class _TopSellingReportViewState extends State<TopSellingReportView> {
  DateTime? _customDate;
  DateTime _selectedMonthYear = DateTime.now();
  DateTime _selectedYear = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await pastOrderStore.loadPastOrders();
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _customDate = picked;
      });
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonthYear,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month and Year',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonthYear = picked;
      });
    }
  }

  Future<void> _selectYear() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedYear,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Year',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedYear = picked;
      });
    }
  }

  List<Map<String, dynamic>> _calculateTopSellingItems() {
    final allOrders = pastOrderStore.pastOrders.toList();

    // Determine date range based on period
    DateTime? startDate;
    DateTime? endDate;

    switch (widget.period) {
      case TopSellingPeriod.Today:
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;

      case TopSellingPeriod.ThisWeek:
        final now = DateTime.now();
        final weekDay = now.weekday;
        startDate = now.subtract(Duration(days: weekDay - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;

      case TopSellingPeriod.DayWise:
        if (_customDate == null) return [];
        startDate = DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
        endDate = DateTime(_customDate!.year, _customDate!.month, _customDate!.day, 23, 59, 59);
        break;

      case TopSellingPeriod.MonthWise:
        startDate = DateTime(_selectedMonthYear.year, _selectedMonthYear.month, 1);
        endDate = DateTime(_selectedMonthYear.year, _selectedMonthYear.month + 1, 0, 23, 59, 59);
        break;

      case TopSellingPeriod.YearWise:
        startDate = DateTime(_selectedYear.year, 1, 1);
        endDate = DateTime(_selectedYear.year, 12, 31, 23, 59, 59);
        break;
    }

    // Filter orders by date range
    final filteredOrders = allOrders.where((order) {
      if (order.orderAt == null) return false;
      final orderDate = order.orderAt!;
      return orderDate.isAfter(startDate!.subtract(const Duration(seconds: 1))) &&
          orderDate.isBefore(endDate!.add(const Duration(seconds: 1)));
    }).toList();

    // Calculate item sales with refund handling
    Map<String, Map<String, dynamic>> itemSales = {};

    for (var order in filteredOrders) {
      // Skip fully refunded orders
      if (order.orderStatus == 'FULLY_REFUNDED') continue;

      // Calculate order-level refund ratio
      final orderTotal = order.totalPrice ?? 0.0;
      final refundAmount = order.refundAmount ?? 0.0;
      final orderRefundRatio = orderTotal > 0 ? ((orderTotal - refundAmount) / orderTotal) : 1.0;

      for (var item in order.items) {
        final itemName = item.title;

        // Calculate effective quantity (after refunds)
        final originalQuantity = item.quantity ?? 0;
        final refundedQuantity = item.refundedQuantity ?? 0;
        final effectiveQuantity = originalQuantity - refundedQuantity;

        // Skip fully refunded items
        if (effectiveQuantity <= 0) continue;

        final price = item.price;
        final baseTotal = price * effectiveQuantity;

        // Apply order-level refund ratio for accurate revenue
        final totalAmount = baseTotal * orderRefundRatio;

        if (itemSales.containsKey(itemName)) {
          itemSales[itemName]!['quantity'] += effectiveQuantity;
          itemSales[itemName]!['totalAmount'] += totalAmount;
        } else {
          itemSales[itemName] = {
            'itemName': itemName,
            'quantity': effectiveQuantity,
            'totalAmount': totalAmount,
          };
        }
      }
    }

    // Convert to list and sort by quantity (most sold first)
    final sortedItems = itemSales.values.toList()
      ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

    return sortedItems;
  }

  String _getPeriodDisplay() {
    switch (widget.period) {
      case TopSellingPeriod.Today:
        return DateFormat('dd/MM/yyyy').format(DateTime.now());
      case TopSellingPeriod.ThisWeek:
        final now = DateTime.now();
        final weekDay = now.weekday;
        final weekStart = now.subtract(Duration(days: weekDay - 1));
        return '${DateFormat('dd/MM').format(weekStart)} - ${DateFormat('dd/MM/yyyy').format(now)}';
      case TopSellingPeriod.DayWise:
        return _customDate != null ? DateFormat('dd/MM/yyyy').format(_customDate!) : '';
      case TopSellingPeriod.MonthWise:
        return DateFormat('MMMM yyyy').format(_selectedMonthYear);
      case TopSellingPeriod.YearWise:
        return DateFormat('yyyy').format(_selectedYear);
    }
  }

  Future<void> _exportToExcel() async {
    final topSellingItems = _calculateTopSellingItems();

    if (topSellingItems.isEmpty) {
      if (!mounted) return;
      NotificationService.instance.showError('No data to export');
      return;
    }

    try {
      // Prepare CSV data
      List<List<dynamic>> rows = [];

      // Header
      rows.add(['Period', 'Item Name', 'Quantity', 'Total Amount']);

      // Data rows
      final periodDisplay = _getPeriodDisplay();
      for (var item in topSellingItems) {
        rows.add([
          periodDisplay,
          item['itemName'],
          item['quantity'],
          DecimalSettings.formatAmount(item['totalAmount']),
        ]);
      }

      // Summary row
      final totalQuantity = topSellingItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
      final totalRevenue = topSellingItems.fold<double>(0, (sum, item) => sum + (item['totalAmount'] as double));
      rows.add(['', 'TOTAL', totalQuantity, DecimalSettings.formatAmount(totalRevenue)]);

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/top_selling_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Write to file
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Top Selling Items Report - ${_getPeriodDisplay()}',
      );

      if (!mounted) return;
      NotificationService.instance.showSuccess('Report exported successfully');
    } catch (e) {
      if (!mounted) return;
      NotificationService.instance.showError('Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (pastOrderStore.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final topSellingItems = _calculateTopSellingItems();
        final totalQuantity = topSellingItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
        final totalRevenue = topSellingItems.fold<double>(0, (sum, item) => sum + (item['totalAmount'] as double));
        final uniqueItems = topSellingItems.length;

        return SingleChildScrollView(
          child: Padding(
            padding: AppResponsive.padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Picker Section (for DayWise, MonthWise, YearWise)
                if (widget.period == TopSellingPeriod.DayWise ||
                    widget.period == TopSellingPeriod.MonthWise ||
                    widget.period == TopSellingPeriod.YearWise) ...[
                  Container(
                    padding: AppResponsive.cardPadding(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.period == TopSellingPeriod.DayWise
                              ? 'Select Date'
                              : widget.period == TopSellingPeriod.MonthWise
                                  ? 'Select Month'
                                  : 'Select Year',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppResponsive.smallSpacing(context)),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: widget.period == TopSellingPeriod.DayWise
                                    ? _pickDate
                                    : widget.period == TopSellingPeriod.MonthWise
                                        ? _selectMonth
                                        : _selectYear,
                                child: Container(
                                  padding: AppResponsive.cardPadding(context),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.primary),
                                    borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.period == TopSellingPeriod.DayWise
                                            ? (_customDate != null
                                                ? DateFormat('dd/MM/yyyy').format(_customDate!)
                                                : 'DD/MM/YYYY')
                                            : widget.period == TopSellingPeriod.MonthWise
                                                ? DateFormat('MMMM yyyy').format(_selectedMonthYear)
                                                : DateFormat('yyyy').format(_selectedYear),
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.bodyFontSize(context),
                                          color: (widget.period == TopSellingPeriod.DayWise && _customDate == null)
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        color: AppColors.primary,
                                        size: AppResponsive.iconSize(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                ],

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Total Items Sold',
                        totalQuantity.toString(),
                        Icons.inventory_2_outlined,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Unique Items',
                        uniqueItems.toString(),
                        Icons.category_outlined,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _buildSummaryCard(
                  context,
                  'Total Revenue',
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalRevenue)}',
                  Icons.monetization_on_outlined,
                  Colors.green,
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Export Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: topSellingItems.isNotEmpty ? _exportToExcel : null,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(
                      'Export to Excel',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.buttonFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: AppResponsive.mediumSpacing(context),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                SizedBox(height: AppResponsive.mediumSpacing(context)),

                // Data Table or Empty State
                if (widget.period == TopSellingPeriod.DayWise && _customDate == null)
                  _buildEmptyState(context, 'Please select a date to view top selling items')
                else if (topSellingItems.isEmpty)
                  _buildEmptyState(context, 'No sales data for selected period')
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: AppResponsive.cardPadding(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Top Selling Items',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.subheadingFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppResponsive.smallSpacing(context),
                                  vertical: AppResponsive.smallSpacing(context) / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                ),
                                child: Text(
                                  '${topSellingItems.length} items',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.captionFontSize(context),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    columnSpacing: AppResponsive.tableColumnSpacing(context),
                                    headingRowHeight: AppResponsive.tableHeadingHeight(context),
                                    dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                                    dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
                                    headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                    columns: [
                                      DataColumn(
                                        label: Text(
                                          'Period',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Item Name',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Quantity',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Total (${CurrencyHelper.currentSymbol})',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.bodyFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: topSellingItems.map((item) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              _getPeriodDisplay(),
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              item['itemName'],
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${item['quantity']}',
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item['totalAmount'])}',
                                              style: GoogleFonts.poppins(
                                                fontSize: AppResponsive.smallFontSize(context),
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: AppResponsive.iconSize(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context) / 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: AppResponsive.largeIconSize(context) * 2,
            color: Colors.grey[400],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}