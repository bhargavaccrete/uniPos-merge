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

  /// Composed at time of sale (Burger, Pizza). Has a recipe describing what
  /// it's made FROM. Not stocked itself — its "stock" is derived live from
  /// ingredient availability, and selling one cascades a deduction into its
  /// ingredients instead of decrementing its own stockQuantity.
  static const String recipeBased = 'recipeBased';

  static const List<String> all = [
    rawMaterial,
    semiFinished,
    finishedGood,
    recipeBased,
  ];

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
      case recipeBased:
        return 'Recipe-Based';
      case finishedGood:
      default:
        return 'Finished Good';
    }
  }

  /// `Items.productType` is nullable so every pre-existing item stays valid
  /// with zero migration — null reads as Finished Good, today's only behavior.
  static String effective(String? type) => type ?? finishedGood;

  /// Menu items (sold on the POS grid) need a category + selling price;
  /// back-of-house types (Raw Material, Semi-Finished) don't. Single source
  /// of truth for both AddItemFormState.validate() and Edit Item's save
  /// validation, so the two screens can't drift on this rule again.
  static bool isMenuType(String? type) =>
      type == finishedGood || type == recipeBased;

  /// The stock fields an item must carry once its type is [type]. Recipe-Based
  /// items derive availability from their recipe (see [isStockDerived]) and
  /// must never carry over stale tracking/quantity from before a type switch.
  static ({bool trackInventory, double stockQuantity}) resolvePhysicalStock(
    String? type, {
    required bool requestedTrackInventory,
    required double requestedStockQuantity,
  }) {
    if (isStockDerived(type)) {
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
