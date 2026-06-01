import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'license_validation_service.dart';

/// Debug-only helper. Generates a local RSA-2048 key pair and uses it
/// to create properly signed license tokens — the same format the real
/// server will produce. This lets you test the full validation chain
/// (RSA → device hash → expiry) without a real server.
///
/// The private key is stored only in SharedPreferences (debug builds).
/// It is never present in release builds — every method asserts kDebugMode.
class DevTokenHelper {
  DevTokenHelper._();

  static const _prefKey = 'dev_rsa_keypair_v1';

  static RSAPublicKey? _pubKey;
  static RSAPrivateKey? _privKey;

  // ── Init ─────────────────────────────────────────────────────────────────

  /// Loads (or generates on first call) the dev RSA key pair, then registers
  /// the public key with [LicenseValidationService] so validation works.
  ///
  /// First call: generates 2048-bit key pair (~3s), persists to SharedPrefs.
  /// Subsequent calls: loads from SharedPrefs in milliseconds.
  static Future<void> init() async {
    assert(kDebugMode, 'DevTokenHelper must only be used in debug builds');
    if (_pubKey != null) return;
    await _loadOrGenerate();
    LicenseValidationService.setDevPublicKey(_pubKey!);
  }

  // ── Token Creation ────────────────────────────────────────────────────────

  /// Creates a signed token in the exact format the real server will produce:
  /// ```json
  /// { "payload": "<base64url(json)>", "signature": "<base64url(RSA-SHA256)>" }
  /// ```
  /// Pass [customExpiryDate] in the past to create an expired token for testing.
  static Future<String> createSignedToken({
    required String licenseKey,
    required Map<String, dynamic> devicePayload,
    required String deviceHash,
    int validityDays = 30,
    String planName = 'Pro Monthly',
    DateTime? customActivatedAt,
    DateTime? customExpiryDate,
  }) async {
    assert(kDebugMode, 'DevTokenHelper must only be used in debug builds');
    if (_privKey == null) await _loadOrGenerate();

    final activatedAt = customActivatedAt ?? DateTime.now();
    final expiryDate =
        customExpiryDate ?? activatedAt.add(Duration(days: validityDays));

    final payloadJson = jsonEncode({
      'license_key': licenseKey,
      'status': 'active',
      'plan_name': planName,
      'expiry_date': expiryDate.toIso8601String(),
      'activated_at': activatedAt.toIso8601String(),
      'validity_days': validityDays,
      'device_hash': deviceHash,
      'device': devicePayload,
    });

    final payloadBytes = Uint8List.fromList(utf8.encode(payloadJson));
    final payloadB64 = base64Url.encode(payloadBytes);

    final signer = Signer('SHA-256/RSA');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(_privKey!));
    final sig = signer.generateSignature(payloadBytes) as RSASignature;

    return jsonEncode({
      'payload': payloadB64,
      'signature': base64Url.encode(sig.bytes),
    });
  }

  // ── Key Generation / Loading ──────────────────────────────────────────────

  static Future<void> _loadOrGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);

    if (stored != null) {
      try {
        final m = jsonDecode(stored) as Map<String, dynamic>;
        final n = BigInt.parse(m['n'] as String, radix: 16);
        final e = BigInt.parse(m['e'] as String, radix: 16);
        final d = BigInt.parse(m['d'] as String, radix: 16);
        final p = BigInt.parse(m['p'] as String, radix: 16);
        final q = BigInt.parse(m['q'] as String, radix: 16);
        _pubKey = RSAPublicKey(n, e);
        _privKey = RSAPrivateKey(n, d, p, q);
        return;
      } catch (_) {}
    }

    // First run — generate a 2048-bit RSA key pair (takes ~3 seconds)
    final random = FortunaRandom();
    final seed = Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    random.seed(KeyParameter(seed));

    final gen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        random,
      ));

    final pair = gen.generateKeyPair();
    _pubKey = pair.publicKey as RSAPublicKey;
    _privKey = pair.privateKey as RSAPrivateKey;

    // Persist so subsequent runs are instant
    await prefs.setString(_prefKey, jsonEncode({
      'n': _pubKey!.modulus!.toRadixString(16),
      'e': _pubKey!.publicExponent!.toRadixString(16),
      'd': _privKey!.privateExponent!.toRadixString(16),
      'p': _privKey!.p!.toRadixString(16),
      'q': _privKey!.q!.toRadixString(16),
    }));
  }
}