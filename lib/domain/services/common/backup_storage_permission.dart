import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Storage permission for backups written to the public Download folder.
///
/// Android 11+ (API 30+) lets the app create its own files there without any
/// permission, so nothing is asked. Android 7–10 (API 24–29) need
/// WRITE_EXTERNAL_STORAGE (declared with maxSdkVersion 29); without it every
/// automatic backup fails.
class BackupStoragePermission {
  BackupStoragePermission._();

  /// Shown when an automatic backup cannot run for lack of the permission.
  static const String deniedMessage =
      'Storage permission is off, so the backup could not be saved to '
      'Downloads. Turn on the backup setting again or make a manual backup '
      'and allow storage access.';

  @visibleForTesting
  static bool? isAndroidOverride;
  @visibleForTesting
  static Future<int> Function()? sdkIntOverride;
  @visibleForTesting
  static Future<bool> Function()? isGrantedOverride;
  @visibleForTesting
  static Future<bool> Function()? requestOverride;

  @visibleForTesting
  static void resetForTesting() {
    isAndroidOverride = null;
    sdkIntOverride = null;
    isGrantedOverride = null;
    requestOverride = null;
  }

  static bool get _isAndroid =>
      isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

  static Future<int> _sdkInt() async => sdkIntOverride != null
      ? sdkIntOverride!()
      : (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  /// True when this device needs the runtime permission (Android 10 or older).
  static Future<bool> isRequired() async {
    if (!_isAndroid) return false;
    try {
      return await _sdkInt() <= 29;
    } catch (_) {
      return false;
    }
  }

  /// Without asking: may a backup be written to Downloads now? Used by the
  /// automatic backup, which runs on a timer and cannot show a prompt.
  static Future<bool> isGranted() async {
    if (!await isRequired()) return true;
    try {
      return isGrantedOverride != null
          ? await isGrantedOverride!()
          : await Permission.storage.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Asks for the permission if this device needs it and it is not granted.
  /// Call only while the user is on a screen (toggle, backup button).
  static Future<bool> ensure() async {
    if (await isGranted()) return true;
    try {
      return requestOverride != null
          ? await requestOverride!()
          : (await Permission.storage.request()).isGranted;
    } catch (_) {
      return false;
    }
  }
}
