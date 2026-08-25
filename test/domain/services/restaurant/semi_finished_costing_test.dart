import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';

/// M1 — a Semi-Finished item's cost was never written back after production.
///
/// TRACE: `InventoryService.produceBatch` already computed the correct
/// `producedUnitCost` (`recipe.estimatedCostPerUnit(...)`) and put it on the
/// produced StockMovementModel's `unitCost` — but that's a historical
/// movement record, read only by reports that filter on movement reason
/// (`ingredientUsageReport`/`wastageReport`). It was never written onto
/// `semiFinishedItem.lastPurchaseCost`. Every OTHER cost consumer — a parent
/// Recipe-Based recipe using this item as an ingredient
/// (`ingredientQuantitiesFor`'s cost lookup), `RecipeReportService
/// .foodCostReport`, `RecipeBuilderWidget`'s cost preview — reads
/// `ingredient.lastPurchaseCost ?? 0.0`. With it unset, a produced
/// Semi-Finished item costs ₹0 everywhere except its own movement history.
///
/// FIX: `produceBatch` now also sets
/// `semiFinishedItem.lastPurchaseCost = producedUnitCost` and saves it —
/// the same `item.save()` pattern already used for `stockQuantity` in the
/// same method. The next production run overwrites it, exactly like a Raw
/// Material's `lastPurchaseCost` is overwritten by its next GRN. No new
/// field, no manual cost entry.
///
/// These tests drive the same pure entry point production code uses
/// (`RecipeModel.estimatedCostPerUnit`) and the exact assignment the fix
/// performs, since `produceBatch` itself needs a full GetIt/Hive harness
/// (see recipe_availability_test.dart's note on this codebase's convention).
void main() {
  // Potato: ₹50/kg, purchased — unaffected by this fix.
  Items potato({double lastPurchaseCost = 50.0}) => Items(
        id: 'rm-potato',
        name: 'Potato',
        productType: ProductType.rawMaterial,
        unit: 'kg',
        lastPurchaseCost: lastPurchaseCost,
      );

  // Bread: ₹2/slice, purchased — used directly by a Recipe-Based dish too.
  Items bread({double lastPurchaseCost = 2.0}) => Items(
        id: 'rm-bread',
        name: 'Bread',
        productType: ProductType.rawMaterial,
        unit: 'pcs',
        lastPurchaseCost: lastPurchaseCost,
      );

  RecipeModel vadaRecipe() => RecipeModel(
        id: 'recipe-vada',
        itemId: 'sf-vada',
        yieldQty: 10, // 10 Vadas per batch
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'rm-potato', quantity: 1.0), // 1 kg potato
        ],
      );

  double costOf(List<Items> items, String id) {
    try {
      return items.firstWhere((i) => i.id == id).lastPurchaseCost ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  test('1. SF recipe cost / yield = unit cost (₹50 potato / 10 Vadas = ₹5)', () {
    final items = [potato()];
    final recipe = vadaRecipe();
    final unitCost = recipe.estimatedCostPerUnit((id) => costOf(items, id));
    expect(unitCost, closeTo(5.0, 0.0001));
  });

  test('2. producing the SF batch establishes that unit cost on the item', () {
    final items = [potato()];
    final recipe = vadaRecipe();
    final vada = Items(id: 'sf-vada', name: 'Vada', productType: ProductType.semiFinished, unit: 'pcs');
    expect(vada.lastPurchaseCost, isNull); // unset before production, as today

    // The exact fix applied inside produceBatch: compute from the recipe,
    // write it back onto the produced item.
    final producedUnitCost = recipe.estimatedCostPerUnit((id) => costOf(items, id));
    vada.lastPurchaseCost = producedUnitCost;

    expect(vada.lastPurchaseCost, closeTo(5.0, 0.0001));
  });

  test('3. a parent Recipe-Based recipe using the SF receives ₹5, not ₹0', () {
    final rawItems = [potato()];
    final vadaRecipeModel = vadaRecipe();
    final vada = Items(id: 'sf-vada', name: 'Vada', productType: ProductType.semiFinished, unit: 'pcs');
    // Simulate a completed production run, per test 2.
    vada.lastPurchaseCost = vadaRecipeModel.estimatedCostPerUnit((id) => costOf(rawItems, id));

    final allItems = [...rawItems, vada];
    final vadaPavRecipe = RecipeModel(
      id: 'recipe-vada-pav',
      itemId: 'rb-vada-pav',
      yieldQty: 1,
      ingredients: [
        RecipeIngredientModel(ingredientItemId: 'sf-vada', quantity: 1.0), // 1 Vada per Vada Pav
      ],
    );

    final vadaPavCost = vadaPavRecipe.estimatedCostPerUnit((id) => costOf(allItems, id));
    expect(vadaPavCost, closeTo(5.0, 0.0001));
  });

  test('4. Raw Material costing is unaffected by the SF fix', () {
    // A Recipe-Based dish consuming a Raw Material directly (no SF involved)
    // still costs exactly as before: 0.2 kg potato @ ₹50/kg = ₹10.
    final items = [potato()];
    final friesRecipe = RecipeModel(
      id: 'recipe-fries',
      itemId: 'rb-fries',
      yieldQty: 1,
      ingredients: [
        RecipeIngredientModel(ingredientItemId: 'rm-potato', quantity: 0.2),
      ],
    );
    expect(friesRecipe.estimatedCostPerUnit((id) => costOf(items, id)), closeTo(10.0, 0.0001));
  });

  test('5. Recipe-Based costing combining a direct Raw Material and the fixed SF is correct', () {
    final rawItems = [potato(), bread()];
    final vadaRecipeModel = vadaRecipe();
    final vada = Items(id: 'sf-vada', name: 'Vada', productType: ProductType.semiFinished, unit: 'pcs');
    vada.lastPurchaseCost = vadaRecipeModel.estimatedCostPerUnit((id) => costOf(rawItems, id));

    final allItems = [...rawItems, vada];
    // Vada Pav: 1 Vada (₹5, from the fix) + 2 slices Bread (₹2 each, direct RM) = ₹9.
    final vadaPavRecipe = RecipeModel(
      id: 'recipe-vada-pav-2',
      itemId: 'rb-vada-pav',
      yieldQty: 1,
      ingredients: [
        RecipeIngredientModel(ingredientItemId: 'sf-vada', quantity: 1.0),
        RecipeIngredientModel(ingredientItemId: 'rm-bread', quantity: 2.0),
      ],
    );
    expect(vadaPavRecipe.estimatedCostPerUnit((id) => costOf(allItems, id)), closeTo(9.0, 0.0001));
  });
}
