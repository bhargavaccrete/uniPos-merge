/// Hive TypeAdapter IDs for all models in the app
///
/// ID Ranges (MUST be 0-223 due to Hive limitation):
/// - Common Models:              1-19
/// - Restaurant Models:          100-149   ← FULL, do not add here
/// - Retail Models:              150-184   (assigned so far)
/// - Restaurant OVERFLOW:        185-199   ← new restaurant models go here
/// - Retail Models (future):     200-223
///
/// IMPORTANT: Once assigned, these IDs should NEVER be changed
/// as it will break existing Hive databases.
/// NOTE: Hive only allows TypeIds from 0 to 223!
///
/// ## Why there is a restaurant overflow range
///
/// The original layout gave restaurant 100-149 and retail 150-223. Restaurant
/// filled its 50 slots (the last seven went to the damaged-goods/stock-take
/// chain, 143-149), so a new restaurant model has nowhere to go inside its
/// own block.
///
/// The 100-149 boundary is a *convention*, not a runtime constraint — verified
/// before this range was carved out:
///   - Hive's hard limit is 223; the highest id assigned anywhere was 184.
///   - All 82 adapters in the app resolve their typeId through this class
///     (only `paymentMethod`'s literal 6 is inline), and none collide.
///   - `isRestaurantModel` / `isRetailModel` / `restaurantModelIds` /
///     `retailModelIds` below have ZERO consumers in lib/ — nothing at runtime
///     branches on which range an id falls in.
///
/// So restaurant continues at 185. Retail's next id must start at **200**, not
/// 185, or the two modes will collide — that is the only rule this split adds.
/// Restaurant has 186-199 (14 slots) left; retail has 200-223 (24 slots).

class HiveTypeIds {
  HiveTypeIds._(); // Private constructor to prevent instantiation

  // ==================== COMMON MODELS (1-19) ====================
  static const int taxDetails = 2;
  static const int businessType = 3;
  static const int businessDetails = 4;
  // 5 was taxRateItem — retired, named tax rates now live in the shared
  // Tax entity (typeId 114, data/models/common/taxmodel_314.dart), not this
  // per-record blob. Don't reuse 5.
  static const int paymentMethod = 6;

  // ==================== RESTAURANT MODELS (100-149) ====================
  // category, staff, customer, and tax below are shared with retail (see
  // data/models/common/) — kept in this numeric range since that's where
  // they were first assigned; the number can never move, only what we
  // call it in code.
  static const int category = 100;
  // 101 was restaurantCompany — retired, the Company model/repo/store were
  // confirmed dead code (only writer was an unreachable screen) and deleted;
  // store info lives in the shared BusinessDetails model instead. Don't
  // reuse 101.
  static const int restaurantItem = 102;
  static const int restaurantExtra = 103;
  static const int restaurantTopping = 104;
  static const int restaurantVariant = 105;
  static const int restaurantChoice = 106;
  static const int restaurantChoiceOption = 107;
  static const int restaurantCart = 108;
  static const int restaurantOrder = 109;
  static const int staff = 110;
  static const int restaurantTable = 111;
  static const int restaurantItemVariant = 112;
  static const int restaurantPastOrder = 113;
  static const int tax = 114;
  static const int restaurantExpense = 115;
  static const int restaurantExpense1 = 116;
  static const int restaurantEod = 117;



  static const int OrderTypeSummary = 118;
  static const int CategorySales = 119;
  static const int PaymentSummary = 120;
  static const int CashReconciliation = 121;
  static const int TestBill = 122;
  static const int TestBillItem = 123;
  static const int TaxSummary = 124;
  static const int customer = 125;
  static const int restaurantStockLog = 126;
  static const int restaurantShift = 127;

  // Cash Management (128-129)
  static const int restaurantCashMovement = 128; // CashMovementModel — Cash In/Out events
  static const int restaurantCashHandover  = 129; // CashHandoverModel — 2-step shift handover

  // Printer Management (130)
  static const int savedPrinter = 130; // SavedPrinterModel — BT/WiFi printer config

  static const int restaurantSession = 131; // RestaurantSessionModel — Session-based day management
  static const int restaurantAttendance = 132; // AttendanceModel — Staff clock-in/clock-out
  // SHARED (restaurant + retail) — id and box name are historical, do not change.
  static const int appNotification = 133; // AppNotificationModel — persisted notifications
  static const int restaurantItemCancellation = 134; // ItemCancellationModel — item-level cancel audit

  // Recipe / BOM (135-137) — see docs/inventory_recipe_system_plan.md
  static const int restaurantRecipe = 135; // RecipeModel — header: what an item is made of
  static const int restaurantRecipeIngredient = 136; // RecipeIngredientModel — embedded line in RecipeModel.ingredients
  static const int restaurantRecipeProduction = 137; // RecipeProductionModel — "batch produced" log for Semi-Finished items

  // Restaurant Purchase Order / GRN (138-142) — raw-material procurement,
  // mirrors retail's Supplier/PurchaseOrder/GRN pattern (150-164) but scoped
  // to restaurant's Items model, per docs/inventory_recipe_system_plan.md §6.
  static const int restaurantSupplier = 138;
  static const int restaurantPurchaseOrder = 139;
  static const int restaurantPurchaseOrderItem = 140;
  static const int restaurantGrn = 141;
  static const int restaurantGrnItem = 142;

  // Restaurant damaged-goods/loss/stock-take chain (143-149) — mirrors
  // retail's PurchaseReturn/SupplierClaim/InventoryLoss/StockTake pattern
  // (174-181), scoped to restaurant's Items model. Exhausts the reserved
  // restaurant range (100-149) — any future restaurant model needs a new
  // range carved out.
  static const int restaurantPurchaseReturn = 143;
  static const int restaurantPurchaseReturnItem = 144;
  static const int restaurantSupplierClaim = 145;
  static const int restaurantSupplierClaimItem = 146;
  static const int restaurantInventoryLoss = 147;
  static const int restaurantStockTake = 148;
  static const int restaurantStockTakeItem = 149;

  // ==================== RETAIL MODELS (150-223) ====================
  static const int retailProduct = 150;
  static const int retailVariant = 151;
  static const int retailCart = 152;
  static const int retailSale = 153;
  static const int retailSaleItem = 154;
  static const int retailSupplier = 155;
  // RETIRED: 156 (retailPurchaseItem) and 157 (retailPurchase) belonged to the
  // standalone Purchase feature, removed in favour of Purchase Orders + GRN.
  // NEVER reassign these ids — old box files on disk still reference them.
  // 158 was retailCustomer — retired, customer now shares RestaurantCustomer's
  // typeId (125), see Customer in data/models/common/. Don't reuse 158.
  static const int retailHoldSale = 159;
  static const int retailHoldSaleItem = 160;
  static const int retailPurchaseOrder = 161;
  static const int retailPurchaseOrderItem = 162;
  static const int retailGrn = 163;
  static const int retailGrnItem = 164;
  // 165 was retailCategory — retired, category now shares restaurantCategory's
  // typeId (100), see Category in data/models/common/. Don't reuse 165.
  static const int retailPaymentEntry = 166;
  // 167 was retailAdmin — retired, admin credential is now a SharedPreferences
  // value (see domain/services/retail/auth_service.dart), not a Hive model.
  // Don't reuse 167.
  static const int retailCreditPayment = 168;
  static const int retailAttribute = 169;
  static const int retailAttributeValue = 170;
  static const int retailProductAttribute = 171;
  // 172 was retailStaff — retired, staff now shares restaurantStaff's typeId
  // (110), see StaffModel in data/models/common/. Don't reuse 172.
  static const int retailBillingTab = 173;

  // Damaged-goods workflow off the back of a GRN. Damaged units never enter
  // stock and are never billed, so these are records of intent/outcome, not
  // stock or ledger movements.
  static const int retailPurchaseReturn = 174;
  static const int retailPurchaseReturnItem = 175;
  static const int retailSupplierClaim = 176;
  static const int retailSupplierClaimItem = 177;
  static const int retailInventoryLoss = 178;

  /// Journal behind SupplierModel.currentBalance. One row per movement so the
  /// balance can be explained, not just stated.
  static const int retailSupplierLedgerEntry = 179;

  /// Physical stock count. Header + lines, following the PO/GRN pair
  /// convention: the header is the count session, each line one variant that
  /// was counted. Committing a line goes through `StockAdjustmentService`, so
  /// these boxes hold the count paperwork, never the stock movement itself.
  static const int retailStockTake = 180;
  static const int retailStockTakeItem = 181;

  /// Bundle/kit products — see docs/retail_inventory_system_plan.md §3.2.
  /// A bundle has no stock of its own and cascades a sale into its
  /// components; a repack/kit variant is stocked directly but replenished by
  /// assembling it from a source variant rather than a GRN.
  static const int retailBundle = 182;
  static const int retailBundleComponent = 183;

  /// Append-only "assembled a batch" log for repack/kit variants — mirrors
  /// restaurant's RecipeProductionModel.
  static const int retailKitAssembly = 184;

  // NOTE: the next RETAIL id is 200, not 185 — 185-199 is the restaurant
  // overflow range reserved below. See the range map at the top of this file.

  // ============ RESTAURANT OVERFLOW (185-199) ============
  // The 100-149 restaurant block is full. New restaurant models are assigned
  // here instead. Next free: 186.

  /// Journal behind `RestaurantSupplierModel.currentBalance`. One row per
  /// movement so the balance can be explained, not just stated — the same
  /// contract as retail's `retailSupplierLedgerEntry` (179).
  static const int restaurantSupplierLedgerEntry = 185;

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
    retailPurchaseReturn,
    retailPurchaseReturnItem,
    retailSupplierClaim,
    retailSupplierClaimItem,
    retailInventoryLoss,
    retailSupplierLedgerEntry,
    retailStockTake,
    retailStockTakeItem,
    retailHoldSale,
    retailHoldSaleItem,
    retailPurchaseOrder,
    retailPurchaseOrderItem,
    retailGrn,
    retailGrnItem,
    retailPaymentEntry,
    retailCreditPayment,
    retailAttribute,
    retailAttributeValue,
    retailProductAttribute,
    retailBillingTab,
    retailBundle,
    retailBundleComponent,
    retailKitAssembly
  ];

  /// Get all restaurant model IDs
  static List<int> get restaurantModelIds => [
    category,
    restaurantItem,
    restaurantExtra,
    restaurantTopping,
    restaurantVariant,
    restaurantChoice,
    restaurantChoiceOption,
    restaurantCart,
    restaurantOrder,
    staff,
    restaurantTable,
    restaurantItemVariant,
    restaurantPastOrder,
    tax,
    restaurantExpense,
    restaurantExpense1,
    restaurantEod,
    OrderTypeSummary,
    CategorySales,
    PaymentSummary,
    CashReconciliation,
    TestBill,
    TestBillItem,
    TaxSummary,
    customer,
    restaurantStockLog,
    restaurantShift,
    restaurantCashMovement,
    restaurantCashHandover,
    savedPrinter,
    restaurantSession,
    restaurantAttendance,
    appNotification,
    restaurantItemCancellation,
    restaurantRecipe,
    restaurantRecipeIngredient,
    restaurantRecipeProduction,
    restaurantSupplier,
    restaurantPurchaseOrder,
    restaurantPurchaseOrderItem,
    restaurantGrn,
    restaurantGrnItem,
    restaurantPurchaseReturn,
    restaurantPurchaseReturnItem,
    restaurantSupplierClaim,
    restaurantSupplierClaimItem,
    restaurantInventoryLoss,
    restaurantStockTake,
    restaurantStockTakeItem,
    restaurantSupplierLedgerEntry,
  ];

  /// True for ids in the restaurant overflow range carved out above.
  static bool isRestaurantOverflowModel(int typeId) =>
      typeId >= 185 && typeId <= 199;
}