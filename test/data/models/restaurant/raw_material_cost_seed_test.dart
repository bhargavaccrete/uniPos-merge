import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';

/// B1 — a Raw Material's "Cost Price" input was being saved only to
/// `Items.price`, which no costing consumer reads; they all read
/// `lastPurchaseCost`, which only a GRN confirm wrote. So a freshly-created
/// Raw Material priced at the Add/Edit screen contributed ₹0 to recipe
/// costing until its first GRN.
///
/// The fix (`ProductType.seededLastPurchaseCost`, wired into both
/// `AddItemFormState.toItem()` and `EdititemScreen._saveChanges`) also seeds
/// `lastPurchaseCost` from that same input for Raw Material only, without
/// touching `price` (still needed for `sellDirectlyAtPos` selling behavior)
/// or GRN's own write.
void main() {
  group('ProductType.seededLastPurchaseCost', () {
    test('Raw Material cost price seeds lastPurchaseCost', () {
      expect(ProductType.seededLastPurchaseCost(ProductType.rawMaterial, 50.0), 50.0);
    });

    test('a blank/unparseable cost price seeds null, same as leaving it empty today', () {
      expect(ProductType.seededLastPurchaseCost(ProductType.rawMaterial, null), isNull);
    });

    test('every other type never seeds lastPurchaseCost from this input', () {
      expect(ProductType.seededLastPurchaseCost(ProductType.semiFinished, 50.0), isNull);
      expect(ProductType.seededLastPurchaseCost(ProductType.finishedGood, 50.0), isNull);
      expect(ProductType.seededLastPurchaseCost(ProductType.recipeBased, 50.0), isNull);
      expect(ProductType.seededLastPurchaseCost(null, 50.0), isNull);
    });
  });

  group('Raw Material selling price is unaffected by the cost seed', () {
    test('price (what the cart/finalPrice reads) stays independent of lastPurchaseCost', () {
      // Simulates a Raw Material with "Sell directly at POS" on: the same
      // Cost Price input still writes `price` unconditionally (unchanged),
      // while lastPurchaseCost is seeded alongside it from this fix.
      final potato = Items(
        id: 'rm-1',
        name: 'Potato',
        price: 50.0,
        productType: ProductType.rawMaterial,
        sellDirectlyAtPos: true,
        lastPurchaseCost: ProductType.seededLastPurchaseCost(ProductType.rawMaterial, 50.0),
      );
      expect(potato.finalPrice, 50.0);
      expect(potato.lastPurchaseCost, 50.0);

      // Even if lastPurchaseCost later diverges (e.g. after a GRN at a
      // different rate), the POS selling price must keep reading `price`,
      // never `lastPurchaseCost`.
      potato.lastPurchaseCost = 999.0;
      expect(potato.finalPrice, 50.0);
    });
  });

  test('GRN can still update the same Raw Material cost after creation (₹50 → ₹55)', () {
    // Step 1: created in Add/Edit with Cost Price ₹50 — our fix seeds it.
    final potato = Items(
      id: 'rm-1',
      name: 'Potato',
      productType: ProductType.rawMaterial,
      lastPurchaseCost: ProductType.seededLastPurchaseCost(ProductType.rawMaterial, 50.0),
    );
    expect(potato.lastPurchaseCost, 50.0);

    // Step 2: a GRN line confirms at ₹55 — same unconditional overwrite
    // RestaurantPurchaseOrderStore performs today (`item.lastPurchaseCost =
    // line.costPrice`), untouched by this fix.
    const grnLineCostPrice = 55.0;
    potato.lastPurchaseCost = grnLineCostPrice;
    expect(potato.lastPurchaseCost, 55.0);
  });

  test('recipe costing sees the seeded ₹50 immediately, before any GRN', () {
    final potato = Items(
      id: 'rm-1',
      name: 'Potato',
      productType: ProductType.rawMaterial,
      lastPurchaseCost: ProductType.seededLastPurchaseCost(ProductType.rawMaterial, 50.0),
    );
    final items = [potato];

    // Same shape as InventoryService's production-cost lookup and
    // RecipeReportService's ingredient cost lookup: resolve by id, read
    // lastPurchaseCost, default to 0 if never purchased/found.
    double costOf(String id) {
      Items? ing;
      try {
        ing = items.firstWhere((i) => i.id == id);
      } catch (_) {
        return 0.0;
      }
      return ing.lastPurchaseCost ?? 0.0;
    }

    final friesRecipe = RecipeModel(
      id: 'recipe-fries',
      itemId: 'fries',
      yieldQty: 1,
      ingredients: [
        RecipeIngredientModel(ingredientItemId: 'rm-1', quantity: 0.2), // 200g potato per portion
      ],
    );

    expect(friesRecipe.estimatedCostPerUnit(costOf), closeTo(10.0, 0.0001)); // 0.2 * 50
  });
}
