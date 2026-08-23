import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_purchase_order_model.g.dart';

/// Restaurant Purchase Order status — mirrors retail's POStatus.
/// - draft: created but not yet sent to supplier
/// - sent: sent to supplier, awaiting delivery
/// - partiallyReceived: some lines received via GRN
/// - completed: all lines received
/// - cancelled: PO cancelled
enum RestaurantPOStatus {
  draft,
  sent,
  partiallyReceived,
  completed,
  cancelled,
}

/// Restaurant-scoped Purchase Order for raw-material procurement. Mirrors
/// retail's PurchaseOrderModel, scoped separately per docs/inventory_recipe_system_plan.md §6
/// (restaurant's Item model has no variant-purchasing complexity retail needs).
@HiveType(typeId: HiveTypeIds.restaurantPurchaseOrder)
class RestaurantPurchaseOrderModel extends HiveObject {
  @HiveField(0)
  final String poId;

  @HiveField(1)
  final String poNumber; // Auto-generated, e.g. PO-20260824-001

  @HiveField(2)
  final String supplierId;

  @HiveField(3)
  final String? supplierName; // denormalized for display

  @HiveField(4)
  final String expectedDeliveryDate; // ISO 8601 date string

  @HiveField(5)
  final double totalItems; // total ordered qty across all lines

  @HiveField(6)
  final double estimatedTotal;

  @HiveField(7)
  final String status; // RestaurantPOStatus as string

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String createdAt;

  @HiveField(10)
  final String updatedAt;

  RestaurantPurchaseOrderModel({
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    this.supplierName,
    required this.expectedDeliveryDate,
    this.totalItems = 0,
    this.estimatedTotal = 0,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RestaurantPurchaseOrderModel.create({
    required String poId,
    required String poNumber,
    required String supplierId,
    String? supplierName,
    required String expectedDeliveryDate,
    double totalItems = 0,
    double estimatedTotal = 0,
    RestaurantPOStatus status = RestaurantPOStatus.draft,
    String? notes,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantPurchaseOrderModel(
      poId: poId,
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

  RestaurantPOStatus get statusEnum => RestaurantPOStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => RestaurantPOStatus.draft,
      );

  bool get canEdit => statusEnum == RestaurantPOStatus.draft;
  bool get canReceive =>
      statusEnum == RestaurantPOStatus.sent || statusEnum == RestaurantPOStatus.partiallyReceived;
  bool get isCompleted =>
      statusEnum == RestaurantPOStatus.completed || statusEnum == RestaurantPOStatus.cancelled;

  RestaurantPurchaseOrderModel copyWith({
    String? supplierId,
    String? supplierName,
    String? expectedDeliveryDate,
    double? totalItems,
    double? estimatedTotal,
    String? status,
    String? notes,
  }) {
    return RestaurantPurchaseOrderModel(
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      totalItems: totalItems ?? this.totalItems,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
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

  factory RestaurantPurchaseOrderModel.fromMap(Map<String, dynamic> map) {
    return RestaurantPurchaseOrderModel(
      poId: map['poId'] as String,
      poNumber: map['poNumber'] as String,
      supplierId: map['supplierId'] as String,
      supplierName: map['supplierName'] as String?,
      expectedDeliveryDate: map['expectedDeliveryDate'] as String,
      totalItems: (map['totalItems'] as num?)?.toDouble() ?? 0,
      estimatedTotal: (map['estimatedTotal'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }
}
