import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
part 'cartmodel_308.g.dart';

@HiveType(typeId: 308)
class CartItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String imagePath;

  @HiveField(3)
  final double price;

  @HiveField(4)
  int quantity;

  @HiveField(5)
  final String? variantName;

  @HiveField(6)
  final double? variantPrice;

  @HiveField(7)
  final List<String>? choiceNames;

  @HiveField(8)
  final String? instruction;

  @HiveField(9) // Use the next available HiveField index
  final double? taxRate; // e.g., 0.18 for 18%

  @HiveField(10) // Use the next available HiveField index
  final double? discount; // e.g., 0.18 for 18%

  @HiveField(11)
  final String? weightDisplay;

  @HiveField(12)
  final List<Map<String, dynamic>>? extras;

  @HiveField(13)
  final String? categoryName;

  @HiveField(14)
  int? refundedQuantity;


  @HiveField(15)
  final String productId;

  @HiveField(16)
  final bool? isStockManaged;


  CartItem({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.price,
     required this.productId,
    this.isStockManaged,

    this.quantity = 1,
    this.variantName,
    this.variantPrice,
    this.choiceNames,
    this.instruction,
    this.taxRate,
    this.discount,
    this.extras,
    this.weightDisplay, // NEW: Added to constructor
    this.categoryName,
    this.refundedQuantity,
  });
// This getter calculates the price of a SINGLE item including variants and discounts.
  double get finalItemPrice {
    // Start with the base price
    double finalPrice = price;

    // Add the variant price if it exists
    // finalPrice += (variantPrice ?? 0);

    // Subtract the discount if it exists
    finalPrice -= (discount ?? 0);

    // Ensure the price doesn't go below zero
    return finalPrice.clamp(0, double.infinity);
  }

  double get totalPrice => finalItemPrice * quantity;

  // ========== CORRECTED CODE BELOW ==========
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CartItem &&
        other.id == id &&
        other.title == title &&
        other.variantName == variantName && // Check variant name
        listEquals(other.choiceNames, choiceNames); // Check choices
    // We usually don't compare price or imagePath for equality,
    // as the ID and options are what make an item unique.
  }

  @override
  int get hashCode {
    return id.hashCode ^
    title.hashCode ^
    variantName.hashCode ^
    choiceNames.hashCode; // Include choices in the hash
  }
  CartItem copyWith({
    String? id,
    String? title,
    String? productId,
    String? imagePath,
    double? price,

    bool? isStockManaged,
    int? quantity,
    String? variantName,
    double? variantPrice,
    List<String>? choiceNames,
    String? instruction,
    double? taxRate,
    double? discount,
    List <Map<String, dynamic>>? extras,
    String? weightDisplay, // NEW
    String? categoryName,
    int? refundedQuantity,

  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      price: price ?? this.price,

      isStockManaged: isStockManaged ?? this.isStockManaged,

      quantity: quantity ?? this.quantity,
      variantName: variantName ?? this.variantName,
      variantPrice: variantPrice ?? this.variantPrice,
      choiceNames: choiceNames ?? this.choiceNames,
      instruction: instruction ?? this.instruction,
      taxRate: taxRate ?? this.taxRate,
      discount: discount ?? this.discount,
      extras: extras ?? this.extras,
      weightDisplay: weightDisplay ?? this.weightDisplay, // NEW
      categoryName: categoryName ?? this.categoryName,
      refundedQuantity: refundedQuantity ?? this.refundedQuantity,
    );
  }

  // Convert to Map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'price': price,
      'quantity': quantity,
      'variantName': variantName,
      'variantPrice': variantPrice,
      'choiceNames': choiceNames,
      'instruction': instruction,
      'taxRate': taxRate,
      'discount': discount,
      'weightDisplay': weightDisplay,
      'extras': extras,
      'categoryName': categoryName,
      'refundedQuantity': refundedQuantity,
      'productId': productId,
      'isStockManaged': isStockManaged,
    };
  }

  // Create from Map for import
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      imagePath: map['imagePath'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      variantName: map['variantName'],
      variantPrice: map['variantPrice']?.toDouble(),
      choiceNames: (map['choiceNames'] as List?)?.map((e) => e.toString()).toList(),
      instruction: map['instruction'],
      taxRate: map['taxRate']?.toDouble(),
      discount: map['discount']?.toDouble(),
      weightDisplay: map['weightDisplay'],
      extras: (map['extras'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      categoryName: map['categoryName'],
      refundedQuantity: map['refundedQuantity'],
      productId: map['productId'] ?? '',
      isStockManaged: map['isStockManaged'],
    );
  }
}
