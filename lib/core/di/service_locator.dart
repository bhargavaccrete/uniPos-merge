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
import 'package:billberrylite/domain/store/restaurant/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';

import 'package:billberrylite/data/repositories/restaurant/attendance_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/notification_repository.dart';

// Type aliases for convenience getters (to avoid prefixing with 'restaurant.')
typedef CartStoreRes = restaurant.CartStoreRes;
typedef VariantRepositoryRes = restaurant.VariantRepositoryRes;

final locator = GetIt.instance;

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

  // LicenseStore is common — needed in setup wizard before business mode is selected
  locator.registerLazySingleton<LicenseApiService>(() => LicenseApiService());
  locator.registerLazySingleton<LicenseStore>(
    () => LicenseStore(locator<LicenseApiService>()),
  );

  // Register business-specific dependencies based on mode
  // If mode is not set yet (during setup), we'll register them later
  if (AppConfig.isBusinessModeSet) {
    if (AppConfig.isRetail) {
      await _registerRetailDependencies();
    } else if (AppConfig.isRestaurant) {
      await _registerRestaurantDependencies();
    }
  }
}

/// Register retail-specific dependencies
/// Called when business mode is set to retail
Future<void> _registerRetailDependencies() async {
  // Skip if already registered
  if (locator.isRegistered<ProductStore>()) return;

  // Register Repositories (Singletons - lazy loaded)
  locator.registerLazySingleton<SaleItemRepository>(() => SaleItemRepository());
  locator.registerLazySingleton<HoldSaleRepository>(() => HoldSaleRepository());

  // Register Services (Singletons - lazy loaded)
  locator.registerLazySingleton<ReportService>(() => ReportService());
  locator.registerLazySingleton<StockAlertService>(() => StockAlertService());
  locator.registerLazySingleton<GstService>(() => GstService());
  locator.registerLazySingleton<SkuGeneratorService>(() => SkuGeneratorService());
  locator.registerLazySingleton<CustomerIdGeneratorService>(
      () => CustomerIdGeneratorService());
  locator.registerLazySingleton<DamagedGoodsStore>(() => DamagedGoodsStore());

  // Register Repositories
  locator.registerLazySingleton<retail.VariantRepository>(() => retail.VariantRepository());

  // Category CRUD (add/edit/delete) — shared store+repository with restaurant.
  // Same `Category` model, retail's own box; plan-gating and item-cascade
  // logic inside are business-mode-aware (see CategoryRepository/CategoryStore).
  locator.registerLazySingleton<CategoryRepository>(() => CategoryRepository());
  locator.registerLazySingleton<CategoryStore>(
    () => CategoryStore(locator<CategoryRepository>()),
  );

  // Tax — shared with restaurant (same Tax entity/box, unified this branch).
  // Add Product's tax dropdown reads `taxStore.taxes`; without this
  // registration it throws as soon as the screen loads.
  locator.registerLazySingleton<TaxRepository>(() => TaxRepository());
  locator.registerLazySingleton<TaxStore>(
    () => TaxStore(locator<TaxRepository>()),
  );

  // Register AuthService — single admin password, SharedPreferences-backed
  // (same storage approach as restaurant's admin PIN), no Hive model.
  locator.registerLazySingleton<AuthService>(() => AuthService());

  // Register Stores (Singletons - lazy loaded)
  // CartStore depends on CartRepository — the store never touches Hive itself.
  locator.registerLazySingleton<retail.CartRepository>(
      () => retail.CartRepository());
  locator.registerLazySingleton<retail.CartStore>(
      () => retail.CartStore(locator<retail.CartRepository>()));
  locator.registerLazySingleton<ProductStore>(() => ProductStore());
  locator.registerLazySingleton<SaleStore>(() => SaleStore());

  // Customer CRUD — shared store+repository with restaurant. Same `Customer`
  // model, retail's own box; plan-gating inside is a no-op for retail (see
  // PlanEnforce._bypassed).
  locator.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
  locator.registerLazySingleton<CustomerStore>(
    () => CustomerStore(locator<CustomerRepository>()),
  );

  // Staff CRUD — shared store+repository with restaurant. Same `StaffModel`
  // (restaurant's shape only — retail's onboarding no longer collects the
  // extra permission/employment fields), retail's own box.
  locator.registerLazySingleton<StaffRepository>(() => StaffRepository());
  locator.registerLazySingleton<StaffStore>(
    () => StaffStore(locator<StaffRepository>()),
  );

  locator.registerLazySingleton<SupplierStore>(() => SupplierStore());
  locator.registerLazySingleton<PurchaseOrderStore>(() => PurchaseOrderStore());

  // HoldSaleStore depends on HoldSaleRepository
  locator.registerLazySingleton<HoldSaleStore>(
        () => HoldSaleStore(locator<HoldSaleRepository>()),
  );

  // Initialize HoldSaleStore to open boxes
  locator<HoldSaleStore>().init();

  locator.registerLazySingleton<StockAlertStore>(() => StockAlertStore());

  // Credit System
  locator.registerLazySingleton<CreditPaymentRepository>(() => CreditPaymentRepository());
  locator.registerLazySingleton<CreditStore>(() => CreditStore());

  // Attribute System (WooCommerce-style)
  locator.registerLazySingleton<AttributeRepository>(() => AttributeRepository());
  locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
  locator.registerLazySingleton<VariantGeneratorService>(() => VariantGeneratorService());

  // End-of-Day & Expenses (reused from restaurant side).
  // The repositories are already AppConfig.isRetail-aware (they bind to the
  // retail 'eodBox' / 'expenseBox', which hive_init opens for retail), so the
  // same restaurant stores work here unchanged. Without these, retail EOD
  // generation, EOD save, and the Start-Day "carry forward last closing
  // balance" all fail because eodStore/expenseStore aren't resolvable.
  locator.registerLazySingleton<ExpenseRepository>(() => ExpenseRepository());
  locator.registerLazySingleton<ExpenseStore>(
    () => ExpenseStore(locator<ExpenseRepository>()),
  );
  locator.registerLazySingleton<EodRepository>(() => EodRepository());
  locator.registerLazySingleton<EodStore>(
    () => EodStore(locator<EodRepository>()),
  );
  locator.registerLazySingleton<ItemCancellationRepository>(
      () => ItemCancellationRepository());

  // Cash Drawer (Cash In / Cash Out) — reused from restaurant. The repository
  // binds to the shared cashMovementsBox (opened for retail in hive_init), and
  // feeds EOD cash reconciliation which already reads these movements.
  locator.registerLazySingleton<CashMovementRepository>(() => CashMovementRepository());
  locator.registerLazySingleton<CashMovementStore>(
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
  // Skip if already registered
  if (locator.isRegistered<CategoryStore>()) return;


  // ==================== RESTAURANT REPOSITORIES ====================
  locator.registerLazySingleton<CategoryRepository>(() => CategoryRepository());
  locator.registerLazySingleton<ItemRepository>(() => ItemRepository());
  locator.registerLazySingleton<VariantRepositoryRes>(() => restaurant.VariantRepositoryRes());
  locator.registerLazySingleton<ChoiceRepository>(() => ChoiceRepository());
  locator.registerLazySingleton<ExtraRepository>(() => ExtraRepository());
  locator.registerLazySingleton<OrderRepository>(() => OrderRepository());
  locator.registerLazySingleton<PastOrderRepository>(() => PastOrderRepository());
  locator.registerLazySingleton<CartRepository>(() => CartRepository());
  locator.registerLazySingleton<TableRepository>(() => TableRepository());
  locator.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
  locator.registerLazySingleton<StaffRepository>(() => StaffRepository());
  locator.registerLazySingleton<ShiftRepository>(() => ShiftRepository());
  locator.registerLazySingleton<CashMovementRepository>(() => CashMovementRepository());
  locator.registerLazySingleton<CashHandoverRepository>(() => CashHandoverRepository());
  locator.registerLazySingleton<ExpenseRepository>(() => ExpenseRepository());
  locator.registerLazySingleton<ExpenseCategoryRepository>(() => ExpenseCategoryRepository());
  locator.registerLazySingleton<TaxRepository>(() => TaxRepository());
  locator.registerLazySingleton<EodRepository>(() => EodRepository());
  locator.registerLazySingleton<ItemCancellationRepository>(
      () => ItemCancellationRepository());
  locator.registerLazySingleton<PrinterRepository>(() => PrinterRepository());
  locator.registerLazySingleton<AttendanceRepository>(() => AttendanceRepository());
  locator.registerLazySingleton<NotificationRepository>(() => NotificationRepository());
  locator.registerLazySingleton<ThermalPrinterService>(() => ThermalPrinterService());

  // ==================== RESTAURANT STORES ====================
  locator.registerLazySingleton<CategoryStore>(
    () => CategoryStore(locator<CategoryRepository>()),
  );
  locator.registerLazySingleton<ItemStore>(
    () => ItemStore(locator<ItemRepository>()),
  );
  locator.registerLazySingleton<VariantStore>(
    () => VariantStore(locator<restaurant.VariantRepositoryRes>()),
  );
  locator.registerLazySingleton<ChoiceStore>(
    () => ChoiceStore(locator<ChoiceRepository>()),
  );
  locator.registerLazySingleton<ExtraStore>(
    () => ExtraStore(locator<ExtraRepository>()),
  );
  locator.registerLazySingleton<OrderStore>(
    () => OrderStore(locator<OrderRepository>()),
  );
  locator.registerLazySingleton<PastOrderStore>(
    () => PastOrderStore(locator<PastOrderRepository>()),
  );
  locator.registerLazySingleton<restaurant.CartStoreRes>(
    () => restaurant.CartStoreRes(locator<CartRepository>()),
  );
  locator.registerLazySingleton<TableStore>(
    () => TableStore(locator<TableRepository>()),
  );
  locator.registerLazySingleton<CustomerStore>(
    () => CustomerStore(locator<CustomerRepository>()),
  );
  locator.registerLazySingleton<StaffStore>(
    () => StaffStore(locator<StaffRepository>()),
  );
  locator.registerLazySingleton<ShiftStore>(
    () => ShiftStore(locator<ShiftRepository>()),
  );
  // Auto-close the open shift when any logout path calls RestaurantSession.clearSession()
  RestaurantSession.onShiftAutoClose = (id) => shiftStore.closeShift(id);
  // Auto clock-out attendance on logout
  RestaurantSession.onAttendanceAutoClockOut = (name) => attendanceStore.autoClockOutIfOpen(name);

  // Cash Management stores
  locator.registerLazySingleton<CashMovementStore>(
    () => CashMovementStore(locator<CashMovementRepository>()),
  );
  locator.registerLazySingleton<CashHandoverStore>(
    () => CashHandoverStore(locator<CashHandoverRepository>()),
  );
  locator.registerLazySingleton<ExpenseStore>(
    () => ExpenseStore(locator<ExpenseRepository>()),
  );
  locator.registerLazySingleton<ExpenseCategoryStore>(
    () => ExpenseCategoryStore(locator<ExpenseCategoryRepository>()),
  );
  locator.registerLazySingleton<TaxStore>(
    () => TaxStore(locator<TaxRepository>()),
  );
  locator.registerLazySingleton<EodStore>(
    () => EodStore(locator<EodRepository>()),
  );
  locator.registerLazySingleton<AppStore>(() => AppStore());
  locator.registerLazySingleton<PrinterStore>(
    () => PrinterStore(locator<PrinterRepository>(), locator<ThermalPrinterService>()),
  );
  locator.registerLazySingleton<AttendanceStore>(() => AttendanceStore(locator<AttendanceRepository>()));
  locator.registerLazySingleton<NotificationStore>(() => NotificationStore(locator<NotificationRepository>()));

  // Load saved printers at startup so defaultKotPrinter / defaultReceiptPrinter
  // are available immediately when the first order is placed.
  // Without this, printKOT() would find null defaults and fall through to PDF.
  await locator<PrinterStore>().loadSavedPrinters();

}

/// Register business dependencies dynamically (called during setup wizard)
/// This is called when user selects a business type
Future<void> registerBusinessDependencies(BusinessMode mode) async {
  // ignore: avoid_print
  if (mode == BusinessMode.retail) {
    // ignore: avoid_print
    await _registerRetailDependencies();
    // ignore: avoid_print
  } else if (mode == BusinessMode.restaurant) {
    // ignore: avoid_print
    await _registerRestaurantDependencies();
    // ignore: avoid_print
  }
}

/// Reset all dependencies (useful for testing or logout)
Future<void> resetServiceLocator() async {
  await locator.reset();
}



/// Reset all dependencies (useful for testing or logout)
Future<void> resetLocator() async {
  await locator.reset();
  await setupServiceLocator();
}

/// Business details (store name, owner, GST, logo, etc.) — shared between
/// Restaurant and Retail, populated by the setup wizard's Store Details step.
BusinessDetailsRepository get businessDetailsRepository =>
    locator<BusinessDetailsRepository>();

// ==================== MODE-AWARE CONVENIENCE GETTERS ====================

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
SaleStore get saleStore => locator<SaleStore>();
SupplierStore get supplierStore => locator<SupplierStore>();
DamagedGoodsStore get damagedGoodsStore => locator<DamagedGoodsStore>();
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
NotificationStore get notificationStore => locator<NotificationStore>();
LicenseStore get licenseStore => locator<LicenseStore>();

/// Restaurant Repositories
CategoryRepository get categoryRepository => locator<CategoryRepository>();
ItemRepository get itemRepository => locator<ItemRepository>();
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