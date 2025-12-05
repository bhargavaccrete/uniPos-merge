import "package:hive/hive.dart";
import "package:unipos/core/constants/hive_type_ids.dart";

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
  });

  /// Check if this is a variable product
  bool get isVariable => productType == 'variable' || hasVariants;

  /// Check if this is a simple product
  bool get isSimple => productType == 'simple' && !hasVariants;

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
    };
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
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brandName: brandName ?? this.brandName,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      hasVariants: hasVariants ?? this.hasVariants,
      createdAt: createdAt ?? this.createdAt,
      updateAt: updateAt ?? DateTime.now().toIso8601String(),
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode ?? this.hsnCode,
      productType: productType ?? this.productType,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      defaultMrp: defaultMrp ?? this.defaultMrp,
      defaultCostPrice: defaultCostPrice ?? this.defaultCostPrice,
    );
  }
}