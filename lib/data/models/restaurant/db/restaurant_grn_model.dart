import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_grn_model.g.dart';

const _uuid = Uuid();

/// Restaurant GRN status — mirrors retail's GRNStatus. Stock is ONLY
/// updated when a GRN is confirmed (see docs/inventory_recipe_system_plan.md §6.1).
enum RestaurantGRNStatus { draft, confirmed, cancelled }

/// GRN (Goods Received Note) — what actually arrived from the supplier for a
/// [RestaurantPurchaseOrderModel]. Confirming a GRN is the only place raw
/// material stock increments; mirrors retail's GRN pattern.
@HiveType(typeId: HiveTypeIds.restaurantGrn)
class RestaurantGRNModel extends HiveObject {
  @HiveField(0)
  final String grnId;

  @HiveField(1)
  final String grnNumber;

  @HiveField(2)
  final String poId;

  @HiveField(3)
  final String poNumber;

  @HiveField(4)
  final String supplierId;

  @HiveField(5)
  final String? supplierName;

  @HiveField(6)
  final String receivedDate;

  @HiveField(7)
  final double totalOrderedQty;

  @HiveField(8)
  final double totalReceivedQty;

  @HiveField(9)
  final double? totalAmount;

  @HiveField(10)
  final String status; // RestaurantGRNStatus as string

  @HiveField(11)
  final String? notes;

  @HiveField(12)
  final String? invoiceNumber;

  @HiveField(13)
  final String createdAt;

  @HiveField(14)
  final String updatedAt;

  RestaurantGRNModel({
    required this.grnId,
    required this.grnNumber,
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    this.supplierName,
    required this.receivedDate,
    this.totalOrderedQty = 0,
    this.totalReceivedQty = 0,
    this.totalAmount,
    required this.status,
    this.notes,
    this.invoiceNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  /// [grnNumber] is minted by `RestaurantGRNRepository.generateGRNNumber()`
  /// and passed in, rather than generated here: the shared
  /// `DocumentNumberService` writes a counter to Hive, so it is async and
  /// cannot run inside a synchronous factory.
  factory RestaurantGRNModel.create({
    required String grnNumber,
    required String poId,
    required String poNumber,
    required String supplierId,
    String? supplierName,
    required String receivedDate,
    double totalOrderedQty = 0,
    double totalReceivedQty = 0,
    double? totalAmount,
    RestaurantGRNStatus status = RestaurantGRNStatus.draft,
    String? notes,
    String? invoiceNumber,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantGRNModel(
      grnId: _uuid.v4(),
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      receivedDate: receivedDate,
      totalOrderedQty: totalOrderedQty,
      totalReceivedQty: totalReceivedQty,
      totalAmount: totalAmount,
      status: status.name,
      notes: notes,
      invoiceNumber: invoiceNumber,
      createdAt: now,
      updatedAt: now,
    );
  }

  RestaurantGRNStatus get statusEnum => RestaurantGRNStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => RestaurantGRNStatus.draft,
      );

  bool get canEdit => statusEnum == RestaurantGRNStatus.draft;
  bool get isConfirmed => statusEnum == RestaurantGRNStatus.confirmed;
  bool get isFullyReceived => totalReceivedQty >= totalOrderedQty;

  RestaurantGRNModel copyWith({
    double? totalOrderedQty,
    double? totalReceivedQty,
    double? totalAmount,
    String? status,
    String? notes,
    String? invoiceNumber,
  }) {
    return RestaurantGRNModel(
      grnId: grnId,
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      receivedDate: receivedDate,
      totalOrderedQty: totalOrderedQty ?? this.totalOrderedQty,
      totalReceivedQty: totalReceivedQty ?? this.totalReceivedQty,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grnId': grnId,
        'grnNumber': grnNumber,
        'poId': poId,
        'poNumber': poNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'receivedDate': receivedDate,
        'totalOrderedQty': totalOrderedQty,
        'totalReceivedQty': totalReceivedQty,
        'totalAmount': totalAmount,
        'status': status,
        'notes': notes,
        'invoiceNumber': invoiceNumber,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory RestaurantGRNModel.fromMap(Map<String, dynamic> map) {
    return RestaurantGRNModel(
      grnId: map['grnId'] as String,
      grnNumber: map['grnNumber'] as String,
      poId: map['poId'] as String,
      poNumber: map['poNumber'] as String,
      supplierId: map['supplierId'] as String,
      supplierName: map['supplierName'] as String?,
      receivedDate: map['receivedDate'] as String,
      totalOrderedQty: (map['totalOrderedQty'] as num?)?.toDouble() ?? 0,
      totalReceivedQty: (map['totalReceivedQty'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      status: map['status'] as String,
      notes: map['notes'] as String?,
      invoiceNumber: map['invoiceNumber'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }
}
