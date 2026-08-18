import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'supplier_claim_model_176.g.dart';

const _uuid = Uuid();

/// Supplier Claim status.
/// - pending: raised with the supplier, awaiting their decision
/// - approved: supplier accepted the claim, settlement still outstanding
/// - rejected: supplier refused it — the loss stays with us
/// - settled: closed, compensation received or written down
enum SupplierClaimStatus {
  pending,
  approved,
  rejected,
  settled,
}

/// Supplier Claim — damaged goods kept on site while compensation is pursued
/// (`DamagedHandling.keepForClaim` on a GRN line).
///
/// **Deliberately inert on both ledgers.** Inventory is untouched (the goods
/// are damaged and were never accepted into stock) and the supplier balance is
/// untouched (damaged units were never billed). A claim is an open question,
/// not a transaction — it stays open until [status] resolves.
///
/// If a claim is ultimately rejected, the goods are a real loss; recording that
/// outcome is what [SupplierClaimStatus.rejected] captures, and the follow-up
/// write-off is a separate deliberate act rather than an automatic side effect.
@HiveType(typeId: HiveTypeIds.retailSupplierClaim)
class SupplierClaimModel extends HiveObject {
  @HiveField(0)
  final String claimId;

  /// `CLM-20260813-001`, from DocumentNumberService.
  @HiveField(1)
  final String claimNumber;

  // --- Source documents ---
  @HiveField(2)
  final String grnId;

  @HiveField(3)
  final String grnNumber;

  @HiveField(4)
  final String poId;

  @HiveField(5)
  final String poNumber;

  // --- Supplier ---
  @HiveField(6)
  final String supplierId;

  @HiveField(7)
  final String? supplierName;

  // --- Claim body ---
  @HiveField(8)
  final String claimDate;

  @HiveField(9)
  final int totalQty;

  /// Value being claimed for — informational only, never posted to a ledger.
  @HiveField(10)
  final double totalAmount;

  @HiveField(11)
  final String status; // SupplierClaimStatus as string

  // --- Resolution ---
  @HiveField(12)
  final String? resolutionNote;

  @HiveField(13)
  final String? resolvedAt;

  @HiveField(14)
  final String? notes;

  @HiveField(15)
  final String createdAt;

  @HiveField(16)
  final String updatedAt;

  SupplierClaimModel({
    required this.claimId,
    required this.claimNumber,
    required this.grnId,
    required this.grnNumber,
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    this.supplierName,
    required this.claimDate,
    this.totalQty = 0,
    this.totalAmount = 0,
    required this.status,
    this.resolutionNote,
    this.resolvedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierClaimModel.create({
    required String claimNumber,
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
    return SupplierClaimModel(
      claimId: _uuid.v4(),
      claimNumber: claimNumber,
      grnId: grnId,
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      claimDate: now,
      totalQty: totalQty,
      totalAmount: totalAmount,
      status: SupplierClaimStatus.pending.name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  SupplierClaimStatus get statusEnum => SupplierClaimStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => SupplierClaimStatus.pending,
      );

  /// Still awaiting a supplier decision.
  bool get isOpen => statusEnum == SupplierClaimStatus.pending;

  /// Decision made but not yet closed out.
  bool get isResolved =>
      statusEnum == SupplierClaimStatus.rejected ||
      statusEnum == SupplierClaimStatus.settled;

  String get statusDisplay {
    switch (statusEnum) {
      case SupplierClaimStatus.pending:
        return 'Pending';
      case SupplierClaimStatus.approved:
        return 'Approved';
      case SupplierClaimStatus.rejected:
        return 'Rejected';
      case SupplierClaimStatus.settled:
        return 'Settled';
    }
  }

  Map<String, dynamic> toMap() => {
        'claimId': claimId,
        'claimNumber': claimNumber,
        'grnId': grnId,
        'grnNumber': grnNumber,
        'poId': poId,
        'poNumber': poNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'claimDate': claimDate,
        'totalQty': totalQty,
        'totalAmount': totalAmount,
        'status': status,
        'resolutionNote': resolutionNote,
        'resolvedAt': resolvedAt,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory SupplierClaimModel.fromMap(Map<String, dynamic> map) {
    return SupplierClaimModel(
      claimId: map['claimId'] as String,
      claimNumber: map['claimNumber'] as String,
      grnId: map['grnId'] as String? ?? '',
      grnNumber: map['grnNumber'] as String? ?? '',
      poId: map['poId'] as String? ?? '',
      poNumber: map['poNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String?,
      claimDate: map['claimDate'] as String,
      totalQty: (map['totalQty'] as num?)?.toInt() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? SupplierClaimStatus.pending.name,
      resolutionNote: map['resolutionNote'] as String?,
      resolvedAt: map['resolvedAt'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }

  SupplierClaimModel copyWith({
    int? totalQty,
    double? totalAmount,
    String? status,
    String? resolutionNote,
    String? resolvedAt,
    String? notes,
    String? updatedAt,
  }) {
    return SupplierClaimModel(
      claimId: claimId,
      claimNumber: claimNumber,
      grnId: grnId,
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      claimDate: claimDate,
      totalQty: totalQty ?? this.totalQty,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }
}
