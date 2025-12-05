import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'purchase_order_item_model_212.g.dart';

const _uuid = Uuid();

/// PO Item - Just what we ordered from supplier
/// No receiving tracking here - that's handled by GRN (Goods Received Note)
@HiveType(typeId: 212)
class PurchaseOrderItemModel extends HiveObject {
  @HiveField(0)
  final String poItemId;

  @HiveField(1)
  final String poId; // Links to PurchaseOrderModel

  @HiveField(2)
  final String variantId; // Links to VarianteModel

  @HiveField(3)
  final String productId; // Links to ProductModel

  @HiveField(4)
  final String? productName; // Denormalized for display

  @HiveField(5)
  final String? variantInfo; // e.g., "Size: L, Color: Red"

  @HiveField(6)
  final int orderedQty; // Quantity we want to order

  @HiveField(7)
  final double? estimatedPrice; // Optional price estimation per unit

  @HiveField(8)
  final double? estimatedTotal; // orderedQty * estimatedPrice

  @HiveField(9)
  final String createdAt;

  PurchaseOrderItemModel({
    required this.poItemId,
    required this.poId,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantInfo,
    required this.orderedQty,
    this.estimatedPrice,
    this.estimatedTotal,
    required this.createdAt,
  });

  factory PurchaseOrderItemModel.create({
    required String poId,
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required int orderedQty,
    double? estimatedPrice,
  }) {
    final now = DateTime.now().toIso8601String();

    return PurchaseOrderItemModel(
      poItemId: _uuid.v4(),
      poId: poId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
      orderedQty: orderedQty,
      estimatedPrice: estimatedPrice,
      estimatedTotal: estimatedPrice != null ? orderedQty * estimatedPrice : null,
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'poItemId': poItemId,
      'poId': poId,
      'variantId': variantId,
      'productId': productId,
      'productName': productName,
      'variantInfo': variantInfo,
      'orderedQty': orderedQty,
      'estimatedPrice': estimatedPrice,
      'estimatedTotal': estimatedTotal,
      'createdAt': createdAt,
    };
  }

  PurchaseOrderItemModel copyWith({
    String? poItemId,
    String? poId,
    String? variantId,
    String? productId,
    String? productName,
    String? variantInfo,
    int? orderedQty,
    double? estimatedPrice,
    double? estimatedTotal,
    String? createdAt,
  }) {
    return PurchaseOrderItemModel(
      poItemId: poItemId ?? this.poItemId,
      poId: poId ?? this.poId,
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantInfo: variantInfo ?? this.variantInfo,
      orderedQty: orderedQty ?? this.orderedQty,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}