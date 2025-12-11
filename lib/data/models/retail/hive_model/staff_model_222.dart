import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'staff_model_222.g.dart';

/// Comprehensive Staff Model for Retail POS
/// Contains both basic info and POS-specific access & permissions
@HiveType(typeId: HiveTypeIds.retailStaff)
class RetailStaffModel extends HiveObject {
  // ===== BASIC INFORMATION =====
  @HiveField(0)
  final String id; // Unique staff ID

  @HiveField(1)
  final String firstName;

  @HiveField(2)
  final String lastName;

  @HiveField(3)
  final String? email;

  @HiveField(4)
  final String? phone;

  @HiveField(5)
  final String? address;

  // ===== POS ACCESS =====
  @HiveField(6)
  final String username; // For POS login

  @HiveField(7)
  final String pin; // 4-6 digit PIN for quick login

  @HiveField(8)
  final String? passwordHash; // Optional password for full login

  @HiveField(9)
  final String role; // Manager, Cashier, Sales, Inventory

  // ===== WORK DETAILS =====
  @HiveField(10)
  final String? employeeId; // Company employee ID

  @HiveField(11)
  final String? department; // Sales, Service, Warehouse, etc.

  @HiveField(12)
  final String? shift; // Morning, Afternoon, Evening, Night

  @HiveField(13)
  final DateTime? hireDate;

  // ===== POS PERMISSIONS =====
  @HiveField(14)
  final bool canProcessSales; // Can complete sale transactions

  @HiveField(15)
  final bool canProcessReturns; // Can process returns/refunds

  @HiveField(16)
  final bool canGiveDiscounts; // Can apply discounts

  @HiveField(17)
  final double? maxDiscountPercent; // Maximum discount percentage allowed

  @HiveField(18)
  final bool canAccessReports; // Can view reports

  @HiveField(19)
  final bool canManageInventory; // Can add/edit products

  @HiveField(20)
  final bool canManageStaff; // Can add/edit staff

  @HiveField(21)
  final bool canVoidTransactions; // Can void/cancel transactions

  @HiveField(22)
  final bool canOpenCashDrawer; // Can manually open cash drawer

  // ===== STATUS & AUDIT =====
  @HiveField(23)
  final bool isActive; // Active/Inactive status

  @HiveField(24)
  final DateTime createdAt;

  @HiveField(25)
  final DateTime? lastLoginAt;

  @HiveField(26)
  final String? notes; // Additional notes

  RetailStaffModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.address,
    required this.username,
    required this.pin,
    this.passwordHash,
    required this.role,
    this.employeeId,
    this.department,
    this.shift,
    this.hireDate,
    this.canProcessSales = true,
    this.canProcessReturns = false,
    this.canGiveDiscounts = false,
    this.maxDiscountPercent,
    this.canAccessReports = false,
    this.canManageInventory = false,
    this.canManageStaff = false,
    this.canVoidTransactions = false,
    this.canOpenCashDrawer = false,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.notes,
  });

  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Check if user has manager-level permissions
  bool get isManager =>
      role.toLowerCase() == 'manager' ||
      canManageStaff ||
      canManageInventory;

  /// Verify PIN
  bool verifyPin(String inputPin) {
    return pin == inputPin;
  }

  /// Create copy with updated last login
  RetailStaffModel copyWithLastLogin() {
    return copyWith(lastLoginAt: DateTime.now());
  }

  /// Copy with
  RetailStaffModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? username,
    String? pin,
    String? passwordHash,
    String? role,
    String? employeeId,
    String? department,
    String? shift,
    DateTime? hireDate,
    bool? canProcessSales,
    bool? canProcessReturns,
    bool? canGiveDiscounts,
    double? maxDiscountPercent,
    bool? canAccessReports,
    bool? canManageInventory,
    bool? canManageStaff,
    bool? canVoidTransactions,
    bool? canOpenCashDrawer,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? notes,
  }) {
    return RetailStaffModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      username: username ?? this.username,
      pin: pin ?? this.pin,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      shift: shift ?? this.shift,
      hireDate: hireDate ?? this.hireDate,
      canProcessSales: canProcessSales ?? this.canProcessSales,
      canProcessReturns: canProcessReturns ?? this.canProcessReturns,
      canGiveDiscounts: canGiveDiscounts ?? this.canGiveDiscounts,
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      canAccessReports: canAccessReports ?? this.canAccessReports,
      canManageInventory: canManageInventory ?? this.canManageInventory,
      canManageStaff: canManageStaff ?? this.canManageStaff,
      canVoidTransactions: canVoidTransactions ?? this.canVoidTransactions,
      canOpenCashDrawer: canOpenCashDrawer ?? this.canOpenCashDrawer,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      notes: notes ?? this.notes,
    );
  }

  /// Convert to map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'username': username,
      'pin': pin,
      'role': role,
      'employeeId': employeeId,
      'department': department,
      'shift': shift,
      'hireDate': hireDate?.toIso8601String(),
      'canProcessSales': canProcessSales,
      'canProcessReturns': canProcessReturns,
      'canGiveDiscounts': canGiveDiscounts,
      'maxDiscountPercent': maxDiscountPercent,
      'canAccessReports': canAccessReports,
      'canManageInventory': canManageInventory,
      'canManageStaff': canManageStaff,
      'canVoidTransactions': canVoidTransactions,
      'canOpenCashDrawer': canOpenCashDrawer,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Create from map for import
  factory RetailStaffModel.fromMap(Map<String, dynamic> map) {
    return RetailStaffModel(
      id: map['id'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      username: map['username'] ?? '',
      pin: map['pin'] ?? '',
      passwordHash: map['passwordHash'],
      role: map['role'] ?? 'Cashier',
      employeeId: map['employeeId'],
      department: map['department'],
      shift: map['shift'],
      hireDate: map['hireDate'] != null ? DateTime.tryParse(map['hireDate']) : null,
      canProcessSales: map['canProcessSales'] ?? true,
      canProcessReturns: map['canProcessReturns'] ?? false,
      canGiveDiscounts: map['canGiveDiscounts'] ?? false,
      maxDiscountPercent: map['maxDiscountPercent']?.toDouble(),
      canAccessReports: map['canAccessReports'] ?? false,
      canManageInventory: map['canManageInventory'] ?? false,
      canManageStaff: map['canManageStaff'] ?? false,
      canVoidTransactions: map['canVoidTransactions'] ?? false,
      canOpenCashDrawer: map['canOpenCashDrawer'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null ? DateTime.tryParse(map['lastLoginAt']) : null,
      notes: map['notes'],
    );
  }

  /// Create default manager role preset
  static RetailStaffModel createManager({
    required String id,
    required String firstName,
    required String lastName,
    required String username,
    required String pin,
    String? email,
    String? phone,
  }) {
    return RetailStaffModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      username: username,
      pin: pin,
      role: 'Manager',
      canProcessSales: true,
      canProcessReturns: true,
      canGiveDiscounts: true,
      maxDiscountPercent: 50.0,
      canAccessReports: true,
      canManageInventory: true,
      canManageStaff: true,
      canVoidTransactions: true,
      canOpenCashDrawer: true,
      createdAt: DateTime.now(),
    );
  }

  /// Create default cashier role preset
  static RetailStaffModel createCashier({
    required String id,
    required String firstName,
    required String lastName,
    required String username,
    required String pin,
    String? email,
    String? phone,
  }) {
    return RetailStaffModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      username: username,
      pin: pin,
      role: 'Cashier',
      canProcessSales: true,
      canProcessReturns: false,
      canGiveDiscounts: false,
      canAccessReports: false,
      canManageInventory: false,
      canManageStaff: false,
      canVoidTransactions: false,
      canOpenCashDrawer: true,
      createdAt: DateTime.now(),
    );
  }
}