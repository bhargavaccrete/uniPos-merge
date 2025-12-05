import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'grn_model_213.g.dart';

const _uuid = Uuid();

/// GRN (Goods Received Note) Status
/// - draft: GRN created but not yet confirmed
/// - confirmed: GRN confirmed, stock has been updated
/// - cancelled: GRN cancelled (no stock impact)
enum GRNStatus {
  draft,
  confirmed,
  cancelled,
}

/// GRN - Goods Received Note (Material Receiving)
/// This is where we record what actually arrived from the supplier
/// Stock is ONLY updated when GRN is confirmed
@HiveType(typeId: 213)
class GRNModel extends HiveObject {
  @HiveField(0)
  final String grnId;

  @HiveField(1)
  final String grnNumber; // Auto-generated GRN number (e.g., GRN-20250101-001)

  @HiveField(2)
  final String poId; // Links to PurchaseOrderModel

  @HiveField(3)
  final String poNumber; // Denormalized for display

  @HiveField(4)
  final String supplierId;

  @HiveField(5)
  final String? supplierName; // Denormalized for display

  @HiveField(6)
  final String receivedDate; // Date when goods were received

  @HiveField(7)
  final int totalOrderedQty; // Total quantity that was ordered in PO

  @HiveField(8)
  final int totalReceivedQty; // Total quantity actually received

  @HiveField(9)
  final double? totalAmount; // Total cost of received items

  @HiveField(10)
  final String status; // GRNStatus as string

  @HiveField(11)
  final String? notes; // Any notes about the receiving (damaged items, etc.)

  @HiveField(12)
  final String? invoiceNumber; // Supplier's invoice number (optional)

  @HiveField(13)
  final String createdAt;

  @HiveField(14)
  final String updatedAt;

  GRNModel({
    required this.grnId,
    required this.grnNumber,
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    this.supplierName,
    required this.receivedDate,
    required this.totalOrderedQty,
    required this.totalReceivedQty,
    this.totalAmount,
    required this.status,
    this.notes,
    this.invoiceNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GRNModel.create({
    required String grnNumber,
    required String poId,
    required String poNumber,
    required String supplierId,
    String? supplierName,
    required String receivedDate,
    int totalOrderedQty = 0,
    int totalReceivedQty = 0,
    double? totalAmount,
    GRNStatus status = GRNStatus.draft,
    String? notes,
    String? invoiceNumber,
  }) {
    final now = DateTime.now().toIso8601String();

    return GRNModel(
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

  /// Get GRNStatus enum from string
  GRNStatus get statusEnum {
    return GRNStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => GRNStatus.draft,
    );
  }

  /// Check if GRN can be edited (only draft status)
  bool get canEdit => statusEnum == GRNStatus.draft;

  /// Check if GRN is confirmed
  bool get isConfirmed => statusEnum == GRNStatus.confirmed;

  /// Check if all ordered items were received
  bool get isFullyReceived => totalReceivedQty >= totalOrderedQty;

  /// Check if partial receiving
  bool get isPartiallyReceived =>
      totalReceivedQty > 0 && totalReceivedQty < totalOrderedQty;

  /// Shortage quantity
  int get shortageQty => totalOrderedQty - totalReceivedQty;

  Map<String, dynamic> toMap() {
    return {
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
  }

  GRNModel copyWith({
    String? grnId,
    String? grnNumber,
    String? poId,
    String? poNumber,
    String? supplierId,
    String? supplierName,
    String? receivedDate,
    int? totalOrderedQty,
    int? totalReceivedQty,
    double? totalAmount,
    String? status,
    String? notes,
    String? invoiceNumber,
    String? createdAt,
    String? updatedAt,
  }) {
    return GRNModel(
      grnId: grnId ?? this.grnId,
      grnNumber: grnNumber ?? this.grnNumber,
      poId: poId ?? this.poId,
      poNumber: poNumber ?? this.poNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      receivedDate: receivedDate ?? this.receivedDate,
      totalOrderedQty: totalOrderedQty ?? this.totalOrderedQty,
      totalReceivedQty: totalReceivedQty ?? this.totalReceivedQty,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }
}