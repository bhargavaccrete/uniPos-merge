import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'admin_model_217.g.dart';

@HiveType(typeId: HiveTypeIds.retailAdmin)
class AdminModel extends HiveObject {
  @HiveField(0)
  final String adminId;

  @HiveField(1)
  final String username;

  @HiveField(2)
  final String passwordHash;

  @HiveField(3)
  final String createdAt;

  @HiveField(4)
  final String updatedAt;

  AdminModel({
    required this.adminId,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new admin with hashed password
  factory AdminModel.create({
    required String adminId,
    required String username,
    required String password,
  }) {
    final now = DateTime.now().toIso8601String();
    return AdminModel(
      adminId: adminId,
      username: username,
      passwordHash: _hashPassword(password),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create default admin account
  factory AdminModel.createDefault() {
    return AdminModel.create(
      adminId: 'admin_default',
      username: 'admin',
      password: 'admin123',
    );
  }

  /// Hash password using SHA-256 with salt
  static String _hashPassword(String password) {
    // Use a fixed salt for simplicity (in production, use unique salt per user)
    const salt = 'rpos_admin_salt_2024';
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify password
  bool verifyPassword(String password) {
    return passwordHash == _hashPassword(password);
  }

  /// Create copy with updated password
  AdminModel copyWithNewPassword(String newPassword) {
    return AdminModel(
      adminId: adminId,
      username: username,
      passwordHash: _hashPassword(newPassword),
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Create copy with updates
  AdminModel copyWith({
    String? adminId,
    String? username,
    String? passwordHash,
    String? createdAt,
    String? updatedAt,
  }) {
    return AdminModel(
      adminId: adminId ?? this.adminId,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'username': username,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      adminId: map['adminId'] as String,
      username: map['username'] as String,
      passwordHash: map['passwordHash'] as String? ?? '',
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }

  @override
  String toString() {
    return 'AdminModel(adminId: $adminId, username: $username)';
  }
}