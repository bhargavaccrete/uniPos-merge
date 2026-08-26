import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'purchase_return_item_model_175.g.dart';

const _uuid = Uuid();

/// One line of a [PurchaseReturnModel].
///
/// [grnItemId] points back at the exact GRN line the damage was recorded on,
/// which is what makes partial returns traceable — you can always ask "how much
/// of this GRN line has already been returned".
@HiveType(typeId: HiveTypeIds.retailPurchaseReturnItem)
class PurchaseReturnItemModel extends HiveObject {
  @HiveField(0)
  final String returnItemId;

  @HiveField(1)
  final String returnId;

  /// The GRN line this damage came from.
  @HiveField(2)
  final String grnItemId;

  @HiveField(3)
  final String variantId;

  @HiveField(4)
  final String productId;

  @HiveField(5)
  final String? productName; // Denormalized for display

  @HiveField(6)
  final String? variantInfo; // e.g. "Size: L, Color: Red"

  @HiveField(7)
  final double returnedQty;

  @HiveField(8)
  final double? costPrice;

  /// returnedQty * costPrice — the value being sent back.
  @HiveField(9)
  final double? totalAmount;

  @HiveField(10)
  final String? remarks;

  @HiveField(11)
  final String createdAt;

  PurchaseReturnItemModel({
    required this.returnItemId,
    required this.returnId,
    required this.grnItemId,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantInfo,
    required this.returnedQty,
    this.costPrice,
    this.totalAmount,
    this.remarks,
    required this.createdAt,
  });

  factory PurchaseReturnItemModel.create({
    required String returnId,
    required String grnItemId,
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required double returnedQty,
    double? costPrice,
    String? remarks,
  }) {
    return PurchaseReturnItemModel(
      returnItemId: _uuid.v4(),
      returnId: returnId,
      grnItemId: grnItemId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
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
        'variantId': variantId,
        'productId': productId,
        'productName': productName,
        'variantInfo': variantInfo,
        'returnedQty': returnedQty,
        'costPrice': costPrice,
        'totalAmount': totalAmount,
        'remarks': remarks,
        'createdAt': createdAt,
      };

  factory PurchaseReturnItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnItemModel(
      returnItemId: map['returnItemId'] as String,
      returnId: map['returnId'] as String,
      grnItemId: map['grnItemId'] as String? ?? '',
      variantId: map['variantId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String?,
      variantInfo: map['variantInfo'] as String?,
      returnedQty: (map['returnedQty'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }
}
