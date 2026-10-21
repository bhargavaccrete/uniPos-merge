import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'recipe_ingredient_model.dart';

part 'recipe_model.g.dart';

/// Bill of Materials for a Semi-Finished or Recipe-Based [Items] record —
/// what it's made from and how much of each. See
/// docs/inventory_recipe_system_plan.md §4 for the design.
@HiveType(typeId: HiveTypeIds.restaurantRecipe)
class RecipeModel extends HiveObject {
  @HiveField(0)
  final String id;

  /// The item this recipe produces. `Items.recipeId` points back here.
  @HiveField(1)
  final String itemId;

  /// Units produced per batch. 1 for made-to-order items (a Burger recipe
  /// yields 1 Burger); >1 for batch prep (a dough recipe might yield 10).
  @HiveField(2)
  final double yieldQty;

  @HiveField(3)
  final String? yieldUnit;

  @HiveField(4)
  final List<RecipeIngredientModel> ingredients;

  @HiveField(5)
  final String? prepInstructions;

  @HiveField(6)
  DateTime? createdTime;

  @HiveField(7)
  DateTime? lastEditedTime;

  @HiveField(8)
  String? editedBy;

  @HiveField(9, defaultValue: 0)
  int editCount;

  RecipeModel({
    required this.id,
    required this.itemId,
    this.yieldQty = 1.0,
    this.yieldUnit,
    this.ingredients = const [],
    this.prepInstructions,
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
  });

  bool get hasIngredients => ingredients.isNotEmpty;

  /// Estimated cost to produce [yieldQty] units, from each ingredient's
  /// `lastPurchaseCost` (0 if never purchased). [ingredientCostOf] resolves
  /// an ingredient item's cost — callers pass a lookup since this model has
  /// no repository access.
  double estimatedCost(double Function(String ingredientItemId) ingredientCostOf) {
    var total = 0.0;
    for (final line in ingredients) {
      total += line.effectiveQuantity * ingredientCostOf(line.ingredientItemId);
    }
    return total;
  }

  /// Estimated cost per single yield-unit (e.g. cost per Burger, not per batch).
  double estimatedCostPerUnit(double Function(String ingredientItemId) ingredientCostOf) {
    if (yieldQty <= 0) return 0.0;
    return estimatedCost(ingredientCostOf) / yieldQty;
  }

  RecipeModel copyWith({
    String? id,
    String? itemId,
    double? yieldQty,
    String? yieldUnit,
    List<RecipeIngredientModel>? ingredients,
    String? prepInstructions,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
  }) {
    return RecipeModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      yieldQty: yieldQty ?? this.yieldQty,
      yieldUnit: yieldUnit ?? this.yieldUnit,
      ingredients: ingredients ?? this.ingredients,
      prepInstructions: prepInstructions ?? this.prepInstructions,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemId': itemId,
        'yieldQty': yieldQty,
        'yieldUnit': yieldUnit,
        'ingredients': ingredients.map((e) => e.toMap()).toList(),
        'prepInstructions': prepInstructions,
        'createdTime': createdTime?.toIso8601String(),
        'lastEditedTime': lastEditedTime?.toIso8601String(),
        'editedBy': editedBy,
        'editCount': editCount,
      };

  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    return RecipeModel(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      yieldQty: (map['yieldQty'] as num?)?.toDouble() ?? 1.0,
      yieldUnit: map['yieldUnit'] as String?,
      ingredients: (map['ingredients'] as List?)
              ?.map((e) => RecipeIngredientModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      prepInstructions: map['prepInstructions'] as String?,
      createdTime:
          map['createdTime'] != null ? DateTime.tryParse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null
          ? DateTime.tryParse(map['lastEditedTime'])
          : null,
      editedBy: map['editedBy'] as String?,
      editCount: map['editCount'] ?? 0,
    );
  }
}
