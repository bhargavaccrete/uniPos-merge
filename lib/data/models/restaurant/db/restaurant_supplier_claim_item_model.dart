import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_supplier_claim_item_model.g.dart';

const _uuid = Uuid();

/// One line of a [RestaurantSupplierClaimModel] — the damaged quantity from a
/// single GRN line being claimed for. Mirrors retail's
/// `SupplierClaimItemModel`.
@HiveType(typeId: HiveTypeIds.restaurantSupplierClaimItem)
class RestaurantSupplierClaimItemModel extends HiveObject {
  @HiveField(0)
  final String claimItemId;

  @HiveField(1)
  final String claimId;

  @HiveField(2)
  final String grnItemId;

  @HiveField(3)
  final String itemId;

  @HiveField(4)
  final String? itemName;

  @HiveField(5)
  final double claimedQty;

  @HiveField(6)
  final double? costPrice;

  @HiveField(7)
  final double? totalAmount;

  @HiveField(8)
  final String? remarks;

  @HiveField(9)
  final String createdAt;

  RestaurantSupplierClaimItemModel({
    required this.claimItemId,
    required this.claimId,
    required this.grnItemId,
    required this.itemId,
    this.itemName,
    required this.claimedQty,
    this.costPrice,
    this.totalAmount,
    this.remarks,
    required this.createdAt,
  });

  factory RestaurantSupplierClaimItemModel.create({
    required String claimId,
    required String grnItemId,
    required String itemId,
    String? itemName,
    required double claimedQty,
    double? costPrice,
    String? remarks,
  }) {
    return RestaurantSupplierClaimItemModel(
      claimItemId: _uuid.v4(),
      claimId: claimId,
      grnItemId: grnItemId,
      itemId: itemId,
      itemName: itemName,
      claimedQty: claimedQty,
      costPrice: costPrice,
      totalAmount: costPrice != null ? claimedQty * costPrice : null,
      remarks: remarks,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'claimItemId': claimItemId,
        'claimId': claimId,
        'grnItemId': grnItemId,
        'itemId': itemId,
        'itemName': itemName,
        'claimedQty': claimedQty,
        'costPrice': costPrice,
        'totalAmount': totalAmount,
        'remarks': remarks,
        'createdAt': createdAt,
      };

  factory RestaurantSupplierClaimItemModel.fromMap(Map<String, dynamic> map) {
    return RestaurantSupplierClaimItemModel(
      claimItemId: map['claimItemId'] as String,
      claimId: map['claimId'] as String,
      grnItemId: map['grnItemId'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String?,
      claimedQty: (map['claimedQty'] as num?)?.toDouble() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }
}
