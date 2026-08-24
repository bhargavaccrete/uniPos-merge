import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_purchase_return_item_model.g.dart';

const _uuid = Uuid();

/// One line of a [RestaurantPurchaseReturnModel]. [grnItemId] points back at
/// the exact GRN line the damage was recorded on, so partial returns stay
/// traceable. Mirrors retail's `PurchaseReturnItemModel`.
@HiveType(typeId: HiveTypeIds.restaurantPurchaseReturnItem)
class RestaurantPurchaseReturnItemModel extends HiveObject {
  @HiveField(0)
  final String returnItemId;

  @HiveField(1)
  final String returnId;

  @HiveField(2)
  final String grnItemId;

  @HiveField(3)
  final String itemId;

  @HiveField(4)
  final String? itemName;

  @HiveField(5)
  final double returnedQty;

  @HiveField(6)
  final double? costPrice;

  /// returnedQty * costPrice — the value being sent back.
  @HiveField(7)
  final double? totalAmount;

  @HiveField(8)
  final String? remarks;

  @HiveField(9)
  final String createdAt;

  RestaurantPurchaseReturnItemModel({
    required this.returnItemId,
    required this.returnId,
    required this.grnItemId,
    required this.itemId,
    this.itemName,
    required this.returnedQty,
    this.costPrice,
    this.totalAmount,
    this.remarks,
    required this.createdAt,
  });

  factory RestaurantPurchaseReturnItemModel.create({
    required String returnId,
    required String grnItemId,
    required String itemId,
    String? itemName,
    required double returnedQty,
    double? costPrice,
    String? remarks,
  }) {
    return RestaurantPurchaseReturnItemModel(
      returnItemId: _uuid.v4(),
      returnId: returnId,
      grnItemId: grnItemId,
      itemId: itemId,
      itemName: itemName,
      returnedQty: returnedQty,
      costPrice: costPrice,
      totalAmount: costPrice != null ? returnedQty * costPrice : null,
      remarks: remarks,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'returnItemId': returnItemId,
        'returnId': returnId,
        'grnItemId': grnItemId,
        'itemId': itemId,
        'itemName': itemName,
        'returnedQty': returnedQty,
        'costPrice': costPrice,
        'totalAmount': totalAmount,
        'remarks': remarks,
        'createdAt': createdAt,
      };

  factory RestaurantPurchaseReturnItemModel.fromMap(
      Map<String, dynamic> map) {
    return RestaurantPurchaseReturnItemModel(
      returnItemId: map['returnItemId'] as String,
      returnId: map['returnId'] as String,
      grnItemId: map['grnItemId'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String?,
      returnedQty: (map['returnedQty'] as num?)?.toDouble() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }
}
