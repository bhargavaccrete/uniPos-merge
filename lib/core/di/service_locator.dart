import 'package:get_it/get_it.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/data/repositories/business_type_repository.dart';
import 'package:unipos/data/repositories/business_details_repository.dart';
import 'package:unipos/data/repositories/tax_details_repository.dart';
import 'package:unipos/data/repositories/payment_method_repository.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import 'package:unipos/stores/payment_method_store.dart';

// ==================== RETAIL IMPORTS ====================
import 'package:unipos/data/repositories/retail/admin_repository.dart';
import 'package:unipos/data/repositories/retail/attribute_repository.dart';
import 'package:unipos/data/repositories/retail/category_model_repository.dart';
import 'package:unipos/data/repositories/retail/credit_payment_repository.dart';
import 'package:unipos/data/repositories/retail/hold_sale_repository.dart';
import 'package:unipos/data/repositories/retail/variant_repository.dart' as retail;
import 'package:unipos/data/repositories/retail/sale_item_repository.dart';
import 'package:unipos/domain/services/retail/auth_service.dart';
import 'package:unipos/domain/services/retail/backup_service.dart';
import 'package:unipos/domain/services/retail/gst_service.dart';
import 'package:unipos/domain/services/retail/print_service.dart';
import 'package:unipos/domain/services/retail/report_service.dart';
import 'package:unipos/domain/services/retail/stock_alert_service.dart';
import 'package:unipos/domain/services/retail/variant_generator_service.dart';
import 'package:unipos/domain/store/retail/attribute_store.dart';
import 'package:unipos/domain/store/retail/cart_store.dart' as retail;
import 'package:unipos/domain/store/retail/credit_store.dart';
import 'package:unipos/domain/store/retail/customer_store.dart';
import 'package:unipos/domain/store/retail/hold_sale_store.dart';
import 'package:unipos/domain/store/retail/product_store.dart';
import 'package:unipos/domain/store/retail/purchase_order_store.dart';
import 'package:unipos/domain/store/retail/purchase_store.dart';
import 'package:unipos/domain/store/retail/sale_store.dart';
import 'package:unipos/domain/store/retail/stock_alert_store.dart';
import 'package:unipos/domain/store/retail/supplier_store.dart';

// ==================== RESTAURANT IMPORTS ====================
import 'package:unipos/data/repositories/restaurant/category_repository.dart';
import 'package:unipos/data/repositories/restaurant/item_repository.dart';
import 'package:unipos/data/repositories/restaurant/variant_repository.dart' as restaurant;
import 'package:unipos/data/repositories/restaurant/choice_repository.dart';
import 'package:unipos/data/repositories/restaurant/extra_repository.dart';
import 'package:unipos/data/repositories/restaurant/order_repository.dart';
import 'package:unipos/data/repositories/restaurant/past_order_repository.dart';
import 'package:unipos/data/repositories/restaurant/cart_repository.dart';
import 'package:unipos/data/repositories/restaurant/table_repository.dart';
import 'package:unipos/data/repositories/restaurant/customer_repository.dart' as restaurant;
import 'package:unipos/data/repositories/restaurant/staff_repository.dart';
import 'package:unipos/data/repositories/restaurant/expense_repository.dart';
import 'package:unipos/data/repositories/restaurant/expense_category_repository.dart';
import 'package:unipos/data/repositories/restaurant/tax_repository.dart';
import 'package:unipos/data/repositories/restaurant/company_repository.dart';
import 'package:unipos/data/repositories/restaurant/eod_repository.dart';

import 'package:unipos/domain/store/restaurant/category_store.dart';
import 'package:unipos/domain/store/restaurant/item_store.dart';
import 'package:unipos/domain/store/restaurant/variant_store.dart';
import 'package:unipos/domain/store/restaurant/choice_store.dart';
import 'package:unipos/domain/store/restaurant/extra_store.dart';
import 'package:unipos/domain/store/restaurant/order_store.dart';
import 'package:unipos/domain/store/restaurant/past_order_store.dart';
import 'package:unipos/domain/store/restaurant/cart_store.dart' as restaurant;
import 'package:unipos/domain/store/restaurant/table_store.dart';
import 'package:unipos/domain/store/restaurant/customer_store.dart' as restaurant;
import 'package:unipos/domain/store/restaurant/staff_store.dart';
import 'package:unipos/domain/store/restaurant/expense_store.dart';
import 'package:unipos/domain/store/restaurant/expense_category_store.dart';
import 'package:unipos/domain/store/restaurant/tax_store.dart';
import 'package:unipos/domain/store/restaurant/company_store.dart';
import 'package:unipos/domain/store/restaurant/eod_store.dart';
import 'package:unipos/domain/store/restaurant/appStore.dart';

import '../../data/repositories/restaurant/customer_repository.dart';
import '../../data/repositories/restaurant/variant_repository.dart';
import '../../domain/store/restaurant/cart_store.dart';
import '../../domain/store/restaurant/customer_store.dart';

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
  print('💳 Initializing PaymentMethodStore...');
  final paymentStore = locator<PaymentMethodStore>();
  await paymentStore.init();
  print('💳 PaymentMethodStore initialized with ${paymentStore.paymentMethods.length} methods');

  // Register PrintService as a common dependency for both Retail and Restaurant
  locator.registerLazySingleton<PrintService>(() => PrintService());

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
  locator.registerLazySingleton<BackupService>(() => BackupService());
  locator.registerLazySingleton<ReportService>(() => ReportService());
  locator.registerLazySingleton<StockAlertService>(() => StockAlertService());
  locator.registerLazySingleton<GstService>(() => GstService());

  // Register Repositories
  locator.registerLazySingleton<CategoryModelRepository>(() => CategoryModelRepository());
  locator.registerLazySingleton<retail.VariantRepository>(() => retail.VariantRepository());
  locator.registerLazySingleton<AdminRepository>(() => AdminRepository());

  // Register AuthService (depends on AdminRepository)
  locator.registerLazySingleton<AuthService>(
        () => AuthService(locator<AdminRepository>()),
  );

  // Ensure default admin account exists
  await locator<AuthService>().ensureDefaultAdmin();
  print('✓ Default admin account initialized (username: admin, password: admin123)');

  // Register Stores (Singletons - lazy loaded)
  locator.registerLazySingleton<retail.CartStore>(() => retail.CartStore());
  locator.registerLazySingleton<ProductStore>(() => ProductStore());
  locator.registerLazySingleton<SaleStore>(() => SaleStore());
  locator.registerLazySingleton<CustomerStoreRetail>(() => CustomerStoreRetail());
  locator.registerLazySingleton<SupplierStore>(() => SupplierStore());
  locator.registerLazySingleton<PurchaseStore>(() => PurchaseStore());
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
}

/// Register restaurant-specific dependencies
/// Called when business mode is set to restaurant
Future<void> _registerRestaurantDependencies() async {
  // Skip if already registered
  if (locator.isRegistered<CategoryStore>()) return;

  print('🍽️ Registering restaurant dependencies...');

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
  locator.registerLazySingleton<CustomerRepositoryRes>(() => CustomerRepositoryRes());
  locator.registerLazySingleton<StaffRepository>(() => StaffRepository());
  locator.registerLazySingleton<ExpenseRepository>(() => ExpenseRepository());
  locator.registerLazySingleton<ExpenseCategoryRepository>(() => ExpenseCategoryRepository());
  locator.registerLazySingleton<TaxRepository>(() => TaxRepository());
  locator.registerLazySingleton<CompanyRepository>(() => CompanyRepository());
  locator.registerLazySingleton<EodRepository>(() => EodRepository());

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
  locator.registerLazySingleton<restaurant.CustomerStoreRes>(
    () => restaurant.CustomerStoreRes(locator<restaurant.CustomerRepositoryRes>()),
  );
  locator.registerLazySingleton<StaffStore>(
    () => StaffStore(locator<StaffRepository>()),
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
  locator.registerLazySingleton<CompanyStore>(
    () => CompanyStore(locator<CompanyRepository>()),
  );
  locator.registerLazySingleton<EodStore>(
    () => EodStore(locator<EodRepository>()),
  );
  locator.registerLazySingleton<AppStore>(() => AppStore());

  print('✅ Restaurant dependencies registered successfully');
}

/// Register business dependencies dynamically (called during setup wizard)
/// This is called when user selects a business type
Future<void> registerBusinessDependencies(BusinessMode mode) async {
  // ignore: avoid_print
  print('registerBusinessDependencies: mode=$mode');
  if (mode == BusinessMode.retail) {
    // ignore: avoid_print
    print('registerBusinessDependencies: calling _registerRetailDependencies');
    await _registerRetailDependencies();
    // ignore: avoid_print
    print('registerBusinessDependencies: _registerRetailDependencies completed');
  } else if (mode == BusinessMode.restaurant) {
    // ignore: avoid_print
    print('registerBusinessDependencies: calling _registerRestaurantDependencies');
    await _registerRestaurantDependencies();
    // ignore: avoid_print
    print('registerBusinessDependencies: _registerRestaurantDependencies completed');
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

// ==================== RETAIL CONVENIENCE GETTERS ====================

/// Retail Stores
retail.CartStore get cartStore => locator<retail.CartStore>();
ProductStore get productStore => locator<ProductStore>();
SaleStore get saleStore => locator<SaleStore>();
CustomerStoreRetail get customerStoreRestail => locator<CustomerStoreRetail>();
SupplierStore get supplierStore => locator<SupplierStore>();
PurchaseStore get purchaseStore => locator<PurchaseStore>();
PurchaseOrderStore get purchaseOrderStore => locator<PurchaseOrderStore>();
HoldSaleStore get holdSaleStore => locator<HoldSaleStore>();
StockAlertStore get stockAlertStore => locator<StockAlertStore>();
CreditStore get creditStore => locator<CreditStore>();
AttributeStore get attributeStore => locator<AttributeStore>();

/// Retail Services
BackupService get backupService => locator<BackupService>();
ReportService get reportService => locator<ReportService>();
PrintService get printService => locator<PrintService>();
StockAlertService get stockAlertService => locator<StockAlertService>();
GstService get gstService => locator<GstService>();
AuthService get authService => locator<AuthService>();
VariantGeneratorService get variantGeneratorService => locator<VariantGeneratorService>();

/// Retail Repositories
SaleItemRepository get saleItemRepository => locator<SaleItemRepository>();
HoldSaleRepository get holdSaleRepository => locator<HoldSaleRepository>();
CategoryModelRepository get categoryModelRepository => locator<CategoryModelRepository>();
retail.VariantRepository get variantRepository => locator<retail.VariantRepository>();
AdminRepository get adminRepository => locator<AdminRepository>();
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
CustomerStoreRes get restaurantCustomerStore => locator<CustomerStoreRes>();
StaffStore get staffStore => locator<StaffStore>();
ExpenseStore get expenseStore => locator<ExpenseStore>();
ExpenseCategoryStore get expenseCategoryStore => locator<ExpenseCategoryStore>();
TaxStore get taxStore => locator<TaxStore>();
CompanyStore get companyStore => locator<CompanyStore>();
EodStore get eodStore => locator<EodStore>();
AppStore get appStore => locator<AppStore>();

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
CustomerRepositoryRes get restaurantCustomerRepository => locator<CustomerRepositoryRes>();
StaffRepository get staffRepository => locator<StaffRepository>();
ExpenseRepository get expenseRepository => locator<ExpenseRepository>();
ExpenseCategoryRepository get expenseCategoryRepository => locator<ExpenseCategoryRepository>();
TaxRepository get taxRepository => locator<TaxRepository>();
CompanyRepository get companyRepository => locator<CompanyRepository>();
EodRepository get eodRepository => locator<EodRepository>();

// ==================== GLOBAL REFRESH FUNCTION ====================

/// Call this after modifying data directly in Hive (e.g., from test data generator)
/// to ensure all stores reload their cached data
Future<void> refreshAllRestaurantStores() async {
  print('🔄 Global refresh: reloading all restaurant stores');
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
  print('✅ Global refresh complete');
}