/// Shared networking config for all API services (license, signup, …).
///
/// Only environment-level values live here — the host and the device auth key
/// that every endpoint shares. Per-feature route paths stay inside their own
/// service file so this never becomes a dumping ground.
class ApiConstants {
  static const String baseUrl = 'http://192.168.120.47:8002';

  static const String deviceKey =
      '66e6c682046bd7998b86bc27ed26963ad260e04b8fd62f76d48b9e718ffdee65';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'X-Device-Key': deviceKey,
  };

  // ── License ────────────────────────────────────────────────────────────────
  static const String licenseValidatePath = '/api/v1/mobile/license/validate';
  static const String licenseActivatePath = '/api/v1/mobile/license/activate';
  static const String licenseStatusPath = '/api/v1/mobile/license/status';
  static const String licenseHeartbeatPath = '/api/v1/mobile/license/heartbeat';
  static const String licenseDeactivatePath = '/api/v1/mobile/license/deactivate';
  static const String licenseRequestOtp = '/api/v1/signup/request-otp';
  static const String licenseVerifyOtp = '/api/v1/signup/verify-otp';
  static const String licenseResendOtp = '/api/v1/signup/resend-otp';
}
