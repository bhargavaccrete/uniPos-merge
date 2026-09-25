import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/comparison/comparison.dart'
    show kComparisonPeriodEntitlements;
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
    List<String>? entitlementAnyOf,
  }) {
    return GestureDetector(
      onTap: () {
        // Entitlement denied → upgrade blocker instead of opening the report.
        if (entitlementKey != null &&
            !PlanGuard.allowedOr(context, entitlementKey, featureName: title)) {
          return;
        }
        if (entitlementAnyOf != null &&
            !PlanGuard.allowedAnyOf(
              context,
              entitlementAnyOf,
              featureName: title,
            )) {
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
              child: Icon(icon, color: iconColor, size: isTablet ? 30 : 28),
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
                  fontSize: AppResponsive.bodyFontSize(context),
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
      body: AppResponsive.constrainedContent(
        context: context,
        maxWidth: AppResponsive.maxContentWidth(context),
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: AppResponsive.padding(context),
          // Grouped into sections rather than one wall of tiles. Each section
          // is its own shrink-wrapped grid inside a Column; none of them
          // scrolls — the SingleChildScrollView above owns that.
          //
          // All tiles are still SHOWN whatever the plan says; tapping one that
          // is not granted opens the upgrade blocker (see _buildReportCard).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Sales & Operations'),
              _grid(_salesTiles(isTablet)),
              _sectionHeader('Purchasing'),
              _grid(_purchasingTiles(isTablet)),
              _sectionHeader('Inventory'),
              _grid(_inventoryTiles(isTablet)),
            ],
          ),
        ),
      ),
    );
  }

  /// Section label above each grid.
  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppResponsive.mediumSpacing(context),
        bottom: AppResponsive.smallSpacing(context),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// One section grid. Same geometry for every section, so the tiles line up
  /// across section boundaries instead of each group sizing itself.
  Widget _grid(List<Widget> tiles) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: AppResponsive.gridColumns(
        context,
        mobile: 2,
        tablet: 3,
        desktop: 4,
      ),
      crossAxisSpacing: AppResponsive.gridSpacing(context),
      mainAxisSpacing: AppResponsive.gridSpacing(context),
      childAspectRatio: AppResponsive.gridAspectRatio(context),
      children: tiles,
    );
  }

  List<Widget> _salesTiles(bool isTablet) {
    return [
              _buildReportCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Total Sale',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsTotalSales,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsTotalSale,
              ),
              _buildReportCard(
                icon: Icons.fastfood,
                title: 'Sales BY Items',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsSalesBYItem,
                ),
                iconColor: Colors.deepOrangeAccent,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsSaleByItem,
              ),
              _buildReportCard(
                icon: Icons.category,
                title: 'Sale By Category',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsSalesByCategory,
                ),
                iconColor: Colors.deepOrangeAccent,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsSaleByCategory,
              ),
              _buildReportCard(
                icon: Icons.auto_graph,
                title: 'Daily Closing Reports',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsDailyClosingReport,
                ),
                iconColor: Colors.deepOrangeAccent,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsDailyClosing,
              ),
              _buildReportCard(
                icon: Icons.list_alt,
                title: 'Customer List',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsCustomerList,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsCustomerList,
              ),
              _buildReportCard(
                icon: Icons.trending_up,
                title: 'Sales Comparison',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsSalesComparison,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementAnyOf: kComparisonPeriodEntitlements,
              ),
              _buildReportCard(
                icon: Icons.inventory_2_outlined,
                title: 'Comparison BY Product',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsComparisionByProduct,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsComparisonProduct,
              ),
              _buildReportCard(
                icon: Icons.backspace_outlined,
                title: 'Refund Details',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsRefundDetails,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsRefundDetails,
              ),
              _buildReportCard(
                icon: Icons.cancel_outlined,
                title: 'Void Order Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsVoidOrderReport,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsVoidOrders,
              ),
              _buildReportCard(
                icon: Icons.remove_circle_outline,
                title: 'Item Cancellation Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsItemCancellation,
                ),
                iconColor: Colors.red,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsItemCancellation,
              ),
              _buildReportCard(
                icon: Icons.note_alt_outlined,
                title: 'Discount Order Reports',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsDiscountOrderReport,
                ),
                iconColor: Colors.deepOrangeAccent,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsDiscountOrders,
              ),
              _buildReportCard(
                icon: Icons.event_available,
                title: 'Pos End Day',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPosOrder,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPosEndDay,
              ),
              _buildReportCard(
                icon: Icons.monetization_on_outlined,
                title: 'Customer List BY Revenue',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsCustomerListByRevenue,
                ),
                iconColor: Colors.deepOrangeAccent,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsCustomerRevenue,
              ),
              _buildReportCard(
                icon: Icons.receipt_long,
                title: 'Expense Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsExpense,
                ),
                iconColor: Colors.red,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsExpense,
              ),
              _buildReportCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Sales by Payment Mode',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPaymentMode,
                ),
                iconColor: Colors.teal,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPaymentMode,
              ),
              _buildReportCard(
                icon: Icons.analytics,
                title: 'Performance Statistics',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantPerformanceStats,
                ),
                iconColor: Colors.purple,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPerformanceStatistics,
              ),
              _buildReportCard(
                icon: Icons.badge_outlined,
                title: 'Shift Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantShiftReport,
                ),
                iconColor: Colors.teal,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsShift,
              ),
              _buildReportCard(
                icon: Icons.leaderboard_rounded,
                title: 'Staff Performance',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantStaffPerformance,
                ),
                iconColor: Colors.deepPurple,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsStaffPerformance,
              ),
              _buildReportCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Cash Drawer History',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantCashDrawerHistory,
                ),
                iconColor: Colors.teal,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsCashDrawerHistory,
              ),
              _buildReportCard(
                icon: Icons.access_time_rounded,
                title: 'Attendance Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantAttendanceReport,
                ),
                iconColor: Colors.deepPurple,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsAttendance,
              ),

              // layout regression can't be mistaken for a report bug.
    ];
  }

  /// Purchasing — the supplier/PO/GRN chain. All nine are gated by their own
  /// `reports.*` key, which the manifest must grant.
  List<Widget> _purchasingTiles(bool isTablet) {
    return [
              _buildReportCard(
                icon: Icons.assessment_outlined,
                title: 'Purchase Summary',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPurchaseSummary,
                ),
                iconColor: AppColors.primary,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPurchaseSummary,
              ),
              _buildReportCard(
                icon: Icons.receipt_long_rounded,
                title: 'GRN Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsGrn,
                ),
                iconColor: AppColors.success,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsGrn,
              ),
              _buildReportCard(
                icon: Icons.local_shipping_rounded,
                title: 'Supplier-wise Purchases',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsSupplierPurchase,
                ),
                iconColor: Colors.indigo,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsSupplierPurchase,
              ),
              _buildReportCard(
                icon: Icons.hourglass_top_rounded,
                title: 'Pending Purchase Orders',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPoPending,
                ),
                iconColor: AppColors.warning,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPoStatus,
              ),
              _buildReportCard(
                icon: Icons.incomplete_circle_rounded,
                title: 'Partially Received Orders',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPoPartial,
                ),
                iconColor: Colors.orange,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPoStatus,
              ),
              _buildReportCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Completed Orders',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPoCompleted,
                ),
                iconColor: Colors.green,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPoStatus,
              ),
              _buildReportCard(
                icon: Icons.report_gmailerrorred_rounded,
                title: 'Damaged Items',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsDamagedItems,
                ),
                iconColor: AppColors.danger,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsDamagedItems,
              ),
              _buildReportCard(
                icon: Icons.assignment_return_rounded,
                title: 'Purchase Returns',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsPurchaseReturn,
                ),
                iconColor: Colors.blueGrey,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsPurchaseReturn,
              ),
              _buildReportCard(
                icon: Icons.account_balance_rounded,
                title: 'Supplier Statement',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsSupplierStatement,
                ),
                iconColor: Colors.deepOrange,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsSupplierStatement,
              ),
    ];
  }

  List<Widget> _inventoryTiles(bool isTablet) {
    return [
              _buildReportCard(
                icon: Icons.tune_rounded,
                title: 'Stock Adjustments',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsStockAdjustment,
                ),
                iconColor: Colors.brown,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsStockAdjustment,
              ),
              _buildReportCard(
                icon: Icons.warning_amber_rounded,
                title: 'Low Stock Report',
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.restaurantReportsLowStock,
                ),
                iconColor: AppColors.warning,
                isTablet: isTablet,
                entitlementKey: EntKeys.reportsLowStock,
              ),
    ];
  }

}
