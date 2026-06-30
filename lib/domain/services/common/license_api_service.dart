import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:billberrylite/core/constants/api_constants.dart';
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
  static const _timeout = Duration(seconds: 15);

  // ── Validate Key ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> validateKey(String key) async {
    final device = await DevicePayloadService.build();
    return _post(
        ApiConstants.licenseValidatePath, {'licensekey': key, 'device': device});
  }

  // ── Activate ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> activate({
    required String key,
    required String businessName,
    int businessCategory = 6,
  }) async {
    final device = await DevicePayloadService.build();
    final location = await LocationService.build();
    return _post(ApiConstants.licenseActivatePath, {
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
    return _post(ApiConstants.licenseStatusPath, {
      'licensekey': licenseKey,
      'deviceid': device['deviceid'],
      'device': device,
    });
  }

  // ── Sync (startup check + entitlement change detection) ────────────────────

  /// Returns the `data` block whether the server verdict is valid or not (a
  /// revoked/expired key comes back as a fail envelope but still carries the
  /// `reason` in `data`, which the store needs). Throws only on transport
  /// errors so the caller can apply offline grace and keep the cached manifest.
  Future<Map<String, dynamic>> sync({
    required String licenseKey,
    required String deviceId,
    required int entitlementVersion,
  }) async {
    final requestBody = {
      'licensekey': licenseKey,
      'deviceid': deviceId,
      'entitlementversion': entitlementVersion,
    };

    if (kDebugMode) {
      const pretty = JsonEncoder.withIndent('  ');
      debugPrint('── LICENSE API REQUEST ─────────────────────────');
      debugPrint('POST ${ApiConstants.baseUrl}${ApiConstants.licenseSyncPath}');
      debugPrint(pretty.convert(requestBody));
      debugPrint('────────────────────────────────────────────────');
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.licenseSyncPath}'),
            headers: ApiConstants.headers,
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('── LICENSE API RESPONSE ────────────────────────');
        debugPrint('Status: ${response.statusCode}');
        debugPrint(response.body);
        debugPrint('────────────────────────────────────────────────');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? const {};
    } on TimeoutException {
      throw const LicenseApiException('Connection timed out.');
    } on http.ClientException catch (e) {
      if (kDebugMode) debugPrint('── LICENSE SYNC NETWORK ERROR ── $e');
      throw const LicenseApiException('Could not reach the server.');
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('── LICENSE SYNC SOCKET ERROR ── $e');
      throw const LicenseApiException('Could not reach the server.');
    }
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
      debugPrint('POST ${ApiConstants.baseUrl}${ApiConstants.licenseHeartbeatPath}');
      debugPrint(pretty.convert(requestBody));
      debugPrint('────────────────────────────────────────────────');
    }

    final response = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.licenseHeartbeatPath}'),
          headers: ApiConstants.headers,
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
      debugPrint('POST ${ApiConstants.baseUrl}${ApiConstants.licenseDeactivatePath}');
      debugPrint(pretty.convert(requestBody));
      debugPrint('────────────────────────────────────────────────');
    }
    final response = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.licenseDeactivatePath}'),
          headers: ApiConstants.headers,
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

  // ── Self-Signup (Email OTP → License Key) ──────────────────────────────────

  /// Registers the business and triggers an OTP email. [signup] is the full
  /// signup body assembled by the store (customername, businesscategory, …).
  Future<Map<String, dynamic>> requestSignupOtp(
          Map<String, dynamic> signup) =>
      _post(ApiConstants.licenseRequestOtp, signup);

  /// Verifies the emailed OTP. On success the server issues + emails the
  /// license key; the response `data` also carries `licensekey`.
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      _post(ApiConstants.licenseVerifyOtp, {'email': email, 'otp': otp});

  /// Re-sends the OTP to [email]. Returns a fresh `expiresat`/`expiryMinutes`.
  Future<Map<String, dynamic>> resendOtp(String email) =>
      _post(ApiConstants.licenseResendOtp, {'email': email});

  // ── Core HTTP Helper ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      if (kDebugMode) {
        const pretty = JsonEncoder.withIndent('  ');
        debugPrint('── LICENSE API REQUEST ─────────────────────────');
        debugPrint('POST ${ApiConstants.baseUrl}$path');
        debugPrint(pretty.convert(body));
        debugPrint('────────────────────────────────────────────────');
      }

      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}$path'),
            headers: ApiConstants.headers,
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

      final ok2xx = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok2xx || (success != 1 && success != true)) {
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
    } on http.ClientException catch (e) {
      // ClientException covers far more than "no internet": cleartext-blocked,
      // connection refused, connection reset, host unreachable, etc. Log the
      // real reason so a misleading "no internet" never masks the true cause.
      if (kDebugMode) debugPrint('── LICENSE API NETWORK ERROR ── $e');
      throw const LicenseApiException(
          'Could not reach the server. Check your connection and try again.');
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('── LICENSE API SOCKET ERROR ── $e');
      throw const LicenseApiException(
          'Could not reach the server. Check your connection and try again.');
    } catch (e) {
      if (e is LicenseApiException) rethrow;
      if (kDebugMode) debugPrint('── LICENSE API UNEXPECTED ERROR ── $e');
      throw const LicenseApiException('Unexpected error. Please try again.');
    }
  }
}
