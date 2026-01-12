import 'package:hive/hive.dart';
import '../../../../core/constants/hive_type_ids.dart';

// This is required for the code generator to work
part 'customer_model_125.g.dart';

@HiveType(typeId: HiveTypeIds.RestaurantCustomer)
class RestaurantCustomer extends HiveObject {
  @HiveField(0)
  final String customerId;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? phone;

  @HiveField(3)
  final int totalVisites;

  @HiveField(4)
  final String? lastVisitAt;

  @HiveField(5)
  final String? lastorderType; // dine in | take away | delivery

  @HiveField(6)
  final String? favoriteItems;

  @HiveField(7)
  final String? foodPrefrence;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final int loyaltyPoints;

  @HiveField(10)
  final String createdAt;

  @HiveField(11)
  final String? updatedAt;

  RestaurantCustomer({
    required this.customerId,
    this.name,
    this.phone,
    this.totalVisites = 0,
    this.lastVisitAt,
    this.lastorderType,
    this.favoriteItems,
    this.foodPrefrence,
    this.notes,
    this.loyaltyPoints = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory RestaurantCustomer.create({
    required String customerId,
    String? name,
    String? phone,
    String? foodPrefrence,
    String? notes,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantCustomer(
      customerId: customerId,
      name: name,
      phone: phone,
      foodPrefrence: foodPrefrence,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  // --- ADDED: toMap Method ---
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'name': name,
      'phone': phone,
      'totalVisites': totalVisites,
      'lastVisitAt': lastVisitAt,
      'lastorderType': lastorderType,
      'favoriteItems': favoriteItems,
      'foodPrefrence': foodPrefrence,
      'notes': notes,
      'loyaltyPoints': loyaltyPoints,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // --- FIXED: fromMap Method with null safety ---
  factory RestaurantCustomer.fromMap(Map<String, dynamic> map) {
    return RestaurantCustomer(
      customerId: map['customerId'] ?? '',
      name: map['name'],
      phone: map['phone'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'],
      notes: map['notes'],
      foodPrefrence: map['foodPrefrence'],
      favoriteItems: map['favoriteItems'],
      lastorderType: map['lastorderType'],
      lastVisitAt: map['lastVisitAt'],
      // Added safety for integer parsing
      loyaltyPoints: (map['loyaltyPoints'] as num?)?.toInt() ?? 0,
      totalVisites: (map['totalVisites'] as num?)?.toInt() ?? 0,
    );
  }

  RestaurantCustomer copyWith({
    String? name,
    String? phone,
    int? totalVisites,
    String? lastVisitAt,
    String? lastorderType,
    String? favoriteItems,
    String? foodPrefrence,
    String? notes,
    int? loyaltyPoints,
    String? updatedAt,
  }) {
    return RestaurantCustomer(
      customerId: this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalVisites: totalVisites ?? this.totalVisites,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      lastorderType: lastorderType ?? this.lastorderType,
      favoriteItems: favoriteItems ?? this.favoriteItems,
      foodPrefrence: foodPrefrence ?? this.foodPrefrence,
      notes: notes ?? this.notes,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }
}