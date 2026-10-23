import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'recipe_production_model.g.dart';

/// Append-only record of one "batch produced" run for a Semi-Finished or
/// made-in-advance Finished item — e.g. "made 10 units of Burger Patty from
/// the recipe". Mirrors
/// [StockMovementModel]: never edited or deleted. See
/// docs/inventory_recipe_system_plan.md §6.3.
@HiveType(typeId: HiveTypeIds.restaurantRecipeProduction)
class RecipeProductionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String recipeId;

  /// The item this production run replenished.
  @HiveField(2)
  final String itemId;

  /// Item name captured at save time (survives item rename/delete).
  @HiveField(3)
  final String itemName;

  /// The planned batch, in yield-units — what the ingredients were drawn for.
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

  /// What the batch actually yielded, when it differed from [batchQty].
  /// Null on runs recorded before actual output existed.
  @HiveField(8)
  final double? actualQty;

  RecipeProductionModel({
    required this.id,
    required this.recipeId,
    required this.itemId,
    required this.itemName,
    required this.batchQty,
    required this.producedTime,
    this.producedBy,
    this.movementIds = const [],
    this.actualQty,
  });

  /// Units added to stock by this run.
  double get outputQty => actualQty ?? batchQty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipeId': recipeId,
        'itemId': itemId,
        'itemName': itemName,
        'batchQty': batchQty,
        'producedTime': producedTime.toIso8601String(),
        'producedBy': producedBy,
        'movementIds': movementIds,
        'actualQty': actualQty,
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
      actualQty: (map['actualQty'] as num?)?.toDouble(),
    );
  }
}
