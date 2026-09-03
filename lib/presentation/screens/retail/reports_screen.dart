import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/screens/retail/reports/daily_sales_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/monthly_sales_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/product_wise_sales_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/variant_wise_sales_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/category_wise_sales_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/supplier_wise_purchase_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/low_stock_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/stock_adjustment_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/top_selling_products_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/profit_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/purchase_summary_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/purchase_order_status_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/grn_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/damaged_items_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/purchase_return_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/cash_drawer_history_report_screen.dart';
// Financial reports that already existed but were only reachable from Settings,
// or (in Credit's case) not reachable at all.
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/presentation/screens/retail/gst_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/credit_reports_screen.dart';
import 'package:billberrylite/presentation/screens/retail/eod_reports_list_screen.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/presentation/screens/common/attendance/attendance_report_screen.dart';
import 'package:billberrylite/presentation/screens/common/shift/shift_report_screen.dart';
import 'package:billberrylite/presentation/screens/common/shift/staff_performance_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      // The restaurant hub uses buildPrimaryAppBar rather than reportAppBar —
      // it is a menu of reports, not a report.
      appBar: buildPrimaryAppBar(title: 'Reports'),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        child: ListView(
          padding: AppResponsive.padding(context),
          children: [
            _buildSectionHeader(context, 'Sales Reports'),
            _buildReportCard(
              context,
              title: 'Daily Sales',
              subtitle: 'View sales for a specific date',
              icon: Icons.today,
              color: const Color(0xFF2196F3),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailySalesReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsDailySales,
            ),
            _buildReportCard(
              context,
              title: 'Monthly Sales',
              subtitle: 'View monthly sales breakdown',
              icon: Icons.calendar_month,
              color: const Color(0xFF9C27B0),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonthlySalesReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsMonthlySales,
            ),
            _buildReportCard(
              context,
              title: 'Product-wise Sales',
              subtitle: 'Sales grouped by products',
              icon: Icons.shopping_bag,
              color: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductWiseSalesReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsSaleByProduct,
            ),
            _buildReportCard(
              context,
              title: 'Variant-wise Sales',
              subtitle: 'Sales grouped by product variants',
              icon: Icons.settings,
              color: const Color(0xFFFF9800),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VariantWiseSalesReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsSaleByVariant,
            ),
            _buildReportCard(
              context,
              title: 'Category-wise Sales',
              subtitle: 'Sales grouped by categories',
              icon: Icons.category,
              color: const Color(0xFF00BCD4),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryWiseSalesReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsSaleByCategory,
            ),
            _buildReportCard(
              context,
              title: 'Top Selling Products',
              subtitle: 'Best performing products',
              icon: Icons.trending_up,
              color: const Color(0xFFE91E63),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TopSellingProductsReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsTopSelling,
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Purchase Reports'),
            _buildReportCard(
              context,
              title: 'Purchase Summary',
              subtitle: 'Ordered vs received, and what it cost',
              icon: Icons.assessment,
              color: const Color(0xFF3F51B5),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseSummaryReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsPurchaseSummary,
            ),
            _buildReportCard(
              context,
              title: 'Supplier-wise Purchases',
              subtitle: 'Spend per supplier, based on goods received',
              icon: Icons.local_shipping,
              color: const Color(0xFF673AB7),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const SupplierWisePurchaseReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsSupplierPurchase,
            ),
            _buildReportCard(
              context,
              title: 'Pending Purchase Orders',
              subtitle: 'Sent to supplier, awaiting delivery',
              icon: Icons.hourglass_top,
              color: const Color(0xFFFF9800),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const PurchaseOrderStatusReportScreen.pending(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsPoStatus,
            ),
            _buildReportCard(
              context,
              title: 'Partially Received Orders',
              subtitle: 'Some goods still outstanding',
              icon: Icons.incomplete_circle,
              color: const Color(0xFF00BCD4),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const PurchaseOrderStatusReportScreen.partiallyReceived(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsPoStatus,
            ),
            _buildReportCard(
              context,
              title: 'Completed Orders',
              subtitle: 'Fully received purchase orders',
              icon: Icons.check_circle,
              color: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const PurchaseOrderStatusReportScreen.completed(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsPoStatus,
            ),
            _buildReportCard(
              context,
              title: 'GRN Report',
              subtitle: 'Confirmed goods receipts',
              icon: Icons.receipt_long,
              color: const Color(0xFF009688),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GRNReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsGrn,
            ),
            _buildReportCard(
              context,
              title: 'Damaged Items',
              subtitle: 'Received damaged, grouped by outcome',
              icon: Icons.report_gmailerrorred,
              color: const Color(0xFFE53935),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DamagedItemsReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsDamagedItems,
            ),
            _buildReportCard(
              context,
              title: 'Purchase Returns',
              subtitle: 'Returned to supplier and credit note status',
              icon: Icons.assignment_return,
              color: const Color(0xFF795548),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseReturnReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsPurchaseReturn,
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Inventory Reports'),
            _buildReportCard(
              context,
              title: 'Low Stock Alert',
              subtitle: 'Products running low on stock',
              icon: Icons.warning_amber,
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LowStockReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsLowStock,
            ),
            _buildReportCard(
              context,
              title: 'Stock Adjustments',
              subtitle: 'Manual stock corrections and who made them',
              icon: Icons.tune_rounded,
              color: const Color(0xFF7E57C2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StockAdjustmentReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsStockAdjustment,
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Financial Reports'),
            _buildReportCard(
              context,
              title: 'Profit Report',
              subtitle: 'Revenue vs Cost analysis',
              icon: Icons.attach_money,
              color: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfitReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsProfit,
            ),
            _buildReportCard(
              context,
              // "GST Report" only where the tax is called GST. The
              // subtitle already says "Output tax", which is true everywhere.
              title: TaxLabelRule.reportTitle,
              subtitle: 'Output tax by rate, product and category',
              icon: Icons.receipt,
              color: const Color(0xFF00796B),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GstReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsGst,
            ),
            _buildReportCard(
              context,
              title: 'Credit Reports',
              subtitle: 'Credit sales, collections and outstanding',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF5D4037),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreditReportsScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.billingCredit,
            ),
            _buildReportCard(
              context,
              title: 'Cash Drawer History',
              subtitle: 'Cash in and out over time',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF00897B),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CashDrawerHistoryReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsCashDrawerHistory,
            ),
            _buildReportCard(
              context,
              title: 'End of Day History',
              subtitle: 'Past day closes and cash reconciliation',
              icon: Icons.event_available,
              color: const Color(0xFF455A64),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EODReportsListScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsEodHistory,
            ),
            _buildSectionHeader(context, 'Staff Reports'),
            _buildReportCard(
              context,
              title: 'Attendance',
              subtitle: 'Clock-in hours per staff member',
              icon: Icons.how_to_reg,
              color: const Color(0xFFEC407A),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsAttendance,
            ),
            _buildReportCard(
              context,
              title: 'Shift Report',
              subtitle: 'Shifts with sales and expenses',
              icon: Icons.schedule,
              color: const Color(0xFF5C6BC0),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShiftReportScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsShift,
            ),
            _buildReportCard(
              context,
              title: 'Staff Performance',
              subtitle: 'Sales and hours per staff member',
              icon: Icons.leaderboard,
              color: const Color(0xFF26A69A),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StaffPerformanceScreen(),
                ),
              ),
              entitlementKey: RetailEntKeys.reportsStaffPerformance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppResponsive.smallSpacing(context),
        top: AppResponsive.smallSpacing(context),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.subheadingFontSize(context),
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? entitlementKey,
  }) {
    final iconBox = AppResponsive.largeIconSize(context) * 1.5;

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: ListTile(
        contentPadding: AppResponsive.listTilePadding(context),
        leading: Container(
          width: iconBox,
          height: iconBox,
          decoration: BoxDecoration(
            // `color` is this report's own identity, kept as-is.
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: AppResponsive.iconSize(context),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.textSecondary,
        ),
        // Show-and-block: the tile stays visible and the upgrade sheet explains
        // why, matching the restaurant hub. Tiles with no key are always open.
        onTap: entitlementKey == null
            ? onTap
            : () {
                if (!PlanGuard.allowedOr(
                  context,
                  entitlementKey,
                  featureName: title,
                )) {
                  return;
                }
                onTap();
              },
      ),
    );
  }
}
