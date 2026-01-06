import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'category_model_215.g.dart';

@HiveType(typeId: HiveTypeIds.retailCategory)
class CategoryModel extends HiveObject {
  @HiveField(0)
  final String categoryId;

  @HiveField(1)
  final String categoryName;

  @HiveField(2)
  final double? gstRate; // GST percentage (e.g., 5, 12, 18, 28)

  @HiveField(3)
  final String? hsnCode; // HSN/SAC code for GST

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final String createdAt;

  @HiveField(6)
  final String? updatedAt;

  CategoryModel({
    required this.categoryId,
    required this.categoryName,
    this.gstRate,
    this.hsnCode,
    this.description,
    required this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.create({
    required String categoryId,
    required String categoryName,
    double? gstRate,
    String? hsnCode,
    String? description,
  }) {
    final now = DateTime.now().toIso8601String();
    return CategoryModel(
      categoryId: categoryId,
      categoryName: categoryName,
      gstRate: gstRate,
      hsnCode: hsnCode,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  CategoryModel copyWith({
    String? categoryId,
    String? categoryName,
    double? gstRate,
    String? hsnCode,
    String? description,
    String? createdAt,
    String? updatedAt,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode ?? this.hsnCode,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'gstRate': gstRate,
      'hsnCode': hsnCode,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      gstRate: (map['gstRate'] as num?)?.toDouble(),
      hsnCode: map['hsnCode'] as String?,
      description: map['description'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
    );
  }
}