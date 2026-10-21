import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'inventory_loss_model_178.g.dart';

const _uuid = Uuid();

/// Where a loss originated. Sources share one report, so a new kind of loss
/// only needs a constant here rather than a model of its own.
class InventoryLossSource {
  InventoryLossSource._();
  static const String grnDamage = 'grn_damage';

  /// Raised by hand after a supplier rejected the claim for these goods, so
  /// the already-billed damage becomes the business's cost.
  static const String claimRejected = 'claim_rejected';

  /// Raised when a purchase return is cancelled: the damaged goods are not
  /// going back and no credit note is coming, so the value the GRN billed is
  /// the business's cost — dated by the cancellation.
  static const String returnCancelled = 'return_cancelled';

  /// A customer returned goods that can't be resold (damaged, defective,
  /// expired). They never re-enter stock; their cost is the business's loss.
  /// No GRN — inventory, not purchasing.
  static const String saleReturn = 'sale_return';

  /// Raised by a manual stock adjustment whose reason was loss-bearing —
  /// breakage, expiry, theft, internal use, samples. Unlike the two sources
  /// above, these units WERE in inventory, so `StockAdjustmentService` removes
  /// them as well as recording the loss. See [grnId] being null for these.
  static const String stockAdjustment = 'stock_adjustment';
}

/// Inventory Loss — stock the business absorbed the cost of.
///
/// Two very different origins share this row, distinguished by [source]:
///
/// | Source | Were the units ever in stock? | Who decrements? |
/// |---|---|---|
/// | `grnDamage`, `claimRejected` | No — excluded from `acceptedQty` at GRN confirm | nobody |
/// | `stockAdjustment` | Yes — they were on the shelf | `StockAdjustmentService` |
///
/// **So this model never decrements stock itself.** For the GRN sources there
/// is nothing to subtract; for an adjustment the caller has already moved the
/// stock and writes this row only to record the cost. Either way the row's job
/// is to make the loss visible, reportable and priced — never to move units.
///
/// **Flat by design.** Purchase returns and claims are documents with a
/// lifecycle and a counterparty; a write-off is terminal the moment it's
/// recorded and has neither. One row per damaged line also makes the
/// damaged-items report a single fold instead of a header/item join.
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
  final double quantity;

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
    required double quantity,
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
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      lossValue: (map['lossValue'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String? ?? 'Damaged on receipt',
      note: map['note'] as String?,
      recordedAt: map['recordedAt'] as String,
    );
  }
}
