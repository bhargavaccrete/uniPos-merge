import 'package:flutter/material.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/widgets/upgrade_sheet.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

enum _CustPeriod { all, today, week, month, year, custom }

class CustomerListReport extends StatefulWidget {
  const CustomerListReport({super.key});

  @override
  State<CustomerListReport> createState() => _CustomerListReportState();
}

class _CustomerListReportState extends State<CustomerListReport> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, orders, spent, date
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  // Cached data — computed once after load, re-filtered on search/sort
  List<CustomerReportData> _allCustomerData = [];
  List<CustomerReportData> _filteredData = [];

  // Pre-computed summary totals
  int _totalCustomers = 0;
  int _activeCustomers = 0;
  double _totalRevenue = 0.0;

  // Period filter (default: all-time).
  _CustPeriod _period = _CustPeriod.all;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      restaurantCustomerStore.loadCustomers(),
      pastOrderStore.loadPastOrders(),
    ]);
    _buildCustomerData();
  }

  /// Build order lookup map once, then compute customer data in single pass.
  /// O(orders + customers) instead of O(customers × orders).
  void _buildCustomerData() {
    final (start, end) = _periodBounds();

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    // Step 1: Build indexed lookup — O(orders)
    final ordersByName = <String, List<_OrderStats>>{};
    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus ?? '';
      // Skip VOID/VOIDED — not valid sales
      if (OrderStatusFilter.isVoided(status)) continue;
      if (cutoff != null && order.orderAt != null && order.orderAt!.isBefore(cutoff)) continue;

      // Period filter — orders without a timestamp can't be placed in a range.
      if (start != null && end != null) {
        final at = order.orderAt;
        if (at == null || at.isBefore(start) || !at.isBefore(end)) continue;
      }

      final key = order.customerName.trim().toLowerCase();
      if (key.isEmpty) continue;

      final spent = status == 'FULLY_REFUNDED'
          ? 0.0
          : order.totalPrice - (order.refundAmount ?? 0.0);

      ordersByName.putIfAbsent(key, () => []).add(_OrderStats(
        spent: spent,
        orderAt: order.orderAt,
      ));
    }

    // Step 2: Map customers to report data — O(customers)
    final customers = restaurantCustomerStore.customers;
    final result = <CustomerReportData>[];

    for (final customer in customers) {
      final customerName = (customer.name ?? '').trim().toLowerCase();
      final customerPhone = customer.phone?.trim() ?? '';

      // Lookup by name
      var stats = ordersByName[customerName];

      // Fallback: check if phone matches any order customer name
      if (stats == null && customerPhone.isNotEmpty) {
        for (final entry in ordersByName.entries) {
          if (entry.key.contains(customerPhone)) {
            stats = entry.value;
            break;
          }
        }
      }

      final totalOrders = stats?.length ?? 0;
      double totalSpent = 0.0;
      DateTime? lastOrderDate;

      if (stats != null) {
        for (final s in stats) {
          totalSpent += s.spent;
          if (s.orderAt != null) {
            if (lastOrderDate == null || s.orderAt!.isAfter(lastOrderDate)) {
              lastOrderDate = s.orderAt;
            }
          }
        }
      }

      // Date-scoped view (option B): when a period is active, list only
      // customers who actually ordered within it.
      if (_period != _CustPeriod.all && totalOrders == 0) continue;

      result.add(CustomerReportData(
        srNo: 0, // assigned after filtering
        name: customer.name ?? 'Unknown',
        phone: customer.phone ?? '-',
        totalOrders: totalOrders,
        totalSpent: totalSpent,
        lastOrderDate: lastOrderDate,
        registrationDate: DateTime.tryParse(customer.createdAt),
      ));
    }

    _allCustomerData = result;

    // Compute summary totals once
    int active = 0;
    double revenue = 0.0;
    for (final c in result) {
      if (c.totalOrders > 0) active++;
      revenue += c.totalSpent;
    }

    _totalCustomers = result.length;
    _activeCustomers = active;
    _totalRevenue = revenue;

    _applyFilterAndSort();
  }

  /// Filter by search query + sort — runs on search/sort change only.
  void _applyFilterAndSort() {
    var data = _allCustomerData.toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      data = data.where((c) {
        return c.name.toLowerCase().contains(query) ||
               c.phone.contains(query);
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        data.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'orders':
        data.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
        break;
      case 'spent':
        data.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
      case 'date':
        data.sort((a, b) {
          if (a.lastOrderDate == null && b.lastOrderDate == null) return 0;
          if (a.lastOrderDate == null) return 1;
          if (b.lastOrderDate == null) return -1;
          return b.lastOrderDate!.compareTo(a.lastOrderDate!);
        });
        break;
    }

    // Assign srNo after filter
    for (int i = 0; i < data.length; i++) {
      data[i] = CustomerReportData(
        srNo: i + 1,
        name: data[i].name,
        phone: data[i].phone,
        totalOrders: data[i].totalOrders,
        totalSpent: data[i].totalSpent,
        lastOrderDate: data[i].lastOrderDate,
        registrationDate: data[i].registrationDate,
      );
    }

    setState(() {
      _filteredData = data;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  /// Half-open [start, end) bounds for the selected period; (null, null) for
  /// all-time or an incomplete custom range.
  /// null bounds = no date restriction ('All'; or Custom before a range is set).
  (DateTime?, DateTime?) _periodBounds() {
    final now = DateTime.now();
    final standard = _standardPeriod(_period);
    if (standard != null) {
      return (reportPeriodStartBound(standard, now), reportPeriodEndBound(standard, now));
    }
    if (_period == _CustPeriod.custom && _fromDate != null && _toDate != null) {
      return (
        DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
        DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1)),
      );
    }
    return (null, null);
  }

  /// The kit period this maps to, or null for 'all' / 'custom' (unbounded).
  static ReportPeriod? _standardPeriod(_CustPeriod p) {
    switch (p) {
      case _CustPeriod.today:
        return ReportPeriod.today;
      case _CustPeriod.week:
        return ReportPeriod.thisWeek;
      case _CustPeriod.month:
        return ReportPeriod.thisMonth;
      case _CustPeriod.year:
        return ReportPeriod.thisYear;
      case _CustPeriod.all:
      case _CustPeriod.custom:
        return null;
    }
  }

  bool _periodAllowed(_CustPeriod p) {
    final standard = _standardPeriod(p);
    if (standard == null) return true; // 'all'/'custom' are clamped by the cutoff
    return ReportHistoryWindow.allows(reportPeriodStartBound(standard, DateTime.now()));
  }

  IconData _periodIcon(_CustPeriod p) {
    switch (p) {
      case _CustPeriod.all:
        return Icons.all_inclusive;
      case _CustPeriod.today:
        return Icons.today;
      case _CustPeriod.week:
        return Icons.view_week;
      case _CustPeriod.month:
        return Icons.calendar_month;
      case _CustPeriod.year:
        return Icons.calendar_today;
      case _CustPeriod.custom:
        return Icons.date_range;
    }
  }

  Future<void> _onPeriodSelected(_CustPeriod p) async {
    if (p == _CustPeriod.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: ReportHistoryWindow.cutoff ?? DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: (_fromDate != null && _toDate != null)
            ? DateTimeRange(start: _fromDate!, end: _toDate!)
            : null,
      );
      if (range == null) return;
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
        _period = p;
      });
    } else {
      setState(() => _period = p);
    }
    // Re-aggregate (period scopes which orders count) then re-filter/sort.
    _buildCustomerData();
  }

  String _periodLabel(_CustPeriod p) {
    switch (p) {
      case _CustPeriod.all:
        return 'All';
      case _CustPeriod.today:
        return 'Today';
      case _CustPeriod.week:
        return 'This Week';
      case _CustPeriod.month:
        return 'This Month';
      case _CustPeriod.year:
        return 'This Year';
      case _CustPeriod.custom:
        if (_fromDate != null && _toDate != null) {
          return '${DateFormat('dd MMM').format(_fromDate!)} – ${DateFormat('dd MMM').format(_toDate!)}';
        }
        return 'Custom';
    }
  }

  Widget _buildPeriodFilter(BuildContext context) {
    return ReportFilterBar<_CustPeriod>(
      selected: _period,
      onSelected: _onPeriodSelected,
      options: [
        for (final p in _CustPeriod.values)
          ReportFilterOption(
            value: p,
            label: _periodLabel(p),
            icon: _periodIcon(p),
            locked: !_periodAllowed(p),
            onLockedTap: () => UpgradeSheet.showHistoryLimit(
              context,
              featureName: '${_periodLabel(p)} customers',
              neededDays: ReportHistoryWindow.requiredDays(
                  reportPeriodStartBound(_standardPeriod(p)!, DateTime.now())),
              allowedDays: ReportHistoryWindow.limitDays ?? 0,
            ),
          ),
      ],
    );
  }

  Future<void> _exportReport() async {
    if (_filteredData.isEmpty) {
      NotificationService.instance.showError('No customers to export');
      return;
    }

    final headers = [
      'Sr No',
      'Customer Name',
      'Mobile',
      'Total Orders',
      'Total Spent',
      'Last Order Date',
      'Registration Date'
    ];

    final data = _filteredData.map((customer) => [
      customer.srNo.toString(),
      customer.name,
      customer.phone,
      customer.totalOrders.toString(),
      ReportExportService.formatCurrency(customer.totalSpent),
      customer.lastOrderDate != null
          ? ReportExportService.formatDate(customer.lastOrderDate!)
          : 'Never',
      customer.registrationDate != null
          ? ReportExportService.formatDate(customer.registrationDate!)
          : '-',
    ]).toList();

    final avgSpent = _totalCustomers > 0 ? _totalRevenue / _totalCustomers : 0.0;

    final summary = {
      'Total Customers': _totalCustomers.toString(),
      'Active Customers': '$_activeCustomers (${((_activeCustomers / _totalCustomers) * 100).toStringAsFixed(1)}%)',
      'Total Revenue': ReportExportService.formatCurrency(_totalRevenue),
      'Avg Spent/Customer': ReportExportService.formatCurrency(avgSpent),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'customer_list_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Customer List Report',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Customer List Report',
        subtitle: 'View all registered customers',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          _buildPeriodFilter(context),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(
            child: _isLoading
                ? const ReportLoading()
                : ReportBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReportSummaryRow(cards: [
                          ReportSummaryCard(
                            title: 'Total Customers',
                            value: _totalCustomers.toString(),
                            icon: Icons.people_outline,
                            color: Colors.blue,
                          ),
                          ReportSummaryCard(
                            title: 'Active Customers',
                            value: _activeCustomers.toString(),
                            icon: Icons.shopping_bag_outlined,
                            color: Colors.green,
                          ),
                        ]),
                        AppResponsive.verticalSpace(context, size: SpacingSize.small),
                        ReportSummaryCard(
                          title: 'Total Revenue',
                          value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRevenue)}',
                          icon: Icons.monetization_on_outlined,
                          color: Colors.orange,
                        ),
                        AppResponsive.verticalSpace(context),
                        _buildSearchAndSortCard(),
                        AppResponsive.verticalSpace(context),
                        ReportExportButton(onPressed: _exportReport),
                        AppResponsive.verticalSpace(context),
                        if (_filteredData.isEmpty)
                          ReportEmptyState(
                            icon: Icons.people_outline,
                            title: 'No Customers',
                            message: _searchQuery.isNotEmpty
                                ? 'No customers found matching "$_searchQuery"'
                                : 'No customers registered yet',
                          )
                        else
                          _buildCustomerTable(),
                        ReportPagination(
                          currentPage: _currentPage,
                          rowsPerPage: _rowsPerPage,
                          totalCount: _filteredData.length,
                          onPageChanged: (page) => setState(() => _currentPage = page),
                          unit: 'customers',
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortCard() {
    return ReportCard(
      child: Column(
        children: [
          AppTextField(
            onChanged: (value) {
              _searchQuery = value;
              _applyFilterAndSort();
            },
            hint: 'Search by name or phone',
            icon: Icons.search,
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              Text(
                'Sort by:',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Name', 'name'),
                      _buildSortChip('Orders', 'orders'),
                      _buildSortChip('Spent', 'spent'),
                      _buildSortChip('Last Order', 'date'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTable() {
    final pageData = ReportPagination.pageSlice(_filteredData, _currentPage, _rowsPerPage);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  'Customer Details',
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                  ),
                  child: Text(
                    '${_filteredData.length} customers',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: DataTable(
                  columnSpacing: AppResponsive.tableColumnSpacing(context),
                  headingRowHeight: AppResponsive.tableHeadingHeight(context),
                  dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                  dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
                  columns: [
                    DataColumn(label: Text('Sr', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Name', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Mobile', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Orders', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Spent (${CurrencyHelper.currentSymbol})', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Last Order', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  ],
                  rows: pageData.map((customer) {
                    return DataRow(
                      cells: [
                        DataCell(Text(customer.srNo.toString(), style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context)))),
                        DataCell(Text(customer.name, style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), fontWeight: FontWeight.w500))),
                        DataCell(Text(customer.phone, style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context)))),
                        DataCell(
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                              vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                            ),
                            decoration: BoxDecoration(
                              color: customer.totalOrders > 0
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              customer.totalOrders.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.captionFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: customer.totalOrders > 0 ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(DecimalSettings.formatAmount(customer.totalSpent), style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), fontWeight: FontWeight.w600, color: Colors.green))),
                        DataCell(Text(
                          customer.lastOrderDate != null ? DateFormat('dd/MM/yy').format(customer.lastOrderDate!) : 'Never',
                          style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), color: customer.lastOrderDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: EdgeInsets.only(right: AppResponsive.smallSpacing(context) / 2),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        onSelected: (selected) {
          if (selected) {
            _sortBy = value;
            _applyFilterAndSort();
          }
        },
      ),
    );
  }

}

class _OrderStats {
  final double spent;
  final DateTime? orderAt;
  const _OrderStats({required this.spent, this.orderAt});
}

class CustomerReportData {
  final int srNo;
  final String name;
  final String phone;
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastOrderDate;
  final DateTime? registrationDate;

  CustomerReportData({
    required this.srNo,
    required this.name,
    required this.phone,
    required this.totalOrders,
    required this.totalSpent,
    this.lastOrderDate,
    this.registrationDate,
  });
}