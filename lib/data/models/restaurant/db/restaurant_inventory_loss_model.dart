import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_inventory_loss_model.g.dart';

const _uuid = Uuid();

/// Where a loss originated. Mirrors retail's `InventoryLossSource`.
class RestaurantInventoryLossSource {
  RestaurantInventoryLossSource._();
  static const String grnDamage = 'grn_damage';

  /// Raised by hand after a supplier rejected the claim for these goods.
  static const String claimRejected = 'claim_rejected';

  /// Raised by a manual stock adjustment whose reason was loss-bearing
  /// (breakage, expiry, theft, wastage). These units WERE in inventory, so
  /// `RestaurantStockAdjustmentService` removes them as well as recording
  /// the loss.
  static const String stockAdjustment = 'stock_adjustment';
}

/// Inventory Loss — raw-material stock the business absorbed the cost of.
/// Mirrors retail's `InventoryLossModel`.
///
/// **Never decrements stock itself.** For the GRN sources there is nothing
/// to subtract (the units never entered stock); for an adjustment the
/// caller has already moved the stock and this row only records the cost.
@HiveType(typeId: HiveTypeIds.restaurantInventoryLoss)
class RestaurantInventoryLossModel extends HiveObject {
  @HiveField(0)
  final String lossId;

  /// `LOSS-20260813-001`, from the shared `DocumentNumberService`.
  @HiveField(1)
  final String lossNumber;

  /// See [RestaurantInventoryLossSource].
  @HiveField(2)
  final String source;

  @HiveField(3)
  final String? grnId;

  @HiveField(4)
  final String? grnNumber;

  @HiveField(5)
  final String? grnItemId;

  @HiveField(6)
  final String? poId;

  @HiveField(7)
  final String? supplierId;

  @HiveField(8)
  final String? supplierName;

  @HiveField(9)
  final String itemId;

  @HiveField(10)
  final String? itemName;

  @HiveField(11)
  final double quantity;

  @HiveField(12)
  final double? costPrice;

  /// quantity * costPrice — what the loss cost the business.
  @HiveField(13)
  final double lossValue;

  @HiveField(14)
  final String reason;

  @HiveField(15)
  final String? note;

  @HiveField(16)
  final String recordedAt;

  RestaurantInventoryLossModel({
    required this.lossId,
    required this.lossNumber,
    required this.source,
    this.grnId,
    this.grnNumber,
    this.grnItemId,
    this.poId,
    this.supplierId,
    this.supplierName,
    required this.itemId,
    this.itemName,
    required this.quantity,
    this.costPrice,
    this.lossValue = 0,
    required this.reason,
    this.note,
    required this.recordedAt,
  });

  factory RestaurantInventoryLossModel.create({
    required String lossNumber,
    String source = RestaurantInventoryLossSource.grnDamage,
    String? grnId,
    String? grnNumber,
    String? grnItemId,
    String? poId,
    String? supplierId,
    String? supplierName,
    required String itemId,
    String? itemName,
    required double quantity,
    double? costPrice,
    required String reason,
    String? note,
  }) {
    return RestaurantInventoryLossModel(
      lossId: _uuid.v4(),
      lossNumber: lossNumber,
      source: source,
      grnId: grnId,
      grnNumber: grnNumber,
      grnItemId: grnItemId,
      poId: poId,
      supplierId: supplierId,
      supplierName: supplierName,
      itemId: itemId,
      itemName: itemName,
      quantity: quantity,
      costPrice: costPrice,
      lossValue: costPrice != null ? quantity * costPrice : 0,
      reason: reason,
      note: note,
      recordedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'lossId': lossId,
        'lossNumber': lossNumber,
        'source': source,
        'grnId': grnId,
        'grnNumber': grnNumber,
        'grnItemId': grnItemId,
        'poId': poId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'costPrice': costPrice,
        'lossValue': lossValue,
        'reason': reason,
        'note': note,
        'recordedAt': recordedAt,
      };

  factory RestaurantInventoryLossModel.fromMap(Map<String, dynamic> map) {
    return RestaurantInventoryLossModel(
      lossId: map['lossId'] as String,
      lossNumber: map['lossNumber'] as String,
      source: map['source'] as String? ??
          RestaurantInventoryLossSource.grnDamage,
      grnId: map['grnId'] as String?,
      grnNumber: map['grnNumber'] as String?,
      grnItemId: map['grnItemId'] as String?,
      poId: map['poId'] as String?,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      lossValue: (map['lossValue'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String? ?? 'Damaged on receipt',
      note: map['note'] as String?,
      recordedAt: map['recordedAt'] as String,
    );
  }
}
