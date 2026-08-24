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

  /// Unit this line's [quantity] is expressed in. When it differs from the
  /// ingredient item's own stock unit (e.g. a recipe calls for 250 `g` of an
  /// ingredient stocked in `kg`), [conversionFactor] converts between them —
  /// see that field's doc. Purely a display label when the two units match.
  @HiveField(2)
  final String? unit;

  /// Extra quantity consumed for prep loss, as a percent (0-100).
  @HiveField(3, defaultValue: 0.0)
  final double wastagePercent;

  @HiveField(4)
  final String? note;

  /// How many of the ingredient item's native stock unit equal one [unit] of
  /// this line — e.g. `0.001` when [unit] is `'g'` and the ingredient is
  /// stocked in `'kg'` (1 g = 0.001 kg). [effectiveQuantity] multiplies by
  /// this before deduction, so stock always moves in the item's own unit
  /// regardless of what unit the recipe was written in.
  ///
  /// Defaults to `1.0` — no conversion, [unit] is assumed to already match
  /// the ingredient's stock unit. Every recipe saved before this field
  /// existed deserializes with `1.0`, so existing deduction math is
  /// unchanged unless a conversion is deliberately set.
  @HiveField(5, defaultValue: 1.0)
  final double conversionFactor;

  RecipeIngredientModel({
    required this.ingredientItemId,
    required this.quantity,
    this.unit,
    this.wastagePercent = 0.0,
    this.note,
    this.conversionFactor = 1.0,
  });

  /// Effective quantity consumed per batch, in the ingredient item's own
  /// stock unit — wastage and unit conversion both folded in.
  double get effectiveQuantity =>
      quantity * conversionFactor * (1 + wastagePercent / 100);

  RecipeIngredientModel copyWith({
    String? ingredientItemId,
    double? quantity,
    String? unit,
    double? wastagePercent,
    String? note,
    double? conversionFactor,
  }) {
    return RecipeIngredientModel(
      ingredientItemId: ingredientItemId ?? this.ingredientItemId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      wastagePercent: wastagePercent ?? this.wastagePercent,
      note: note ?? this.note,
      conversionFactor: conversionFactor ?? this.conversionFactor,
    );
  }

  Map<String, dynamic> toMap() => {
        'ingredientItemId': ingredientItemId,
        'quantity': quantity,
        'unit': unit,
        'wastagePercent': wastagePercent,
        'note': note,
        'conversionFactor': conversionFactor,
      };

  factory RecipeIngredientModel.fromMap(Map<String, dynamic> map) {
    return RecipeIngredientModel(
      ingredientItemId: map['ingredientItemId'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String?,
      wastagePercent: (map['wastagePercent'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String?,
      conversionFactor: (map['conversionFactor'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
