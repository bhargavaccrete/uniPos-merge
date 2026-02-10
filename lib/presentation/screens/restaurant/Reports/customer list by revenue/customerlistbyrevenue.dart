import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';

class CustomerListByRevenue extends StatefulWidget {
  const CustomerListByRevenue({super.key});

  @override
  State<CustomerListByRevenue> createState() => _CustomerListByRevenueState();
}

class _CustomerListByRevenueState extends State<CustomerListByRevenue> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerRevenue();
  }

  Future<void> _loadCustomerRevenue() async {
    setState(() => _isLoading = true);
    await pastOrderStore.loadPastOrders();
    setState(() => _isLoading = false);
  }

  List<CustomerRevenueData> _calculateCustomerRevenue() {
    final allOrders = pastOrderStore.pastOrders.toList();
    final Map<String, CustomerRevenueData> customerMap = {};

    for (final order in allOrders) {
      // Skip fully refunded and voided orders
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status == 'FULLY_REFUNDED' || status == 'VOIDED' || status == 'VOID') continue;

      // Get customer name, use "Walk-in Customer" if empty
      String customerName = order.customerName.trim();
      if (customerName.isEmpty) {
        customerName = 'Walk-in Customer';
      }

      // Calculate net revenue (total - refund)
      final netRevenue = order.totalPrice - (order.refundAmount ?? 0.0);

      // Skip if net revenue is 0 or negative
      if (netRevenue <= 0) continue;

      if (customerMap.containsKey(customerName)) {
        customerMap[customerName]!.revenue += netRevenue;
        customerMap[customerName]!.orderCount += 1;
      } else {
        customerMap[customerName] = CustomerRevenueData(
          srNo: 0,
          name: customerName,
          revenue: netRevenue,
          orderCount: 1,
        );
      }
    }

    // Convert to list and sort by revenue (descending)
    final List<CustomerRevenueData> customers = customerMap.values.toList();
    customers.sort((a, b) => b.revenue.compareTo(a.revenue));

    // Assign serial numbers
    for (int i = 0; i < customers.length; i++) {
      customers[i].srNo = i + 1;
    }

    return customers;
  }

  double _calculateTotalRevenue(List<CustomerRevenueData> customers) {
    return customers.fold(0.0, (sum, customer) => sum + customer.revenue);
  }

  double _calculateAverageRevenue(List<CustomerRevenueData> customers) {
    if (customers.isEmpty) return 0.0;
    return _calculateTotalRevenue(customers) / customers.length;
  }

  Future<void> _exportToExcel(List<CustomerRevenueData> customers) async {
    if (customers.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    List<String> headers = [
      'Rank',
      'Customer Name',
      'Total Orders',
      'Total Revenue',
    ];

    List<List<dynamic>> rows = [headers];

    for (var customer in customers) {
      rows.add([
        customer.srNo.toString(),
        customer.name,
        customer.orderCount.toString(),
        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(customer.revenue)}',
      ]);
    }

    // Add summary
    rows.add([]);
    rows.add(['Summary', '', '', '']);
    rows.add(['Total Customers', customers.length.toString(), '', '']);
    rows.add(['Total Revenue', '', '', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_calculateTotalRevenue(customers))}']);
    rows.add(['Average Revenue', '', '', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_calculateAverageRevenue(customers))}']);

    String csv = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/customer_revenue_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], text: "Customer Revenue Report");

      if (mounted) {
        NotificationService.instance.showSuccess('Report exported successfully');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error exporting: $e');
      }
    }
  }

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
                          'Customer Revenue',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Top customers by revenue',
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
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.people,
                      size: AppResponsive.iconSize(context),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Observer(
      builder: (_) {
        if (_isLoading || pastOrderStore.isLoading) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final customers = _calculateCustomerRevenue();

        if (customers.isEmpty) {
          return _buildEmptyState(context);
        }

        return SingleChildScrollView(
          padding: AppResponsive.padding(context),
          child: AppResponsive.constrainedContent(
            context: context,
            child: Column(
              children: [
                _buildSummaryCards(context, customers, isTablet),
                SizedBox(height: 16),
                _buildRefreshButton(context, isTablet),
                SizedBox(height: 16),
                _buildExportButton(context, customers, isTablet),
                SizedBox(height: 16),
                _buildCustomersTable(context, customers, isTablet),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 40.0, desktop: 60.0)),
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
                Icons.people,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No Customer Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              'No customer revenue data found',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, List<CustomerRevenueData> customers, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    final totalRevenue = _calculateTotalRevenue(customers);
    final averageRevenue = _calculateAverageRevenue(customers);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Total Customers',
            customers.length.toString(),
            Icons.people,
            AppColors.primary,
            isTablet,
            isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Total Revenue',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalRevenue)}',
            Icons.attach_money,
            Colors.green,
            isTablet,
            isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Average Revenue',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(averageRevenue)}',
            Icons.analytics,
            Colors.orange,
            isTablet,
            isDesktop,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color iconColor,
    bool isTablet,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
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
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 16 : (isTablet ? 14 : 13),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isDesktop ? 28 : (isTablet ? 22 : 20),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 32 : (isTablet ? 24 : 22),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, bool isTablet) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loadCustomerRevenue,
        icon: Icon(Icons.refresh, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Refresh Data',
          style: GoogleFonts.poppins(
            fontSize: isDesktop ? 17 : (isTablet ? 16 : 15),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 18 : (isTablet ? 16 : 14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, List<CustomerRevenueData> customers, bool isTablet) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _exportToExcel(customers),
        icon: Icon(Icons.file_download_outlined, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Export to Excel',
          style: GoogleFonts.poppins(
            fontSize: isDesktop ? 17 : (isTablet ? 16 : 15),
            fontWeight: FontWeight.w600,
          ),
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

  Widget _buildCustomersTable(BuildContext context, List<CustomerRevenueData> customers, bool isTablet) {
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
                    'Rank',
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
                    'Customer Name',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Total Orders',
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
                    'Total Revenue',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: headerFontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: customers.map((customer) {
                // Medal colors for top 3
                Color? rankColor;
                IconData? medalIcon;
                if (customer.srNo == 1) {
                  rankColor = Color(0xFFFFD700); // Gold
                  medalIcon = Icons.workspace_premium;
                } else if (customer.srNo == 2) {
                  rankColor = Color(0xFFC0C0C0); // Silver
                  medalIcon = Icons.workspace_premium;
                } else if (customer.srNo == 3) {
                  rankColor = Color(0xFFCD7F32); // Bronze
                  medalIcon = Icons.workspace_premium;
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (medalIcon != null) ...[
                            Icon(medalIcon, color: rankColor, size: AppResponsive.getValue(context, mobile: 18.0, desktop: 20.0)),
                            SizedBox(width: 4),
                          ],
                          Text(
                            customer.srNo.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: cellFontSize,
                              color: AppColors.textPrimary,
                              fontWeight: customer.srNo <= 3 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        customer.name,
                        style: GoogleFonts.poppins(
                          fontSize: cellFontSize,
                          color: AppColors.textPrimary,
                          fontWeight: customer.srNo <= 3 ? FontWeight.w600 : FontWeight.w400,
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
                          color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          customer.orderCount.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
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
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(customer.revenue)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
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

class CustomerRevenueData {
  int srNo;
  final String name;
  double revenue;
  int orderCount;

  CustomerRevenueData({
    required this.srNo,
    required this.name,
    required this.revenue,
    required this.orderCount,
  });
}