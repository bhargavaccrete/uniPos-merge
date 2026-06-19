import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/license_model.dart';
import '../../../domain/services/common/device_payload_service.dart';
import '../../../domain/services/common/dev_token_helper.dart';
import '../../../domain/services/common/license_api_service.dart';
import '../../../domain/services/common/license_validation_service.dart';

part 'license_store.g.dart';

class LicenseStore = _LicenseStore with _$LicenseStore; // ignore: use_of_private_type_in_public_api

abstract class _LicenseStore with Store {
  final LicenseApiService _api;
  _LicenseStore(this._api);

  static const _tokenKey = 'unipos_license_token';
  static const _deviceIdKey = '_stored_device_id';
  static const _pendingKeyStorageKey = 'unipos_pending_license_key';
  // Temporary bypass flag (e.g. web where activation is unavailable). Stored in
  // SharedPreferences so it works on web (secure storage is unreliable there).
  static const _bypassKey = 'unipos_license_bypass';
  // Anti-rollback "high-water-mark": furthest-forward time we've ever seen
  // (ms since epoch). Expiry is checked against max(now, this) so setting the
  // device clock backward cannot make an expired license look valid.
  static const _lastSeenKey = 'unipos_last_seen_epoch';
  static const _storage = FlutterSecureStorage();

  Timer? _heartbeatTimer;

  // Loaded/advanced by [_loadAndAdvanceTrustedClock]. A plain field (not an
  // @observable) so no MobX codegen change is needed — isLicensed recomputes
  // when licenseInfo changes, by which point this is already loaded.
  int _trustedNowMs = 0;

  /// When true, the app behaves as licensed without an actual activation.
  /// Set via [skipLicense]; cleared via [clearBypass].
  @observable
  bool licenseBypassed = false;

  @observable
  LicenseInfo? licenseInfo;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  LicenseStatus get status =>
      licenseInfo?.status ?? LicenseStatus.notActivated;

  @computed
  bool get isLicensed =>
      licenseBypassed ||
      (licenseInfo?.isValidLocallyAsOf(_trustedNow()) ?? false);

  @computed
  bool get isExpiringSoon =>
      licenseInfo != null &&
      licenseInfo!.isValidLocally &&
      licenseInfo!.daysRemaining <= 7;

  @computed
  DeviceInfo? get deviceInfo => licenseInfo?.deviceInfo;

  // ── Storage Helpers ───────────────────────────────────────────────────────

  Future<void> _saveToken(String rawToken) async {
    await _storage.write(key: _tokenKey, value: rawToken);
  }

  Future<void> _applyServerData(Map<String, dynamic> data) async {
    final devicePayload = await DevicePayloadService.build();
    final info = LicenseInfo.fromServerJson(data, devicePayload);
    // Server is authoritative — reset the trusted clock to its time (may correct
    // a poisoned forward clock). Done before licenseInfo so isLicensed recomputes
    // against the corrected time.
    await _resetTrustedClockFromServer(info);
    licenseInfo = info;
    final storedJson = {
      ...info.toJson(),
      _deviceIdKey: devicePayload['deviceid'],
    };
    await _saveToken(jsonEncode(storedJson));
  }

  Future<void> _lockLicense() async {
    stopHeartbeatTimer();
    await _storage.delete(key: _tokenKey);
    licenseInfo = null;
  }

  // ── Anti-rollback trusted clock (high-water-mark) ──────────────────────────

  /// The trusted "now": never earlier than the stored high-water-mark, so a
  /// rolled-back device clock is ignored for expiry purposes.
  DateTime _trustedNow() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ms = nowMs > _trustedNowMs ? nowMs : _trustedNowMs;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Loads the stored high-water-mark, advances it to max(now, stored, seedFrom)
  /// and persists it. Must run before [isLicensed] is read at startup/activation
  /// so a backward-set clock is caught on the very first check.
  Future<void> _loadAndAdvanceTrustedClock({DateTime? seedFrom}) async {
    int stored = 0;
    try {
      final raw = await _storage.read(key: _lastSeenKey);
      stored = int.tryParse(raw ?? '') ?? 0;
    } catch (_) {}
    // First run after activation: seed from the server-issued activation date.
    if (stored == 0 && seedFrom != null) {
      stored = seedFrom.millisecondsSinceEpoch;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _trustedNowMs = nowMs > stored ? nowMs : stored; // high-water-mark (max)
    try {
      await _storage.write(key: _lastSeenKey, value: '$_trustedNowMs');
    } catch (_) {}
  }

  /// Resets the trusted clock to the server's authoritative time (expiry minus
  /// remaining days). Unlike the offline high-water-mark, this may move the mark
  /// DOWN — but only on a verified server response, which lets a valid license
  /// recover from an accidental forward-clock "poison" WITHOUT reopening the
  /// offline rollback hole (a backward device clock alone can never do this).
  Future<void> _resetTrustedClockFromServer(LicenseInfo info) async {
    DateTime serverNow;
    if (info.expiryDate != null && info.validityDays > 0) {
      serverNow = info.expiryDate!.subtract(Duration(days: info.validityDays));
    } else {
      serverNow = DateTime.now();
    }
    _trustedNowMs = serverNow.millisecondsSinceEpoch;
    try {
      await _storage.write(key: _lastSeenKey, value: '$_trustedNowMs');
    } catch (_) {}
  }

  // ── Load & Validate ───────────────────────────────────────────────────────

  // ── License bypass (skip) ─────────────────────────────────────────────────

  /// Loads the persisted bypass flag. Call at startup before guarding routes.
  @action
  Future<void> loadBypassFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      licenseBypassed = prefs.getBool(_bypassKey) ?? false;
    } catch (_) {}
  }

  /// Bypass the license requirement so the app is not locked. Persists across
  /// restarts. Used as a temporary "Skip for now" escape hatch.
  @action
  Future<void> skipLicense() async {
    licenseBypassed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bypassKey, true);
    } catch (_) {}
  }

  /// Re-enables the license gate (clears the skip).
  @action
  Future<void> clearBypass() async {
    licenseBypassed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bypassKey);
    } catch (_) {}
  }

  @action
  Future<void> loadCachedLicense() async {
    await loadBypassFlag();
    try {
      final rawToken = await _storage.read(key: _tokenKey);
      if (rawToken == null) return;

      final tokenMap = jsonDecode(rawToken) as Map<String, dynamic>;

      // Debug signed-token path (created by DevTokenHelper / injectMockLicense)
      if (tokenMap.containsKey('payload')) {
        if (kDebugMode) await DevTokenHelper.init();
        final devicePayload = await DevicePayloadService.build();
        final info = LicenseValidationService.validate(
          rawToken: rawToken,
          currentDevice: devicePayload,
        );
        await _loadAndAdvanceTrustedClock(seedFrom: info?.activatedAt);
        licenseInfo = info;
        if (licenseInfo != null) startHeartbeatTimer();
        return;
      }

      // Production plain-JSON path — device binding check
      final devicePayload = await DevicePayloadService.build();
      final currentDeviceId = devicePayload['deviceid'] as String? ?? '';
      final storedDeviceId = tokenMap[_deviceIdKey] as String? ?? '';
      if (storedDeviceId.isNotEmpty && storedDeviceId != currentDeviceId) {
        await _storage.delete(key: _tokenKey);
        return;
      }

      final info = LicenseInfo.fromJson(tokenMap);
      await _loadAndAdvanceTrustedClock(seedFrom: info.activatedAt);
      licenseInfo = info;
      if (licenseInfo != null) startHeartbeatTimer();
    } catch (_) {}
  }

  // ── Validate Key ──────────────────────────────────────────────────────────

  /// Last successful validate-API response, used to show plan preview UI.
  /// Plain field — no codegen needed.
  Map<String, dynamic>? _lastValidateData;
  Map<String, dynamic>? get validatedKeyPreview => _lastValidateData;

  @action
  Future<bool> validateKey(String key) async {
    isLoading = true;
    errorMessage = null;
    _lastValidateData = null;
    try {
      final data = await _api.validateKey(key);
      final valid = data['valid'] as bool? ?? false;
      final activatable = data['activatable'] as bool? ?? false;
      if (!valid) {
        errorMessage = 'Invalid license key. Please check and try again.';
        return false;
      }
      if (!activatable) {
        errorMessage =
            'This license has reached its device limit. Contact support.';
        return false;
      }
      _lastValidateData = data;
      return true;
    } on LicenseApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
    }
  }

  // ── Self-Signup (Email OTP) ───────────────────────────────────────────────

  @observable
  bool isRequestingOtp = false;

  @observable
  bool isVerifying = false;

  @observable
  String? signupError;

  /// Server-authoritative OTP expiry (UTC). The UI counts down against this.
  @observable
  DateTime? otpExpiresAt;

  /// Registers the business and triggers the OTP email. [signup] comes from
  /// SetupWizardStore.buildSignupBody(). Returns true on success.
  @action
  Future<bool> requestSignupOtp(Map<String, dynamic> signup) async {
    isRequestingOtp = true;
    signupError = null;
    try {
      final data = await _api.requestSignupOtp(signup);
      otpExpiresAt = DateTime.tryParse(data['expiresat'] as String? ?? '');
      return true;
    } on LicenseApiException catch (e) {
      signupError = e.message;
      return false;
    } finally {
      isRequestingOtp = false;
    }
  }

  /// Verifies the OTP. On success the server emails the license key, which the
  /// user enters manually on the next phase. Returns true on success.
  @action
  Future<bool> verifyOtp(String email, String otp) async {
    isVerifying = true;
    signupError = null;
    try {
      await _api.verifyOtp(email, otp);
      return true;
    } on LicenseApiException catch (e) {
      signupError = e.message;
      return false;
    } finally {
      isVerifying = false;
    }
  }

  /// Re-sends the OTP and refreshes [otpExpiresAt]. Returns true on success.
  @action
  Future<bool> resendOtp(String email) async {
    isRequestingOtp = true;
    signupError = null;
    try {
      final data = await _api.resendOtp(email);
      otpExpiresAt = DateTime.tryParse(data['expiresat'] as String? ?? '');
      return true;
    } on LicenseApiException catch (e) {
      signupError = e.message;
      return false;
    } finally {
      isRequestingOtp = false;
    }
  }

  // ── Activation ────────────────────────────────────────────────────────────

  @action
  Future<bool> activateLicense(
    String key, {
    String businessName = '',
    int businessCategory = 6,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final data = await _api.activate(
        key: key,
        businessName: businessName,
        businessCategory: businessCategory,
      );
      final devicePayload = await DevicePayloadService.build();
      final info = LicenseInfo.fromServerJson(data, devicePayload);
      if (!info.isValidLocally) {
        errorMessage = 'License is not active. Contact support.';
        return false;
      }
      // Server confirmed activation — reset trusted clock to server time so a
      // fresh/renewed key recovers even if the mark was previously advanced.
      await _resetTrustedClockFromServer(info);
      licenseInfo = info;
      final storedJson = {
        ...info.toJson(),
        _deviceIdKey: devicePayload['deviceid'],
      };
      await _saveToken(jsonEncode(storedJson));
      startHeartbeatTimer();
      return true;
    } on LicenseApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
    }
  }

  // ── Status Check ──────────────────────────────────────────────────────────

  @action
  Future<void> checkStatus() async {
    if (licenseInfo == null) return;
    isLoading = true;
    errorMessage = null;
    try {
      final data = await _api.checkStatus(licenseInfo!.licenseKey);
      final valid = data['valid'] as bool? ?? true;
      final reason = data['reason'] as String?;

      if (valid) {
        await _applyServerData(data);
      } else if (reason == 'EXPIRED') {
        await _applyServerData(data);
      } else {
        // DEVICE_MISMATCH, SUSPENDED, or unknown reason — hard lock
        await _lockLicense();
      }
    } on LicenseApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
    }
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  @action
  Future<void> heartbeat() async {
    if (licenseInfo == null) return;
    try {
      final accepted = await _api.heartbeat(licenseInfo!.licenseKey);
      if (!accepted) await _lockLicense();
    } catch (_) {
      // Network error — offline grace, keep license active
    }
  }

  void startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      kDebugMode ? const Duration(seconds: 30) : const Duration(hours: 6),
      (_) => heartbeat(),
    );
  }

  void stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @action
  Future<void> refreshLicense() async => checkStatus();

  // ── Pending Key (collected at startup, activated after setup) ────────────

  Future<String?> getPendingKey() =>
      _storage.read(key: _pendingKeyStorageKey);

  Future<void> savePendingKey(String key) =>
      _storage.write(key: _pendingKeyStorageKey, value: key);

  Future<void> clearPendingKey() =>
      _storage.delete(key: _pendingKeyStorageKey);

  /// Activates using the key saved by [savePendingKey]. Returns true on success.
  /// Clears the pending key once activated.
  @action
  Future<bool> activateWithPendingKey({required String businessName}) async {
    final key = await getPendingKey();
    if (key == null || key.trim().isEmpty) return false;
    final success = await activateLicense(key.trim(), businessName: businessName);
    if (success) await clearPendingKey();
    return success;
  }

  /// Fires a background server status check without blocking the caller.
  /// Safe to call at app startup — network errors are silently ignored.
  void checkStatusInBackground() {
    if (licenseInfo == null) return;
    checkStatus();
  }

  // ── Deactivation ──────────────────────────────────────────────────────────

  @action
  Future<void> deactivateLicense() async {
    if (licenseInfo != null) {
      try {
        await _api.deactivate(licenseInfo!.licenseKey);
      } catch (_) {
        // Always clear locally even if server call fails
      }
    }
    stopHeartbeatTimer();
    await _storage.delete(key: _tokenKey);
    licenseInfo = null;
    errorMessage = null;
  }

  // ── Dev/Testing only ──────────────────────────────────────────────────────

  @action
  Future<void> injectMockLicense({int validityDays = 30}) async {
    if (!kDebugMode) return;
    await DevTokenHelper.init();
    final devicePayload = await DevicePayloadService.build();
    final deviceHash =
        LicenseValidationService.computeDeviceHash(devicePayload);
    final rawToken = await DevTokenHelper.createSignedToken(
      licenseKey: 'TEST-MOCK-KEY-0001',
      devicePayload: devicePayload,
      deviceHash: deviceHash,
      validityDays: validityDays,
    );
    licenseInfo = LicenseValidationService.validate(
      rawToken: rawToken,
      currentDevice: devicePayload,
    );
    await _saveToken(rawToken);
  }

  @action
  Future<void> injectExpiredLicense() async {
    if (!kDebugMode) return;
    await DevTokenHelper.init();
    final devicePayload = await DevicePayloadService.build();
    final deviceHash =
        LicenseValidationService.computeDeviceHash(devicePayload);
    final past = DateTime.now().subtract(const Duration(days: 31));
    final rawToken = await DevTokenHelper.createSignedToken(
      licenseKey: 'TEST-EXPIRED-0001',
      devicePayload: devicePayload,
      deviceHash: deviceHash,
      validityDays: 30,
      customActivatedAt: past,
      customExpiryDate: past.add(const Duration(days: 30)),
    );
    licenseInfo = LicenseValidationService.validate(
      rawToken: rawToken,
      currentDevice: devicePayload,
    );
    await _saveToken(rawToken);
  }
}
