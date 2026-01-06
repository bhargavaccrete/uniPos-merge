import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'grn_item_model_214.g.dart';

const _uuid = Uuid();

/// Damaged Item Handling Method
enum DamagedHandling {
  none,           // No damaged items
  keepForClaim,   // Keep and file claim with supplier
  returnToSupplier, // Return to supplier (creates purchase return)
  writeOff,       // Write off as loss
}

/// GRN Item - Records what was ordered vs what was actually received
/// This is where we compare: Ordered 50, Received 45
@HiveType(typeId: HiveTypeIds.retailGrnItem)
class GRNItemModel extends HiveObject {
  @HiveField(0)
  final String grnItemId;

  @HiveField(1)
  final String grnId; // Links to GRNModel

  @HiveField(2)
  final String poItemId; // Links to original PO item

  @HiveField(3)
  final String variantId; // Links to VarianteModel

  @HiveField(4)
  final String productId; // Links to ProductModel

  @HiveField(5)
  final String? productName; // Denormalized for display

  @HiveField(6)
  final String? variantInfo; // e.g., "Size: L, Color: Red"

  @HiveField(7)
  final int orderedQty; // Quantity that was ordered in PO

  @HiveField(8)
  final int receivedQty; // Quantity actually received (total physical receipt)

  @HiveField(9)
  final int acceptedQty; // Quantity accepted into stock (good items only)

  @HiveField(10)
  final int? damagedQty; // Quantity damaged

  @HiveField(11)
  final String? damagedHandling; // How to handle damaged items (DamagedHandling enum)

  @HiveField(12)
  final double? costPrice; // Actual cost price per unit

  @HiveField(13)
  final double? totalAmount; // acceptedQty * costPrice (only for good items)

  @HiveField(14)
  final String? remarks; // Notes about this item

  @HiveField(15)
  final String createdAt;

  @HiveField(16)
  final double? damagedAmount; // Cost of damaged items (for claims/returns)

  GRNItemModel({
    required this.grnItemId,
    required this.grnId,
    required this.poItemId,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantInfo,
    required this.orderedQty,
    required this.receivedQty,
    required this.acceptedQty,
    this.damagedQty,
    this.damagedHandling,
    this.costPrice,
    this.totalAmount,
    this.remarks,
    required this.createdAt,
    this.damagedAmount,
  });

  factory GRNItemModel.create({
    required String grnId,
    required String poItemId,
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required int orderedQty,
    required int receivedQty,
    required int acceptedQty,
    int? damagedQty,
    DamagedHandling? damagedHandling,
    double? costPrice,
    String? remarks,
  }) {
    final now = DateTime.now().toIso8601String();
    final damaged = damagedQty ?? 0;

    return GRNItemModel(
      grnItemId: _uuid.v4(),
      grnId: grnId,
      poItemId: poItemId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
      orderedQty: orderedQty,
      receivedQty: receivedQty,
      acceptedQty: acceptedQty,
      damagedQty: damagedQty,
      damagedHandling: damagedHandling?.name,
      costPrice: costPrice,
      totalAmount: costPrice != null ? acceptedQty * costPrice : null,
      damagedAmount: costPrice != null && damaged > 0 ? damaged * costPrice : null,
      remarks: remarks,
      createdAt: now,
    );
  }

  /// Shortage quantity (ordered but not received)
  int get shortageQty => orderedQty - receivedQty;

  /// Check if fully received
  bool get isFullyReceived => receivedQty >= orderedQty;

  /// Check if partially received
  bool get isPartiallyReceived => receivedQty > 0 && receivedQty < orderedQty;

  /// Check if nothing received
  bool get isNotReceived => receivedQty == 0;

  /// Good quantity (received minus damaged)
  int get goodQty => receivedQty - (damagedQty ?? 0);

  Map<String, dynamic> toMap() {
    return {
      'grnItemId': grnItemId,
      'grnId': grnId,
      'poItemId': poItemId,
      'variantId': variantId,
      'productId': productId,
      'productName': productName,
      'variantInfo': variantInfo,
      'orderedQty': orderedQty,
      'receivedQty': receivedQty,
      'acceptedQty': acceptedQty,
      'damagedQty': damagedQty,
      'damagedHandling': damagedHandling,
      'damagedAmount': damagedAmount,
      'costPrice': costPrice,
      'totalAmount': totalAmount,
      'remarks': remarks,
      'createdAt': createdAt,
    };
  }

  factory GRNItemModel.fromMap(Map<String, dynamic> map) {
    return GRNItemModel(
      grnItemId: map['grnItemId'] as String,
      grnId: map['grnId'] as String,
      poItemId: map['poItemId'] as String,
      variantId: map['variantId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String?,
      variantInfo: map['variantInfo'] as String?,
      orderedQty: (map['orderedQty'] as num).toInt(),
      receivedQty: (map['receivedQty'] as num).toInt(),
      acceptedQty: (map['acceptedQty'] as num).toInt(),
      damagedQty: (map['damagedQty'] as num?)?.toInt(),
      damagedHandling: map['damagedHandling'] as String?,
      damagedAmount: (map['damagedAmount'] as num?)?.toDouble(),
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  GRNItemModel copyWith({
    String? grnItemId,
    String? grnId,
    String? poItemId,
    String? variantId,
    String? productId,
    String? productName,
    String? variantInfo,
    int? orderedQty,
    int? receivedQty,
    int? acceptedQty,
    int? damagedQty,
    String? damagedHandling,
    double? damagedAmount,
    double? costPrice,
    double? totalAmount,
    String? remarks,
    String? createdAt,
  }) {
    return GRNItemModel(
      grnItemId: grnItemId ?? this.grnItemId,
      grnId: grnId ?? this.grnId,
      poItemId: poItemId ?? this.poItemId,
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantInfo: variantInfo ?? this.variantInfo,
      orderedQty: orderedQty ?? this.orderedQty,
      receivedQty: receivedQty ?? this.receivedQty,
      acceptedQty: acceptedQty ?? this.acceptedQty,
      damagedQty: damagedQty ?? this.damagedQty,
      damagedHandling: damagedHandling ?? this.damagedHandling,
      damagedAmount: damagedAmount ?? this.damagedAmount,
      costPrice: costPrice ?? this.costPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get damaged handling as enum
  DamagedHandling? get damagedHandlingEnum {
    if (damagedHandling == null) return null;
    try {
      return DamagedHandling.values.firstWhere((e) => e.name == damagedHandling);
    } catch (e) {
      return null;
    }
  }

  /// Display text for damaged handling
  String get damagedHandlingDisplay {
    switch (damagedHandlingEnum) {
      case DamagedHandling.keepForClaim:
        return 'Keep for Claim';
      case DamagedHandling.returnToSupplier:
        return 'Return to Supplier';
      case DamagedHandling.writeOff:
        return 'Write Off';
      default:
        return 'None';
    }
  }
}