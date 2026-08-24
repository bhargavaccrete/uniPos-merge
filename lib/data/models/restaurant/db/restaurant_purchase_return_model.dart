import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_purchase_return_model.g.dart';

const _uuid = Uuid();

/// Purchase Return status. Mirrors retail's `PurchaseReturnStatus`.
/// - pending: raised, waiting for the supplier to acknowledge
/// - creditReceived: supplier issued a credit note against it
/// - cancelled: withdrawn, no longer expected
enum RestaurantPurchaseReturnStatus {
  pending,
  creditReceived,
  cancelled,
}

/// Purchase Return — raw material going back to the supplier because it
/// arrived damaged and was marked `damagedHandling: 'returnToSupplier'` on a
/// [RestaurantGRNItemModel] line. Mirrors retail's `PurchaseReturnModel`,
/// scoped to restaurant's Items/Supplier models.
///
/// **No stock movement, but it does move money — later.** Damaged units are
/// excluded from `acceptedQty`, so they never entered inventory. The credit
/// applies to [RestaurantSupplierModel.currentBalance] only when the credit
/// note is recorded, guarded by [creditApplied] so a replay can't double-credit.
@HiveType(typeId: HiveTypeIds.restaurantPurchaseReturn)
class RestaurantPurchaseReturnModel extends HiveObject {
  @HiveField(0)
  final String returnId;

  /// `PR-20260813-001`, from the shared `DocumentNumberService`.
  @HiveField(1)
  final String returnNumber;

  @HiveField(2)
  final String grnId;

  @HiveField(3)
  final String grnNumber;

  @HiveField(4)
  final String poId;

  @HiveField(5)
  final String poNumber;

  @HiveField(6)
  final String supplierId;

  @HiveField(7)
  final String? supplierName;

  @HiveField(8)
  final String returnDate;

  @HiveField(9)
  final double totalQty;

  @HiveField(10)
  final double totalAmount;

  @HiveField(11)
  final String status; // RestaurantPurchaseReturnStatus as string

  @HiveField(12)
  final String? creditNoteNumber;

  @HiveField(13)
  final String? creditNoteDate;

  @HiveField(14)
  final double? creditNoteAmount;

  @HiveField(15)
  final String? notes;

  @HiveField(16)
  final String createdAt;

  @HiveField(17)
  final String updatedAt;

  /// True once the credit note reduced the supplier balance. Guards against
  /// a second `recordCreditNote` crediting the same return twice.
  @HiveField(18)
  final bool? creditApplied;

  RestaurantPurchaseReturnModel({
    required this.returnId,
    required this.returnNumber,
    required this.grnId,
    required this.grnNumber,
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    this.supplierName,
    required this.returnDate,
    this.totalQty = 0,
    this.totalAmount = 0,
    required this.status,
    this.creditNoteNumber,
    this.creditNoteDate,
    this.creditNoteAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.creditApplied,
  });

  factory RestaurantPurchaseReturnModel.create({
    required String returnNumber,
    required String grnId,
    required String grnNumber,
    required String poId,
    required String poNumber,
    required String supplierId,
    String? supplierName,
    double totalQty = 0,
    double totalAmount = 0,
    String? notes,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantPurchaseReturnModel(
      returnId: _uuid.v4(),
      returnNumber: returnNumber,
      grnId: grnId,
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      returnDate: now,
      totalQty: totalQty,
      totalAmount: totalAmount,
      status: RestaurantPurchaseReturnStatus.pending.name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  RestaurantPurchaseReturnStatus get statusEnum =>
      RestaurantPurchaseReturnStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => RestaurantPurchaseReturnStatus.pending,
      );

  bool get isOpen => statusEnum == RestaurantPurchaseReturnStatus.pending;

  bool get isCreditApplied => creditApplied == true;

  /// Signed supplier-balance adjustment that recording a credit note should
  /// apply — negative because a credit reduces what is owed. `0` means make
  /// no balance change at all. [noteAmount] is the credit note's face value,
  /// which may be less than [totalAmount] if the supplier only credits part.
  static double creditAdjustment(
    RestaurantPurchaseReturnModel r,
    double? noteAmount,
  ) {
    if (r.isCreditApplied) return 0;
    return -(noteAmount ?? r.totalAmount);
  }

  String get statusDisplay {
    switch (statusEnum) {
      case RestaurantPurchaseReturnStatus.pending:
        return 'Pending';
      case RestaurantPurchaseReturnStatus.creditReceived:
        return 'Credit Received';
      case RestaurantPurchaseReturnStatus.cancelled:
        return 'Cancelled';
    }
  }

  RestaurantPurchaseReturnModel copyWith({
    double? totalQty,
    double? totalAmount,
    String? status,
    String? creditNoteNumber,
    String? creditNoteDate,
    double? creditNoteAmount,
    String? notes,
    String? updatedAt,
    bool? creditApplied,
  }) {
    return RestaurantPurchaseReturnModel(
      returnId: returnId,
      returnNumber: returnNumber,
      grnId: grnId,
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      returnDate: returnDate,
      totalQty: totalQty ?? this.totalQty,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      creditNoteNumber: creditNoteNumber ?? this.creditNoteNumber,
      creditNoteDate: creditNoteDate ?? this.creditNoteDate,
      creditNoteAmount: creditNoteAmount ?? this.creditNoteAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      creditApplied: creditApplied ?? this.creditApplied,
    );
  }

  Map<String, dynamic> toMap() => {
        'returnId': returnId,
        'returnNumber': returnNumber,
        'grnId': grnId,
        'grnNumber': grnNumber,
        'poId': poId,
        'poNumber': poNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'returnDate': returnDate,
        'totalQty': totalQty,
        'totalAmount': totalAmount,
        'status': status,
        'creditNoteNumber': creditNoteNumber,
        'creditNoteDate': creditNoteDate,
        'creditNoteAmount': creditNoteAmount,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'creditApplied': creditApplied,
      };

  factory RestaurantPurchaseReturnModel.fromMap(Map<String, dynamic> map) {
    return RestaurantPurchaseReturnModel(
      returnId: map['returnId'] as String,
      returnNumber: map['returnNumber'] as String,
      grnId: map['grnId'] as String,
      grnNumber: map['grnNumber'] as String? ?? '',
      poId: map['poId'] as String? ?? '',
      poNumber: map['poNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String?,
      returnDate: map['returnDate'] as String,
      totalQty: (map['totalQty'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ??
          RestaurantPurchaseReturnStatus.pending.name,
      creditNoteNumber: map['creditNoteNumber'] as String?,
      creditNoteDate: map['creditNoteDate'] as String?,
      creditNoteAmount: (map['creditNoteAmount'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      creditApplied: map['creditApplied'] as bool?,
    );
  }
}
