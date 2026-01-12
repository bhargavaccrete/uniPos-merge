import 'package:flutter/material.dart';
import 'package:unipos/core/routes/routes_name.dart';

// Retail Screens
import 'package:unipos/presentation/screens/retail/ex/posscreen.dart';
import 'package:unipos/presentation/screens/retail/home_screen.dart';
import 'package:unipos/presentation/screens/retail/inventory_screen.dart';
import 'package:unipos/presentation/screens/retail/add_product_screen.dart';
import 'package:unipos/presentation/screens/retail/category_management_screen.dart';
import 'package:unipos/presentation/screens/retail/stock_alerts_screen.dart';
import 'package:unipos/presentation/screens/retail/checkout_screen.dart';
import 'package:unipos/presentation/screens/retail/parked_sales_screen.dart';
import 'package:unipos/presentation/screens/retail/customer_list_screen.dart';
import 'package:unipos/presentation/screens/retail/credit_reports_screen.dart';
import 'package:unipos/presentation/screens/retail/supplier_list_screen.dart';
import 'package:unipos/presentation/screens/retail/purchase_history_screen.dart';
import 'package:unipos/presentation/screens/retail/purchase_order_list_screen.dart';
import 'package:unipos/presentation/screens/retail/add_purchase_screen.dart';
import 'package:unipos/presentation/screens/retail/reports_screen.dart';
import 'package:unipos/presentation/screens/retail/sales_history_screen.dart';
import 'package:unipos/presentation/screens/retail/eod_report_screen.dart';
import 'package:unipos/presentation/screens/retail/gst_report_screen.dart';
import 'package:unipos/presentation/screens/retail/settings_screen.dart';
import 'package:unipos/presentation/screens/retail/store_info_settings_screen.dart';
import 'package:unipos/presentation/screens/retail/gst_settings_screen.dart';
import 'package:unipos/presentation/screens/retail/payment_setup_screen.dart';
import 'package:unipos/presentation/screens/retail/staff_setup_screen.dart';
import 'package:unipos/presentation/screens/retail/backup_screen.dart';

class RetailRoutes {
  static Map<String, WidgetBuilder> get routes => {
    RouteNames.retailBilling: (_) => const RetailPosScreen(),
    RouteNames.retailMenu: (_) => const HomeScreen(),

    RouteNames.checkout: (_) => const CheckoutScreen(),
    RouteNames.parkedSales: (_) => const ParkedSalesScreen(),

    RouteNames.inventory: (_) => const InventoryScreen(),
    RouteNames.addProduct: (_) => const AddProductScreen(),
    RouteNames.categories: (_) => const CategoryManagementScreen(),
    RouteNames.stockAlerts: (_) => const StockAlertsScreen(),

    RouteNames.customers: (_) => const CustomerListScreen(),
    RouteNames.creditReports: (_) => const CreditReportsScreen(),

    RouteNames.suppliers: (_) => const SupplierListScreen(),
    RouteNames.purchaseOrders: (_) => const PurchaseOrderListScreen(),
    RouteNames.addPurchase: (_) => const AddPurchaseScreen(),
    RouteNames.purchaseHistory: (_) => const PurchaseHistoryScreen(),

    RouteNames.reports: (_) => const ReportsScreen(),
    RouteNames.salesHistory: (_) => const SalesHistoryScreen(),
    RouteNames.eodReport: (_) => const EODReportScreen(),
    RouteNames.gstReport: (_) => const GstReportScreen(),

    RouteNames.settings: (_) => const SettingsScreen(),
    RouteNames.storeInfo: (_) => const StoreInfoSettingsScreen(),
    RouteNames.gstSettings: (_) => const GstSettingsScreen(),
    RouteNames.paymentSetup: (_) => const PaymentSetupScreen(),
    RouteNames.staffSetup: (_) => const StaffSetupScreen(),
    RouteNames.backup: (_) => const BackupScreen(),
  };
}
