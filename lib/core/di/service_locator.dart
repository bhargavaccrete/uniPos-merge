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
// All restaurant repositories and stores have been removed
// Restaurant functionality now uses direct Hive database access via:
// - HiveBoxes (for categories and items)
// - itemsBoxes (for items)
// - HiveChoice (for choices)
// - HiveExtra (for extras)
// - HiveVariante (for variants)
// - HiveCart (for cart operations)
// - HiveTable (for table management)
// - HiveOrder (for order management)
// - HivePastOrder (for past orders)
// - HiveStaff (for staff management)
// - HiveEOD (for end of day operations)
// - HiveExpenseCategory (for expense categories)
// - HiveTax (for tax management)
// - HiveTestBill (for test bills)

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
  locator.registerLazySingleton<PrintService>(() => PrintService());
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
  locator.registerLazySingleton<CustomerStore>(() => CustomerStore());
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
  // ignore: avoid_print
  print('_registerRestaurantDependencies: checking if already registered');
  // All restaurant repositories and stores have been removed
  // Restaurant functionality now uses direct Hive database access
  // No dependencies to register
  // ignore: avoid_print
  print('_registerRestaurantDependencies: using direct Hive access, no dependencies to register');
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
CustomerStore get customerStore => locator<CustomerStore>();
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

// All restaurant stores and repositories have been removed
// Restaurant functionality now uses direct Hive database access via:
// - HiveBoxes.getAllCategories(), HiveBoxes.addCategory(), etc.
// - itemsBoxes.getAllItems(), itemsBoxes.addItem(), itemsBoxes.updateItem(), etc.
// - HiveChoice.getAllChoice(), HiveChoice.addChoice(), etc.
// - HiveExtra.getAllExtra(), HiveExtra.addExtra(), etc.
// - HiveVariante.getAllVariante(), HiveVariante.addVariante(), etc.
// - HiveCart for cart operations
// - HiveTable for table management
// - HiveOrder for order management
// - HivePastOrder for past orders
// - HiveStaff for staff management
// - HiveEOD for end of day operations
// - HiveExpenseCategory for expense categories
// - HiveTax for tax management
// - HiveTestBill for test bills