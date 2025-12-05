import 'package:hive/hive.dart';

part 'customer_model_208.g.dart';

@HiveType(typeId: 208)
class CustomerModel extends HiveObject {
  @HiveField(0)
  final String customerId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String? email;

  @HiveField(4)
  final String? address;

  @HiveField(5)
  final String? notes;

  // Purchase Summary
  @HiveField(6)
  final double totalPurchaseAmount;

  @HiveField(7)
  final String? lastVisited;

  @HiveField(8)
  final int visitCount;

  // Loyalty points
  @HiveField(9)
  final int pointsBalance;

  @HiveField(10)
  final int totalPointEarned;

  @HiveField(11)
  final int totalPointRedeemed;

  // Credit System
  @HiveField(12)
  final double creditBalance;

  @HiveField(13)
  final double creditLimit;

  @HiveField(14)
  final String? gstNumber;

  @HiveField(15)
  final String createdAt;

  @HiveField(16)
  final String? updatedAt;

  CustomerModel({
    required this.customerId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.notes,
    this.totalPurchaseAmount = 0.0,
    this.lastVisited,
    this.visitCount = 0,
    this.pointsBalance = 0,
    this.totalPointEarned = 0,
    this.totalPointRedeemed = 0,
    this.creditBalance = 0.0,
    this.creditLimit = 0.0,
    this.gstNumber,
    required this.createdAt,
    this.updatedAt,
  });

  factory CustomerModel.create({
    required String customerId,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
    String? gstNumber,
    double creditLimit = 0.0,
    double openingBalance = 0.0,
  }) {
    final now = DateTime.now().toIso8601String();

    return CustomerModel(
      customerId: customerId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      totalPurchaseAmount: 0.0,
      lastVisited: null,
      visitCount: 0,
      pointsBalance: 0,
      totalPointEarned: 0,
      creditBalance: openingBalance,
      creditLimit: creditLimit,
      gstNumber: gstNumber,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a copy with updated fields
  CustomerModel copyWith({
    String? customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    double? totalPurchaseAmount,
    String? lastVisited,
    int? visitCount,
    int? pointsBalance,
    int? totalPointEarned,
    int? totalPointRedeemed,
    double? creditBalance,
    double? creditLimit,
    String? gstNumber,
    String? createdAt,
    String? updatedAt,
  }) {
    return CustomerModel(
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      totalPurchaseAmount: totalPurchaseAmount ?? this.totalPurchaseAmount,
      lastVisited: lastVisited ?? this.lastVisited,
      visitCount: visitCount ?? this.visitCount,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      totalPointEarned: totalPointEarned ?? this.totalPointEarned,
      totalPointRedeemed: totalPointRedeemed ?? this.totalPointRedeemed,
      creditBalance: creditBalance ?? this.creditBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      gstNumber: gstNumber ?? this.gstNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'totalPurchaseAmount': totalPurchaseAmount,
      'lastVisited': lastVisited,
      'visitCount':visitCount,
      'pointsBalance':pointsBalance,
      'totalPointEarned':totalPointEarned,
      'totalPointRedeemed':totalPointRedeemed,
      'creditBalance': creditBalance,
      'creditLimit':creditLimit,
      'gstNumber':gstNumber,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}