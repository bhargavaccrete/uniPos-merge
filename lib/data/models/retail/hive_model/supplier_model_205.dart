import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'supplier_model_205.g.dart';

const _uuid = Uuid();

@HiveType(typeId: HiveTypeIds.retailSupplier)
class SupplierModel extends HiveObject {
  @HiveField(0)
  final String supplierId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? phone;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final String? gstNumber;

  @HiveField(5)
  final double openingBalance;

  @HiveField(6)
  final double currentBalance;

  @HiveField(7)
  final String createdAt;

  @HiveField(8)
  final String updatedAt;

  SupplierModel({
    required this.supplierId,
    required this.name,
    this.phone,
    this.address,
    this.gstNumber,
    this.openingBalance = 0,
    this.currentBalance = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierModel.create({
    required String name,
    String? phone,
    String? address,
    String? gstNumber,
    double openingBalance = 0,
    double currentBalance = 0,
  }) {
    final now = DateTime.now().toIso8601String();

    return SupplierModel(
      supplierId: _uuid.v4(),
      name: name,
      phone: phone,
      address: address,
      gstNumber: gstNumber,
      openingBalance: openingBalance,
      currentBalance: currentBalance,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'name': name,
      'phone': phone,
      'address': address,
      'gstNumber': gstNumber,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Map (for backup restore)
  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      supplierId: map['supplierId'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      gstNumber: map['gstNumber'] as String?,
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }
}
