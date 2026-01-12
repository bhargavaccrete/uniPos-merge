/// Centralized Hive Box Names
///
/// All Hive box names used throughout the application are defined here.
/// This prevents typos, makes refactoring easier, and provides a single source of truth.
///
/// Usage:
/// ```dart
/// import 'package:unipos/core/constants/hive_box_names.dart';
///
/// // Instead of: Hive.box('products')
/// // Use: Hive.box(HiveBoxNames.products)
/// ```

class HiveBoxNames {
  // Private constructor to prevent instantiation
  HiveBoxNames._();

  // ==================== COMMON BOXES ====================

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

  /// Customer records box
  static const String customers = 'customers';

  /// Supplier records box
  static const String suppliers = 'suppliers';

  /// Purchase orders box
  static const String purchases = 'purchases';

  /// Purchase line items box
  static const String purchaseItems = 'purchaseItems';

  /// Purchase order model box
  static const String purchaseOrders = 'purchaseOrders';

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

  /// Retail category models box (with GST support)
  static const String categoryModels = 'category_models';

  /// Payment entries box
  static const String paymentEntries = 'paymentEntries';

  /// Admin box
  static const String adminBox = 'admin_box';

  /// Credit payments box
  static const String creditPayments = 'credit_payments';

  /// Attributes box
  static const String attributes = 'attributes';

  /// Attribute values box
  static const String attributeValues = 'attribute_values';

  /// Product attributes box
  static const String productAttributes = 'product_attributes';

  /// Retail staff box
  static const String retailStaff = 'retail_staff';

  /// Billing tabs box
  static const String billingTabs = 'billingTabs';

  /// Retail end-of-day reports box
  static const String retailEOD = 'eodBox';

  /// Retail expense categories box
  static const String retailExpenseCategory = 'expenseCategory';

  /// Retail expenses box
  static const String retailExpense = 'expenseBox';

  // ==================== RESTAURANT BOXES ====================

  /// Restaurant categories box
  static const String restaurantCategories = 'categories';

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

  /// Restaurant company/business details box
  static const String restaurantCompany = 'companyBox';

  /// Restaurant staff box
  static const String restaurantStaff = 'staffBox';

  /// Restaurant tables box
  static const String restaurantTables = 'tablesBox';

  /// Restaurant current orders box
  static const String restaurantOrders = 'orderBox';

  /// Restaurant past/completed orders box
  static const String restaurantPastOrders = 'pastorderBox';

  /// Restaurant taxes box
  static const String restaurantTaxes = 'restaurant_taxes';

  /// Restaurant end-of-day reports box
  static const String restaurantEOD = 'restaurant_eodBox';

  /// Restaurant expense categories box
  static const String restaurantExpenseCategory = 'restaurant_expenseCategory';

  /// Restaurant expenses box
  static const String restaurantExpense = 'restaurant_expenseBox';

  /// Restaurant app counters box (for order numbering)
  static const String appCounters = 'appCounters';

  /// Restaurant test bill box
  static const String testBillBox = 'testBillBox';
  static const String restaurantCustomer = 'restaurantCustomers';

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
    customers,
    suppliers,
    purchases,
    purchaseItems,
    purchaseOrders,
    purchaseOrderItems,
    grns,
    grnItems,
    holdSales,
    holdSaleItems,
    retailCategories,
    categoryModels,
    paymentEntries,
    adminBox,
    creditPayments,
    attributes,
    attributeValues,
    productAttributes,
    retailStaff,
    billingTabs,
    retailEOD,
    retailExpenseCategory,
    retailExpense,
  ];

  /// All restaurant box names (for bulk operations like clearing/backup)
  static const List<String> allRestaurantBoxes = [
    restaurantCategories,
    restaurantItems,
    restaurantVariants,
    restaurantChoices,
    restaurantExtras,
    restaurantCart,
    restaurantCompany,
    restaurantStaff,
    restaurantTables,
    restaurantOrders,
    restaurantPastOrders,
    restaurantTaxes,
    restaurantEOD,
    restaurantExpenseCategory,
    restaurantExpense,
    appCounters,
    testBillBox,
    restaurantCustomer
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
  ];
}