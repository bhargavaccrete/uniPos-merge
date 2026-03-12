import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'cash_handover_model.g.dart';

/// Represents an async 2-step cash drawer handover between two staff members.
///
/// HOW IT WORKS:
///   Step 1 (closer): outgoing staff counts cash, saves [closedAmount].
///                    Status becomes 'PENDING'.
///   Step 2 (receiver): incoming staff counts same cash, saves [receivedAmount].
///                    Status becomes 'MATCHED' or 'DISCREPANCY'.
///
/// WHY 2-STEP ASYNC:
///   Night staff leaves at 11 PM; morning staff arrives at 9 AM.
///   They can never confirm simultaneously. The gap between [closedAt]
///   and [receivedAt] is the accountability window — if cash is missing,
///   both parties and the timeframe are recorded.
@HiveType(typeId: HiveTypeIds.restaurantCashHandover)
class CashHandoverModel extends HiveObject {
  /// Unique ID (UUID v4)
  @HiveField(0)
  final String id;

  // ── Step 1: Outgoing staff (closer) ──────────────────────────────────────

  /// Name of the staff member handing over the drawer
  @HiveField(1)
  final String closedBy;

  /// When Step 1 was completed (outgoing staff confirmed their count)
  @HiveField(2)
  final DateTime closedAt;

  /// Amount counted by outgoing staff before leaving
  @HiveField(3)
  final double closedAmount;

  /// Optional note from outgoing staff
  @HiveField(4)
  final String? closedNote;

  // ── Step 2: Incoming staff (receiver) — null until confirmed ─────────────

  /// Name of the staff member receiving the drawer (null = not yet received)
  @HiveField(5)
  final String? receivedBy;

  /// When Step 2 was completed (incoming staff confirmed their count)
  @HiveField(6)
  final DateTime? receivedAt;

  /// Amount counted by incoming staff when they arrived
  @HiveField(7)
  final double? receivedAmount;

  /// Optional note from incoming staff
  @HiveField(8)
  final String? receivedNote;

  // ── Result ───────────────────────────────────────────────────────────────

  /// Handover result:
  ///   'PENDING'      — Step 2 not yet done
  ///   'MATCHED'      — Both counts agree (variance == 0 or within tolerance)
  ///   'DISCREPANCY'  — Counts differ; manager should investigate
  @HiveField(9)
  final String status;

  /// receivedAmount - closedAmount (null while PENDING)
  /// Positive = more cash found than expected (overage)
  /// Negative = less cash found than expected (shortage)
  @HiveField(10)
  final double? variance;

  CashHandoverModel({
    required this.id,
    required this.closedBy,
    required this.closedAt,
    required this.closedAmount,
    this.closedNote,
    this.receivedBy,
    this.receivedAt,
    this.receivedAmount,
    this.receivedNote,
    required this.status,
    this.variance,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'closedBy': closedBy,
        'closedAt': closedAt.toIso8601String(),
        'closedAmount': closedAmount,
        'closedNote': closedNote,
        'receivedBy': receivedBy,
        'receivedAt': receivedAt?.toIso8601String(),
        'receivedAmount': receivedAmount,
        'receivedNote': receivedNote,
        'status': status,
        'variance': variance,
      };

  factory CashHandoverModel.fromMap(Map<String, dynamic> map) =>
      CashHandoverModel(
        id: map['id'] ?? '',
        closedBy: map['closedBy'] ?? '',
        closedAt:
            DateTime.tryParse(map['closedAt'] ?? '') ?? DateTime.now(),
        closedAmount: (map['closedAmount'] ?? 0).toDouble(),
        closedNote: map['closedNote'] as String?,
        receivedBy: map['receivedBy'] as String?,
        receivedAt: map['receivedAt'] != null
            ? DateTime.tryParse(map['receivedAt'] as String)
            : null,
        receivedAmount: map['receivedAmount'] != null
            ? (map['receivedAmount'] as num).toDouble()
            : null,
        receivedNote: map['receivedNote'] as String?,
        status: map['status'] ?? 'PENDING',
        variance: map['variance'] != null
            ? (map['variance'] as num).toDouble()
            : null,
      );

  bool get isPending     => status == 'PENDING';
  bool get isMatched     => status == 'MATCHED';
  bool get isDiscrepancy => status == 'DISCREPANCY';

  /// Returns a copy with updated receiver fields after Step 2.
  CashHandoverModel withReceived({
    required String receivedBy,
    required DateTime receivedAt,
    required double receivedAmount,
    String? receivedNote,
  }) {
    final v = receivedAmount - closedAmount;
    // Tolerance: ±1 unit considered matched (rounding errors)
    final resolved = v.abs() <= 1.0 ? 'MATCHED' : 'DISCREPANCY';
    return CashHandoverModel(
      id: id,
      closedBy: closedBy,
      closedAt: closedAt,
      closedAmount: closedAmount,
      closedNote: closedNote,
      receivedBy: receivedBy,
      receivedAt: receivedAt,
      receivedAmount: receivedAmount,
      receivedNote: receivedNote,
      status: resolved,
      variance: v,
    );
  }
}
