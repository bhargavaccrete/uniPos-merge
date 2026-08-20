import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'inventory_loss_model_178.g.dart';

const _uuid = Uuid();

/// Where a loss originated. Only [grnDamage] exists today; the field is here so
/// later sources (expiry, breakage on the shop floor, stock count shortfall)
/// can share the same report without a model change.
class InventoryLossSource {
  InventoryLossSource._();
  static const String grnDamage = 'grn_damage';

  /// Raised by hand after a supplier rejected the claim for these goods, so
  /// the already-billed damage becomes the business's cost.
  static const String claimRejected = 'claim_rejected';
}

/// Inventory Loss — damaged goods written off at receipt
/// (`DamagedHandling.writeOff` on a GRN line).
///
/// **Flat by design.** Purchase returns and claims are documents with a
/// lifecycle and a counterparty; a write-off is terminal the moment it's
/// recorded and has neither. One row per damaged GRN line also makes the
/// damaged-items report a single fold instead of a header/item join.
///
/// **This does NOT decrement stock.** Damaged units are excluded from
/// `acceptedQty` at GRN confirm, so they never entered inventory — subtracting
/// here would remove stock that was never added. The row exists to make the
/// loss visible and reportable, and to record its cost.
@HiveType(typeId: HiveTypeIds.retailInventoryLoss)
class InventoryLossModel extends HiveObject {
  @HiveField(0)
  final String lossId;

  /// `LOSS-20260813-001`, from DocumentNumberService.
  @HiveField(1)
  final String lossNumber;

  /// See [InventoryLossSource].
  @HiveField(2)
  final String source;

  // --- Source documents (nullable for future non-GRN losses) ---
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

  // --- What was lost ---
  @HiveField(9)
  final String variantId;

  @HiveField(10)
  final String productId;

  @HiveField(11)
  final String? productName;

  @HiveField(12)
  final String? variantInfo;

  @HiveField(13)
  final int quantity;

  @HiveField(14)
  final double? costPrice;

  /// quantity * costPrice — what the loss cost the business.
  @HiveField(15)
  final double lossValue;

  @HiveField(16)
  final String reason;

  @HiveField(17)
  final String? note;

  @HiveField(18)
  final String recordedAt;

  InventoryLossModel({
    required this.lossId,
    required this.lossNumber,
    required this.source,
    this.grnId,
    this.grnNumber,
    this.grnItemId,
    this.poId,
    this.supplierId,
    this.supplierName,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantInfo,
    required this.quantity,
    this.costPrice,
    this.lossValue = 0,
    required this.reason,
    this.note,
    required this.recordedAt,
  });

  factory InventoryLossModel.create({
    required String lossNumber,
    String source = InventoryLossSource.grnDamage,
    String? grnId,
    String? grnNumber,
    String? grnItemId,
    String? poId,
    String? supplierId,
    String? supplierName,
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required int quantity,
    double? costPrice,
    required String reason,
    String? note,
  }) {
    return InventoryLossModel(
      lossId: _uuid.v4(),
      lossNumber: lossNumber,
      source: source,
      grnId: grnId,
      grnNumber: grnNumber,
      grnItemId: grnItemId,
      poId: poId,
      supplierId: supplierId,
      supplierName: supplierName,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
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
        'variantId': variantId,
        'productId': productId,
        'productName': productName,
        'variantInfo': variantInfo,
        'quantity': quantity,
        'costPrice': costPrice,
        'lossValue': lossValue,
        'reason': reason,
        'note': note,
        'recordedAt': recordedAt,
      };

  factory InventoryLossModel.fromMap(Map<String, dynamic> map) {
    return InventoryLossModel(
      lossId: map['lossId'] as String,
      lossNumber: map['lossNumber'] as String,
      source: map['source'] as String? ?? InventoryLossSource.grnDamage,
      grnId: map['grnId'] as String?,
      grnNumber: map['grnNumber'] as String?,
      grnItemId: map['grnItemId'] as String?,
      poId: map['poId'] as String?,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      variantId: map['variantId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String?,
      variantInfo: map['variantInfo'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      lossValue: (map['lossValue'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String? ?? 'Damaged on receipt',
      note: map['note'] as String?,
      recordedAt: map['recordedAt'] as String,
    );
  }
}
