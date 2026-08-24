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
        return 'Semi-Finished (Prep)';
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
}
