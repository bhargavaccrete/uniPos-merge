

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/retail/hive_model/admin_model_217.dart';
import '../../../data/repositories/retail/admin_repository.dart';

/// Authentication result
class AuthResult {
  final bool success;
  final String? errorMessage;
  final AdminModel? admin;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.admin,
  });

  factory AuthResult.success(AdminModel admin) => AuthResult(
        success: true,
        admin: admin,
      );

  factory AuthResult.failure(String message) => AuthResult(
        success: false,
        errorMessage: message,
      );
}

/// Authentication Service for session management
class AuthService {
  static const String _sessionKey = 'admin_session';
  static const String _sessionTimestampKey = 'admin_session_timestamp';
  static const String _usernameKey = 'admin_username';

  final AdminRepository _adminRepository;

  // Current logged in admin (cached)
  AdminModel? _currentAdmin;

  AuthService(this._adminRepository);

  /// Get current logged in admin
  AdminModel? get currentAdmin => _currentAdmin;

  /// Check if user is logged in
  bool get isLoggedIn => _currentAdmin != null;

  /// Initialize auth service - check for existing session
  Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = prefs.getBool(_sessionKey) ?? false;

    if (hasSession) {
      // Verify session is still valid
      final admin = await _adminRepository.getAdmin();
      if (admin != null) {
        _currentAdmin = admin;
        return true;
      }
    }

    return false;
  }

  /// Ensure default admin exists
  Future<void> ensureDefaultAdmin() async {
    await _adminRepository.ensureDefaultAdmin();
  }

  /// Login with username and password
  Future<AuthResult> login(String username, String password) async {
    // Validate input
    if (username.trim().isEmpty) {
      return AuthResult.failure('Username is required');
    }

    if (password.isEmpty) {
      return AuthResult.failure('Password is required');
    }

    // Authenticate
    final admin = await _adminRepository.authenticate(
      username.trim(),
      password,
    );

    if (admin == null) {
      return AuthResult.failure('Invalid username or password');
    }

    // Save session
    await _saveSession(admin);
    _currentAdmin = admin;

    return AuthResult.success(admin);
  }

  /// Logout
  Future<void> logout() async {
    await _clearSession();
    _currentAdmin = null;
  }

  /// Change password
  Future<AuthResult> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // Validate input
    if (oldPassword.isEmpty) {
      return AuthResult.failure('Current password is required');
    }

    if (newPassword.isEmpty) {
      return AuthResult.failure('New password is required');
    }

    if (newPassword.length < 6) {
      return AuthResult.failure('New password must be at least 6 characters');
    }

    if (newPassword != confirmPassword) {
      return AuthResult.failure('New passwords do not match');
    }

    if (oldPassword == newPassword) {
      return AuthResult.failure('New password must be different from current password');
    }

    // Update password
    final success = await _adminRepository.updatePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (!success) {
      return AuthResult.failure('Current password is incorrect');
    }

    // Refresh current admin
    _currentAdmin = await _adminRepository.getAdmin();

    return AuthResult.success(_currentAdmin!);
  }

  /// Save session to SharedPreferences
  Future<void> _saveSession(AdminModel admin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_usernameKey, admin.username);
    await prefs.setString(
      _sessionTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Clear session from SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_sessionTimestampKey);
  }

  /// Get session info
  Future<Map<String, dynamic>> getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hasSession': prefs.getBool(_sessionKey) ?? false,
      'username': prefs.getString(_usernameKey),
      'loginTime': prefs.getString(_sessionTimestampKey),
    };
  }
}