import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'bundle_component_model.dart';

part 'bundle_model.g.dart';

/// A bundle or repack/kit product's component list — one per
/// [ProductModel.stockMode] `'bundle'`/`'repack'` product (via its single
/// variant, [variantId]). Bundle products have no stock of their own and
/// cascade a sale into their components; repack/kit products are stocked
/// directly but replenished by assembling from a source variant. Mirrors
/// restaurant's `RecipeModel`. See docs/retail_inventory_system_plan.md §3.2.
@HiveType(typeId: HiveTypeIds.retailBundle)
class RetailBundleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String productId;

  /// The bundle/repack product's single variant — the sellable SKU whose
  /// sale (bundle) or stock replenishment (repack) this component list drives.
  @HiveField(2)
  final String variantId;

  /// Embedded, same choice restaurant's `RecipeModel.ingredients` made — a
  /// handful of rows per bundle, no need for a separate box + repository.
  @HiveField(3)
  final List<BundleComponentModel> components;

  @HiveField(4)
  final String createdAt;

  @HiveField(5)
  final String updatedAt;

  RetailBundleModel({
    required this.id,
    required this.productId,
    required this.variantId,
    this.components = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasComponents => components.isNotEmpty;

  /// Estimated cost to sell/assemble one unit, from each component's cost.
  double estimatedCost(double Function(String componentVariantId) costOf) {
    double total = 0;
    for (final c in components) {
      total += costOf(c.componentVariantId) * c.quantity;
    }
    return total;
  }

  RetailBundleModel copyWith({
    String? id,
    String? productId,
    String? variantId,
    List<BundleComponentModel>? components,
    String? createdAt,
    String? updatedAt,
  }) {
    return RetailBundleModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      components: components ?? this.components,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'variantId': variantId,
        'components': components.map((c) => c.toMap()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory RetailBundleModel.fromMap(Map<String, dynamic> map) =>
      RetailBundleModel(
        id: map['id'] as String,
        productId: map['productId'] as String,
        variantId: map['variantId'] as String,
        components: (map['components'] as List<dynamic>? ?? [])
            .map((c) => BundleComponentModel.fromMap(c as Map<String, dynamic>))
            .toList(),
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
      );
}
