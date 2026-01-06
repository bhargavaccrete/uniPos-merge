import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'purchase_model_207.g.dart';

const _uuid = Uuid();


@HiveType(typeId: HiveTypeIds.retailPurchase)
class PurchaseModel extends HiveObject {
  @HiveField(0)
  final String purchaseId;

  @HiveField(1)
  final String supplierId;

  @HiveField(2)
  final String? invoiceNumber;

  @HiveField(3)
  final int totalItems;

  @HiveField(4)
  final double totalAmount;

  @HiveField(5)
  final String purchaseDate;

  @HiveField(6)
  final String createdAt;

  @HiveField(7)
  final String updatedAt;

  PurchaseModel({
    required this.purchaseId,
    required this.supplierId,
    this.invoiceNumber,
    required this.totalItems,
    required this.totalAmount,
    required this.purchaseDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseModel.create({
    required String supplierId,
    String? invoiceNumber,
    required int totalItems,
    required double totalAmount,
  }) {
    final now = DateTime.now().toIso8601String();

    return PurchaseModel(
      purchaseId: _uuid.v4(),
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      totalItems: totalItems,
      totalAmount: totalAmount,
      purchaseDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseId': purchaseId,
      'supplierId': supplierId,
      'invoiceNumber': invoiceNumber,
      'totalItems': totalItems,
      'totalAmount': totalAmount,
      'purchaseDate': purchaseDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Map (for backup restore)
  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      purchaseId: map['purchaseId'] as String,
      supplierId: map['supplierId'] as String,
      invoiceNumber: map['invoiceNumber'] as String?,
      totalItems: (map['totalItems'] as num).toInt(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      purchaseDate: map['purchaseDate'] as String,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }
}
