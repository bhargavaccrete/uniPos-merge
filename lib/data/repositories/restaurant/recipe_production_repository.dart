import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/recipe_production_model.dart';

/// Data access layer for [RecipeProductionModel] — the append-only "batch
/// produced" log for Semi-Finished items. See
/// docs/inventory_recipe_system_plan.md §6.3.
class RecipeProductionRepository {
  Box<RecipeProductionModel> get _box =>
      Hive.box<RecipeProductionModel>(HiveBoxNames.restaurantRecipeProductions);

  List<RecipeProductionModel> getAllProductions() =>
      _box.values.toList()..sort((a, b) => b.producedTime.compareTo(a.producedTime));

  List<RecipeProductionModel> getProductionsForItem(String itemId) =>
      getAllProductions().where((p) => p.itemId == itemId).toList();

  Future<void> saveProduction(RecipeProductionModel production) async {
    await _box.put(production.id, production);
  }
}
