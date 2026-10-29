import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'item_cancellation_model_134.g.dart';

/// Audit record for a single item cancelled from an already-placed (KOT'd) order.
/// Captured at commit time with the reason entered by staff, so the
/// Item Cancellation Report can show what was cancelled, by whom, and why.
@HiveType(typeId: HiveTypeIds.restaurantItemCancellation)
class ItemCancellationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String itemName;

  @HiveField(2)
  final String? variantName;

  @HiveField(3)
  final int quantity; // how many units were cancelled

  @HiveField(4)
  final double amount; // value of the cancelled quantity

  @HiveField(5)
  final String reason;

  @HiveField(6)
  final String orderId;

  @HiveField(7)
  final int? billNumber;

  @HiveField(8)
  final int? kotNumber;

  @HiveField(9)
  final String? staffName;

  @HiveField(10)
  final DateTime timestamp;

  @HiveField(11)
  final String? sessionId;

  @HiveField(12)
  final String? orderType;

  @HiveField(13)
  final String? tableNo;

  ItemCancellationModel({
    required this.id,
    required this.itemName,
    this.variantName,
    required this.quantity,
    required this.amount,
    required this.reason,
    required this.orderId,
    this.billNumber,
    this.kotNumber,
    this.staffName,
    required this.timestamp,
    this.sessionId,
    this.orderType,
    this.tableNo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'variantName': variantName,
      'quantity': quantity,
      'amount': amount,
      'reason': reason,
      'orderId': orderId,
      'billNumber': billNumber,
      'kotNumber': kotNumber,
      'staffName': staffName,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'orderType': orderType,
      'tableNo': tableNo,
    };
  }

  factory ItemCancellationModel.fromMap(Map<String, dynamic> map) {
    return ItemCancellationModel(
      id: map['id'] as String,
      itemName: map['itemName'] as String,
      variantName: map['variantName'] as String?,
      quantity: (map['quantity'] as num).toInt(),
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      orderId: map['orderId'] as String,
      billNumber: (map['billNumber'] as num?)?.toInt(),
      kotNumber: (map['kotNumber'] as num?)?.toInt(),
      staffName: map['staffName'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      sessionId: map['sessionId'] as String?,
      orderType: map['orderType'] as String?,
      tableNo: map['tableNo'] as String?,
    );
  }
}
