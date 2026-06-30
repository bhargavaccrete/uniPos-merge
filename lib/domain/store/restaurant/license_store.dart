import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobx/mobx.dart';
import '../../../core/plan/entitlements.dart';
import '../../../core/plan/entitlement_debug.dart';
import '../../../core/routes/routes_name.dart';
import '../../../data/models/restaurant/license_model.dart';
import '../../../domain/services/common/device_payload_service.dart';
import '../../../domain/services/common/dev_token_helper.dart';
import '../../../domain/services/common/license_api_service.dart';
import '../../../domain/services/common/license_validation_service.dart';
import '../../../domain/services/common/manifest_service.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../../core/di/service_locator.dart';

part 'license_store.g.dart';

class LicenseStore extends _LicenseStore with _$LicenseStore {
  LicenseStore(super.api);

  static void navigateToNextScreen(BuildContext context) {
    _LicenseStore.navigateToNextScreen(context);
  }
}

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
  // Server-driven entitlements manifest (signed) cache — separate from the RSA
  // license token. Drives PlanGate/Entitlements; refreshed by sync.
  static const _manifestRawKey = 'unipos_manifest_raw';
  static const _manifestSigKey = 'unipos_manifest_sig';
  static const _entVersionKey = 'unipos_entitlement_version';
  static const _lastSyncKey = 'unipos_last_sync_at';
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

  /// Strict-whitelist guard: the verified entitlements manifest is the single
  /// source of truth. Bypass (web/testing) is exempt; otherwise a licensed
  /// device with no verified manifest (never activated with one, or its cache
  /// failed verification) must reactivate before using licensed features.
  /// Reactive inside an Observer — reads the entitlements ObservableMap.
  bool get hasVerifiedManifest =>
      licenseBypassed || Entitlements.instance.hasManifest;

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

  @action
  Future<void> clearAllLicenseState() async {
    stopHeartbeatTimer();
    await _storage.delete(key: _tokenKey);
    licenseInfo = null;
    await _clearManifestCache();
    Entitlements.instance.clear();
  }

  // ── Entitlements Manifest (signed) ─────────────────────────────────────────

  Future<void> _saveManifest(String raw, String sig, int version) async {
    await _storage.write(key: _manifestRawKey, value: raw);
    await _storage.write(key: _manifestSigKey, value: sig);
    await _storage.write(key: _entVersionKey, value: '$version');
  }

  Future<void> _clearManifestCache() async {
    await _storage.delete(key: _manifestRawKey);
    await _storage.delete(key: _manifestSigKey);
    await _storage.delete(key: _entVersionKey);
  }

  Future<int> _cachedEntVersion() async {
    final v = await _storage.read(key: _entVersionKey);
    return int.tryParse(v ?? '') ?? 0;
  }

  Future<DateTime?> lastSyncAt() async {
    final v = await _storage.read(key: _lastSyncKey);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> _touchLastSync() async {
    await _storage.write(
        key: _lastSyncKey, value: DateTime.now().toIso8601String());
  }

  /// Verifies a manifest+signature carried in a server [data] block, loads it
  /// into [Entitlements], and caches it. No-op if the block lacks a manifest or
  /// the signature/identity checks fail (keeps the prior cached entitlements).
  Future<void> _ingestManifest(
      Map<String, dynamic> data, String deviceId, String licenseKey) async {
    final raw = data['manifest'] as String?;
    final sig = data['signature'] as String?;
    if (raw == null || sig == null) return;
    final parsed = await ManifestService.verifyAndParse(
      manifestRaw: raw,
      sigB64: sig,
      deviceId: deviceId,
      licenseKey: licenseKey,
    );
    if (parsed == null) {
      await clearAllLicenseState();
      return;
    }
    Entitlements.instance.loadFromManifest(parsed);
    await _saveManifest(raw, sig, parsed.version);
  }

  /// Loads the cached manifest into [Entitlements] for offline-first enforcement.
  Future<void> _loadCachedManifest(String deviceId, String licenseKey) async {
    try {
      final raw = await _storage.read(key: _manifestRawKey);
      final sig = await _storage.read(key: _manifestSigKey);
      if (raw == null || sig == null) return;
      final parsed = await ManifestService.verifyAndParse(
        manifestRaw: raw,
        sigB64: sig,
        deviceId: deviceId,
        licenseKey: licenseKey,
      );
      if (parsed != null) {
        Entitlements.instance.loadFromManifest(parsed);
      } else {
        // Cached manifest failed verification (tampered / wrong device / wrong
        // key) — wipe all licensing state.
        await clearAllLicenseState();
      }
    } catch (_) {}
  }

  /// Startup: hydrate entitlements from cache (offline-safe), then kick a
  /// background sync to pick up plan changes / revocation when online.
  Future<void> _hydrateAndSyncManifest() async {
    final info = licenseInfo;
    if (info == null) return;
    final devicePayload = await DevicePayloadService.build();
    final deviceId = devicePayload['deviceid'] as String? ?? '';
    await _loadCachedManifest(deviceId, info.licenseKey);
    syncEntitlements(); // fire-and-forget
  }

  /// Sync entitlements with the server: detects plan changes and revocation
  /// without an app release. Offline → keeps the cached manifest silently.
  @action
  Future<void> syncEntitlements() async {
    final info = licenseInfo;
    if (info == null) return;
    final devicePayload = await DevicePayloadService.build();
    final deviceId = devicePayload['deviceid'] as String? ?? '';
    try {
      final data = await _api.sync(
        licenseKey: info.licenseKey,
        deviceId: deviceId,
        entitlementVersion: await _cachedEntVersion(),
      );
      final valid = data['valid'] as bool? ?? true;
      if (!valid) {
        // REVOKED / CANCELLED / DEVICE_MISMATCH / EXPIRED — hard lock.
        await clearAllLicenseState();
        return;
      }
      await _touchLastSync();
      final changed = data['entitlementChanged'] as bool? ?? false;
      if (changed) {
        await _ingestManifest(data, deviceId, info.licenseKey);
        EntitlementDebug.dump('SYNC', data); // debug-only — only when changed
      }
    } catch (_) {
      // Offline — keep cache, enforce expiry + grace locally.
    }
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
        await _hydrateAndSyncManifest();
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
      await _hydrateAndSyncManifest();
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
      // Verify + cache the entitlements manifest carried in the same response.
      await _ingestManifest(
          data, devicePayload['deviceid'] as String? ?? '', info.licenseKey);
      EntitlementDebug.dump('ACTIVATE', data); // debug-only diagnostics
      await _touchLastSync();
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
        await clearAllLicenseState();
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
      if (!accepted) await clearAllLicenseState();
    } catch (_) {
      // Network error — offline grace, keep license active
    }
  }

  void startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      kDebugMode ? const Duration(seconds: 30) : const Duration(hours: 6),
      (_) async {
        await heartbeat();
        await syncEntitlements();
      },
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
    await clearAllLicenseState();
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

  /// Route decision helper for restaurant entry points (Splash, Login, Setup Wizard).
  /// Navigates to License Key Entry, License Lock, or Dashboard based on state.
  static void navigateToNextScreen(BuildContext context) {
    final licStore = locator<LicenseStore>();

    // 1. If not licensed (and not bypassed)
    if (!licStore.isLicensed) {
      if (licStore.licenseInfo == null) {
        // No license at all -> License Activation (Key Entry)
        Navigator.pushReplacementNamed(context, RouteNames.licenseKeyEntry);
      } else {
        // Expired or invalid -> License Locked
        Navigator.pushReplacementNamed(context, RouteNames.licenseLock);
      }
      return;
    }

    // 2. Must have a verified manifest to proceed (unless bypassed)
    if (!licStore.hasVerifiedManifest) {
      Navigator.pushReplacementNamed(context, RouteNames.licenseLock);
      return;
    }

    // 3. Fully valid and verified -> Proceed to POS Home or Login based on login state
    final isLoggedIn = RestaurantSession.isLoggedIn;
    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, RouteNames.restaurantHome);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.restaurantLogin);
    }
  }
}
