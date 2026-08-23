import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_purchase_order_item_model.g.dart';

const _uuid = Uuid();

/// One ordered line of a [RestaurantPurchaseOrderModel] — just what we
/// ordered. Receiving is tracked separately by [RestaurantGRNItemModel],
/// mirroring retail's PO/GRN split.
@HiveType(typeId: HiveTypeIds.restaurantPurchaseOrderItem)
class RestaurantPurchaseOrderItemModel extends HiveObject {
  @HiveField(0)
  final String poItemId;

  @HiveField(1)
  final String poId;

  @HiveField(2)
  final String itemId; // links to Items (must be a Raw Material)

  @HiveField(3)
  final String? itemName; // denormalized for display

  @HiveField(4)
  final double orderedQty;

  @HiveField(5)
  final double? estimatedPrice; // per unit

  @HiveField(6)
  final double? estimatedTotal;

  @HiveField(7)
  final String createdAt;

  RestaurantPurchaseOrderItemModel({
    required this.poItemId,
    required this.poId,
    required this.itemId,
    this.itemName,
    required this.orderedQty,
    this.estimatedPrice,
    this.estimatedTotal,
    required this.createdAt,
  });

  factory RestaurantPurchaseOrderItemModel.create({
    required String poId,
    required String itemId,
    String? itemName,
    required double orderedQty,
    double? estimatedPrice,
  }) {
    return RestaurantPurchaseOrderItemModel(
      poItemId: _uuid.v4(),
      poId: poId,
      itemId: itemId,
      itemName: itemName,
      orderedQty: orderedQty,
      estimatedPrice: estimatedPrice,
      estimatedTotal: estimatedPrice != null ? orderedQty * estimatedPrice : null,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'poItemId': poItemId,
        'poId': poId,
        'itemId': itemId,
        'itemName': itemName,
        'orderedQty': orderedQty,
        'estimatedPrice': estimatedPrice,
        'estimatedTotal': estimatedTotal,
        'createdAt': createdAt,
      };

  factory RestaurantPurchaseOrderItemModel.fromMap(Map<String, dynamic> map) {
    return RestaurantPurchaseOrderItemModel(
      poItemId: map['poItemId'] as String,
      poId: map['poId'] as String,
      itemId: map['itemId'] as String,
      itemName: map['itemName'] as String?,
      orderedQty: (map['orderedQty'] as num?)?.toDouble() ?? 0,
      estimatedPrice: (map['estimatedPrice'] as num?)?.toDouble(),
      estimatedTotal: (map['estimatedTotal'] as num?)?.toDouble(),
      createdAt: map['createdAt'] as String,
    );
  }
}
