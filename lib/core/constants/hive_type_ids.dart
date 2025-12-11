/// Hive TypeAdapter IDs for all models in the app
///
/// ID Ranges (MUST be 0-223 due to Hive limitation):
/// - Common Models: 1-19
/// - Restaurant Models: 100-149
/// - Retail Models: 150-223
///
/// IMPORTANT: Once assigned, these IDs should NEVER be changed
/// as it will break existing Hive databases.
/// NOTE: Hive only allows TypeIds from 0 to 223!

class HiveTypeIds {
  HiveTypeIds._(); // Private constructor to prevent instantiation

  // ==================== COMMON MODELS (1-19) ====================
  static const int taxDetails = 2;
  static const int businessType = 3;
  static const int businessDetails = 4;
  static const int taxRateItem = 5;
  static const int paymentMethod = 6;

  // ==================== RESTAURANT MODELS (100-149) ====================
  static const int restaurantCategory = 100;
  static const int restaurantCompany = 101;
  static const int restaurantItem = 102;
  static const int restaurantExtra = 103;
  static const int restaurantTopping = 104;
  static const int restaurantVariant = 105;
  static const int restaurantChoice = 106;
  static const int restaurantChoiceOption = 107;
  static const int restaurantCart = 108;
  static const int restaurantOrder = 109;
  static const int restaurantStaff = 110;
  static const int restaurantTable = 111;
  static const int restaurantItemVariant = 112;
  static const int restaurantPastOrder = 113;
  static const int restaurantTax = 114;
  static const int restaurantExpense = 115;
  static const int restaurantExpense1 = 116;
  static const int restaurantEod = 117;
  static const int orderTypeSummary = 118;
  static const int CategorySales = 119;
  static const int PaymentSummary = 120;
  static const int CashReconciliation = 121;
  static const int restaurantTestBill = 122;
  static const int restaurantTestBillItem = 123;

  // ==================== RETAIL MODELS (150-223) ====================
  static const int retailProduct = 150;
  static const int retailVariant = 151;
  static const int retailCart = 152;
  static const int retailSale = 153;
  static const int retailSaleItem = 154;
  static const int retailSupplier = 155;
  static const int retailPurchaseItem = 156;
  static const int retailPurchase = 157;
  static const int retailCustomer = 158;
  static const int retailHoldSale = 159;
  static const int retailHoldSaleItem = 160;
  static const int retailPurchaseOrder = 161;
  static const int retailPurchaseOrderItem = 162;
  static const int retailGrn = 163;
  static const int retailGrnItem = 164;
  static const int retailCategory = 165;
  static const int retailPaymentEntry = 166;
  static const int retailAdmin = 167;
  static const int retailCreditPayment = 168;
  static const int retailAttribute = 169;
  static const int retailAttributeValue = 170;
  static const int retailProductAttribute = 171;
  static const int retailStaff = 172;

  // ==================== HELPER METHODS ====================

  /// Check if a typeId belongs to retail models
  static bool isRetailModel(int typeId) {
    return typeId >= 150 && typeId <= 223;
  }

  /// Check if a typeId belongs to restaurant models
  static bool isRestaurantModel(int typeId) {
    return typeId >= 100 && typeId < 150;
  }

  /// Check if a typeId belongs to common models
  static bool isCommonModel(int typeId) {
    return typeId >= 1 && typeId < 20;
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
    retailStaff,
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