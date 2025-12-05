import 'package:hive/hive.dart';

part 'hold_sale_item_model_210.g.dart';

@HiveType(typeId: 210)
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

  @HiveField(5)
  final String? size;

  @HiveField(6)
  final String? color;

  @HiveField(7)
  final String? weight;

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

  HoldSaleItemModel({
    required this.holdSaleItemId,
    required this.holdSaleId,
    required this.variantId,
    required this.productId,
    required this.productName,
    this.size,
    this.color,
    this.weight,
    required this.price,
    required this.qty,
    required this.total,
    this.barcode,
    required this.createdAt,
  });

  factory HoldSaleItemModel.create({
    required String holdSaleId,
    required String variantId,
    required String productId,
    required String productName,
    String? size,
    String? color,
    String? weight,
    required double price,
    required int qty,
    String? barcode,
  }) {
    final now = DateTime.now().toIso8601String();
    final holdSaleItemId = '${holdSaleId}_${variantId}_${DateTime.now().millisecondsSinceEpoch}';

    return HoldSaleItemModel(
      holdSaleItemId: holdSaleItemId,
      holdSaleId: holdSaleId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      size: size,
      color: color,
      weight: weight,
      price: price,
      qty: qty,
      total: price * qty,
      barcode: barcode,
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'holdSaleItemId': holdSaleItemId,
      'holdSaleId': holdSaleId,
      'variantId': variantId,
      'productId': productId,
      'productName': productName,
      'size': size,
      'color': color,
      'weight': weight,
      'price': price,
      'qty': qty,
      'total': total,
      'barcode': barcode,
      'createdAt': createdAt,
    };
  }
}