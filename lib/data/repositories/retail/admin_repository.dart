import 'package:hive/hive.dart';

import '../../models/retail/hive_model/admin_model_217.dart';

/// Repository for Admin user management
class AdminRepository {
  late Box<AdminModel> _adminBox;

  AdminRepository() {
    _adminBox = Hive.box<AdminModel>('admin_box');
  }

  /// Get the admin user (only one admin)
  Future<AdminModel?> getAdmin() async {
    if (_adminBox.isEmpty) {
      return null;
    }
    return _adminBox.values.first;
  }

  /// Check if admin exists
  Future<bool> hasAdmin() async {
    return _adminBox.isNotEmpty;
  }

  /// Create default admin if not exists
  Future<AdminModel> ensureDefaultAdmin() async {
    final existing = await getAdmin();
    if (existing != null) {
      return existing;
    }

    final defaultAdmin = AdminModel.createDefault();
    await _adminBox.put(defaultAdmin.adminId, defaultAdmin);
    return defaultAdmin;
  }

  /// Authenticate admin with username and password
  Future<AdminModel?> authenticate(String username, String password) async {
    final admin = await getAdmin();
    if (admin == null) {
      return null;
    }

    if (admin.username.toLowerCase() != username.toLowerCase()) {
      return null;
    }

    if (!admin.verifyPassword(password)) {
      return null;
    }

    return admin;
  }

  /// Update admin password
  Future<bool> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final admin = await getAdmin();
    if (admin == null) {
      return false;
    }

    // Verify old password
    if (!admin.verifyPassword(oldPassword)) {
      return false;
    }

    // Update with new password
    final updatedAdmin = admin.copyWithNewPassword(newPassword);
    await _adminBox.put(admin.adminId, updatedAdmin);
    return true;
  }

  /// Update admin (for other updates)
  Future<void> updateAdmin(AdminModel admin) async {
    await _adminBox.put(admin.adminId, admin);
  }

  /// Reset to default admin (for testing/recovery)
  Future<AdminModel> resetToDefault() async {
    await _adminBox.clear();
    return ensureDefaultAdmin();
  }
}