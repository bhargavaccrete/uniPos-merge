import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'variante_model_201.g.dart';

@HiveType(typeId: HiveTypeIds.retailVariant)
class VarianteModel extends HiveObject {
  @HiveField(0)
  final String varianteId;

  @HiveField(1)
  final String productId;

  @HiveField(2)
  final String? size;

  @HiveField(3)
  final String? color;

  @HiveField(4)
  final String? weight;

  @HiveField(5)
  final String? sku;

  @HiveField(6)
  final String? barcode;

  @HiveField(7)
  final double? mrp;

  @HiveField(8)
  final double? costPrice;

  @HiveField(9)
  final int stockQty;

  @HiveField(10)
  final int? minStock;

  @HiveField(11)
  final double? taxRate; // GST rate at variant level (overrides product/category)

  @HiveField(12)
  final String createdAt;

  @HiveField(15)
  final double? sellingPrice; // Actual selling price (can be different from MRP)

  @HiveField(16)
  final String? hsnCode; // HSN code at variant level (optional override)

  @HiveField(13)
  final String? updateAt;

  /// Custom/Dynamic attributes for flexible variant properties
  /// Examples: {"Material": "Cotton", "Flavor": "Vanilla", "Capacity": "64GB"}
  @HiveField(14)
  final Map<String, String>? customAttributes;

  /// Stores attribute value IDs that make up this variant
  /// Key: attributeId, Value: attributeValueId
  /// Used for WooCommerce-style variant system
  @HiveField(17)
  final Map<String, String>? attributeValueIds;

  /// Optional image for this specific variant
  @HiveField(18)
  final String? imagePath;

  /// Flag to mark this as the default variant for the product
  @HiveField(19)
  final bool isDefault;

  /// Variant status: active, inactive, out_of_stock
  @HiveField(20)
  final String status;

  VarianteModel({
    required this.varianteId,
    required this.productId,
    this.size,
    this.color,
    this.weight,
    this.sku,
    this.barcode,
    this.mrp,
    this.costPrice,
    this.stockQty = 0,
    this.minStock,
    this.taxRate,
    required this.createdAt,
    this.updateAt,
    this.customAttributes,
    this.sellingPrice,
    this.hsnCode,
    this.attributeValueIds,
    this.imagePath,
    this.isDefault = false,
    this.status = 'active',
  });

  // Factory for creating a variant
  factory VarianteModel.create({
    required String varianteId,
    required String productId,
    String? size,
    String? color,
    String? weight,
    String? sku,
    String? barcode,
    double? mrp,
    double? costPrice,
    int stockQty = 0,
    int? minStock,
    double? taxRate,
    Map<String, String>? customAttributes,
    double? sellingPrice,
    String? hsnCode,
    Map<String, String>? attributeValueIds,
    String? imagePath,
    bool isDefault = false,
    String status = 'active',
  }) {
    final now = DateTime.now().toIso8601String();
    return VarianteModel(
      varianteId: varianteId,
      productId: productId,
      size: size,
      color: color,
      weight: weight,
      sku: sku,
      barcode: barcode,
      mrp: mrp,
      costPrice: costPrice,
      stockQty: stockQty,
      minStock: minStock,
      taxRate: taxRate,
      createdAt: now,
      updateAt: now,
      customAttributes: customAttributes,
      sellingPrice: sellingPrice,
      hsnCode: hsnCode,
      attributeValueIds: attributeValueIds,
      imagePath: imagePath,
      isDefault: isDefault,
      status: status,
    );
  }

  /// Get the effective selling price (sellingPrice > mrp > 0)
  double get effectivePrice => sellingPrice ?? mrp ?? 0;

  /// Get variant description including custom attributes
  String get variantDescription {
    List<String> parts = [];
    if (size != null && size!.isNotEmpty) parts.add('Size: $size');
    if (color != null && color!.isNotEmpty) parts.add('Color: $color');
    if (weight != null && weight!.isNotEmpty) parts.add('Weight: $weight');

    // Add custom attributes
    if (customAttributes != null && customAttributes!.isNotEmpty) {
      for (var entry in customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }

    return parts.isEmpty ? 'Default' : parts.join(', ');
  }

  /// Get short variant description (for compact display)
  String get shortDescription {
    List<String> parts = [];
    if (size != null && size!.isNotEmpty) parts.add(size!);
    if (color != null && color!.isNotEmpty) parts.add(color!);
    if (weight != null && weight!.isNotEmpty) parts.add(weight!);

    // Add custom attribute values only
    if (customAttributes != null && customAttributes!.isNotEmpty) {
      parts.addAll(customAttributes!.values);
    }

    return parts.isEmpty ? 'Default' : parts.join(' • ');
  }

  /// Check if variant has any attributes defined
  bool get hasAttributes {
    return (size != null && size!.isNotEmpty) ||
           (color != null && color!.isNotEmpty) ||
           (weight != null && weight!.isNotEmpty) ||
           (customAttributes != null && customAttributes!.isNotEmpty);
  }

  /// Get all attributes as a map (including standard + custom)
  Map<String, String> get allAttributes {
    final attrs = <String, String>{};
    if (size != null && size!.isNotEmpty) attrs['Size'] = size!;
    if (color != null && color!.isNotEmpty) attrs['Color'] = color!;
    if (weight != null && weight!.isNotEmpty) attrs['Weight'] = weight!;
    if (customAttributes != null) {
      attrs.addAll(customAttributes!);
    }
    return attrs;
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'varianteId': varianteId,
      'productId': productId,
      'size': size,
      'color': color,
      'weight': weight,
      'sku': sku,
      'barcode': barcode,
      'mrp': mrp,
      'costPrice': costPrice,
      'stockQty': stockQty,
      'minStock': minStock,
      'taxRate': taxRate,
      'createdAt': createdAt,
      'updateAt': updateAt,
      'customAttributes': customAttributes,
      'sellingPrice': sellingPrice,
      'hsnCode': hsnCode,
      'attributeValueIds': attributeValueIds,
      'imagePath': imagePath,
      'isDefault': isDefault,
      'status': status,
    };
  }

  // Create from Map (for backup restore)
  factory VarianteModel.fromMap(Map<String, dynamic> map) {
    return VarianteModel(
      varianteId: map['varianteId'] as String,
      productId: map['productId'] as String,
      size: map['size'] as String?,
      color: map['color'] as String?,
      weight: map['weight'] as String?,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      mrp: (map['mrp'] as num?)?.toDouble(),
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      stockQty: (map['stockQty'] as num?)?.toInt() ?? 0,
      minStock: (map['minStock'] as num?)?.toInt(),
      taxRate: (map['taxRate'] as num?)?.toDouble(),
      createdAt: map['createdAt'] as String,
      updateAt: map['updateAt'] as String?,
      customAttributes: map['customAttributes'] != null
          ? Map<String, String>.from(map['customAttributes'])
          : null,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble(),
      hsnCode: map['hsnCode'] as String?,
      attributeValueIds: map['attributeValueIds'] != null
          ? Map<String, String>.from(map['attributeValueIds'])
          : null,
      imagePath: map['imagePath'] as String?,
      isDefault: (map['isDefault'] as bool?) ?? false,
      status: (map['status'] as String?) ?? 'active',
    );
  }

  /// Check if variant is available for sale
  bool get isAvailable => status == 'active' && stockQty > 0;

  /// Check if variant is in stock
  bool get isInStock => stockQty > 0;

  // CopyWith method for updating variants
  VarianteModel copyWith({
    String? varianteId,
    String? productId,
    String? size,
    String? color,
    String? weight,
    String? sku,
    String? barcode,
    double? mrp,
    double? costPrice,
    int? stockQty,
    int? minStock,
    double? taxRate,
    String? createdAt,
    String? updateAt,
    Map<String, String>? customAttributes,
    double? sellingPrice,
    String? hsnCode,
    Map<String, String>? attributeValueIds,
    String? imagePath,
    bool? isDefault,
    String? status,
  }) {
    return VarianteModel(
      varianteId: varianteId ?? this.varianteId,
      productId: productId ?? this.productId,
      size: size ?? this.size,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      mrp: mrp ?? this.mrp,
      costPrice: costPrice ?? this.costPrice,
      stockQty: stockQty ?? this.stockQty,
      minStock: minStock ?? this.minStock,
      taxRate: taxRate ?? this.taxRate,
      createdAt: createdAt ?? this.createdAt,
      updateAt: updateAt ?? DateTime.now().toIso8601String(),
      customAttributes: customAttributes ?? this.customAttributes,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      hsnCode: hsnCode ?? this.hsnCode,
      attributeValueIds: attributeValueIds ?? this.attributeValueIds,
      imagePath: imagePath ?? this.imagePath,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
    );
  }
}
