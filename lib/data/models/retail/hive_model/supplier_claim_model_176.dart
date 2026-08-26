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
/// **Inert on inventory, not on the ledger.** The goods are damaged and were
/// never accepted into stock, so nothing here touches inventory. They WERE
/// billed though — a GRN accrues the full received value, matching the
/// supplier's invoice — which is precisely why a claim is worth pursuing.
///
/// The balance moves once, at [SupplierClaimStatus.settled]; see
/// [claimBalanceAdjustment] and [creditApplied]. Approving a claim is only the
/// supplier agreeing, so it moves nothing yet.
///
/// If a claim is rejected the damage stays a real, already-paid-for cost. The
/// follow-up write-off is a separate deliberate act rather than an automatic
/// side effect, tracked by [lossRecorded].
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
  final double totalQty;

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

  /// True once settling this claim credited the supplier balance. Makes the
  /// credit exactly-once even if the transition is somehow replayed.
  ///
  /// Nullable so claims written before credits existed deserialize as `false`
  /// rather than failing the adapter's cast. Read through [isCreditApplied].
  @HiveField(17)
  final bool? creditApplied;

  /// True once a rejected claim was written off into inventory losses. Stops a
  /// second write-off duplicating the loss records. Read through
  /// [isLossRecorded].
  @HiveField(18)
  final bool? lossRecorded;

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
    this.creditApplied,
    this.lossRecorded,
  });

  factory SupplierClaimModel.create({
    required String claimNumber,
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

  /// Whether the supplier balance has already been credited for this claim.
  bool get isCreditApplied => creditApplied == true;

  /// Whether a rejected claim has already been written off as a loss.
  bool get isLossRecorded => lossRecorded == true;

  /// Signed supplier-balance adjustment a transition to [target] should apply —
  /// negative because a credit reduces what is owed. `0` means make no balance
  /// change at all.
  ///
  /// Only settlement moves money: `approved` is the supplier agreeing, not
  /// paying, and `rejected` leaves the full amount payable. Pure and static so
  /// the decision — including the exactly-once guarantee — can be tested
  /// without Hive or the service locator.
  static double claimBalanceAdjustment(
    SupplierClaimModel c,
    SupplierClaimStatus target,
  ) {
    if (target != SupplierClaimStatus.settled) return 0;
    if (c.isCreditApplied) return 0;
    return -c.totalAmount;
  }

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
        'creditApplied': creditApplied,
        'lossRecorded': lossRecorded,
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
      totalQty: (map['totalQty'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? SupplierClaimStatus.pending.name,
      resolutionNote: map['resolutionNote'] as String?,
      resolvedAt: map['resolvedAt'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      creditApplied: map['creditApplied'] as bool?,
      lossRecorded: map['lossRecorded'] as bool?,
    );
  }

  SupplierClaimModel copyWith({
    double? totalQty,
    double? totalAmount,
    String? status,
    String? resolutionNote,
    String? resolvedAt,
    String? notes,
    String? updatedAt,
    bool? creditApplied,
    bool? lossRecorded,
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
      creditApplied: creditApplied ?? this.creditApplied,
      lossRecorded: lossRecorded ?? this.lossRecorded,
    );
  }
}
