import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/pos%20End%20Day%20Report/posenddayreport.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/customer%20list%20by%20revenue/customerlistbyrevenue.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/expenseReport/expensereport.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
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
    String? entitlementKey,
  }) {
    return GestureDetector(
      onTap: () {
        // Entitlement denied → upgrade blocker instead of opening the report.
        if (entitlementKey != null &&
            !PlanGuard.allowedOr(context, entitlementKey, featureName: title)) {
          return;
        }
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
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
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Reports'),
      body: SingleChildScrollView(
              padding: AppResponsive.padding(context),
              child: GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: AppResponsive.gridColumns(context, mobile: 2, tablet: 3, desktop: 4),
                    crossAxisSpacing: AppResponsive.gridSpacing(context),
                    mainAxisSpacing: AppResponsive.gridSpacing(context),
                    childAspectRatio: AppResponsive.gridAspectRatio(context),
                    children: [
                      // All report tiles are shown; tapping a tile not in the plan
                      // shows the upgrade blocker (handled in _buildReportCard).
                      _buildReportCard(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Total Sale',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsTotalSales),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsTotalSale,
                      ),
                      _buildReportCard(
                        icon: Icons.fastfood,
                        title: 'Sales BY Items',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsSalesBYItem),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsSaleByItem,
                      ),
                      _buildReportCard(
                        icon: Icons.category,
                        title: 'Sale By Category',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsSalesByCategory),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsSaleByCategory,
                      ),
                      _buildReportCard(
                        icon: Icons.auto_graph,
                        title: 'Daily Closing Reports',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsDailyClosingReport),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsDailyClosing,
                      ),
                      _buildReportCard(
                        icon: Icons.list_alt,
                        title: 'Customer List',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsCustomerList),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsCustomerList,
                      ),
                      _buildReportCard(
                        icon: Icons.view_week,
                        title: 'Comparison BY Week',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByWeek),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsComparisonWeek,
                      ),
                      _buildReportCard(
                        icon: Icons.calendar_month,
                        title: 'Comparison BY Month',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByMonth),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsComparisonMonth,
                      ),
                      _buildReportCard(
                        icon: Icons.calendar_today,
                        title: 'Comparison BY Year',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByYear),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsComparisonYear,
                      ),
                      _buildReportCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'Comparison BY Product',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByProduct),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsComparisonProduct,
                      ),
                      _buildReportCard(
                        icon: Icons.backspace_outlined,
                        title: 'Refund Details',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsRefundDetails),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsRefundDetails,
                      ),
                      _buildReportCard(
                        icon: Icons.cancel_outlined,
                        title: 'Void Order Report',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsVoidOrderReport),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsVoidOrders,
                      ),
                      _buildReportCard(
                        icon: Icons.remove_circle_outline,
                        title: 'Item Cancellation Report',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsItemCancellation),
                        iconColor: Colors.red,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsItemCancellation,
                      ),
                      _buildReportCard(
                        icon: Icons.note_alt_outlined,
                        title: 'Discount Order Reports',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReportsDiscountOrderReport),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsDiscountOrders,
                      ),
                      _buildReportCard(
                        icon: Icons.event_available,
                        title: 'Pos End Day',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Posenddayreport())),
                        iconColor: AppColors.primary,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsPosEndDay,
                      ),
                      _buildReportCard(
                        icon: Icons.monetization_on_outlined,
                        title: 'Customer List BY Revenue',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerListByRevenue())),
                        iconColor: Colors.deepOrangeAccent,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsCustomerRevenue,
                      ),
                      _buildReportCard(
                        icon: Icons.receipt_long,
                        title: 'Expense Report',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseReport())),
                        iconColor: Colors.red,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsExpense,
                      ),
                      _buildReportCard(
                        icon: Icons.analytics,
                        title: 'Performance Statistics',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantPerformanceStats),
                        iconColor: Colors.purple,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsPerformanceStatistics,
                      ),
                      _buildReportCard(
                        icon: Icons.badge_outlined,
                        title: 'Shift Report',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantShiftReport),
                        iconColor: Colors.teal,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsShift,
                      ),
                      _buildReportCard(
                        icon: Icons.leaderboard_rounded,
                        title: 'Staff Performance',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantStaffPerformance),
                        iconColor: Colors.deepPurple,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsStaffPerformance,
                      ),
                      _buildReportCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Cash Drawer History',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantCashDrawerHistory),
                        iconColor: Colors.teal,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsCashDrawerHistory,
                      ),
                      _buildReportCard(
                        icon: Icons.access_time_rounded,
                        title: 'Attendance Report',
                        onTap: () => Navigator.pushNamed(context, RouteNames.restaurantAttendanceReport),
                        iconColor: Colors.deepPurple,
                        isTablet: isTablet,
                        entitlementKey: EntKeys.reportsAttendance,
                      ),
                    ],
                  ),
            ),
    );
  }
}