import 'dart:io';

import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'itemvariantemodel_312.dart';

part 'itemmodel_302.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantItem)
class Items extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? imagePath; // CHANGED from imagePath

  @HiveField(3)
  final double? price;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final String? categoryOfItem; // category id

  @HiveField(6)
  final String? isVeg;

  @HiveField(7)
  final String? unit;

  @HiveField(8)
  final List<ItemVariante>? variant;

  @HiveField(9)
  final List<String>? choiceIds;

  @HiveField(10)
  final List<String>? extraId;

  @HiveField(11)
  double? taxRate;


  @HiveField(12)
  bool isEnabled;

  // --- IMPROVED INVENTORY FIELDS ---
  @HiveField(13)
  bool trackInventory; // RENAMED: from istrackInventory for convention

  @HiveField(14)
  double stockQuantity; // IMPROVEMENT: Made non-nullable for safety

  @HiveField(15)
  bool allowOrderWhenOutOfStock; // Allow ordering when stock is 0 or negative


  @HiveField(16)
  final bool isSoldByWeight;

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(17)
  DateTime? createdTime;

  @HiveField(18)
  DateTime? lastEditedTime;

  @HiveField(19)
  String? editedBy;

  @HiveField(20)
  int editCount;

  @HiveField(21)
  Map<String, Map<String, int>>? extraConstraints; // Map of extraId to {min, max}

  Items({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.categoryOfItem,
    this.imagePath, // CHANGED from imagePath
    this.isVeg,
    this.unit,
    this.isSoldByWeight = false,
    this.variant = const [],
    this.choiceIds = const [],
    this.extraId = const [],
    this.taxRate,
    this.isEnabled = true,
    this.trackInventory = false, // RENAMED
    this.stockQuantity = 0.0,
    this.allowOrderWhenOutOfStock = true, // Default: allow ordering when out of stock
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
    this.extraConstraints,
  });

// --- ADJUSTED HELPER LOGIC ---
  bool get hasVariants => variant?.isNotEmpty ?? false;

  bool get isInStock {
    // This logic now safely handles a null variant list.
    if (hasVariants) {
      // The '!' is safe here because hasVariants already checked for null and not empty.
      return variant!.any((v) => v.isInStock);
    }
    // If there are no variants, check the parent item.
    return !trackInventory || stockQuantity > 0;
  }




  double get finalPrice => price ?? 0;

  double get basePrice {
    if (taxRate == null || taxRate == 0) {
      return finalPrice;
    }
    return finalPrice / (1 + taxRate!);
  }

  double get taxAmount {
    return finalPrice - basePrice;
  }

  void applyTax(double newRate) {
    taxRate = newRate;
    save();
  }

  void removeTax() {
    taxRate = null;
    save();
  }

  Items copyWith({
    String? id,
    String? name,
    double? price,
    String? categoryOfItem,
    String? description,
    String? imagePath, // CHANGED from imagePath
    String? isVeg,
    String? unit,
    bool? isSoldByWeight,
    List<ItemVariante>? variant,
    List<String>? choiceIds,
    List<String>? extraId,
    bool? isEnabled,
    double? taxRate, // F
    bool? trackInventory, // RENAMED
    double? stockQuantity,
    bool? allowOrderWhenOutOfStock,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
    Map<String, Map<String, int>>? extraConstraints,
  }) {
    return Items(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        categoryOfItem: categoryOfItem ?? this.categoryOfItem,
        imagePath: imagePath ?? this.imagePath,
        // CHANGED from imagePath
        description: description ?? this.description,
        isVeg: isVeg ?? this.isVeg,
        unit: unit ?? this.unit,
        isSoldByWeight: isSoldByWeight ?? this.isSoldByWeight,
        variant: variant ?? this.variant,
        choiceIds: choiceIds ?? this.choiceIds,
        extraId: extraId ?? this.extraId,
        isEnabled: isEnabled ?? this.isEnabled,
        taxRate: taxRate ?? this.taxRate,
      trackInventory: trackInventory ?? this.trackInventory, // RENAMED
      stockQuantity: stockQuantity ?? this.stockQuantity,
      allowOrderWhenOutOfStock: allowOrderWhenOutOfStock ?? this.allowOrderWhenOutOfStock,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
      extraConstraints: extraConstraints ?? this.extraConstraints,
    );
  }

  /// Convert to map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath, // CHANGED from imagePath
      'price': price,
      'description': description,
      'categoryOfItem': categoryOfItem,
      'isVeg': isVeg,
      'unit': unit,
      'isSoldByWeight': isSoldByWeight,
      'variant': variant?.map((v) => v.toMap()).toList(),
      'choiceIds': choiceIds,
      'extraId': extraId,
      'taxRate': taxRate,
      'isEnabled': isEnabled,
      'trackInventory': trackInventory, // RENAMED
      'stockQuantity': stockQuantity,
      'allowOrderWhenOutOfStock': allowOrderWhenOutOfStock,
      'createdTime': createdTime?.toIso8601String(),
      'lastEditedTime': lastEditedTime?.toIso8601String(),
      'editedBy': editedBy,
      'editCount': editCount,
      'extraConstraints': extraConstraints,
    };
  }

  /// Create from map for import
  factory Items.fromMap(Map<String, dynamic> map) {
    // Helper logic to safely parse the price from the map
    final priceValue = map['price'];
    double? parsedPrice;
    if (priceValue is String) {
      parsedPrice = double.tryParse(priceValue);
    } else if (priceValue is num) {
      parsedPrice = priceValue.toDouble();
    }

    // Helper function to safely parse boolean values
    bool _parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == '1') return true;
        if (lower == 'false' || lower == 'no' || lower == '0') return false;
      }
      if (value is int) return value != 0;
      return defaultValue;
    }

    // 🖼️ Fix image path for imported files
    String? fixedImagePath;
    if (map['imagePath'] != null && map['imagePath'].toString().isNotEmpty) {
      try {
        // get only filename (like "123.png")
        final fileName = map['imagePath'].toString().split(Platform.pathSeparator).last;
        // rebuild full path to new app directory
        final dir = Hive.box<Items>("itemBoxs").path; // local trick to get Hive's storage folder
        if (dir != null) {
          final baseDir = Directory(dir).parent.path; // go one level up to app_flutter/
          fixedImagePath = "$baseDir/product_images/$fileName";
        }
      } catch (e) {
        fixedImagePath = map['imagePath']; // fallback
      }
    }

    return Items(
      id: map['id'] ?? '',
      // : S.tryParse(map['id'].toString()) ?? 0,
      name: map['name'] ?? '',
      imagePath: fixedImagePath,
      // CHANGED from imagePath
      price: parsedPrice,
      // FIXED price parsing
      description: map['description'],
      categoryOfItem: map['categoryOfItem'],
      isVeg: map['isVeg'],
      isSoldByWeight: _parseBool(map['isSoldByWeight'], false), // ADDED
      unit: map['unit'],
      variant: (map['variant'] as List?)?.map((v) => ItemVariante.fromMap(v as Map<String, dynamic>)).toList(),
      choiceIds: (map['choiceIds'] as List?)?.map((e) => e.toString()).toList(),
      extraId: (map['extraId'] as List?)?.map((e) => e.toString()).toList(),
      taxRate: map['taxRate']?.toDouble(),
      isEnabled: _parseBool(map['isEnabled'], true),
      trackInventory: _parseBool(map['trackInventory'], false), // RENAMED
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      allowOrderWhenOutOfStock: _parseBool(map['allowOrderWhenOutOfStock'], true),
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
      extraConstraints: map['extraConstraints'] != null
        ? Map<String, Map<String, int>>.from(
            (map['extraConstraints'] as Map).map(
              (key, value) => MapEntry(
                key.toString(),
                Map<String, int>.from(value as Map),
              ),
            ),
          )
        : null,
    );
  }
}
