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

class CustomerListReport extends StatefulWidget {
  const CustomerListReport({super.key});

  @override
  State<CustomerListReport> createState() => _CustomerListReportState();
}

class _CustomerListReportState extends State<CustomerListReport> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, orders, spent, date

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      restaurantCustomerStore.loadCustomers(),
      pastOrderStore.loadPastOrders(),
    ]);
    if (mounted) setState(() {});
  }

  List<CustomerReportData> _calculateCustomerData() {
    final customers = restaurantCustomerStore.customers.toList();
    final allOrders = pastOrderStore.pastOrders.toList();

    List<CustomerReportData> customerDataList = [];

    for (int i = 0; i < customers.length; i++) {
      final customer = customers[i];

      // Find all orders for this customer
      final customerOrders = allOrders.where((order) {
        final orderCustomerName = order.customerName.trim().toLowerCase();
        final customerName = (customer.name ?? '').trim().toLowerCase();
        final customerPhone = customer.phone?.trim() ?? '';

        // Match by name or phone
        return orderCustomerName == customerName ||
               (customerPhone.isNotEmpty && order.customerName.contains(customerPhone));
      }).toList();

      // Calculate order statistics
      final totalOrders = customerOrders.length;
      final totalSpent = customerOrders.fold<double>(
        0.0,
        (sum, order) => sum + ((order.totalPrice ?? 0.0) - (order.refundAmount ?? 0.0))
      );

      // Find last order date
      DateTime? lastOrderDate;
      if (customerOrders.isNotEmpty) {
        customerOrders.sort((a, b) {
          if (a.orderAt == null && b.orderAt == null) return 0;
          if (a.orderAt == null) return 1;
          if (b.orderAt == null) return -1;
          return b.orderAt!.compareTo(a.orderAt!);
        });
        lastOrderDate = customerOrders.first.orderAt;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = (customer.name ?? '').toLowerCase().contains(query);
        final matchesPhone = (customer.phone ?? '').contains(query);

        if (!matchesName && !matchesPhone) {
          continue;
        }
      }

      customerDataList.add(CustomerReportData(
        srNo: i + 1,
        name: customer.name ?? 'Unknown',
        phone: customer.phone ?? '-',
        totalOrders: totalOrders,
        totalSpent: totalSpent,
        lastOrderDate: lastOrderDate,
        registrationDate: DateTime.tryParse(customer.createdAt),
      ));
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name':
        customerDataList.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'orders':
        customerDataList.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
        break;
      case 'spent':
        customerDataList.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
      case 'date':
        customerDataList.sort((a, b) {
          if (a.lastOrderDate == null && b.lastOrderDate == null) return 0;
          if (a.lastOrderDate == null) return 1;
          if (b.lastOrderDate == null) return -1;
          return b.lastOrderDate!.compareTo(a.lastOrderDate!);
        });
        break;
    }

    return customerDataList;
  }

  Future<void> _exportToExcel() async {
    final customerData = _calculateCustomerData();

    if (customerData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customers to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Prepare CSV data
      List<List<dynamic>> rows = [];

      // Header
      rows.add([
        'Sr No',
        'Customer Name',
        'Mobile',
        'Total Orders',
        'Total Spent',
        'Last Order Date',
        'Registration Date'
      ]);

      // Data rows
      for (var customer in customerData) {
        rows.add([
          customer.srNo,
          customer.name,
          customer.phone,
          customer.totalOrders,
          DecimalSettings.formatAmount(customer.totalSpent),
          customer.lastOrderDate != null
              ? DateFormat('dd/MM/yyyy').format(customer.lastOrderDate!)
              : 'Never',
          customer.registrationDate != null
              ? DateFormat('dd/MM/yyyy').format(customer.registrationDate!)
              : '-',
        ]);
      }

      // Summary row
      final totalCustomers = customerData.length;
      final activeCustomers = customerData.where((c) => c.totalOrders > 0).length;
      final totalRevenue = customerData.fold<double>(0, (sum, c) => sum + c.totalSpent);

      rows.add([]);
      rows.add(['Summary']);
      rows.add(['Total Customers', totalCustomers]);
      rows.add(['Active Customers', activeCustomers]);
      rows.add(['Total Revenue', DecimalSettings.formatAmount(totalRevenue)]);

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/customer_list_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Write to file
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Customer List Report',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                              'Customer List Report',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.headingFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'View all registered customers',
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
                ],
              ),
            ),
            // Content
            Expanded(
              child: Observer(
                builder: (_) {
                  if (restaurantCustomerStore.isLoading || pastOrderStore.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final customerData = _calculateCustomerData();
                  final totalCustomers = restaurantCustomerStore.customers.length;
                  final activeCustomers = customerData.where((c) => c.totalOrders > 0).length;
                  final totalRevenue = customerData.fold<double>(0, (sum, c) => sum + c.totalSpent);

                  return SingleChildScrollView(
                    child: Padding(
                      padding: AppResponsive.padding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  context,
                                  'Total Customers',
                                  totalCustomers.toString(),
                                  Icons.people_outline,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(width: AppResponsive.smallSpacing(context)),
                              Expanded(
                                child: _buildSummaryCard(
                                  context,
                                  'Active Customers',
                                  activeCustomers.toString(),
                                  Icons.shopping_bag_outlined,
                                  Colors.green,
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
                            Colors.orange,
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
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Search Field
                                TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search by name or phone',
                                    hintStyle: GoogleFonts.poppins(
                                      fontSize: AppResponsive.bodyFontSize(context),
                                      color: Colors.grey,
                                    ),
                                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                      borderSide: BorderSide(color: AppColors.primary),
                                    ),
                                    contentPadding: AppResponsive.cardPadding(context),
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(context),
                                  ),
                                ),
                                SizedBox(height: AppResponsive.smallSpacing(context)),
                                // Sort Options
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
                              onPressed: customerData.isNotEmpty ? _exportToExcel : null,
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
                          if (customerData.isEmpty)
                            _buildEmptyState(
                              context,
                              _searchQuery.isNotEmpty
                                  ? 'No customers found matching "$_searchQuery"'
                                  : 'No customers registered yet',
                            )
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
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                          ),
                                          child: Text(
                                            '${customerData.length} customers',
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
                                          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                          columns: [
                                            DataColumn(
                                              label: SizedBox(
                                                width: AppResponsive.getValue(context, mobile: 30.0, tablet: 40.0, desktop: 50.0),
                                                child: Text(
                                                  'Sr',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.bodyFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: AppResponsive.getValue(context, mobile: 100.0, tablet: 120.0, desktop: 150.0),
                                                child: Text(
                                                  'Name',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.bodyFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: AppResponsive.getValue(context, mobile: 100.0, tablet: 110.0, desktop: 120.0),
                                                child: Text(
                                                  'Mobile',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.bodyFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: AppResponsive.getValue(context, mobile: 60.0, tablet: 70.0, desktop: 80.0),
                                                child: Text(
                                                  'Orders',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.bodyFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: AppResponsive.getValue(context, mobile: 80.0, tablet: 100.0, desktop: 120.0),
                                                child: Text(
                                                  'Spent (${CurrencyHelper.currentSymbol})',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.bodyFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: AppResponsive.getValue(context, mobile: 80.0, tablet: 90.0, desktop: 100.0),
                                                child: Text(
                                                  'Last Order',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.bodyFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        rows: customerData.map((customer) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  customer.srNo.toString(),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.smallFontSize(context),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  customer.name,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.smallFontSize(context),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  customer.phone,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.smallFontSize(context),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: AppResponsive.smallSpacing(context),
                                                    vertical: AppResponsive.smallSpacing(context) / 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: customer.totalOrders > 0
                                                        ? Colors.blue.withOpacity(0.1)
                                                        : Colors.grey.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    customer.totalOrders.toString(),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: AppResponsive.smallFontSize(context),
                                                      fontWeight: FontWeight.w600,
                                                      color: customer.totalOrders > 0 ? Colors.blue : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  DecimalSettings.formatAmount(customer.totalSpent),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.smallFontSize(context),
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  customer.lastOrderDate != null
                                                      ? DateFormat('dd/MM/yy').format(customer.lastOrderDate!)
                                                      : 'Never',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.smallFontSize(context),
                                                    color: customer.lastOrderDate != null
                                                        ? Colors.black87
                                                        : Colors.grey,
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
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
            setState(() {
              _sortBy = value;
            });
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
            color: Colors.black.withOpacity(0.05),
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