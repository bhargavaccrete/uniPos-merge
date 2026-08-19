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
import 'package:billberrylite/presentation/screens/retail/auth/retail_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

class RetailRoutes {
  /// Wraps a screen with [RetailGuard] to enforce a plan entitlement.
  /// [entitlement] is a `RetailEntKeys.*` string, or null for an always-open
  /// route (home / in-progress checkout / recovery). No-op until the backend
  /// sends a retail manifest — see `PlanEnforce._bypassed`.
  static WidgetBuilder _guard(Widget child, [String? entitlement]) =>
      (_) => RetailGuard(entitlementKey: entitlement, child: child);

  static Map<String, WidgetBuilder> get routes => {
    RouteNames.retailBilling: _guard(const RetailPosScreen(), RetailEntKeys.billing),
    RouteNames.retailMenu: _guard(const HomeScreen()), // home — always open

    // Mid-sale flows stay open; the billing entrance above is the gate.
    RouteNames.checkout: _guard(const CheckoutScreen()),
    RouteNames.parkedSales: _guard(const ParkedSalesScreen()),

    RouteNames.productManagement: _guard(const ProductManagementScreen(), RetailEntKeys.catalog),
    RouteNames.inventory: _guard(const InventoryScreen(), RetailEntKeys.inventory),
    RouteNames.addProduct: _guard(const AddProductScreen(), RetailEntKeys.catalog),
    RouteNames.categories: _guard(const CategoryManagementScreen(), RetailEntKeys.catalogCategories),
    RouteNames.stockAlerts: _guard(const StockAlertsScreen(), RetailEntKeys.inventory),

    RouteNames.customers: _guard(const CustomerListScreen(), RetailEntKeys.customers),
    RouteNames.creditReports: _guard(const CreditReportsScreen(), RetailEntKeys.billingCredit),

    RouteNames.suppliers: _guard(const SupplierListScreen(), RetailEntKeys.suppliers),
    RouteNames.purchaseOrders: _guard(const PurchaseOrderListScreen(), RetailEntKeys.purchase),
    RouteNames.damagedGoods: _guard(const DamagedGoodsHubScreen(), RetailEntKeys.purchaseDamaged),
    RouteNames.purchaseReturns: _guard(const PurchaseReturnListScreen(), RetailEntKeys.purchaseReturns),
    RouteNames.supplierClaims: _guard(const SupplierClaimListScreen(), RetailEntKeys.suppliers),
    RouteNames.inventoryLosses: _guard(const InventoryLossListScreen(), RetailEntKeys.purchaseDamaged),

    RouteNames.reports: _guard(const ReportsScreen(), RetailEntKeys.reports),
    RouteNames.salesHistory: _guard(const SalesHistoryScreen(), RetailEntKeys.reports),
    RouteNames.gstReport: _guard(const GstReportScreen(), RetailEntKeys.reports),

    RouteNames.settings: _guard(const SettingsScreen(), RetailEntKeys.settings),
    RouteNames.storeInfo: _guard(const StoreInfoSettingsScreen(), RetailEntKeys.settings),
    RouteNames.gstSettings: _guard(const TaxSettingsScreen(), RetailEntKeys.settings),
    RouteNames.paymentSetup: _guard(const PaymentSetupScreen(), RetailEntKeys.settings),
    RouteNames.staffSetup: _guard(const StaffSetupScreen(), RetailEntKeys.users),
    RouteNames.backup: _guard(const BackupScreen(), RetailEntKeys.dataBackup),
  };
}
