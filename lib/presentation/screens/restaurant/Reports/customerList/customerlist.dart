import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

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
    // Step 1: Build indexed lookup — O(orders)
    final ordersByName = <String, List<_OrderStats>>{};
    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus ?? '';
      // Skip VOID/VOIDED — not valid sales
      if (status == 'VOID' || status == 'VOIDED') continue;

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
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
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
                          'Customer List Report',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View all registered customers',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
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
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: AppResponsive.padding(context),
                      child: AppResponsive.constrainedContent(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary Cards
                            Row(
                              children: [
                                Expanded(
                                  child: ReportSummaryCard(
                                    title: 'Total Customers',
                                    value: _totalCustomers.toString(),
                                    icon: Icons.people_outline,
                                    color: Colors.blue,
                                  ),
                                ),
                                SizedBox(width: AppResponsive.smallSpacing(context)),
                                Expanded(
                                  child: ReportSummaryCard(
                                    title: 'Active Customers',
                                    value: _activeCustomers.toString(),
                                    icon: Icons.shopping_bag_outlined,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppResponsive.smallSpacing(context)),
                            ReportSummaryCard(
                              title: 'Total Revenue',
                              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRevenue)}',
                              icon: Icons.monetization_on_outlined,
                              color: Colors.orange,
                            ),

                            SizedBox(height: AppResponsive.mediumSpacing(context)),

                            // Search and Sort Bar
                            Container(
                              padding: AppResponsive.cardPadding(context),
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
                            ),

                            SizedBox(height: AppResponsive.mediumSpacing(context)),

                            // Export Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _filteredData.isNotEmpty ? _exportReport : null,
                                icon: const Icon(Icons.file_download_outlined),
                                label: Text(
                                  'Export Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.buttonFontSize(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: AppResponsive.mediumSpacing(context)),

                            // Data Table or Empty State
                            if (_filteredData.isEmpty)
                              _buildEmptyState(
                                context,
                                _searchQuery.isNotEmpty
                                    ? 'No customers found matching "$_searchQuery"'
                                    : 'No customers registered yet',
                              )
                            else
                              _buildCustomerTable(),

                            if (_filteredData.length > _rowsPerPage)
                              _buildPaginationControls(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTable() {
    final pageData = _filteredData.length <= _rowsPerPage
        ? _filteredData
        : _filteredData.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).toList();

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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: AppResponsive.screenWidth(context) - AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0),
                ),
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
        ],
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
            'Showing $start–$end of ${_filteredData.length} customers',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
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
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
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

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: AppResponsive.padding(context),
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
        children: [
          Icon(
            Icons.people_outline,
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