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
/// **This document moves no money and no stock, by design.** Damaged units are
/// excluded from `acceptedQty`, so they never entered inventory, and the GRN
/// only bills `totalAcceptedAmount`, so they were never charged. The return is
/// the audit trail of what is going back plus a place to record the supplier's
/// credit note when it arrives.
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
    );
  }
}
