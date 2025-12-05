import 'package:hive/hive.dart';

part 'product_attribute_model_221.g.dart';

/// Product Attribute Assignment Model
/// TypeId: 23
///
/// Links a product to global attributes and specifies which values
/// are available for that product.
///
/// Example:
/// - Product "T-Shirt" has attribute "Color" with values ["Red", "Blue"]
/// - Product "T-Shirt" has attribute "Size" with values ["S", "M", "L"]
@HiveType(typeId: 221)
class ProductAttributeModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String productId; // Links to ProductModel

  @HiveField(2)
  final String attributeId; // Links to AttributeModel

  @HiveField(3)
  final List<String> selectedValueIds; // List of AttributeValueModel IDs

  @HiveField(4)
  final bool usedForVariants; // Whether this attribute generates variants

  @HiveField(5)
  final bool isVisible; // Show on product page

  @HiveField(6)
  final int position; // Display order

  @HiveField(7)
  final String createdAt;

  @HiveField(8)
  final String? updatedAt;

  ProductAttributeModel({
    required this.id,
    required this.productId,
    required this.attributeId,
    required this.selectedValueIds,
    this.usedForVariants = true,
    this.isVisible = true,
    this.position = 0,
    required this.createdAt,
    this.updatedAt,
  });

  ProductAttributeModel copyWith({
    String? id,
    String? productId,
    String? attributeId,
    List<String>? selectedValueIds,
    bool? usedForVariants,
    bool? isVisible,
    int? position,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductAttributeModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      attributeId: attributeId ?? this.attributeId,
      selectedValueIds: selectedValueIds ?? List.from(this.selectedValueIds),
      usedForVariants: usedForVariants ?? this.usedForVariants,
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ProductAttributeModel(productId: $productId, attributeId: $attributeId, values: $selectedValueIds)';
}