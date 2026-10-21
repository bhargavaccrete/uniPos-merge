import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';

/// A1 + A2 — RECIPE-AWARE STOCK STATUS OUTSIDE THE POS
///
/// Phase 1 taught the POS to read Recipe-Based availability from ingredients.
/// Two surfaces were left reading the stored `stockQuantity` and therefore
/// reported a Burger as out of stock however full the pantry was:
///
///   A1  `manage_Inventory.dart` — Stock Levels list, badge, low/out counters
///   A2  `StockAdjustService.lowStockEntries()` — the Low Stock screen
///
/// Both now go through `InventoryService.isInStock` / `.isLowStock`, the same
/// recipe-aware pair, which delegate straight to the `Items` getters for every
/// non-recipe type so their behaviour is bit-for-bit unchanged.
///
/// `effectiveAvailableStock` resolves recipes through `recipeRepository` and
/// `itemStore` (GetIt), so these tests pass the availability in via the
/// predicates' `available:` override — the same single implementation
/// production runs, just with the lookup supplied rather than resolved.
void main() {
  Items makeItem({
    String id = 'item-1',
    String name = 'Item',
    String? productType,
    double stockQuantity = 0,
    bool trackInventory = true,
    bool lowStockAlertEnabled = true,
    double? lowStockThreshold,
  }) {
    return Items(
      id: id,
      name: name,
      price: 100,
      productType: productType,
      stockQuantity: stockQuantity,
      trackInventory: trackInventory,
      lowStockAlertEnabled: lowStockAlertEnabled,
      lowStockThreshold: lowStockThreshold,
    );
  }

  Items burger({double? threshold}) => makeItem(
        id: 'burger',
        name: 'Burger',
        productType: ProductType.recipeBased,
        // Deliberately 0 — a Recipe-Based item never populates this field.
        stockQuantity: 0,
        lowStockThreshold: threshold,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // 1. A STOCKED PANTRY IS NOT "OUT OF STOCK"
  // ══════════════════════════════════════════════════════════════════════════

  group('Recipe-Based with ingredients available', () {
    test('is NOT reported out of stock — the original A1/A2 defect', () {
      final item = burger();

      // What the old code did: read the stored field.
      expect(item.isInStock, isFalse,
          reason: 'the raw model getter is exactly what was wrong');

      // What every screen now does.
      expect(InventoryService.isInStock(item, available: 20), isTrue);
    });

    test('is not low stock when availability is comfortably above threshold', () {
      final item = burger(threshold: 5);

      expect(InventoryService.isLowStock(item, available: 20), isFalse);
      expect(InventoryService.isInStock(item, available: 20), isTrue);
    });

    test('unconstrained availability (no tracked ingredients) is in stock, never low',
        () {
      final item = burger(threshold: 5);

      expect(InventoryService.isInStock(item, available: double.infinity), isTrue);
      expect(InventoryService.isLowStock(item, available: double.infinity), isFalse);
    });

    test('a Recipe-Based item is stock-governed even with tracking off', () {
      // Its ingredients carry their own flags — the rule the POS applies.
      final item = makeItem(
        id: 'burger',
        productType: ProductType.recipeBased,
        trackInventory: false,
      );

      expect(InventoryService.isStockGoverned(item), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. SHORT INGREDIENTS MAKE IT LOW / OUT
  // ══════════════════════════════════════════════════════════════════════════

  group('Recipe-Based with insufficient ingredients', () {
    test('becomes out of stock when nothing can be made', () {
      final item = burger();

      expect(InventoryService.isInStock(item, available: 0), isFalse);
    });

    test('becomes low stock at the threshold boundary', () {
      final item = burger(threshold: 5);

      expect(InventoryService.isLowStock(item, available: 5), isTrue,
          reason: 'at the threshold counts as low');
      expect(InventoryService.isLowStock(item, available: 6), isFalse);
    });

    test('below the threshold is low stock but still in stock', () {
      final item = burger(threshold: 5);

      expect(InventoryService.isLowStock(item, available: 2), isTrue);
      expect(InventoryService.isInStock(item, available: 2), isTrue);
    });

    test('zero availability is out of stock, not low stock', () {
      final item = burger(threshold: 5);

      expect(InventoryService.isInStock(item, available: 0), isFalse);
      expect(InventoryService.isLowStock(item, available: 0), isFalse,
          reason: 'out of stock supersedes low stock, as the badge does');
    });

    test('low-stock still respects the per-item opt-out', () {
      final item = makeItem(
        id: 'burger',
        productType: ProductType.recipeBased,
        lowStockAlertEnabled: false,
        lowStockThreshold: 5,
      );

      expect(InventoryService.isLowStock(item, available: 1), isFalse);
      expect(InventoryService.isInStock(item, available: 1), isTrue,
          reason: 'opting out of alerts must not hide real availability');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3-5. EVERY OTHER PRODUCT TYPE IS UNTOUCHED
  //
  // For non-recipe types the predicates delegate to the model getters, so these
  // assert the delegation as well as the behaviour.
  // ══════════════════════════════════════════════════════════════════════════

  group('directly-stocked types still read stockQuantity', () {
    for (final (label, type) in [
      ('Finished Good', ProductType.finishedGood),
      ('Semi-Finished', ProductType.semiFinished),
      ('Raw Material', ProductType.rawMaterial),
    ]) {
      test('$label in stock when the stored quantity is positive', () {
        final item = makeItem(productType: type, stockQuantity: 12);

        expect(InventoryService.isInStock(item), isTrue);
        expect(InventoryService.isInStock(item), item.isInStock,
            reason: 'must delegate to the model getter unchanged');
      });

      test('$label out of stock when the stored quantity is zero', () {
        final item = makeItem(productType: type, stockQuantity: 0);

        expect(InventoryService.isInStock(item), isFalse);
        expect(InventoryService.isInStock(item), item.isInStock);
      });

      test('$label low stock follows the stored quantity, not any recipe', () {
        final low = makeItem(
            productType: type, stockQuantity: 3, lowStockThreshold: 5);
        final healthy = makeItem(
            productType: type, stockQuantity: 50, lowStockThreshold: 5);

        expect(InventoryService.isLowStock(low), isTrue);
        expect(InventoryService.isLowStock(low), low.isLowStock);
        expect(InventoryService.isLowStock(healthy), isFalse);
        expect(InventoryService.isLowStock(healthy), healthy.isLowStock);
      });

      test('$label ignores an availability override entirely', () {
        // The override is a recipe-path concern; it must not leak into the
        // stored-stock path, or a caller could accidentally rewrite reality.
        final item = makeItem(productType: type, stockQuantity: 0);

        expect(InventoryService.isInStock(item, available: 999), isFalse,
            reason: '$label must still read its own stockQuantity');
      });

      test('$label with tracking off is not stock-governed', () {
        final item = makeItem(productType: type, trackInventory: false);

        expect(InventoryService.isStockGoverned(item), isFalse);
      });
    }

    test('a legacy item with no productType behaves as Finished Good', () {
      final item = makeItem(stockQuantity: 8);

      expect(item.effectiveProductType, ProductType.finishedGood);
      expect(InventoryService.isInStock(item), isTrue);
      expect(InventoryService.isInStock(item), item.isInStock);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. THE POS AND THE INVENTORY SCREEN AGREE
  //
  // Both read `effectiveAvailableStock`, which for Recipe-Based items resolves
  // through `availableToMakeFrom` — the one implementation. Driving that
  // function directly proves the figure both surfaces receive is the same one.
  // ══════════════════════════════════════════════════════════════════════════

  group('POS and Inventory report the same availability', () {
    Items ingredient(String id, double qty, {bool track = true}) => makeItem(
          id: id,
          name: id,
          productType: ProductType.rawMaterial,
          stockQuantity: qty,
          trackInventory: track,
        );

    RecipeModel recipe() => RecipeModel(
          id: 'r',
          itemId: 'burger',
          ingredients: [
            RecipeIngredientModel(ingredientItemId: 'bun', quantity: 1),
            RecipeIngredientModel(ingredientItemId: 'patty', quantity: 1),
            RecipeIngredientModel(ingredientItemId: 'cheese', quantity: 1),
          ],
        );

    Items? Function(String) lookup(List<Items> items) => (id) {
          for (final i in items) {
            if (i.id == id) return i;
          }
          return null;
        };

    test('the spec pantry yields 20, and both surfaces call it in stock', () {
      final pantry = [
        ingredient('bun', 50),
        ingredient('patty', 20),
        ingredient('cheese', 30),
      ];

      final available =
          InventoryService.availableToMakeFrom(recipe(), lookup(pantry));
      expect(available, 20);

      final item = burger(threshold: 5);

      // Inventory Stock Levels (A1) — badge + counters.
      expect(InventoryService.isInStock(item, available: available), isTrue);
      expect(InventoryService.isLowStock(item, available: available), isFalse);

      // POS (Phase 1) — same figure, same verdict.
      expect(
        InventoryService.posStatusFromAvailable(
          available: available,
          allowOrderWhenOutOfStock: false,
        ),
        PosStockStatus.inStock,
      );
    });

    test('an exhausted ingredient reads out of stock on BOTH surfaces', () {
      final pantry = [
        ingredient('bun', 50),
        ingredient('patty', 0),
        ingredient('cheese', 30),
      ];

      final available =
          InventoryService.availableToMakeFrom(recipe(), lookup(pantry));
      expect(available, 0);

      final item = burger();

      expect(InventoryService.isInStock(item, available: available), isFalse);
      expect(
        InventoryService.posStatusFromAvailable(
          available: available,
          allowOrderWhenOutOfStock: false,
        ),
        PosStockStatus.outOfStock,
      );
    });

    test('a dwindling pantry reads low on BOTH surfaces', () {
      final pantry = [
        ingredient('bun', 50),
        ingredient('patty', 3),
        ingredient('cheese', 30),
      ];

      final available =
          InventoryService.availableToMakeFrom(recipe(), lookup(pantry));
      expect(available, 3);

      final item = burger(threshold: 5);

      // Inventory: flagged low but still sellable.
      expect(InventoryService.isLowStock(item, available: available), isTrue);
      expect(InventoryService.isInStock(item, available: available), isTrue);

      // POS: still in stock — it has no separate "low" state, and 3 > 0.
      expect(
        InventoryService.posStatusFromAvailable(
          available: available,
          allowOrderWhenOutOfStock: false,
        ),
        PosStockStatus.inStock,
      );
    });

    test('effectiveAvailableStock is a pass-through for non-recipe types', () {
      // Which is what guarantees the two surfaces agree for them too: they
      // both end up reading the same stored figure.
      for (final type in [
        ProductType.finishedGood,
        ProductType.semiFinished,
        ProductType.rawMaterial,
      ]) {
        final item = makeItem(productType: type, stockQuantity: 17);
        expect(InventoryService.effectiveAvailableStock(item), 17);
      }
    });
  });
}
