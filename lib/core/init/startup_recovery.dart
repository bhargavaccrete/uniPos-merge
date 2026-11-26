import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import 'hive_init.dart';
import 'hive_preservation.dart';
import 'hive_safe_open.dart';
import 'recovery_journal.dart';
import 'restore_record.dart';

/// A backup the recovery screen will not use. Nothing was changed.
class RecoveryRefused implements Exception {
  final String message;
  RecoveryRefused(this.message);
  @override
  String toString() => message;
}

/// No save method worked. The preserved files were not touched.
class ExportFailed implements Exception {
  final String message;
  ExportFailed(this.message);
  @override
  String toString() => message;
}

/// An export built and verified in memory, not yet saved.
class BuiltExport {
  final Uint8List bytes;
  final Map<String, Uint8List> sources;
  final String fileName;
  const BuiltExport(this.bytes, this.sources, this.fileName);
}

enum ExportOutcomeKind { savedToFolder, savedViaDialog, cancelled }

class ExportOutcome {
  final ExportOutcomeKind kind;

  /// Saved path (or, after the Android Save dialog, the document name).
  final String? location;
  final String? note;
  const ExportOutcome(this.kind, this.location, {this.note});
}

enum RecoveryRestoreResult { restored, notStarted, failed }

class RecoveryRestoreOutcome {
  final RecoveryRestoreResult result;

  /// What still blocks startup after an unsuccessful restore (the originals
  /// are back). Null after success, or when the originals now open.
  final HiveStartupBlocked? blocked;
  final Object? error;
  const RecoveryRestoreOutcome(this.result, {this.blocked, this.error});
}

String _modeLabel(String mode) =>
    mode == BusinessMode.retail.name ? 'Retail' : 'Restaurant';

/// M4 startup recovery: the actions behind the Recovery screen. None of them
/// can leave the app running with an empty or missing business-data box.
class StartupRecovery {
  StartupRecovery._();

  /// Restore and export need files: not on web, and only when the data folder
  /// is known.
  static bool get filesSupported =>
      !kIsWeb && HiveSafeOpen.hiveDirectory != null;

  /// A restore must not start while a box is merely in use (that is not
  /// damage: Retry is the answer) or when nothing needs recovering. BKP-5
  /// (C2): an interrupted restore needs recovering even when every box opens.
  static bool canRestore(List<HiveBoxFailure> failures,
          {RestoreRecord? interrupted}) =>
      filesSupported &&
      (failures.isNotEmpty || interrupted != null) &&
      failures.every((f) => f.kind != HiveBoxFailureKind.inaccessible);

  /// The device's business type, or null when it is unknown (the box that
  /// stores it is one of the failures, or setup never finished).
  static String? deviceMode(List<HiveBoxFailure> failures) {
    if (failures.any((f) => f.boxName == HiveBoxNames.appConfig)) return null;
    if (!AppConfig.isInitialized || !AppConfig.isBusinessModeSet) return null;
    return AppConfig.businessMode.name;
  }

  /// Opens every startup box again. Null when all opened (normal startup may
  /// continue); otherwise what is still blocked — including an unfinished
  /// restore (BKP-5). Never creates, deletes or repairs a damaged file beyond
  /// what [HiveSafeOpen] allows.
  ///
  /// [forRestore] (C1): only for opening the boxes a restore is about to
  /// replace; an open restore record does not block that. Null then does NOT
  /// mean normal startup may continue.
  static Future<HiveStartupBlocked?> retry({bool forRestore = false}) async {
    HiveSafeOpen.failures.clear();
    HiveSafeOpen.repairs.clear();
    HiveInit.forgetOpenedGroups();
    try {
      await HiveInit.openStartupBoxes(forRestore: forRestore);
      return null;
    } on HiveStartupBlocked catch (e) {
      return e;
    }
  }

  /// Steps 2–4, before anything moves: the password opens the file and its
  /// integrity checks pass, it is a backup of this device's business type,
  /// and it contains every BKP-9 critical section. Throws [RecoveryRefused]
  /// or the import's own error. Writes nothing.
  static Future<String> checkBackup({
    required String path,
    required String password,
    required String? deviceMode,
  }) async {
    final info = await UnifiedBackupService.inspectBackupFile(path, password);
    if (info.mode != BusinessMode.restaurant.name &&
        info.mode != BusinessMode.retail.name) {
      throw RecoveryRefused('This file is not a Bill Berry Lite Restaurant or '
          'Retail backup, so it was not used.');
    }
    if (deviceMode != null && info.mode != deviceMode) {
      throw RecoveryRefused('This is a ${_modeLabel(info.mode)} backup, but '
          'this device is set up for ${_modeLabel(deviceMode)}. It was not '
          'used.');
    }
    if (info.missingCriticalSections.isNotEmpty) {
      throw RecoveryRefused('This backup does not contain all business '
          'records (missing: ${info.missingCriticalSections.join(', ')}). It '
          'cannot fully replace the damaged data, so it was not used.');
    }
    return info.mode;
  }

  /// Steps 6–10. [runRestore] is the existing restore (production:
  /// `UnifiedBackupService.importFromFilePath`); it runs only after every
  /// failed original was moved aside and every box opened. On any outcome but
  /// success the originals are put back and startup is blocked again.
  ///
  /// [prepareServices] builds what the existing restore expects to find
  /// (the service locator), after every box is open.
  static Future<RecoveryRestoreOutcome> restore({
    required List<HiveBoxFailure> failures,
    required Future<bool> Function() runRestore,
    Future<void> Function()? prepareServices,
    // BKP-5: the open record of an interrupted restore. It keeps pointing to
    // the original data until this restore succeeds (R2).
    RestoreRecord? interrupted,
  }) async {
    if (!canRestore(failures, interrupted: interrupted)) {
      return RecoveryRestoreOutcome(RecoveryRestoreResult.notStarted,
          blocked: HiveStartupBlocked(failures, interruptedRestore: interrupted));
    }
    final dir = HiveSafeOpen.hiveDirectory!;

    // 6–7: move each failed original aside (recorded first), then open every
    // box. A damaged box found only now (e.g. behind a damaged AppConfig) is
    // handled the same way.
    var toMove = failures;
    for (var round = 0;; round++) {
      try {
        await RecoveryJournal.moveAside(
            dir, toMove.map((f) => f.boxName).toList());
      } catch (e) {
        return _abandon(dir, RecoveryRestoreResult.notStarted, e);
      }
      final still = await retry(forRestore: true);
      if (still == null) break;
      if (round >= 4 || !canRestore(still.failures)) {
        return _abandon(dir, RecoveryRestoreResult.notStarted, still);
      }
      toMove = still.failures;
    }

    Object? error;
    try {
      await prepareServices?.call();
      if (await runRestore()) {
        await RecoveryJournal.complete(dir);
        // The restore did not own a record that was already open: it is
        // closed here, after success (the backup replaced everything).
        if (interrupted != null) {
          await RestoreRecordStore.close(dir, 'replaced-by-backup');
        }
        return const RecoveryRestoreOutcome(RecoveryRestoreResult.restored);
      }
    } catch (e) {
      error = e;
    }
    return _abandon(dir, RecoveryRestoreResult.failed, error);
  }

  /// BKP-5 Undo: puts back the data from before an interrupted normal
  /// restore — the record's snapshot through the existing restore
  /// ([runRestore] gets its path), then the record's pending-work journal.
  /// The record stays open (startup stays blocked) until both are back and
  /// verified, so an Undo that fails or is interrupted can be repeated.
  static Future<RecoveryRestoreOutcome> undo({
    required RestoreRecord record,
    required Future<bool> Function(String snapshotPath) runRestore,
    Future<void> Function()? prepareServices,
  }) async {
    final dir = HiveSafeOpen.hiveDirectory;
    if (!filesSupported || dir == null || !record.canUndo) {
      return RecoveryRestoreOutcome(RecoveryRestoreResult.notStarted,
          blocked: HiveStartupBlocked(const [], interruptedRestore: record),
          error: RecoveryRefused('Undo is not available for this restore.'));
    }
    if (!RestoreRecordStore.snapshotIntact(record)) {
      return RecoveryRestoreOutcome(RecoveryRestoreResult.notStarted,
          blocked: HiveStartupBlocked(const [], interruptedRestore: record),
          error: RecoveryRefused('The safety copy taken before the restore is '
              'missing or has changed, so it cannot be put back. Restore a '
              'backup instead, or export the files for support.'));
    }
    final still = await retry(forRestore: true);
    if (still != null) {
      return RecoveryRestoreOutcome(RecoveryRestoreResult.notStarted,
          blocked: still);
    }

    Object? error;
    try {
      await prepareServices?.call();
      if (await runRestore(record.snapshotPath)) {
        final journalBack = await UnifiedBackupService
            .putBackWorkJournalEntries(record.mode, record.journal);
        if (journalBack) {
          await RestoreRecordStore.close(dir, 'undone');
          return const RecoveryRestoreOutcome(RecoveryRestoreResult.restored);
        }
        error = StateError('the data was put back, but the pending stock work '
            'list could not be put back and checked');
      }
    } catch (e) {
      error = e;
    }
    await Hive.close();
    return RecoveryRestoreOutcome(RecoveryRestoreResult.failed,
        blocked: await retry() ??
            HiveStartupBlocked(const [], interruptedRestore: record),
        error: error);
  }

  static Future<RecoveryRestoreOutcome> _abandon(
      String dir, RecoveryRestoreResult result, Object? error) async {
    await Hive.close();
    await RecoveryJournal.revert(dir);
    // Null only if the originals now open (the problem was temporary): the
    // caller may then continue normal startup, exactly as after Retry.
    final blocked = await retry();
    return RecoveryRestoreOutcome(result, blocked: blocked, error: error);
  }

  /// Every preserved file (copies, manifests, moved originals, recovery
  /// records), relative to the preservation root. Unverified temporary
  /// `.copying` files are left out.
  static List<File> preservedFiles() {
    final dir = HiveSafeOpen.hiveDirectory;
    if (kIsWeb || dir == null) return const [];
    final root = Directory(p.join(dir, HivePreservation.folderName));
    if (!root.existsSync()) return const [];
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !f.path.endsWith('.copying'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// What "Export for support" contains, entry name → file: every preserved
  /// file (relative to the preservation root) and, while a restore record is
  /// open (BKP-5), the record and the snapshot it points to under
  /// `interrupted-restore/`.
  static Map<String, File> exportSources() {
    final dir = HiveSafeOpen.hiveDirectory;
    if (kIsWeb || dir == null) return const {};
    final root = p.join(dir, HivePreservation.folderName);
    final out = <String, File>{
      for (final f in preservedFiles())
        p.posix.joinAll(p.split(p.relative(f.path, from: root))): f,
    };
    final record = RestoreRecordStore.file(dir);
    if (record.existsSync()) {
      out['interrupted-restore/${p.basename(record.path)}'] = record;
      final open = RestoreRecordStore.read(dir);
      if (open != null && open.readable) {
        final snap = File(open.snapshotPath);
        if (snap.existsSync()) {
          out['interrupted-restore/${p.basename(snap.path)}'] = snap;
        }
      }
    }
    return out;
  }

  /// Test hook: runs on the written temporary export before it is verified.
  @visibleForTesting
  static Future<void> Function(File part)? afterExportWriteForTesting;

  static const String exportPrefix = 'BillBerryLite_damaged-data_';
  static const String exportExtension = '.bblsupport';

  /// Test hook replacing the final rename of a written export.
  @visibleForTesting
  static Future<void> Function(File part, String target)? renameForTesting;

  /// Waits between rename attempts (one more attempt than waits). A rename
  /// can fail briefly while antivirus or OneDrive opens the new file.
  @visibleForTesting
  static List<Duration> renameRetryDelays = const [
    Duration(milliseconds: 150),
    Duration(milliseconds: 300),
    Duration(milliseconds: 600),
    Duration(milliseconds: 1200),
  ];

  /// Builds the encrypted export of every preserved file and checks it in
  /// memory (decrypt + compare every entry) before anything is saved. Same
  /// two layers as a backup: a password-protected (AES) zip, then the whole
  /// zip encrypted with [password]. Reads the preserved files only.
  static Future<BuiltExport> buildExport(String password) async {
    if (!filesSupported) {
      throw RecoveryRefused('Exporting files is not available here.');
    }
    final files = exportSources();
    if (files.isEmpty) {
      throw RecoveryRefused('There are no preserved files to export.');
    }
    final sources = <String, Uint8List>{
      for (final e in files.entries) e.key: await e.value.readAsBytes(),
    };

    final archive = Archive();
    sources.forEach((name, bytes) =>
        archive.addFile(ArchiveFile(name, bytes.length, bytes)));
    final zip = ZipEncoder(password: password).encode(archive);
    if (zip == null || zip.isEmpty) throw StateError('the export zip is empty');
    if (_readableWithoutPassword(zip, sources)) {
      throw StateError('encryption failed — refusing to save a readable file');
    }
    final blob =
        BackupEncryptionService.encryptBytes(Uint8List.fromList(zip), password);
    if (!_matches(readExport(blob, password), sources)) {
      throw StateError('the export did not decrypt back to the preserved files');
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    return BuiltExport(blob, sources, '$exportPrefix$stamp$exportExtension');
  }

  static bool _matches(
          Map<String, Uint8List> opened, Map<String, Uint8List> sources) =>
      opened.length == sources.length &&
      sources.entries.every((e) => listEquals(opened[e.key], e.value));

  /// [target], or `name-1.ext`, `name-2.ext`… when it exists: an existing
  /// file is never overwritten.
  static File unusedTarget(File target) {
    if (!target.existsSync()) return target;
    final dir = target.parent.path;
    final ext = p.extension(target.path);
    final stem = p.basenameWithoutExtension(target.path);
    for (var i = 1;; i++) {
      final f = File(p.join(dir, '$stem-$i$ext'));
      if (!f.existsSync()) return f;
    }
  }

  /// Writes [built] next to [requested] (under a free name), reads it back,
  /// decrypts and compares it, and only then renames it into place, retrying
  /// a short-lived lock. Returns the final path. On failure only this write's
  /// own `.part` file is removed; nothing else is touched.
  static Future<String> writeExport(
      BuiltExport built, String password, File requested) async {
    await requested.parent.create(recursive: true);
    var target = unusedTarget(requested);
    final part = File('${target.path}.part');
    try {
      await part.writeAsBytes(built.bytes, flush: true);
      await afterExportWriteForTesting?.call(part);
      final back = await part.readAsBytes();
      if (!_matches(readExport(back, password), built.sources)) {
        throw StateError('the saved export does not match the preserved files');
      }
      for (var attempt = 0;; attempt++) {
        target = unusedTarget(target);
        try {
          final rename = renameForTesting;
          if (rename != null) {
            await rename(part, target.path);
          } else {
            await part.rename(target.path);
          }
          return target.path;
        } on FileSystemException {
          if (attempt >= renameRetryDelays.length) rethrow;
          await Future.delayed(renameRetryDelays[attempt]);
        }
      }
    } catch (e) {
      try {
        if (part.existsSync()) part.deleteSync(); // our own unverified temp
      } catch (_) {}
      rethrow;
    }
  }

  /// Saves the export into [targetDirectory] (verified, under a free name).
  static Future<String> exportPreserved({
    required String password,
    required String targetDirectory,
  }) async {
    final built = await buildExport(password);
    return writeExport(
        built, password, File(p.join(targetDirectory, built.fileName)));
  }

  /// Saves the export the way this platform allows.
  ///
  /// Android: the Downloads folder first (as backups do). Only when that
  /// fails with a file-system error (no storage permission on Android 7–10,
  /// a work profile, storage unavailable) the system Save-as dialog gets the
  /// already verified bytes. A Downloads copy that reads back wrong is an
  /// error, not a reason to try elsewhere.
  ///
  /// Desktop: the system Save dialog (starting in Downloads when the system
  /// reports one; never a silent fallback to Documents), then the verified
  /// write with a free name and rename retries.
  ///
  /// Throws [ExportFailed] when no method saved it. Never touches the
  /// preserved files.
  static Future<ExportOutcome> exportForThisPlatform({
    required String password,
    bool? android,
    Future<String> Function()? downloadsDirectory,
    Future<String?> Function(String fileName, Uint8List bytes)? saveAsWithBytes,
    Future<String?> Function(String fileName, String? initialDirectory)?
        pickSavePath,
    Future<String?> Function()? desktopInitialDirectory,
  }) async {
    final built = await buildExport(password);

    if (android ?? Platform.isAndroid) {
      Object? downloadsError;
      try {
        final dir =
            await (downloadsDirectory ?? UnifiedBackupService.downloadsBackupPath)();
        final saved =
            await writeExport(built, password, File(p.join(dir, built.fileName)));
        return ExportOutcome(ExportOutcomeKind.savedToFolder, saved);
      } on FileSystemException catch (e) {
        downloadsError = e.osError?.message ?? e.message;
      }
      final String? shown;
      try {
        shown = await (saveAsWithBytes ?? _saveAsWithBytes)(
            built.fileName, built.bytes);
      } catch (e) {
        throw ExportFailed('The export could not be saved to Downloads '
            '($downloadsError) or through the Save dialog '
            '(${e is PlatformException ? e.message ?? e.code : e}).');
      }
      if (shown == null) {
        return ExportOutcome(ExportOutcomeKind.cancelled, null,
            note: 'The Downloads folder is not available on this device '
                '($downloadsError), and saving was cancelled.');
      }
      return ExportOutcome(ExportOutcomeKind.savedViaDialog, shown);
    }

    final initial =
        await (desktopInitialDirectory ?? _desktopDownloads)();
    var name = built.fileName;
    if (initial != null) {
      name = p.basename(unusedTarget(File(p.join(initial, name))).path);
    }
    final chosen = await (pickSavePath ?? _pickSavePath)(name, initial);
    if (chosen == null) {
      return const ExportOutcome(ExportOutcomeKind.cancelled, null,
          note: 'Export cancelled.');
    }
    final requested = File(p.extension(chosen).toLowerCase() == exportExtension
        ? chosen
        : '$chosen$exportExtension');
    final saved = await writeExport(built, password, requested);
    return ExportOutcome(ExportOutcomeKind.savedToFolder, saved,
        note: p.equals(saved, requested.path)
            ? null
            : 'A file with the chosen name already exists, so it was kept '
                'and the export was saved under a new name.');
  }

  static Future<String?> _saveAsWithBytes(String fileName, Uint8List bytes) =>
      FilePicker.platform.saveFile(
          dialogTitle: 'Save export for support',
          fileName: fileName,
          bytes: bytes);

  static Future<String?> _pickSavePath(String fileName, String? initial) =>
      FilePicker.platform.saveFile(
        dialogTitle: 'Save export for support',
        fileName: fileName,
        initialDirectory: initial,
        type: FileType.custom,
        allowedExtensions: [exportExtension.substring(1)],
        lockParentWindow: true,
      );

  static Future<String?> _desktopDownloads() async {
    try {
      return (await getDownloadsDirectory())?.path;
    } catch (_) {
      return null;
    }
  }

  /// Opens an export made by [exportPreserved]: entry name → bytes. Throws on
  /// a wrong password or damaged file.
  static Map<String, Uint8List> readExport(List<int> bytes, String password) {
    final zip = BackupEncryptionService.decryptBytes(
        Uint8List.fromList(bytes), password);
    if (zip == null) throw StateError('wrong password or damaged export');
    final archive = ZipDecoder().decodeBytes(zip, password: password);
    return {
      for (final f in archive.files.where((f) => f.isFile))
        f.name: Uint8List.fromList(f.content as List<int>),
    };
  }

  static bool _readableWithoutPassword(
      List<int> zip, Map<String, Uint8List> sources) {
    try {
      final archive = ZipDecoder().decodeBytes(zip);
      for (final f in archive.files.where((f) => f.isFile)) {
        final original = sources[f.name];
        if (original != null &&
            original.isNotEmpty &&
            listEquals(Uint8List.fromList(f.content as List<int>), original)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
