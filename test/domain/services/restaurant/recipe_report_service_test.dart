import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/domain/services/restaurant/recipe_report_service.dart';

/// The Food Cost report replaced per-lookup `firstWhere` scans with an
/// id → item map. These pin that the pure `*From` entry points return exactly
/// what the scan-based originals did, including which duplicate id wins.

// ── Pre-change implementations, verbatim except that `itemStore.items`,
//    `recipeRepository.getRecipeForItem` and `allMovements()` are parameters.

List<RecipeCostReportRow> legacyFoodCostReport(
  List<Items> storeItems,
  RecipeModel? Function(String) getRecipeForItem,
) {
  double costOf(String ingredientItemId) {
    try {
      final ingredient = storeItems.firstWhere((i) => i.id == ingredientItemId);
      return ingredient.lastPurchaseCost ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  final rows = <RecipeCostReportRow>[];
  for (final item in storeItems) {
    final isRecipe = item.isSemiFinished || item.isRecipeBased;
    if (!isRecipe && !item.isFinishedGood) continue;

    if (item.isFinishedGood && item.lastPurchaseCost == null) continue;

    RecipeModel? recipe;
    int ingredientCount = 0;
    double costPerUnit = 0.0;

    if (isRecipe) {
      recipe = getRecipeForItem(item.id);
      if (recipe == null || !recipe.hasIngredients) continue;
      costPerUnit = recipe.estimatedCostPerUnit(costOf);
      ingredientCount = recipe.ingredients.length;
    } else {
      costPerUnit = item.lastPurchaseCost ?? 0.0;
    }

    final sellingPrice = item.price;
    double? foodCostPercent;
    double? marginPercent;
    if (sellingPrice != null && sellingPrice > 0) {
      foodCostPercent = (costPerUnit / sellingPrice) * 100;
      marginPercent = 100 - foodCostPercent;
    }

    rows.add(RecipeCostReportRow(
      item: item,
      recipe: recipe,
      costPerUnit: costPerUnit,
      sellingPrice: sellingPrice,
      foodCostPercent: foodCostPercent,
      marginPercent: marginPercent,
      ingredientCount: ingredientCount,
    ));
  }
  rows.sort((a, b) => a.item.name.compareTo(b.item.name));
  return rows;
}

List<IngredientUsageRow> legacyIngredientUsageReport(
  List<StockMovementModel> allMovements,
  Iterable<Items> Function() storeItems, {
  DateTime? from,
  DateTime? to,
}) {
  final movements = allMovements.where((m) {
    if (m.type != 'out') return false;
    final isRecipeCascade = m.reason.startsWith('Sale (recipe');
    final isProduction = m.reason.startsWith('Production (');
    if (!isRecipeCascade && !isProduction) return false;
    if (from != null && m.timestamp.isBefore(from)) return false;
    if (to != null && m.timestamp.isAfter(to)) return false;
    return true;
  });

  final byItem = <String, IngredientUsageRow>{};
  for (final m in movements) {
    double costPerUnit = m.unitCost ?? 0.0;
    if (m.unitCost == null) {
      try {
        costPerUnit = storeItems().firstWhere((i) => i.id == m.itemId).lastPurchaseCost ?? 0.0;
      } catch (_) {}
    }

    final existing = byItem[m.itemId];
    if (existing == null) {
      byItem[m.itemId] = IngredientUsageRow(
        itemId: m.itemId,
        itemName: m.itemName,
        unit: m.unit,
        consumedQty: m.quantity,
        estimatedCost: m.quantity * costPerUnit,
        movementCount: 1,
      );
    } else {
      byItem[m.itemId] = IngredientUsageRow(
        itemId: existing.itemId,
        itemName: existing.itemName,
        unit: existing.unit,
        consumedQty: existing.consumedQty + m.quantity,
        estimatedCost: existing.estimatedCost + (m.quantity * costPerUnit),
        movementCount: existing.movementCount + 1,
      );
    }
  }

  final rows = byItem.values.toList()
    ..sort((a, b) => b.consumedQty.compareTo(a.consumedQty));
  return rows;
}

List<WastageRow> legacyWastageReport(
  List<StockMovementModel> allMovements,
  Iterable<Items> Function() storeItems, {
  DateTime? from,
  DateTime? to,
}) {
  final movements = allMovements.where((m) {
    if (m.type != 'out') return false;
    if (m.reason != 'Wastage / Spoilage') return false;
    if (from != null && m.timestamp.isBefore(from)) return false;
    if (to != null && m.timestamp.isAfter(to)) return false;
    return true;
  });

  final byItem = <String, WastageRow>{};
  for (final m in movements) {
    double costPerUnit = m.unitCost ?? 0.0;
    if (m.unitCost == null) {
      try {
        costPerUnit = storeItems().firstWhere((i) => i.id == m.itemId).lastPurchaseCost ?? 0.0;
      } catch (_) {}
    }

    final existing = byItem[m.itemId];
    if (existing == null) {
      byItem[m.itemId] = WastageRow(
        itemId: m.itemId,
        itemName: m.itemName,
        unit: m.unit,
        wastedQty: m.quantity,
        estimatedCost: m.quantity * costPerUnit,
        movementCount: 1,
      );
    } else {
      byItem[m.itemId] = WastageRow(
        itemId: existing.itemId,
        itemName: existing.itemName,
        unit: existing.unit,
        wastedQty: existing.wastedQty + m.quantity,
        estimatedCost: existing.estimatedCost + (m.quantity * costPerUnit),
        movementCount: existing.movementCount + 1,
      );
    }
  }

  final rows = byItem.values.toList()
    ..sort((a, b) => b.wastedQty.compareTo(a.wastedQty));
  return rows;
}

// ── Snapshots (exact doubles, identity for the item/recipe) ─────────────────

List<Object?> foodSnap(List<RecipeCostReportRow> rows) => [
      for (final r in rows)
        [
          identityHashCode(r.item),
          r.recipe == null ? null : identityHashCode(r.recipe),
          r.costPerUnit,
          r.sellingPrice,
          r.foodCostPercent,
          r.marginPercent,
          r.ingredientCount,
        ],
    ];

List<Object?> usageSnap(List<IngredientUsageRow> rows) => [
      for (final r in rows)
        [r.itemId, r.itemName, r.unit, r.consumedQty, r.estimatedCost, r.movementCount],
    ];

List<Object?> wasteSnap(List<WastageRow> rows) => [
      for (final r in rows)
        [r.itemId, r.itemName, r.unit, r.wastedQty, r.estimatedCost, r.movementCount],
    ];

// ── Fixtures ────────────────────────────────────────────────────────────────

Items item(String id, String type, {double? cost, double? price, String? name}) => Items(
      id: id,
      name: name ?? id,
      productType: type,
      unit: 'kg',
      lastPurchaseCost: cost,
      price: price,
    );

int _mv = 0;
StockMovementModel movement(
  String itemId,
  DateTime at, {
  double qty = 1,
  double? unitCost,
  String reason = 'Sale (recipe: Burger)',
  String type = 'out',
}) =>
    StockMovementModel(
      id: 'm${_mv++}',
      timestamp: at,
      itemId: itemId,
      itemName: 'Name $itemId',
      type: type,
      quantity: qty,
      balanceAfter: 0,
      reason: reason,
      unit: 'kg',
      staffName: 'staff',
      unitCost: unitCost,
    );

void main() {
  group('foodCostReportFrom', () {
    test('normal recipe cost, food cost % and margin %', () {
      final potato = item('rm-potato', ProductType.rawMaterial, cost: 50);
      final vada = item('sf-vada', ProductType.semiFinished, price: 20, name: 'Vada');
      final recipe = RecipeModel(
        id: 'r-vada',
        itemId: 'sf-vada',
        yieldQty: 10,
        ingredients: [RecipeIngredientModel(ingredientItemId: 'rm-potato', quantity: 1)],
      );
      final items = [potato, vada];
      RecipeModel? lookup(String id) => id == 'sf-vada' ? recipe : null;

      final rows = RecipeReportService.foodCostReportFrom(items: items, recipeForItem: lookup);
      expect(foodSnap(rows), foodSnap(legacyFoodCostReport(items, lookup)));
      expect(rows, hasLength(1));
      expect(rows.single.costPerUnit, 5.0);
      expect(rows.single.foodCostPercent, 25.0);
      expect(rows.single.marginPercent, 75.0);
      expect(rows.single.ingredientCount, 1);
    });

    test('duplicate ingredient id: the FIRST item wins', () {
      final first = item('rm-dup', ProductType.rawMaterial, cost: 10);
      final second = item('rm-dup', ProductType.rawMaterial, cost: 999);
      final dish = item('rb-dish', ProductType.recipeBased, price: 100);
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'rb-dish',
        ingredients: [RecipeIngredientModel(ingredientItemId: 'rm-dup', quantity: 2)],
      );
      final items = [first, dish, second];
      RecipeModel? lookup(String id) => id == 'rb-dish' ? recipe : null;

      final rows = RecipeReportService.foodCostReportFrom(items: items, recipeForItem: lookup);
      expect(foodSnap(rows), foodSnap(legacyFoodCostReport(items, lookup)));
      expect(rows.single.costPerUnit, 20.0); // 2 × first item's ₹10, not ₹999
    });

    test('missing ingredient costs 0.0; finished good without cost is skipped', () {
      final dish = item('rb-dish', ProductType.recipeBased, price: 50);
      final bottled = item('fg-water', ProductType.finishedGood, price: 20);
      final costed = item('fg-soda', ProductType.finishedGood, cost: 8, price: 20);
      final recipe = RecipeModel(
        id: 'r',
        itemId: 'rb-dish',
        ingredients: [
          RecipeIngredientModel(ingredientItemId: 'does-not-exist', quantity: 3),
        ],
      );
      final items = [dish, bottled, costed];
      RecipeModel? lookup(String id) => id == 'rb-dish' ? recipe : null;

      final rows = RecipeReportService.foodCostReportFrom(items: items, recipeForItem: lookup);
      expect(foodSnap(rows), foodSnap(legacyFoodCostReport(items, lookup)));
      expect(rows.map((r) => r.item.id), ['fg-soda', 'rb-dish']);
      expect(rows.last.costPerUnit, 0.0);
    });

    test('large mixed catalogue matches the legacy implementation', () {
      final rnd = Random(11);
      const types = [
        ProductType.rawMaterial,
        ProductType.semiFinished,
        ProductType.recipeBased,
        ProductType.finishedGood,
        'legacyNull',
      ];
      final items = <Items>[];
      for (var i = 0; i < 120; i++) {
        final t = types[rnd.nextInt(types.length)];
        items.add(Items(
          id: 'it-${rnd.nextInt(90)}', // duplicates on purpose
          name: 'Name ${rnd.nextInt(30)}', // name ties on purpose
          productType: t == 'legacyNull' ? null : t,
          lastPurchaseCost: rnd.nextInt(4) == 0 ? null : rnd.nextInt(5000) / 7,
          price: rnd.nextInt(5) == 0 ? null : (rnd.nextInt(3) == 0 ? 0.0 : rnd.nextInt(9000) / 3),
        ));
      }
      final recipes = <String, RecipeModel>{};
      for (final it in items) {
        if (rnd.nextInt(4) == 0) continue;
        recipes.putIfAbsent(
          it.id,
          () => RecipeModel(
            id: 'r-${it.id}',
            itemId: it.id,
            yieldQty: rnd.nextInt(5) == 0 ? 0.0 : (1 + rnd.nextInt(6)).toDouble(),
            ingredients: [
              for (var j = 0; j < rnd.nextInt(4); j++)
                RecipeIngredientModel(
                  ingredientItemId: 'it-${rnd.nextInt(100)}',
                  quantity: rnd.nextInt(400) / 13,
                  wastagePercent: rnd.nextInt(3) * 5.0,
                ),
            ],
          ),
        );
      }
      RecipeModel? lookup(String id) => recipes[id];

      final actual = RecipeReportService.foodCostReportFrom(items: items, recipeForItem: lookup);
      expect(foodSnap(actual), foodSnap(legacyFoodCostReport(items, lookup)));
      expect(actual.length, greaterThan(32));
    });
  });

  group('ingredientUsageReportFrom / wastageReportFrom', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 10, 23, 59, 59);

    test('null legacy unitCost uses the item cost; missing item stays 0.0; 0.0 unitCost is kept', () {
      final items = [
        item('rm-a', ProductType.rawMaterial, cost: 40),
        item('rm-a', ProductType.rawMaterial, cost: 400), // duplicate — first wins
      ];
      final at = DateTime(2026, 9, 5);
      final movements = [
        movement('rm-a', at, qty: 2), // legacy → item cost 40
        movement('rm-a', at, qty: 1, unitCost: 0.0), // recorded zero, not a fallback
        movement('rm-a', at, qty: 1, unitCost: 12.5),
        movement('rm-ghost', at, qty: 3), // legacy, item gone → 0.0
      ];

      final usage = RecipeReportService.ingredientUsageReportFrom(movements: movements, items: () => items);
      expect(usageSnap(usage), usageSnap(legacyIngredientUsageReport(movements, () => items)));
      final byId = {for (final r in usage) r.itemId: r};
      expect(byId['rm-a']!.estimatedCost, 2 * 40 + 0.0 + 12.5);
      expect(byId['rm-ghost']!.estimatedCost, 0.0);

      final wasteMovements = [
        for (final m in movements)
          movement(m.itemId, m.timestamp, qty: m.quantity, unitCost: m.unitCost, reason: 'Wastage / Spoilage'),
      ];
      final waste = RecipeReportService.wastageReportFrom(movements: wasteMovements, items: () => items);
      expect(wasteSnap(waste), wasteSnap(legacyWastageReport(wasteMovements, () => items)));
      expect({for (final r in waste) r.itemId: r.estimatedCost}, {'rm-a': 92.5, 'rm-ghost': 0.0});
    });

    test('item list is not read when every movement carries unitCost', () {
      final movements = [movement('rm-a', DateTime(2026, 9, 5), qty: 2, unitCost: 3)];
      Iterable<Items> unreachable() => throw StateError('ItemStore not registered');

      final usage = RecipeReportService.ingredientUsageReportFrom(movements: movements, items: unreachable);
      expect(usageSnap(usage), usageSnap(legacyIngredientUsageReport(movements, unreachable)));
      expect(usage.single.estimatedCost, 6.0);

      final waste = [movement('rm-a', DateTime(2026, 9, 5), qty: 2, unitCost: 3, reason: 'Wastage / Spoilage')];
      expect(wasteSnap(RecipeReportService.wastageReportFrom(movements: waste, items: unreachable)),
          wasteSnap(legacyWastageReport(waste, unreachable)));
    });

    test('an unreadable item list prices legacy movements at 0.0, as the old catch did', () {
      final at = DateTime(2026, 9, 5);
      final movements = [
        movement('rm-a', at, qty: 2),
        movement('rm-a', at, qty: 1, unitCost: 4),
      ];
      Iterable<Items> broken() => throw StateError('ItemStore not registered');

      final usage = RecipeReportService.ingredientUsageReportFrom(movements: movements, items: broken);
      expect(usageSnap(usage), usageSnap(legacyIngredientUsageReport(movements, broken)));
      expect(usage.single.estimatedCost, 4.0);

      final waste = [
        for (final m in movements)
          movement(m.itemId, m.timestamp, qty: m.quantity, unitCost: m.unitCost, reason: 'Wastage / Spoilage'),
      ];
      expect(wasteSnap(RecipeReportService.wastageReportFrom(movements: waste, items: broken)),
          wasteSnap(legacyWastageReport(waste, broken)));
    });

    test('from and to are both inclusive', () {
      final items = [item('rm-a', ProductType.rawMaterial, cost: 1)];
      final movements = [
        movement('rm-a', from.subtract(const Duration(microseconds: 1)), qty: 1000),
        movement('rm-a', from, qty: 1),
        movement('rm-a', to, qty: 10),
        movement('rm-a', to.add(const Duration(microseconds: 1)), qty: 5000),
      ];
      final usage = RecipeReportService.ingredientUsageReportFrom(
          movements: movements, items: () => items, from: from, to: to);
      expect(usageSnap(usage),
          usageSnap(legacyIngredientUsageReport(movements, () => items, from: from, to: to)));
      expect(usage.single.consumedQty, 11);
      expect(usage.single.movementCount, 2);

      final waste = [
        for (final m in movements)
          movement(m.itemId, m.timestamp, qty: m.quantity, reason: 'Wastage / Spoilage'),
      ];
      final wasted = RecipeReportService.wastageReportFrom(movements: waste, items: () => items, from: from, to: to);
      expect(wasteSnap(wasted), wasteSnap(legacyWastageReport(waste, () => items, from: from, to: to)));
      expect(wasted.single.wastedQty, 11);
    });

    test('reason and type filters', () {
      final items = [item('rm-a', ProductType.rawMaterial, cost: 2)];
      final at = DateTime(2026, 9, 5);
      final movements = [
        movement('rm-a', at, reason: 'Sale (recipe: Pizza)'),
        movement('rm-a', at, reason: 'Production (Dough)'),
        movement('rm-a', at, reason: 'Wastage / Spoilage'),
        movement('rm-a', at, reason: 'Sale (recipe: Pizza)', type: 'in'),
        movement('rm-a', at, reason: 'GRN received'),
      ];
      final usage = RecipeReportService.ingredientUsageReportFrom(movements: movements, items: () => items);
      expect(usageSnap(usage), usageSnap(legacyIngredientUsageReport(movements, () => items)));
      expect(usage.single.movementCount, 2);

      final waste = RecipeReportService.wastageReportFrom(movements: movements, items: () => items);
      expect(wasteSnap(waste), wasteSnap(legacyWastageReport(movements, () => items)));
      expect(waste.single.movementCount, 1);
    });

    test('large mixed movement history matches the legacy implementation', () {
      final rnd = Random(5);
      final items = [
        for (var i = 0; i < 80; i++)
          item('it-${rnd.nextInt(60)}', ProductType.rawMaterial,
              cost: rnd.nextInt(4) == 0 ? null : rnd.nextInt(900) / 9),
      ];
      const reasons = [
        'Sale (recipe: A)',
        'Production (B)',
        'Wastage / Spoilage',
        'Manual adjustment',
      ];
      final base = DateTime(2026, 7, 1);
      final movements = [
        for (var i = 0; i < 2000; i++)
          movement(
            'it-${rnd.nextInt(75)}',
            base.add(Duration(minutes: rnd.nextInt(90 * 24 * 60))),
            qty: rnd.nextInt(700) / 11,
            unitCost: rnd.nextInt(2) == 0 ? null : rnd.nextInt(500) / 3,
            reason: reasons[rnd.nextInt(reasons.length)],
            type: rnd.nextInt(6) == 0 ? 'in' : 'out',
          ),
      ];
      final ranges = <(DateTime?, DateTime?)>[
        (null, null),
        (DateTime(2026, 8, 1), null),
        (null, DateTime(2026, 8, 15, 23, 59, 59)),
        (DateTime(2026, 7, 20), DateTime(2026, 9, 2, 23, 59, 59)),
      ];
      for (final (f, t) in ranges) {
        expect(
          usageSnap(RecipeReportService.ingredientUsageReportFrom(
              movements: movements, items: () => items, from: f, to: t)),
          usageSnap(legacyIngredientUsageReport(movements, () => items, from: f, to: t)),
          reason: 'usage $f..$t',
        );
        expect(
          wasteSnap(RecipeReportService.wastageReportFrom(
              movements: movements, items: () => items, from: f, to: t)),
          wasteSnap(legacyWastageReport(movements, () => items, from: f, to: t)),
          reason: 'wastage $f..$t',
        );
      }
    });
  });
}
