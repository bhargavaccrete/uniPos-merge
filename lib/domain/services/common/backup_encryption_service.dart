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

  /// Single source of truth for the backup-password policy — used by the
  /// onboarding Security step, the Settings dialog, and the export gate.
  /// Returns an error message to show the user, or null when the input is valid.
  static String? validatePassword(String password, String confirm) {
    if (password.isEmpty) return 'Please enter a backup password';
    if (!RegExp(r'^\d{6}$').hasMatch(password)) {
      return 'Backup password must be 6 digits';
    }
    if (password != confirm) return 'Backup passwords do not match';
    return null;
  }

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
  // Binary blob encryption (whole-file lock — nothing is browsable)
  // ---------------------------------------------------------------------------

  /// Magic header marking a Bill Berry Lite encrypted backup blob.
  static final List<int> _blobMagic = utf8.encode('BBLTENC1'); // 8 bytes

  /// Encrypts arbitrary bytes (e.g. a whole zip) into a self-contained opaque
  /// blob: [magic][saltLen][salt][ivLen][iv][AES-CBC ciphertext]. The result
  /// has no readable structure — it can only be opened by [decryptBytes].
  static Uint8List encryptBytes(Uint8List data, String password) {
    final salt = _generateSalt(); // base64 string
    final key = _deriveKey(password, salt);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    final saltBytes = utf8.encode(salt);
    final out = BytesBuilder();
    out.add(_blobMagic);
    out.addByte(saltBytes.length);
    out.add(saltBytes);
    out.addByte(iv.bytes.length);
    out.add(iv.bytes);
    out.add(encrypted.bytes);
    return out.toBytes();
  }

  /// Reverses [encryptBytes]. Returns null on wrong password / bad data.
  static Uint8List? decryptBytes(Uint8List blob, String password) {
    try {
      if (!isEncryptedBlob(blob)) return null;
      var p = _blobMagic.length;
      final saltLen = blob[p++];
      final salt = utf8.decode(blob.sublist(p, p + saltLen));
      p += saltLen;
      final ivLen = blob[p++];
      final iv = enc.IV(Uint8List.fromList(blob.sublist(p, p + ivLen)));
      p += ivLen;
      final cipher = blob.sublist(p);
      final key = _deriveKey(password, salt);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final plain = encrypter
          .decryptBytes(enc.Encrypted(Uint8List.fromList(cipher)), iv: iv);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }

  /// True if [bytes] begins with the Bill Berry Lite encrypted-backup magic header.
  static bool isEncryptedBlob(List<int> bytes) {
    if (bytes.length < _blobMagic.length) return false;
    for (var i = 0; i < _blobMagic.length; i++) {
      if (bytes[i] != _blobMagic[i]) return false;
    }
    return true;
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