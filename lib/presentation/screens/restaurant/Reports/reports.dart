import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/pos%20End%20Day%20Report/posenddayreport.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/customer%20list%20by%20revenue/customerlistbyrevenue.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/expenseReport/expensereport.dart';
import 'package:unipos/util/color.dart';
import '../../../../core/routes/routes_name.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1 * iconColor.a),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: isTablet ? 30 : 28,
              ),
            ),
            SizedBox(height: isTablet ? 14 : 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1200;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Header
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
                          'Operational Reports',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View detailed business reports',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 10 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: isTablet ? 22 : 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 8),

          // Reports Grid
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int columns = 2;
                  if (isDesktop) {
                    columns = 4;
                  } else if (isTablet) {
                    columns = 3;
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: isTablet ? 16 : 12,
                    mainAxisSpacing: isTablet ? 16 : 12,
                    childAspectRatio: isTablet ? 1.2 : 1.1,
                    children: [
                      _buildReportCard(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Total Sale',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsTotalSales),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.fastfood,
                        title: 'Sales BY Items',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsSalesBYItem),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.category,
                        title: 'Sale By Category',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsSalesByCategory),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.auto_graph,
                        title: 'Daily Closing Reports',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsDailyClosingReport),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.graphic_eq_outlined,
                        title: 'Sales By Top Selling',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsSalesByTop),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.list_alt,
                        title: 'Customer List',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsCustomerList),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.view_week,
                        title: 'Comparison BY Week',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByWeek),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.calendar_month,
                        title: 'Comparison BY Month',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByMonth),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.calendar_today,
                        title: 'Comparison BY Year',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByYear),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'Comparison BY Product',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByProduct),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.backspace_outlined,
                        title: 'Refund Details',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsRefundDetails),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.cancel_outlined,
                        title: 'Void Order Report',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsVoidOrderReport),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.note_alt_outlined,
                        title: 'Discount Order Reports',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsDiscountOrderReport),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.event_available,
                        title: 'Pos End Day',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Posenddayreport())),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.monetization_on_outlined,
                        title: 'Customer List BY Revenue',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerListByRevenue())),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.receipt_long,
                        title: 'Expense Report',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseReport())),
                        iconColor: Colors.red,
                        isTablet: isTablet,
                      ),
                      _buildReportCard(
                        icon: Icons.analytics,
                        title: 'Performance Statistics',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantPerformanceStats),
                        iconColor: Colors.purple,
                        isTablet: isTablet,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}