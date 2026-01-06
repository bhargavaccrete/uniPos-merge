import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'attribute_model_219.g.dart';

/// Global Product Attribute Model (e.g., Color, Size, Material)
/// TypeId: 21
///
/// This represents a reusable attribute that can be assigned to multiple products.
/// Similar to WooCommerce's global product attributes.
@HiveType(typeId: HiveTypeIds.retailAttribute)
class AttributeModel extends HiveObject {
  @HiveField(0)
  final String attributeId;

  @HiveField(1)
  final String name; // e.g., "Color", "Size", "Material"

  @HiveField(2)
  final String slug; // URL-friendly name: "color", "size", "material"

  @HiveField(3)
  final int sortOrder; // Display order in UI

  @HiveField(4)
  final bool isActive; // Can be deactivated without deleting

  @HiveField(5)
  final String createdAt;

  @HiveField(6)
  final String? updatedAt;

  AttributeModel({
    required this.attributeId,
    required this.name,
    required this.slug,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  AttributeModel copyWith({
    String? attributeId,
    String? name,
    String? slug,
    int? sortOrder,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return AttributeModel(
      attributeId: attributeId ?? this.attributeId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generate slug from name
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Convert to map for export/backup
  Map<String, dynamic> toMap() {
    return {
      'attributeId': attributeId,
      'name': name,
      'slug': slug,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from map for import/restore
  factory AttributeModel.fromMap(Map<String, dynamic> map) {
    return AttributeModel(
      attributeId: map['attributeId'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  @override
  String toString() => 'AttributeModel(id: $attributeId, name: $name)';
}