import 'package:hive/hive.dart';
import '../../../core/constants/hive_type_ids.dart';

part 'customer_model_125.g.dart';

/// Customer — shared between Restaurant and Retail. Each mode keeps its own
/// physically-separate box (see CustomerRepository), same model.
///
/// Fields are grouped by purpose below for readability; the @HiveField index
/// numbers are what Hive actually serializes by, and must NEVER change once
/// assigned — declaration order here is purely cosmetic. Indices 0-11 are
/// restaurant's original fields; 12-19 were added from retail's CustomerModel
/// (unused/null/0 for restaurant — see project_no_credit_restaurant for why
/// restaurant has no credit fields).
@HiveType(typeId: HiveTypeIds.customer)
class Customer extends HiveObject {
  // --- Identity ---
  @HiveField(0)
  final String customerId;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? phone;

  @HiveField(12)
  final String? email;

  @HiveField(13)
  final String? address;

  @HiveField(14)
  final String? gstNumber;

  // --- Visit / Order Stats ---
  @HiveField(3)
  final int totalVisites;

  @HiveField(4)
  final String? lastVisitAt;

  @HiveField(5)
  final String? lastorderType; // dine in | take away | delivery

  @HiveField(15, defaultValue: 0.0)
  final double totalPurchaseAmount;

  // --- Preferences / Notes ---
  @HiveField(6)
  final String? favoriteItems;

  @HiveField(7)
  final String? foodPrefrence;

  @HiveField(8)
  final String? notes;

  // --- Loyalty ---
  @HiveField(9)
  final int loyaltyPoints;

  @HiveField(16, defaultValue: 0)
  final int totalPointEarned;

  @HiveField(17, defaultValue: 0)
  final int totalPointRedeemed;

  // --- Credit (retail only — restaurant has no credit/pay-later) ---
  @HiveField(18, defaultValue: 0.0)
  final double creditBalance;

  @HiveField(19, defaultValue: 0.0)
  final double creditLimit;

  // --- Audit ---
  @HiveField(10)
  final String createdAt;

  @HiveField(11)
  final String? updatedAt;

  Customer({
    required this.customerId,
    this.name,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
    this.totalVisites = 0,
    this.lastVisitAt,
    this.lastorderType,
    this.totalPurchaseAmount = 0.0,
    this.favoriteItems,
    this.foodPrefrence,
    this.notes,
    this.loyaltyPoints = 0,
    this.totalPointEarned = 0,
    this.totalPointRedeemed = 0,
    this.creditBalance = 0.0,
    this.creditLimit = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory Customer.create({
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    String? foodPrefrence,
    String? notes,
    double creditLimit = 0.0,
    double openingBalance = 0.0,
  }) {
    final now = DateTime.now().toIso8601String();
    return Customer(
      customerId: customerId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      gstNumber: gstNumber,
      foodPrefrence: foodPrefrence,
      notes: notes,
      creditLimit: creditLimit,
      creditBalance: openingBalance,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gstNumber': gstNumber,
      'totalVisites': totalVisites,
      'lastVisitAt': lastVisitAt,
      'lastorderType': lastorderType,
      'totalPurchaseAmount': totalPurchaseAmount,
      'favoriteItems': favoriteItems,
      'foodPrefrence': foodPrefrence,
      'notes': notes,
      'loyaltyPoints': loyaltyPoints,
      'totalPointEarned': totalPointEarned,
      'totalPointRedeemed': totalPointRedeemed,
      'creditBalance': creditBalance,
      'creditLimit': creditLimit,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      customerId: map['customerId'] ?? '',
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      gstNumber: map['gstNumber'],
      totalVisites: (map['totalVisites'] as num?)?.toInt() ?? 0,
      lastVisitAt: map['lastVisitAt'],
      lastorderType: map['lastorderType'],
      totalPurchaseAmount: (map['totalPurchaseAmount'] as num?)?.toDouble() ?? 0.0,
      favoriteItems: map['favoriteItems'],
      foodPrefrence: map['foodPrefrence'],
      notes: map['notes'],
      loyaltyPoints: (map['loyaltyPoints'] as num?)?.toInt() ?? 0,
      totalPointEarned: (map['totalPointEarned'] as num?)?.toInt() ?? 0,
      totalPointRedeemed: (map['totalPointRedeemed'] as num?)?.toInt() ?? 0,
      creditBalance: (map['creditBalance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['creditLimit'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'],
    );
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    int? totalVisites,
    String? lastVisitAt,
    String? lastorderType,
    double? totalPurchaseAmount,
    String? favoriteItems,
    String? foodPrefrence,
    String? notes,
    int? loyaltyPoints,
    int? totalPointEarned,
    int? totalPointRedeemed,
    double? creditBalance,
    double? creditLimit,
    String? updatedAt,
    // `x ?? this.x` can never put a nullable field back to null, so an edit
    // form has no way to clear an optional value. These say so explicitly,
    // instead of forcing callers to hand-build the model.
    bool clearEmail = false,
    bool clearAddress = false,
    bool clearGstNumber = false,
    bool clearNotes = false,
    bool clearFoodPrefrence = false,
  }) {
    return Customer(
      customerId: this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: clearEmail ? null : (email ?? this.email),
      address: clearAddress ? null : (address ?? this.address),
      gstNumber: clearGstNumber ? null : (gstNumber ?? this.gstNumber),
      totalVisites: totalVisites ?? this.totalVisites,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      lastorderType: lastorderType ?? this.lastorderType,
      totalPurchaseAmount: totalPurchaseAmount ?? this.totalPurchaseAmount,
      favoriteItems: favoriteItems ?? this.favoriteItems,
      foodPrefrence:
          clearFoodPrefrence ? null : (foodPrefrence ?? this.foodPrefrence),
      notes: clearNotes ? null : (notes ?? this.notes),
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      totalPointEarned: totalPointEarned ?? this.totalPointEarned,
      totalPointRedeemed: totalPointRedeemed ?? this.totalPointRedeemed,
      creditBalance: creditBalance ?? this.creditBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }
}
