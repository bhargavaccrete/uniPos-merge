import 'package:flutter/material.dart';
import 'package:billberrylite/core/routes/routes_name.dart';

// Retail Screens
import 'package:billberrylite/presentation/screens/retail/ex/posscreen.dart';
import 'package:billberrylite/presentation/screens/retail/home_screen.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_screen.dart';
import 'package:billberrylite/presentation/screens/retail/product_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/screens/retail/category_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/stock_alerts_screen.dart';
import 'package:billberrylite/presentation/screens/retail/checkout_screen.dart';
import 'package:billberrylite/presentation/screens/retail/parked_sales_screen.dart';
import 'package:billberrylite/presentation/screens/retail/customer_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/credit_reports_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_order_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/damaged_goods_hub_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_loss_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports_screen.dart';
import 'package:billberrylite/presentation/screens/retail/sales_history_screen.dart';
import 'package:billberrylite/presentation/screens/retail/gst_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/store_info_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/tax_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/payment_setup_screen.dart';
import 'package:billberrylite/presentation/screens/retail/staff_setup_screen.dart';
import 'package:billberrylite/presentation/screens/retail/backup_screen.dart';

class RetailRoutes {
  static Map<String, WidgetBuilder> get routes => {
    RouteNames.retailBilling: (_) => const RetailPosScreen(),
    RouteNames.retailMenu: (_) => const HomeScreen(),

    RouteNames.checkout: (_) => const CheckoutScreen(),
    RouteNames.parkedSales: (_) => const ParkedSalesScreen(),

    RouteNames.productManagement: (_) => const ProductManagementScreen(),
    RouteNames.inventory: (_) => const InventoryScreen(),
    RouteNames.addProduct: (_) => const AddProductScreen(),
    RouteNames.categories: (_) => const CategoryManagementScreen(),
    RouteNames.stockAlerts: (_) => const StockAlertsScreen(),

    RouteNames.customers: (_) => const CustomerListScreen(),
    RouteNames.creditReports: (_) => const CreditReportsScreen(),

    RouteNames.suppliers: (_) => const SupplierListScreen(),
    RouteNames.purchaseOrders: (_) => const PurchaseOrderListScreen(),
    RouteNames.damagedGoods: (_) => const DamagedGoodsHubScreen(),
    RouteNames.purchaseReturns: (_) => const PurchaseReturnListScreen(),
    RouteNames.supplierClaims: (_) => const SupplierClaimListScreen(),
    RouteNames.inventoryLosses: (_) => const InventoryLossListScreen(),

    RouteNames.reports: (_) => const ReportsScreen(),
    RouteNames.salesHistory: (_) => const SalesHistoryScreen(),
    RouteNames.gstReport: (_) => const GstReportScreen(),

    RouteNames.settings: (_) => const SettingsScreen(),
    RouteNames.storeInfo: (_) => const StoreInfoSettingsScreen(),
    RouteNames.gstSettings: (_) => const TaxSettingsScreen(),
    RouteNames.paymentSetup: (_) => const PaymentSetupScreen(),
    RouteNames.staffSetup: (_) => const StaffSetupScreen(),
    RouteNames.backup: (_) => const BackupScreen(),
  };
}
