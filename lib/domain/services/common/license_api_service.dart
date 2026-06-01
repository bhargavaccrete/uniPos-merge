import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'device_payload_service.dart';
import 'location_service.dart';

class LicenseApiException implements Exception {
  final String message;
  const LicenseApiException(this.message);
  @override
  String toString() => message;
}

/// Pure HTTP layer for the licensing server.
/// Each method returns the parsed [data] block or throws [LicenseApiException].
class LicenseApiService {
  // ── API Config ─────────────────────────────────────────────────────────────
  static const _baseUrl = 'http://192.168.120.47:8005';
  static const _validateKeyPath = '/api/v1/mobile/license/validate';
  static const _activatePath = '/api/v1/mobile/license/activate';
  static const _statusPath = '/api/v1/mobile/license/status';
  static const _heartbeatPath = '/api/v1/mobile/license/heartbeat';
  static const _deactivatePath = '/api/v1/mobile/license/deactivate';
  static const _timeout = Duration(seconds: 15);
  static const _headers = {
    'Content-Type': 'application/json',
    'X-Device-Key': '66e6c682046bd7998b86bc27ed26963ad260e04b8fd62f76d48b9e718ffdee65',
  };

  // ── Validate Key ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> validateKey(String key) async {
    final device = await DevicePayloadService.build();
    return _post(_validateKeyPath, {'licensekey': key, 'device': device});
  }

  // ── Activate ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> activate({
    required String key,
    required String businessName,
    int businessCategory = 6,
  }) async {
    final device = await DevicePayloadService.build();
    final location = await LocationService.build();
    return _post(_activatePath, {
      'licensekey': key,
      'device': device,
      'businesscategory': businessCategory,
      'businessname': businessName,
      'location': location,
    });
  }

  // ── Status ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> checkStatus(String licenseKey) async {
    final device = await DevicePayloadService.build();
    return _post(_statusPath, {
      'licensekey': licenseKey,
      'deviceid': device['deviceid'],
      'device': device,
    });
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  /// Returns true = server accepted, false = server rejected.
  /// Throws on network errors so the caller can apply offline grace.
  Future<bool> heartbeat(String licenseKey) async {
    final device = await DevicePayloadService.build();
    final requestBody = {
      'licensekey': licenseKey,
      'deviceid': device['deviceid'],
      'device': device,
    };

    if (kDebugMode) {
      const pretty = JsonEncoder.withIndent('  ');
      debugPrint('── LICENSE API REQUEST ─────────────────────────');
      debugPrint('POST $_baseUrl$_heartbeatPath');
      debugPrint(pretty.convert(requestBody));
      debugPrint('────────────────────────────────────────────────');
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl$_heartbeatPath'),
          headers: _headers,
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 10));

    if (kDebugMode) {
      debugPrint('── LICENSE API RESPONSE ────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint(response.body);
      debugPrint('────────────────────────────────────────────────');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final s = body['success'];
    return response.statusCode == 200 && (s == 1 || s == true);
  }

  // ── Deactivate ────────────────────────────────────────────────────────────

  Future<void> deactivate(String licenseKey) async {
    final device = await DevicePayloadService.build();
    final requestBody = {
      'licensekey': licenseKey,
      'deviceid': device['deviceid'],
      'device': device,
    };
    if (kDebugMode) {
      const pretty = JsonEncoder.withIndent('  ');
      debugPrint('── LICENSE API REQUEST ─────────────────────────');
      debugPrint('POST $_baseUrl$_deactivatePath');
      debugPrint(pretty.convert(requestBody));
      debugPrint('────────────────────────────────────────────────');
    }
    final response = await http
        .post(
          Uri.parse('$_baseUrl$_deactivatePath'),
          headers: _headers,
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      debugPrint('── LICENSE API RESPONSE ────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint(response.body);
      debugPrint('────────────────────────────────────────────────');
    }
  }

  // ── Core HTTP Helper ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      if (kDebugMode) {
        const pretty = JsonEncoder.withIndent('  ');
        debugPrint('── LICENSE API REQUEST ─────────────────────────');
        debugPrint('POST $_baseUrl$path');
        debugPrint(pretty.convert(body));
        debugPrint('────────────────────────────────────────────────');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('── LICENSE API RESPONSE ────────────────────────');
        debugPrint('Status: ${response.statusCode}');
        debugPrint(response.body);
        debugPrint('────────────────────────────────────────────────');
      }

      final responseBody =
          jsonDecode(response.body) as Map<String, dynamic>;
      final success = responseBody['success'];

      if (response.statusCode != 200 ||
          (success != 1 && success != true)) {
        throw LicenseApiException(
            responseBody['message'] as String? ?? 'Request failed');
      }

      final data = responseBody['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const LicenseApiException(
            'Invalid server response. Contact support.');
      }
      return data;
    } on LicenseApiException {
      rethrow;
    } on TimeoutException {
      throw const LicenseApiException(
          'Connection timed out. Please try again.');
    } on http.ClientException {
      throw const LicenseApiException(
          'No internet connection. Please try again.');
    } catch (e) {
      if (e is LicenseApiException) rethrow;
      throw const LicenseApiException('Unexpected error. Please try again.');
    }
  }
}
