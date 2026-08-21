import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'hold_sale_item_model_210.g.dart';

@HiveType(typeId: HiveTypeIds.retailHoldSaleItem)
class HoldSaleItemModel extends HiveObject {
  @HiveField(0)
  final String holdSaleItemId;

  @HiveField(1)
  final String holdSaleId; // Reference to HoldSaleModel

  @HiveField(2)
  final String variantId;

  @HiveField(3)
  final String productId;

  @HiveField(4)
  final String productName;




  /// Variant descriptors as `{attributeName: value}`, captured when the sale
  /// was parked.
  @HiveField(17)
  final Map<String, String>? attributes;

  @HiveField(8)
  final double price;

  @HiveField(9)
  final int qty;

  @HiveField(10)
  final double total;

  @HiveField(11)
  final String? barcode;

  @HiveField(12)
  final String createdAt;

  // ==================== TAX BASIS ====================
  // Parked with the line so restoring reproduces the bill it was parked at.
  // Without these a park/restore across a rate change silently reprices.

  @HiveField(13)
  final double? gstRate; // percent, e.g. 18

  @HiveField(14)
  final double? taxableAmount; // after this line's share of the discount

  @HiveField(15)
  final double? gstAmount;

  @HiveField(16)
  final double? discountAmount;

  // ==================== PRICE OVERRIDE ====================
  // Parked WITH the line so restoring reproduces the overridden bill, and the
  // reason survives a park that spans a shift change.
  // Indices continue at 18: 5-7 are retired legacy columns and must not be
  // reused, or old parked rows would deserialize as the wrong type.

  /// Catalogue price at override time. Null = the line was not overridden.
  @HiveField(18)
  final double? originalPrice;

  /// `PriceOverrideReason.code`.
  @HiveField(19)
  final String? overrideReason;

  @HiveField(20)
  final String? overrideNote;

  HoldSaleItemModel({
    required this.holdSaleItemId,
    required this.holdSaleId,
    required this.variantId,
    required this.productId,
    required this.productName,
    this.attributes,
    required this.price,
    required this.qty,
    required this.total,
    this.barcode,
    required this.createdAt,
    this.gstRate,
    this.taxableAmount,
    this.gstAmount,
    this.discountAmount,
    this.originalPrice,
    this.overrideReason,
    this.overrideNote,
  });

  factory HoldSaleItemModel.create({
    required String holdSaleId,
    required String variantId,
    required String productId,
    required String productName,
    Map<String, String>? attributes,
    required double price,
    required int qty,
    String? barcode,
    double? gstRate,
    double? taxableAmount,
    double? gstAmount,
    double? discountAmount,
    double? originalPrice,
    String? overrideReason,
    String? overrideNote,
  }) {
    final now = DateTime.now().toIso8601String();
    final holdSaleItemId = '${holdSaleId}_${variantId}_${DateTime.now().millisecondsSinceEpoch}';

    return HoldSaleItemModel(
      holdSaleItemId: holdSaleItemId,
      holdSaleId: holdSaleId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      attributes: attributes,
      price: price,
      qty: qty,
      total: price * qty,
      barcode: barcode,
      createdAt: now,
      gstRate: gstRate,
      taxableAmount: taxableAmount,
      gstAmount: gstAmount,
      discountAmount: discountAmount,
      originalPrice: originalPrice,
      overrideReason: overrideReason,
      overrideNote: overrideNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'holdSaleItemId': holdSaleItemId,
      'holdSaleId': holdSaleId,
      'variantId': variantId,
      'productId': productId,
      'productName': productName,
      'attributes': attributes,
      'price': price,
      'qty': qty,
      'total': total,
      'barcode': barcode,
      'createdAt': createdAt,
      'gstRate': gstRate,
      'taxableAmount': taxableAmount,
      'gstAmount': gstAmount,
      'discountAmount': discountAmount,
      'originalPrice': originalPrice,
      'overrideReason': overrideReason,
      'overrideNote': overrideNote,
    };
  }

  factory HoldSaleItemModel.fromMap(Map<String, dynamic> map) {
    return HoldSaleItemModel(
      holdSaleItemId: map['holdSaleItemId'] as String,
      holdSaleId: map['holdSaleId'] as String,
      variantId: map['variantId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      attributes: (map['attributes'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      price: (map['price'] as num).toDouble(),
      qty: (map['qty'] as num).toInt(),
      total: (map['total'] as num).toDouble(),
      barcode: map['barcode'] as String?,
      createdAt: map['createdAt'] as String,
      gstRate: (map['gstRate'] as num?)?.toDouble(),
      taxableAmount: (map['taxableAmount'] as num?)?.toDouble(),
      gstAmount: (map['gstAmount'] as num?)?.toDouble(),
      discountAmount: (map['discountAmount'] as num?)?.toDouble(),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      overrideReason: map['overrideReason'] as String?,
      overrideNote: map['overrideNote'] as String?,
    );
  }
}