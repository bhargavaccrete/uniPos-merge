import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'recipe_ingredient_model.g.dart';

/// One line of a [RecipeModel] — "N units of ingredient item X".
///
/// Embedded inside `RecipeModel.ingredients`, same pattern as
/// `Items.variant` embeds `List<ItemVariante>` — no separate box, since a
/// recipe realistically has a handful of ingredient rows.
@HiveType(typeId: HiveTypeIds.restaurantRecipeIngredient)
class RecipeIngredientModel extends HiveObject {
  /// The raw-material or semi-finished item consumed by this line.
  ///
  /// MUST reference an item whose productType is rawMaterial or
  /// semiFinished — never recipeBased. Enforced by the ingredient picker UI
  /// (not here), so sale-time deduction only ever expands one level deep.
  @HiveField(0)
  final String ingredientItemId;

  /// Amount of the ingredient needed per [RecipeModel.yieldQty] units produced.
  @HiveField(1)
  final double quantity;

  /// Unit label, expected to match the ingredient item's own `unit` (no
  /// conversion table in v1 — see docs/inventory_recipe_system_plan.md §9.2).
  @HiveField(2)
  final String? unit;

  /// Extra quantity consumed for prep loss, as a percent (0-100).
  @HiveField(3, defaultValue: 0.0)
  final double wastagePercent;

  @HiveField(4)
  final String? note;

  RecipeIngredientModel({
    required this.ingredientItemId,
    required this.quantity,
    this.unit,
    this.wastagePercent = 0.0,
    this.note,
  });

  /// Effective quantity consumed per batch, wastage included.
  double get effectiveQuantity => quantity * (1 + wastagePercent / 100);

  RecipeIngredientModel copyWith({
    String? ingredientItemId,
    double? quantity,
    String? unit,
    double? wastagePercent,
    String? note,
  }) {
    return RecipeIngredientModel(
      ingredientItemId: ingredientItemId ?? this.ingredientItemId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      wastagePercent: wastagePercent ?? this.wastagePercent,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'ingredientItemId': ingredientItemId,
        'quantity': quantity,
        'unit': unit,
        'wastagePercent': wastagePercent,
        'note': note,
      };

  factory RecipeIngredientModel.fromMap(Map<String, dynamic> map) {
    return RecipeIngredientModel(
      ingredientItemId: map['ingredientItemId'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String?,
      wastagePercent: (map['wastagePercent'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String?,
    );
  }
}
