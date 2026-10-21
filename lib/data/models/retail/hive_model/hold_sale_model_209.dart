import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'hold_sale_model_209.g.dart';

@HiveType(typeId: HiveTypeIds.retailHoldSale)
class HoldSaleModel extends HiveObject {
  @HiveField(0)
  final String holdSaleId;

  @HiveField(1)
  final String? customerId;

  @HiveField(2)
  final String? customerName;

  @HiveField(3)
  final String? note; // Reason for holding (e.g., "Customer checking price", "Forgot wallet")

  @HiveField(4)
  final double totalItems;

  @HiveField(5)
  final double subtotal;

  @HiveField(6)
  final String createdAt;

  @HiveField(7)
  final String updatedAt;

  // ==================== PARKED BILL ====================
  // [subtotal] is the payable total at park time. These record how it was
  // composed so the parked-sales list can show a faithful breakdown.

  @HiveField(8)
  final double? itemTotal; // gross, before discount

  @HiveField(9)
  final double? discountAmount;

  @HiveField(10)
  final double? taxableAmount;

  @HiveField(11)
  final double? gstAmount;

  @HiveField(12)
  final bool? isTaxInclusive;

  HoldSaleModel({
    required this.holdSaleId,
    this.customerId,
    this.customerName,
    this.note,
    required this.totalItems,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
    this.itemTotal,
    this.discountAmount,
    this.taxableAmount,
    this.gstAmount,
    this.isTaxInclusive,
  });

  factory HoldSaleModel.create({
    required String holdSaleId,
    String? customerId,
    String? customerName,
    String? note,
    required double totalItems,
    required double subtotal,
    double? itemTotal,
    double? discountAmount,
    double? taxableAmount,
    double? gstAmount,
    bool? isTaxInclusive,
  }) {
    final now = DateTime.now().toIso8601String();

    return HoldSaleModel(
      holdSaleId: holdSaleId,
      customerId: customerId,
      customerName: customerName,
      note: note,
      totalItems: totalItems,
      subtotal: subtotal,
      createdAt: now,
      updatedAt: now,
      itemTotal: itemTotal,
      discountAmount: discountAmount,
      taxableAmount: taxableAmount,
      gstAmount: gstAmount,
      isTaxInclusive: isTaxInclusive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'holdSaleId': holdSaleId,
      'customerId': customerId,
      'customerName': customerName,
      'note': note,
      'totalItems': totalItems,
      'subtotal': subtotal,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'itemTotal': itemTotal,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'gstAmount': gstAmount,
      'isTaxInclusive': isTaxInclusive,
    };
  }

  factory HoldSaleModel.fromMap(Map<String, dynamic> map) {
    return HoldSaleModel(
      holdSaleId: map['holdSaleId'] as String,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      note: map['note'] as String?,
      totalItems: (map['totalItems'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      itemTotal: (map['itemTotal'] as num?)?.toDouble(),
      discountAmount: (map['discountAmount'] as num?)?.toDouble(),
      taxableAmount: (map['taxableAmount'] as num?)?.toDouble(),
      gstAmount: (map['gstAmount'] as num?)?.toDouble(),
      isTaxInclusive: map['isTaxInclusive'] as bool?,
    );
  }
}