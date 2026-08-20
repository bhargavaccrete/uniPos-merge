import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'purchase_return_model_174.g.dart';

const _uuid = Uuid();

/// Purchase Return status.
/// - pending: raised, waiting for the supplier to acknowledge
/// - creditReceived: supplier issued a credit note against it
/// - cancelled: withdrawn, no longer expected
enum PurchaseReturnStatus {
  pending,
  creditReceived,
  cancelled,
}

/// Purchase Return — goods going back to the supplier because they arrived
/// damaged and were marked `DamagedHandling.returnToSupplier` on a GRN.
///
/// **No stock movement, but it does move money — later.** Damaged units are
/// excluded from `acceptedQty`, so they never entered inventory and nothing
/// here touches it. The receipt DID bill them though: a GRN accrues the full
/// received value, matching the supplier's invoice. This return is the claim to
/// get that value back, and the supplier balance drops when the credit note is
/// recorded — not when the return is raised.
///
/// [creditApplied] makes that credit exactly-once. See [creditAdjustment].
///
/// One GRN can raise several returns (partial returns), so the link is
/// many-to-one on [grnId].
@HiveType(typeId: HiveTypeIds.retailPurchaseReturn)
class PurchaseReturnModel extends HiveObject {
  @HiveField(0)
  final String returnId;

  /// `PR-20260813-001`, from DocumentNumberService.
  @HiveField(1)
  final String returnNumber;

  // --- Source documents ---
  @HiveField(2)
  final String grnId;

  @HiveField(3)
  final String grnNumber; // Denormalized for display

  @HiveField(4)
  final String poId;

  @HiveField(5)
  final String poNumber; // Denormalized for display

  // --- Supplier ---
  @HiveField(6)
  final String supplierId;

  @HiveField(7)
  final String? supplierName; // Denormalized so history survives a rename

  // --- Totals ---
  @HiveField(8)
  final String returnDate;

  @HiveField(9)
  final int totalQty;

  @HiveField(10)
  final double totalAmount;

  @HiveField(11)
  final String status; // PurchaseReturnStatus as string

  // --- Supplier credit note (recorded when it arrives) ---
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

  /// True once the credit note reduced the supplier balance. Guards against a
  /// second `recordCreditNote` crediting the same return twice.
  ///
  /// Nullable so returns written before credits existed deserialize as `false`
  /// instead of failing the adapter's cast. Read through [isCreditApplied].
  @HiveField(18)
  final bool? creditApplied;

  PurchaseReturnModel({
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

  factory PurchaseReturnModel.create({
    required String returnNumber,
    required String grnId,
    required String grnNumber,
    required String poId,
    required String poNumber,
    required String supplierId,
    String? supplierName,
    int totalQty = 0,
    double totalAmount = 0,
    String? notes,
  }) {
    final now = DateTime.now().toIso8601String();
    return PurchaseReturnModel(
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
      status: PurchaseReturnStatus.pending.name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  PurchaseReturnStatus get statusEnum => PurchaseReturnStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => PurchaseReturnStatus.pending,
      );

  bool get isOpen => statusEnum == PurchaseReturnStatus.pending;

  /// Whether the supplier balance has already been credited for this return.
  bool get isCreditApplied => creditApplied == true;

  /// Signed supplier-balance adjustment that recording a credit note should
  /// apply — negative because a credit reduces what is owed. `0` means make no
  /// balance change at all.
  ///
  /// Pure and static so the money decision can be tested without Hive or the
  /// service locator; [_DamagedGoodsStore.recordCreditNote] is the only caller
  /// that turns a non-zero result into an actual write.
  ///
  /// [noteAmount] is the credit note's face value, which may be less than
  /// [totalAmount] when the supplier only credits part of the return.
  static double creditAdjustment(PurchaseReturnModel r, double? noteAmount) {
    if (r.isCreditApplied) return 0;
    return -(noteAmount ?? r.totalAmount);
  }

  String get statusDisplay {
    switch (statusEnum) {
      case PurchaseReturnStatus.pending:
        return 'Pending';
      case PurchaseReturnStatus.creditReceived:
        return 'Credit Received';
      case PurchaseReturnStatus.cancelled:
        return 'Cancelled';
    }
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

  factory PurchaseReturnModel.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnModel(
      returnId: map['returnId'] as String,
      returnNumber: map['returnNumber'] as String,
      grnId: map['grnId'] as String,
      grnNumber: map['grnNumber'] as String? ?? '',
      poId: map['poId'] as String? ?? '',
      poNumber: map['poNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String?,
      returnDate: map['returnDate'] as String,
      totalQty: (map['totalQty'] as num?)?.toInt() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? PurchaseReturnStatus.pending.name,
      creditNoteNumber: map['creditNoteNumber'] as String?,
      creditNoteDate: map['creditNoteDate'] as String?,
      creditNoteAmount: (map['creditNoteAmount'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      creditApplied: map['creditApplied'] as bool?,
    );
  }

  PurchaseReturnModel copyWith({
    int? totalQty,
    double? totalAmount,
    String? status,
    String? creditNoteNumber,
    String? creditNoteDate,
    double? creditNoteAmount,
    String? notes,
    String? updatedAt,
    bool? creditApplied,
  }) {
    return PurchaseReturnModel(
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
}
