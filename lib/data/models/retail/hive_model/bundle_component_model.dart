import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'bundle_component_model.g.dart';

/// One component line of a [RetailBundleModel] — a variant consumed when the
/// bundle/repack SKU is sold or assembled, and how many units of it.
/// Retail sells whole units only, so [quantity] is an `int` (unlike
/// restaurant's `RecipeIngredientModel.quantity`, which is a `double` to
/// support weight-based ingredients). See
/// docs/retail_inventory_system_plan.md §3.2.
@HiveType(typeId: HiveTypeIds.retailBundleComponent)
class BundleComponentModel extends HiveObject {
  @HiveField(0)
  final String componentVariantId;

  @HiveField(1)
  final int quantity;

  @HiveField(2)
  final String? note;

  BundleComponentModel({
    required this.componentVariantId,
    required this.quantity,
    this.note,
  });

  BundleComponentModel copyWith({
    String? componentVariantId,
    int? quantity,
    String? note,
  }) {
    return BundleComponentModel(
      componentVariantId: componentVariantId ?? this.componentVariantId,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'componentVariantId': componentVariantId,
        'quantity': quantity,
        'note': note,
      };

  factory BundleComponentModel.fromMap(Map<String, dynamic> map) =>
      BundleComponentModel(
        componentVariantId: map['componentVariantId'] as String,
        quantity: (map['quantity'] as num).toInt(),
        note: map['note'] as String?,
      );
}
