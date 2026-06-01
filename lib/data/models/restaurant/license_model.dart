class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String deviceModel;
  final int deviceOs;
  final String osVersion;
  final String appVersion;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceModel,
    required this.deviceOs,
    required this.osVersion,
    required this.appVersion,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        deviceId: json['deviceid'] as String? ?? '',
        deviceName: json['devicename'] as String? ?? '',
        deviceModel: json['devicemodel'] as String? ?? '',
        deviceOs: json['deviceos'] as int? ?? 0,
        osVersion: json['osversion'] as String? ?? '',
        appVersion: json['appversion'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'deviceid': deviceId,
        'devicename': deviceName,
        'devicemodel': deviceModel,
        'deviceos': deviceOs,
        'osversion': osVersion,
        'appversion': appVersion,
      };

  String get osName {
    switch (deviceOs) {
      case 1:
        return 'Android';
      case 2:
        return 'iOS';
      case 3:
        return 'Windows';
      default:
        return 'Unknown';
    }
  }
}

enum LicenseStatus { active, expired, notActivated, suspended }

extension LicenseStatusX on LicenseStatus {
  String get label {
    switch (this) {
      case LicenseStatus.active:
        return 'Active';
      case LicenseStatus.expired:
        return 'Expired';
      case LicenseStatus.suspended:
        return 'Suspended';
      case LicenseStatus.notActivated:
        return 'Not Activated';
    }
  }

  static LicenseStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return LicenseStatus.active;
      case 'expired':
        return LicenseStatus.expired;
      case 'suspended':
        return LicenseStatus.suspended;
      default:
        return LicenseStatus.notActivated;
    }
  }

  // Server returns status as integer: 2=active, 3=expired, 4=suspended
  static LicenseStatus fromInt(int? value) {
    switch (value) {
      case 2:
        return LicenseStatus.active;
      case 3:
        return LicenseStatus.expired;
      case 4:
        return LicenseStatus.suspended;
      default:
        return LicenseStatus.notActivated;
    }
  }
}

class LicenseInfo {
  final String licenseKey;
  final LicenseStatus status;
  final String planName;
  final DateTime? expiryDate;
  final DateTime? activatedAt;
  final int validityDays;
  final DeviceInfo? deviceInfo;
  final bool isTrial;
  final String? activationId;

  const LicenseInfo({
    required this.licenseKey,
    required this.status,
    this.planName = '',
    this.expiryDate,
    this.activatedAt,
    this.validityDays = 0,
    this.deviceInfo,
    this.isTrial = false,
    this.activationId,
  });

  factory LicenseInfo.fromJson(Map<String, dynamic> json) => LicenseInfo(
        licenseKey: json['license_key'] as String? ?? '',
        status: LicenseStatusX.fromString(json['status'] as String?),
        planName: json['plan_name'] as String? ?? '',
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'] as String)
            : null,
        activatedAt: json['activated_at'] != null
            ? DateTime.tryParse(json['activated_at'] as String)
            : null,
        validityDays: json['validity_days'] as int? ?? 0,
        deviceInfo: json['device'] != null
            ? DeviceInfo.fromJson(json['device'] as Map<String, dynamic>)
            : null,
        isTrial: json['is_trial'] as bool? ?? false,
        activationId: json['activation_id'] as String?,
      );

  /// Parses the server's activation / status response data block.
  factory LicenseInfo.fromServerJson(
    Map<String, dynamic> data,
    Map<String, dynamic> devicePayload,
  ) =>
      LicenseInfo(
        licenseKey: data['licensekey'] as String? ?? '',
        status: LicenseStatusX.fromInt(data['status'] as int?),
        planName: data['planname'] as String? ?? '',
        expiryDate: data['expiresat'] != null
            ? DateTime.tryParse(data['expiresat'] as String)
            : null,
        activatedAt: data['activatedat'] != null
            ? DateTime.tryParse(data['activatedat'] as String)
            : null,
        validityDays: data['daysRemaining'] as int? ?? 0,
        deviceInfo: DeviceInfo.fromJson(devicePayload),
        isTrial: data['islicensetrial'] as bool? ?? false,
        activationId:
            (data['activation'] as Map<String, dynamic>?)?['activationid']
                as String?,
      );

  Map<String, dynamic> toJson() => {
        'license_key': licenseKey,
        'status': status.name,
        'plan_name': planName,
        'expiry_date': expiryDate?.toIso8601String(),
        'activated_at': activatedAt?.toIso8601String(),
        'validity_days': validityDays,
        'device': deviceInfo?.toJson(),
        'is_trial': isTrial,
        'activation_id': activationId,
      };

  bool get isExpiredLocally {
    if (status == LicenseStatus.notActivated) return true;
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isValidLocally =>
      status == LicenseStatus.active && !isExpiredLocally;

  /// Returns 9999 for perpetual licenses (null expiry).
  int get daysRemaining {
    if (expiryDate == null) return 9999;
    final diff = expiryDate!.difference(DateTime.now());
    return diff.inDays.clamp(0, validityDays > 0 ? validityDays : 9999);
  }

  String get maskedKey {
    if (licenseKey.length <= 8) return licenseKey;
    final segments = licenseKey.split('-');
    if (segments.length >= 4) {
      return '${segments[0]}-••••-••••-${segments.last}';
    }
    return '${licenseKey.substring(0, 4)}••••${licenseKey.substring(licenseKey.length - 4)}';
  }

  bool get isActive => status == LicenseStatus.active;
}
