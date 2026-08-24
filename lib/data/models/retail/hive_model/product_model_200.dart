import "dart:typed_data";

import "package:hive/hive.dart";
import "package:billberrylite/core/constants/hive_type_ids.dart";

part 'product_model_200.g.dart';

@HiveType(typeId: HiveTypeIds.retailProduct)
class ProductModel extends HiveObject {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final String? brandName;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String? subCategory;

  @HiveField(5)
  final String? imagePath;

  @HiveField(6)
  final String? description;

  @HiveField(7)
  final bool hasVariants;

  @HiveField(8)
  final String createdAt;

  @HiveField(9)
  final String updateAt;

  @HiveField(10)
  final double? gstRate; // GST percentage at product level

  @HiveField(11)
  final String? hsnCode; // HSN/SAC code for GST

  /// Product type: 'simple' or 'variable'
  /// - simple: Single product without variants (uses default variant for stock/price)
  /// - variable: Product with multiple variants based on attributes
  @HiveField(12)
  final String productType; // 'simple' | 'variable'

  /// Default selling price for simple products (used when no variant selected)
  @HiveField(13)
  final double? defaultPrice;

  /// Default MRP for simple products
  @HiveField(14)
  final double? defaultMrp;

  /// Default cost price for simple products
  @HiveField(15)
  final double? defaultCostPrice;

  /// Reference to a shared Tax entity (see data/models/common/taxmodel_314.dart)
  /// picked in the product form. [gstRate] is kept in sync as the resolved
  /// percentage so GstService/cart/receipt/report code never needs to look
  /// the Tax entity up — it stays a plain cached rate exactly as before.
  @HiveField(16)
  final String? taxId;

  /// Product photo, stored as bytes rather than a file path so it survives on
  /// web as well as mobile — the same choice the restaurant `Items` model makes
  /// with its `imageBytes`. [imagePath] predates this and is unused.
  @HiveField(17)
  final Uint8List? imageBytes;

  /// Stock behavior: `'standard'` (default — this product's own variant
  /// stock is what's sold), `'bundle'` (no stock of its own; selling it
  /// cascades into deducting its `RetailBundleModel` components), or
  /// `'repack'` (has its own stock, replenished by assembling from a source
  /// variant rather than a GRN). Deliberately a SEPARATE field from
  /// [productType] above — that field already means simple-vs-variable
  /// (variant shape) and is checked as `productType == 'variable'` in
  /// several places, so overloading it with new values would silently break
  /// that logic. Null means `'standard'` — additive/backward-compatible, no
  /// migration. See docs/retail_inventory_system_plan.md §3.2.
  @HiveField(18)
  final String? stockMode;

  ProductModel({
    required this.productId,
    required this.productName,
    this.brandName,
    required this.category,
    this.subCategory,
    this.imagePath,
    this.description,
    required this.hasVariants,
    required this.createdAt,
    required this.updateAt,
    this.gstRate,
    this.hsnCode,
    this.productType = 'simple',
    this.defaultPrice,
    this.defaultMrp,
    this.defaultCostPrice,
    this.taxId,
    this.imageBytes,
    this.stockMode,
  });

  /// Check if this is a variable product
  bool get isVariable => productType == 'variable' || hasVariants;

  /// Check if this is a simple product
  bool get isSimple => productType == 'simple' && !hasVariants;

  String get effectiveStockMode => stockMode ?? 'standard';
  bool get isBundle => effectiveStockMode == 'bundle';
  bool get isRepack => effectiveStockMode == 'repack';
  bool get isStandardStock => effectiveStockMode == 'standard';

  /// True for either composite type — the two cases that need a
  /// [RetailBundleModel] component list configured.
  bool get needsBundleComponents => isBundle || isRepack;

  // Convert from simple Product to ProductModel
  factory ProductModel.fromProduct({
    required String productId,
    required String productName,
    String? brandName,
    required String category,
    String? subCategory,
    String? imagePath,
    String? description,
    required bool hasVariants,
    double? gstRate,
    String? hsnCode,
    String productType = 'simple',
    double? defaultPrice,
    double? defaultMrp,
    double? defaultCostPrice,
    String? taxId,
    Uint8List? imageBytes,
    String? stockMode,
  }) {
    final now = DateTime.now().toIso8601String();
    return ProductModel(
      productId: productId,
      productName: productName,
      brandName: brandName,
      category: category,
      subCategory: subCategory,
      imagePath: imagePath,
      description: description,
      hasVariants: hasVariants,
      createdAt: now,
      updateAt: now,
      gstRate: gstRate,
      hsnCode: hsnCode,
      productType: productType,
      defaultPrice: defaultPrice,
      defaultMrp: defaultMrp,
      defaultCostPrice: defaultCostPrice,
      taxId: taxId,
      imageBytes: imageBytes,
      stockMode: stockMode,
    );
  }

  // Convert to simple Product
  Map<String, dynamic> toProduct() {
    return {
      'productId': productId,
      'name': productName,
      'brandName': brandName,
      'category': category,
      'subCategory': subCategory,
      'imagePath': imagePath ?? 'https://via.placeholder.com/150',
      'description': description,
      'hasVariants': hasVariants,
      'createdAt': createdAt,
      'updateAt': updateAt,
      'gstRate': gstRate,
      'hsnCode': hsnCode,
      'productType': productType,
      'defaultPrice': defaultPrice,
      'defaultMrp': defaultMrp,
      'defaultCostPrice': defaultCostPrice,
      'taxId': taxId,
      // List<int> so the backup JSON stays serialisable, matching Items.toMap.
      'imageBytes': imageBytes?.toList(),
      'stockMode': stockMode,
    };
  }

  // Create from Map (for backup restore)
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      productId: map['productId'] as String,
      productName: (map['name'] ?? map['productName']) as String,
      brandName: map['brandName'] as String?,
      category: map['category'] as String,
      subCategory: map['subCategory'] as String?,
      imagePath: map['imagePath'] as String?,
      description: map['description'] as String?,
      hasVariants: map['hasVariants'] as bool,
      createdAt: map['createdAt'] as String,
      updateAt: map['updateAt'] as String,
      gstRate: (map['gstRate'] as num?)?.toDouble(),
      hsnCode: map['hsnCode'] as String?,
      productType: (map['productType'] as String?) ?? 'simple',
      defaultPrice: (map['defaultPrice'] as num?)?.toDouble(),
      defaultMrp: (map['defaultMrp'] as num?)?.toDouble(),
      defaultCostPrice: (map['defaultCostPrice'] as num?)?.toDouble(),
      taxId: map['taxId'] as String?,
      imageBytes: _bytesFrom(map['imageBytes']),
      stockMode: map['stockMode'] as String?,
    );
  }

  /// Backups round-trip bytes through JSON as a List<int>; a restore from an
  /// in-memory map may still hand back a Uint8List.
  static Uint8List? _bytesFrom(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is List) return Uint8List.fromList(raw.cast<int>());
    return null;
  }

  ProductModel copyWith({
    String? productId,
    String? productName,
    String? brandName,
    String? category,
    String? subCategory,
    String? imagePath,
    String? description,
    bool? hasVariants,
    String? createdAt,
    String? updateAt,
    double? gstRate,
    String? hsnCode,
    String? productType,
    double? defaultPrice,
    double? defaultMrp,
    double? defaultCostPrice,
    String? taxId,
    Uint8List? imageBytes,
    String? stockMode,
    // `x ?? this.x` can never put a nullable field back to null, so an edit
    // form has no way to clear an optional value. These say so explicitly,
    // instead of forcing callers to hand-build the model.
    bool clearBrandName = false,
    bool clearDescription = false,
    bool clearHsnCode = false,
    bool clearTax = false,
    bool clearImage = false,
    bool clearStockMode = false,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brandName: clearBrandName ? null : (brandName ?? this.brandName),
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      imagePath: imagePath ?? this.imagePath,
      description: clearDescription ? null : (description ?? this.description),
      hasVariants: hasVariants ?? this.hasVariants,
      createdAt: createdAt ?? this.createdAt,
      updateAt: updateAt ?? DateTime.now().toIso8601String(),
      gstRate: clearTax ? null : (gstRate ?? this.gstRate),
      hsnCode: clearHsnCode ? null : (hsnCode ?? this.hsnCode),
      productType: productType ?? this.productType,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      defaultMrp: defaultMrp ?? this.defaultMrp,
      defaultCostPrice: defaultCostPrice ?? this.defaultCostPrice,
      taxId: clearTax ? null : (taxId ?? this.taxId),
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      stockMode: clearStockMode ? null : (stockMode ?? this.stockMode),
    );
  }
}