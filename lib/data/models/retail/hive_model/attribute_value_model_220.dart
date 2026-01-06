import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'attribute_value_model_220.g.dart';

/// Attribute Value Model (e.g., Red, Blue, S, M, L, XL)
/// TypeId: 22
///
/// Stores individual values for a global attribute.
/// One attribute can have many values.
@HiveType(typeId: HiveTypeIds.retailAttributeValue)
class AttributeValueModel extends HiveObject {
  @HiveField(0)
  final String valueId;

  @HiveField(1)
  final String attributeId; // Links to AttributeModel

  @HiveField(2)
  final String value; // e.g., "Red", "Blue", "Small", "Large"

  @HiveField(3)
  final String slug; // URL-friendly: "red", "blue", "small"

  @HiveField(4)
  final String? colorCode; // Hex color for color attributes (e.g., "#FF0000")

  @HiveField(5)
  final int sortOrder; // Display order within attribute

  @HiveField(6)
  final bool isActive;

  @HiveField(7)
  final String createdAt;

  @HiveField(8)
  final String? updatedAt;

  AttributeValueModel({
    required this.valueId,
    required this.attributeId,
    required this.value,
    required this.slug,
    this.colorCode,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  AttributeValueModel copyWith({
    String? valueId,
    String? attributeId,
    String? value,
    String? slug,
    String? colorCode,
    int? sortOrder,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return AttributeValueModel(
      valueId: valueId ?? this.valueId,
      attributeId: attributeId ?? this.attributeId,
      value: value ?? this.value,
      slug: slug ?? this.slug,
      colorCode: colorCode ?? this.colorCode,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generate slug from value
  static String generateSlug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Convert to map for export/backup
  Map<String, dynamic> toMap() {
    return {
      'valueId': valueId,
      'attributeId': attributeId,
      'value': value,
      'slug': slug,
      'colorCode': colorCode,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from map for import/restore
  factory AttributeValueModel.fromMap(Map<String, dynamic> map) {
    return AttributeValueModel(
      valueId: map['valueId'] as String,
      attributeId: map['attributeId'] as String,
      value: map['value'] as String,
      slug: map['slug'] as String,
      colorCode: map['colorCode'] as String?,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  @override
  String toString() => 'AttributeValueModel(id: $valueId, value: $value)';
}