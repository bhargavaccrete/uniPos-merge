import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceIdSource {
  /// Android androidId — survives reinstall (Android 8+), NOT factory reset
  androidId,
  /// iOS identifierForVendor — survives reinstall, resets only if ALL vendor apps removed
  iosVendorId,
  /// BIOS/UEFI UUID from motherboard firmware — survives EVERYTHING incl. factory reset
  biosUuid,
  /// Windows registry Machine GUID — survives reinstall, NOT factory reset
  machineGuid,
  /// Random UUID saved in SharedPreferences — survives restart only
  fallback,
}

class DeviceIdResult {
  final String id;
  final DeviceIdSource source;

  const DeviceIdResult(this.id, this.source);

  bool get survivesRestart     => true; // all sources survive restart
  bool get survivesReinstall   => source != DeviceIdSource.fallback;
  bool get survivesFactoryReset => source == DeviceIdSource.biosUuid;

  String get sourceLabel {
    switch (source) {
      case DeviceIdSource.androidId:   return 'Android Device ID';
      case DeviceIdSource.iosVendorId: return 'iOS Vendor Identifier';
      case DeviceIdSource.biosUuid:    return 'BIOS/UEFI Firmware UUID';
      case DeviceIdSource.machineGuid: return 'Windows Machine GUID';
      case DeviceIdSource.fallback:    return 'Generated (SharedPreferences)';
    }
  }

  String get storageLabel {
    switch (source) {
      case DeviceIdSource.androidId:   return 'Android OS (system partition)';
      case DeviceIdSource.iosVendorId: return 'iOS OS (system, per vendor)';
      case DeviceIdSource.biosUuid:    return 'Motherboard Firmware (BIOS/UEFI)';
      case DeviceIdSource.machineGuid: return 'Windows Registry';
      case DeviceIdSource.fallback:    return 'App SharedPreferences';
    }
  }
}

/// Generates and caches a stable device identifier.
///
/// ID format: `UNI-XXXXXXXXXXXXXXXX` (16 uppercase hex chars)
class DeviceIdService {
  DeviceIdService._();

  static const _prefKey       = 'unipos_device_id';
  static const _prefSourceKey = 'unipos_device_id_source';

  static DeviceIdResult? _cached;

  /// Returns the full [DeviceIdResult] with id + survival metadata.
  static Future<DeviceIdResult> getResult() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final storedId     = prefs.getString(_prefKey);
    final storedSource = prefs.getString(_prefSourceKey);

    if (storedId != null && storedId.isNotEmpty && storedSource != null) {
      final source = DeviceIdSource.values.firstWhere(
        (s) => s.name == storedSource,
        orElse: () => DeviceIdSource.fallback,
      );
      _cached = DeviceIdResult(storedId, source);
      return _cached!;
    }

    final result = await _generate();
    await prefs.setString(_prefKey, result.id);
    await prefs.setString(_prefSourceKey, result.source.name);
    _cached = result;
    return result;
  }

  /// Convenience — returns just the ID string.
  static Future<String> getDeviceId() async => (await getResult()).id;

  /// Synchronous cached ID (null if not yet loaded).
  static String? get cachedId => _cached?.id;

  /// Pre-loads into cache — call once at app start.
  static Future<void> init() async => await getResult();

  // ── Generators ──────────────────────────────────────────────────────────────

  static Future<DeviceIdResult> _generate() async {
    try {
      if (!kIsWeb && Platform.isAndroid) return await _fromAndroid();
      if (!kIsWeb && Platform.isIOS)     return await _fromIos();
      if (!kIsWeb && Platform.isWindows) return await _fromWindows();
    } catch (_) {}
    return _fallback();
  }

  static Future<DeviceIdResult> _fromAndroid() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return DeviceIdResult(_format(info.id), DeviceIdSource.androidId);
  }

  /// iOS: identifierForVendor (IDFV) — assigned by Apple per device per vendor.
  /// No permission required. Survives reinstall as long as at least one app
  /// from the same developer remains installed on the device.
  static Future<DeviceIdResult> _fromIos() async {
    final info = await DeviceInfoPlugin().iosInfo;
    final idfv = info.identifierForVendor;
    if (idfv != null && idfv.isNotEmpty) {
      return DeviceIdResult(_format(idfv), DeviceIdSource.iosVendorId);
    }
    return _fallback();
  }

  static Future<DeviceIdResult> _fromWindows() async {
    // 1. BIOS UUID — stored in motherboard firmware, survives factory reset
    try {
      final result = await Process.run(
        'wmic', ['csproduct', 'get', 'uuid', '/value'],
        runInShell: true,
      );
      final output = (result.stdout as String).toUpperCase();
      final match  = RegExp(r'UUID=([A-F0-9\-]{36})').firstMatch(output);
      if (match != null) {
        final uuid = match.group(1)!;
        const invalid = {
          'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF',
          '00000000-0000-0000-0000-000000000000',
        };
        if (!invalid.contains(uuid)) {
          return DeviceIdResult(
            _format(uuid.replaceAll('-', '')),
            DeviceIdSource.biosUuid,
          );
        }
      }
    } catch (_) {}

    // 2. Machine GUID from registry — survives reinstall, not factory reset
    try {
      final result = await Process.run(
        'reg', ['query', r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography', '/v', 'MachineGuid'],
        runInShell: true,
      );
      final match = RegExp(r'MachineGuid\s+REG_SZ\s+([\w\-]+)', caseSensitive: false)
          .firstMatch(result.stdout as String);
      if (match != null) {
        return DeviceIdResult(
          _format(match.group(1)!.replaceAll('-', '')),
          DeviceIdSource.machineGuid,
        );
      }
    } catch (_) {}

    return _fallback();
  }

  static DeviceIdResult _fallback() {
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    return DeviceIdResult(_format(seed), DeviceIdSource.fallback);
  }

  static String _format(String raw) {
    final hash = sha256.convert(utf8.encode(raw.trim())).toString().toUpperCase();
    return 'UNI-${hash.substring(0, 16)}';
  }
}
