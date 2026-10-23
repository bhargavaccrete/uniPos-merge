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
import 'package:billberrylite/presentation/screens/retail/expiry_alerts_screen.dart';
import 'package:billberrylite/presentation/screens/common/notifications/notifications_screen.dart';
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
import 'package:billberrylite/presentation/screens/common/staff/manage_staff_screen.dart';
import 'package:billberrylite/presentation/screens/common/attendance/staff_attendance_screen.dart';
import 'package:billberrylite/presentation/screens/common/attendance/attendance_report_screen.dart';
import 'package:billberrylite/presentation/screens/common/shift/shift_report_screen.dart';
import 'package:billberrylite/presentation/screens/common/shift/staff_performance_screen.dart';
import 'package:billberrylite/presentation/screens/retail/backup_screen.dart';
import 'package:billberrylite/presentation/screens/retail/auth/retail_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

class RetailRoutes {
  /// Wraps a screen with [RetailGuard] to enforce ROLE then plan entitlement.
  ///
  /// [permission] is a `RestaurantSession.canAccess` feature key, or null for a
  /// route open to every role. [entitlement] is a `RetailEntKeys.*` string, or
  /// null for an always-open route (home / in-progress checkout / recovery);
  /// entitlements are a no-op until the backend sends a retail manifest — see
  /// `PlanEnforce._bypassed`. Argument order matches `RestaurantRoutes._guard`.
  static WidgetBuilder _guard(
    Widget child, [
    String? permission,
    String? entitlement,
  ]) =>
      (_) => RetailGuard(
        permissionKey: permission,
        entitlementKey: entitlement,
        child: child,
      );

  static Map<String, WidgetBuilder> get routes => {
    RouteNames.retailBilling: _guard(
      const RetailPosScreen(),
      'billing',
      RetailEntKeys.billing,
    ),
    RouteNames.retailMenu: _guard(const HomeScreen()), // home — always open
    // Shared notifications feed. Always open: a notification must stay
    // reachable even when the plan doesn't include the module it came from —
    // the screen checks the entitlement before navigating onward.
    RouteNames.notifications: _guard(const NotificationsScreen()),

    // Mid-sale flows stay open; the billing entrance above is the gate.
    RouteNames.checkout: _guard(const CheckoutScreen()),
    RouteNames.parkedSales: _guard(const ParkedSalesScreen()),

    RouteNames.productManagement: _guard(
      const ProductManagementScreen(),
      'catalog',
      RetailEntKeys.catalog,
    ),
    RouteNames.inventory: _guard(
      const InventoryScreen(),
      'inventory',
      RetailEntKeys.inventory,
    ),
    RouteNames.addProduct: _guard(
      const AddProductScreen(),
      'catalogEdit',
      RetailEntKeys.catalogProducts,
    ),
    RouteNames.categories: _guard(
      const CategoryManagementScreen(),
      'catalogEdit',
      RetailEntKeys.catalogCategories,
    ),
    RouteNames.stockAlerts: _guard(
      const StockAlertsScreen(),
      'inventory',
      RetailEntKeys.inventory,
    ),
    RouteNames.expiryAlerts: _guard(
      const ExpiryAlertsScreen(),
      'inventory',
      RetailEntKeys.inventory,
    ),

    RouteNames.customers: _guard(
      const CustomerListScreen(),
      'customers',
      RetailEntKeys.customers,
    ),
    RouteNames.creditReports: _guard(
      const CreditReportsScreen(),
      'reports',
      RetailEntKeys.billingCredit,
    ),

    RouteNames.suppliers: _guard(
      const SupplierListScreen(),
      'suppliers',
      RetailEntKeys.suppliers,
    ),
    RouteNames.purchaseOrders: _guard(
      const PurchaseOrderListScreen(),
      'purchase',
      RetailEntKeys.purchase,
    ),
    RouteNames.damagedGoods: _guard(
      const DamagedGoodsHubScreen(),
      'purchase',
      RetailEntKeys.purchaseDamaged,
    ),
    RouteNames.purchaseReturns: _guard(
      const PurchaseReturnListScreen(),
      'purchase',
      RetailEntKeys.purchaseReturns,
    ),
    RouteNames.supplierClaims: _guard(
      const SupplierClaimListScreen(),
      'suppliers',
      RetailEntKeys.suppliers,
    ),
    RouteNames.inventoryLosses: _guard(
      const InventoryLossListScreen(),
      'purchase',
      RetailEntKeys.purchaseDamaged,
    ),

    RouteNames.reports: _guard(
      const ReportsScreen(),
      'reports',
      RetailEntKeys.reports,
    ),
    RouteNames.salesHistory: _guard(
      const SalesHistoryScreen(),
      'billing',
      RetailEntKeys.reports,
    ),
    RouteNames.gstReport: _guard(
      const GstReportScreen(),
      'reports',
      RetailEntKeys.reports,
    ),

    // Settings HUB is open to every role: Start Day, End of Day and Logout
    // live inside it, so locking the door would trap a cashier. The
    // sensitive tiles inside carry the 'settings' gate instead.
    RouteNames.settings: _guard(
      const SettingsScreen(),
      null,
      RetailEntKeys.settings,
    ),
    RouteNames.storeInfo: _guard(
      const StoreInfoSettingsScreen(),
      'settings',
      RetailEntKeys.settings,
    ),
    RouteNames.gstSettings: _guard(
      const TaxSettingsScreen(),
      'taxSettings',
      RetailEntKeys.settings,
    ),
    RouteNames.paymentSetup: _guard(
      const PaymentSetupScreen(),
      'settings',
      RetailEntKeys.settings,
    ),
    RouteNames.staffSetup: _guard(
      const ManageStaffScreen(),
      'manageStaff',
      RetailEntKeys.users,
    ),
    RouteNames.backup: _guard(
      const BackupScreen(),
      'dataBackup',
      RetailEntKeys.dataBackup,
    ),

    // Staff attendance + shift reporting — the same shared screens the
    // restaurant uses, gated on retail's own keys.
    RouteNames.retailAttendance: _guard(
      const StaffAttendanceScreen(),
      null,
      RetailEntKeys.attendance,
    ),
    RouteNames.retailAttendanceReport: _guard(
      const AttendanceReportScreen(),
      'reports',
      RetailEntKeys.reportsAttendance,
    ),
    RouteNames.retailShiftReport: _guard(
      const ShiftReportScreen(),
      'reports',
      RetailEntKeys.reportsShift,
    ),
    RouteNames.retailStaffPerformance: _guard(
      const StaffPerformanceScreen(),
      'reports',
      RetailEntKeys.reportsStaffPerformance,
    ),
  };
}
