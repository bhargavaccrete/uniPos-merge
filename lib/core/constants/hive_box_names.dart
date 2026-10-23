/// Centralized Hive Box Names
///
/// All Hive box names used throughout the application are defined here.
/// This prevents typos, makes refactoring easier, and provides a single source of truth.
///
/// Usage:
/// ```dart
/// import 'package:billberrylite/core/constants/hive_box_names.dart';
///
/// // Instead of: Hive.box('products')
/// // Use: Hive.box(HiveBoxNames.products)
/// ```

class HiveBoxNames {
  // Private constructor to prevent instantiation
  HiveBoxNames._();

  // ==================== COMMON BOXES ====================

  /// Persisted app notifications (low stock, expiry, EOD, backup, license).
  /// SHARED by restaurant and retail — one physical box, and only one business
  /// mode is ever active. The string value is historical: renaming it would
  /// orphan every existing restaurant install's notification history.
  static const String appNotifications = 'restaurantNotificationsBox';

  /// Application configuration box
  static const String appConfig = 'appConfigBox';

  /// Application state box (general settings)
  static const String appState = 'app_state';

  /// Store box (legacy - general store settings)
  static const String storeBox = 'storebox';

  /// Tax details box
  static const String taxBox = 'taxBox';

  /// Business type box
  static const String businessTypeBox = 'businessTypeBox';

  /// Business details box
  static const String businessDetailsBox = 'businessDetailsBox';

  /// Payment methods box (shared between retail and restaurant)
  static const String paymentMethods = 'paymentMethodsBox';

  /// Day management box (shared between retail and restaurant)
  static const String dayManagementBox = 'dayManagementBox';

  // ==================== RETAIL BOXES ====================

  /// Product catalog box
  static const String products = 'products';

  /// Product variants box
  static const String variants = 'variants';

  /// Cart items box
  static const String cartItems = 'cartItems';

  /// Sales transactions box
  static const String sales = 'sales';

  /// Sale line items box
  static const String saleItems = 'saleItems';

  /// Customer records box — shared between Restaurant and Retail (a device
  /// only ever runs one mode, so one physical box is enough; see
  /// CustomerRepository).
  static const String customer = 'customers';

  /// Supplier records box
  static const String suppliers = 'suppliers';

  /// Journal of every supplier balance movement. Written only by
  /// SupplierStore.recordBalanceMovement.
  static const String supplierLedger = 'supplierLedger';

  // RETIRED: 'purchases' and 'purchaseItems' belonged to the standalone
  // Purchase feature, removed in favour of Purchase Orders + GRN. Don't reuse
  // these names — an old install may still have those box files on disk.

  /// Purchase order model box
  static const String purchaseOrders = 'purchaseOrders';

  /// Damaged-goods workflow raised from a GRN
  static const String purchaseReturns = 'purchaseReturns';
  static const String purchaseReturnItems = 'purchaseReturnItems';
  static const String supplierClaims = 'supplierClaims';
  static const String supplierClaimItems = 'supplierClaimItems';
  static const String inventoryLosses = 'inventoryLosses';

  /// Physical stock count paperwork — header and counted lines.
  static const String stockTakes = 'stockTakes';
  static const String stockTakeItems = 'stockTakeItems';

  /// Bundle/kit product definitions — see docs/retail_inventory_system_plan.md §3.2.
  static const String bundles = 'bundles';

  /// Append-only "assembled a batch" log for repack/kit variants.
  static const String kitAssemblies = 'kitAssemblies';

  /// Purchase order items box
  static const String purchaseOrderItems = 'purchaseOrderItems';

  /// GRN (Goods Receipt Note) box
  static const String grns = 'grns';

  /// GRN items box
  static const String grnItems = 'grnItems';

  /// Hold sales box (for temporarily saved sales)
  static const String holdSales = 'holdSales';

  /// Hold sale items box
  static const String holdSaleItems = 'holdSaleItems';

  /// Retail categories box (string list)
  static const String retailCategories = 'retail_categories';

  /// Category box — shared between Restaurant and Retail (a device only ever
  /// runs one mode, so one physical box is enough; see CategoryRepository).
  static const String category = 'categories';

  /// Payment entries box
  static const String paymentEntries = 'paymentEntries';

  // 'admin_box' retired — admin credential is now a SharedPreferences value
  // (see domain/services/retail/auth_service.dart), not a Hive box.

  /// Credit payments box
  static const String creditPayments = 'credit_payments';

  /// Attributes box
  static const String attributes = 'attributes';

  /// Attribute values box
  static const String attributeValues = 'attribute_values';

  /// Product attributes box
  static const String productAttributes = 'product_attributes';

  /// Staff box — shared between Restaurant and Retail (a device only ever
  /// runs one mode, so one physical box is enough; see StaffRepository).
  static const String staff = 'staffBox';

  /// Tax rates box — shared between Restaurant and Retail (a device only
  /// ever runs one mode, so one physical box is enough; see TaxRepository).
  static const String tax = 'taxes';

  /// Billing tabs box
  static const String billingTabs = 'billingTabs';

  /// Retail end-of-day reports box
  static const String retailEOD = 'eodBox';

  /// Retail expense categories box
  static const String retailExpenseCategory = 'expenseCategory';

  /// Retail expenses box
  static const String retailExpense = 'expenseBox';

  // ==================== RESTAURANT BOXES ====================

  /// Restaurant menu items box
  static const String restaurantItems = 'itemBoxs';

  /// Restaurant item variants box
  static const String restaurantVariants = 'variante';

  /// Restaurant choices box
  static const String restaurantChoices = 'choice';

  /// Restaurant extras/add-ons box
  static const String restaurantExtras = 'extra';

  /// Restaurant cart box
  static const String restaurantCart = 'cart_box';


  /// Restaurant tables box
  static const String restaurantTables = 'tablesBox';

  /// Restaurant current orders box
  static const String restaurantOrders = 'orderBox';

  /// Restaurant past/completed orders box
  static const String restaurantPastOrders = 'pastorderBox';

  /// Restaurant end-of-day reports box
  static const String restaurantEOD = 'restaurant_eodBox';

  /// Restaurant expense categories box
  static const String restaurantExpenseCategory = 'restaurant_expenseCategory';

  /// Restaurant expenses box
  static const String restaurantExpense = 'restaurant_expenseBox';

  /// Generic named-sequence counters box, shared by both business modes
  /// (restaurant order/bill/KOT numbering, retail SKU sequence, etc.)
  static const String appCounters = 'appCounters';

  /// Restaurant test bill box
  static const String testBillBox = 'testBillBox';

  /// Shift management box — shared between Restaurant and Retail (a device
  /// only ever runs one mode, so one physical box is enough; see
  /// ShiftRepository). String kept as 'shiftBox' — renaming the Dart
  /// identifier does not touch stored data.
  static const String shift = 'shiftBox';

  /// Cash movement events (Cash In / Cash Out during the day)
  static const String restaurantCashMovements = 'cashMovementsBox';

  /// Stock movement log (manual stock add/remove with reason + history)
  static const String restaurantStockMovements = 'stockMovementsBox';

  /// Pending Settle stock work (StockJournal). Untyped — plain maps, no
  /// adapter. Device-local: never exported, cleared on restore.
  static const String restaurantStockJournal = 'restaurantStockJournal';

  /// Cash handover records (2-step shift handover between staff)
  static const String restaurantCashHandovers = 'cashHandoversBox';

  /// Saved thermal printers (Bluetooth/WiFi configuration)
  static const String restaurantPrinters = 'restaurantPrintersBox';

  /// Restaurant POS Sessions
  static const String restaurantSessions = 'restaurantSessionsBox';

  /// Staff attendance clock-in/out records — shared between Restaurant and
  /// Retail. String kept as 'restaurantAttendanceBox' so existing installs
  /// and backups keep reading the same box.
  static const String attendance = 'restaurantAttendanceBox';

  /// Item-level cancellation audit (items cancelled from a placed order, with reason)
  static const String restaurantItemCancellations = 'restaurantItemCancellationsBox';

  /// Recipes (Bill of Materials) — what a Semi-Finished/Recipe-Based item is made of
  static const String restaurantRecipes = 'restaurantRecipesBox';

  /// "Batch produced" log for Semi-Finished items (raw materials -> prepped stock)
  static const String restaurantRecipeProductions = 'restaurantRecipeProductionsBox';

  /// Restaurant raw-material suppliers (mirrors retail's suppliers box, own box per mode)
  static const String restaurantSuppliers = 'restaurantSuppliersBox';

  /// Restaurant purchase orders (raw-material procurement)
  static const String restaurantPurchaseOrders = 'restaurantPurchaseOrdersBox';

  /// Restaurant purchase order line items
  static const String restaurantPurchaseOrderItems = 'restaurantPurchaseOrderItemsBox';

  /// Restaurant GRNs (Goods Receipt Notes) — confirming a GRN is the only
  /// place raw-material stock increments, mirrors retail's GRN pattern
  static const String restaurantGrns = 'restaurantGrnsBox';

  /// Restaurant GRN line items
  static const String restaurantGrnItems = 'restaurantGrnItemsBox';

  /// Restaurant purchase returns (damaged raw material sent back to supplier)
  static const String restaurantPurchaseReturns = 'restaurantPurchaseReturnsBox';

  /// Restaurant purchase return line items
  static const String restaurantPurchaseReturnItems = 'restaurantPurchaseReturnItemsBox';

  /// Restaurant supplier claims (damaged raw material kept on site pending compensation)
  static const String restaurantSupplierClaims = 'restaurantSupplierClaimsBox';

  /// Restaurant supplier claim line items
  static const String restaurantSupplierClaimItems = 'restaurantSupplierClaimItemsBox';

  /// Restaurant inventory losses (write-offs — damaged/rejected/adjusted stock)
  static const String restaurantInventoryLosses = 'restaurantInventoryLossesBox';

  /// Restaurant physical stock take sessions
  static const String restaurantStockTakes = 'restaurantStockTakesBox';

  /// Restaurant stock take line items
  static const String restaurantStockTakeItems = 'restaurantStockTakeItemsBox';

  /// Journal behind every restaurant supplier balance movement. One row per
  /// movement, written only by `RestaurantSupplierStore.recordBalanceMovement`.
  static const String restaurantSupplierLedger = 'restaurantSupplierLedgerBox';

  // ==================== HELPER METHODS ====================

  /// Get the appropriate EOD box name based on business mode
  ///
  /// [isRetail] - true for retail mode, false for restaurant mode
  /// Returns the correct EOD box name for the current mode
  static String getEODBox(bool isRetail) {
    return isRetail ? retailEOD : restaurantEOD;
  }

  /// Get the appropriate expense category box name based on business mode
  ///
  /// [isRetail] - true for retail mode, false for restaurant mode
  /// Returns the correct expense category box name for the current mode
  static String getExpenseCategoryBox(bool isRetail) {
    return isRetail ? retailExpenseCategory : restaurantExpenseCategory;
  }

  /// Get the appropriate expense box name based on business mode
  ///
  /// [isRetail] - true for retail mode, false for restaurant mode
  /// Returns the correct expense box name for the current mode
  static String getExpenseBox(bool isRetail) {
    return isRetail ? retailExpense : restaurantExpense;
  }

  // ==================== BOX NAME LISTS ====================

  /// All retail box names (for bulk operations like clearing/backup)
  static const List<String> allRetailBoxes = [
    products,
    variants,
    cartItems,
    sales,
    saleItems,
    customer,
    suppliers,
    supplierLedger,
    purchaseOrders,
    purchaseReturns,
    purchaseReturnItems,
    supplierClaims,
    supplierClaimItems,
    inventoryLosses,
    stockTakes,
    stockTakeItems,
    bundles,
    kitAssemblies,
    purchaseOrderItems,
    grns,
    grnItems,
    holdSales,
    holdSaleItems,
    retailCategories,
    category,
    paymentEntries,
    creditPayments,
    attributes,
    attributeValues,
    productAttributes,
    staff,
    billingTabs,
    retailEOD,
    retailExpenseCategory,
    retailExpense,
    tax,
    shift,
    attendance,
  ];

  /// All restaurant box names (for bulk operations like clearing/backup)
  static const List<String> allRestaurantBoxes = [
    category,
    restaurantItems,
    restaurantVariants,
    restaurantChoices,
    restaurantExtras,
    restaurantCart,
    staff,
    restaurantTables,
    restaurantOrders,
    restaurantPastOrders,
    tax,
    restaurantEOD,
    restaurantExpenseCategory,
    restaurantExpense,
    appCounters,
    testBillBox,
    customer,
    shift,
    restaurantCashMovements,
    restaurantStockMovements,
    restaurantStockJournal,
    restaurantCashHandovers,
    restaurantPrinters,
    restaurantSessions,
    attendance,
    restaurantItemCancellations,
    restaurantRecipes,
    restaurantRecipeProductions,
    restaurantSuppliers,
    restaurantPurchaseOrders,
    restaurantPurchaseOrderItems,
    restaurantGrns,
    restaurantGrnItems,
    restaurantPurchaseReturns,
    restaurantPurchaseReturnItems,
    restaurantSupplierClaims,
    restaurantSupplierClaimItems,
    restaurantInventoryLosses,
    restaurantStockTakes,
    restaurantStockTakeItems,
    restaurantSupplierLedger,
  ];

  /// All common box names (shared between retail and restaurant)
  static const List<String> allCommonBoxes = [
    appConfig,
    appState,
    storeBox,
    taxBox,
    businessTypeBox,
    businessDetailsBox,
    paymentMethods,
    dayManagementBox,
    appNotifications,
  ];
}