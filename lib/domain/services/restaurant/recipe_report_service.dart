import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/recipe_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';

/// One row of [RecipeReportService.foodCostReport] — cost/margin snapshot for
/// a single Semi-Finished or Recipe-Based item.
class RecipeCostReportRow {
  final Items item;
  final RecipeModel recipe;
  final double costPerUnit;
  final double? sellingPrice;
  final double? foodCostPercent; // costPerUnit / sellingPrice * 100
  final double? marginPercent; // 100 - foodCostPercent
  final int ingredientCount;

  RecipeCostReportRow({
    required this.item,
    required this.recipe,
    required this.costPerUnit,
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
  /// Cost/margin snapshot for every Semi-Finished and Recipe-Based item that
  /// has a configured recipe. Items without one (or without ingredients) are
  /// skipped — nothing meaningful to report yet.
  static List<RecipeCostReportRow> foodCostReport() {
    double costOf(String ingredientItemId) {
      try {
        final ingredient = itemStore.items.firstWhere((i) => i.id == ingredientItemId);
        return ingredient.lastPurchaseCost ?? 0.0;
      } catch (_) {
        return 0.0;
      }
    }

    final rows = <RecipeCostReportRow>[];
    for (final item in itemStore.items) {
      if (!item.isSemiFinished && !item.isRecipeBased) continue;
      final recipe = recipeRepository.getRecipeForItem(item.id);
      if (recipe == null || !recipe.hasIngredients) continue;

      final costPerUnit = recipe.estimatedCostPerUnit(costOf);
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
        ingredientCount: recipe.ingredients.length,
      ));
    }
    rows.sort((a, b) => a.item.name.compareTo(b.item.name));
    return rows;
  }

  /// Total quantity of each raw material/semi-finished item consumed via
  /// recipe-cascaded sales (`InventoryService._deductRecipeIngredients`,
  /// reason `'Sale (recipe: ...)'`) and batch production
  /// (`InventoryService.produceBatch`, reason `'Production (...)'`) within
  /// [from]..[to] (inclusive; null means unbounded on that side).
  static List<IngredientUsageRow> ingredientUsageReport({DateTime? from, DateTime? to}) {
    final stockRepo = StockMovementRepository();
    final movements = stockRepo.allMovements().where((m) {
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
      // Prefer the cost that was actually in effect when this movement was
      // recorded (StockMovementModel.unitCost) over today's live cost, so a
      // report for last month prices last month's ingredients correctly even
      // if the purchase cost has since changed. Movements logged before this
      // field existed fall back to the item's current cost.
      double costPerUnit = m.unitCost ?? 0.0;
      if (m.unitCost == null) {
        try {
          costPerUnit = itemStore.items.firstWhere((i) => i.id == m.itemId).lastPurchaseCost ?? 0.0;
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

  /// Total quantity of each raw material/semi-finished item logged as
  /// 'Wastage / Spoilage' (the manual removal reason offered on the
  /// Inventory screen's stock-adjustment dialog) within [from]..[to].
  static List<WastageRow> wastageReport({DateTime? from, DateTime? to}) {
    final stockRepo = StockMovementRepository();
    final movements = stockRepo.allMovements().where((m) {
      if (m.type != 'out') return false;
      if (m.reason != 'Wastage / Spoilage') return false;
      if (from != null && m.timestamp.isBefore(from)) return false;
      if (to != null && m.timestamp.isAfter(to)) return false;
      return true;
    });

    final byItem = <String, WastageRow>{};
    for (final m in movements) {
      // Same historical-cost preference as ingredientUsageReport — see there.
      double costPerUnit = m.unitCost ?? 0.0;
      if (m.unitCost == null) {
        try {
          costPerUnit = itemStore.items.firstWhere((i) => i.id == m.itemId).lastPurchaseCost ?? 0.0;
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
}
