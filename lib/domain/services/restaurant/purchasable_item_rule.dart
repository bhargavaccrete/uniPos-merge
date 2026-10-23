import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';

/// Which items a supplier can deliver on a Purchase Order (Phase 1.7).
///
/// Raw Materials, Semi-Finished (bought-in prep, Q5) and Trade Items are
/// bought. Made-to-order dishes own no stock, and a made-in-advance Finished
/// item with a recipe is produced, so neither is ordered. A Finished item
/// with no recipe was most likely bought in before Trade Item existed: it
/// stays orderable, flagged so the owner reclassifies it (Q1).
class PurchasableItemRule {
  PurchasableItemRule._();

  static const String legacyLabel = 'Legacy — set as Trade Item';

  /// [hasRecipe]: the item has a recipe with at least one ingredient.
  static bool isPurchasable(Items item, {required bool hasRecipe}) =>
      item.isRawMaterial ||
      item.isSemiFinished ||
      item.isTradeItem ||
      isLegacyBoughtIn(item, hasRecipe: hasRecipe);

  static bool isLegacyBoughtIn(Items item, {required bool hasRecipe}) =>
      item.isMadeInAdvance && !hasRecipe;
}
