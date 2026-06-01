import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'device_id_service.dart';

/// Builds the device{} block sent to the licensing API on every activation.
/// Uses [device_info_plus] for model/OS data and [package_info_plus] for the real app version.
class DevicePayloadService {

  static Future<Map<String, dynamic>> build() async {
    final deviceId = await DeviceIdService.getDeviceId();
    final appVersion = await _getAppVersion();

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return {
          'deviceid': deviceId,
          'devicename': info.model,
          'devicemodel': '${info.brand} ${info.model}',
          'deviceos': 1,
          'osversion': info.version.release,
          'appversion': appVersion,
        };
      }

      if (!kIsWeb && Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return {
          'deviceid': deviceId,
          'devicename': info.name,
          'devicemodel': info.model,
          'deviceos': 2,
          'osversion': info.systemVersion,
          'appversion': appVersion,
        };
      }

      if (!kIsWeb && Platform.isWindows) {
        final info = await DeviceInfoPlugin().windowsInfo;
        return {
          'deviceid': deviceId,
          'devicename': info.computerName,
          'devicemodel': 'Windows PC',
          'deviceos': 3,
          'osversion': '${info.majorVersion}.${info.minorVersion}',
          'appversion': appVersion,
        };
      }
    } catch (_) {}

    // Fallback for unsupported or web platforms
    return {
      'deviceid': deviceId,
      'devicename': kIsWeb ? 'Web Browser' : Platform.localHostname,
      'devicemodel': kIsWeb ? 'Web' : Platform.operatingSystem,
      'deviceos': 0,
      'osversion': kIsWeb ? '' : Platform.operatingSystemVersion,
      'appversion': appVersion,
    };
  }

  static Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }
}