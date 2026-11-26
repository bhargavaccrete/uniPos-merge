import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

/// A verified copy of an original box file.
class PreservedFile {
  final String path;
  final String manifestPath;
  final int size;
  final String sha256;
  const PreservedFile(this.path, this.manifestPath, this.size, this.sha256);
}

class PreservationException implements Exception {
  final String message;
  PreservationException(this.message);
  @override
  String toString() => 'PreservationException: $message';
}

/// Copies an original Hive file aside BEFORE anything may repair or change
/// it. A copy counts only after it is read back and matches the original's
/// size and SHA-256. Never overwrites and never deletes a preserved copy.
///
/// Layout: `<hive dir>/damaged/<timestamp>/<file>` plus
/// `<file>.manifest.json`, one timestamp folder per app start.
class HivePreservation {
  HivePreservation._();

  static const String folderName = 'damaged';

  /// Test hook: runs after the temporary copy is written and flushed, before
  /// it is verified. A test may change the copy (verification must then fail)
  /// or throw (a failed copy).
  @visibleForTesting
  static Future<void> Function(File temporaryCopy)? afterCopyWriteForTesting;

  /// Test hook for the clock used in folder names and the manifest.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static Directory? _sessionFolder;
  static final Map<String, PreservedFile> _preservedThisRun = {};

  /// Forgets this run's folder, so the next preservation starts a new one.
  @visibleForTesting
  static void resetForTesting() {
    _sessionFolder = null;
    _preservedThisRun.clear();
    afterCopyWriteForTesting = null;
    now = DateTime.now;
  }

  /// Copies [source] into this run's preservation folder and writes its
  /// manifest. Throws [PreservationException] unless a verified copy exists.
  static Future<PreservedFile> preserve({
    required File source,
    required String hiveDirectory,
    required String boxName,
    required String reason,
    Map<String, Object?> details = const {},
    String? error,
  }) async {
    try {
      final original = await source.readAsBytes();
      final originalHash = sha256.convert(original).toString();
      // Retry re-opens a still-damaged box: the identical bytes already have a
      // verified copy in this run, so it is reused instead of copied again.
      final earlier = _preservedThisRun[source.path];
      if (earlier != null &&
          earlier.sha256 == originalHash &&
          File(earlier.path).existsSync()) {
        return earlier;
      }

      final folder = await sessionFolder(hiveDirectory);
      final target = unusedFile(folder, p.basename(source.path));
      final temporary = unusedFile(folder, '${p.basename(target.path)}.copying');

      final raf = await temporary.open(mode: FileMode.writeOnly);
      try {
        await raf.writeFrom(original);
        await raf.flush();
      } finally {
        await raf.close();
      }
      await afterCopyWriteForTesting?.call(temporary);

      final copy = await temporary.readAsBytes();
      if (copy.length != original.length ||
          sha256.convert(copy).toString() != originalHash) {
        throw PreservationException(
            'the copy of ${p.basename(source.path)} did not match the original '
            '(size or SHA-256)');
      }
      // The original must not have changed while it was copied.
      final again = await source.readAsBytes();
      if (again.length != original.length ||
          sha256.convert(again).toString() != originalHash) {
        throw PreservationException(
            '${p.basename(source.path)} changed while it was being copied');
      }
      if (target.existsSync()) {
        throw PreservationException('${target.path} appeared during the copy');
      }
      await temporary.rename(target.path);

      final manifest = unusedFile(folder, '${p.basename(target.path)}.manifest.json');
      final appVersion = await _appVersion();
      await _writeVerified(
        manifest,
        utf8.encode(const JsonEncoder.withIndent('  ').convert({
          'box': boxName,
          'reason': reason,
          'error': ?error,
          'originalPath': source.path,
          'preservedPath': target.path,
          'originalSize': original.length,
          'sha256': originalHash,
          'damageKind': details['damageKind'],
          'corruptionOffset': details['damageOffset'],
          'validRecordsBefore': details['validRecordsBefore'],
          'validRecordsAfter': details['validRecordsAfter'],
          'scanComplete': details['scanComplete'],
          'appVersion': appVersion,
          'platform': Platform.operatingSystem,
          'preservedAt': now().toIso8601String(),
        })),
      );
      debugPrint('🛟 Preserved $boxName → ${target.path}');
      return _preservedThisRun[source.path] =
          PreservedFile(target.path, manifest.path, original.length, originalHash);
    } on PreservationException {
      rethrow;
    } catch (e) {
      throw PreservationException('could not copy ${source.path}: $e');
    }
  }

  /// This app start's preservation folder, created on first use.
  static Future<Directory> sessionFolder(String hiveDirectory) async {
    final existing = _sessionFolder;
    if (existing != null && existing.existsSync()) return existing;
    final t = now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}-'
        '${t.millisecond.toString().padLeft(3, '0')}';
    final root = p.join(hiveDirectory, folderName);
    var dir = Directory(p.join(root, stamp));
    for (var i = 1; dir.existsSync(); i++) {
      dir = Directory(p.join(root, '$stamp-$i'));
    }
    await dir.create(recursive: true);
    return _sessionFolder = dir;
  }

  /// [name] in [folder], or `name-1`, `name-2`… when taken. Never an existing
  /// file, so nothing already preserved is ever overwritten.
  static File unusedFile(Directory folder, String name) {
    var file = File(p.join(folder.path, name));
    if (!file.existsSync()) return file;
    final dot = name.indexOf('.');
    final stem = dot < 0 ? name : name.substring(0, dot);
    final ext = dot < 0 ? '' : name.substring(dot);
    for (var i = 1;; i++) {
      file = File(p.join(folder.path, '$stem-$i$ext'));
      if (!file.existsSync()) return file;
    }
  }

  static Future<void> _writeVerified(File target, List<int> bytes) async {
    final temporary = unusedFile(target.parent, '${p.basename(target.path)}.copying');
    final raf = await temporary.open(mode: FileMode.writeOnly);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    final back = await temporary.readAsBytes();
    if (!listEquals(back, Uint8List.fromList(bytes))) {
      throw PreservationException('the manifest could not be written');
    }
    await temporary.rename(target.path);
  }

  static Future<String> _appVersion() async {
    try {
      return await appVersionLookup().timeout(const Duration(seconds: 2));
    } catch (_) {
      return 'unknown';
    }
  }

  /// Overridable so tests (no platform channel) get a fixed version.
  @visibleForTesting
  static Future<String> Function() appVersionLookup = _platformVersion;

  static Future<String> _platformVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }
}
