import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/product_type.dart';
import '../../../data/models/restaurant/db/recipe_model.dart';

/// Which items take part in recipes (Phase 1.5). PURE — the Recipes screen,
/// the Create Recipe picker and the recipe builder all read these rules.
class RecipeCatalog {
  /// Items Create Recipe offers: Finished or Semi-Finished, no recipe yet.
  static List<Items> itemsNeedingRecipe(
      List<Items> items, List<RecipeModel> recipes) {
    final withRecipe = {for (final r in recipes) r.itemId};
    return [
      for (final i in items)
        if (_canHaveRecipe(i) && !withRecipe.contains(i.id)) i,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The Recipes list: one entry per recipe whose item still exists and can
  /// carry one (a recipe kept after a type change to Raw / Trade is hidden),
  /// sorted by item name.
  static List<({Items item, RecipeModel recipe})> entries(
      List<Items> items, List<RecipeModel> recipes) {
    final byId = {for (final i in items) i.id: i};
    final seen = <String>{};
    final out = <({Items item, RecipeModel recipe})>[];
    for (final r in recipes) {
      final item = byId[r.itemId];
      if (item == null || !_canHaveRecipe(item) || !seen.add(item.id)) continue;
      out.add((item: item, recipe: r));
    }
    return out..sort((a, b) => a.item.name.compareTo(b.item.name));
  }

  /// What a recipe for [forItemId] may use: Raw Materials and Semi-Finished
  /// items, never itself. Trade Items and Finished items are never
  /// ingredients — this also keeps the sale cascade one level deep.
  static List<Items> ingredientCandidates(List<Items> items,
          {required String forItemId}) =>
      [
        for (final i in items)
          if ((i.isRawMaterial || i.isSemiFinished) && i.id != forItemId) i,
      ]..sort((a, b) => a.name.compareTo(b.name));

  static bool _canHaveRecipe(Items i) =>
      ProductType.canHaveRecipe(i.effectiveProductType);
}
