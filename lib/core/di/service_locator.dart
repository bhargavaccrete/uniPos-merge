import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/tax_details_repository.dart';
import 'package:billberrylite/data/repositories/payment_method_repository.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import 'package:billberrylite/stores/payment_method_store.dart';

// ==================== RETAIL IMPORTS ====================
import 'package:billberrylite/data/repositories/retail/attribute_repository.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/kit_assembly_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/hold_sale_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart' as retail;
import 'package:billberrylite/data/repositories/retail/variant_repository.dart' as retail;
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/sku_generator_service.dart';
import 'package:billberrylite/domain/services/retail/customer_id_generator_service.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/stock_take_store.dart';
import 'package:billberrylite/domain/services/retail/print_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';
import 'package:billberrylite/domain/services/retail/variant_generator_service.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/cart_store.dart' as retail;
import 'package:billberrylite/domain/store/retail/credit_store.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/retail/hold_sale_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/domain/store/retail/stock_alert_store.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';

// ==================== RESTAURANT IMPORTS ====================
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_production_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_return_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_claim_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_inventory_loss_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_stock_take_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_ledger_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/variant_repository.dart' as restaurant;
import 'package:billberrylite/data/repositories/restaurant/choice_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/extra_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cart_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/staff_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/shift_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_handover_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_category_repository.dart';
import 'package:billberrylite/data/repositories/common/tax_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/eod_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_cancellation_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/printer_repository.dart';

import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_purchase_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_damaged_goods_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_stock_take_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_supplier_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/domain/store/restaurant/choice_store.dart';
import 'package:billberrylite/domain/store/restaurant/extra_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/cart_store.dart' as restaurant;
import 'package:billberrylite/domain/store/restaurant/table_store.dart';
import 'package:billberrylite/domain/store/common/staff_store.dart';
import 'package:billberrylite/domain/store/restaurant/shift_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_handover_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_category_store.dart';
import 'package:billberrylite/domain/store/common/tax_store.dart';
import 'package:billberrylite/domain/store/restaurant/eod_store.dart';
import 'package:billberrylite/domain/store/restaurant/appStore.dart';
import 'package:billberrylite/domain/store/restaurant/printer_store.dart';
import 'package:billberrylite/domain/store/restaurant/attendance_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';

import 'package:billberrylite/data/repositories/restaurant/attendance_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import '../../domain/services/retail/barcode_generator_service.dart';

// Type aliases for convenience getters (to avoid prefixing with 'restaurant.')
typedef CartStoreRes = restaurant.CartStoreRes;
typedef VariantRepositoryRes = restaurant.VariantRepositoryRes;

final locator = GetIt.instance;

/// The business mode whose dependency graph is currently in the container,
/// or null when only the common registrations are present.
BusinessMode? _registeredBusinessMode;

/// Undo hooks for every registration made by [_registerRetailDependencies] /
/// [_registerRestaurantDependencies], in registration order.
final List<FutureOr<void> Function()> _businessUnregisterHooks = [];

/// Registers a business-mode-scoped lazy singleton and remembers how to remove
/// it again.
///
/// The two mode graphs overlap (CategoryStore, TaxStore, CustomerStore,
/// StaffStore, EodStore, ExpenseStore, CashMovementStore and their
/// repositories are shared), so registering one on top of the other throws
/// "already registered" partway through and leaves the rest of that mode —
/// ProductStore included — missing. Switching mode therefore tears the old
/// graph down first, which this bookkeeping makes possible.
void _regBusiness<T extends Object>(T Function() factory) {
  locator.registerLazySingleton<T>(factory);
  _businessUnregisterHooks.add(() => locator.unregister<T>());
}

/// Removes everything the current business mode registered, newest first.
Future<void> _unregisterBusinessDependencies() async {
  // Restaurant wires these to stores that are about to disappear.
  RestaurantSession.onShiftAutoClose = null;
  RestaurantSession.onAttendanceAutoClockOut = null;

  for (final undo in _businessUnregisterHooks.reversed) {
    await undo();
  }
  _businessUnregisterHooks.clear();
  _registeredBusinessMode = null;
}

/// Initialize all dependencies
/// Call this in main() AFTER Hive initialization
/// Hive adapters and boxes are registered in main.dart
Future<void> setupServiceLocator() async {
  // ==================== COMMON REPOSITORIES ====================

  // Singleton - one instance throughout app
  locator.registerLazySingleton<BusinessTypeRepository>(() => BusinessTypeRepository());
  locator.registerLazySingleton<BusinessDetailsRepository>(() => BusinessDetailsRepository());
  locator.registerLazySingleton<TaxDetailsRepository>(() => TaxDetailsRepository());
  locator.registerLazySingleton<PaymentMethodRepository>(() => PaymentMethodRepository());

  // ==================== COMMON STORES ====================
  // Factory - new instance each time (for screens that need fresh state)
  locator.registerFactory<SetupWizardStore>(
    () => SetupWizardStore(
      businessTypeRepo: locator<BusinessTypeRepository>(),
      businessDetailsRepo: locator<BusinessDetailsRepository>(),
      taxDetailsRepo: locator<TaxDetailsRepository>(),
    ),
  );

  // Singleton for PaymentMethodStore
  locator.registerLazySingleton<PaymentMethodStore>(
    () => PaymentMethodStore(locator<PaymentMethodRepository>()),
  );

  // Initialize PaymentMethodStore (load payment methods from Hive)
  final paymentStore = locator<PaymentMethodStore>();
  await paymentStore.init();

  // Register PrintService as a common dependency for both Retail and Restaurant
  locator.registerLazySingleton<PrintService>(() => PrintService());

  // Printer connection stack — common to both modes. None of these touch a
  // restaurant type; both verticals pair printers through the same shared UI
  // (`screens/common/printer/`) and both reach the transport via `printerStore`.
  // Registering them per-mode meant any retail read of `printerStore` threw
  // "not registered inside GetIt".
  locator.registerLazySingleton<PrinterRepository>(() => PrinterRepository());
  locator.registerLazySingleton<ThermalPrinterService>(() => ThermalPrinterService());
  locator.registerLazySingleton<PrinterStore>(
    () => PrinterStore(locator<PrinterRepository>(), locator<ThermalPrinterService>()),
  );

  // Notification feed — common to both modes for the same reason as the
  // printer stack above. Restaurant raises low-stock/EOD/backup/license
  // events, retail raises low-stock/expiry; both persist to the one shared
  // box (HiveBoxNames.appNotifications) and render through the one shared
  // screen. Registered here rather than per-mode so `notificationStore` is
  // never "not registered inside GetIt" in retail, and so it survives the
  // setup wizard's business-mode switch (the box is common, so nothing dangles).
  locator.registerLazySingleton<NotificationRepository>(() => NotificationRepository());
  locator.registerLazySingleton<NotificationStore>(
    () => NotificationStore(locator<NotificationRepository>()),
  );

  // LicenseStore is common — needed in setup wizard before business mode is selected
  locator.registerLazySingleton<LicenseApiService>(() => LicenseApiService());
  locator.registerLazySingleton<LicenseStore>(
    () => LicenseStore(locator<LicenseApiService>()),
  );

  // Load saved printers at startup so defaultKotPrinter / defaultReceiptPrinter
  // are available immediately when the first order is placed.
  // Without this, printKOT() would find null defaults and fall through to PDF.
  // Async side-effect, so it runs after every common registration above.
  await locator<PrinterStore>().loadSavedPrinters();

  // Register business-specific dependencies based on mode
  // If mode is not set yet (during setup), we'll register them later
  if (AppConfig.isBusinessModeSet) {
    // Through registerBusinessDependencies, not the private helpers directly,
    // so `_registeredBusinessMode` reflects what is actually in the container.
    await registerBusinessDependencies(AppConfig.businessMode);
  }
}

/// Register retail-specific dependencies
/// Called when business mode is set to retail
Future<void> _registerRetailDependencies() async {
  // Register Repositories (Singletons - lazy loaded)
  _regBusiness<SaleItemRepository>(() => SaleItemRepository());
  _regBusiness<HoldSaleRepository>(() => HoldSaleRepository());

  // Register Services (Singletons - lazy loaded)
  _regBusiness<ReportService>(() => ReportService());
  _regBusiness<StockAlertService>(() => StockAlertService());
  _regBusiness<GstService>(() => GstService());
  _regBusiness<SkuGeneratorService>(() => SkuGeneratorService());
  _regBusiness<BarcodeGeneratorService>(
      () => BarcodeGeneratorService());
  _regBusiness<CustomerIdGeneratorService>(
      () => CustomerIdGeneratorService());
  _regBusiness<DamagedGoodsStore>(() => DamagedGoodsStore());
  _regBusiness<StockTakeStore>(() => StockTakeStore());

  // Register Repositories
  _regBusiness<retail.VariantRepository>(() => retail.VariantRepository());

  // Bundle/kit products — see docs/retail_inventory_system_plan.md §3.2.
  _regBusiness<BundleRepository>(() => BundleRepository());
  _regBusiness<KitAssemblyRepository>(() => KitAssemblyRepository());

  // Category CRUD (add/edit/delete) — shared store+repository with restaurant.
  // Same `Category` model, retail's own box; plan-gating and item-cascade
  // logic inside are business-mode-aware (see CategoryRepository/CategoryStore).
  _regBusiness<CategoryRepository>(() => CategoryRepository());
  _regBusiness<CategoryStore>(
    () => CategoryStore(locator<CategoryRepository>()),
  );

  // Tax — shared with restaurant (same Tax entity/box, unified this branch).
  // Add Product's tax dropdown reads `taxStore.taxes`; without this
  // registration it throws as soon as the screen loads.
  _regBusiness<TaxRepository>(() => TaxRepository());
  _regBusiness<TaxStore>(
    () => TaxStore(locator<TaxRepository>()),
  );

  // Register AuthService — single admin password, SharedPreferences-backed
  // (same storage approach as restaurant's admin PIN), no Hive model.
  _regBusiness<AuthService>(() => AuthService());

  // Register Stores (Singletons - lazy loaded)
  // CartStore depends on CartRepository — the store never touches Hive itself.
  _regBusiness<retail.CartRepository>(
      () => retail.CartRepository());
  _regBusiness<retail.CartStore>(
      () => retail.CartStore(locator<retail.CartRepository>()));
  _regBusiness<ProductStore>(() => ProductStore());
  _regBusiness<SaleStore>(() => SaleStore());

  // Customer CRUD — shared store+repository with restaurant. Same `Customer`
  // model, retail's own box; plan-gating inside is a no-op for retail (see
  // PlanEnforce._bypassed).
  _regBusiness<CustomerRepository>(() => CustomerRepository());
  _regBusiness<CustomerStore>(
    () => CustomerStore(locator<CustomerRepository>()),
  );

  // Staff CRUD — shared store+repository with restaurant. Same `StaffModel`
  // (restaurant's shape only — retail's onboarding no longer collects the
  // extra permission/employment fields), retail's own box.
  _regBusiness<StaffRepository>(() => StaffRepository());
  _regBusiness<StaffStore>(
    () => StaffStore(locator<StaffRepository>()),
  );

  _regBusiness<SupplierStore>(() => SupplierStore());
  _regBusiness<PurchaseOrderStore>(() => PurchaseOrderStore());

  // HoldSaleStore depends on HoldSaleRepository
  _regBusiness<HoldSaleStore>(
        () => HoldSaleStore(locator<HoldSaleRepository>()),
  );

  // Initialize HoldSaleStore to open boxes
  locator<HoldSaleStore>().init();

  _regBusiness<StockAlertStore>(() => StockAlertStore());

  // Credit System
  _regBusiness<CreditPaymentRepository>(() => CreditPaymentRepository());
  _regBusiness<CreditStore>(() => CreditStore());

  // Attribute System (WooCommerce-style)
  _regBusiness<AttributeRepository>(() => AttributeRepository());
  _regBusiness<AttributeStore>(() => AttributeStore());
  _regBusiness<VariantGeneratorService>(() => VariantGeneratorService());

  // End-of-Day & Expenses (reused from restaurant side).
  // The repositories are already AppConfig.isRetail-aware (they bind to the
  // retail 'eodBox' / 'expenseBox', which hive_init opens for retail), so the
  // same restaurant stores work here unchanged. Without these, retail EOD
  // generation, EOD save, and the Start-Day "carry forward last closing
  // balance" all fail because eodStore/expenseStore aren't resolvable.
  _regBusiness<ExpenseRepository>(() => ExpenseRepository());
  _regBusiness<ExpenseStore>(
    () => ExpenseStore(locator<ExpenseRepository>()),
  );
  _regBusiness<EodRepository>(() => EodRepository());
  _regBusiness<EodStore>(
    () => EodStore(locator<EodRepository>()),
  );
  _regBusiness<ItemCancellationRepository>(
      () => ItemCancellationRepository());

  // Cash Drawer (Cash In / Cash Out) — reused from restaurant. The repository
  // binds to the shared cashMovementsBox (opened for retail in hive_init), and
  // feeds EOD cash reconciliation which already reads these movements.
  _regBusiness<CashMovementRepository>(() => CashMovementRepository());
  _regBusiness<CashMovementStore>(
    () => CashMovementStore(locator<CashMovementRepository>()),
  );

  // Async side-effects go LAST, after every registration. The registrations
  // above are synchronous and cannot fail, so the container is fully populated
  // before this point — an error here can no longer strand ProductStore and
  // everything after it as unregistered. (Restaurant does the same, see
  // `loadSavedPrinters` at the end of _registerRestaurantDependencies.)
  await locator<AuthService>().ensureDefaultAdmin();
}

/// Register restaurant-specific dependencies
/// Called when business mode is set to restaurant
Future<void> _registerRestaurantDependencies() async {

  // ==================== RESTAURANT REPOSITORIES ====================
  _regBusiness<CategoryRepository>(() => CategoryRepository());
  _regBusiness<ItemRepository>(() => ItemRepository());
  _regBusiness<RecipeRepository>(() => RecipeRepository());
  _regBusiness<RecipeProductionRepository>(
    () => RecipeProductionRepository(),
  );
  _regBusiness<RestaurantSupplierRepository>(() => RestaurantSupplierRepository());
  _regBusiness<RestaurantPurchaseOrderRepository>(() => RestaurantPurchaseOrderRepository());
  _regBusiness<RestaurantPurchaseOrderItemRepository>(() => RestaurantPurchaseOrderItemRepository());
  _regBusiness<RestaurantGRNRepository>(() => RestaurantGRNRepository());
  _regBusiness<RestaurantGRNItemRepository>(() => RestaurantGRNItemRepository());
  _regBusiness<RestaurantPurchaseReturnRepository>(() => RestaurantPurchaseReturnRepository());
  _regBusiness<RestaurantSupplierClaimRepository>(() => RestaurantSupplierClaimRepository());
  _regBusiness<RestaurantInventoryLossRepository>(() => RestaurantInventoryLossRepository());
  _regBusiness<RestaurantStockTakeRepository>(() => RestaurantStockTakeRepository());
  _regBusiness<RestaurantSupplierLedgerRepository>(() => RestaurantSupplierLedgerRepository());
  _regBusiness<VariantRepositoryRes>(() => restaurant.VariantRepositoryRes());
  _regBusiness<ChoiceRepository>(() => ChoiceRepository());
  _regBusiness<ExtraRepository>(() => ExtraRepository());
  _regBusiness<OrderRepository>(() => OrderRepository());
  _regBusiness<PastOrderRepository>(() => PastOrderRepository());
  _regBusiness<CartRepository>(() => CartRepository());
  _regBusiness<TableRepository>(() => TableRepository());
  _regBusiness<CustomerRepository>(() => CustomerRepository());
  _regBusiness<StaffRepository>(() => StaffRepository());
  _regBusiness<ShiftRepository>(() => ShiftRepository());
  _regBusiness<CashMovementRepository>(() => CashMovementRepository());
  _regBusiness<CashHandoverRepository>(() => CashHandoverRepository());
  _regBusiness<ExpenseRepository>(() => ExpenseRepository());
  _regBusiness<ExpenseCategoryRepository>(() => ExpenseCategoryRepository());
  _regBusiness<TaxRepository>(() => TaxRepository());
  _regBusiness<EodRepository>(() => EodRepository());
  _regBusiness<ItemCancellationRepository>(
      () => ItemCancellationRepository());
  _regBusiness<AttendanceRepository>(() => AttendanceRepository());
  // PrinterRepository / ThermalPrinterService / PrinterStore and the
  // Notification stack are COMMON — registered in setupServiceLocator(),
  // see the printer block there.

  // ==================== RESTAURANT STORES ====================
  _regBusiness<CategoryStore>(
    () => CategoryStore(locator<CategoryRepository>()),
  );
  _regBusiness<ItemStore>(
    () => ItemStore(locator<ItemRepository>()),
  );
  _regBusiness<RestaurantPurchaseOrderStore>(
    () => RestaurantPurchaseOrderStore(),
  );
  _regBusiness<RestaurantDamagedGoodsStore>(
    () => RestaurantDamagedGoodsStore(),
  );
  _regBusiness<RestaurantSupplierStore>(
    () => RestaurantSupplierStore(),
  );
  _regBusiness<RestaurantStockTakeStore>(
    () => RestaurantStockTakeStore(),
  );
  _regBusiness<VariantStore>(
    () => VariantStore(locator<restaurant.VariantRepositoryRes>()),
  );
  _regBusiness<ChoiceStore>(
    () => ChoiceStore(locator<ChoiceRepository>()),
  );
  _regBusiness<ExtraStore>(
    () => ExtraStore(locator<ExtraRepository>()),
  );
  _regBusiness<OrderStore>(
    () => OrderStore(locator<OrderRepository>()),
  );
  _regBusiness<PastOrderStore>(
    () => PastOrderStore(locator<PastOrderRepository>()),
  );
  _regBusiness<restaurant.CartStoreRes>(
    () => restaurant.CartStoreRes(locator<CartRepository>()),
  );
  _regBusiness<TableStore>(
    () => TableStore(locator<TableRepository>()),
  );
  _regBusiness<CustomerStore>(
    () => CustomerStore(locator<CustomerRepository>()),
  );
  _regBusiness<StaffStore>(
    () => StaffStore(locator<StaffRepository>()),
  );
  _regBusiness<ShiftStore>(
    () => ShiftStore(locator<ShiftRepository>()),
  );
  // Auto-close the open shift when any logout path calls RestaurantSession.clearSession()
  RestaurantSession.onShiftAutoClose = (id) => shiftStore.closeShift(id);
  // Auto clock-out attendance on logout
  RestaurantSession.onAttendanceAutoClockOut = (name) => attendanceStore.autoClockOutIfOpen(name);

  // Cash Management stores
  _regBusiness<CashMovementStore>(
    () => CashMovementStore(locator<CashMovementRepository>()),
  );
  _regBusiness<CashHandoverStore>(
    () => CashHandoverStore(locator<CashHandoverRepository>()),
  );
  _regBusiness<ExpenseStore>(
    () => ExpenseStore(locator<ExpenseRepository>()),
  );
  _regBusiness<ExpenseCategoryStore>(
    () => ExpenseCategoryStore(locator<ExpenseCategoryRepository>()),
  );
  _regBusiness<TaxStore>(
    () => TaxStore(locator<TaxRepository>()),
  );
  _regBusiness<EodStore>(
    () => EodStore(locator<EodRepository>()),
  );
  _regBusiness<AppStore>(() => AppStore());
  _regBusiness<AttendanceStore>(() => AttendanceStore(locator<AttendanceRepository>()));
}

/// Register business dependencies dynamically (called during setup wizard)
/// This is called when user selects a business type
/// Safe to call repeatedly, and safe to call with a DIFFERENT mode than last
/// time — the setup wizard's Business Type step lets the user change their mind
/// until setup is completed, and the previous mode's graph is torn down before
/// the new one goes in.
Future<void> registerBusinessDependencies(BusinessMode mode) async {
  if (mode == BusinessMode.none) return;
  if (_registeredBusinessMode == mode) return;

  if (_registeredBusinessMode != null) {
    await _unregisterBusinessDependencies();
  }

  if (mode == BusinessMode.retail) {
    await _registerRetailDependencies();
  } else if (mode == BusinessMode.restaurant) {
    await _registerRestaurantDependencies();
  }
  _registeredBusinessMode = mode;
}

/// Reset all dependencies (useful for testing or logout)
Future<void> resetServiceLocator() async {
  await locator.reset();
  _businessUnregisterHooks.clear();
  _registeredBusinessMode = null;
}



/// Reset all dependencies (useful for testing or logout)
Future<void> resetLocator() async {
  await locator.reset();
  _businessUnregisterHooks.clear();
  _registeredBusinessMode = null;
  await setupServiceLocator();
}

/// Business details (store name, owner, GST, logo, etc.) — shared between
/// Restaurant and Retail, populated by the setup wizard's Store Details step.
BusinessDetailsRepository get businessDetailsRepository =>
    locator<BusinessDetailsRepository>();

// ==================== MODE-AWARE CONVENIENCE GETTERS ====================

/// Persisted notification feed — shared by both modes (see the common
/// registration in setupServiceLocator).
NotificationStore get notificationStore => locator<NotificationStore>();

/// Mode-aware cart store getter - works for both retail and restaurant
dynamic get cartStore {
  if (AppConfig.isRetail) {
    return locator<retail.CartStore>();
  } else if (AppConfig.isRestaurant) {
    return locator<restaurant.CartStoreRes>();
  }
  throw Exception('Business mode not set - cannot access cart store');
}

// ==================== RETAIL CONVENIENCE GETTERS ====================

/// Retail Stores
retail.CartStore get retailCartStore => locator<retail.CartStore>();
ProductStore get productStore => locator<ProductStore>();
BundleRepository get bundleRepository => locator<BundleRepository>();
KitAssemblyRepository get kitAssemblyRepository => locator<KitAssemblyRepository>();
SaleStore get saleStore => locator<SaleStore>();
SupplierStore get supplierStore => locator<SupplierStore>();
DamagedGoodsStore get damagedGoodsStore => locator<DamagedGoodsStore>();
StockTakeStore get stockTakeStore => locator<StockTakeStore>();
PurchaseOrderStore get purchaseOrderStore => locator<PurchaseOrderStore>();
HoldSaleStore get holdSaleStore => locator<HoldSaleStore>();
StockAlertStore get stockAlertStore => locator<StockAlertStore>();
CreditStore get creditStore => locator<CreditStore>();
AttributeStore get attributeStore => locator<AttributeStore>();

/// Retail Services
ReportService get reportService => locator<ReportService>();
PrintService get printService => locator<PrintService>();
StockAlertService get stockAlertService => locator<StockAlertService>();
GstService get gstService => locator<GstService>();
SkuGeneratorService get skuGeneratorService => locator<SkuGeneratorService>();
BarcodeGeneratorService get barcodeGeneratorService =>
    locator<BarcodeGeneratorService>();
CustomerIdGeneratorService get customerIdGeneratorService =>
    locator<CustomerIdGeneratorService>();
AuthService get authService => locator<AuthService>();
VariantGeneratorService get variantGeneratorService => locator<VariantGeneratorService>();

/// Retail Repositories
SaleItemRepository get saleItemRepository => locator<SaleItemRepository>();
HoldSaleRepository get holdSaleRepository => locator<HoldSaleRepository>();
retail.VariantRepository get variantRepository => locator<retail.VariantRepository>();
CreditPaymentRepository get creditPaymentRepository => locator<CreditPaymentRepository>();
AttributeRepository get attributeRepository => locator<AttributeRepository>();


// ==================== RESTAURANT CONVENIENCE GETTERS ====================

/// Restaurant Stores
CategoryStore get categoryStore => locator<CategoryStore>();
ItemStore get itemStore => locator<ItemStore>();
RestaurantPurchaseOrderStore get restaurantPurchaseOrderStore =>
    locator<RestaurantPurchaseOrderStore>();
RestaurantDamagedGoodsStore get restaurantDamagedGoodsStore =>
    locator<RestaurantDamagedGoodsStore>();
RestaurantStockTakeStore get restaurantStockTakeStore =>
    locator<RestaurantStockTakeStore>();

RestaurantSupplierStore get restaurantSupplierStore =>
    locator<RestaurantSupplierStore>();
VariantStore get variantStore => locator<VariantStore>();
ChoiceStore get choiceStore => locator<ChoiceStore>();
ExtraStore get extraStore => locator<ExtraStore>();
OrderStore get orderStore => locator<OrderStore>();
PastOrderStore get pastOrderStore => locator<PastOrderStore>();
CartStoreRes get restaurantCartStore => locator<CartStoreRes>();
TableStore get tableStore => locator<TableStore>();
CustomerStore get customerStore => locator<CustomerStore>();
StaffStore get staffStore => locator<StaffStore>();
ShiftStore get shiftStore => locator<ShiftStore>();
CashMovementStore get cashMovementStore => locator<CashMovementStore>();
CashHandoverStore  get cashHandoverStore  => locator<CashHandoverStore>();
ExpenseStore get expenseStore => locator<ExpenseStore>();
ExpenseCategoryStore get expenseCategoryStore => locator<ExpenseCategoryStore>();
TaxStore get taxStore => locator<TaxStore>();
EodStore get eodStore => locator<EodStore>();
AppStore get appStore => locator<AppStore>();
PrinterStore get printerStore => locator<PrinterStore>();
AttendanceStore get attendanceStore => locator<AttendanceStore>();
LicenseStore get licenseStore => locator<LicenseStore>();

/// Restaurant Repositories
CategoryRepository get categoryRepository => locator<CategoryRepository>();
ItemRepository get itemRepository => locator<ItemRepository>();
RecipeRepository get recipeRepository => locator<RecipeRepository>();
RecipeProductionRepository get recipeProductionRepository =>
    locator<RecipeProductionRepository>();
RestaurantSupplierRepository get restaurantSupplierRepository => locator<RestaurantSupplierRepository>();
RestaurantPurchaseOrderRepository get restaurantPurchaseOrderRepository => locator<RestaurantPurchaseOrderRepository>();
RestaurantPurchaseOrderItemRepository get restaurantPurchaseOrderItemRepository => locator<RestaurantPurchaseOrderItemRepository>();
RestaurantGRNRepository get restaurantGrnRepository => locator<RestaurantGRNRepository>();
RestaurantGRNItemRepository get restaurantGrnItemRepository => locator<RestaurantGRNItemRepository>();
RestaurantPurchaseReturnRepository get restaurantPurchaseReturnRepository => locator<RestaurantPurchaseReturnRepository>();
RestaurantSupplierClaimRepository get restaurantSupplierClaimRepository => locator<RestaurantSupplierClaimRepository>();
RestaurantInventoryLossRepository get restaurantInventoryLossRepository => locator<RestaurantInventoryLossRepository>();
RestaurantStockTakeRepository get restaurantStockTakeRepository => locator<RestaurantStockTakeRepository>();
RestaurantSupplierLedgerRepository get restaurantSupplierLedgerRepository => locator<RestaurantSupplierLedgerRepository>();
restaurant.VariantRepositoryRes get restaurantVariantRepository => locator<restaurant.VariantRepositoryRes>();
ChoiceRepository get choiceRepository => locator<ChoiceRepository>();
ExtraRepository get extraRepository => locator<ExtraRepository>();
OrderRepository get orderRepository => locator<OrderRepository>();
PastOrderRepository get pastOrderRepository => locator<PastOrderRepository>();
CartRepository get cartRepository => locator<CartRepository>();
TableRepository get tableRepository => locator<TableRepository>();
CustomerRepository get customerRepository => locator<CustomerRepository>();
StaffRepository get staffRepository => locator<StaffRepository>();
ExpenseRepository get expenseRepository => locator<ExpenseRepository>();
ExpenseCategoryRepository get expenseCategoryRepository => locator<ExpenseCategoryRepository>();
TaxRepository get taxRepository => locator<TaxRepository>();
EodRepository get eodRepository => locator<EodRepository>();

// ==================== GLOBAL REFRESH FUNCTION ====================

/// Call this after modifying data directly in Hive (e.g., from test data generator)
/// to ensure all stores reload their cached data
Future<void> refreshAllRestaurantStores() async {
  await Future.wait([
    categoryStore.loadCategories(),
    itemStore.loadItems(),
    variantStore.loadVariants(),
    extraStore.loadExtras(),
    choiceStore.loadChoices(),
    tableStore.loadTables(),
    orderStore.loadOrders(),
    restaurantCartStore.loadCartItems(),
  ]);
}