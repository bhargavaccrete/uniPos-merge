import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/recipe_model.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';

/// Where a food-cost row's cost came from.
enum FoodCostSource {
  /// The item's recipe, priced from each ingredient's cost.
  recipe,

  /// `lastPurchaseCost` — written by the latest production run or GRN.
  lastCost,

  /// `lastPurchaseCost` of a Trade Item — written by the latest GRN.
  purchase,

  /// No cost is known.
  none;

  String get label => switch (this) {
        recipe => 'Recipe cost',
        lastCost => 'Last production/purchase cost',
        purchase => 'Last purchase cost',
        none => 'No cost yet',
      };
}

/// One row of [RecipeReportService.foodCostReport] — cost/margin snapshot for
/// a single Finished, Semi-Finished or Trade item.
class RecipeCostReportRow {
  final Items item;
  final RecipeModel? recipe;

  /// Null when the cost is unknown — never reported as ₹0.
  final double? costPerUnit;
  final FoodCostSource costSource;

  /// Recipe lines whose ingredient has no cost (or no longer exists).
  final int missingCostIngredients;
  final double? sellingPrice;
  final double? foodCostPercent; // costPerUnit / sellingPrice * 100
  final double? marginPercent; // 100 - foodCostPercent
  final int ingredientCount;

  RecipeCostReportRow({
    required this.item,
    this.recipe,
    required this.costPerUnit,
    required this.costSource,
    this.missingCostIngredients = 0,
    required this.sellingPrice,
    required this.foodCostPercent,
    required this.marginPercent,
    required this.ingredientCount,
  });
}

/// One row of [RecipeReportService.ingredientUsageReport] — total quantity of
/// a single raw material/semi-finished item consumed (via recipe-cascaded
/// sales and/or batch production) within a date range.
class IngredientUsageRow {
  final String itemId;
  final String itemName;
  final String unit;
  final double consumedQty;
  final double estimatedCost;
  final int movementCount;

  IngredientUsageRow({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.consumedQty,
    required this.estimatedCost,
    required this.movementCount,
  });
}

/// One row of [RecipeReportService.wastageReport] — total quantity logged as
/// 'Wastage / Spoilage' for a single raw material/semi-finished item within a
/// date range (see the manual stock-adjustment reasons in `manage_Inventory.dart`).
class WastageRow {
  final String itemId;
  final String itemName;
  final String unit;
  final double wastedQty;
  final double estimatedCost;
  final int movementCount;

  WastageRow({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.wastedQty,
    required this.estimatedCost,
    required this.movementCount,
  });
}

/// Aggregation layer over recipes and stock movements for the Phase 6
/// reporting surface: food-cost %, ingredient usage, recipe margin, wastage.
/// See docs/inventory_recipe_system_plan.md §10 (Phase 6).
class RecipeReportService {
  /// id → item, FIRST occurrence wins — the item a `firstWhere` scan returns
  /// when ids are duplicated.
  static Map<String, Items> _firstItemById(Iterable<Items> items) {
    final byId = <String, Items>{};
    for (final item in items) {
      byId.putIfAbsent(item.id, () => item);
    }
    return byId;
  }

  /// Fallback cost for a movement logged before `unitCost` existed: the
  /// item's current cost, or 0.0 when the item — or the item list itself —
  /// can't be resolved. [items] is only read on the first such movement,
  /// matching the original per-movement `try { itemStore… } catch (_) {}`.
  static double Function(String itemId) _legacyCostLookup(
    Iterable<Items> Function() items,
  ) {
    Map<String, Items>? byId;
    return (itemId) {
      if (byId == null) {
        try {
          byId = _firstItemById(items());
        } catch (_) {
          byId = const {};
        }
      }
      final item = byId![itemId];
      return item == null ? 0.0 : (item.lastPurchaseCost ?? 0.0);
    };
  }

  /// Cost/margin snapshot for every Finished, Semi-Finished and Trade item
  /// (Raw Materials are ingredients, not costed products). Cost by type:
  /// - Finished with a recipe → the recipe's ingredient cost.
  /// - Finished made in advance, no recipe → `lastPurchaseCost` (latest
  ///   production run or GRN).
  /// - Finished made to order, no recipe → unknown.
  /// - Trade → `lastPurchaseCost` (latest GRN).
  /// - Semi-Finished → `lastPurchaseCost`, else its recipe estimate.
  /// A missing cost is unknown (null), never ₹0: a recipe is unknown when any
  /// ingredient has no cost or its yield is not positive.
  static List<RecipeCostReportRow> foodCostReport() => foodCostReportFrom(
        items: itemStore.items,
        recipeForItem: recipeRepository.getRecipeForItem,
      );

  static List<RecipeCostReportRow> foodCostReportFrom({
    required Iterable<Items> items,
    required RecipeModel? Function(String itemId) recipeForItem,
  }) {
    final itemById = _firstItemById(items);

    final rows = <RecipeCostReportRow>[];
    for (final item in items) {
      if (!item.isFinished && !item.isSemiFinished && !item.isTradeItem) {
        continue;
      }

      final stored = recipeForItem(item.id);
      final recipe = (stored != null && stored.hasIngredients) ? stored : null;
      final recipeCost =
          recipe == null ? null : _recipeCostPerUnit(recipe, itemById);

      double? costPerUnit;
      var source = FoodCostSource.none;
      if (item.isTradeItem) {
        costPerUnit = item.lastPurchaseCost;
        if (costPerUnit != null) source = FoodCostSource.purchase;
      } else if (item.isSemiFinished && item.lastPurchaseCost != null) {
        costPerUnit = item.lastPurchaseCost;
        source = FoodCostSource.lastCost;
      } else if (recipeCost != null) {
        costPerUnit = recipeCost.cost;
        source = FoodCostSource.recipe;
      } else if (item.isMadeInAdvance && item.lastPurchaseCost != null) {
        costPerUnit = item.lastPurchaseCost;
        source = FoodCostSource.lastCost;
      }

      final sellingPrice = item.price;
      double? foodCostPercent;
      double? marginPercent;
      if (costPerUnit != null && sellingPrice != null && sellingPrice > 0) {
        foodCostPercent = (costPerUnit / sellingPrice) * 100;
        marginPercent = 100 - foodCostPercent;
      }

      rows.add(RecipeCostReportRow(
        item: item,
        recipe: recipe,
        costPerUnit: costPerUnit,
        costSource: source,
        missingCostIngredients:
            source == FoodCostSource.recipe ? recipeCost!.missing : 0,
        sellingPrice: sellingPrice,
        foodCostPercent: foodCostPercent,
        marginPercent: marginPercent,
        ingredientCount: recipe?.ingredients.length ?? 0,
      ));
    }
    // Costed rows first so unknown ones (work still to do) don't bury them.
    rows.sort((a, b) {
      final known = (a.costPerUnit == null ? 1 : 0)
          .compareTo(b.costPerUnit == null ? 1 : 0);
      return known != 0 ? known : a.item.name.compareTo(b.item.name);
    });
    return rows;
  }

  /// [recipe]'s cost per unit, null when it can't be known: any ingredient
  /// without a cost (or deleted), or a yield that isn't positive. [missing]
  /// counts the uncosted ingredient lines.
  static ({double? cost, int missing}) _recipeCostPerUnit(
    RecipeModel recipe,
    Map<String, Items> itemById,
  ) {
    var missing = 0;
    for (final line in recipe.ingredients) {
      if (itemById[line.ingredientItemId]?.lastPurchaseCost == null) missing++;
    }
    if (missing > 0 || recipe.yieldQty <= 0) {
      return (cost: null, missing: missing);
    }
    return (
      cost: recipe.estimatedCostPerUnit(
          (id) => itemById[id]!.lastPurchaseCost!),
      missing: 0,
    );
  }

  /// Total quantity of each raw material/semi-finished item consumed via
  /// recipe-cascaded sales (`InventoryService._deductRecipeIngredients`,
  /// reason `'Sale (recipe: ...)'`) and batch production
  /// (`InventoryService.produceBatch`, reason `'Production (...)'`) within
  /// [from]..[to] (inclusive; null means unbounded on that side).
  static List<IngredientUsageRow> ingredientUsageReport({DateTime? from, DateTime? to}) =>
      ingredientUsageReportFrom(
        movements: StockMovementRepository().allMovements(),
        items: () => itemStore.items,
        from: from,
        to: to,
      );

  static List<IngredientUsageRow> ingredientUsageReportFrom({
    required Iterable<StockMovementModel> movements,
    required Iterable<Items> Function() items,
    DateTime? from,
    DateTime? to,
  }) {
    final filtered = movements.where((m) {
      if (m.type != 'out') return false;
      final isRecipeCascade = m.reason.startsWith('Sale (recipe');
      final isProduction = m.reason.startsWith('Production (');
      if (!isRecipeCascade && !isProduction) return false;
      if (from != null && m.timestamp.isBefore(from)) return false;
      if (to != null && m.timestamp.isAfter(to)) return false;
      return true;
    });

    final legacyCostOf = _legacyCostLookup(items);
    final byItem = <String, IngredientUsageRow>{};
    for (final m in filtered) {
      // Prefer the cost that was actually in effect when this movement was
      // recorded (StockMovementModel.unitCost) over today's live cost, so a
      // report for last month prices last month's ingredients correctly even
      // if the purchase cost has since changed. Movements logged before this
      // field existed fall back to the item's current cost.
      double costPerUnit = m.unitCost ?? 0.0;
      if (m.unitCost == null) {
        costPerUnit = legacyCostOf(m.itemId);
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

  /// Total quantity of each raw material/semi-finished item logged as
  /// 'Wastage / Spoilage' (the manual removal reason offered on the
  /// Inventory screen's stock-adjustment dialog) within [from]..[to].
  static List<WastageRow> wastageReport({DateTime? from, DateTime? to}) =>
      wastageReportFrom(
        movements: StockMovementRepository().allMovements(),
        items: () => itemStore.items,
        from: from,
        to: to,
      );

  static List<WastageRow> wastageReportFrom({
    required Iterable<StockMovementModel> movements,
    required Iterable<Items> Function() items,
    DateTime? from,
    DateTime? to,
  }) {
    final filtered = movements.where((m) {
      if (m.type != 'out') return false;
      if (m.reason != 'Wastage / Spoilage') return false;
      if (from != null && m.timestamp.isBefore(from)) return false;
      if (to != null && m.timestamp.isAfter(to)) return false;
      return true;
    });

    final legacyCostOf = _legacyCostLookup(items);
    final byItem = <String, WastageRow>{};
    for (final m in filtered) {
      // Same historical-cost preference as ingredientUsageReport — see there.
      double costPerUnit = m.unitCost ?? 0.0;
      if (m.unitCost == null) {
        costPerUnit = legacyCostOf(m.itemId);
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
}
