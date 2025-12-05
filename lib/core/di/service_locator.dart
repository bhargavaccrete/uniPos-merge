import 'package:get_it/get_it.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/data/repositories/business_type_repository.dart';
import 'package:unipos/data/repositories/business_details_repository.dart';
import 'package:unipos/data/repositories/tax_details_repository.dart';
import 'package:unipos/stores/setup_wizard_store.dart';

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
import '../../data/repositories/restaurant/cart_repository.dart';
import '../../data/repositories/restaurant/category_repository.dart' as restaurant;
import '../../data/repositories/restaurant/choice_repository.dart';
import '../../data/repositories/restaurant/eod_repository.dart';
import '../../data/repositories/restaurant/expense_repository.dart';
import '../../data/repositories/restaurant/extra_repository.dart';
import '../../data/repositories/restaurant/item_repository.dart';
import '../../data/repositories/restaurant/order_repository.dart';
import '../../data/repositories/restaurant/past_order_repository.dart';
import '../../data/repositories/restaurant/staff_repository.dart';
import '../../data/repositories/restaurant/table_repository.dart';
import '../../data/repositories/restaurant/tax_repository.dart';
import '../../data/repositories/restaurant/variant_repository.dart' as restaurant;
import '../../domain/store/restaurant/cart_store.dart' as restaurant;
import '../../domain/store/restaurant/category_store.dart' as restaurant;
import '../../domain/store/restaurant/choice_store.dart';
import '../../domain/store/restaurant/eod_store.dart';
import '../../domain/store/restaurant/expense_store.dart';
import '../../domain/store/restaurant/extra_store.dart';
import '../../domain/store/restaurant/item_store.dart';
import '../../domain/store/restaurant/order_store.dart';
import '../../domain/store/restaurant/past_order_store.dart';
import '../../domain/store/restaurant/staff_store.dart';
import '../../domain/store/restaurant/table_store.dart';
import '../../domain/store/restaurant/tax_store.dart';
import '../../domain/store/restaurant/variant_store.dart';

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

  // ==================== COMMON STORES ====================
  // Factory - new instance each time (for screens that need fresh state)
  locator.registerFactory<SetupWizardStore>(
    () => SetupWizardStore(
      businessTypeRepo: locator<BusinessTypeRepository>(),
      businessDetailsRepo: locator<BusinessDetailsRepository>(),
      taxDetailsRepo: locator<TaxDetailsRepository>(),
    ),
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
  // Skip if already registered
  if (locator.isRegistered<ItemStore>()) {
    // ignore: avoid_print
    print('_registerRestaurantDependencies: already registered, skipping');
    return;
  }
  // ignore: avoid_print
  print('_registerRestaurantDependencies: registering dependencies');

  // ==================== REPOSITORIES ====================
  locator.registerLazySingleton<ItemRepository>(() => ItemRepository());
  locator.registerLazySingleton<restaurant.CategoryRepository>(() => restaurant.CategoryRepository());
  locator.registerLazySingleton<CartRepository>(() => CartRepository());
  locator.registerLazySingleton<OrderRepository>(() => OrderRepository());
  locator.registerLazySingleton<TableRepository>(() => TableRepository());
  locator.registerLazySingleton<StaffRepository>(() => StaffRepository());
  locator.registerLazySingleton<TaxRepository>(() => TaxRepository());
  locator.registerLazySingleton<ExpenseRepository>(() => ExpenseRepository());
  locator.registerLazySingleton<PastOrderRepository>(() => PastOrderRepository());
  locator.registerLazySingleton<EodRepository>(() => EodRepository());
  locator.registerLazySingleton<restaurant.VariantRepository>(() => restaurant.VariantRepository());
  locator.registerLazySingleton<ChoiceRepository>(() => ChoiceRepository());
  locator.registerLazySingleton<ExtraRepository>(() => ExtraRepository());

  // ==================== STORES ====================
  locator.registerLazySingleton<ItemStore>(() => ItemStore());
  locator.registerLazySingleton<restaurant.CategoryStore>(() => restaurant.CategoryStore());
  locator.registerLazySingleton<restaurant.CartStorer>(() => restaurant.CartStorer());
  locator.registerLazySingleton<OrderStore>(() => OrderStore());
  locator.registerLazySingleton<TableStore>(() => TableStore());
  locator.registerLazySingleton<StaffStore>(() => StaffStore());
  locator.registerLazySingleton<TaxStore>(() => TaxStore());
  locator.registerLazySingleton<ExpenseStore>(() => ExpenseStore());
  locator.registerLazySingleton<PastOrderStore>(() => PastOrderStore());
  locator.registerLazySingleton<EodStore>(() => EodStore());
  locator.registerLazySingleton<VariantStore>(() => VariantStore());
  locator.registerLazySingleton<ChoiceStore>(() => ChoiceStore());
  locator.registerLazySingleton<ExtraStore>(() => ExtraStore());
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

/// Restaurant Stores
ItemStore get itemStore => locator<ItemStore>();
restaurant.CategoryStore get categoryStore => locator<restaurant.CategoryStore>();
restaurant.CartStorer get restaurantCartStore => locator<restaurant.CartStorer>();
restaurant.CartStorer get cartStorer => locator<restaurant.CartStorer>();  // Alias for backward compatibility
OrderStore get orderStore => locator<OrderStore>();
TableStore get tableStore => locator<TableStore>();
StaffStore get staffStore => locator<StaffStore>();
TaxStore get taxStore => locator<TaxStore>();
ExpenseStore get expenseStore => locator<ExpenseStore>();
PastOrderStore get pastOrderStore => locator<PastOrderStore>();
EodStore get eodStore => locator<EodStore>();
VariantStore get variantStore => locator<VariantStore>();
ChoiceStore get choiceStore => locator<ChoiceStore>();
ExtraStore get extraStore => locator<ExtraStore>();

/// Restaurant Repositories
ItemRepository get itemRepository => locator<ItemRepository>();
restaurant.CategoryRepository get restaurantCategoryRepository => locator<restaurant.CategoryRepository>();
CartRepository get cartRepository => locator<CartRepository>();
OrderRepository get orderRepository => locator<OrderRepository>();
TableRepository get tableRepository => locator<TableRepository>();
StaffRepository get staffRepository => locator<StaffRepository>();
TaxRepository get taxRepository => locator<TaxRepository>();
ExpenseRepository get expenseRepository => locator<ExpenseRepository>();
PastOrderRepository get pastOrderRepository => locator<PastOrderRepository>();
EodRepository get eodRepository => locator<EodRepository>();
restaurant.VariantRepository get restaurantVariantRepository => locator<restaurant.VariantRepository>();
ChoiceRepository get choiceRepository => locator<ChoiceRepository>();
ExtraRepository get extraRepository => locator<ExtraRepository>();