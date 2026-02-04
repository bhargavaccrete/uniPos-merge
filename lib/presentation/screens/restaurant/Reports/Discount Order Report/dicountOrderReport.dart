import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';

enum DiscountPeriod { Today, ThisWeek, Month, Year, Custom }

class DiscountOrderReport extends StatefulWidget {
  const DiscountOrderReport({super.key});

  @override
  State<DiscountOrderReport> createState() => _DiscountOrderReportState();
}

class _DiscountOrderReportState extends State<DiscountOrderReport> {
  DiscountPeriod _selectedPeriod = DiscountPeriod.Today;

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
                          'Discount Orders',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Track orders with discounts',
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
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.discount,
                      size: AppResponsive.iconSize(context),
                      color: Colors.orange,
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
                  _filterButton(DiscountPeriod.Today, 'Today', Icons.today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.ThisWeek, 'This Week', Icons.view_week),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.Month, 'This Month', Icons.calendar_month),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.Year, 'This Year', Icons.calendar_today),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  _filterButton(DiscountPeriod.Custom, 'Custom', Icons.date_range),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: DiscountDataView(
              key: ValueKey(_selectedPeriod),
              period: _selectedPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(DiscountPeriod period, String title, IconData icon) {
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

class DiscountDataView extends StatefulWidget {
  final DiscountPeriod period;
  const DiscountDataView({super.key, required this.period});

  @override
  State<DiscountDataView> createState() => _DiscountDataViewState();
}

class _DiscountDataViewState extends State<DiscountDataView> {
  List<pastOrderModel> _allOrders = [];
  List<pastOrderModel> _filteredOrders = [];
  double _totalDiscountAmount = 0.0;
  int _totalOrdersCount = 0;
  double _averageDiscount = 0.0;
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant DiscountDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDataAndFilter();

    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
    }
  }

  Future<void> _loadDataAndFilter() async {
    await pastOrderStore.loadPastOrders();
    _allOrders = pastOrderStore.pastOrders
        .where((order) {
          // Filter orders with discount > 0
          if ((order.Discount ?? 0) <= 0) return false;

          // Exclude refunded and voided orders
          final status = order.orderStatus?.toUpperCase() ?? '';
          if (status == 'FULLY_REFUNDED' || status == 'VOID') return false;

          return true;
        })
        .toList();
    _fetchAndFilterData();
  }

  void _fetchAndFilterData() {
    setState(() {
      _isLoading = true;
    });

    List<pastOrderModel> resultingList = [];
    final now = DateTime.now();

    if (widget.period == DiscountPeriod.Custom) {
      if (_startDate != null && _endDate != null) {
        resultingList = _allOrders.where((order) {
          final orderDate = order.orderAt;
          if (orderDate == null) return false;
          return orderDate.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
              orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      }
    } else {
      switch (widget.period) {
        case DiscountPeriod.Today:
          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return orderDate.year == now.year &&
                orderDate.month == now.month &&
                orderDate.day == now.day;
          }).toList();
          break;
        case DiscountPeriod.ThisWeek:
          final dayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek = DateTime(dayOfWeek.year, dayOfWeek.month, dayOfWeek.day);
          final endOfWeek = startOfWeek.add(const Duration(days: 7));

          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return !orderDate.isBefore(startOfWeek) && orderDate.isBefore(endOfWeek);
          }).toList();
          break;
        case DiscountPeriod.Month:
          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return orderDate.year == now.year && orderDate.month == now.month;
          }).toList();
          break;
        case DiscountPeriod.Year:
          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return orderDate.year == now.year;
          }).toList();
          break;
        case DiscountPeriod.Custom:
          break;
      }
    }

    setState(() {
      _filteredOrders = resultingList;
      _totalOrdersCount = _filteredOrders.length;
      _totalDiscountAmount = _filteredOrders.fold(0.0, (sum, order) => sum + (order.Discount ?? 0.0));
      _averageDiscount = _totalOrdersCount > 0 ? _totalDiscountAmount / _totalOrdersCount : 0.0;
      _isLoading = false;
    });
  }

  Future<void> _exportToExcel() async {
    if (_filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> headers = [
      'Date',
      'Invoice ID',
      'Customer Name',
      'Payment Method',
      'Order Type',
      'Subtotal',
      'Discount',
      'Total Amount'
    ];

    List<List<dynamic>> rows = [headers];

    for (var order in _filteredOrders) {
      rows.add([
        order.orderAt != null ? DateFormat('dd-MM-yyyy HH:mm').format(order.orderAt!) : 'N/A',
        order.id,
        order.customerName,
        order.paymentmode ?? 'N/A',
        order.orderType ?? 'N/A',
        (order.subTotal ?? 0.0).toStringAsFixed(2),
        (order.Discount ?? 0.0).toStringAsFixed(2),
        order.totalPrice.toStringAsFixed(2),
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getTemporaryDirectory();
      final periodName = widget.period.name;
      final path = '${directory.path}/discount_orders_${periodName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], text: "Discount Orders Report - $periodName");

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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (widget.period == DiscountPeriod.Custom) {
      return _buildCustomDateSelector(isTablet);
    }

    return _buildReportUI(isTablet);
  }

  Widget _buildCustomDateSelector(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    String formatDate(DateTime? date) {
      if (date == null) return 'Select Date';
      return DateFormat('dd MMM, yyyy').format(date);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1400 : 1000),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
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
                        fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDatePickerButton('Start Date', formatDate(_startDate), () => _selectDate(context, true), isTablet)),
                        SizedBox(width: 16),
                        Expanded(child: _buildDatePickerButton('End Date', formatDate(_endDate), () => _selectDate(context, false), isTablet)),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_startDate != null && _endDate != null) ? _fetchAndFilterData : null,
                        icon: Icon(Icons.filter_list, size: isTablet ? 20 : 18),
                        label: Text(
                          'Apply Filter',
                          style: GoogleFonts.poppins(fontSize: isTablet ? 16 : 15, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          disabledBackgroundColor: AppColors.divider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_filteredOrders.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildReportContent(isTablet),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(String label, String value, VoidCallback onPressed, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: isTablet ? 14 : 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 14 : 12),
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
                    fontSize: isTablet ? 14 : 13,
                    color: value == 'Select Date' ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                Icon(Icons.calendar_today, size: isTablet ? 20 : 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportUI(bool isTablet) {
    if (_filteredOrders.isEmpty) {
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
                Icons.discount,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Discount Orders',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No discount orders found for this period',
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
        child: _buildReportContent(isTablet),
      ),
    );
  }

  Widget _buildReportContent(bool isTablet) {
    return Column(
      children: [
        _buildSummaryCards(isTablet),
        SizedBox(height: 16),
        _buildExportButton(isTablet),
        SizedBox(height: 16),
        _buildDataTable(isTablet),
      ],
    );
  }

  Widget _buildSummaryCards(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return Row(
      children: [
        Expanded(
          flex: isDesktop ? 1 : 1,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Orders',
                      style: GoogleFonts.poppins(fontSize: isDesktop ? 16 : (isTablet ? 14 : 13), fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.shopping_cart, color: AppColors.primary, size: isDesktop ? 28 : (isTablet ? 22 : 20)),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  _totalOrdersCount.toString(),
                  style: GoogleFonts.poppins(fontSize: isDesktop ? 32 : (isTablet ? 24 : 22), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          flex: isDesktop ? 1 : 1,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Discount',
                      style: GoogleFonts.poppins(fontSize: isDesktop ? 16 : (isTablet ? 14 : 13), fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1 * Colors.orange.a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.discount, color: Colors.orange, size: isDesktop ? 28 : (isTablet ? 22 : 20)),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalDiscountAmount)}',
                  style: GoogleFonts.poppins(fontSize: isDesktop ? 32 : (isTablet ? 24 : 22), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          flex: isDesktop ? 1 : 1,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Average Discount',
                      style: GoogleFonts.poppins(fontSize: isDesktop ? 16 : (isTablet ? 14 : 13), fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1 * Colors.green.a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.analytics, color: Colors.green, size: isDesktop ? 28 : (isTablet ? 22 : 20)),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_averageDiscount)}',
                  style: GoogleFonts.poppins(fontSize: isDesktop ? 32 : (isTablet ? 24 : 22), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportToExcel,
        icon: Icon(Icons.file_download_outlined, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Export to Excel',
          style: GoogleFonts.poppins(fontSize: isDesktop ? 17 : (isTablet ? 16 : 15), fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 18 : (isTablet ? 16 : 14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildDataTable(bool isTablet) {
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2)),
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
                DataColumn(label: Text('Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Invoice ID', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Customer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Discount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
              ],
              rows: _filteredOrders.map((order) {
                final discount = order.Discount ?? 0.0;
                return DataRow(
                  cells: [
                    DataCell(Text(order.orderAt != null ? DateFormat('dd-MM-yy\nHH:mm').format(order.orderAt!) : 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(Text('#${order.id.substring(0, 8)}...', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                    DataCell(Text(order.customerName.isNotEmpty ? order.customerName : 'Guest', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(order.paymentmode ?? 'N/A', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    DataCell(Text(order.orderType ?? 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textSecondary))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(discount)}', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(order.totalPrice)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
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