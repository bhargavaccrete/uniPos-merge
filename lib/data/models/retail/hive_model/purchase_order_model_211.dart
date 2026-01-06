import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'purchase_order_model_211.g.dart';

/// Purchase Order Status
/// - draft: PO created but not yet sent to supplier
/// - sent: PO has been sent to supplier
/// - partiallyCompleted: Some items have been received
/// - fullyCompleted: All items have been received
/// - cancelled: PO has been cancelled
enum POStatus {
  draft,
  sent,
  partiallyCompleted,
  fullyCompleted,
  cancelled,
}

@HiveType(typeId: HiveTypeIds.retailPurchaseOrder)
class PurchaseOrderModel extends HiveObject {
  @HiveField(0)
  final String poId;

  @HiveField(1)
  final String poNumber; // Auto-generated PO number (e.g., PO-20250101-001)

  @HiveField(2)
  final String supplierId;

  @HiveField(3)
  final String? supplierName; // Denormalized for display

  @HiveField(4)
  final String expectedDeliveryDate; // ISO 8601 date string

  @HiveField(5)
  final int totalItems; // Total quantity of all items

  @HiveField(6)
  final double estimatedTotal; // Price estimation (optional/editable)

  @HiveField(7)
  final String status; // POStatus as string

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String createdAt;

  @HiveField(10)
  final String updatedAt;

  PurchaseOrderModel({
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    this.supplierName,
    required this.expectedDeliveryDate,
    required this.totalItems,
    this.estimatedTotal = 0,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseOrderModel.create({
    required String poNumber,
    required String supplierId,
    String? supplierName,
    required String expectedDeliveryDate,
    int totalItems = 0,
    double estimatedTotal = 0,
    POStatus status = POStatus.draft,
    String? notes,
  }) {
    final now = DateTime.now().toIso8601String();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    return PurchaseOrderModel(
      poId: id,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      expectedDeliveryDate: expectedDeliveryDate,
      totalItems: totalItems,
      estimatedTotal: estimatedTotal,
      status: status.name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get POStatus enum from string
  POStatus get statusEnum {
    return POStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => POStatus.draft,
    );
  }

  /// Check if PO can be edited (only draft status)
  bool get canEdit => statusEnum == POStatus.draft;

  /// Check if PO can receive items
  bool get canReceive =>
      statusEnum == POStatus.sent || statusEnum == POStatus.partiallyCompleted;

  /// Check if PO is completed
  bool get isCompleted =>
      statusEnum == POStatus.fullyCompleted ||
      statusEnum == POStatus.cancelled;

  Map<String, dynamic> toMap() {
    return {
      'poId': poId,
      'poNumber': poNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'expectedDeliveryDate': expectedDeliveryDate,
      'totalItems': totalItems,
      'estimatedTotal': estimatedTotal,
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderModel(
      poId: map['poId'] as String,
      poNumber: map['poNumber'] as String,
      supplierId: map['supplierId'] as String,
      supplierName: map['supplierName'] as String?,
      expectedDeliveryDate: map['expectedDeliveryDate'] as String,
      totalItems: (map['totalItems'] as num).toInt(),
      estimatedTotal: (map['estimatedTotal'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }

  /// Create a copy with updated fields
  PurchaseOrderModel copyWith({
    String? poId,
    String? poNumber,
    String? supplierId,
    String? supplierName,
    String? expectedDeliveryDate,
    int? totalItems,
    double? estimatedTotal,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return PurchaseOrderModel(
      poId: poId ?? this.poId,
      poNumber: poNumber ?? this.poNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      totalItems: totalItems ?? this.totalItems,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }
}