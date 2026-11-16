import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import 'hive_file_inspector.dart';
import 'hive_preservation.dart';
import 'restore_record.dart';

/// Why a box was left closed.
enum HiveBoxFailureKind {
  /// Checksum damage Hive's crash recovery would have cut away. Not repaired.
  corrupted,

  /// Records with a valid checksum that cannot be decoded (unknown typeId,
  /// adapter error). Not changed.
  unreadable,

  /// Lock, permission or other I/O error. Not damage; nothing was changed.
  inaccessible,

  /// Damaged or unreadable, and no verified copy could be made, so the
  /// original was not repaired either.
  preservationFailed,
}

class HiveBoxFailure {
  final String boxName;
  final HiveBoxFailureKind kind;
  final String error;
  final HiveFileScan? scan;
  final PreservedFile? preserved;
  final String? preservationError;

  /// When the box failed to open.
  final DateTime detectedAt;

  HiveBoxFailure({
    required this.boxName,
    required this.kind,
    required this.error,
    this.scan,
    this.preserved,
    this.preservationError,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  String describe() {
    switch (kind) {
      case HiveBoxFailureKind.corrupted:
        return '• $boxName: damaged (${_damageText(scan)}). It was NOT repaired. '
            'The original file was left unchanged, and a verified copy was '
            'saved to:\n  ${preserved?.path}';
      case HiveBoxFailureKind.unreadable:
        final where = preserved == null
            ? 'It was left untouched in this device\'s storage.'
            : 'It was NOT changed, and a verified copy was saved to:\n  '
                '${preserved!.path}';
        return '• $boxName: could not be read. This can happen when the data '
            'was saved by a newer version of the app. $where';
      case HiveBoxFailureKind.inaccessible:
        return '• $boxName: could not be opened because the file is in use or '
            'not accessible. This is not damage, and nothing was changed. '
            'Close any other Bill Berry Lite window and start the app again.';
      case HiveBoxFailureKind.preservationFailed:
        return '• $boxName: damaged or unreadable, and a safe copy could NOT be '
            'made (${preservationError ?? 'unknown reason'}). The original file '
            'was left untouched and was NOT repaired.';
    }
  }

  static String _damageText(HiveFileScan? scan) {
    switch (scan?.kind) {
      case HiveDamageKind.middleCorruption:
        final n = scan!.validRecordsAfter;
        final more = scan.scanComplete ? '$n' : 'at least $n';
        return 'damage inside the file; an automatic repair would have '
            'dropped $more saved record(s) after it';
      case HiveDamageKind.badFinalRecord:
        return 'the last saved record is damaged';
      case HiveDamageKind.tornFinalRecord:
        return 'an unfinished last write that could not be repaired';
      case HiveDamageKind.none:
      case null:
        return 'checksum error';
    }
  }
}

/// A box opened after Hive dropped an unfinished last write. The original
/// file was preserved first.
class HiveRepairNotice {
  final String boxName;
  final PreservedFile preserved;
  final HiveFileScan scan;
  final int sizeAfter;
  const HiveRepairNotice(this.boxName, this.preserved, this.scan, this.sizeAfter);
}

/// Thrown when any required box could not be opened safely. Normal startup
/// must stop: no repositories, services or server with missing boxes.
class HiveStartupBlocked implements Exception {
  final List<HiveBoxFailure> failures;

  /// BKP-5: a restore that did not finish (its record is still open). The
  /// business data may be partly replaced.
  final RestoreRecord? interruptedRestore;

  HiveStartupBlocked(this.failures, {this.interruptedRestore});

  String get message {
    final onlyAccess = interruptedRestore == null &&
        failures.every((f) => f.kind == HiveBoxFailureKind.inaccessible);
    final b = StringBuffer(
        'Bill Berry Lite stopped before opening the till because some saved '
        'business data could not be opened safely. Nothing was deleted or '
        'repaired.\n\n');
    if (interruptedRestore != null) {
      b.writeln('• A restore did not finish. Business data may be partly '
          'replaced.');
    }
    for (final f in failures) {
      b.writeln(f.describe());
    }
    if (!onlyAccess) {
      b.write('\nDo not uninstall the app or clear its data: that would delete '
          'the original files and their copies. Contact support.');
    }
    return b.toString().trim();
  }

  @override
  String toString() => message;
}

/// Opens startup boxes without letting Hive destroy recoverable data.
///
/// 1. A compaction leftover (`.hivec`) is preserved before Hive may delete it.
/// 2. Every box opens with `crashRecovery: false`: Hive checks every record's
///    checksum and throws on damage WITHOUT writing to the file.
/// 3. On a checksum error the original is preserved (verified copy) and
///    scanned. Only a confirmed unfinished last write is then opened with
///    Hive's crash recovery; any other damage leaves the box closed.
/// 4. On a decode error the original is preserved and the box stays closed.
/// 5. Lock / permission / I/O errors are retried, never treated as damage.
class HiveSafeOpen {
  HiveSafeOpen._();

  /// Folder holding the `.hive` files; set by `HiveInit.init`. Null on web
  /// and when unknown (then nothing can be preserved, so nothing is repaired).
  static String? hiveDirectory;

  /// Boxes left closed in this run.
  static final List<HiveBoxFailure> failures = [];

  /// Boxes opened after an unfinished last write was dropped.
  static final List<HiveRepairNotice> repairs = [];

  @visibleForTesting
  static int accessAttempts = 3;
  @visibleForTesting
  static Duration accessRetryDelay = const Duration(milliseconds: 200);
  @visibleForTesting
  static Duration lockReleaseTimeout = const Duration(seconds: 2);

  @visibleForTesting
  static void resetForTesting() {
    failures.clear();
    repairs.clear();
    accessAttempts = 3;
    accessRetryDelay = const Duration(milliseconds: 200);
    lockReleaseTimeout = const Duration(seconds: 2);
  }

  /// Stops startup if any box was left closed.
  static void throwIfBlocked() {
    if (failures.isNotEmpty) {
      throw HiveStartupBlocked(List.of(failures),
          interruptedRestore: pendingRestore());
    }
  }

  /// BKP-5: the open restore record in the data folder, or null (also on
  /// web, where restores keep their earlier behaviour).
  static RestoreRecord? pendingRestore() {
    final dir = kIsWeb ? null : hiveDirectory;
    return dir == null ? null : RestoreRecordStore.read(dir);
  }

  static bool _isChecksumError(Object e) =>
      e is HiveError && e.message.contains('Wrong checksum');

  /// The box, or null when it was left closed (see [failures]).
  static Future<Box<E>?> openBox<E>(String name) async {
    final file = name.toLowerCase();
    final dir = kIsWeb ? null : hiveDirectory;

    if (dir != null) {
      final leftover = File(p.join(dir, '$file.hivec'));
      if (leftover.existsSync()) {
        try {
          await HivePreservation.preserve(
              source: leftover,
              hiveDirectory: dir,
              boxName: name,
              reason: 'compactionLeftover');
        } on PreservationException catch (e) {
          return _fail(HiveBoxFailure(
              boxName: name,
              kind: HiveBoxFailureKind.preservationFailed,
              error: 'unfinished compaction file $file.hivec',
              preservationError: e.message));
        }
      }
    }

    Object? accessError;
    for (var attempt = 1; attempt <= accessAttempts; attempt++) {
      try {
        return await _guarded(
            () => Hive.openBox<E>(name, crashRecovery: false));
      } on FileSystemException catch (e) {
        accessError = e;
        if (attempt < accessAttempts) await Future.delayed(accessRetryDelay);
      } catch (e) {
        return _damaged<E>(name, file, dir, e);
      }
    }
    return _fail(HiveBoxFailure(
        boxName: name,
        kind: HiveBoxFailureKind.inaccessible,
        error: '$accessError'));
  }

  static Future<Box<E>?> _damaged<E>(
      String name, String file, String? dir, Object error) async {
    final checksum = _isChecksumError(error);
    debugPrint('⚠️ Hive box "$name" did not open: $error');
    if (dir == null) {
      return _fail(HiveBoxFailure(
        boxName: name,
        kind: kIsWeb
            ? HiveBoxFailureKind.unreadable
            : HiveBoxFailureKind.preservationFailed,
        error: '$error',
        preservationError: kIsWeb ? null : 'the data folder is unknown',
      ));
    }

    await _waitForLockRelease(dir, file);
    final source = File(p.join(dir, '$file.hive'));
    HiveFileScan? scan;
    if (checksum) {
      try {
        scan = HiveFileInspector.scan(await source.readAsBytes());
      } catch (_) {}
    }

    final PreservedFile preserved;
    try {
      preserved = await HivePreservation.preserve(
        source: source,
        hiveDirectory: dir,
        boxName: name,
        reason: checksum ? (scan?.kind.name ?? 'checksumError') : 'unreadable',
        details: scan?.toJson() ?? const {},
        error: '$error',
      );
    } on PreservationException catch (e) {
      return _fail(HiveBoxFailure(
          boxName: name,
          kind: HiveBoxFailureKind.preservationFailed,
          error: '$error',
          scan: scan,
          preservationError: e.message));
    }

    if (!checksum) {
      return _fail(HiveBoxFailure(
          boxName: name,
          kind: HiveBoxFailureKind.unreadable,
          error: '$error',
          preserved: preserved));
    }
    if (scan == null || scan.kind != HiveDamageKind.tornFinalRecord) {
      return _fail(HiveBoxFailure(
          boxName: name,
          kind: HiveBoxFailureKind.corrupted,
          error: '$error',
          scan: scan,
          preserved: preserved));
    }

    // Only the last write was unfinished and the original is preserved: let
    // Hive drop that record, as it always did.
    try {
      final box =
          await _guarded(() => Hive.openBox<E>(name, crashRecovery: true));
      final sizeAfter = source.existsSync() ? source.lengthSync() : -1;
      repairs.add(HiveRepairNotice(name, preserved, scan, sizeAfter));
      debugPrint('🛟 "$name": unfinished last write dropped '
          '(${scan.size} → $sizeAfter bytes); original kept at '
          '${preserved.path}');
      return box;
    } catch (e) {
      return _fail(HiveBoxFailure(
          boxName: name,
          kind: e is FileSystemException
              ? HiveBoxFailureKind.inaccessible
              : HiveBoxFailureKind.unreadable,
          error: '$e',
          scan: scan,
          preserved: preserved));
    }
  }

  static Null _fail(HiveBoxFailure failure) {
    failures.add(failure);
    debugPrint('⛔ ${failure.describe()}');
    return null;
  }

  /// A failed open closes the half-opened box without waiting; its lock file
  /// disappears once that close finishes.
  static Future<void> _waitForLockRelease(String dir, String file) async {
    final lock = File(p.join(dir, '$file.lock'));
    final deadline = DateTime.now().add(lockReleaseTimeout);
    while (lock.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Runs a Hive open in its own error zone. When an open fails, Hive also
  /// fails its internal "box is opening" future, which nobody awaits; that
  /// duplicate of the error already handled is dropped here. Any other
  /// uncaught error goes on to the surrounding zone unchanged.
  static Future<T> _guarded<T>(Future<T> Function() body) {
    final outer = Zone.current;
    final result = Completer<T>();
    Object? handled;
    var settled = false;
    final early = <(Object, StackTrace)>[];
    void forward(Object e, StackTrace s) {
      if (identical(e, handled)) return;
      // After a failed open Hive closes the half-opened box without waiting;
      // that close can fail too (e.g. it cannot delete a `.lock` file another
      // process holds). Nothing to act on: the failure is already handled.
      if (handled != null && e is FileSystemException) {
        debugPrint('Hive cleanup after a failed open: $e');
        return;
      }
      outer.handleUncaughtError(e, s);
    }

    runZonedGuarded(() async {
      try {
        result.complete(await body());
      } catch (e, s) {
        handled = e;
        result.completeError(e, s);
      }
      // The duplicate may be reported before the error reaches the catch.
      settled = true;
      for (final (e, s) in early) {
        forward(e, s);
      }
      early.clear();
    }, (e, s) {
      if (settled) {
        forward(e, s);
      } else {
        early.add((e, s));
      }
    });
    return result.future;
  }
}
