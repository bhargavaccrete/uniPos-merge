import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/domain/services/restaurant/recipe_report_service.dart';

/// Usage/wastage: the pure `*From` entry points return exactly what the
/// scan-based originals did, including which duplicate id wins. Food cost:
/// the Phase 1.8 per-type cost rules.

// ── Pre-change implementations, verbatim except that `itemStore.items` and
//    `allMovements()` are parameters.

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
  // Phase 1.8 — cost by product type; a missing cost is unknown, never ₹0.
  group('foodCostReportFrom', () {
    final bun = item('rm-bun', ProductType.rawMaterial, cost: 10);
    final cheese = item('rm-cheese', ProductType.rawMaterial, cost: 400);
    RecipeModel recipeFor(String itemId,
            {double yieldQty = 1,
            List<RecipeIngredientModel>? lines}) =>
        RecipeModel(
          id: 'r-$itemId',
          itemId: itemId,
          yieldQty: yieldQty,
          ingredients: lines ??
              [
                RecipeIngredientModel(ingredientItemId: 'rm-bun', quantity: 1),
                RecipeIngredientModel(
                    ingredientItemId: 'rm-cheese', quantity: 0.05),
              ],
        ); // ₹10 + ₹20 = ₹30 per batch
    Items finished(String id, String prep, {double? cost, double? price}) =>
        Items(
          id: id,
          name: id,
          productType: ProductType.finishedGood,
          prepMode: prep,
          lastPurchaseCost: cost,
          price: price,
        );

    List<RecipeCostReportRow> report(List<Items> items,
            [Map<String, RecipeModel> recipes = const {}]) =>
        RecipeReportService.foodCostReportFrom(
            items: [bun, cheese, ...items], recipeForItem: (id) => recipes[id]);
    RecipeCostReportRow rowOf(List<RecipeCostReportRow> rows, String id) =>
        rows.singleWhere((r) => r.item.id == id);

    test('made-to-order Finished with a recipe: recipe cost', () {
      final burger = finished('burger', ProductType.madeToOrder, price: 150);
      final row = rowOf(report([burger], {'burger': recipeFor('burger')}),
          'burger');
      expect(row.costPerUnit, 30);
      expect(row.costSource, FoodCostSource.recipe);
      expect(row.foodCostPercent, 20);
      expect(row.marginPercent, 80);
      expect(row.ingredientCount, 2);
    });

    test('made-in-advance Finished with a recipe: recipe cost, not its last '
        'cost', () {
      final sandwich = finished('sandwich', ProductType.madeInAdvance,
          cost: 99, price: 100);
      final row = rowOf(
          report([sandwich], {'sandwich': recipeFor('sandwich')}), 'sandwich');
      expect(row.costPerUnit, 30);
      expect(row.costSource, FoodCostSource.recipe);
    });

    test('made-in-advance Finished without a recipe: latest production or '
        'purchase cost', () {
      final cake =
          finished('cake', ProductType.madeInAdvance, cost: 12, price: 48);
      final row = rowOf(report([cake]), 'cake');
      expect(row.costPerUnit, 12);
      expect(row.costSource, FoodCostSource.lastCost);
      expect(row.foodCostPercent, 25);
    });

    test('legacy Finished (no type stored) without a recipe: same rule', () {
      final legacy = item('legacy', 'unused', cost: 5, price: 10)
        ..productType = null;
      expect(rowOf(report([legacy]), 'legacy').costPerUnit, 5);
    });

    test('made-in-advance Finished without a recipe or cost: shown as '
        'unknown, not ₹0', () {
      final cake = finished('cake', ProductType.madeInAdvance, price: 48);
      final row = rowOf(report([cake]), 'cake');
      expect(row.costPerUnit, isNull);
      expect(row.costSource, FoodCostSource.none);
      expect(row.foodCostPercent, isNull);
      expect(row.marginPercent, isNull);
    });

    test('made-to-order Finished without a recipe: unknown', () {
      final tea = finished('tea', ProductType.madeToOrder, cost: 3, price: 20);
      final row = rowOf(report([tea]), 'tea');
      expect(row.costPerUnit, isNull);
      expect(row.costSource, FoodCostSource.none);
    });

    test('Trade Item: latest purchase cost', () {
      final coke = item('coke', ProductType.tradeItem, cost: 30, price: 60);
      final row = rowOf(report([coke]), 'coke');
      expect(row.costPerUnit, 30);
      expect(row.costSource, FoodCostSource.purchase);
      expect(row.foodCostPercent, 50);
    });

    test('Trade Item never bought: unknown', () {
      final coke = item('coke', ProductType.tradeItem, price: 60);
      final row = rowOf(report([coke]), 'coke');
      expect(row.costPerUnit, isNull);
      expect(row.costSource, FoodCostSource.none);
    });

    test('Semi-Finished: latest production or purchase cost wins over the '
        'recipe estimate', () {
      final dough = item('dough', ProductType.semiFinished, cost: 4);
      final row =
          rowOf(report([dough], {'dough': recipeFor('dough')}), 'dough');
      expect(row.costPerUnit, 4);
      expect(row.costSource, FoodCostSource.lastCost);
      expect(row.recipe, isNotNull);
    });

    test('Semi-Finished never produced or bought: falls back to the recipe '
        'estimate', () {
      final dough = item('dough', ProductType.semiFinished);
      final row = rowOf(
          report([dough], {'dough': recipeFor('dough', yieldQty: 10)}),
          'dough');
      expect(row.costPerUnit, 3);
      expect(row.costSource, FoodCostSource.recipe);
    });

    test('Semi-Finished with no cost and no recipe: unknown', () {
      final dough = item('dough', ProductType.semiFinished);
      final row = rowOf(report([dough]), 'dough');
      expect(row.costPerUnit, isNull);
      expect(row.costSource, FoodCostSource.none);
    });

    test('an ingredient without a cost makes the recipe cost unknown', () {
      final salt = item('rm-salt', ProductType.rawMaterial);
      final burger = finished('burger', ProductType.madeToOrder, price: 150);
      final recipe = recipeFor('burger', lines: [
        RecipeIngredientModel(ingredientItemId: 'rm-bun', quantity: 1),
        RecipeIngredientModel(ingredientItemId: 'rm-salt', quantity: 0.01),
      ]);
      final row = rowOf(report([salt, burger], {'burger': recipe}), 'burger');
      expect(row.costPerUnit, isNull);
      expect(row.missingCostIngredients, 1);
      expect(row.costSource, FoodCostSource.recipe);
      expect(row.foodCostPercent, isNull);
    });

    test('a deleted ingredient makes the recipe cost unknown', () {
      final burger = finished('burger', ProductType.madeToOrder, price: 150);
      final recipe = recipeFor('burger', lines: [
        RecipeIngredientModel(ingredientItemId: 'gone', quantity: 3),
      ]);
      final row = rowOf(report([burger], {'burger': recipe}), 'burger');
      expect(row.costPerUnit, isNull);
      expect(row.missingCostIngredients, 1);
    });

    test('an ingredient recorded at ₹0 is a known cost', () {
      final water = item('rm-water', ProductType.rawMaterial, cost: 0);
      final tea = finished('tea', ProductType.madeToOrder, price: 20);
      final recipe = recipeFor('tea', lines: [
        RecipeIngredientModel(ingredientItemId: 'rm-water', quantity: 1),
      ]);
      final row = rowOf(report([water, tea], {'tea': recipe}), 'tea');
      expect(row.costPerUnit, 0);
      expect(row.missingCostIngredients, 0);
      expect(row.foodCostPercent, 0);
    });

    test('a recipe with no yield is unknown, not ₹0', () {
      final burger = finished('burger', ProductType.madeToOrder, price: 150);
      final row = rowOf(
          report([burger], {'burger': recipeFor('burger', yieldQty: 0)}),
          'burger');
      expect(row.costPerUnit, isNull);
    });

    test('Raw Materials are never rows', () {
      expect(report([]), isEmpty);
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
      final rows = RecipeReportService.foodCostReportFrom(
          items: [first, dish, second],
          recipeForItem: (id) => id == 'rb-dish' ? recipe : null);
      expect(rows.single.costPerUnit, 20.0); // 2 × first item's ₹10, not ₹999
    });

    test('known costs first, then unknown, each by name', () {
      final rows = report([
        item('z-coke', ProductType.tradeItem, cost: 30, name: 'Zed'),
        item('a-cola', ProductType.tradeItem, name: 'Ace'),
        item('m-soda', ProductType.tradeItem, cost: 8, name: 'Mid'),
        item('b-pop', ProductType.tradeItem, name: 'Bee'),
      ]);
      expect(rows.map((r) => r.item.name), ['Mid', 'Zed', 'Ace', 'Bee']);
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
