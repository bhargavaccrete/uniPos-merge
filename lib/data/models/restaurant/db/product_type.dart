/// The four ways a restaurant [Items] record can behave in inventory.
///
/// Stored as a plain string on `Items.productType` (matches this codebase's
/// convention for small enums, e.g. `isVeg`, `StockMovementModel.type`) rather
/// than a Hive-typed enum, so it never needs its own adapter/typeId.
/// See docs/inventory_recipe_system_plan.md §3 for the full rationale.
class ProductType {
  ProductType._();

  /// Purchased ingredient, stocked via PO/GRN. Has no recipe. Hidden from the
  /// POS sale grid by default (it's not usually sold on its own).
  static const String rawMaterial = 'rawMaterial';

  /// Prepped in-house ahead of time in batches (dough, sauce, cooked patty).
  /// Has a recipe describing what it's made FROM, but is itself directly
  /// stocked — replenished via the Production flow, not GRN, and decremented
  /// directly on sale like a Finished Good.
  static const String semiFinished = 'semiFinished';

  /// Ready-to-sell as-is (bottled drink, packaged snack). No recipe, no
  /// change from how every item worked before this feature existed.
  static const String finishedGood = 'finishedGood';

  /// LEGACY (pre-Phase 1). Stored on existing items and in old backups; read
  /// as Finished · made to order ([effective], [effectivePrepMode]). Never
  /// written by new code.
  static const String recipeBased = 'recipeBased';

  /// Bought and resold as-is (bottled drink, packaged snack). Own stock,
  /// replenished by PO → GRN; never has a recipe and is never an ingredient.
  static const String tradeItem = 'tradeItem';

  /// Finished preparation modes (`Items.prepMode`).
  static const String madeToOrder = 'madeToOrder';
  static const String madeInAdvance = 'madeInAdvance';

  /// The types a user can choose (Phase 1). Legacy [recipeBased] is read,
  /// never offered.
  static const List<String> all = [
    finishedGood,
    semiFinished,
    rawMaterial,
    tradeItem,
  ];

  /// What the item editor / quick add shows for a stored item: the effective
  /// type and the effective preparation mode, so a legacy 'recipeBased' item
  /// opens as Finished · made to order and saves back as exactly that.
  static ({String type, String prepMode, bool makeFresh}) editorView(
          String? storedType, String? storedPrepMode, bool storedMakeFresh) =>
      (
        type: effective(storedType),
        prepMode: effectivePrepMode(storedType, storedPrepMode),
        makeFresh: storedMakeFresh,
      );

  /// The fields the editor writes back. Only Finished carries a preparation
  /// mode, and only made in advance can "make fresh when out".
  static ({String productType, String? prepMode, bool makeFreshWhenOut})
      storedFields(
          {required String type,
          required String prepMode,
          required bool makeFresh}) {
    final finished = effective(type) == finishedGood;
    return (
      productType: effective(type),
      prepMode: finished ? prepMode : null,
      makeFreshWhenOut: finished && prepMode == madeInAdvance && makeFresh,
    );
  }

  /// The preparation mode an item behaves with. A stored [prepMode] wins;
  /// otherwise a legacy 'recipeBased' item is made to order and every other
  /// item made in advance — exactly how each sold before Phase 1.
  static String effectivePrepMode(String? type, String? prepMode) =>
      prepMode ?? (type == recipeBased ? madeToOrder : madeInAdvance);

  /// True for types that carry a [RecipeModel] (via `Items.recipeId`).
  static bool hasRecipe(String? type) =>
      type == semiFinished || type == recipeBased;

  /// True for types whose stock is derived from ingredients rather than
  /// stored on the item itself.
  static bool isStockDerived(String? type) => type == recipeBased;

  static String displayName(String? type) {
    switch (type) {
      case rawMaterial:
        return 'Raw Material';
      case semiFinished:
        return 'Semi-Finished';
      case tradeItem:
        return 'Trade Item';
      case recipeBased: // legacy — reads as Finished (made to order)
      case finishedGood:
      default:
        return 'Finished';
    }
  }

  /// `Items.productType` is nullable so every pre-existing item stays valid
  /// with zero migration — null reads as Finished Good, today's only behavior.
  /// Legacy 'recipeBased' reads as Finished too; its made-to-order behaviour
  /// comes from [effectivePrepMode].
  static String effective(String? type) =>
      (type == null || type == recipeBased) ? finishedGood : type;

  /// Menu items (sold on the POS grid) need a category + selling price;
  /// back-of-house types (Raw Material, Semi-Finished) don't. Single source
  /// of truth for both AddItemFormState.validate() and Edit Item's save
  /// validation, so the two screens can't drift on this rule again.
  static bool isMenuType(String? type) =>
      type == finishedGood || type == recipeBased || type == tradeItem;

  /// The stock fields an item must carry once its type is [type]. Recipe-Based
  /// items derive availability from their recipe (see [isStockDerived]) and
  /// must never carry over stale tracking/quantity from before a type switch.
  /// Finished (optional recipe) and Semi-Finished can carry a recipe; Raw
  /// Material and Trade Item never do.
  static bool canHaveRecipe(String? type) =>
      type == finishedGood || type == semiFinished || type == recipeBased;

  /// [prepMode] is the Finished preparation mode: made to order owns no
  /// stock, exactly like the legacy Recipe-Based type.
  static ({bool trackInventory, double stockQuantity}) resolvePhysicalStock(
    String? type, {
    String? prepMode,
    required bool requestedTrackInventory,
    required double requestedStockQuantity,
  }) {
    if (isStockDerived(type) ||
        (type == finishedGood && prepMode == madeToOrder)) {
      return (trackInventory: false, stockQuantity: 0.0);
    }
    return (
      trackInventory: requestedTrackInventory,
      stockQuantity: requestedStockQuantity,
    );
  }

  /// A Raw Material's "Cost Price" input must seed `Items.lastPurchaseCost`
  /// — every costing consumer (recipe cost, stock-take, loss valuation,
  /// movement unitCost) reads that field, not `price`. `price` itself is left
  /// untouched by callers of this helper, so a Raw Material's existing
  /// sell-directly-at-POS price behavior is unaffected. GRN continues to be
  /// the only thing that updates `lastPurchaseCost` after creation (see
  /// RestaurantPurchaseOrderStore's GRN-confirm flow) — this only seeds the
  /// initial value so recipe costing isn't blind until the first GRN.
  static double? seededLastPurchaseCost(String? type, double? enteredCost) =>
      type == rawMaterial ? enteredCost : null;
}
