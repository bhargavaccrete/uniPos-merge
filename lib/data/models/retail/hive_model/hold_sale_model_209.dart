import 'package:hive/hive.dart';

part 'hold_sale_model_209.g.dart';

@HiveType(typeId: 209)
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
  final int totalItems;

  @HiveField(5)
  final double subtotal;

  @HiveField(6)
  final String createdAt;

  @HiveField(7)
  final String updatedAt;

  HoldSaleModel({
    required this.holdSaleId,
    this.customerId,
    this.customerName,
    this.note,
    required this.totalItems,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HoldSaleModel.create({
    required String holdSaleId,
    String? customerId,
    String? customerName,
    String? note,
    required int totalItems,
    required double subtotal,
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
    };
  }
}