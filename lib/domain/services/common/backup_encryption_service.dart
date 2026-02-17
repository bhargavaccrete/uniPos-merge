import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles AES-256-CBC encryption/decryption for backup files.
/// Password is stored securely via OS keychain (flutter_secure_storage).
class BackupEncryptionService {
  static const String _passwordHashKey = 'backup_password_hash';
  static const String _passwordKey = 'backup_password'; // Stored for auto-backup use

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---------------------------------------------------------------------------
  // Password Management
  // ---------------------------------------------------------------------------

  /// Returns true if a backup password has been configured.
  static Future<bool> hasPassword() async {
    try {
      final hash = await _storage.read(key: _passwordHashKey);
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Saves the password and its hash to secure storage.
  static Future<void> setPassword(String password) async {
    final hash = _hashPassword(password);
    await _storage.write(key: _passwordHashKey, value: hash);
    await _storage.write(key: _passwordKey, value: password);
  }

  /// Retrieves the stored password (used by auto-backup).
  /// Returns null if no password is configured.
  static Future<String?> getStoredPassword() async {
    try {
      return await _storage.read(key: _passwordKey);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the provided password matches the stored hash.
  static Future<bool> verifyPassword(String password) async {
    try {
      final storedHash = await _storage.read(key: _passwordHashKey);
      if (storedHash == null) return false;
      return _hashPassword(password) == storedHash;
    } catch (_) {
      return false;
    }
  }

  /// Removes the stored password (disables encryption for future backups).
  static Future<void> clearPassword() async {
    await _storage.delete(key: _passwordHashKey);
    await _storage.delete(key: _passwordKey);
  }

  // ---------------------------------------------------------------------------
  // Encryption / Decryption
  // ---------------------------------------------------------------------------

  /// Encrypts a JSON string using AES-256-CBC.
  /// Returns a map with: [encryptedData, salt, iv]
  static Map<String, String> encryptData(String jsonData, String password) {
    final salt = _generateSalt();
    final key = _deriveKey(password, salt);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encrypt(jsonData, iv: iv);

    return {
      'encryptedData': encrypted.base64,
      'salt': salt,
      'iv': base64Encode(iv.bytes),
    };
  }

  /// Decrypts an encrypted backup.
  /// Returns the original JSON string, or null if the password is wrong.
  static String? decryptData({
    required String encryptedBase64,
    required String salt,
    required String ivBase64,
    required String password,
  }) {
    try {
      final key = _deriveKey(password, salt);
      final iv = enc.IV(base64Decode(ivBase64));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = enc.Encrypted.fromBase64(encryptedBase64);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return null; // Wrong password or corrupted data
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// SHA-256 hash of the password (for verification only, never decryptable).
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Generates a random 16-byte salt encoded as Base64.
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Derives a 32-byte AES key from password + salt using SHA-256.
  static enc.Key _deriveKey(String password, String salt) {
    final combined = utf8.encode(password + salt);
    final hash = sha256.convert(combined);
    return enc.Key(Uint8List.fromList(hash.bytes));
  }
}