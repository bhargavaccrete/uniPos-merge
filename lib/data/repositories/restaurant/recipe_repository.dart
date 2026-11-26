import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/recipe_model.dart';

/// Data access layer for [RecipeModel]. One recipe per item (`itemId` is
/// effectively unique) — see docs/inventory_recipe_system_plan.md §4.
class RecipeRepository {
  Box<RecipeModel> get _box => Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes);

  List<RecipeModel> getAllRecipes() => _box.values.toList();

  RecipeModel? getRecipeById(String id) => _box.get(id);

  /// The recipe that produces [itemId], if any.
  RecipeModel? getRecipeForItem(String itemId) {
    try {
      return _box.values.firstWhere((r) => r.itemId == itemId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRecipe(RecipeModel recipe) async {
    await _box.put(recipe.id, recipe);
  }

  /// Saves [recipe] as THE recipe of its item: if the item already has one
  /// under another id, that row is replaced in place (its id kept), so an
  /// item can never end up with two recipes.
  Future<void> saveForItem(RecipeModel recipe) async {
    final existing = getRecipeForItem(recipe.itemId);
    if (existing != null && existing.id != recipe.id) {
      await _box.put(existing.id, recipe.copyWith(id: existing.id));
      return;
    }
    await _box.put(recipe.id, recipe);
  }

  Future<void> deleteRecipe(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteRecipeForItem(String itemId) async {
    final recipe = getRecipeForItem(itemId);
    if (recipe != null) await _box.delete(recipe.id);
  }
}
