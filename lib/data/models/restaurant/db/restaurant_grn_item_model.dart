import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_grn_item_model.g.dart';

const _uuid = Uuid();

/// One line of a [RestaurantGRNModel] — compares what was ordered against
/// what actually arrived. Confirming the parent GRN adds [acceptedQty] to
/// the item's stock and records [costPrice] as its `lastPurchaseCost`
/// (see docs/inventory_recipe_system_plan.md §6.1).
@HiveType(typeId: HiveTypeIds.restaurantGrnItem)
class RestaurantGRNItemModel extends HiveObject {
  @HiveField(0)
  final String grnItemId;

  @HiveField(1)
  final String grnId;

  @HiveField(2)
  final String poItemId;

  @HiveField(3)
  final String itemId;

  @HiveField(4)
  final String? itemName;

  @HiveField(5)
  final double orderedQty;

  @HiveField(6)
  final double receivedQty;

  @HiveField(7)
  final double acceptedQty; // enters stock

  @HiveField(8)
  final double? damagedQty;

  @HiveField(9)
  final double? costPrice; // per unit, becomes item.lastPurchaseCost

  @HiveField(10)
  final double? totalAmount; // acceptedQty * costPrice

  @HiveField(11)
  final String? remarks;

  @HiveField(12)
  final String createdAt;

  /// How a damaged line is being handled: `'returnToSupplier'` (raises a
  /// `RestaurantPurchaseReturnModel`), `'keepForClaim'` (raises a
  /// `RestaurantSupplierClaimModel`), or `'writeOff'` (raises a
  /// `RestaurantInventoryLossModel` directly). Null when [damagedQty] is
  /// null/zero — mirrors retail's `DamagedHandling` enum, stored as a plain
  /// string here since restaurant has no shared enum module to import it from.
  @HiveField(13)
  final String? damagedHandling;

  RestaurantGRNItemModel({
    required this.grnItemId,
    required this.grnId,
    required this.poItemId,
    required this.itemId,
    this.itemName,
    required this.orderedQty,
    required this.receivedQty,
    required this.acceptedQty,
    this.damagedQty,
    this.costPrice,
    this.totalAmount,
    this.remarks,
    required this.createdAt,
    this.damagedHandling,
  });

  factory RestaurantGRNItemModel.create({
    required String grnId,
    required String poItemId,
    required String itemId,
    String? itemName,
    required double orderedQty,
    required double receivedQty,
    required double acceptedQty,
    double? damagedQty,
    double? costPrice,
    String? remarks,
    String? damagedHandling,
  }) {
    return RestaurantGRNItemModel(
      grnItemId: _uuid.v4(),
      grnId: grnId,
      poItemId: poItemId,
      itemId: itemId,
      itemName: itemName,
      orderedQty: orderedQty,
      receivedQty: receivedQty,
      acceptedQty: acceptedQty,
      damagedQty: damagedQty,
      costPrice: costPrice,
      totalAmount: costPrice != null ? acceptedQty * costPrice : null,
      remarks: remarks,
      createdAt: DateTime.now().toIso8601String(),
      damagedHandling: damagedHandling,
    );
  }

  double get shortageQty => orderedQty - receivedQty;
  double get goodQty => receivedQty - (damagedQty ?? 0);

  Map<String, dynamic> toMap() => {
        'grnItemId': grnItemId,
        'grnId': grnId,
        'poItemId': poItemId,
        'itemId': itemId,
        'itemName': itemName,
        'orderedQty': orderedQty,
        'receivedQty': receivedQty,
        'acceptedQty': acceptedQty,
        'damagedQty': damagedQty,
        'costPrice': costPrice,
        'totalAmount': totalAmount,
        'remarks': remarks,
        'createdAt': createdAt,
        'damagedHandling': damagedHandling,
      };

  factory RestaurantGRNItemModel.fromMap(Map<String, dynamic> map) {
    return RestaurantGRNItemModel(
      grnItemId: map['grnItemId'] as String,
      grnId: map['grnId'] as String,
      poItemId: map['poItemId'] as String,
      itemId: map['itemId'] as String,
      itemName: map['itemName'] as String?,
      orderedQty: (map['orderedQty'] as num?)?.toDouble() ?? 0,
      receivedQty: (map['receivedQty'] as num?)?.toDouble() ?? 0,
      acceptedQty: (map['acceptedQty'] as num?)?.toDouble() ?? 0,
      damagedQty: (map['damagedQty'] as num?)?.toDouble(),
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
      damagedHandling: map['damagedHandling'] as String?,
    );
  }
}
