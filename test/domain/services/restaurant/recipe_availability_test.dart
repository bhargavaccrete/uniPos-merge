import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';

/// PHASE 1 — POS CORRECTNESS FOR RECIPE-BASED ITEMS + RAW-MATERIAL VISIBILITY
///
/// Covers the two gaps closed in this pass:
///   1. Raw Materials are hidden from the POS sale grid by default, with an
///      explicit per-item opt-in (`Items.sellDirectlyAtPos` → `sellsAtPos`).
///   2. Recipe-Based items derive availability from their ingredients via
///      `InventoryService`, instead of reporting a stored `stockQuantity` they
///      never populate.
///
/// WHAT THESE TESTS DRIVE, AND WHY IT'S THE REAL THING
/// `InventoryService.calculateAvailableToMake` / `deductStockForOrder` /
/// `restoreStockForRefund` read `itemStore` and `recipeRepository` — GetIt/MobX
/// singletons that need a full app harness (the same limitation
/// `inventory_and_cart_test.dart` and `inventory_chain_report_test.dart`
/// already document). So the shared rules those methods depend on are exposed
/// as PURE statics, and the tests below drive *those*:
///
///   - `availableToMakeFrom`      ← what `calculateAvailableToMake` delegates to
///   - `ingredientQuantitiesFor`  ← what the sale, void/refund and production
///                                  paths all call to size each movement
///   - `posStatusFromAvailable`   ← what both menu screens call for status
///   - `effectiveAvailableStock` / `isStockGoverned` ← the POS/cart entry points
///
/// There is exactly one implementation of each; production and tests share it,
/// so nothing here is a re-creation of logic that lives elsewhere.
void main() {
  // ── Fixtures ────────────────────────────────────────────────────────────

  Items makeItem({
    required String id,
    required String name,
    String? productType,
    double stockQuantity = 0,
    bool trackInventory = true,
    bool allowOrderWhenOutOfStock = false,
    bool? sellDirectlyAtPos,
  }) {
    return Items(
      id: id,
      name: name,
      price: 100,
      productType: productType,
      stockQuantity: stockQuantity,
      trackInventory: trackInventory,
      allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
      sellDirectlyAtPos: sellDirectlyAtPos,
    );
  }

  /// The burger from the spec: 1 bun + 1 patty + 1 cheese, yielding 1 burger.
  RecipeModel burgerRecipe({
    double yieldQty = 1,
    double bunQty = 1,
    double pattyQty = 1,
    double cheeseQty = 1,
    double wastagePercent = 0,
    double conversionFactor = 1,
  }) {
    return RecipeModel(
      id: 'recipe-burger',
      itemId: 'burger',
      yieldQty: yieldQty,
      ingredients: [
        RecipeIngredientModel(
          ingredientItemId: 'bun',
          quantity: bunQty,
          wastagePercent: wastagePercent,
          conversionFactor: conversionFactor,
        ),
        RecipeIngredientModel(
          ingredientItemId: 'patty',
          quantity: pattyQty,
          wastagePercent: wastagePercent,
          conversionFactor: conversionFactor,
        ),
        RecipeIngredientModel(
          ingredientItemId: 'cheese',
          quantity: cheeseQty,
          wastagePercent: wastagePercent,
          conversionFactor: conversionFactor,
        ),
      ],
    );
  }

  /// Builds the `Items? Function(String)` lookup `availableToMakeFrom` takes,
  /// standing in for `itemStore.items.firstWhere(...)`.
  Items? Function(String) lookupFrom(List<Items> items) {
    return (id) {
      for (final item in items) {
        if (item.id == id) return item;
      }
      return null;
    };
  }

  List<Items> pantry({
    double bun = 50,
    double patty = 20,
    double cheese = 30,
    bool trackBun = true,
    bool trackPatty = true,
    bool trackCheese = true,
  }) =>
      [
        makeItem(
            id: 'bun',
            name: 'Bun',
            productType: ProductType.rawMaterial,
            stockQuantity: bun,
            trackInventory: trackBun),
        makeItem(
            id: 'patty',
            name: 'Patty',
            productType: ProductType.rawMaterial,
            stockQuantity: patty,
            trackInventory: trackPatty),
        makeItem(
            id: 'cheese',
            name: 'Cheese',
            productType: ProductType.rawMaterial,
            stockQuantity: cheese,
            trackInventory: trackCheese),
      ];

  // ══════════════════════════════════════════════════════════════════════════
  // 1-2. DIRECTLY-STOCKED TYPES ARE UNCHANGED
  //
  // The whole point of routing the POS through effectiveAvailableStock is that
  // it must be a no-op for every type except recipeBased.
  // ══════════════════════════════════════════════════════════════════════════

  group('effectiveAvailableStock leaves directly-stocked types alone', () {
    test('Finished Good reports its stored stockQuantity', () {
      final item = makeItem(
          id: 'coke',
          name: 'Coke',
          productType: ProductType.finishedGood,
          stockQuantity: 12);

      expect(InventoryService.effectiveAvailableStock(item), 12);
    });

    test('an item with no productType at all (legacy row) behaves as Finished Good', () {
      final legacy = makeItem(id: 'old', name: 'Legacy Item', stockQuantity: 7);

      expect(legacy.effectiveProductType, ProductType.finishedGood);
      expect(InventoryService.effectiveAvailableStock(legacy), 7);
    });

    test('Semi-Finished reports its own batch-produced stockQuantity, not its recipe', () {
      // A Semi-Finished item HAS a recipe (it describes how it's made), but at
      // sale time it draws down its own stock like any stocked item.
      final sauce = makeItem(
          id: 'sauce',
          name: 'Burger Sauce',
          productType: ProductType.semiFinished,
          stockQuantity: 4);

      expect(InventoryService.effectiveAvailableStock(sauce), 4);
    });

    test('Raw Material reports its own stockQuantity', () {
      final bun = makeItem(
          id: 'bun',
          name: 'Bun',
          productType: ProductType.rawMaterial,
          stockQuantity: 50);

      expect(InventoryService.effectiveAvailableStock(bun), 50);
    });

    test('isStockGoverned still follows trackInventory for non-recipe types', () {
      for (final type in [
        ProductType.finishedGood,
        ProductType.semiFinished,
        ProductType.rawMaterial,
      ]) {
        expect(
          InventoryService.isStockGoverned(
              makeItem(id: 'x', name: 'X', productType: type, trackInventory: false)),
          isFalse,
          reason: '$type with tracking off must stay ungoverned',
        );
        expect(
          InventoryService.isStockGoverned(
              makeItem(id: 'x', name: 'X', productType: type, trackInventory: true)),
          isTrue,
        );
      }
    });

    test('Recipe-Based is governed even with trackInventory off', () {
      // Its availability comes from ingredients, which carry their own flags —
      // the same branch checkStockAvailability already applied.
      final burger = makeItem(
          id: 'burger',
          name: 'Burger',
          productType: ProductType.recipeBased,
          trackInventory: false);

      expect(InventoryService.isStockGoverned(burger), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3-4. RAW MATERIAL POS VISIBILITY
  // ══════════════════════════════════════════════════════════════════════════

  group('POS visibility (Items.sellsAtPos)', () {
    test('Raw Material is hidden from the POS by default', () {
      final flour =
          makeItem(id: 'flour', name: 'Flour', productType: ProductType.rawMaterial);

      expect(flour.sellDirectlyAtPos, isNull, reason: 'no explicit choice made');
      expect(flour.sellsAtPos, isFalse);
    });

    test('Raw Material can be explicitly opted in', () {
      final cannedDrink = makeItem(
          id: 'can',
          name: 'Canned Drink',
          productType: ProductType.rawMaterial,
          sellDirectlyAtPos: true);

      expect(cannedDrink.sellsAtPos, isTrue);
    });

    test('Finished Good, Semi-Finished and Recipe-Based all sell by default', () {
      for (final type in [
        ProductType.finishedGood,
        ProductType.semiFinished,
        ProductType.recipeBased,
      ]) {
        expect(makeItem(id: 'x', name: 'X', productType: type).sellsAtPos, isTrue,
            reason: '$type must remain sellable');
      }
    });

    test('a legacy item with no productType still sells — no migration needed', () {
      expect(makeItem(id: 'old', name: 'Legacy').sellsAtPos, isTrue);
    });

    test('an explicit false hides even a normally-sellable type', () {
      final hidden = makeItem(
          id: 'prep',
          name: 'Prep Only',
          productType: ProductType.semiFinished,
          sellDirectlyAtPos: false);

      expect(hidden.sellsAtPos, isFalse);
    });

    test('the flag survives a Hive map round-trip', () {
      final opted = makeItem(
          id: 'can',
          name: 'Canned Drink',
          productType: ProductType.rawMaterial,
          sellDirectlyAtPos: true);

      final restored = Items.fromMap(opted.toMap());

      expect(restored.sellDirectlyAtPos, isTrue);
      expect(restored.sellsAtPos, isTrue);
    });

    test('a map with no sellDirectlyAtPos key (pre-upgrade backup) reads as the default', () {
      final map = makeItem(
              id: 'flour', name: 'Flour', productType: ProductType.rawMaterial)
          .toMap()
        ..remove('sellDirectlyAtPos');

      final restored = Items.fromMap(map);

      expect(restored.sellDirectlyAtPos, isNull);
      expect(restored.sellsAtPos, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5-9. AVAILABLE-TO-MAKE MATH
  //
  // This is `availableToMakeFrom`, the single implementation that
  // `calculateAvailableToMake` (and therefore the POS, the Recipes screen and
  // the Production screen) delegates to.
  // ══════════════════════════════════════════════════════════════════════════

  group('availableToMakeFrom', () {
    test('the spec example: bun 50 / patty 20 / cheese 30 → 20 burgers', () {
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry()),
      );

      expect(available, 20);
    });

    test('the scarcest ingredient sets the ceiling, whichever one it is', () {
      // Move the shortage to cheese; the answer must follow it.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(bun: 50, patty: 40, cheese: 3)),
      );

      expect(available, 3);
    });

    test('after selling 1 burger, availability drops to 19', () {
      // Mirrors the worked example in the spec: every ingredient goes down by
      // one, and the patty (still scarcest) governs.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(bun: 49, patty: 19, cheese: 29)),
      );

      expect(available, 19);
    });

    test('per-ingredient quantity > 1 divides correctly', () {
      // A double-patty burger halves what the same patty stock supports.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(pattyQty: 2),
        lookupFrom(pantry(bun: 50, patty: 20, cheese: 30)),
      );

      expect(available, 10);
    });

    test('wastage percent is consumed, reducing what can be made', () {
      // 100% wastage = each burger eats 2 patties, so 20 patties → 10 burgers.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(wastagePercent: 100),
        lookupFrom(pantry(bun: 50, patty: 20, cheese: 30)),
      );

      expect(available, 10);
    });

    test('a realistic 10% wastage floors rather than rounds up', () {
      // 20 patties / 1.1 per burger = 18.18 → 18 whole burgers.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(wastagePercent: 10),
        lookupFrom(pantry(bun: 50, patty: 20, cheese: 30)),
      );

      expect(available, 18);
    });

    test('conversionFactor is applied — a recipe written in grams against kg stock', () {
      // 250 g of an ingredient stocked in kg → 0.25 kg per unit produced.
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'soup',
        ingredients: [
          RecipeIngredientModel(
            ingredientItemId: 'stock-powder',
            quantity: 250,
            unit: 'g',
            conversionFactor: 0.001, // 1 g = 0.001 kg
          ),
        ],
      );
      final items = [
        makeItem(
            id: 'stock-powder',
            name: 'Stock Powder',
            productType: ProductType.rawMaterial,
            stockQuantity: 2), // 2 kg
      ];

      // 2 kg / 0.25 kg = 8 servings.
      expect(InventoryService.availableToMakeFrom(recipe, lookupFrom(items)), 8);
    });

    test('conversionFactor and wastage compound', () {
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'soup',
        ingredients: [
          RecipeIngredientModel(
            ingredientItemId: 'stock-powder',
            quantity: 250,
            unit: 'g',
            conversionFactor: 0.001,
            wastagePercent: 100, // doubles it → 0.5 kg per serving
          ),
        ],
      );
      final items = [
        makeItem(
            id: 'stock-powder',
            name: 'Stock Powder',
            productType: ProductType.rawMaterial,
            stockQuantity: 2),
      ];

      expect(InventoryService.availableToMakeFrom(recipe, lookupFrom(items)), 4);
    });

    test('yieldQty > 1 multiplies the batch count into units', () {
      // One batch consumes 1 of each and yields 10 units; patty (20) is the
      // ceiling at 20 batches → 200 units.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(yieldQty: 10),
        lookupFrom(pantry()),
      );

      expect(available, 200);
    });

    test('zero stock on ANY one ingredient makes the item unavailable', () {
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(bun: 50, patty: 0, cheese: 30)),
      );

      expect(available, 0);
    });

    test('negative stock clamps to 0, never a negative availability', () {
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(bun: 50, patty: -5, cheese: 30)),
      );

      expect(available, 0);
    });

    test('a deleted ingredient makes the item unavailable rather than crashing', () {
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom([
          makeItem(
              id: 'bun',
              name: 'Bun',
              productType: ProductType.rawMaterial,
              stockQuantity: 50),
          // patty and cheese records are gone
        ]),
      );

      expect(available, 0);
    });

    test('an untracked ingredient never limits availability', () {
      // Patty is the scarcest but isn't inventory-tracked, so it's ignored;
      // cheese (30) becomes the ceiling.
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(bun: 50, patty: 1, cheese: 30, trackPatty: false)),
      );

      expect(available, 30);
    });

    test('when NO ingredient is tracked, availability is unbounded', () {
      final available = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(
            trackBun: false, trackPatty: false, trackCheese: false)),
      );

      expect(available, double.infinity);
    });

    test('an empty recipe yields 0, not infinity', () {
      final empty = RecipeModel(id: 'r', itemId: 'burger', ingredients: const []);

      expect(InventoryService.availableToMakeFrom(empty, lookupFrom(pantry())), 0);
    });

    test('a zero-quantity ingredient line is skipped, not divided by', () {
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'burger',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'garnish', quantity: 0),
        ],
      );
      final items = [
        makeItem(
            id: 'bun',
            name: 'Bun',
            productType: ProductType.rawMaterial,
            stockQuantity: 5),
        makeItem(
            id: 'garnish',
            name: 'Garnish',
            productType: ProductType.rawMaterial,
            stockQuantity: 0),
      ];

      expect(InventoryService.availableToMakeFrom(recipe, lookupFrom(items)), 5);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 10-11. WHAT A SALE AND A VOID/REFUND MOVE
  //
  // `ingredientQuantitiesFor` is the shared rule behind
  // `_deductRecipeIngredients`, `_restoreRecipeIngredients` and `produceBatch`
  // — it decides exactly how much of each ingredient every one of those paths
  // writes. Applying it here proves the quantities, and that a sale followed by
  // its own reversal is exactly symmetric.
  // ══════════════════════════════════════════════════════════════════════════

  group('ingredientQuantitiesFor (sale, void/refund and production sizing)', () {
    test('selling 1 burger consumes 1 of each ingredient', () {
      final lines = InventoryService.ingredientQuantitiesFor(burgerRecipe(), 1);

      expect(lines.map((l) => l.ingredientItemId), ['bun', 'patty', 'cheese']);
      expect(lines.map((l) => l.quantity), [1, 1, 1]);
    });

    test('selling 3 burgers scales every ingredient linearly', () {
      final lines = InventoryService.ingredientQuantitiesFor(burgerRecipe(), 3);

      expect(lines.map((l) => l.quantity), [3, 3, 3]);
    });

    test('applying a sale to real stock reproduces the spec walkthrough', () {
      final items = pantry(); // bun 50, patty 20, cheese 30
      final lookup = lookupFrom(items);

      expect(
          InventoryService.availableToMakeFrom(burgerRecipe(), lookup), 20,
          reason: 'before the sale');

      for (final line in InventoryService.ingredientQuantitiesFor(burgerRecipe(), 1)) {
        final ingredient = lookup(line.ingredientItemId)!;
        ingredient.stockQuantity -= line.quantity;
      }

      expect(lookup('bun')!.stockQuantity, 49);
      expect(lookup('patty')!.stockQuantity, 19);
      expect(lookup('cheese')!.stockQuantity, 29);
      expect(InventoryService.availableToMakeFrom(burgerRecipe(), lookup), 19,
          reason: 'after selling one burger');
    });

    test('a void/refund restores exactly what the sale consumed', () {
      final recipe = burgerRecipe(pattyQty: 2, wastagePercent: 10);
      final items = pantry();
      final lookup = lookupFrom(items);
      final before = {for (final i in items) i.id: i.stockQuantity};

      // Sale of 3 …
      for (final line in InventoryService.ingredientQuantitiesFor(recipe, 3)) {
        lookup(line.ingredientItemId)!.stockQuantity -= line.quantity;
      }
      expect(lookup('patty')!.stockQuantity, lessThan(before['patty']!),
          reason: 'the sale must actually move stock');

      // … then the void of the same 3.
      for (final line in InventoryService.ingredientQuantitiesFor(recipe, 3)) {
        lookup(line.ingredientItemId)!.stockQuantity += line.quantity;
      }

      for (final item in items) {
        expect(item.stockQuantity, closeTo(before[item.id]!, 1e-9),
            reason: '${item.name} must return to its pre-sale level');
      }
    });

    test('yieldQty divides the consumption — a 10-unit batch costs one batch of inputs', () {
      final lines =
          InventoryService.ingredientQuantitiesFor(burgerRecipe(yieldQty: 10), 10);

      expect(lines.map((l) => l.quantity), [1, 1, 1]);
    });

    test('the same ingredient listed twice produces two lines, not a merged one', () {
      // Preserves one audit-trail movement row per recipe line.
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'burger',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'patty', quantity: 1),
          RecipeIngredientModel(ingredientItemId: 'patty', quantity: 2),
        ],
      );

      final lines = InventoryService.ingredientQuantitiesFor(recipe, 1);

      expect(lines, hasLength(2));
      expect(lines.map((l) => l.quantity), [1, 2]);
    });

    test('wastage and conversion are folded into the consumed quantity', () {
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'soup',
        ingredients: [
          RecipeIngredientModel(
            ingredientItemId: 'stock-powder',
            quantity: 250,
            conversionFactor: 0.001,
            wastagePercent: 20,
          ),
        ],
      );

      final lines = InventoryService.ingredientQuantitiesFor(recipe, 1);

      // 250 * 0.001 * 1.2 = 0.3 kg
      expect(lines.single.quantity, closeTo(0.3, 1e-9));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 12. allowOrderWhenOutOfStock STILL DECIDES THE BLOCK
  //
  // `posStatusFromAvailable` is what both menu.dart and menu_grid_screen.dart
  // call for a Recipe-Based item's badge, so this is the POS behaviour itself.
  // ══════════════════════════════════════════════════════════════════════════

  group('posStatusFromAvailable', () {
    test('available stock reads as in-stock regardless of the override', () {
      for (final allow in [true, false]) {
        expect(
          InventoryService.posStatusFromAvailable(
              available: 5, allowOrderWhenOutOfStock: allow),
          PosStockStatus.inStock,
        );
      }
    });

    test('zero availability blocks when out-of-stock ordering is off', () {
      expect(
        InventoryService.posStatusFromAvailable(
            available: 0, allowOrderWhenOutOfStock: false),
        PosStockStatus.outOfStock,
      );
    });

    test('zero availability still sells when out-of-stock ordering is on', () {
      expect(
        InventoryService.posStatusFromAvailable(
            available: 0, allowOrderWhenOutOfStock: true),
        PosStockStatus.orderAvailable,
      );
    });

    test('unbounded availability reads as untracked', () {
      expect(
        InventoryService.posStatusFromAvailable(
            available: double.infinity, allowOrderWhenOutOfStock: false),
        PosStockStatus.notTracked,
      );
    });

    test('a burger whose patties ran out is blocked, but sells with the override on', () {
      final soldOut = InventoryService.availableToMakeFrom(
        burgerRecipe(),
        lookupFrom(pantry(bun: 50, patty: 0, cheese: 30)),
      );

      expect(
        InventoryService.posStatusFromAvailable(
            available: soldOut, allowOrderWhenOutOfStock: false),
        PosStockStatus.outOfStock,
      );
      expect(
        InventoryService.posStatusFromAvailable(
            available: soldOut, allowOrderWhenOutOfStock: true),
        PosStockStatus.orderAvailable,
      );
    });
  });
}
