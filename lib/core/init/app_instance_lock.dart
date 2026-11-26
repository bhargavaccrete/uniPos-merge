import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AppAlreadyRunningException implements Exception {
  @override
  String toString() =>
      'Bill Berry Lite is already running on this computer.\n\n'
      'Only one copy can use the business data at a time. Close the other '
      'Bill Berry Lite window and start the app again. Nothing was changed.';
}

/// One running copy of the app per data folder (desktop).
///
/// Hive locks each box only while it opens it, and a failed lock closes the
/// half-opened box, which deletes the other copy's `.lock` file. A second
/// copy of the app could then write to the same files. This exclusive OS
/// lock is taken before any box is touched and held for the whole process.
///
/// The OS releases the lock when the process ends, crash included, so a
/// lock FILE left behind by a closed or crashed copy never blocks a start.
class AppInstanceLock {
  AppInstanceLock._();

  static const String fileName = 'billberrylite.instance.lock';

  static RandomAccessFile? _held;

  static bool get isHeld => _held != null;

  /// Whether this platform needs the lock (desktop: several app copies can
  /// run at once). Android runs one app process; web has no files.
  static bool get appliesToThisPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Throws [AppAlreadyRunningException] when another copy holds the lock.
  static Future<void> acquire(String directory) async {
    if (_held != null) return;
    await Directory(directory).create(recursive: true);
    final raf = await File(p.join(directory, fileName))
        .open(mode: FileMode.append);
    try {
      await raf.lock(FileLock.exclusive);
    } on FileSystemException {
      await raf.close();
      throw AppAlreadyRunningException();
    }
    _held = raf;
  }

  @visibleForTesting
  static Future<void> releaseForTesting() async {
    final raf = _held;
    _held = null;
    if (raf != null) {
      await raf.unlock();
      await raf.close();
    }
  }
}
