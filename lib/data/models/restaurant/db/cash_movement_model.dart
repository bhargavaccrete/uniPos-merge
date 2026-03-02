import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'cash_movement_model.g.dart';

/// Represents a single manual cash movement in or out of the physical drawer.
///
/// These are mid-day entries made by staff — NOT the same as Expenses
/// (which go through the accounting/category system). Cash movements are
/// quick, operational entries: owner adds float, petty cash withdrawal, safe drop, etc.
///
/// Immutability rule: movements are NEVER deleted. To correct a mistake,
/// add a counter-entry (e.g., a Cash In to undo an accidental Cash Out).
@HiveType(typeId: HiveTypeIds.restaurantCashMovement)
class CashMovementModel extends HiveObject {
  /// Unique ID (UUID v4)
  @HiveField(0)
  final String id;

  /// When this movement was recorded (device clock, not editable after save)
  @HiveField(1)
  final DateTime timestamp;

  /// Direction: 'in' = cash added to drawer, 'out' = cash removed from drawer
  @HiveField(2)
  final String type;

  /// Amount moved (always positive — direction is captured by [type])
  @HiveField(3)
  final double amount;

  /// Short reason, chosen from a fixed dropdown to keep data clean
  /// e.g. 'Owner deposit', 'Safe drop', 'Petty cash', 'Advance', 'Supplier payment', 'Other'
  @HiveField(4)
  final String reason;

  /// Optional free-text note for extra detail
  @HiveField(5)
  final String? note;

  /// Name of the staff member who recorded this movement
  /// (from RestaurantSession.staffName at the time of save)
  @HiveField(6)
  final String staffName;

  CashMovementModel({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.amount,
    required this.reason,
    this.note,
    required this.staffName,
  });

  /// True if this movement adds cash to the drawer
  bool get isCashIn => type == 'in';

  /// Signed amount: positive for Cash In, negative for Cash Out
  double get signedAmount => isCashIn ? amount : -amount;

  /// Human-readable label for the log
  String get label => isCashIn ? 'Cash In — $reason' : 'Cash Out — $reason';
}
