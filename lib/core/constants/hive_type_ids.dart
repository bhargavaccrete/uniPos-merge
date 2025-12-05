/// Hive TypeAdapter IDs for all models in the app
///
/// ID Ranges:
/// - Common Models: 1-99
/// - Retail Models: 200-299
/// - Restaurant Models: 300-399
///
/// IMPORTANT: Once assigned, these IDs should NEVER be changed
/// as it will break existing Hive databases.

class HiveTypeIds {
  HiveTypeIds._(); // Private constructor to prevent instantiation

  // ==================== COMMON MODELS (1-99) ====================
  static const int taxDetails = 2;
  static const int businessType = 101;  // Matches @HiveType(typeId: 101) in business_type.dart
  static const int businessDetails = 102;

  // ==================== RETAIL MODELS (200-299) ====================
  static const int retailProduct = 200;
  static const int retailVariant = 201;
  static const int retailCart = 202;
  static const int retailSale = 203;
  static const int retailSaleItem = 204;
  static const int retailSupplier = 205;
  static const int retailPurchaseItem = 206;
  static const int retailPurchase = 207;
  static const int retailCustomer = 208;
  static const int retailHoldSale = 209;
  static const int retailHoldSaleItem = 210;
  static const int retailPurchaseOrder = 211;
  static const int retailPurchaseOrderItem = 212;
  static const int retailGrn = 213;
  static const int retailGrnItem = 214;
  static const int retailCategory = 215;
  static const int retailPaymentEntry = 216;
  static const int retailAdmin = 217;
  static const int retailCreditPayment = 218;
  static const int retailAttribute = 219;
  static const int retailAttributeValue = 220;
  static const int retailProductAttribute = 221;

  // ==================== RESTAURANT MODELS (300-399) ====================
  static const int restaurantCategory = 300;
  static const int restaurantCompany = 301;
  static const int restaurantItem = 302;
  static const int restaurantExtra = 303;
  static const int restaurantTopping = 304;
  static const int restaurantVariant = 305;
  static const int restaurantChoice = 306;
  static const int restaurantChoiceOption = 307;
  static const int restaurantCart = 308;
  static const int restaurantOrder = 309;
  static const int restaurantStaff = 310;
  static const int restaurantTable = 311;
  static const int restaurantItemVariant = 312;
  static const int restaurantPastOrder = 313;
  static const int restaurantTax = 314;
  static const int restaurantExpense = 315;
  static const int restaurantExpense1 = 316;
  static const int restaurantEod = 317;
  static const int restaurantTestBill = 318;

  // ==================== HELPER METHODS ====================

  /// Check if a typeId belongs to retail models
  static bool isRetailModel(int typeId) {
    return typeId >= 200 && typeId < 300;
  }

  /// Check if a typeId belongs to restaurant models
  static bool isRestaurantModel(int typeId) {
    return typeId >= 300 && typeId < 400;
  }

  /// Check if a typeId belongs to common models
  static bool isCommonModel(int typeId) {
    return typeId >= 1 && typeId < 100;
  }

  /// Get all retail model IDs
  static List<int> get retailModelIds => [
    retailProduct,
    retailVariant,
    retailCart,
    retailSale,
    retailSaleItem,
    retailSupplier,
    retailPurchaseItem,
    retailPurchase,
    retailCustomer,
    retailHoldSale,
    retailHoldSaleItem,
    retailPurchaseOrder,
    retailPurchaseOrderItem,
    retailGrn,
    retailGrnItem,
    retailCategory,
    retailPaymentEntry,
    retailAdmin,
    retailCreditPayment,
    retailAttribute,
    retailAttributeValue,
    retailProductAttribute,
  ];

  /// Get all restaurant model IDs
  static List<int> get restaurantModelIds => [
    restaurantCategory,
    restaurantCompany,
    restaurantItem,
    restaurantExtra,
    restaurantTopping,
    restaurantVariant,
    restaurantChoice,
    restaurantChoiceOption,
    restaurantCart,
    restaurantOrder,
    restaurantStaff,
    restaurantTable,
    restaurantItemVariant,
    restaurantPastOrder,
    restaurantTax,
    restaurantExpense,
    restaurantExpense1,
    restaurantEod,
    restaurantTestBill,
  ];
}