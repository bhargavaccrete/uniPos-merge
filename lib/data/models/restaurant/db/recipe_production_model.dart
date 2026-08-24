import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'recipe_production_model.g.dart';

/// Append-only record of one "batch produced" run for a Semi-Finished item —
/// e.g. "made 10 units of Burger Patty from the recipe". Mirrors
/// [StockMovementModel]: never edited or deleted. See
/// docs/inventory_recipe_system_plan.md §6.3.
@HiveType(typeId: HiveTypeIds.restaurantRecipeProduction)
class RecipeProductionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String recipeId;

  /// The Semi-Finished item this production run replenished.
  @HiveField(2)
  final String itemId;

  /// Item name captured at save time (survives item rename/delete).
  @HiveField(3)
  final String itemName;

  /// How many yield-units were produced this run.
  @HiveField(4)
  final double batchQty;

  @HiveField(5)
  final DateTime producedTime;

  @HiveField(6)
  final String? producedBy;

  /// IDs of the StockMovementModel rows this run created — one 'out' per
  /// ingredient consumed, one 'in' for the produced item — so a production
  /// run's full effect can be traced from either side.
  @HiveField(7)
  final List<String> movementIds;

  RecipeProductionModel({
    required this.id,
    required this.recipeId,
    required this.itemId,
    required this.itemName,
    required this.batchQty,
    required this.producedTime,
    this.producedBy,
    this.movementIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipeId': recipeId,
        'itemId': itemId,
        'itemName': itemName,
        'batchQty': batchQty,
        'producedTime': producedTime.toIso8601String(),
        'producedBy': producedBy,
        'movementIds': movementIds,
      };

  factory RecipeProductionModel.fromMap(Map<String, dynamic> map) {
    return RecipeProductionModel(
      id: map['id'] ?? '',
      recipeId: map['recipeId'] ?? '',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      batchQty: (map['batchQty'] as num?)?.toDouble() ?? 0.0,
      producedTime:
          DateTime.tryParse(map['producedTime'] ?? '') ?? DateTime.now(),
      producedBy: map['producedBy'] as String?,
      movementIds:
          (map['movementIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }
}
