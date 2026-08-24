import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_supplier_claim_model.g.dart';

const _uuid = Uuid();

/// Supplier Claim status. Mirrors retail's `SupplierClaimStatus`.
/// - pending: raised with the supplier, awaiting their decision
/// - approved: supplier accepted the claim, settlement still outstanding
/// - rejected: supplier refused it — the loss stays with us
/// - settled: closed, compensation received or written down
enum RestaurantSupplierClaimStatus {
  pending,
  approved,
  rejected,
  settled,
}

/// Supplier Claim — damaged raw material kept on site while compensation is
/// pursued (`damagedHandling: 'keepForClaim'` on a
/// [RestaurantGRNItemModel] line). Mirrors retail's `SupplierClaimModel`.
///
/// The balance moves once, at [RestaurantSupplierClaimStatus.settled]; see
/// [claimBalanceAdjustment]. If rejected, the damage becomes a real cost — the
/// follow-up write-off into [RestaurantInventoryLossModel] is a deliberate
/// separate act, tracked by [lossRecorded].
@HiveType(typeId: HiveTypeIds.restaurantSupplierClaim)
class RestaurantSupplierClaimModel extends HiveObject {
  @HiveField(0)
  final String claimId;

  /// `CLM-20260813-001`, from the shared `DocumentNumberService`.
  @HiveField(1)
  final String claimNumber;

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
  final String claimDate;

  @HiveField(9)
  final double totalQty;

  @HiveField(10)
  final double totalAmount;

  @HiveField(11)
  final String status; // RestaurantSupplierClaimStatus as string

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

  /// True once settling this claim credited the supplier balance.
  @HiveField(17)
  final bool? creditApplied;

  /// True once a rejected claim was written off into inventory losses.
  @HiveField(18)
  final bool? lossRecorded;

  RestaurantSupplierClaimModel({
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

  factory RestaurantSupplierClaimModel.create({
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
    return RestaurantSupplierClaimModel(
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
      status: RestaurantSupplierClaimStatus.pending.name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  RestaurantSupplierClaimStatus get statusEnum =>
      RestaurantSupplierClaimStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => RestaurantSupplierClaimStatus.pending,
      );

  bool get isOpen => statusEnum == RestaurantSupplierClaimStatus.pending;

  bool get isCreditApplied => creditApplied == true;

  bool get isLossRecorded => lossRecorded == true;

  bool get isResolved =>
      statusEnum == RestaurantSupplierClaimStatus.rejected ||
      statusEnum == RestaurantSupplierClaimStatus.settled;

  /// Signed supplier-balance adjustment a transition to [target] should
  /// apply — negative because a credit reduces what is owed. `0` means make
  /// no balance change. Only settlement moves money.
  static double claimBalanceAdjustment(
    RestaurantSupplierClaimModel c,
    RestaurantSupplierClaimStatus target,
  ) {
    if (target != RestaurantSupplierClaimStatus.settled) return 0;
    if (c.isCreditApplied) return 0;
    return -c.totalAmount;
  }

  String get statusDisplay {
    switch (statusEnum) {
      case RestaurantSupplierClaimStatus.pending:
        return 'Pending';
      case RestaurantSupplierClaimStatus.approved:
        return 'Approved';
      case RestaurantSupplierClaimStatus.rejected:
        return 'Rejected';
      case RestaurantSupplierClaimStatus.settled:
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

  factory RestaurantSupplierClaimModel.fromMap(Map<String, dynamic> map) {
    return RestaurantSupplierClaimModel(
      claimId: map['claimId'] as String,
      claimNumber: map['claimNumber'] as String,
      grnId: map['grnId'] as String? ?? '',
      grnNumber: map['grnNumber'] as String? ?? '',
      poId: map['poId'] as String? ?? '',
      poNumber: map['poNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String?,
      claimDate: map['claimDate'] as String,
      totalQty: (map['totalQty'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status:
          map['status'] as String? ?? RestaurantSupplierClaimStatus.pending.name,
      resolutionNote: map['resolutionNote'] as String?,
      resolvedAt: map['resolvedAt'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      creditApplied: map['creditApplied'] as bool?,
      lossRecorded: map['lossRecorded'] as bool?,
    );
  }

  RestaurantSupplierClaimModel copyWith({
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
    return RestaurantSupplierClaimModel(
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
