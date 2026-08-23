import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_supplier_model.g.dart';

const _uuid = Uuid();

/// Raw-material supplier for restaurant mode. Own box, mirrors retail's
/// SupplierModel — restaurant has no PO pipeline before this feature (see
/// docs/inventory_recipe_system_plan.md §6), so it needed one of its own.
@HiveType(typeId: HiveTypeIds.restaurantSupplier)
class RestaurantSupplierModel extends HiveObject {
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
  final double currentBalance;

  @HiveField(6)
  final String createdAt;

  @HiveField(7)
  final String updatedAt;

  RestaurantSupplierModel({
    required this.supplierId,
    required this.name,
    this.phone,
    this.address,
    this.gstNumber,
    this.currentBalance = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RestaurantSupplierModel.create({
    required String name,
    String? phone,
    String? address,
    String? gstNumber,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantSupplierModel(
      supplierId: _uuid.v4(),
      name: name,
      phone: phone,
      address: address,
      gstNumber: gstNumber,
      createdAt: now,
      updatedAt: now,
    );
  }

  RestaurantSupplierModel copyWith({
    String? name,
    String? phone,
    String? address,
    String? gstNumber,
    double? currentBalance,
    bool clearPhone = false,
    bool clearAddress = false,
    bool clearGstNumber = false,
  }) {
    return RestaurantSupplierModel(
      supplierId: supplierId,
      name: name ?? this.name,
      phone: clearPhone ? null : (phone ?? this.phone),
      address: clearAddress ? null : (address ?? this.address),
      gstNumber: clearGstNumber ? null : (gstNumber ?? this.gstNumber),
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() => {
        'supplierId': supplierId,
        'name': name,
        'phone': phone,
        'address': address,
        'gstNumber': gstNumber,
        'currentBalance': currentBalance,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory RestaurantSupplierModel.fromMap(Map<String, dynamic> map) {
    return RestaurantSupplierModel(
      supplierId: map['supplierId'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      gstNumber: map['gstNumber'] as String?,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }
}
