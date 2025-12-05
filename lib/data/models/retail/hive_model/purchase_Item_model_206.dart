import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'purchase_Item_model_206.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 206)
class PurchaseItemModel extends HiveObject {
  @HiveField(0)
  final String purchaseItemId;

  @HiveField(1)
  final String purchaseId;      // links to PurchaseModel

  @HiveField(2)
  final String variantId;       // links to VariantModel

  @HiveField(3)
  final String productId;       // optional but helpful

  @HiveField(4)
  final int quantity;

  @HiveField(5)
  final double costPrice;

  @HiveField(6)
  final double mrp;             // selling price

  @HiveField(7)
  final double total;           // quantity * costPrice

  @HiveField(8)
  final String createdAt;

  PurchaseItemModel({
    required this.purchaseItemId,
    required this.purchaseId,
    required this.variantId,
    required this.productId,
    required this.quantity,
    required this.costPrice,
    required this.mrp,
    required this.total,
    required this.createdAt,
  });

  factory PurchaseItemModel.create({
    required String purchaseId,
    required String variantId,
    required String productId,
    required int quantity,
    required double costPrice,
    required double mrp,
  }) {
    final now = DateTime.now().toIso8601String();

    return PurchaseItemModel(
      purchaseItemId: _uuid.v4(),
      purchaseId: purchaseId,
      variantId: variantId,
      productId: productId,
      quantity: quantity,
      costPrice: costPrice,
      mrp: mrp,
      total: quantity * costPrice,
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseItemId': purchaseItemId,
      'purchaseId': purchaseId,
      'variantId': variantId,
      'productId': productId,
      'quantity': quantity,
      'costPrice': costPrice,
      'mrp': mrp,
      'total': total,
      'createdAt': createdAt,
    };
  }
}
