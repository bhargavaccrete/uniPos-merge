import 'package:flutter/material.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/Discount%20Order%20Report/dicountOrderReport.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/comparisonbyproduct/comparisonproduct.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/dailyClosingReports/dailyclosing.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/pos%20End%20Day%20Report/posenddayreport.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/refundDetails/refunddetails.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbyCategory/salesbycategory.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbyItem/salesbyitem.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/totalsales/totalsales.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_damaged_items_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_grn_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_low_stock_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_purchase_return_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_stock_adjustment_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_supplier_statement_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_purchase_order_status_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_purchase_summary_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/purchase/restaurant_supplier_wise_purchase_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/data_generator_screen.dart';
import 'package:billberrylite/presentation/screens/common/attendance/staff_attendance_screen.dart';
import 'package:billberrylite/presentation/screens/common/attendance/attendance_report_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/import/bulk_import_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/order.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/import/test_data_screen.dart';

// Core Screens
import 'package:billberrylite/presentation/screens/onboarding/splashScreen.dart';
import 'package:billberrylite/presentation/screens/onboarding/animated_splash_screen.dart';
import 'package:billberrylite/presentation/screens/onboarding/walkthroughScreen.dart';
import 'package:billberrylite/presentation/screens/onboarding/userSelectionScreen.dart';
import 'package:billberrylite/presentation/screens/onboarding/existingUserRestoreScreen.dart';
import 'package:billberrylite/presentation/screens/onboarding/license_key_entry_screen.dart';
import 'package:billberrylite/presentation/screens/onboarding/setupWizardScreen.dart';

// Restaurant - Auth
import 'package:billberrylite/presentation/screens/restaurant/auth/restaurant_login.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/restaurant_guard.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/license_lock_screen.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';

// Restaurant - Home & Dashboard
import 'package:billberrylite/presentation/screens/restaurant/welcome_Admin.dart';
import 'package:billberrylite/presentation/screens/restaurant/usage_limit_screen.dart';
import 'package:billberrylite/presentation/screens/common/notifications/notifications_screen.dart';

// Restaurant - Orders
import 'package:billberrylite/presentation/screens/restaurant/start%20order/startorder.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/activeorder.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/pastorder.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/orderDetails.dart';

// Restaurant - Tables
import 'package:billberrylite/presentation/screens/restaurant/tabbar/table.dart';

// Restaurant - Menu
import 'package:billberrylite/presentation/screens/restaurant/tabbar/menu.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/manage_menu_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/setup_add_item_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/category_management_screen.dart';

// Restaurant - Customers
import 'package:billberrylite/presentation/screens/restaurant/customer/customer_list_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/customer/manage_customers_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/customer/customer_detail_screen.dart';

// Restaurant - Online Orders
import 'package:billberrylite/presentation/screens/restaurant/online%20Order/online.dart';
import 'package:billberrylite/presentation/screens/restaurant/online%20Order/inProgress.dart';
import 'package:billberrylite/presentation/screens/restaurant/online%20Order/Completed.dart';
import 'package:billberrylite/presentation/screens/restaurant/online%20Order/missed.dart';

// Restaurant - Inventory
import 'package:billberrylite/presentation/screens/restaurant/inventory/manage_Inventory.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/low_stock_screen.dart';

// Restaurant - Staff
import 'package:billberrylite/presentation/screens/common/staff/manage_staff_screen.dart';

// Restaurant - Expenses
import 'package:billberrylite/presentation/screens/restaurant/Expense/Expense.dart';
import 'package:billberrylite/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:billberrylite/presentation/screens/restaurant/Expense/viewexpense.dart';
import 'package:billberrylite/presentation/screens/restaurant/Expense/managecategory.dart';

// Restaurant - Reports
import 'package:billberrylite/presentation/screens/restaurant/Reports/reports.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/performance_statistics_report.dart';

// Restaurant - Settings
import 'package:billberrylite/presentation/screens/restaurant/Settings/settingsScreen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/orderSettings.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/paymentsMethods.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/changePassword.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/licensing_screen.dart';
import 'package:billberrylite/presentation/screens/retail/store_info_settings_screen.dart';

// Restaurant - Tax
import 'package:billberrylite/presentation/screens/restaurant/TaxSetting/apply_tax_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/TaxSetting/addMultipleTax.dart';

// Restaurant - Printer
import 'package:billberrylite/presentation/screens/restaurant/printerSetting/printersetting.dart';
import 'package:billberrylite/presentation/screens/restaurant/printerSetting/customization.dart';

// Restaurant - End Day
import 'package:billberrylite/presentation/screens/restaurant/end%20day/endday.dart';

// Restaurant - Other
import 'package:billberrylite/presentation/screens/restaurant/need%20help/needhelp.dart';
import 'package:billberrylite/presentation/screens/restaurant/customiztion/customization_drawer.dart';

import '../../presentation/screens/restaurant/Reports/comparison/comparison.dart';
import '../../presentation/screens/restaurant/Reports/customer list by revenue/customerlistbyrevenue.dart';
import '../../presentation/screens/restaurant/Reports/customerList/customerlist.dart';
import '../../presentation/screens/restaurant/Reports/expenseReport/expensereport.dart';
import '../../presentation/screens/restaurant/Reports/paymentMode/payment_mode_report.dart';
import '../../presentation/screens/restaurant/Reports/void Order Report/voidOrderReport.dart';
import '../../presentation/screens/restaurant/Reports/item Cancellation Report/itemCancellationReport.dart';
import '../../presentation/screens/common/printer/addprinter/addprinter.dart';
import '../../presentation/screens/common/shift/shift_report_screen.dart';
import '../../presentation/screens/common/shift/staff_performance_screen.dart';
import '../../presentation/screens/restaurant/cash_drawer/cash_drawer_screen.dart';
import '../../presentation/screens/restaurant/cash_drawer/cash_drawer_history_screen.dart';

class RestaurantRoutes {
  /// Wraps a widget builder with [RestaurantGuard] to enforce login + optional role check.
  /// [permission] maps to a key in [RestaurantSession.canAccess].
  static WidgetBuilder _guard(
    Widget child, [
    String? permission,
    String? entitlement,
  ]) =>
      (_) => RestaurantGuard(
        child: child,
        permissionKey: permission,
        entitlementKey: entitlement,
      );

  static Map<String, WidgetBuilder> get routes => {
    // Core (restaurant flow)
    RouteNames.splash: (_) => const SplashScreen(),
    RouteNames.walkthrough: (_) => const WalkthroughScreen(),
    RouteNames.userSelection: (_) => const UserSelectionScreen(),
    RouteNames.restore: (_) => const ExistingUserRestoreScreen(),
    RouteNames.licenseKeyEntry: (_) => const LicenseKeyEntryScreen(),
    RouteNames.licenseLock: (context) => LicenseLockScreen(
      onActivated: () {
        LicenseStore.navigateToNextScreen(context);
      },
    ),
    RouteNames.setupWizard: (_) => const SetupWizardScreen(),

    // Restaurant - Auth
    RouteNames.restaurantLogin: (_) => const RestaurantLogin(),

    // Restaurant - Home & Dashboard
    RouteNames.restaurantHome: _guard(const AdminWelcome()),
    RouteNames.restaurantNotifications: _guard(const NotificationsScreen()),

    // Restaurant - Orders
    RouteNames.restaurantStartOrder: _guard(
      const Startorder(),
      'startOrder',
      EntKeys.billing,
    ),
    RouteNames.restaurantOrder: _guard(
      const Order(),
      'startOrder',
      EntKeys.billing,
    ),
    RouteNames.restaurantActiveOrders: _guard(
      const Activeorder(),
      'startOrder',
      EntKeys.billing,
    ),
    RouteNames.restaurantPastOrders: _guard(
      const Pastorder(),
      'startOrder',
      EntKeys.billing,
    ),
    RouteNames.restaurantOrderDetails: _guard(
      const Orderdetails(),
      'startOrder',
      EntKeys.billing,
    ),

    // Restaurant - Tables
    RouteNames.restaurantTables: _guard(
      const TableScreen(),
      'startOrder',
      EntKeys.billingTables,
    ),

    // Restaurant - Menu
    RouteNames.restaurantAdminWelcome: _guard(const AdminWelcome()),
    RouteNames.restaurantManageMenu: _guard(
      const Managemenu(),
      'manageMenu',
      EntKeys.manageMenu,
    ),
    RouteNames.restaurantAddItem: _guard(
      const SetupAddItemScreen(),
      'manageMenu',
      EntKeys.manageMenuItems,
    ),
    RouteNames.restaurantCategoryManagement: _guard(
      const CategoryManagementScreen(),
      'manageMenu',
      EntKeys.manageMenuCategories,
    ),

    // Restaurant - Customers
    RouteNames.restaurantCustomers: _guard(
      const CustomerListScreen(),
      'customers',
      EntKeys.customers,
    ),
    RouteNames.restaurantManageCustomers: _guard(
      const ManageCustomersScreen(),
      'customers',
      EntKeys.customers,
    ),

    /*
    // Restaurant - Online Orders
    RouteNames.restaurantOnlineOrders: (_) => const OnlineOrders(),
    RouteNames.restaurantOnlineInProgress: (_) => const InProgressOnline(),
    RouteNames.restaurantOnlineCompleted: (_) => const CompletedOnline(),
    RouteNames.restaurantOnlineMissed: (_) => const MissedOnline(),
*/

    // Restaurant - Inventory
    RouteNames.restaurantInventory: _guard(
      const ManageInventory(),
      'inventory',
      EntKeys.inventory,
    ),

    // Same role + entitlement as the Inventory hub it lives under, so reaching
    // it from a notification can't bypass a gate the hub would have applied.
    RouteNames.restaurantLowStock: _guard(
      const LowStockScreen(),
      'inventory',
      EntKeys.inventory,
    ),

    // Restaurant - Staff
    RouteNames.restaurantStaff: _guard(
      const ManageStaffScreen(),
      'manageStaff',
      EntKeys.users,
    ),

    // Restaurant - Expenses
    RouteNames.restaurantExpenses: _guard(
      const ExpenseScreen(),
      'expenses',
      EntKeys.expenses,
    ),
    RouteNames.restaurantAddExpense: _guard(
      const Addexpence(),
      'expenses',
      EntKeys.expenses,
    ),
    RouteNames.restaurantViewExpense: _guard(
      const ViewExpense(),
      'expenses',
      EntKeys.expenses,
    ),
    RouteNames.restaurantExpenseCategory: _guard(
      const ManageCategory(),
      'expenses',
      EntKeys.expenses,
    ),

    // Restaurant - Reports
    RouteNames.restaurantReports: _guard(
      const ReportsScreen(),
      'reports',
      EntKeys.reports,
    ),
    RouteNames.restaurantPerformanceStats: _guard(
      const PerformanceStatisticsReport(),
      'reports',
      EntKeys.reportsPerformanceStatistics,
    ),
    RouteNames.restaurantReportsTotalSales: _guard(
      const Totalsales(),
      'reports',
      EntKeys.reportsTotalSale,
    ),

    // ── Purchasing reports ──────────────────────────────────────────────
    // All three PO-status routes share EntKeys.reportsPoStatus: they are
    // named constructors of one screen over one dataset.
    RouteNames.restaurantReportsPurchaseSummary: _guard(
      const RestaurantPurchaseSummaryReportScreen(),
      'reports',
      EntKeys.reportsPurchaseSummary,
    ),
    RouteNames.restaurantReportsSupplierPurchase: _guard(
      const RestaurantSupplierWisePurchaseReportScreen(),
      'reports',
      EntKeys.reportsSupplierPurchase,
    ),
    RouteNames.restaurantReportsPoPending: _guard(
      const RestaurantPurchaseOrderStatusReportScreen.pending(),
      'reports',
      EntKeys.reportsPoStatus,
    ),
    RouteNames.restaurantReportsPoPartial: _guard(
      const RestaurantPurchaseOrderStatusReportScreen.partiallyReceived(),
      'reports',
      EntKeys.reportsPoStatus,
    ),
    RouteNames.restaurantReportsPoCompleted: _guard(
      const RestaurantPurchaseOrderStatusReportScreen.completed(),
      'reports',
      EntKeys.reportsPoStatus,
    ),
    RouteNames.restaurantReportsGrn: _guard(
      const RestaurantGRNReportScreen(),
      'reports',
      EntKeys.reportsGrn,
    ),
    RouteNames.restaurantReportsDamagedItems: _guard(
      const RestaurantDamagedItemsReportScreen(),
      'reports',
      EntKeys.reportsDamagedItems,
    ),
    RouteNames.restaurantReportsPurchaseReturn: _guard(
      const RestaurantPurchaseReturnReportScreen(),
      'reports',
      EntKeys.reportsPurchaseReturn,
    ),
    RouteNames.restaurantReportsStockAdjustment: _guard(
      const RestaurantStockAdjustmentReportScreen(),
      'reports',
      EntKeys.reportsStockAdjustment,
    ),
    RouteNames.restaurantReportsLowStock: _guard(
      const RestaurantLowStockReportScreen(),
      'reports',
      EntKeys.reportsLowStock,
    ),
    RouteNames.restaurantReportsSupplierStatement: _guard(
      const RestaurantSupplierStatementReportScreen(),
      'reports',
      EntKeys.reportsSupplierStatement,
    ),
    RouteNames.restaurantReportsSalesBYItem: _guard(
      Salesbyitem(),
      'reports',
      EntKeys.reportsSaleByItem,
    ),
    RouteNames.restaurantReportsSalesByCategory: _guard(
      SalesByCategory(),
      'reports',
      EntKeys.reportsSaleByCategory,
    ),
    RouteNames.restaurantReportsDailyClosingReport: _guard(
      DailyClosingReport(),
      'reports',
      EntKeys.reportsDailyClosing,
    ),
    RouteNames.restaurantReportsCustomerList: _guard(
      CustomerListReport(),
      'reports',
      EntKeys.reportsCustomerList,
    ),
    // Periods gate themselves inside the screen; the route opens if any is granted.
    RouteNames.restaurantReportsSalesComparison: (_) => RestaurantGuard(
      permissionKey: 'reports',
      entitlementAnyOf: kComparisonPeriodEntitlements,
      child: const SalesComparison(),
    ),
    RouteNames.restaurantReportsComparisionByProduct: _guard(
      ComparisonByProduct(),
      'reports',
      EntKeys.reportsComparisonProduct,
    ),
    RouteNames.restaurantReportsRefundDetails: _guard(
      RefundDetails(),
      'reports',
      EntKeys.reportsRefundDetails,
    ),
    RouteNames.restaurantReportsDiscountOrderReport: _guard(
      DiscountOrderReport(),
      'reports',
      EntKeys.reportsDiscountOrders,
    ),
    RouteNames.restaurantReportsPosOrder: _guard(
      Posenddayreport(),
      'reports',
      EntKeys.reportsPosEndDay,
    ),
    RouteNames.restaurantReportsCustomerListByRevenue: _guard(
      CustomerListByRevenue(),
      'reports',
      EntKeys.reportsCustomerRevenue,
    ),
    RouteNames.restaurantReportsExpense: _guard(
      ExpenseReport(),
      'reports',
      EntKeys.reportsExpense,
    ),
    RouteNames.restaurantReportsPaymentMode: _guard(
      const PaymentModeReport(),
      'reports',
      EntKeys.reportsPaymentMode,
    ),
    RouteNames.restaurantReportsVoidOrderReport: _guard(
      VoidOrderReport(),
      'reports',
      EntKeys.reportsVoidOrders,
    ),
    RouteNames.restaurantReportsItemCancellation: _guard(
      const ItemCancellationReport(),
      'reports',
      EntKeys.reportsItemCancellation,
    ),
    RouteNames.restaurantShiftReport: _guard(
      const ShiftReportScreen(),
      'reports',
      EntKeys.reportsShift,
    ),
    RouteNames.restaurantStaffPerformance: _guard(
      const StaffPerformanceScreen(),
      'reports',
      EntKeys.reportsStaffPerformance,
    ),
    RouteNames.restaurantCashDrawer: _guard(
      const CashDrawerScreen(),
      'cashDrawer',
      EntKeys.cashDrawer,
    ),
    RouteNames.restaurantCashDrawerHistory: _guard(
      const CashDrawerHistoryScreen(),
      'reports',
      EntKeys.reportsCashDrawerHistory,
    ),

    // Restaurant - Settings
    RouteNames.restaurantSettings: _guard(
      const Settingsscreen(),
      'settings',
      EntKeys.settings,
    ),
    RouteNames.restaurantUsageLimit: _guard(
      const UsageLimitScreen(),
      'settings',
    ),
    // Licensing is the RECOVERY path (renew / reactivate / view) — it must never
    // be entitlement-gated, or a plan without `settings` (e.g. trial) could not
    // reach it to fix its own license. Role check only.
    RouteNames.restaurantLicensing: _guard(const LicensingScreen(), 'settings'),
    // Same screen retail uses — both verticals print from StoreSettingsService.
    RouteNames.restaurantStoreInfo: _guard(
      const StoreInfoSettingsScreen(),
      'settings',
      EntKeys.settings,
    ),
    RouteNames.restaurantOrderSettings: _guard(
      Ordersettings(),
      'settings',
      EntKeys.settings,
    ),
    RouteNames.restaurantPaymentMethods: _guard(
      Paymentsmethods(),
      'settings',
      EntKeys.settings,
    ),
    RouteNames.restaurantChangePassword: _guard(
      Changepassword(),
      'settings',
      EntKeys.settings,
    ),

    // Restaurant - Tax — opens the tax management screen directly (the old
    // single-card "Tax Settings" menu screen was a redundant hop, now removed).
    RouteNames.restaurantTaxSettings: _guard(
      Addtax(),
      'taxSettings',
      EntKeys.settings,
    ),

    // Restaurant - Printer
    // Printer setup is required to actually operate (KOT/bill printing), so it
    // follows billing — a plan that can sell can configure its printer.
    RouteNames.restaurantPrinterSettings: _guard(
      const Printersetting(),
      'settings',
      EntKeys.billing,
    ),
    RouteNames.restaurantPrinterCustomization: _guard(
      const CustomizationPrinter(),
      'settings',
      EntKeys.billing,
    ),
    RouteNames.restaurantAddPrinter: _guard(
      const AddPrinter(),
      'settings',
      EntKeys.billing,
    ),

    // Restaurant - End Day
    // End Day is the CLOSE half of the day lifecycle. A day auto-starts on the
    // first order (billing), so its close path must ALWAYS be reachable — never
    // entitlement-gate it, or an open day (and the pending-EOD nag) can deadlock.
    RouteNames.restaurantEndDay: _guard(const EndDayDrawer(), 'endDay'),

    // Restaurant - Attendance
    RouteNames.restaurantAttendance: _guard(
      const StaffAttendanceScreen(),
      null,
      EntKeys.attendance,
    ),
    RouteNames.restaurantAttendanceReport: _guard(
      const AttendanceReportScreen(),
      'reports',
      EntKeys.reportsAttendance,
    ),

    // Restaurant - Other
    // Support/Help must stay reachable WITHOUT login — it's the escape hatch
    // from the license-lock screen, the upgrade blocker, and the setup wizard.
    // Guarding it bounced un-logged-in users to the PIN screen (a dead end).
    RouteNames.restaurantNeedHelp: (_) => const NeedhelpDrawer(),
    RouteNames.restaurantCustomizationDrawer: _guard(
      const CustomizationDrawer(),
      'settings',
    ),
    RouteNames.restaurantTestData: _guard(const TestDataScreen(), 'settings'),
    RouteNames.restaurantBulkImport: _guard(
      const RestaurantBulkImportScreen(),
      'settings',
    ),
    RouteNames.restaurantDataGenratorScreen: _guard(
      const DataGeneratorScreen(),
      'settings',
    ),
    RouteNames.restaurantSplashPreview: _guard(
      const AnimatedSplashScreen(),
      'settings',
    ),
  };
}
