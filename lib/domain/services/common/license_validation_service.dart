import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import '../../../data/models/restaurant/license_model.dart';

/// Stateless offline validation chain — runs on every app start.
///
/// Returns [LicenseInfo] when the token passes RSA + device + clock checks.
///   • Valid license   → info.isValidLocally == true  → app unlocks
///   • Expired license → info.isValidLocally == false → lock screen "License Expired"
///   • Tampered/wrong device/clock rollback → null   → lock screen "License Required"
class LicenseValidationService {
  // Production RSA-2048 public key (PEM). Replace with your server's public key.
  static const _prodPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
REPLACE_WITH_YOUR_SERVER_RSA_2048_PUBLIC_KEY_PEM
-----END PUBLIC KEY-----''';

  // Set by DevTokenHelper.init() in debug builds only.
  static RSAPublicKey? _devPublicKey;

  /// Called by DevTokenHelper to register the local test public key.
  /// Only has effect in debug builds.
  static void setDevPublicKey(RSAPublicKey key) {
    assert(kDebugMode);
    _devPublicKey = key;
  }

  // ── Device Hash ───────────────────────────────────────────────────────────

  /// SHA-256 of deviceid|devicemodel|deviceos — ties this license to one device.
  static String computeDeviceHash(Map<String, dynamic> device) {
    final raw =
        '${device['deviceid']}|${device['devicemodel']}|${device['deviceos']}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  // ── RSA Signature ─────────────────────────────────────────────────────────

  static bool _verifySignature(String payloadB64, String signatureB64) {
    try {
      // Debug: use the locally generated dev key (set by DevTokenHelper.init())
      // Release: parse the embedded production public key PEM
      final RSAPublicKey publicKey;
      if (kDebugMode && _devPublicKey != null) {
        publicKey = _devPublicKey!;
      } else {
        publicKey =
            enc.RSAKeyParser().parse(_prodPublicKeyPem) as RSAPublicKey;
      }

      final payloadBytes = Uint8List.fromList(
          base64Url.decode(base64Url.normalize(payloadB64)));
      final sigBytes = Uint8List.fromList(
          base64Url.decode(base64Url.normalize(signatureB64)));

      final signer = Signer('SHA-256/RSA');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      return signer.verifySignature(payloadBytes, RSASignature(sigBytes));
    } catch (_) {
      return false;
    }
  }

  // ── Full Validation Chain ─────────────────────────────────────────────────

  /// Runs all checks against the stored signed token.
  ///
  /// Returns null  → tampered payload, wrong device, or clock rollback.
  /// Returns info  → signature + device valid. Caller checks isValidLocally
  ///                 to distinguish active vs expired.
  static LicenseInfo? validate({
    required String rawToken,
    required Map<String, dynamic> currentDevice,
  }) {
    try {
      final tokenMap = jsonDecode(rawToken) as Map<String, dynamic>;
      final payloadB64 = tokenMap['payload'] as String;
      final signatureB64 = tokenMap['signature'] as String;

      // Step 1 — RSA signature (tamper-proof: expiry/plan cannot be edited)
      if (!_verifySignature(payloadB64, signatureB64)) return null;

      // Step 2 — decode payload
      final payloadJson = utf8
          .decode(base64Url.decode(base64Url.normalize(payloadB64)));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      // Step 3 — device hash (license cannot move to another device)
      final currentHash = computeDeviceHash(currentDevice);
      if ((payload['device_hash'] as String?) != currentHash) return null;

      // Step 3.5 — clock rollback protection
      // If system clock is set before activation date, someone rolled it back.
      final activatedAt =
          DateTime.tryParse(payload['activated_at'] as String? ?? '');
      if (activatedAt != null && DateTime.now().isBefore(activatedAt)) {
        return null;
      }

      // Step 4 — return info (may be expired — isLicensed computed prop handles unlocking)
      // Returning expired info (not null) lets the lock screen show "License Expired"
      // instead of "License Required", giving the user the right context.
      return LicenseInfo.fromJson(payload);
    } catch (_) {
      return null;
    }
  }
}