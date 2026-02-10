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

class RestaurantRoutes {
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
    RouteNames.restaurantHome: (_) => const AdminWelcome(),
    // RouteNames.restaurantDashboard: (_) => const DashboardScreen(),

    // Restaurant - Orders
    RouteNames.restaurantStartOrder: (_) => const Startorder(),
    RouteNames.restaurantOrder: (_) => const Order(),

    RouteNames.restaurantActiveOrders: (_) => const Activeorder(),
    RouteNames.restaurantPastOrders: (_) => const Pastorder(),
    RouteNames.restaurantOrderDetails: (_) => const Orderdetails(),

    // Restaurant - Tables
    RouteNames.restaurantTables: (_) => const TableScreen(),

    // Restaurant - Menu
    RouteNames.restaurantAdminWelcome: (_) => const AdminWelcome(),
    RouteNames.restaurantManageMenu: (_) => const Managemenu(),
    RouteNames.restaurantAddItem: (_) => const SetupAddItemScreen(),
    RouteNames.restaurantCategoryManagement: (_) => const CategoryManagementScreen(),

    // Restaurant - Customers
    RouteNames.restaurantCustomers: (_) => const CustomerListScreen(),
    RouteNames.restaurantManageCustomers: (_) => const ManageCustomersScreen(),
    RouteNames.restaurantAddEditCustomer: (_) => const AddEditCustomerScreen(),
    // RouteNames.restaurantCustomerDetail: (_) => const CustomerDetailScreen(),

/*
    // Restaurant - Online Orders
    RouteNames.restaurantOnlineOrders: (_) => const OnlineOrders(),
    RouteNames.restaurantOnlineInProgress: (_) => const InProgressOnline(),
    RouteNames.restaurantOnlineCompleted: (_) => const CompletedOnline(),
    RouteNames.restaurantOnlineMissed: (_) => const MissedOnline(),
*/

    // Restaurant - Inventory
    RouteNames.restaurantInventory: (_) => const ManageInventory(),
    RouteNames.restaurantStockHistory: (_) =>  StockHistory(),

    // Restaurant - Staff
    RouteNames.restaurantStaff: (_) => const manageStaff(),

    // Restaurant - Expenses
    RouteNames.restaurantExpenses: (_) => const ExpenseScreen(),
    RouteNames.restaurantAddExpense: (_) => const Addexpence(),
    RouteNames.restaurantViewExpense: (_) => const ViewExpense(),
    RouteNames.restaurantExpenseCategory: (_) => const ManageCategory(),

    // Restaurant - Reports
    RouteNames.restaurantReports: (_) => const ReportsScreen(),
    // RouteNames.restaurantFilterOrders: (_) => const FilterOrders(),
    RouteNames.restaurantPerformanceStats: (_) => const PerformanceStatisticsReport(),
    RouteNames.restaurantReportsTotalSales: (_) => const Totalsales(),
    RouteNames.restaurantReportsSalesBYItem: (_) =>  Salesbyitem(),
    RouteNames.restaurantReportsSalesByCategory: (_) =>  SalesByCategory(),
    RouteNames.restaurantReportsDailyClosingReport: (_) =>  DailyClosingReport(),
    RouteNames.restaurantReportsSalesByTop: (_) =>  SalesByTopSelling(),
    RouteNames.restaurantReportsCustomerList: (_) =>  CustomerListReport(),
    RouteNames.restaurantReportsComparisionByWeek: (_) =>  SalesComparison(),
    RouteNames.restaurantReportsComparisionByMonth: (_) =>  ComparisonByMonth(),
    RouteNames.restaurantReportsComparisionByYear: (_) =>  ComparisonByYear(),
    RouteNames.restaurantReportsComparisionByProduct: (_) =>  ComparisonByProduct(),
    RouteNames.restaurantReportsRefundDetails: (_) =>  RefundDetails(),
    RouteNames.restaurantReportsDiscountOrderReport: (_) =>  DiscountOrderReport(),
    RouteNames.restaurantReportsPosOrder: (_) =>  Posenddayreport(),
    RouteNames.restaurantReportsCustomerListByRevenue: (_) =>  CustomerListByRevenue(),
    RouteNames.restaurantReportsExpense: (_) =>  ExpenseReport(),
    RouteNames.restaurantReportsVoidOrderReport: (_) =>  VoidOrderReport(),
    // RouteNames.restaurantReportsPerformanceStatistics: (_) =>  PerformanceStatisticsReport(),




    // Restaurant - Settings
    RouteNames.restaurantSettings: (_) => const  Settingsscreen(),
    RouteNames.restaurantOrderSettings: (_) =>  Ordersettings(),
    RouteNames.restaurantPaymentMethods: (_) =>  Paymentsmethods(),
    // RouteNames.restaurantOrderNotifications: (_) => const OrderNotificationSettings(),
    RouteNames.restaurantChangePassword: (_) =>  Changepassword(),
    RouteNames.restaurantAddressCustomization: (_) =>  AddressCustomizationScreen(),

    // Restaurant - Tax
    RouteNames.restaurantTaxSettings: (_) =>  taxSetting(),
    RouteNames.restaurantTaxRegistration: (_) =>  Taxragistration(),
    // RouteNames.restaurantApplyTax: (_) => const ApplyTaxScreen(),
    RouteNames.restaurantAddMultipleTax: (_) =>  Addtax(),

    // Restaurant - Printer
    RouteNames.restaurantPrinterSettings: (_) => const Printersetting(),
    RouteNames.restaurantPrinterCustomization: (_) => const CustomizationPrinter(),
    RouteNames.restaurantAddPrinter: (_) => const AddPrinter(),

    // Restaurant - End Day
    RouteNames.restaurantEndDay: (_) => const EndDayDrawer(),

    // Restaurant - Other
    // RouteNames.restaurantLanguage: (_) => const LanguageScreen(),
    RouteNames.restaurantNeedHelp: (_) => const NeedhelpDrawer(),
    RouteNames.restaurantCustomizationDrawer: (_) => const CustomizationDrawer(),
    RouteNames.restaurantTestData: (_) => const TestDataScreen(),
    RouteNames.restaurantBulkImportTestScreen: (_) => const BulkImportTestScreenV3(),
    RouteNames.restaurantDataGenratorScreen: (_) => const DataGeneratorScreen(),

  };
}
