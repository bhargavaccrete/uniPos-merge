import 'package:flutter/material.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/Discount%20Order%20Report/dicountOrderReport.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparison/comparisonbymonth.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparison/comparisonbyweek.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparison/comparisonbyyear.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparisonbyproduct/comparisonproduct.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/dailyClosingReports/dailyclosing.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/pos%20End%20Day%20Report/posenddayreport.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/refundDetails/refunddetails.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyCategory/salesbycategory.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyItem/salesbyitem.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/salesbytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/totalsales/totalsales.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/data_generator_screen.dart';
import 'package:unipos/presentation/screens/restaurant/import/bulk_import_test_screen_v3.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/order.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/import/test_data_screen.dart';

// Core Screens
import 'package:unipos/presentation/screens/onboarding/splashScreen.dart';
import 'package:unipos/presentation/screens/onboarding/walkthroughScreen.dart';
import 'package:unipos/presentation/screens/onboarding/userSelectionScreen.dart';
import 'package:unipos/presentation/screens/onboarding/existingUserRestoreScreen.dart';
import 'package:unipos/presentation/screens/onboarding/setupWizardScreen.dart';

// Restaurant - Auth
import 'package:unipos/presentation/screens/restaurant/auth/restaurant_login.dart';
import 'package:unipos/presentation/screens/restaurant/auth/admin_login.dart';
import 'package:unipos/presentation/screens/restaurant/auth/restaurant_guard.dart';

// Restaurant - Home & Dashboard
import 'package:unipos/presentation/screens/restaurant/welcome_Admin.dart';

// Restaurant - Orders
import 'package:unipos/presentation/screens/restaurant/start%20order/startorder.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/activeorder.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/pastorder.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/orderDetails.dart';

// Restaurant - Tables
import 'package:unipos/presentation/screens/restaurant/tabbar/table.dart';

// Restaurant - Menu
import 'package:unipos/presentation/screens/restaurant/tabbar/menu.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/manage_menu_screen.dart';
import 'package:unipos/presentation/screens/restaurant/auth/setup_add_item_screen.dart';
import 'package:unipos/presentation/screens/restaurant/auth/category_management_screen.dart';

// Restaurant - Customers
import 'package:unipos/presentation/screens/restaurant/customer/customer_list_screen.dart';
import 'package:unipos/presentation/screens/restaurant/customer/manage_customers_screen.dart';
import 'package:unipos/presentation/screens/restaurant/customer/add_edit_customer_screen.dart';
import 'package:unipos/presentation/screens/restaurant/customer/customer_detail_screen.dart';

// Restaurant - Online Orders
import 'package:unipos/presentation/screens/restaurant/online%20Order/online.dart';
import 'package:unipos/presentation/screens/restaurant/online%20Order/inProgress.dart';
import 'package:unipos/presentation/screens/restaurant/online%20Order/Completed.dart';
import 'package:unipos/presentation/screens/restaurant/online%20Order/missed.dart';

// Restaurant - Inventory
import 'package:unipos/presentation/screens/restaurant/inventory/manage_Inventory.dart';
import 'package:unipos/presentation/screens/restaurant/inventory/stock_history.dart';

// Restaurant - Staff
import 'package:unipos/presentation/screens/restaurant/ManageStaff/manageStaff.dart';

// Restaurant - Expenses
import 'package:unipos/presentation/screens/restaurant/Expense/Expense.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/viewexpense.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/managecategory.dart';

// Restaurant - Reports
import 'package:unipos/presentation/screens/restaurant/Reports/reports.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/filterOrders.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/performance_statistics_report.dart';

// Restaurant - Settings
import 'package:unipos/presentation/screens/restaurant/Settings/settingsScreen.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/orderSettings.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/paymentsMethods.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/orderNotificationSetting.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/changePassword.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/addressCustomizationScreen.dart';

// Restaurant - Tax
import 'package:unipos/presentation/screens/restaurant/TaxSetting/taxSettings.dart';
import 'package:unipos/presentation/screens/restaurant/TaxSetting/taxRagistration.dart';
import 'package:unipos/presentation/screens/restaurant/TaxSetting/apply_tax_screen.dart';
import 'package:unipos/presentation/screens/restaurant/TaxSetting/addMultipleTax.dart';

// Restaurant - Printer
import 'package:unipos/presentation/screens/restaurant/printerSetting/printersetting.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/customization.dart';

// Restaurant - End Day
import 'package:unipos/presentation/screens/restaurant/end%20day/endday.dart';

// Restaurant - Other
import 'package:unipos/presentation/screens/restaurant/language.dart';
import 'package:unipos/presentation/screens/restaurant/need%20help/needhelp.dart';
import 'package:unipos/presentation/screens/restaurant/customiztion/customization_drawer.dart';

import '../../presentation/screens/restaurant/Reports/comparison/comparison.dart';
import '../../presentation/screens/restaurant/Reports/customer list by revenue/customerlistbyrevenue.dart';
import '../../presentation/screens/restaurant/Reports/customerList/customerlist.dart';
import '../../presentation/screens/restaurant/Reports/expenseReport/expensereport.dart';
import '../../presentation/screens/restaurant/Reports/void Order Report/voidOrderReport.dart';
import '../../presentation/screens/restaurant/printerSetting/addprinter/addprinter.dart';
import '../../presentation/screens/restaurant/shift/shift_report_screen.dart';
import '../../presentation/screens/restaurant/shift/staff_performance_screen.dart';

class RestaurantRoutes {
  /// Wraps a widget builder with [RestaurantGuard] to enforce login + optional role check.
  /// [permission] maps to a key in [RestaurantSession.canAccess].
  static WidgetBuilder _guard(Widget child, [String? permission]) =>
      (_) => RestaurantGuard(child: child, permissionKey: permission);

  static Map<String, WidgetBuilder> get routes => {
    // Core (restaurant flow)
    RouteNames.splash: (_) => const SplashScreen(),
    RouteNames.walkthrough: (_) => const WalkthroughScreen(),
    RouteNames.userSelection: (_) => const UserSelectionScreen(),
    RouteNames.restore: (_) => const ExistingUserRestoreScreen(),
    RouteNames.setupWizard: (_) => const SetupWizardScreen(),

    // Restaurant - Auth
    RouteNames.restaurantLogin: (_) => const RestaurantLogin(),
    RouteNames.restaurantAdminLogin: (_) => const AdminLogin(),
/*    RouteNames.restaurantCashierWaiter: (_) => const CashierWaiter(),
    RouteNames.restaurantSignup: (_) => const SignUp(),
    RouteNames.restaurantAuthSelection: (_) => const AuthSelectionScreen(),
    RouteNames.restaurantSupport: (_) => const Support(),*/

    // Restaurant - Home & Dashboard
    RouteNames.restaurantHome: _guard(const AdminWelcome()),

    // Restaurant - Orders
    RouteNames.restaurantStartOrder: _guard(const Startorder(), 'startOrder'),
    RouteNames.restaurantOrder: _guard(const Order(), 'startOrder'),
    RouteNames.restaurantActiveOrders: _guard(const Activeorder(), 'startOrder'),
    RouteNames.restaurantPastOrders: _guard(const Pastorder(), 'startOrder'),
    RouteNames.restaurantOrderDetails: _guard(const Orderdetails(), 'startOrder'),

    // Restaurant - Tables
    RouteNames.restaurantTables: _guard(const TableScreen(), 'startOrder'),

    // Restaurant - Menu
    RouteNames.restaurantAdminWelcome: _guard(const AdminWelcome()),
    RouteNames.restaurantManageMenu: _guard(const Managemenu(), 'manageMenu'),
    RouteNames.restaurantAddItem: _guard(const SetupAddItemScreen(), 'manageMenu'),
    RouteNames.restaurantCategoryManagement: _guard(const CategoryManagementScreen(), 'manageMenu'),

    // Restaurant - Customers
    RouteNames.restaurantCustomers: _guard(const CustomerListScreen(), 'customers'),
    RouteNames.restaurantManageCustomers: _guard(const ManageCustomersScreen(), 'customers'),
    RouteNames.restaurantAddEditCustomer: _guard(const AddEditCustomerScreen(), 'customers'),

/*
    // Restaurant - Online Orders
    RouteNames.restaurantOnlineOrders: (_) => const OnlineOrders(),
    RouteNames.restaurantOnlineInProgress: (_) => const InProgressOnline(),
    RouteNames.restaurantOnlineCompleted: (_) => const CompletedOnline(),
    RouteNames.restaurantOnlineMissed: (_) => const MissedOnline(),
*/

    // Restaurant - Inventory
    RouteNames.restaurantInventory: _guard(const ManageInventory(), 'inventory'),
    RouteNames.restaurantStockHistory: _guard(StockHistory(), 'inventory'),

    // Restaurant - Staff
    RouteNames.restaurantStaff: _guard(const manageStaff(), 'manageStaff'),

    // Restaurant - Expenses
    RouteNames.restaurantExpenses: _guard(const ExpenseScreen(), 'expenses'),
    RouteNames.restaurantAddExpense: _guard(const Addexpence(), 'expenses'),
    RouteNames.restaurantViewExpense: _guard(const ViewExpense(), 'expenses'),
    RouteNames.restaurantExpenseCategory: _guard(const ManageCategory(), 'expenses'),

    // Restaurant - Reports
    RouteNames.restaurantReports: _guard(const ReportsScreen(), 'reports'),
    RouteNames.restaurantPerformanceStats: _guard(const PerformanceStatisticsReport(), 'reports'),
    RouteNames.restaurantReportsTotalSales: _guard(const Totalsales(), 'reports'),
    RouteNames.restaurantReportsSalesBYItem: _guard(Salesbyitem(), 'reports'),
    RouteNames.restaurantReportsSalesByCategory: _guard(SalesByCategory(), 'reports'),
    RouteNames.restaurantReportsDailyClosingReport: _guard(DailyClosingReport(), 'reports'),
    RouteNames.restaurantReportsSalesByTop: _guard(SalesByTopSelling(), 'reports'),
    RouteNames.restaurantReportsCustomerList: _guard(CustomerListReport(), 'reports'),
    RouteNames.restaurantReportsComparisionByWeek: _guard(SalesComparison(), 'reports'),
    RouteNames.restaurantReportsComparisionByMonth: _guard(ComparisonByMonth(), 'reports'),
    RouteNames.restaurantReportsComparisionByYear: _guard(ComparisonByYear(), 'reports'),
    RouteNames.restaurantReportsComparisionByProduct: _guard(ComparisonByProduct(), 'reports'),
    RouteNames.restaurantReportsRefundDetails: _guard(RefundDetails(), 'reports'),
    RouteNames.restaurantReportsDiscountOrderReport: _guard(DiscountOrderReport(), 'reports'),
    RouteNames.restaurantReportsPosOrder: _guard(Posenddayreport(), 'reports'),
    RouteNames.restaurantReportsCustomerListByRevenue: _guard(CustomerListByRevenue(), 'reports'),
    RouteNames.restaurantReportsExpense: _guard(ExpenseReport(), 'reports'),
    RouteNames.restaurantReportsVoidOrderReport: _guard(VoidOrderReport(), 'reports'),
    RouteNames.restaurantShiftReport: _guard(const ShiftReportScreen(), 'reports'),
    RouteNames.restaurantStaffPerformance: _guard(const StaffPerformanceScreen(), 'reports'),

    // Restaurant - Settings
    RouteNames.restaurantSettings: _guard(const Settingsscreen(), 'settings'),
    RouteNames.restaurantOrderSettings: _guard(Ordersettings(), 'settings'),
    RouteNames.restaurantPaymentMethods: _guard(Paymentsmethods(), 'settings'),
    RouteNames.restaurantChangePassword: _guard(Changepassword(), 'settings'),
    RouteNames.restaurantAddressCustomization: _guard(AddressCustomizationScreen(), 'settings'),

    // Restaurant - Tax
    RouteNames.restaurantTaxSettings: _guard(taxSetting(), 'taxSettings'),
    RouteNames.restaurantTaxRegistration: _guard(Taxragistration(), 'taxSettings'),
    RouteNames.restaurantAddMultipleTax: _guard(Addtax(), 'taxSettings'),

    // Restaurant - Printer
    RouteNames.restaurantPrinterSettings: _guard(const Printersetting(), 'settings'),
    RouteNames.restaurantPrinterCustomization: _guard(const CustomizationPrinter(), 'settings'),
    RouteNames.restaurantAddPrinter: _guard(const AddPrinter(), 'settings'),

    // Restaurant - End Day
    RouteNames.restaurantEndDay: _guard(const EndDayDrawer(), 'endDay'),

    // Restaurant - Other
    RouteNames.restaurantNeedHelp: _guard(const NeedhelpDrawer()),
    RouteNames.restaurantCustomizationDrawer: _guard(const CustomizationDrawer(), 'settings'),
    RouteNames.restaurantTestData: _guard(const TestDataScreen(), 'settings'),
    RouteNames.restaurantBulkImportTestScreen: _guard(const BulkImportTestScreenV3(), 'settings'),
    RouteNames.restaurantDataGenratorScreen: _guard(const DataGeneratorScreen(), 'settings'),

  };
}
