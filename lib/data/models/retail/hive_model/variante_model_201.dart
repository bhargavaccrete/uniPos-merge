import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
part 'variante_model_201.g.dart';

@HiveType(typeId: HiveTypeIds.retailVariant)
class VarianteModel extends HiveObject {
  @HiveField(0)
  final String varianteId;

  @HiveField(1)
  final String productId;

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

  /// Reference to a shared Tax entity (see data/models/common/taxmodel_314.dart)
  /// picked in the variant form. [taxRate] is kept in sync as the resolved
  /// percentage so GstService/cart/receipt/report code never needs to look
  /// the Tax entity up — it stays a plain cached rate exactly as before.
  @HiveField(21)
  final String? taxId;

  VarianteModel({
    required this.varianteId,
    required this.productId,
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
    this.taxId,
  });

  // Factory for creating a variant
  factory VarianteModel.create({
    required String varianteId,
    required String productId,
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
    String? taxId,
  }) {
    final now = DateTime.now().toIso8601String();
    return VarianteModel(
      varianteId: varianteId,
      productId: productId,
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
      taxId: taxId,
    );
  }

  /// Get the effective selling price (sellingPrice > mrp > 0)
  double get effectivePrice => sellingPrice ?? mrp ?? 0;

  /// Labelled descriptor, e.g. "Storage: 1tb, Colour: Black".
  ///
  /// Reads only [customAttributes], so the labels are whatever the shop
  /// actually named its fields. For a variant built from the global attribute
  /// system, prefer `attributeStore.attributesOf` — it also resolves
  /// [attributeValueIds].
  String get variantDescription {
    final attrs = customAttributes;
    if (attrs == null || attrs.isEmpty) return 'Default';
    return attrs.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  /// Label used in inventory lists and variant pickers.
  String get displayName {
    final parts = <String>[];
    customAttributes?.forEach((key, value) {
      if (value.isNotEmpty) parts.add('$key: $value');
    });
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  /// Values only, no labels (for compact display).
  String get shortDescription {
    final values = customAttributes?.values.where((v) => v.isNotEmpty) ?? const [];
    return values.isEmpty ? 'Default' : values.join(' • ');
  }

  /// Check if variant has any attributes defined
  bool get hasAttributes => customAttributes?.isNotEmpty ?? false;

  /// All descriptors as a map.
  Map<String, String> get allAttributes =>
      Map<String, String>.from(customAttributes ?? const {});

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'varianteId': varianteId,
      'productId': productId,
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
      'taxId': taxId,
    };
  }

  // Create from Map (for backup restore)
  factory VarianteModel.fromMap(Map<String, dynamic> map) {
    return VarianteModel(
      varianteId: map['varianteId'] as String,
      productId: map['productId'] as String,
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
      taxId: map['taxId'] as String?,
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
    String? taxId,
    // `x ?? this.x` can never put a nullable field back to null, so an edit
    // form has no way to clear an optional number. These say so explicitly,
    // instead of forcing callers to hand-build the model (which is how
    // sellingPrice/hsnCode/status used to get silently wiped).
    bool clearMrp = false,
    bool clearMinStock = false,
    /// Same reason as [clearMrp]: `barcode ?? this.barcode` cannot put the field
    /// back to null, so removing a barcode needs an explicit flag.
    ///
    /// Clearing a barcode strands every label already printed with it, so a
    /// caller must confirm with the user first.
    bool clearBarcode = false,
  }) {
    return VarianteModel(
      varianteId: varianteId ?? this.varianteId,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      mrp: clearMrp ? null : (mrp ?? this.mrp),
      costPrice: costPrice ?? this.costPrice,
      stockQty: stockQty ?? this.stockQty,
      minStock: clearMinStock ? null : (minStock ?? this.minStock),
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
      taxId: taxId ?? this.taxId,
    );
  }
}
