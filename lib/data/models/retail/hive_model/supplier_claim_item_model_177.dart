import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'supplier_claim_item_model_177.g.dart';

const _uuid = Uuid();

/// One line of a [SupplierClaimModel] — the damaged units from a single GRN
/// line that are being claimed for.
@HiveType(typeId: HiveTypeIds.retailSupplierClaimItem)
class SupplierClaimItemModel extends HiveObject {
  @HiveField(0)
  final String claimItemId;

  @HiveField(1)
  final String claimId;

  /// The GRN line the damage was recorded on.
  @HiveField(2)
  final String grnItemId;

  @HiveField(3)
  final String variantId;

  @HiveField(4)
  final String productId;

  @HiveField(5)
  final String? productName;

  @HiveField(6)
  final String? variantInfo;

  @HiveField(7)
  final int claimedQty;

  @HiveField(8)
  final double? costPrice;

  @HiveField(9)
  final double? totalAmount;

  @HiveField(10)
  final String? remarks;

  @HiveField(11)
  final String createdAt;

  SupplierClaimItemModel({
    required this.claimItemId,
    required this.claimId,
    required this.grnItemId,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantInfo,
    required this.claimedQty,
    this.costPrice,
    this.totalAmount,
    this.remarks,
    required this.createdAt,
  });

  factory SupplierClaimItemModel.create({
    required String claimId,
    required String grnItemId,
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required int claimedQty,
    double? costPrice,
    String? remarks,
  }) {
    return SupplierClaimItemModel(
      claimItemId: _uuid.v4(),
      claimId: claimId,
      grnItemId: grnItemId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
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
        'variantId': variantId,
        'productId': productId,
        'productName': productName,
        'variantInfo': variantInfo,
        'claimedQty': claimedQty,
        'costPrice': costPrice,
        'totalAmount': totalAmount,
        'remarks': remarks,
        'createdAt': createdAt,
      };

  factory SupplierClaimItemModel.fromMap(Map<String, dynamic> map) {
    return SupplierClaimItemModel(
      claimItemId: map['claimItemId'] as String,
      claimId: map['claimId'] as String,
      grnItemId: map['grnItemId'] as String? ?? '',
      variantId: map['variantId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String?,
      variantInfo: map['variantInfo'] as String?,
      claimedQty: (map['claimedQty'] as num?)?.toInt() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }
}
