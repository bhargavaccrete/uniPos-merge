import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Verified entitlements manifest returned by [ManifestService.verifyAndParse].
class ManifestData {
  final Map<String, dynamic> entitlements;
  final Map<String, dynamic> license;
  final int version;

  const ManifestData({
    required this.entitlements,
    required this.license,
    required this.version,
  });
}

/// Verifies the Ed25519-signed entitlements manifest before it is trusted.
///
/// The signature covers the EXACT UTF-8 bytes of the manifest STRING — so we
/// verify the raw string first and only then [jsonDecode] it. Never re-serialize
/// the decoded object: key reordering would change the bytes and break the check.
class ManifestService {
  ManifestService._();

  // Raw 32-byte Ed25519 public key (base64). Bundled, NOT fetched at runtime —
  // fetching would defeat the purpose. From GET /mobile/license/public-key.
  // TODO(license): confirm this matches the LIVE server's signing key.
  static const _publicKeyB64 = 'zTUI0t+aX5NMpOK+W+Re3X5p4+P+EATRw7Gs+MXs88Q=';

  static final _algo = Ed25519();

  /// Verifies [manifestRaw] against [sigB64], then decodes and checks identity.
  /// Returns null on any failure (bad signature, wrong device, key mismatch,
  /// malformed JSON) — callers fall back to their cached/restrictive state.
  static Future<ManifestData?> verifyAndParse({
    required String manifestRaw,
    required String sigB64,
    required String deviceId,
    required String licenseKey,
  }) async {
    try {
      if (!await _verify(manifestRaw, sigB64)) {
        if (kDebugMode) debugPrint('── MANIFEST verify FAILED (signature)');
        return null;
      }

      final m = jsonDecode(manifestRaw) as Map<String, dynamic>;

      // Anti-copy: a manifest lifted from another device/key must be rejected.
      if (m['deviceid'] != deviceId) {
        if (kDebugMode) debugPrint('── MANIFEST deviceid mismatch');
        return null;
      }
      if (m['licensekey'] != licenseKey) {
        if (kDebugMode) debugPrint('── MANIFEST licensekey mismatch');
        return null;
      }

      final ent = (m['entitlements'] as Map?)?.cast<String, dynamic>() ?? {};
      final lic = (m['license'] as Map?)?.cast<String, dynamic>() ?? {};
      final version = (m['version'] as num?)?.toInt() ?? 0;
      return ManifestData(entitlements: ent, license: lic, version: version);
    } catch (e) {
      if (kDebugMode) debugPrint('── MANIFEST parse error: $e');
      return null;
    }
  }

  static Future<bool> _verify(String msg, String sigB64) async {
    final publicKey = SimplePublicKey(
      base64Decode(_publicKeyB64),
      type: KeyPairType.ed25519,
    );
    final signature = Signature(
      base64Decode(sigB64),
      publicKey: publicKey,
    );
    return _algo.verify(utf8.encode(msg), signature: signature);
  }
}
