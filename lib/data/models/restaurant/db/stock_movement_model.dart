import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'stock_movement_model.g.dart';

/// Append-only record of a single manual stock change for an item (or variant).
///
/// Mirrors [CashMovementModel]: movements are NEVER edited or deleted — to
/// correct a mistake, record a counter-movement. This keeps a trustworthy
/// audit trail of who changed stock, by how much, and why.
@HiveType(typeId: HiveTypeIds.restaurantStockLog)
class StockMovementModel extends HiveObject {
  /// Unique ID (UUID v4) — also used as the Hive key.
  @HiveField(0)
  final String id;

  /// When this movement was recorded (device clock, not editable after save).
  @HiveField(1)
  final DateTime timestamp;

  /// Item this movement belongs to.
  @HiveField(2)
  final String itemId;

  /// Variant ID when the change was on a variant's stock, else null.
  @HiveField(3)
  final String? variantId;

  /// Item name captured at save time (so history survives item rename/delete).
  @HiveField(4)
  final String itemName;

  /// Direction: 'in' = stock added, 'out' = stock removed.
  @HiveField(5)
  final String type;

  /// Quantity moved (always positive — direction is captured by [type]).
  @HiveField(6)
  final double quantity;

  /// Stock level AFTER this movement was applied (for a running ledger).
  @HiveField(7)
  final double balanceAfter;

  /// Reason chosen from a fixed dropdown to keep data clean.
  @HiveField(8)
  final String reason;

  /// Optional free-text note for extra detail.
  @HiveField(9)
  final String? note;

  /// Unit label at save time (e.g. 'kg', 'pcs').
  @HiveField(10)
  final String unit;

  /// Staff member who recorded this movement.
  @HiveField(11)
  final String staffName;

  /// POS session this movement belongs to (optional).
  @HiveField(12)
  final String? sessionId;

  StockMovementModel({
    required this.id,
    required this.timestamp,
    required this.itemId,
    this.variantId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    required this.reason,
    this.note,
    required this.unit,
    required this.staffName,
    this.sessionId,
  });

  /// True if this movement added stock.
  bool get isIn => type == 'in';

  /// Signed quantity: positive for stock in, negative for stock out.
  double get signedQuantity => isIn ? quantity : -quantity;

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'itemId': itemId,
        'variantId': variantId,
        'itemName': itemName,
        'type': type,
        'quantity': quantity,
        'balanceAfter': balanceAfter,
        'reason': reason,
        'note': note,
        'unit': unit,
        'staffName': staffName,
        'sessionId': sessionId,
      };

  factory StockMovementModel.fromMap(Map<String, dynamic> map) =>
      StockMovementModel(
        id: map['id'] ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
        itemId: map['itemId'] ?? '',
        variantId: map['variantId'] as String?,
        itemName: map['itemName'] ?? '',
        type: map['type'] ?? 'in',
        quantity: (map['quantity'] ?? 0).toDouble(),
        balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
        reason: map['reason'] ?? '',
        note: map['note'] as String?,
        unit: map['unit'] ?? '',
        staffName: map['staffName'] ?? '',
        sessionId: map['sessionId'] as String?,
      );
}
