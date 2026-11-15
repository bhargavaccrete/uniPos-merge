import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:universal_html/html.dart' as html;
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/main.dart' show navigatorKey;
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/services/retail/retail_checkout_commit.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/screens/common/backup/restore_skipped_notice.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/data/models/common/business_type.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/models/tax_details.dart';
import 'package:billberrylite/models/payment_method.dart' as pm;

// Restaurant models
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/choicemodel_306.dart';
import 'package:billberrylite/data/models/restaurant/db/extramodel_303.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';

import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/testbillmodel_318.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_handover_model.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/common/attendance_model.dart';

// Shared models
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/expensemodel_315.dart';

// Helper classes
import 'package:billberrylite/data/models/restaurant/db/database/hive_expensecategory.dart';

// Retail models
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/models/retail/hive_model/stock_take_model_180.dart';
import '../../../data/models/retail/hive_model/stock_take_item_model_181.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/payment_entry_model_216.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_production_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_item_model.dart';

/// Unified Backup Service - Works for both Restaurant and Retail modes
///
/// Features:
/// - Mode-aware data export (automatically detects Restaurant/Retail)
/// - ZIP format with images (if available)
/// - Auto-save to Downloads or custom folder
/// - Import with automatic mode detection
/// - Complete data backup including EOD and Expenses

// Top-level functions — must be outside the class for compute() to use them.

// Serialises data map to JSON string in a background isolate.
String _jsonEncodeMap(Map<String, dynamic> data) => jsonEncode(data);

/// A decoded backup file: its data map plus the image entries still to write.
typedef _DecodedBackup = ({
  Map<String, dynamic> data,
  List<Map<String, dynamic>> images,
});

/// One pass over a backup: the validate-only pass or the real write pass.
///
/// The validate pass records which boxes the restore tolerates as unreadable
/// (their step swallows the error); the write pass leaves those boxes as they
/// are instead of emptying them. Every box write goes through [write], so the
/// first failure, even one an existing try/catch would swallow, is kept and
/// stops all later writes.
class _RestoreRun {
  _RestoreRun({
    required this.validateOnly,
    Map<String, String>? tolerated,
    this.isRollback = false,
  }) : tolerated = tolerated ?? {};

  final bool validateOnly;
  final bool isRollback;

  /// Box name → backup key of sections the restore could not read.
  final Map<String, String> tolerated;

  Object? writeFailure;

  /// BKP-9: device settings (`localPrefs`, `secureCreds`) that could not be
  /// restored; reported with the skipped sections.
  final List<String> unrestoredSettings = [];

  /// BKP-9: steps after the writes that did not finish (user-facing labels).
  final List<String> postRestoreWarnings = [];

  bool isTolerated(String boxName) => tolerated.containsKey(boxName);

  /// Validate pass: runs [read]; on failure remembers the box, then rethrows
  /// so the surrounding step behaves exactly as the restore would.
  T parse<T>(String boxName, String key, T Function() read) {
    try {
      return read();
    } catch (_) {
      if (validateOnly) tolerated[boxName] = key;
      rethrow;
    }
  }

  /// Write pass: runs one box's writes. [body] returns the record count the
  /// box must hold afterwards (null = not checked). A throw or a wrong count
  /// is kept as [writeFailure]; once set, later writes are skipped.
  Future<void> write(
      String key, Box box, Future<int?> Function() body) async {
    if (writeFailure != null) return;
    try {
      final expected = await body();
      if (expected != null && box.length != expected) {
        throw StateError(
            '"$key" holds ${box.length} records after writing $expected');
      }
      final inject = isRollback
          ? UnifiedBackupService.failRollbackWritingKeyForTesting
          : UnifiedBackupService.failWritingKeyForTesting;
      if (inject == key) {
        throw StateError('injected write failure on "$key"');
      }
    } catch (e) {
      writeFailure = StateError('Writing "$key" failed: $e');
    }
  }
}

/// Restore image writes, made undoable: every file the restore overwrites is
/// first copied to an undo folder, every file it creates is recorded.
class _ImageJournal {
  _ImageJournal(this.undoDir);

  final Directory undoDir;
  final Map<String, String?> _undo = {}; // target path → saved copy (null = new)

  Future<void> write(File target, List<int> bytes) async {
    if (!_undo.containsKey(target.path)) {
      if (target.existsSync()) {
        if (!undoDir.existsSync()) undoDir.createSync(recursive: true);
        final copy = File(p.join(undoDir.path, '${_undo.length}'));
        await target.copy(copy.path);
        _undo[target.path] = copy.path;
      } else {
        _undo[target.path] = null;
      }
    }
    target
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  /// Puts every overwritten file back and deletes every created one.
  Future<void> revert() async {
    for (final entry in _undo.entries) {
      final target = File(entry.key);
      final saved = entry.value;
      if (saved == null) {
        if (target.existsSync()) target.deleteSync();
      } else {
        await File(saved).copy(target.path);
      }
    }
    discard();
  }

  /// The restore succeeded: the saved originals are no longer needed.
  void discard() {
    if (undoDir.existsSync()) undoDir.deleteSync(recursive: true);
    _undo.clear();
  }
}

/// This device's data taken just before a restore's first write.
class _Snapshot {
  _Snapshot(this.data, this.itemImages, this.filePath);

  /// The export map (`_collectAllData`), detached through JSON.
  final Map<String, dynamic> data;

  /// Restaurant item image bytes, which the export map strips.
  final Map<String, Uint8List> itemImages;

  /// Encrypted copy on disk, or null (no backup password, web, or failed).
  final String? filePath;
}

/// A restore that failed after it had started writing.
class RestoreFailedException implements Exception {
  RestoreFailedException({
    required this.cause,
    required this.dataRolledBack,
    this.journalRestored = true,
    this.snapshotPath,
    this.unrestoredJournal,
    this.unrestoredJournalEntries = const {},
  });

  final Object cause;

  /// The business data was put back AND re-checked equal to the snapshot.
  final bool dataRolledBack;

  /// Every pending-work journal entry from before the restore was put back
  /// AND re-checked.
  final bool journalRestored;

  /// Both: the device is exactly as it was before the restore.
  bool get rolledBack => dataRolledBack && journalRestored;

  /// Encrypted copy of the data from just before the restore, if one exists.
  final String? snapshotPath;

  /// The pending-work journal that could not be put back, or null.
  final String? unrestoredJournal;

  /// Its entries as they were before the restore (kept for diagnosis).
  final Map<dynamic, dynamic> unrestoredJournalEntries;

  String get userMessage {
    final copy = snapshotPath == null
        ? ''
        : '\n\nA protected copy of your data from just before the restore is '
            'saved inside the app at:\n$snapshotPath';
    final journalName = unrestoredJournal ?? 'pending-work journal';
    final pending = journalRestored
        ? ''
        : '\n\n${unrestoredJournalEntries.length} entries of unfinished stock '
            'work in the $journalName could not be put back.';
    if (dataRolledBack && journalRestored) {
      return 'The backup could not be fully restored, so your previous data was '
          'put back and checked. Nothing from the backup was kept.$copy';
    }
    if (dataRolledBack) {
      return 'The backup could not be fully restored. Your business data was '
          'put back and checked, and nothing from the backup was kept.'
          '$pending Please contact support before selling or adjusting '
          'stock.$copy';
    }
    return 'The backup could not be fully restored, and your previous data '
        'could NOT be fully put back. Please stop using the app and contact '
        'support before entering new data.$pending$copy';
  }

  @override
  String toString() => 'RestoreFailedException(rolledBack: $rolledBack, '
      'dataRolledBack: $dataRolledBack, journalRestored: $journalRestored, '
      '${journalRestored ? '' : 'journal not restored: $unrestoredJournal '
          '(${unrestoredJournalEntries.length} entries), '}$cause)';
}

/// BKP-11: a backup file that was written but could not be read back and
/// opened. No file is left under the backup's name.
class BackupVerificationException implements Exception {
  const BackupVerificationException(this.detail);

  final String detail;

  String get message =>
      'Backup not saved: the file could not be checked after writing '
      '($detail). No backup file was kept. Check that there is free storage '
      'space and try again.';

  @override
  String toString() => message;
}

/// BKP-9: a restore refused before anything was written, because sections
/// holding money, stock, ledgers or numbering could not be read.
class RestoreRefusedException implements Exception {
  RestoreRefusedException(this.sections);

  /// The unreadable critical sections (backup keys), sorted.
  final List<String> sections;

  String get message =>
      'This backup was not restored: these sections could not be read: '
      '${sections.join(', ')}. Nothing on this device was changed.';

  @override
  String toString() => message;
}

// Decodes a password-protected (WinZip-AES) ZIP → file entries (CPU-heavy, runs
// in an isolate). [password] decrypts each entry's content.
List<Map<String, dynamic>> _decodeZipInIsolate((List<int>, String?) args) {
  final (zipBytes, password) = args;
  try {
    final archive = ZipDecoder().decodeBytes(zipBytes, password: password);
    return archive
        .where((f) => f.content != null)
        .map((f) => {'name': f.name, 'bytes': f.content as List<int>})
        .toList();
  } catch (e) {
    // 4e-1: the WinZip-AES entry authentication code did not match. Reached
    // only past the password check, so the contents are damaged.
    if ('$e'.contains(archiveMacMismatchError)) {
      throw StateError(innerIntegrityFailure);
    }
    rethrow;
  }
}

/// The `archive` package's error when a WinZip-AES entry's authentication
/// code does not match its contents (pinned by test).
@visibleForTesting
const String archiveMacMismatchError = "macs don't match";

/// Marker carried out of the decode isolate for that failure.
@visibleForTesting
const String innerIntegrityFailure = 'bbl-inner-integrity-failure';

bool _isInnerIntegrityFailure(Object e) => '$e'.contains(innerIntegrityFailure);

// Encodes entries into a password-protected (WinZip-AES) ZIP. The file LIST is
// visible, but every entry's CONTENT is AES-encrypted — opening/extracting any
// file requires the password. Runs in an isolate.
Uint8List? _encodeArchiveInIsolate((List<Map<String, dynamic>>, String?) args) {
  final (entries, password) = args;
  final archive = Archive();
  for (final entry in entries) {
    final bytes = entry['bytes'] as List<int>;
    archive.addFile(ArchiveFile(entry['name'] as String, bytes.length, bytes));
  }
  final result = ZipEncoder(password: password).encode(archive);
  return result == null ? null : Uint8List.fromList(result);
}

class UnifiedBackupService {
  static const String _backupDirectoryName = 'BillBerryLite_Backups';

  /// Shown when an import is rejected for not being encrypted.
  static const String _unencryptedMsg =
      'This backup is not encrypted and cannot be restored. '
      'Only password-protected backups are supported.';

  /// BKP-11: the file's own bytes show it is incomplete; no password can
  /// open it, so the user is not asked for one.
  static const String backupDamagedMessage =
      'This backup file is damaged or incomplete (it may not have finished '
      'saving or copying), so it cannot be opened with any password. Try '
      'another backup file.';

  /// BKP-11: decryption failed on a file that looks complete. The format has
  /// no checksum, so a wrong password and a damaged file look the same.
  static const String backupWrongPasswordMessage =
      'Wrong password, or the backup file is damaged — cannot open backup.';

  /// 4e-1: the password was right, but the contents failed their integrity
  /// check (the WinZip-AES authentication code).
  static const String backupIntegrityFailedMessage =
      'This backup file is damaged: part of its contents failed the integrity '
      'check, so it cannot be restored. The password was accepted. Try '
      'another backup file.';

  /// The message for a failure decoding the zip inside a backup.
  static String _innerDecodeMessage(Object e, String otherwise) =>
      _isInnerIntegrityFailure(e) ? backupIntegrityFailedMessage : otherwise;

  /// Refuses an encrypted backup whose bytes show it is incomplete.
  static void _refuseTruncatedBlob(List<int> bytes) {
    if (BackupEncryptionService.isTruncatedBlob(bytes)) {
      throw Exception(backupDamagedMessage);
    }
  }

  /// Decrypts the outer layer of an encrypted backup, or throws the message
  /// that matches the failure.
  static Uint8List _openProtectedBlob(Uint8List bytes, String password) {
    _refuseTruncatedBlob(bytes);
    final zip = BackupEncryptionService.decryptBytes(bytes, password);
    if (zip == null) throw Exception(backupWrongPasswordMessage);
    return zip;
  }

  /// SharedPreferences keys NEVER backed up or restored — device-bound
  /// (device id / license / printers / captain net config) or session/transient.
  /// Restoring these to another device would break licensing/printing.
  static const Set<String> _prefsDenylist = {
    // Device & license (security-critical, per-device)
    'unipos_device_id', 'unipos_device_id_source', 'unipos_license_token',
    'unipos_pending_license_key', 'unipos_last_seen_epoch', 'unipos_license_bypass',
    // Hardware / network config
    'default_kot_printer_id', 'default_receipt_printer_id',
    'captain_pos_ip', 'captain_logged_in', 'captain_staff_id', 'is_captain_mode',
    // Session / auth state (re-established on login)
    'restaurant_is_logged_in', 'restaurant_login_type', 'restaurant_staff_role',
    'restaurant_staff_name', 'restaurant_current_shift_id',
    'admin_session', 'admin_username', 'admin_session_timestamp',
    'admin_staff_id',
    // Transient / regenerated
    'last_backup_date', 'auto_backup_enabled', 'first_time_pos',
    'first_time_pos_v2', 'last_eod_date', 'retail_last_eod_date',
    'pendingEod_snoozed_date', 'dev_rsa_keypair_v1',
  };

  /// ---------------------------
  /// 🔧 HELPER: Deep clean map for JSON serialization
  /// ---------------------------
  /// Recursively cleans a map to ensure all values are JSON serializable
  /// Handles nested maps, lists, and converts non-serializable objects
  static dynamic _deepCleanMap(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Map) {
      final cleanedMap = <String, dynamic>{};
      value.forEach((key, val) {
        cleanedMap[key.toString()] = _deepCleanMap(val);
      });
      return cleanedMap;
    } else if (value is List) {
      return value.map((item) => _deepCleanMap(item)).toList();
    } else if (value is String || value is num || value is bool) {
      return value;
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else {
      // For any other type, try to convert to string
      return value.toString();
    }
  }

  /// Folder that [exportToDownloads] writes to. Android keeps the public
  /// Download folder; desktop uses the OS Downloads folder (a hardcoded
  /// `/storage/...` path on Windows silently resolves to `<drive>:\storage\...`).
  static Future<String> downloadsBackupPath() async {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return '/storage/emulated/0/Download';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  /// ---------------------------
  /// ✅ EXPORT TO DOWNLOADS (AUTO-SAVE)
  /// ---------------------------
  /// Automatically saves backup to Downloads folder
  /// Returns the file path or null if failed
  static Future<String?> exportToDownloads({bool includeImages = true}) async {
    lastExportError = null;
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return null;
    if (kIsWeb) {
      return await _exportForWeb();
    }

    try {
      debugPrint("📦 Starting backup to Downloads (images: $includeImages)...");

      // Collect all data
      final data = await _collectCompleteBackup();

      // Create ZIP backup
      return await _createZipBackup(data, saveToDownloads: true, includeImages: includeImages);
    } catch (e, stackTrace) {
      debugPrint("❌ Auto-save backup failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// Web-only: serialize backup to JSON, zip it and trigger browser download.
  static Future<String?> _exportForWeb() async {
    try {
      debugPrint("📦 Web backup: collecting data...");
      final data = await _collectCompleteBackup();
      final jsonString = jsonEncode(data);

      // Encryption is mandatory — never write plaintext on web either.
      final password = await BackupEncryptionService.getStoredPassword();
      if (password == null || password.isEmpty) {
        throw Exception(
            'No backup password set — refusing to write an unencrypted backup');
      }
      const isEncrypted = true;

      // Password-protected zip: data.json's content is AES-encrypted, so it
      // can't be opened without the password.
      final encryptedDataMap = BackupEncryptionService.encryptData(jsonString, password);
      final encryptedJsonString = jsonEncode(encryptedDataMap);

      final archive = Archive();
      final jsonBytes = utf8.encode(encryptedJsonString);
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

      final zipData = ZipEncoder(password: password).encode(archive);
      if (zipData == null) throw Exception("ZIP creation failed");
      if (_looksLikePlainBackup(zipData)) {
        throw Exception(
            'Backup encryption failed — refusing to write a readable file');
      }

      // Encrypt the entire ZIP bytes to fully protect the zip file (header & filenames)
      final protectedZipData = BackupEncryptionService.encryptBytes(Uint8List.fromList(zipData), password);

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final suffix = isEncrypted ? 'encrypted' : 'backup';
      final fileName = 'BillBerryLite_${suffix}_$timestamp.zip';

      final blob = html.Blob([protectedZipData]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      debugPrint("✅ Web backup downloaded: $fileName");
      return fileName;
    } catch (e) {
      debugPrint("❌ Web backup failed: $e");
      return null;
    }
  }

  /// ---------------------------
  /// ✅ EXPORT TO CUSTOM FOLDER
  /// ---------------------------
  /// Saves backup to user-selected folder
  /// Returns the file path or null if failed
  static Future<String?> exportToCustomFolder(String folderPath) async {
    lastExportError = null;
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return null;
    if (kIsWeb) {
      return await _exportForWeb();
    }

    try {
      debugPrint("📦 Starting backup to custom folder: $folderPath");

      // Collect all data
      final data = await _collectCompleteBackup();

      // Create ZIP backup
      return await _createZipBackup(data, customPath: folderPath);
    } catch (e, stackTrace) {
      debugPrint("❌ Custom folder backup failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// ---------------------------
  /// ✅ EXPORT TO SHARE (share sheet / web download)
  /// ---------------------------
  /// Saves backup to app cache then shares it via the system share sheet.
  /// On web, triggers a browser download instead.
  static Future<String?> exportToShare() async {
    lastExportError = null;
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return null;
    if (kIsWeb) return await _exportForWeb();
    try {
      final data = await _collectCompleteBackup();
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/backup_share_cache');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
      return await _createZipBackup(data, customPath: cacheDir.path);
    } catch (e) {
      debugPrint("❌ exportToShare failed: $e");
      return null;
    }
  }

  /// ---------------------------
  /// ✅ IMPORT/RESTORE FROM BACKUP
  /// ---------------------------
  /// Imports backup file and automatically detects mode.
  /// Shows a password dialog if the backup is encrypted.
  static Future<bool> importData(BuildContext context) async {
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return false;
    try {
      debugPrint("📦 Starting import process...");

      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        withData: kIsWeb, // need bytes on web (no file paths)
      );

      if (picked == null) {
        debugPrint("❌ No file selected");
        return false;
      }

      if (kIsWeb) {
        final bytes = picked.files.single.bytes;
        if (bytes == null) {
          debugPrint("❌ No file bytes on web");
          return false;
        }
        return await _importFromRawBytes(context, bytes, picked.files.single.name);
      }

      final file = File(picked.files.single.path!);
      return await importFromFilePath(context, file.path);
    } catch (e, stackTrace) {
      debugPrint("❌ Import failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return false;
    }
  }

  /// Web-only import: parse backup directly from raw bytes (no filesystem access).
  static Future<bool> importFromBytes(
      BuildContext context, Uint8List rawBytes, String fileName) =>
      _importFromRawBytes(context, rawBytes, fileName);

  static Future<bool> _importFromRawBytes(
      BuildContext context, Uint8List rawBytes, String fileName) async {
    try {
      if (fileName.toLowerCase().endsWith('.json')) {
        // Plain-JSON backups are unencrypted — rejected.
        throw Exception(_unencryptedMsg);
      }

      // BKP-11: an incomplete file is refused before asking for a password.
      _refuseTruncatedBlob(rawBytes);
      final String? password = await _showPasswordDialog(context);
      if (password == null) throw Exception("Restore cancelled: no password");

      List<Map<String, dynamic>> entries;
      if (BackupEncryptionService.isEncryptedBlob(rawBytes)) {
        // New protected backup: decrypt the outer layer first
        final decryptedZip = _openProtectedBlob(rawBytes, password);
        try {
          entries = _decodeZipInIsolate((decryptedZip.toList(), password));
        } catch (e) {
          throw Exception(_innerDecodeMessage(
              e, "Wrong password or corrupted backup entries"));
        }
      } else {
        // Legacy backup: check if plain
        if (_looksLikePlainBackup(rawBytes.toList())) {
          throw Exception(_unencryptedMsg);
        }
        try {
          entries = _decodeZipInIsolate((rawBytes.toList(), password));
        } catch (e) {
          throw Exception(_innerDecodeMessage(e, backupWrongPasswordMessage));
        }
      }

      final decoded = await _decodeEntries(entries, password);
      await _restoreDecodedBackup(decoded.data, images: decoded.images);
      debugPrint("✅ Web import completed!");
      return true;
    } on RestoreFailedException catch (e) {
      debugPrint("❌ Web import failed while writing: $e");
      await promptRestartAfterFailedRestore(e);
      return false;
    } catch (e, st) {
      debugPrint("❌ Web import failed: $e\n$st");
      _showImportError(context, e);
      return false;
    }
  }

  /// ---------------------------
  /// ✅ IMPORT FROM FILE PATH
  /// ---------------------------
  static Future<bool> importFromFilePath(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      debugPrint("📦 Importing from file: $filePath");

      if (!await file.exists()) {
        debugPrint("❌ File does not exist: $filePath");
        return false;
      }

      final extension = p.extension(file.path).toLowerCase();
      debugPrint("📦 File extension: $extension");

      if (extension == '.json') {
        // Plain-JSON backups are unencrypted — rejected.
        throw Exception(_unencryptedMsg);
      }
      // Pass a password dialog as the provider for encrypted backups
      final decoded = await _extractZipBackup(
        file,
        passwordProvider: () => _showPasswordDialog(context),
      );
      await _restoreDecodedBackup(decoded.data, images: decoded.images);

      debugPrint("✅ Import completed successfully!");
      return true;
    } on RestoreFailedException catch (e) {
      debugPrint("❌ Import failed while writing: $e");
      await promptRestartAfterFailedRestore(e);
      return false;
    } catch (e, stackTrace) {
      debugPrint("❌ Import from file path failed: $e");
      debugPrint("Stack trace: $stackTrace");
      _showImportError(context, e);
      return false;
    }
  }

  /// Surfaces the reason an import failed (e.g. unencrypted backup, wrong
  /// password) to the user instead of failing silently. Uses the global
  /// navigator context so it shows even if the caller's context went stale.
  static void _showImportError(BuildContext context, Object e) {
    final ctx = navigatorKey.currentContext ?? context;
    if (!ctx.mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  /// ---------------------------
  /// 🔧 PASSWORD DIALOG FOR RESTORE
  /// ---------------------------
  static Future<String?> _showPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool obscure = true;

    // Use the global navigator context — the caller's context can go stale
    // after the system file-picker round-trip, which would silently skip this
    // prompt (and let an encrypted import appear to "not ask" for a password).
    final dialogContext = navigatorKey.currentContext ?? context;

    return showDialog<String>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AppDialogShell(
          title: 'Encrypted Backup',
          subtitle: 'Enter your backup password to restore',
          accent: AppColors.primary,
          icon: Icons.lock_outline_rounded,
          body: AppTextField(
            controller: controller,
            obscureText: obscure,
            autofocus: true,
            label: 'Backup Password',
            // Backup password is a 6-digit numeric PIN (matches the Set dialog).
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Restore',
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------
  /// 🔧 RESTART AFTER A SUCCESSFUL RESTORE
  /// ---------------------------
  /// A restore rewrites Hive and SharedPreferences (and may switch the business
  /// mode) underneath stores, notifiers and DI that were loaded at startup —
  /// none of which reload. Closing the app is the one way every surface comes
  /// back reading the restored data, so EVERY restore entry point ends here.
  ///
  /// Web cannot `exit`, so it asks the user to reopen the tab instead.
  static Future<void> promptRestartAfterRestore() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    // BKP-9: success is claimed only when nothing was skipped and every
    // post-restore step finished.
    final content = restoreResultContent(
      skipped: lastRestoreSkippedSections,
      postRestoreWarnings: lastRestorePostRestoreWarnings,
      web: kIsWeb,
    );
    await showAppInfoDialog(
      context: ctx,
      title: content.title,
      message: content.message,
      buttonLabel: kIsWeb ? 'OK' : 'Close App',
      accent: content.hasWarnings ? AppColors.warning : AppColors.success,
      icon: content.hasWarnings
          ? Icons.warning_amber_rounded
          : Icons.check_circle_rounded,
    );
    if (!kIsWeb) exit(0);
  }

  /// A restore that failed after it started writing. The app's in-memory
  /// stores no longer match the database either way, so it must restart.
  static Future<void> promptRestartAfterFailedRestore(
      RestoreFailedException failure) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await showAppInfoDialog(
        context: ctx,
        title: 'Restore Failed',
        message: '${failure.userMessage}\n\n'
            '${kIsWeb ? 'Close this tab and open the app again.' : 'The app will now close. Please open it again.'}',
        buttonLabel: kIsWeb ? 'OK' : 'Close App',
        accent: failure.rolledBack ? AppColors.warning : AppColors.danger,
        icon: failure.rolledBack
            ? Icons.restore_rounded
            : Icons.error_outline_rounded,
      );
    }
    if (!kIsWeb) exit(0);
  }

  /// ---------------------------
  /// 🔧 ENSURE A BACKUP PASSWORD EXISTS (prompt to set one if missing)
  /// ---------------------------
  /// Returns true if a backup password is set (or was just set), false if the
  /// user cancelled. Manual export entry points call this before exporting so a
  /// backup is never attempted without encryption.
  static Future<bool> ensureBackupPassword(BuildContext context) async {
    if (await BackupEncryptionService.hasPassword()) return true;
    if (!context.mounted) return false;
    return await _showSetBackupPasswordDialog(context);
  }

  /// Validates a new backup password against its confirmation.
  /// Returns an error message to show the user, or null when the input is valid.
  static String? _validateBackupPassword(String password, String confirm) =>
      BackupEncryptionService.validatePassword(password, confirm);

  /// Prompts the user to set a backup password (with confirmation).
  /// Saves it via BackupEncryptionService and returns true on success.
  static Future<bool> _showSetBackupPasswordDialog(BuildContext context) async {
    final pwdController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.lock_outline, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Set Backup Password')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Backups are encrypted with this password. You will need it '
                  'to restore — it cannot be recovered if lost.'),
              const SizedBox(height: 16),
              AppTextField(
                controller: pwdController,
                obscureText: obscure,
                autofocus: true,
                label: 'Backup Password (6 digits)',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: confirmController,
                obscureText: obscure,
                label: 'Confirm Password',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pwd = pwdController.text.trim();
                final confirm = confirmController.text.trim();
                final err = _validateBackupPassword(pwd, confirm);
                if (err != null) {
                  setState(() => error = err);
                  return;
                }
                await BackupEncryptionService.setPassword(pwd);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Set Password'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// ---------------------------
  /// 🔧 ENSURE BOXES ARE OPENED FOR RESTORE
  /// ---------------------------
  /// Ensures all necessary Hive boxes are opened for the detected mode
  /// If boxes aren't open, initializes them using HiveInit
  static Future<void> _ensureBoxesOpened(String mode) async {
    debugPrint("📦 Ensuring boxes are opened for mode: $mode");

    try {
      // ✅ ALWAYS ensure common boxes are opened first (required for both modes)
      final bool commonBoxesOpen = Hive.isBoxOpen(HiveBoxNames.appConfig) &&
          Hive.isBoxOpen(HiveBoxNames.appState) &&
          Hive.isBoxOpen(HiveBoxNames.storeBox) &&
          Hive.isBoxOpen(HiveBoxNames.businessDetailsBox) &&
          Hive.isBoxOpen(HiveBoxNames.businessTypeBox) &&
          Hive.isBoxOpen(HiveBoxNames.taxBox) &&
          Hive.isBoxOpen(HiveBoxNames.paymentMethods);

      if (!commonBoxesOpen) {
        debugPrint("📦 Common boxes not open yet - opening via HiveInit...");
        // Note: Common adapters are already registered during HiveInit.init()
        await HiveInit.openCommonBoxes();
        debugPrint("✅ Common boxes opened successfully");
      } else {
        debugPrint("📦 Common boxes already open");
      }

      // ✅ Open mode-specific boxes
      if (mode == 'retail') {
        // Check if retail boxes are already open
        final bool boxesAlreadyOpen = Hive.isBoxOpen(HiveBoxNames.products) &&
            Hive.isBoxOpen(HiveBoxNames.variants);

        if (!boxesAlreadyOpen) {
          debugPrint("📦 Retail boxes not open yet - initializing via HiveInit...");
          // Register adapters and open boxes for retail mode
          await HiveInit.registerRetailAdapters();
          await HiveInit.openRetailBoxes();
          debugPrint("✅ Retail boxes initialized successfully");
        } else {
          debugPrint("📦 Retail boxes already open");
        }
      } else if (mode == 'restaurant') {
        // Check if restaurant boxes are already open
        final bool boxesAlreadyOpen = Hive.isBoxOpen(HiveBoxNames.category) &&
            Hive.isBoxOpen(HiveBoxNames.restaurantItems);

        if (!boxesAlreadyOpen) {
          debugPrint("📦 Restaurant boxes not open yet - initializing via HiveInit...");
          // Register adapters and open boxes for restaurant mode
          await HiveInit.registerRestaurantAdapters();
          await HiveInit.openRestaurantBoxes();
          debugPrint("✅ Restaurant boxes initialized successfully");
        } else {
          debugPrint("📦 Restaurant boxes already open");
        }
      }

      debugPrint("✅ All necessary boxes (common + $mode) are ready for restore");
    } catch (e, stackTrace) {
      debugPrint("❌ Error ensuring boxes are open: $e");
      debugPrint("Stack trace: $stackTrace");
      throw Exception("Failed to initialize Hive boxes for restore. Error: $e");
    }
  }

  /// Test seams over the private export/restore steps; no behaviour of their own.
  @visibleForTesting
  static Future<Map<String, dynamic>> collectAllDataForTesting() =>
      _collectAllData();

  @visibleForTesting
  static Future<void> restoreRestaurantDataForTesting(
          Map<String, dynamic> data) =>
      _restoreRestaurantData(data);

  @visibleForTesting
  static Future<void> restoreRetailDataForTesting(Map<String, dynamic> data) =>
      _restoreRetailData(data);

  /// ---------------------------
  /// 🔧 COLLECT ALL DATA (MODE-AWARE)
  /// ---------------------------
  ///
  /// [mode] exports that business type's sections instead of the device's.
  /// The pre-restore snapshot passes the restore's mode, so on an install
  /// whose setup is unfinished (no mode yet) it still covers the staff,
  /// categories, products… the restore is about to replace.
  static Future<Map<String, dynamic>> _collectAllData({String? mode}) async {
    final exportMap = <String, List<Map<String, dynamic>>>{};
    _exportFailures = <String>{};
    final exportMode = mode ?? AppConfig.businessMode.name;
    final isRestaurant = exportMode == BusinessMode.restaurant.name;
    final isRetail = exportMode == BusinessMode.retail.name;

    if (isRestaurant) {
      debugPrint("📦 Collecting RESTAURANT data...");

      // Categories — shared box (restaurant + retail)
      exportMap["categories"] = Hive.box<Category>(HiveBoxNames.category).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Items — imageBytes stripped from JSON (raw pixels = 100+ MB as List<int>).
      // Each item's image is stored separately as item_img_{id} binary in the ZIP.
      exportMap["items"] = Hive.box<Items>("itemBoxs").values.map((e) {
        final map = _deepCleanMap(e.toMap()) as Map<String, dynamic>;
        map.remove('imageBytes');
        return map;
      }).toList();

      // Variants
      exportMap["variants"] = Hive.box<VariantModel>("variante").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Choices
      exportMap["choices"] = Hive.box<ChoicesModel>("choice").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Extras
      exportMap["extras"] = Hive.box<Extramodel>("extra").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Staff — shared box (restaurant + retail)
      exportMap["staffBox"] = Hive.box<StaffModel>(HiveBoxNames.staff).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();

      // Taxes — shared box (restaurant + retail); retail's export of this
      // same box lives below in the `isRetail` branch, under the same key.
      try {
        exportMap["taxes"] = Hive.box<Tax>(HiveBoxNames.tax).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Tax box not found: $e");
        exportMap["taxes"] = [];
        _exportFailures.add("taxes");
      }

      // Expense Categories (using helper - mode aware)
      try {
        final expenseCatBox = Hive.box<ExpenseCategory>(HiveBoxNames.getExpenseCategoryBox(isRetail));
        exportMap["expenseCategories"] = expenseCatBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Expense category box error: $e");
        exportMap["expenseCategories"] = [];
        _exportFailures.add("expenseCategories");
      }

      // Expenses (using helper - mode aware)
      try {
        final expenseBox = Hive.box<Expense>(HiveBoxNames.getExpenseBox(isRetail));
        exportMap["expenses"] = expenseBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Expense box error: $e");
        exportMap["expenses"] = [];
        _exportFailures.add("expenses");
      }

      // Tables
      try {
        exportMap["tables"] = Hive.box<TableModel>("tablesBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Tables box not found: $e");
        exportMap["tables"] = [];
        _exportFailures.add("tables");
      }

      // EOD Reports (using mode-aware box name)
      try {
        final eodBoxName = isRetail ? 'eodBox' : 'restaurant_eodBox';
        final eodBox = Hive.box<EndOfDayReport>(eodBoxName);
        exportMap["eodReports"] = eodBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ EOD box error: $e");
        exportMap["eodReports"] = [];
        _exportFailures.add("eodReports");
      }

      // Current Orders
      try {
        exportMap["orders"] = Hive.box<OrderModel>("orderBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Orders box not found: $e");
        exportMap["orders"] = [];
        _exportFailures.add("orders");
      }

      // ✅ Restaurant Cart
      try {
        exportMap["restaurantCart"] = Hive.box<CartItem>(HiveBoxNames.restaurantCart).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Restaurant Cart exported: ${exportMap["restaurantCart"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Cart box not found: $e");
        exportMap["restaurantCart"] = [];
        _exportFailures.add("restaurantCart");
      }

      // ✅ App Counters
      try {
        final countersBox = Hive.box(HiveBoxNames.appCounters);
        final Map<String, dynamic> countersMap = {};
        for (var key in countersBox.keys) {
          countersMap[key.toString()] = countersBox.get(key);
        }
        exportMap["appCounters"] = [countersMap];
        debugPrint("📦 App Counters exported: ${countersMap.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ App Counters box error: $e");
        exportMap["appCounters"] = [];
        _exportFailures.add("appCounters");
      }

      // ✅ Test Bill Box
      try {
        final box = Hive.box<TestBillModel>(HiveBoxNames.testBillBox);
        exportMap["testBillBox"] = box.values.map((TestBillModel e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Test Bill Box exported: ${exportMap["testBillBox"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Test Bill Box error: $e");
        exportMap["testBillBox"] = [];
        _exportFailures.add("testBillBox");
      }

      // ✅ Shifts
      try {
        exportMap["shifts"] = Hive.box<ShiftModel>(HiveBoxNames.shift)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Shifts exported: ${exportMap["shifts"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Shifts box error: $e");
        exportMap["shifts"] = [];
        _exportFailures.add("shifts");
      }

      // ✅ Cash Movements
      try {
        exportMap["cashMovements"] = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Cash Movements exported: ${exportMap["cashMovements"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Cash Movements box error: $e");
        exportMap["cashMovements"] = [];
        _exportFailures.add("cashMovements");
      }

      // ✅ Cash Handovers
      try {
        exportMap["cashHandovers"] = Hive.box<CashHandoverModel>(HiveBoxNames.restaurantCashHandovers)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Cash Handovers exported: ${exportMap["cashHandovers"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Cash Handovers box error: $e");
        exportMap["cashHandovers"] = [];
        _exportFailures.add("cashHandovers");
      }

      // Customers — shared box (restaurant + retail). Retail's export of this
      // same box (key "customers") lives in the isRetail branch below; this
      // branch needs its own copy since only one of the two branches runs
      // per export.
      try {
        exportMap["customers"] = Hive.box<Customer>(HiveBoxNames.customer)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Customers exported: ${exportMap["customers"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Customers box error: $e");
        exportMap["customers"] = [];
        _exportFailures.add("customers");
      }

      // Past Orders — regular Box, all values in memory, no async reads needed
      try {
        final pastOrderBox = Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
        final pastOrdersList = <Map<String, dynamic>>[];
        for (final order in pastOrderBox.values) {
          try {
            pastOrdersList.add(_deepCleanMap(order.toMap()) as Map<String, dynamic>);
          } catch (e) {
            debugPrint("⚠️ Error converting order ${order.id}: $e");
          }
        }
        exportMap["pastOrders"] = pastOrdersList;
        debugPrint("📦 Past Orders exported: ${pastOrdersList.length}");
      } catch (e) {
        debugPrint("❌ Error exporting past orders: $e");
        exportMap["pastOrders"] = [];
        _exportFailures.add("pastOrders");
      }

      // Saved Printers (thermal printer configs — WiFi/BT)
      try {
        exportMap["printers"] = Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Printers exported: ${exportMap["printers"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Printers box error: $e");
        exportMap["printers"] = [];
        _exportFailures.add("printers");
      }

      // Restaurant Sessions
      try {
        exportMap["restaurantSessions"] = Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Sessions exported: ${exportMap["restaurantSessions"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Sessions box error: $e");
        exportMap["restaurantSessions"] = [];
        _exportFailures.add("restaurantSessions");
      }

      // Day Management (current session id, opening balance, day-started flag).
      // Same key as the retail branch; without it a restored restaurant kept
      // this device's day state pointing at sessions the backup replaced.
      try {
        final dayMgmtBox = Hive.box(HiveBoxNames.dayManagementBox);
        final Map<String, dynamic> dayMgmtMap = {};
        for (var key in dayMgmtBox.keys) {
          dayMgmtMap[key.toString()] = dayMgmtBox.get(key);
        }
        exportMap["dayManagement"] = [dayMgmtMap];
        debugPrint("📦 Day Management exported: ${dayMgmtMap.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ Day Management box error: $e");
        exportMap["dayManagement"] = [];
        _exportFailures.add("dayManagement");
      }

      // Item cancellations — the audit trail behind the Item Cancellation Report.
      try {
        exportMap["itemCancellations"] = Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Item cancellations exported: ${exportMap["itemCancellations"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Item cancellations box error: $e");
        exportMap["itemCancellations"] = [];
        _exportFailures.add("itemCancellations");
      }

      // Restaurant Attendance
      try {
        exportMap["restaurantAttendance"] = Hive.box<AttendanceModel>(HiveBoxNames.attendance)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Attendance exported: ${exportMap["restaurantAttendance"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attendance box error: $e");
        exportMap["restaurantAttendance"] = [];
        _exportFailures.add("restaurantAttendance");
      }

      // Recipes (BOM) & Recipe Productions — inventory/recipe management
      try {
        exportMap["recipes"] = Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Recipes exported: ${exportMap["recipes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Recipes box error: $e");
        exportMap["recipes"] = [];
        _exportFailures.add("recipes");
      }

      try {
        exportMap["recipeProductions"] = Hive.box<RecipeProductionModel>(HiveBoxNames.restaurantRecipeProductions).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Recipe Productions exported: ${exportMap["recipeProductions"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Recipe Productions box error: $e");
        exportMap["recipeProductions"] = [];
        _exportFailures.add("recipeProductions");
      }

      // Stock movement audit trail (sales, production, voids, GRN, adjustments).
      // Shared box with retail. On a read error the key is left out rather
      // than exported empty, so restoring that backup keeps the device's rows.
      try {
        exportMap["stockMovements"] =
            Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
                .values
                .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
                .toList();
        debugPrint("📦 Stock movements exported: ${exportMap["stockMovements"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Stock movements box error: $e");
      }

      // Restaurant Suppliers, Purchase Orders & GRNs
      try {
        exportMap["restaurantSuppliers"] = Hive.box<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Suppliers exported: ${exportMap["restaurantSuppliers"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Suppliers box error: $e");
        exportMap["restaurantSuppliers"] = [];
        _exportFailures.add("restaurantSuppliers");
      }

      try {
        exportMap["restaurantPurchaseOrders"] = Hive.box<RestaurantPurchaseOrderModel>(HiveBoxNames.restaurantPurchaseOrders).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Orders exported: ${exportMap["restaurantPurchaseOrders"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Orders box error: $e");
        exportMap["restaurantPurchaseOrders"] = [];
        _exportFailures.add("restaurantPurchaseOrders");
      }

      try {
        exportMap["restaurantPurchaseOrderItems"] = Hive.box<RestaurantPurchaseOrderItemModel>(HiveBoxNames.restaurantPurchaseOrderItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Order Items exported: ${exportMap["restaurantPurchaseOrderItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Order Items box error: $e");
        exportMap["restaurantPurchaseOrderItems"] = [];
        _exportFailures.add("restaurantPurchaseOrderItems");
      }

      try {
        exportMap["restaurantGrns"] = Hive.box<RestaurantGRNModel>(HiveBoxNames.restaurantGrns).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant GRNs exported: ${exportMap["restaurantGrns"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant GRNs box error: $e");
        exportMap["restaurantGrns"] = [];
        _exportFailures.add("restaurantGrns");
      }

      try {
        exportMap["restaurantGrnItems"] = Hive.box<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant GRN Items exported: ${exportMap["restaurantGrnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant GRN Items box error: $e");
        exportMap["restaurantGrnItems"] = [];
        _exportFailures.add("restaurantGrnItems");
      }

      // Supplier balance journal — must travel with the suppliers themselves,
      // or a restored balance has nothing explaining how it got there.
      try {
        exportMap["restaurantSupplierLedger"] = Hive.box<RestaurantSupplierLedgerEntryModel>(HiveBoxNames.restaurantSupplierLedger).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Supplier Ledger exported: ${exportMap["restaurantSupplierLedger"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Supplier Ledger box error: $e");
        exportMap["restaurantSupplierLedger"] = [];
        _exportFailures.add("restaurantSupplierLedger");
      }

      // Damaged-goods / loss / stock-take chain (typeIds 143-149). These were
      // missing from backup entirely: a restore brought back supplier balances
      // while destroying the return/claim documents that justified crediting
      // them down.
      try {
        exportMap["restaurantPurchaseReturns"] = Hive.box<RestaurantPurchaseReturnModel>(HiveBoxNames.restaurantPurchaseReturns).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Returns exported: ${exportMap["restaurantPurchaseReturns"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Returns box error: $e");
        exportMap["restaurantPurchaseReturns"] = [];
        _exportFailures.add("restaurantPurchaseReturns");
      }

      try {
        exportMap["restaurantPurchaseReturnItems"] = Hive.box<RestaurantPurchaseReturnItemModel>(HiveBoxNames.restaurantPurchaseReturnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Return Items exported: ${exportMap["restaurantPurchaseReturnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Return Items box error: $e");
        exportMap["restaurantPurchaseReturnItems"] = [];
        _exportFailures.add("restaurantPurchaseReturnItems");
      }

      try {
        exportMap["restaurantSupplierClaims"] = Hive.box<RestaurantSupplierClaimModel>(HiveBoxNames.restaurantSupplierClaims).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Supplier Claims exported: ${exportMap["restaurantSupplierClaims"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Supplier Claims box error: $e");
        exportMap["restaurantSupplierClaims"] = [];
        _exportFailures.add("restaurantSupplierClaims");
      }

      try {
        exportMap["restaurantSupplierClaimItems"] = Hive.box<RestaurantSupplierClaimItemModel>(HiveBoxNames.restaurantSupplierClaimItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Supplier Claim Items exported: ${exportMap["restaurantSupplierClaimItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Supplier Claim Items box error: $e");
        exportMap["restaurantSupplierClaimItems"] = [];
        _exportFailures.add("restaurantSupplierClaimItems");
      }

      try {
        exportMap["restaurantInventoryLosses"] = Hive.box<RestaurantInventoryLossModel>(HiveBoxNames.restaurantInventoryLosses).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Inventory Losses exported: ${exportMap["restaurantInventoryLosses"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Inventory Losses box error: $e");
        exportMap["restaurantInventoryLosses"] = [];
        _exportFailures.add("restaurantInventoryLosses");
      }

      try {
        exportMap["restaurantStockTakes"] = Hive.box<RestaurantStockTakeModel>(HiveBoxNames.restaurantStockTakes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Stock Takes exported: ${exportMap["restaurantStockTakes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Stock Takes box error: $e");
        exportMap["restaurantStockTakes"] = [];
        _exportFailures.add("restaurantStockTakes");
      }

      try {
        exportMap["restaurantStockTakeItems"] = Hive.box<RestaurantStockTakeItemModel>(HiveBoxNames.restaurantStockTakeItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Stock Take Items exported: ${exportMap["restaurantStockTakeItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Stock Take Items box error: $e");
        exportMap["restaurantStockTakeItems"] = [];
        _exportFailures.add("restaurantStockTakeItems");
      }

    } else if (isRetail) {
      debugPrint("📦 Collecting RETAIL data...");

      // Products
      try {
        exportMap["products"] = Hive.box<ProductModel>(HiveBoxNames.products).values.map((e) => e.toProduct()).toList();
      } catch (e) {
        debugPrint("⚠️ Products box error: $e");
        exportMap["products"] = [];
        _exportFailures.add("products");
      }

      // Variants
      try {
        exportMap["variants"] = Hive.box<VarianteModel>(HiveBoxNames.variants).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Variants box error: $e");
        exportMap["variants"] = [];
        _exportFailures.add("variants");
      }

      // App Counters -- retail needs these as much as restaurant does.
      //
      // Holds `lastSkuSequence`, `lastBarcodeSequence` and the per-day PO/GRN
      // counters. Without it a restored device restarts every sequence at zero
      // and re-issues SKUs, barcodes and document numbers already in use.
      // Mirrors the restaurant export.
      try {
        final countersBox = Hive.box(HiveBoxNames.appCounters);
        final Map<String, dynamic> countersMap = {};
        for (var key in countersBox.keys) {
          countersMap[key.toString()] = countersBox.get(key);
        }
        exportMap["appCounters"] = [countersMap];
        debugPrint("App Counters exported: ${countersMap.keys.length} entries");
      } catch (e) {
        debugPrint("App Counters box error: $e");
        exportMap["appCounters"] = [];
        _exportFailures.add("appCounters");
      }

      // Sales
      try {
        exportMap["sales"] = Hive.box<SaleModel>(HiveBoxNames.sales).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Sales box error: $e");
        exportMap["sales"] = [];
        _exportFailures.add("sales");
      }

      // Sale Items
      try {
        exportMap["saleItems"] = Hive.box<SaleItemModel>(HiveBoxNames.saleItems).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Sale Items box error: $e");
        exportMap["saleItems"] = [];
        _exportFailures.add("saleItems");
      }

      // Customers — shared box (restaurant + retail)
      try {
        exportMap["customers"] = Hive.box<Customer>(HiveBoxNames.customer).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Customers box error: $e");
        exportMap["customers"] = [];
        _exportFailures.add("customers");
      }

      // Suppliers
      try {
        exportMap["suppliers"] = Hive.box<SupplierModel>(HiveBoxNames.suppliers).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Suppliers box error: $e");
        exportMap["suppliers"] = [];
        _exportFailures.add("suppliers");
      }

      // Supplier balance journal — the history behind each currentBalance.
      try {
        exportMap["supplierLedger"] = Hive.box<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Supplier ledger box error: $e");
        exportMap["supplierLedger"] = [];
        _exportFailures.add("supplierLedger");
      }

      // Purchases/purchaseItems intentionally absent — the standalone Purchase
      // feature was removed; goods now arrive through Purchase Orders + GRN.
      // Older backups may still carry those keys; they're simply ignored.

      // Damaged-goods workflow raised from GRNs.
      try {
        exportMap["purchaseReturns"] =
            Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns)
                .values
                .map((e) => e.toMap())
                .toList();
        exportMap["purchaseReturnItems"] =
            Hive.box<PurchaseReturnItemModel>(HiveBoxNames.purchaseReturnItems)
                .values
                .map((e) => e.toMap())
                .toList();
        exportMap["supplierClaims"] =
            Hive.box<SupplierClaimModel>(HiveBoxNames.supplierClaims)
                .values
                .map((e) => e.toMap())
                .toList();
        exportMap["supplierClaimItems"] =
            Hive.box<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems)
                .values
                .map((e) => e.toMap())
                .toList();
        exportMap["inventoryLosses"] =
            Hive.box<InventoryLossModel>(HiveBoxNames.inventoryLosses)
                .values
                .map((e) => e.toMap())
                .toList();
      } catch (e) {
        debugPrint("⚠️ Damaged-goods boxes error: $e");
        exportMap["purchaseReturns"] = [];
        _exportFailures.add("purchaseReturns");
        exportMap["purchaseReturnItems"] = [];
        _exportFailures.add("purchaseReturnItems");
        exportMap["supplierClaims"] = [];
        _exportFailures.add("supplierClaims");
        exportMap["supplierClaimItems"] = [];
        _exportFailures.add("supplierClaimItems");
        exportMap["inventoryLosses"] = [];
        _exportFailures.add("inventoryLosses");
      }

      // Manual stock adjustments. The audit trail for the one stock movement
      // with no document behind it, so it has to survive a restore — without
      // it a restored shop cannot explain its own stock levels.
      try {
        exportMap["stockMovements"] =
            Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
                .values
                .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
                .toList();
      } catch (e) {
        debugPrint("⚠️ Stock movements box error: $e");
        exportMap["stockMovements"] = [];
        _exportFailures.add("stockMovements");
      }

      // Cash drawer movements — Cash In / Cash Out, opening float and the EOD
      // safe drop. Same shared box and key as the restaurant branch; without
      // it a restored retail shop lost its drawer history.
      try {
        exportMap["cashMovements"] =
            Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
                .values
                .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
                .toList();
      } catch (e) {
        debugPrint("⚠️ Cash movements box error: $e");
        exportMap["cashMovements"] = [];
        _exportFailures.add("cashMovements");
      }

      // Physical stock counts. The completed ones justify the adjustments in
      // the movement log, so they travel together or the trail loses its
      // paperwork.
      try {
        exportMap["stockTakes"] =
            Hive.box<StockTakeModel>(HiveBoxNames.stockTakes)
                .values
                .map((e) => e.toMap())
                .toList();
        exportMap["stockTakeItems"] =
            Hive.box<StockTakeItemModel>(HiveBoxNames.stockTakeItems)
                .values
                .map((e) => e.toMap())
                .toList();
      } catch (e) {
        debugPrint("⚠️ Stock take boxes error: $e");
        exportMap["stockTakes"] = [];
        _exportFailures.add("stockTakes");
        exportMap["stockTakeItems"] = [];
        _exportFailures.add("stockTakeItems");
      }

      // Categories (String list)
      try {
        final catBox = Hive.box<String>(HiveBoxNames.retailCategories);
        exportMap["categories"] = catBox.values.map((c) => {'name': c}).toList();
      } catch (e) {
        debugPrint("⚠️ Retail Categories box error: $e");
        exportMap["categories"] = [];
        _exportFailures.add("categories");
      }

      // ✅ Cart Items
      try {
        exportMap["cartItems"] = Hive.box<CartItemModel>(HiveBoxNames.cartItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Cart Items exported: ${exportMap["cartItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Cart Items box error: $e");
        exportMap["cartItems"] = [];
        _exportFailures.add("cartItems");
      }

      // ✅ NEW: Add EOD Reports for Retail
      try {
        final eodBoxName = isRetail ? 'eodBox' : 'restaurant_eodBox';
        final eodBox = Hive.box<EndOfDayReport>(eodBoxName);
        exportMap["eodReports"] = eodBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail EOD Reports exported: ${exportMap["eodReports"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail EOD box error: $e");
        exportMap["eodReports"] = [];
        _exportFailures.add("eodReports");
      }

      // ✅ NEW: Add Expense Categories for Retail
      try {
        final expenseCatBox = Hive.box<ExpenseCategory>(HiveBoxNames.getExpenseCategoryBox(isRetail));
        exportMap["expenseCategories"] = expenseCatBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Expense Categories exported: ${exportMap["expenseCategories"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Expense category box error: $e");
        exportMap["expenseCategories"] = [];
        _exportFailures.add("expenseCategories");
      }

      // ✅ NEW: Add Expenses for Retail
      try {
        final expenseBox = Hive.box<Expense>(HiveBoxNames.getExpenseBox(isRetail));
        exportMap["expenses"] = expenseBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Expenses exported: ${exportMap["expenses"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Expense box error: $e");
        exportMap["expenses"] = [];
        _exportFailures.add("expenses");
      }

      // ✅ Hold Sales & Hold Sale Items
      try {
        exportMap["holdSales"] = Hive.box<HoldSaleModel>(HiveBoxNames.holdSales).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Hold Sales exported: ${exportMap["holdSales"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Hold Sales box error: $e");
        exportMap["holdSales"] = [];
        _exportFailures.add("holdSales");
      }

      try {
        exportMap["holdSaleItems"] = Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Hold Sale Items exported: ${exportMap["holdSaleItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Hold Sale Items box error: $e");
        exportMap["holdSaleItems"] = [];
        _exportFailures.add("holdSaleItems");
      }

      // ✅ Purchase Orders & Purchase Order Items
      try {
        exportMap["purchaseOrders"] = Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Purchase Orders exported: ${exportMap["purchaseOrders"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Purchase Orders box error: $e");
        exportMap["purchaseOrders"] = [];
        _exportFailures.add("purchaseOrders");
      }

      try {
        exportMap["purchaseOrderItems"] = Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Purchase Order Items exported: ${exportMap["purchaseOrderItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Purchase Order Items box error: $e");
        exportMap["purchaseOrderItems"] = [];
        _exportFailures.add("purchaseOrderItems");
      }

      // ✅ GRNs & GRN Items
      try {
        exportMap["grns"] = Hive.box<GRNModel>(HiveBoxNames.grns).values.map((e) => e.toMap()).toList();
        debugPrint("📦 GRNs exported: ${exportMap["grns"]!.length}");
      } catch (e) {
        debugPrint("⚠️ GRNs box error: $e");
        exportMap["grns"] = [];
        _exportFailures.add("grns");
      }

      try {
        exportMap["grnItems"] = Hive.box<GRNItemModel>(HiveBoxNames.grnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 GRN Items exported: ${exportMap["grnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ GRN Items box error: $e");
        exportMap["grnItems"] = [];
        _exportFailures.add("grnItems");
      }

      // ✅ Bundles & Kit Assemblies (bundle/repack inventory)
      try {
        exportMap["bundles"] = Hive.box<RetailBundleModel>(HiveBoxNames.bundles).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Bundles exported: ${exportMap["bundles"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Bundles box error: $e");
        exportMap["bundles"] = [];
        _exportFailures.add("bundles");
      }

      try {
        exportMap["kitAssemblies"] = Hive.box<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Kit Assemblies exported: ${exportMap["kitAssemblies"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Kit Assemblies box error: $e");
        exportMap["kitAssemblies"] = [];
        _exportFailures.add("kitAssemblies");
      }

      // ✅ Categories — shared box (restaurant + retail). Restaurant's export
      // of this same box (key "categories") lives in the isRestaurant branch
      // above; this branch needs its own copy since only one of the two
      // branches runs per export.
      try {
        exportMap["categories"] = Hive.box<Category>(HiveBoxNames.category).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Categories exported: ${exportMap["categories"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Categories box error: $e");
        exportMap["categories"] = [];
        _exportFailures.add("categories");
      }

      // ✅ Payment Entries
      try {
        exportMap["paymentEntries"] = Hive.box<PaymentEntryModel>(HiveBoxNames.paymentEntries).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Payment Entries exported: ${exportMap["paymentEntries"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Payment Entries box error: $e");
        exportMap["paymentEntries"] = [];
        _exportFailures.add("paymentEntries");
      }

      // ✅ Credit Payments
      try {
        exportMap["creditPayments"] = Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Credit Payments exported: ${exportMap["creditPayments"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Credit Payments box error: $e");
        exportMap["creditPayments"] = [];
        _exportFailures.add("creditPayments");
      }

      // ✅ Attributes, Attribute Values, Product Attributes
      try {
        exportMap["attributes"] = Hive.box<AttributeModel>(HiveBoxNames.attributes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Attributes exported: ${exportMap["attributes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attributes box error: $e");
        exportMap["attributes"] = [];
        _exportFailures.add("attributes");
      }

      try {
        exportMap["attributeValues"] = Hive.box<AttributeValueModel>(HiveBoxNames.attributeValues).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Attribute Values exported: ${exportMap["attributeValues"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attribute Values box error: $e");
        exportMap["attributeValues"] = [];
        _exportFailures.add("attributeValues");
      }

      try {
        exportMap["productAttributes"] = Hive.box<ProductAttributeModel>(HiveBoxNames.productAttributes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Product Attributes exported: ${exportMap["productAttributes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Product Attributes box error: $e");
        exportMap["productAttributes"] = [];
        _exportFailures.add("productAttributes");
      }

      // Staff — shared box (restaurant + retail). Restaurant's export of this
      // same box lives above in the `isRestaurant` branch, under the same key;
      // this branch needs its own copy since only one of these two branches
      // runs per export.
      try {
        exportMap["staffBox"] = Hive.box<StaffModel>(HiveBoxNames.staff).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Staff exported: ${exportMap["staffBox"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Staff box error: $e");
        exportMap["staffBox"] = [];
        _exportFailures.add("staffBox");
      }

      // Shifts — shared box (restaurant + retail), same reasoning as Staff
      // above: export is mode-gated, so dropping this branch would mean a
      // retail backup silently carried zero shifts. Same key as restaurant's.
      try {
        exportMap["shifts"] = Hive.box<ShiftModel>(HiveBoxNames.shift)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Shifts exported: ${exportMap["shifts"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Shifts box error: $e");
        exportMap["shifts"] = [];
        _exportFailures.add("shifts");
      }

      // Attendance — shared box, same reasoning. The key stays
      // "restaurantAttendance" so a restore never has to guess which of two
      // names a backup used based on its origin mode.
      try {
        exportMap["restaurantAttendance"] =
            Hive.box<AttendanceModel>(HiveBoxNames.attendance)
                .values
                .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
                .toList();
        debugPrint(
            "📦 Attendance exported: ${exportMap["restaurantAttendance"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attendance box error: $e");
        exportMap["restaurantAttendance"] = [];
        _exportFailures.add("restaurantAttendance");
      }

      // Tax — shared box (restaurant + retail), same reasoning as Staff above.
      try {
        exportMap["taxes"] = Hive.box<Tax>(HiveBoxNames.tax).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Taxes exported: ${exportMap["taxes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Tax box error: $e");
        exportMap["taxes"] = [];
        _exportFailures.add("taxes");
      }

      // ✅ Billing Tabs
      try {
        exportMap["billingTabs"] = Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Billing Tabs exported: ${exportMap["billingTabs"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Billing Tabs box error: $e");
        exportMap["billingTabs"] = [];
        _exportFailures.add("billingTabs");
      }

      // ✅ Day Management Box (opening balance)
      try {
        final dayMgmtBox = Hive.box(HiveBoxNames.dayManagementBox);
        final Map<String, dynamic> dayMgmtMap = {};
        for (var key in dayMgmtBox.keys) {
          dayMgmtMap[key.toString()] = dayMgmtBox.get(key);
        }
        exportMap["dayManagement"] = [dayMgmtMap];
        debugPrint("📦 Day Management exported: ${dayMgmtMap.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ Day Management box error: $e");
        exportMap["dayManagement"] = [];
        _exportFailures.add("dayManagement");
      }

      // Day sessions — retail's DayManagementService keeps its sessions in this
      // shared box, and dayManagement above points into it by session id.
      try {
        exportMap["restaurantSessions"] = Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Sessions exported: ${exportMap["restaurantSessions"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Sessions box error: $e");
        exportMap["restaurantSessions"] = [];
        _exportFailures.add("restaurantSessions");
      }

      // Saved printers — shared box, also written by retail's printer setup.
      try {
        exportMap["printers"] = Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Printers exported: ${exportMap["printers"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Printers box error: $e");
        exportMap["printers"] = [];
        _exportFailures.add("printers");
      }

      // Admin credential is a SharedPreferences value now (retail_admin_username/
      // retail_admin_password), not a Hive box — it's already covered by the
      // generic localPrefs export below, no explicit handling needed here.
    }

    // ==================== COMMON BOXES (both retail and restaurant) ====================

    // ✅ App Config Box (CRITICAL - stores business mode and setup completion status)
    try {
      final appConfigBox = Hive.box(HiveBoxNames.appConfig);
      final Map<String, dynamic> appConfigMap = {};
      for (var key in appConfigBox.keys) {
        appConfigMap[key.toString()] = appConfigBox.get(key);
      }
      exportMap["appConfig"] = [appConfigMap];
      debugPrint("📦 App config exported: ${appConfigMap.keys.length} entries");
    } catch (e) {
      debugPrint("⚠️ App config box error: $e");
      exportMap["appConfig"] = [];
      _exportFailures.add("appConfig");
    }

    // App State
    try {
      final appStateBox = Hive.box("app_state");
      final Map<String, dynamic> appStateMap = {};
      for (var key in appStateBox.keys) {
        appStateMap[key.toString()] = appStateBox.get(key);
      }
      exportMap["appState"] = [appStateMap];
      debugPrint("📦 App state exported: ${appStateMap.keys.length} settings");
    } catch (e) {
      debugPrint("⚠️ App state box error: $e");
      exportMap["appState"] = [];
      _exportFailures.add("appState");
    }

    // Store Box (legacy store info)
    try {
      final storeBox = Hive.box(HiveBoxNames.storeBox);
      final Map<String, dynamic> storeMap = {};
      for (var key in storeBox.keys) {
        storeMap[key.toString()] = storeBox.get(key);
      }
      exportMap["storeBox"] = [storeMap];
      debugPrint("📦 Store box exported: ${storeMap.keys.length} entries");
    } catch (e) {
      debugPrint("⚠️ Store box error: $e");
      exportMap["storeBox"] = [];
      _exportFailures.add("storeBox");
    }

    // Business Details Box
    try {
      final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
      exportMap["businessDetails"] = businessDetailsBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Business details exported: ${exportMap["businessDetails"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Business details box error: $e");
      exportMap["businessDetails"] = [];
      _exportFailures.add("businessDetails");
    }

    // Business Type Box
    try {
      final businessTypeBox = Hive.box<BusinessType>(HiveBoxNames.businessTypeBox);
      exportMap["businessTypes"] = businessTypeBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Business types exported: ${exportMap["businessTypes"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Business type box error: $e");
      exportMap["businessTypes"] = [];
      _exportFailures.add("businessTypes");
    }

    // Tax Details Box
    try {
      final taxBox = Hive.box<TaxDetails>(HiveBoxNames.taxBox);
      exportMap["taxDetails"] = taxBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Tax details exported: ${exportMap["taxDetails"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Tax details box error: $e");
      exportMap["taxDetails"] = [];
      _exportFailures.add("taxDetails");
    }

    // Payment Methods Box (shared)
    try {
      final paymentMethodsBox = Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods);
      exportMap["paymentMethods"] = paymentMethodsBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Payment methods exported: ${exportMap["paymentMethods"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Payment methods box error: $e");
      exportMap["paymentMethods"] = [];
      _exportFailures.add("paymentMethods");
    }

    // ✅ Non-Hive settings: SharedPreferences (admin PIN, store/UPI, currency,
    // toggles, print settings…) minus the device-bound denylist, each tagged
    // with its type so the JSON round-trip restores int vs double correctly.
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPrefs = <Map<String, dynamic>>[];
      for (final key in prefs.getKeys()) {
        if (_prefsDenylist.contains(key)) continue;
        final value = prefs.get(key);
        if (value == null) continue;
        final String type = value is bool
            ? 'bool'
            : value is int
                ? 'int'
                : value is double
                    ? 'double'
                    : value is List
                        ? 'stringList'
                        : 'string';
        localPrefs.add({'key': key, 'type': type, 'value': value});
      }
      exportMap["localPrefs"] = localPrefs;
      debugPrint("📦 Local prefs exported: ${localPrefs.length}");
    } catch (e) {
      debugPrint("⚠️ Local prefs export error: $e");
      exportMap["localPrefs"] = [];
      _exportFailures.add("localPrefs");
    }

    // ✅ Backup password (flutter_secure_storage) so a restored device keeps it.
    try {
      final pwd = await BackupEncryptionService.getStoredPassword();
      exportMap["secureCreds"] =
          (pwd != null && pwd.isNotEmpty) ? [{'backupPassword': pwd}] : [];
    } catch (e) {
      debugPrint("⚠️ Secure creds export error: $e");
      exportMap["secureCreds"] = [];
      _exportFailures.add("secureCreds");
    }

    debugPrint("📦 Total items exported: ${exportMap.values.fold(0, (sum, list) => sum + list.length)}");

    return {
      'version': '2.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'appMode': AppConfig.businessMode.name,
      'data': exportMap,
    };
  }

  /// ---------------------------
  /// 🔧 CREATE ZIP BACKUP
  /// ---------------------------
  static Future<String?> _createZipBackup(
      Map<String, dynamic> data, {
        bool saveToDownloads = false,
        String? customPath,
        bool includeImages = true,
      }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/temp_backup');
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

      // 1️⃣ Serialize data to JSON string (CPU-heavy — runs off main thread)
      final jsonString = await compute(_jsonEncodeMap, data);

      // 2️⃣ Encryption is mandatory — a backup password MUST be set.
      // We never write plaintext: no password ⇒ no backup.
      final password = await BackupEncryptionService.getStoredPassword();
      if (password == null || password.isEmpty) {
        throw Exception(
            'No backup password set — refusing to write an unencrypted backup');
      }
      const isEncrypted = true;

      // 3️⃣ Build archive entries. Encrypt data.json's content using BackupEncryptionService.
      final encryptedDataMap = BackupEncryptionService.encryptData(jsonString, password);
      final encryptedJsonString = jsonEncode(encryptedDataMap);

      final entries = <Map<String, dynamic>>[];
      entries.add({'name': 'data.json', 'bytes': utf8.encode(encryptedJsonString)});

      // 4️⃣ Add item images as named binary entries (item_img_{id})
      // Always included — stored as efficient binary, NOT as JSON integers.
      if (AppConfig.isRestaurant) {
        try {
          final itemBox = Hive.box<Items>("itemBoxs");
          int imgCount = 0;
          for (final item in itemBox.values) {
            if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
              entries.add({'name': 'item_img_${item.id}', 'bytes': item.imageBytes!.toList()});
              imgCount++;
            }
          }
          if (imgCount > 0) debugPrint("📦 Added $imgCount item images to ZIP");
        } catch (e) {
          debugPrint("⚠️ Could not add item images: $e");
        }
      }

      // 4b️⃣ Also include product_images folder (manual backup only)
      if (includeImages) {
        final productDir = Directory('${appDir.path}/product_images');
        final imageFiles = productDir.existsSync()
            ? productDir.listSync().whereType<File>().toList()
            : <File>[];

        for (final img in imageFiles) {
          entries.add({'name': 'prod_img_${p.basename(img.path)}', 'bytes': await img.readAsBytes()});
        }
        if (imageFiles.isNotEmpty) {
          debugPrint("📦 Added ${imageFiles.length} product folder images to ZIP");
        }
      }

      // What the verified file must hold, fixed before anything can change it.
      final expectedEntries = entries.length;
      beforeArchiveForTesting?.call(entries);

      // 5️⃣ Encode a password-protected (AES) ZIP in a background isolate.
      final zipData = await compute(_encodeArchiveInIsolate, (entries, password));

      if (zipData == null || zipData.isEmpty) {
        throw Exception("ZIP creation failed");
      }

      // Safety net: never persist a backup whose data can be read without the
      // password (i.e. if ZIP encryption silently failed).
      if (_looksLikePlainBackup(zipData)) {
        throw Exception(
            'Backup encryption failed — refusing to write a readable file');
      }

      // 5b️⃣ Encrypt the entire ZIP bytes to fully protect the zip file (header & filenames)
      final protectedZipData = BackupEncryptionService.encryptBytes(zipData, password);

      debugPrint("📦 ZIP created: ${zipData.length} bytes. Protected ZIP blob: ${protectedZipData.length} bytes");

      // 6️⃣ Save ZIP to destination
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final suffix = isEncrypted ? 'encrypted' : 'backup';
      final fileName = 'BillBerryLite_${suffix}_$timestamp.zip';

      File outputFile;

      if (saveToDownloads) {
        final downloadsPath = await downloadsBackupPath();
        final downloadsDir = Directory(downloadsPath);
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }
        outputFile = File('$downloadsPath/$fileName');
      } else if (customPath != null) {
        outputFile = File('$customPath/$fileName');
      } else {
        throw Exception("No save location specified");
      }

      // BKP-11: never trust the write. The file only gets its final name once
      // it has been read back and opened exactly as a restore would.
      await _writeVerifiedBackup(outputFile, protectedZipData, password,
          expectedJson: jsonString, expectedEntries: expectedEntries);

      debugPrint("✅ Backup saved and verified: ${outputFile.path}");
      debugPrint("✅ Encrypted: $isEncrypted");

      return outputFile.path;
    } catch (e, stackTrace) {
      if (e is BackupVerificationException) lastExportError = e.message;
      debugPrint("❌ ZIP backup creation failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// Test hook: sees the archive entries just before they are zipped, so a
  /// test can make the encoder's output differ from the data (null in
  /// production).
  @visibleForTesting
  static void Function(List<Map<String, dynamic>> entries)?
      beforeArchiveForTesting;

  /// Test hook: runs on the temporary file right after it is written, before
  /// it is read back (to truncate or corrupt it).
  @visibleForTesting
  static Future<void> Function(File written)? afterBackupWriteForTesting;

  /// Suffix of the temporary file a backup is written to before verifying.
  static const String _partSuffix = '.part';

  /// BKP-11: writes [bytes] to `<target>.part`, reads the file back, checks
  /// it byte for byte, opens it with [password] the way a restore does and
  /// compares its data, and only then renames it to [target]. On any failure
  /// the temporary file is deleted (no unverified backup is ever left with a
  /// backup's name) and a [BackupVerificationException] is thrown.
  static Future<void> _writeVerifiedBackup(
    File target,
    Uint8List bytes,
    String password, {
    required String expectedJson,
    required int expectedEntries,
  }) async {
    _deleteStalePartFiles(target.parent);
    final part = File('${target.path}$_partSuffix');
    try {
      await part.writeAsBytes(bytes, flush: true);
      await afterBackupWriteForTesting?.call(part);

      final readBack = await part.readAsBytes();
      if (readBack.length != bytes.length) {
        throw BackupVerificationException(
            'only ${readBack.length} of ${bytes.length} bytes were saved');
      }
      for (var i = 0; i < bytes.length; i++) {
        if (readBack[i] != bytes[i]) {
          throw const BackupVerificationException(
              'the saved file differs from what was written');
        }
      }
      final zip = BackupEncryptionService.decryptBytes(readBack, password);
      if (zip == null) {
        throw const BackupVerificationException('it could not be decrypted');
      }
      final List<Map<String, dynamic>> files;
      try {
        files = await compute(_decodeZipInIsolate, (zip.toList(), password));
      } catch (_) {
        throw const BackupVerificationException('its contents could not be read');
      }
      if (files.length != expectedEntries) {
        throw BackupVerificationException(
            'it holds ${files.length} of $expectedEntries entries');
      }
      final decoded = await _decodeEntries(files, password);
      if (jsonEncode(decoded.data) != expectedJson) {
        throw const BackupVerificationException(
            'its data does not match what was saved');
      }

      await part.rename(target.path);
    } catch (e) {
      try {
        if (part.existsSync()) part.deleteSync();
      } catch (_) {}
      if (e is BackupVerificationException) rethrow;
      throw BackupVerificationException('$e');
    }
  }

  /// Removes `BillBerryLite_*.zip.part` files an interrupted earlier backup
  /// left in [dir]. Best effort.
  static void _deleteStalePartFiles(Directory dir) {
    try {
      if (!dir.existsSync()) return;
      for (final f in dir.listSync().whereType<File>()) {
        final name = p.basename(f.path);
        if (name.startsWith('BillBerryLite_') &&
            name.endsWith('.zip$_partSuffix')) {
          f.deleteSync();
        }
      }
    } catch (e) {
      debugPrint("⚠️ Could not remove old temporary backup files: $e");
    }
  }

  /// Test hook: writes a backup of this device's data into [dir] through the
  /// real export path; returns its path, or null when it was not saved.
  @visibleForTesting
  static Future<String?> createBackupFileForTesting(Directory dir) async {
    lastExportError = null;
    return _createZipBackup(await _collectCompleteBackup(),
        customPath: dir.path);
  }

  /// ---------------------------
  /// 🔧 EXTRACT ZIP BACKUP
  /// ---------------------------
  /// Backups are password-protected (AES) zips. We prompt for the password,
  /// then decrypt the whole archive with it. [passwordProvider] returns the
  /// entered password, or null to cancel.
  static Future<_DecodedBackup> _extractZipBackup(
    File file, {
    Future<String?> Function()? passwordProvider,
  }) async {
    final zipBytes = await file.readAsBytes();

    // BKP-11: an incomplete file is refused before asking for a password.
    _refuseTruncatedBlob(zipBytes);
    if (passwordProvider == null) {
      throw Exception("Backup is encrypted but no password provider was given");
    }
    final password = await passwordProvider();
    if (password == null) throw Exception("Restore cancelled: no password entered");

    List<Map<String, dynamic>> entries;
    if (BackupEncryptionService.isEncryptedBlob(zipBytes)) {
      // New protected backup: decrypt the outer layer first
      final decryptedZip = _openProtectedBlob(zipBytes, password);
      try {
        entries = await compute(_decodeZipInIsolate, (decryptedZip.toList(), password));
      } catch (e) {
        throw Exception(_innerDecodeMessage(
            e, "Wrong password or corrupted backup entries"));
      }
    } else {
      // Legacy backup: check if plain
      if (_looksLikePlainBackup(zipBytes)) {
        throw Exception(_unencryptedMsg);
      }
      try {
        entries = await compute(_decodeZipInIsolate, (zipBytes.toList(), password));
      } catch (e) {
        throw Exception(_innerDecodeMessage(e, backupWrongPasswordMessage));
      }
    }

    return _decodeEntries(entries, password);
  }

  /// True if the zip's data.json can be read WITHOUT a password (i.e. it's
  /// unencrypted). A WinZip-AES entry yields garbage when read with no password,
  /// so jsonDecode throws and we return false.
  static bool _looksLikePlainBackup(List<int> zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) return false;
      jsonDecode(utf8.decode(dataFile.content));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes images to product_images/ (skipped on web) and returns the parsed
  /// data.json map.
  /// Decodes the backup's data.json and collects its image entries WITHOUT
  /// writing anything, so a backup can be rejected before it touches disk.
  /// The images are written by [_writeImageEntries] once the restore is allowed.
  static Future<_DecodedBackup> _decodeEntries(
      List<Map<String, dynamic>> entries, String password) async {
    final images = <Map<String, dynamic>>[];
    List<int>? dataBytes;

    for (final f in entries) {
      final name = f['name'] as String;

      if (name.startsWith('item_img_') || name.startsWith('prod_img_')) {
        images.add(f);
      } else if (name.toLowerCase() == 'data.json') {
        dataBytes = f['bytes'] as List<int>;
      }
    }

    if (dataBytes == null) throw Exception("Backup data file missing in ZIP");

    final jsonMap = jsonDecode(utf8.decode(dataBytes)) as Map<String, dynamic>;
    if (jsonMap.containsKey('encryptedData') && jsonMap.containsKey('salt') && jsonMap.containsKey('iv')) {
      final decrypted = BackupEncryptionService.decryptData(
        encryptedBase64: jsonMap['encryptedData'],
        salt: jsonMap['salt'],
        ivBase64: jsonMap['iv'],
        password: password,
      );
      if (decrypted == null) {
        throw Exception("Wrong password or corrupted backup data inside ZIP");
      }
      return (data: jsonDecode(decrypted) as Map<String, dynamic>, images: images);
    } else {
      return (data: jsonMap, images: images);
    }
  }

  /// Writes the backup's product/item images into `product_images` through
  /// [journal], so a failed restore can put the previous files back. Restore
  /// never deletes an image file; it only creates or overwrites.
  static Future<void> _writeImageEntries(
      List<Map<String, dynamic>> images, _ImageJournal? journal) async {
    if (kIsWeb || images.isEmpty || journal == null) return; // no filesystem on web
    final appDir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${appDir.path}/product_images');

    for (final f in images) {
      final name = f['name'] as String;
      final bytes = f['bytes'] as List<int>;
      if (!productDir.existsSync()) productDir.createSync(recursive: true);
      final imgName = name.startsWith('prod_img_')
          ? name.replaceFirst('prod_img_', '')
          : name;
      await journal.write(File('${productDir.path}/$imgName'), bytes);
    }
  }

  /// Sections the most recent `_collectAllData` could not export: each was
  /// written as an empty list. Reset at the start of every export.
  static Set<String> _exportFailures = {};

  /// Sections whose export is not required for a safe rollback. The backup
  /// password: an empty `secureCreds` leaves the device's password alone.
  /// (`localPrefs` IS required: rollback reads the store-info preferences from
  /// it, and an empty one would remove them.)
  static const Set<String> _optionalSnapshotSections = {'secureCreds'};

  /// Sections of the last export that failed and matter for a safe rollback.
  static Set<String> get _requiredExportFailures =>
      _exportFailures.difference(_optionalSnapshotSections);

  /// Why the last manual or automatic backup was not saved, when the reason
  /// is an incomplete export; null otherwise. Reset by every export call.
  static String? lastExportError;

  /// The export for a backup file. A section that could not be read would be
  /// saved as empty, and restoring that file would empty the section on the
  /// target device, so an incomplete export is never written as a backup.
  static Future<Map<String, dynamic>> _collectCompleteBackup() async {
    final data = await _collectAllData();
    final failed = _requiredExportFailures;
    if (failed.isNotEmpty) {
      lastExportError = 'Backup not saved: these sections could not be read: '
          '${(failed.toList()..sort()).join(', ')}. A backup without them '
          'could not be restored completely.';
      throw Exception(lastExportError);
    }
    return data;
  }

  /// Sections the last successful restore could not read and left unchanged
  /// (their restore step tolerates unreadable records). Shown to the user.
  static List<String> lastRestoreSkippedSections = const [];

  /// BKP-9: steps after the writes that did not finish in the last
  /// successful restore. Any entry means the restore was not fully clean.
  static List<String> lastRestorePostRestoreWarnings = const [];

  /// BKP-9: Restaurant sections whose restore step tolerates unreadable
  /// records but which hold money, stock, ledgers, numbering or the
  /// definitions those depend on. One of them unreadable refuses the whole
  /// restore before anything is written. (Steps without a try/catch were
  /// already strict.)
  static const Set<String> restaurantCriticalSections = {
    'itemCancellations',
    'cashMovements',
    'cashHandovers',
    'restaurantSessions',
    'dayManagement',
    'shifts',
    'appCounters',
    'customers',
    'stockMovements',
    'recipes',
    'recipeProductions',
    'restaurantSuppliers',
    'restaurantSupplierLedger',
    'restaurantPurchaseOrders',
    'restaurantPurchaseOrderItems',
    'restaurantGrns',
    'restaurantGrnItems',
    'restaurantPurchaseReturns',
    'restaurantPurchaseReturnItems',
    'restaurantSupplierClaims',
    'restaurantSupplierClaimItems',
    'restaurantInventoryLosses',
    'restaurantStockTakes',
    'restaurantStockTakeItems',
  };

  /// BKP-9: the Retail counterpart of [restaurantCriticalSections].
  static const Set<String> retailCriticalSections = {
    'cashMovements',
    'paymentEntries',
    'creditPayments',
    'eodReports',
    'expenses',
    'restaurantSessions',
    'dayManagement',
    'shifts',
    'appCounters',
    'supplierLedger',
    'stockMovements',
    'kitAssemblies',
    'purchaseOrders',
    'purchaseOrderItems',
    'grns',
    'grnItems',
    'holdSales',
    'holdSaleItems',
    'taxes',
    'staffBox',
    'billingTabs',
  };

  /// BKP-9: labels of the steps after the writes, as the user reads them.
  static const String postStepItemImages = 'reloading item images';
  static const String postStepProductList = 'refreshing the product list';
  static const String postStepStoreDetails =
      'copying store details for receipts';

  /// Test hook: the post-restore step with this label fails.
  @visibleForTesting
  static String? failPostRestoreStepForTesting;

  /// Runs one step after the writes. A failure does not undo the restore,
  /// but is recorded so the result is never reported as fully successful.
  static Future<void> _postRestoreStep(
      _RestoreRun r, String label, Future<void> Function() step) async {
    try {
      if (failPostRestoreStepForTesting == label) {
        throw StateError('injected failure: $label');
      }
      await step();
    } catch (e) {
      debugPrint("⚠️ Post-restore step '$label' did not finish: $e");
      r.postRestoreWarnings.add(label);
    }
  }

  /// BKP-2: per backup key, how many records of the last restore kept an
  /// automatic key instead of their ID (a blank ID, or an earlier copy of a
  /// repeated ID). Every record is still restored; this only says how.
  @visibleForTesting
  static Map<String, int> lastRestoreUnkeyedRecords = const {};

  /// BKP-2: writes [models] keyed by their ID, losing none. The LAST copy of
  /// a repeated ID takes the ID key — the one an ID lookup on the source
  /// device returned (Hive lists integer keys before string keys, so the
  /// `put(id)` copy comes last); earlier copies and records with a blank ID
  /// keep automatic keys, exactly as the backup's device held them.
  static Future<void> _putKeyedById<T>(String keyName, Box<T> box,
      List<T> models, String Function(T) idOf) async {
    final lastAt = <String, int>{};
    for (var i = 0; i < models.length; i++) {
      final id = idOf(models[i]);
      if (id.isNotEmpty) lastAt[id] = i;
    }
    final keyed = <String, T>{};
    final unkeyed = <T>[];
    for (var i = 0; i < models.length; i++) {
      final id = idOf(models[i]);
      if (id.isNotEmpty && lastAt[id] == i) {
        keyed[id] = models[i];
      } else {
        unkeyed.add(models[i]);
      }
    }
    await box.putAll(keyed);
    if (unkeyed.isNotEmpty) {
      await box.addAll(unkeyed);
      debugPrint("⚠️ $keyName: ${unkeyed.length} record(s) with a blank or "
          "repeated ID kept under automatic keys");
      lastRestoreUnkeyedRecords = {
        ...lastRestoreUnkeyedRecords,
        keyName: unkeyed.length,
      };
    }
  }

  /// Test hook: clearing the pending-work journal inside the restore removes
  /// this many entries, then fails (0 = fails before removing any).
  @visibleForTesting
  static int? failWorkJournalClearForTesting;

  /// Test hook: putting the journal back during a rollback fails.
  @visibleForTesting
  static bool failWorkJournalPutBackForTesting = false;

  static String _workJournalBox(String mode) =>
      mode == BusinessMode.retail.name
          ? HiveBoxNames.retailCheckoutJournal
          : HiveBoxNames.restaurantStockJournal;

  static String _workJournalLabel(String mode) =>
      mode == BusinessMode.retail.name
          ? 'Retail checkout journal'
          : 'Restaurant stock journal';

  /// Every entry of the pending-work journal, copied out of Hive.
  static Map<dynamic, dynamic> _captureWorkJournal(String mode) {
    final box = Hive.box(_workJournalBox(mode));
    return {for (final key in box.keys) key: _deepCopy(box.get(key))};
  }

  /// Empties the pending-work journal (inside the restore transaction).
  static Future<void> _clearWorkJournal(String mode) async {
    final failAfter = failWorkJournalClearForTesting;
    if (failAfter != null) {
      final box = Hive.box(_workJournalBox(mode));
      for (final key in box.keys.take(failAfter).toList()) {
        await box.delete(key);
      }
      throw StateError('injected journal clear failure after $failAfter');
    }
    if (mode == BusinessMode.retail.name) {
      await RetailCheckoutCommit.clear();
    } else {
      await StockJournal.clear();
    }
  }

  /// Rollback: puts back every [before] entry that is missing or changed,
  /// then checks the whole set is there again. Never throws; false means the
  /// journal is NOT as it was (the rollback is then not reported verified).
  /// Entries added since are kept: they are pending work, never discarded.
  static Future<bool> _putBackWorkJournal(
      String mode, Map<dynamic, dynamic> before) async {
    try {
      if (failWorkJournalPutBackForTesting) {
        throw StateError('injected journal put-back failure');
      }
      final box = Hive.box(_workJournalBox(mode));
      final missing = {
        for (final e in before.entries)
          if (!box.containsKey(e.key) || !_deepEquals(box.get(e.key), e.value))
            e.key: _deepCopy(e.value),
      };
      if (missing.isNotEmpty) await box.putAll(missing);
      final ok = before.entries.every((e) =>
          box.containsKey(e.key) && _deepEquals(box.get(e.key), e.value));
      if (!ok) debugPrint("❌ ${_workJournalLabel(mode)} not fully put back");
      return ok;
    } catch (e) {
      debugPrint("❌ ${_workJournalLabel(mode)} could not be put back "
          "(${before.length} entries: ${before.keys.join(', ')}): $e");
      return false;
    }
  }

  static Object? _deepCopy(Object? v) {
    if (v is Map) return {for (final e in v.entries) e.key: _deepCopy(e.value)};
    if (v is List) return [for (final e in v) _deepCopy(e)];
    return v;
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !_deepEquals(e.value, b[e.key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Test hook: the write pass fails right after writing this backup key.
  @visibleForTesting
  static String? failWritingKeyForTesting;

  /// Test hook: the rollback fails right after writing this backup key.
  @visibleForTesting
  static String? failRollbackWritingKeyForTesting;

  /// The single restore path both import entry points share once the file is
  /// decoded: decide the backup's business type, refuse a cross-mode restore,
  /// read the whole backup, snapshot this device, and only then write. A
  /// failure while writing rolls everything back to the snapshot.
  static Future<void> _restoreDecodedBackup(
    Map<String, dynamic> data, {
    List<Map<String, dynamic>> images = const [],
  }) async {
    lastRestoreSkippedSections = const [];
    lastRestorePostRestoreWarnings = const [];
    lastRestoreUnkeyedRecords = const {};
    final backupMode = _resolveBackupMode(data);
    debugPrint("📦 Detected backup mode: $backupMode");

    _ensureRestoreModeAllowed(backupMode);

    await _ensureBoxesOpened(backupMode);
    final check = _RestoreRun(validateOnly: true);
    try {
      await _restoreAllData(data, backupMode, validateOnly: true, run: check);
    } on FormatException catch (e) {
      throw Exception(
        'This backup file is damaged and was not restored. Nothing on this '
        'device was changed. (${e.message})',
      );
    }

    // BKP-9: an unreadable critical section refuses the whole restore here,
    // before the snapshot and before any box is cleared or written.
    final critical = backupMode == BusinessMode.retail.name
        ? retailCriticalSections
        : restaurantCriticalSections;
    final unreadable = check.tolerated.values.toSet().intersection(critical);
    if (unreadable.isNotEmpty) {
      throw RestoreRefusedException(unreadable.toList()..sort());
    }

    // Nothing has been written yet.
    final snapshot = await _takeSnapshot(backupMode);
    _ImageJournal? journal;
    if (!kIsWeb && images.isNotEmpty) {
      journal = _ImageJournal(Directory(p.join(
          (await getApplicationDocumentsDirectory()).path,
          'restore_image_undo')));
      journal.discard(); // leftovers of an interrupted earlier restore
    }

    // Pending work journal (Restaurant stock journal: Settle, void, cancel and
    // goods-receipt entries; Retail checkout journal). Device-local and never
    // exported: its entries describe this device's data before the restore.
    // Copied now, before any write, so a rollback can put every entry back.
    final pendingWork = _captureWorkJournal(backupMode);

    final run = _RestoreRun(validateOnly: false, tolerated: check.tolerated);
    try {
      await _writeImageEntries(images, journal);
      await _restoreAllData(data, backupMode, run: run);
      // Part of the restore itself: the restored data and the emptied journal
      // succeed together, or both go back to how they were. A failure here
      // rolls back like any write failure, so stale entries can never be
      // replayed against the restored data.
      await _clearWorkJournal(backupMode);
    } catch (e) {
      debugPrint("❌ Restore failed while writing, rolling back: $e");
      final rolledBack = await _rollback(snapshot, backupMode, journal);
      final journalBack = await _putBackWorkJournal(backupMode, pendingWork);
      throw RestoreFailedException(
        cause: e,
        dataRolledBack: rolledBack,
        journalRestored: journalBack,
        snapshotPath: snapshot.filePath,
        unrestoredJournal: journalBack ? null : _workJournalLabel(backupMode),
        unrestoredJournalEntries: journalBack ? const {} : pendingWork,
      );
    }

    journal?.discard();

    lastRestoreSkippedSections = {
      ...check.tolerated.values,
      ...run.unrestoredSettings,
    }.toList()
      ..sort();
    lastRestorePostRestoreWarnings = List.unmodifiable(run.postRestoreWarnings);
  }

  /// True when setup that is not finished yet has already saved data a restore
  /// would replace: a store name, tax settings, or records in the staff,
  /// category, tax, product or item boxes. Payment methods are not checked on
  /// their own: defaults are seeded on every install, and the wizard's payment
  /// step comes after Store Details, whose store name is required.
  static bool hasSetupDataToLose() {
    bool has<T>(String name) =>
        Hive.isBoxOpen(name) && Hive.box<T>(name).isNotEmpty;
    final details = Hive.isBoxOpen(HiveBoxNames.businessDetailsBox)
        ? Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox).values
        : const <BusinessDetails>[];
    return details.any((d) => (d.storeName ?? '').trim().isNotEmpty) ||
        has<TaxDetails>(HiveBoxNames.taxBox) ||
        has<StaffModel>(HiveBoxNames.staff) ||
        has<Category>(HiveBoxNames.category) ||
        has<Tax>(HiveBoxNames.tax) ||
        has<ProductModel>(HiveBoxNames.products) ||
        has<Items>(HiveBoxNames.restaurantItems);
  }

  @visibleForTesting
  static Future<void> restoreDecodedBackupForTesting(
    Map<String, dynamic> data, {
    List<Map<String, dynamic>> images = const [],
  }) =>
      _restoreDecodedBackup(data, images: images);

  /// Takes this device's data just before a restore's first write: the
  /// export map and restaurant item image bytes in memory, plus, on native
  /// with a backup password set, an encrypted copy (the normal backup format)
  /// in app-private `restore_snapshots/`. Never writes an unencrypted file:
  /// `_createZipBackup` refuses without a password.
  static Future<_Snapshot> _takeSnapshot(String mode) async {
    final exported = await _collectAllData(mode: mode);
    // A section that failed to export is an empty list in the snapshot;
    // rolling back to it would empty that box and still compare equal. Refuse
    // to start instead (nothing has been written yet).
    final failed = _requiredExportFailures;
    if (failed.isNotEmpty) {
      throw Exception(
        'The restore did not start: a complete safety copy of this device\'s '
        'data could not be made, so a failed restore could not be undone. '
        'Nothing on this device was changed. (Could not copy: '
        '${(failed.toList()..sort()).join(', ')})',
      );
    }
    final data = jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;

    final itemImages = <String, Uint8List>{};
    if (Hive.isBoxOpen(HiveBoxNames.restaurantItems)) {
      for (final item in Hive.box<Items>(HiveBoxNames.restaurantItems).values) {
        final bytes = item.imageBytes;
        if (bytes != null && bytes.isNotEmpty) itemImages[item.id] = bytes;
      }
    }

    String? filePath;
    if (!kIsWeb) {
      try {
        final password = await BackupEncryptionService.getStoredPassword();
        if (password != null && password.isNotEmpty) {
          final dir = Directory(p.join(
              (await getApplicationDocumentsDirectory()).path,
              'restore_snapshots'));
          if (!dir.existsSync()) dir.createSync(recursive: true);
          filePath = await _createZipBackup(exported, customPath: dir.path);
          if (filePath != null) {
            // Keep only the newest snapshot. p.equals, not ==: the new path
            // is built with '/', while listSync uses the platform separator.
            for (final old in dir.listSync().whereType<File>()) {
              if (!p.equals(old.path, filePath)) old.deleteSync();
            }
          }
        }
      } catch (e) {
        debugPrint("⚠️ Could not save the encrypted pre-restore snapshot: $e");
      }
    }
    debugPrint("📦 Pre-restore snapshot taken (file: ${filePath ?? 'none'})");
    return _Snapshot(data, itemImages, filePath);
  }

  /// Puts the snapshot back through the same restore path, then re-exports
  /// and compares. Returns true only when every backed-up section matches the
  /// snapshot again.
  static Future<bool> _rollback(
      _Snapshot snapshot, String backupMode, _ImageJournal? journal) async {
    try {
      await journal?.revert();
      final run = _RestoreRun(validateOnly: false, isRollback: true);
      await _restoreAllData(snapshot.data, backupMode, run: run);
      await _putBackItemImages(snapshot.itemImages);
      await _putBackStoreInfoPrefs(snapshot.data);

      final now =
          jsonDecode(jsonEncode(await _collectAllData(mode: backupMode)))
              as Map<String, dynamic>;
      if (_requiredExportFailures.isNotEmpty) {
        debugPrint("❌ Rollback not verified: could not re-read "
            "${_requiredExportFailures.join(', ')}");
        return false;
      }
      final same = _sameBackedUpData(now, snapshot.data);
      debugPrint(same
          ? "✅ Rollback verified: previous data is back"
          : "❌ Rollback did not reproduce the previous data");
      return same;
    } catch (e) {
      debugPrint("❌ Rollback failed: $e");
      return false;
    }
  }

  /// The store-info preferences `_syncSharedPreferencesFromBusinessDetails`
  /// writes (retail reads them for receipts).
  static const List<String> _storeInfoPrefKeys = [
    'store_name',
    'store_owner_name',
    'store_address',
    'store_city',
    'store_state',
    'store_pincode',
    'store_phone',
    'store_email',
    'store_gst_number',
  ];

  /// Puts the store-info preferences back exactly as they were before the
  /// restore: the failed restore may have synced the backup's store details
  /// into them, including keys this device never had.
  static Future<void> _putBackStoreInfoPrefs(
      Map<String, dynamic> snapshot) async {
    final before = <String, Object?>{
      for (final entry
          in ((snapshot['data'] as Map)['localPrefs'] as List? ?? const []))
        if (entry is Map && entry['key'] is String)
          entry['key'] as String: entry['value'],
    };
    final prefs = await SharedPreferences.getInstance();
    for (final key in _storeInfoPrefKeys) {
      final value = before[key];
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value.toString());
      }
    }
  }

  /// Restores restaurant item image bytes, which the export map strips.
  static Future<void> _putBackItemImages(Map<String, Uint8List> images) async {
    if (images.isEmpty || !Hive.isBoxOpen(HiveBoxNames.restaurantItems)) return;
    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    final batch = <dynamic, Items>{};
    for (final key in box.keys) {
      final item = box.get(key);
      final bytes = item == null ? null : images[item.id];
      if (item != null && bytes != null) {
        batch[key] = item.copyWith(imageBytes: bytes);
      }
    }
    if (batch.isNotEmpty) await box.putAll(batch);
  }

  /// Compares two exports section by section, ignoring record order.
  /// `localPrefs`/`secureCreds` are device settings a restore only adds to,
  /// never removes from, so they are not part of the check.
  static bool _sameBackedUpData(
      Map<String, dynamic> a, Map<String, dynamic> b) {
    const ignored = {'localPrefs', 'secureCreds'};
    final da = (a['data'] as Map).cast<String, dynamic>();
    final db = (b['data'] as Map).cast<String, dynamic>();
    final keys = {...da.keys, ...db.keys}.difference(ignored);
    for (final key in keys) {
      List<String> canon(Object? v) =>
          [for (final e in (v as List? ?? const [])) jsonEncode(_canonical(e))]
            ..sort();
      final ca = canon(da[key]);
      final cb = canon(db[key]);
      if (ca.length != cb.length) return false;
      for (var i = 0; i < ca.length; i++) {
        if (ca[i] != cb[i]) return false;
      }
    }
    return true;
  }

  /// [value] with every map's keys sorted, so equal data encodes equally.
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canonical(value[k])};
    }
    if (value is List) return [for (final e in value) _canonical(e)];
    return value;
  }

  /// The rollback's own comparison, so tests can show what it can and cannot
  /// see (BKP-4).
  @visibleForTesting
  static bool sameBackedUpDataForTesting(
          Map<String, dynamic> a, Map<String, dynamic> b) =>
      _sameBackedUpData(a, b);

  @visibleForTesting
  static Future<String?> takeSnapshotFileForTesting() async =>
      (await _takeSnapshot(AppConfig.businessMode.name)).filePath;

  @visibleForTesting
  static Future<Map<String, dynamic>> readBackupFileForTesting(
          String path, String password,
          {void Function()? onPasswordAsked}) async =>
      (await _extractZipBackup(File(path), passwordProvider: () async {
        onPasswordAsked?.call();
        return password;
      }))
          .data;

  /// BLK-04: a configured install accepts only its own business type's
  /// backup. A fresh install (mode not set yet) accepts either, which is how
  /// a new device is restored. An undeterminable backup is left to the
  /// existing format checks, which reject it before any write.
  static void _ensureRestoreModeAllowed(String backupMode) {
    if (!AppConfig.isBusinessModeSet) return;
    if (backupMode != BusinessMode.restaurant.name &&
        backupMode != BusinessMode.retail.name) {
      return;
    }
    final deviceMode = AppConfig.businessMode.name;
    if (backupMode == deviceMode) return;

    String label(String mode) =>
        mode == BusinessMode.retail.name ? 'Retail' : 'Restaurant';
    throw Exception(
      'This is a ${label(backupMode)} backup, but this device is set up for '
      '${label(deviceMode)}. A backup can only be restored on the same '
      'business type.',
    );
  }

  /// The backup's business type, including legacy backups that have neither
  /// `appMode` nor the `data` wrapper; 'unknown' when it cannot be told.
  static String _resolveBackupMode(Map<String, dynamic> data) {
    final mode = _detectModeFromBackup(data);
    if (mode != 'unknown' || data.containsKey('data')) return mode;
    return _legacyModeOf(data);
  }

  /// Mode of a legacy (unwrapped) backup from its top-level keys.
  static String _legacyModeOf(Map<String, dynamic> data) {
    if (data.containsKey('products') && data.containsKey('suppliers')) {
      return 'retail';
    } else if (data.containsKey('items') || data.containsKey('tables')) {
      return 'restaurant';
    }
    return 'unknown';
  }

  /// ---------------------------
  /// 🔧 DETECT MODE FROM BACKUP
  /// ---------------------------
  static String _detectModeFromBackup(Map<String, dynamic> data) {
    debugPrint("📦 Backup file structure: ${data.keys.toList()}");

    // Check if backup has mode specified
    if (data.containsKey('appMode')) {
      debugPrint("📦 Found appMode: ${data['appMode']}");
      return data['appMode'];
    }

    // Auto-detect from data structure
    final backupData = data['data'] as Map<String, dynamic>?;
    if (backupData == null) {
      debugPrint("⚠️ No 'data' key found in backup. Available keys: ${data.keys.toList()}");
      return 'unknown';
    }

    debugPrint("📦 Backup data keys: ${backupData.keys.toList()}");

    // Restaurant has: items, tables, pastOrders
    // Retail has: products, sales, suppliers
    if (backupData.containsKey('products') && backupData.containsKey('suppliers')) {
      debugPrint("📦 Detected retail backup (has products & suppliers)");
      return 'retail';
    } else if (backupData.containsKey('itemBoxs') || backupData.containsKey('items') || backupData.containsKey('tables')) {
      debugPrint("📦 Detected restaurant backup (has items/tables)");
      return 'restaurant';
    }

    debugPrint("⚠️ Could not determine backup type from data structure");
    return 'unknown';
  }

  /// ---------------------------
  /// 🔧 RESTORE ALL DATA
  /// ---------------------------
  /// With [validateOnly], runs the same steps reading every record and the
  /// settings blocks but writing nothing, so a damaged backup is refused
  /// before any box is cleared.
  static Future<void> _restoreAllData(Map<String, dynamic> data, String backupMode,
      {bool validateOnly = false, _RestoreRun? run}) async {
    final r = run ?? _RestoreRun(validateOnly: validateOnly);
    debugPrint("📦 ${validateOnly ? 'Validating' : 'Restoring'} data for mode: $backupMode");

    // Validate backup data structure
    if (!data.containsKey('data') || data['data'] == null) {
      debugPrint("❌ Invalid backup format: Missing 'data' key");
      debugPrint("📦 Backup structure: ${data.keys.toList()}");

      // Check if this is a legacy format (direct data without wrapper)
      if (data.containsKey('products') || data.containsKey('items') || data.containsKey('categories')) {
        debugPrint("📦 Detected legacy backup format (unwrapped data)");
        // Treat the entire data object as the backup data
        await _handleLegacyRestore(data, backupMode,
            validateOnly: validateOnly, run: r);
        return;
      }

      throw Exception("Invalid backup file format. The backup file doesn't contain the expected 'data' key. Available keys: ${data.keys.toList()}");
    }

    final backupData = data['data'] as Map<String, dynamic>;

    // Validate mode is known
    if (backupMode == 'unknown') {
      debugPrint("❌ Cannot restore: Unknown backup mode");
      debugPrint("📦 Backup data keys: ${backupData.keys.toList()}");
      throw Exception("Cannot determine backup type. The backup file format is not recognized. Available data keys: ${backupData.keys.toList()}");
    }

    // Restore based on detected mode
    if (backupMode == 'restaurant') {
      await _restoreRestaurantData(backupData,
          validateOnly: validateOnly, run: r);
    } else if (backupMode == 'retail') {
      await _restoreRetailData(backupData, validateOnly: validateOnly, run: r);
    } else {
      throw Exception("Unsupported backup mode: $backupMode");
    }

    if (validateOnly) {
      _validateSettings(backupData);
      return;
    }

    // ==================== RESTORE COMMON BOXES (both retail and restaurant) ====================
    // Settings were checked strictly by the validate pass, so these steps no
    // longer swallow errors: a failure here is a write failure.

    // ✅ Restore app config FIRST (CRITICAL - contains business mode and setup status)
    // A backup without these settings blocks never carried them (legacy), so
    // the device's own are kept rather than emptied.
    await _restoreKeyValueBox(backupData, "appConfig",
        Hive.box(HiveBoxNames.appConfig), r, clearWhenMissing: false);
    await _restoreKeyValueBox(backupData, "appState",
        Hive.box("app_state"), r, clearWhenMissing: false);
    await _restoreKeyValueBox(backupData, "storeBox",
        Hive.box(HiveBoxNames.storeBox), r, clearWhenMissing: false);

    Future<void> settingsList<T>(String key, Box<T> box,
        T Function(Map<String, dynamic>) fromMap) async {
      final raw = backupData[key];
      if (raw == null || raw.isEmpty) {
        // Rollback only: the snapshot is complete (E1), so an empty section
        // means the device had none before the restore. A normal restore
        // keeps the device's settings when the backup has none.
        if (r.isRollback && raw != null) {
          await r.write(key, box, () async {
            await box.clear();
            return 0;
          });
        }
        return;
      }
      debugPrint("📦 Restoring $key...");
      await r.write(key, box, () async {
        final models = [
          for (var item in raw) fromMap(Map<String, dynamic>.from(item)),
        ];
        await box.clear();
        for (final model in models) {
          await box.add(model);
        }
        return models.length;
      });
    }

    await settingsList("businessDetails",
        Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox),
        BusinessDetails.fromMap);
    // ✅ CRITICAL: Sync SharedPreferences from BusinessDetails for retail
    // Retail side uses SharedPreferences for store info, not Hive
    // This must happen AFTER BusinessDetails is restored
    if (backupMode == 'retail' &&
        r.writeFailure == null &&
        backupData["businessDetails"] != null &&
        backupData["businessDetails"].isNotEmpty) {
      await _postRestoreStep(r, postStepStoreDetails,
          _syncSharedPreferencesFromBusinessDetails);
    }
    await settingsList("businessTypes",
        Hive.box<BusinessType>(HiveBoxNames.businessTypeBox),
        BusinessType.fromMap);
    await settingsList("taxDetails",
        Hive.box<TaxDetails>(HiveBoxNames.taxBox), TaxDetails.fromMap);
    await settingsList("paymentMethods",
        Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods),
        pm.PaymentMethod.fromMap);

    // ✅ CRITICAL: Update AppConfig with the correct business mode
    // Note: Only update if appConfig wasn't in the backup (for legacy backups)
    if (backupData["appConfig"] == null || backupData["appConfig"].isEmpty) {
      debugPrint("📦 AppConfig not found in backup - updating from detected mode: $backupMode");
      await r.write("appConfig", Hive.box(HiveBoxNames.appConfig), () async {
        await _updateAppConfigFromBackup(backupMode);
        return null;
      });
    } else {
      debugPrint("📦 AppConfig already restored from backup - skipping manual update");
    }

    // Stop before the device-level settings if any box write failed.
    if (r.writeFailure != null) throw r.writeFailure!;

    // ✅ Restore non-Hive settings (admin PIN, store/UPI, prefs, backup password)
    await _restoreLocalSettings(backupData, r);

    debugPrint("✅ Data restoration completed!");
  }

  /// Restores SharedPreferences (`localPrefs`) + the backup password
  /// (`secureCreds`) saved by `_collectAllData`. Re-applies the denylist so a
  /// tampered backup can't overwrite device id / license / printer keys.
  /// BKP-9: a failure is recorded in [r] and reported, never silent.
  static Future<void> _restoreLocalSettings(
      Map<String, dynamic> backupData, _RestoreRun r) async {
    try {
      final localPrefs = backupData['localPrefs'];
      if (localPrefs is List && localPrefs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        int n = 0;
        for (final entry in localPrefs) {
          if (entry is! Map) continue;
          final key = entry['key'] as String?;
          final type = entry['type'] as String?;
          final value = entry['value'];
          if (key == null || _prefsDenylist.contains(key) || value == null) {
            continue;
          }
          switch (type) {
            case 'bool':
              await prefs.setBool(key, value as bool);
              break;
            case 'int':
              await prefs.setInt(key, (value as num).toInt());
              break;
            case 'double':
              await prefs.setDouble(key, (value as num).toDouble());
              break;
            case 'stringList':
              await prefs.setStringList(
                  key, (value as List).map((e) => e.toString()).toList());
              break;
            default:
              await prefs.setString(key, value.toString());
          }
          n++;
        }
        debugPrint("📦 Local prefs restored: $n");
      }
    } catch (e) {
      debugPrint("⚠️ Local prefs restore error: $e");
      r.unrestoredSettings.add('localPrefs');
    }

    try {
      final creds = backupData['secureCreds'];
      if (creds is List && creds.isNotEmpty) {
        final pwd = (creds.first as Map)['backupPassword'] as String?;
        if (pwd != null && pwd.isNotEmpty) {
          await BackupEncryptionService.setPassword(pwd);
          debugPrint("📦 Backup password restored");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Secure creds restore error: $e");
      r.unrestoredSettings.add('secureCreds');
    }
  }

  /// ---------------------------
  /// 🔧 UPDATE APP CONFIG FROM BACKUP
  /// ---------------------------
  /// Updates AppConfig box to match the restored backup's business mode
  static Future<void> _updateAppConfigFromBackup(String backupMode) async {
    try {
      // Force update the business mode in AppConfig
      final appConfigBox = Hive.box('appConfigBox');

      debugPrint("📦 Current AppConfig business mode: ${appConfigBox.get('businessMode')}");
      debugPrint("📦 Setting business mode to: $backupMode");

      // Force set the business mode (bypassing the one-time restriction)
      await appConfigBox.put('businessMode', backupMode);

      // Mark setup as complete
      await appConfigBox.put('isSetupComplete', true);

      debugPrint("✅ AppConfig updated successfully");
      debugPrint("📦 New business mode: ${appConfigBox.get('businessMode')}");
      debugPrint("📦 Setup complete: ${appConfigBox.get('isSetupComplete')}");
    } catch (e, stackTrace) {
      debugPrint("❌ Failed to update AppConfig: $e");
      debugPrint("Stack trace: $stackTrace");
      // Its caller records this as a write failure, so the restore rolls back.
      rethrow;
    }
  }

  /// ---------------------------
  /// 🔧 HANDLE LEGACY BACKUP RESTORE
  /// ---------------------------
  /// Handles restoration of legacy backup formats that don't have the wrapper structure
  static Future<void> _handleLegacyRestore(Map<String, dynamic> data, String backupMode,
      {bool validateOnly = false, _RestoreRun? run}) async {
    final r = run ?? _RestoreRun(validateOnly: validateOnly);
    debugPrint("📦 Attempting legacy restore...");

    // Re-detect mode if unknown
    final mode = backupMode == 'unknown' ? _legacyModeOf(data) : backupMode;
    if (mode == 'unknown') {
      throw Exception("Cannot determine mode from legacy backup. Keys: ${data.keys.toList()}");
    }
    debugPrint("📦 Legacy backup mode: $mode");

    // Ensure boxes are opened
    await _ensureBoxesOpened(mode);

    // Restore based on mode
    if (mode == 'restaurant') {
      await _restoreRestaurantData(data, validateOnly: validateOnly, run: r);
    } else if (mode == 'retail') {
      await _restoreRetailData(data, validateOnly: validateOnly, run: r);
    }
    if (validateOnly) return;

    // Update AppConfig with the correct business mode
    await r.write("appConfig", Hive.box(HiveBoxNames.appConfig), () async {
      await _updateAppConfigFromBackup(mode);
      return null;
    });
    if (r.writeFailure != null) throw r.writeFailure!;

    debugPrint("✅ Legacy backup restored successfully!");
  }

  /// ---------------------------
  /// 🔧 RESTORE RESTAURANT DATA
  /// ---------------------------
  /// Parses every record of [key] exactly as the restore helpers do, writing
  /// nothing. Throws on the first record the restore could not read.
  static void _validateRecords<T>(
    String key,
    Object? raw,
    T Function(Map<String, dynamic>) fromMap, [
    String Function(T)? idOf,
  ]) {
    final items = raw as List;
    for (var i = 0; i < items.length; i++) {
      try {
        final model = fromMap(Map<String, dynamic>.from(items[i]));
        idOf?.call(model);
      } catch (e) {
        throw FormatException(
            '"$key" record ${i + 1} of ${items.length} cannot be read ($e)');
      }
    }
  }

  /// Strict check of the settings blocks `_restoreAllData` writes. A
  /// malformed one would be cleared and left empty, wiping the business mode
  /// and setup flags, so these must parse even though their restore steps
  /// swallow errors.
  static void _validateSettings(Map<String, dynamic> backupData) {
    for (final key in const ['appConfig', 'appState', 'storeBox']) {
      final raw = backupData[key];
      if (raw == null || raw.isEmpty) continue;
      if ((raw as List).first is! Map<String, dynamic>) {
        throw FormatException('"$key" settings cannot be read');
      }
    }

    void records<T>(String key, T Function(Map<String, dynamic>) fromMap) {
      final raw = backupData[key];
      if (raw == null || raw.isEmpty) return;
      _validateRecords(key, raw, fromMap);
    }

    records('businessDetails', BusinessDetails.fromMap);
    records('businessTypes', BusinessType.fromMap);
    records('taxDetails', TaxDetails.fromMap);
    records('paymentMethods', pm.PaymentMethod.fromMap);
  }

  /// Restores a key/value box exported as `[{...}]` (counters, day state).
  /// [clearWhenMissing]: empty the box when the backup has no such key (true
  /// replace); otherwise keep it.
  static Future<void> _restoreKeyValueBox(Map<String, dynamic> data,
      String key, Box box, _RestoreRun r,
      {required bool clearWhenMissing}) async {
    final raw = data[key];
    if (raw == null || raw.isEmpty) {
      if (raw == null && clearWhenMissing && !r.validateOnly) {
        await r.write(key, box, () async {
          await box.clear();
          return 0;
        });
      }
      return;
    }
    if (r.validateOnly) {
      r.parse(box.name, key, () => raw[0] as Map<String, dynamic>);
      return;
    }
    if (r.isTolerated(box.name)) return;
    await r.write(key, box, () async {
      final values = raw[0] as Map<String, dynamic>;
      await box.clear();
      for (final entry in values.entries) {
        await box.put(entry.key, entry.value);
      }
      return values.length;
    });
  }

  static Future<void> _restoreRestaurantData(Map<String, dynamic> data,
      {bool validateOnly = false, _RestoreRun? run}) async {
    final r = run ?? _RestoreRun(validateOnly: validateOnly);
    debugPrint(validateOnly
        ? "📦 Validating restaurant data..."
        : "📦 Restoring restaurant data...");

    // Helper function to restore a box
    // ⚠️ WARNING: without [idOf] this uses box.add() (auto-increment keys).
    // BKP-2: with [idOf] each record is keyed by its ID, none dropped
    // ([_putKeyedById]). Use restoreBoxWithId() where repeats may collapse.
    Future<void> restoreBox<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap, {
        String Function(T)? idOf,
        }) async {
      if (data[keyName] == null) {
        // True replace: a box the backup does not carry is emptied.
        if (!validateOnly) {
          await r.write(keyName, box, () async {
            await box.clear();
            return 0;
          });
        }
        return;
      }
      if (validateOnly) {
        r.parse(box.name, keyName,
            () => _validateRecords(keyName, data[keyName], fromMap, idOf));
        return;
      }
      if (r.isTolerated(box.name)) {
        debugPrint("⚠️ $keyName could not be read — left unchanged");
        return;
      }
      debugPrint("📦 Restoring $keyName...");
      await r.write(keyName, box, () async {
        final items = data[keyName] as List;
        final models = items
            .map((item) => fromMap(Map<String, dynamic>.from(item)))
            .toList();
        await box.clear();
        if (idOf != null) {
          await _putKeyedById(keyName, box, models, idOf);
        } else {
          // addAll = single batch write, far faster than N individual add() calls
          await box.addAll(models);
        }
        return models.length;
      });
    }

    Future<void> restoreBoxWithId<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        String Function(T) getIdFunc,
        ) async {
      if (data[keyName] == null) {
        // True replace: a box the backup does not carry is emptied.
        if (!validateOnly) {
          await r.write(keyName, box, () async {
            await box.clear();
            return 0;
          });
        }
        return;
      }
      if (validateOnly) {
        r.parse(box.name, keyName,
            () => _validateRecords(keyName, data[keyName], fromMap, getIdFunc));
        return;
      }
      if (r.isTolerated(box.name)) {
        debugPrint("⚠️ $keyName could not be read — left unchanged");
        return;
      }
      debugPrint("📦 Restoring $keyName (with ID keys)...");
      await r.write(keyName, box, () async {
        final items = data[keyName] as List;
        // putAll = single batch write, far faster than N individual put() calls
        final Map<String, T> batch = {};
        for (final item in items) {
          final model = fromMap(Map<String, dynamic>.from(item));
          batch[getIdFunc(model)] = model;
        }
        await box.clear();
        await box.putAll(batch);
        return batch.length;
      });
    }

    await restoreBoxWithId("categories", Hive.box<Category>(HiveBoxNames.category), (m) => Category.fromMap(m), (c) => c.id);
    await restoreBoxWithId("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m), (i) => i.id);

    // Reload imageBytes for each item from its item_img_{id} file.
    // O(n) approach: build a key-by-ID lookup map first, then match files.
    if (!validateOnly) {
      await _postRestoreStep(r, postStepItemImages, () async {
        final appDir = await getApplicationDocumentsDirectory();
        final productDir = Directory('${appDir.path}/product_images');
        if (productDir.existsSync()) {
          final itemBox = Hive.box<Items>("itemBoxs");

          // Build ID → Hive key map in one pass
          final idToKey = <String, dynamic>{};
          for (final key in itemBox.keys) {
            final item = itemBox.get(key);
            if (item != null) idToKey[item.id] = key;
          }

          final imgFiles = productDir.listSync().whereType<File>()
              .where((f) => p.basename(f.path).startsWith('item_img_'))
              .toList();

          // Build batch update map
          final Map<dynamic, Items> imageBatch = {};
          for (final imgFile in imgFiles) {
            final itemId = p.basename(imgFile.path).replaceFirst('item_img_', '');
            final key = idToKey[itemId];
            if (key != null) {
              final item = itemBox.get(key)!;
              final bytes = await imgFile.readAsBytes();
              imageBatch[key] = item.copyWith(imageBytes: bytes);
            }
          }
          if (imageBatch.isNotEmpty) await itemBox.putAll(imageBatch);
          debugPrint("✅ Item images reloaded: ${imageBatch.length}");
        }
      });
    }
    await restoreBoxWithId("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m), (v) => v.id);
    await restoreBoxWithId("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m), (ch) => ch.id);
    await restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m),
        idOf: (e) => e.Id); // BKP-2: ExtraRepository keys by Id
    await restoreBoxWithId("staffBox", Hive.box<StaffModel>(HiveBoxNames.staff), (m) => StaffModel.fromMap(m), (s) => s.id);
    await restoreBoxWithId("taxes", Hive.box<Tax>(HiveBoxNames.tax), (m) => Tax.fromMap(m), (t) => t.id);
    await restoreBoxWithId("expenseCategories", HiveExpenseCat.getECategory(), (m) => ExpenseCategory.fromMap(m), (ec) => ec.id);
    await restoreBoxWithId("expenses", HiveExpenceL.getexpenseBox(), (m) => Expense.fromMap(m), (e) => e.id);
    await restoreBoxWithId("tables", Hive.box<TableModel>("tablesBox"), (m) => TableModel.fromMap(m), (tb) => tb.id);

    // ✅ EOD Reports - hardcoded for restaurant mode (AppConfig not restored yet)
    await restoreBox("eodReports", Hive.box<EndOfDayReport>('restaurant_eodBox'), (m) => EndOfDayReport.fromMap(m),
        idOf: (e) => e.reportId); // BKP-2: EodRepository keys by reportId

    await restoreBoxWithId("pastOrders", Hive.box<PastOrderModel>("pastorderBox"), (m) => PastOrderModel.fromMap(m), (po) => po.id);
    await restoreBoxWithId("orders", Hive.box<OrderModel>("orderBox"), (m) => OrderModel.fromMap(m), (o) => o.id);

    // ✅ Restore Restaurant Cart
    try {
      await restoreBox("restaurantCart", Hive.box<CartItem>(HiveBoxNames.restaurantCart), (m) => CartItem.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant cart: $e");
    }

    // ✅ Restore App Counters. Kept when the backup has none: emptying them
    // would restart bill numbers below the restored orders' numbers.
    try {
      await _restoreKeyValueBox(data, "appCounters",
          Hive.box(HiveBoxNames.appCounters), r, clearWhenMissing: false);
    } catch (e) {
      debugPrint("⚠️ Error restoring app counters: $e");
    }

    // ✅ Restore Test Bill Box
    try {
      await restoreBox("testBillBox", Hive.box<TestBillModel>(HiveBoxNames.testBillBox), (m) => TestBillModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring test bill box: $e");
    }

    // ✅ Restore Shifts
    try {
      await restoreBoxWithId(
        "shifts",
        Hive.box<ShiftModel>(HiveBoxNames.shift),
        (m) => ShiftModel.fromMap(m),
        (s) => s.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring shifts: $e");
    }

    // ✅ Restore Cash Movements
    try {
      await restoreBoxWithId(
        "cashMovements",
        Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements),
        (m) => CashMovementModel.fromMap(m),
        (cm) => cm.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring cash movements: $e");
    }

    // ✅ Restore Cash Handovers
    try {
      await restoreBoxWithId(
        "cashHandovers",
        Hive.box<CashHandoverModel>(HiveBoxNames.restaurantCashHandovers),
        (m) => CashHandoverModel.fromMap(m),
        (ch) => ch.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring cash handovers: $e");
    }

    // ✅ Restore Customers — shared box (restaurant + retail). Retail's
    // restore of this same box (key "customers") lives in
    // `_restoreRetailData`; this function needs its own copy since only one
    // of the two restore functions runs per import.
    try {
      await restoreBoxWithId(
        "customers",
        Hive.box<Customer>(HiveBoxNames.customer),
        (m) => Customer.fromMap(m),
        (c) => c.customerId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring customers: $e");
    }

    // ✅ Restore Saved Printers
    try {
      await restoreBoxWithId(
        "printers",
        Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters),
        (m) => SavedPrinterModel.fromMap(m),
        (p) => p.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring printers: $e");
    }

    // ✅ Restore Restaurant Sessions
    try {
      await restoreBoxWithId(
        "restaurantSessions",
        Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions),
        (m) => RestaurantSessionModel.fromMap(m),
        (s) => s.sessionId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant sessions: $e");
    }

    // ✅ Restore Day Management Box (opening balance, current session)
    try {
      await _restoreKeyValueBox(data, "dayManagement",
          Hive.box(HiveBoxNames.dayManagementBox), r, clearWhenMissing: true);
    } catch (e) {
      debugPrint("⚠️ Error restoring day management: $e");
    }

    // ✅ Restore Item Cancellations
    try {
      await restoreBoxWithId(
        "itemCancellations",
        Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations),
        (m) => ItemCancellationModel.fromMap(m),
        (c) => c.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring item cancellations: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantAttendance",
        Hive.box<AttendanceModel>(HiveBoxNames.attendance),
        (m) => AttendanceModel.fromMap(m),
        (a) => a.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant attendance: $e");
    }

    try {
      await restoreBoxWithId(
        "recipes",
        Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes),
        (m) => RecipeModel.fromMap(m),
        (r) => r.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring recipes: $e");
    }

    try {
      await restoreBoxWithId(
        "recipeProductions",
        Hive.box<RecipeProductionModel>(HiveBoxNames.restaurantRecipeProductions),
        (m) => RecipeProductionModel.fromMap(m),
        (p) => p.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring recipe productions: $e");
    }

    // Absent key (older backups) → restoreBoxWithId leaves the box untouched.
    try {
      await restoreBoxWithId(
        "stockMovements",
        Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements),
        (m) => StockMovementModel.fromMap(m),
        (m) => m.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring stock movements: $e");
    }

    // The pending stock journal is cleared by `_restoreDecodedBackup` only
    // after the whole restore succeeded, so a failed restore keeps it.

    try {
      await restoreBoxWithId(
        "restaurantSuppliers",
        Hive.box<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers),
        (m) => RestaurantSupplierModel.fromMap(m),
        (s) => s.supplierId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant suppliers: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantPurchaseOrders",
        Hive.box<RestaurantPurchaseOrderModel>(HiveBoxNames.restaurantPurchaseOrders),
        (m) => RestaurantPurchaseOrderModel.fromMap(m),
        (po) => po.poId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant purchase orders: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantPurchaseOrderItems",
        Hive.box<RestaurantPurchaseOrderItemModel>(HiveBoxNames.restaurantPurchaseOrderItems),
        (m) => RestaurantPurchaseOrderItemModel.fromMap(m),
        (poi) => poi.poItemId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant purchase order items: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantGrns",
        Hive.box<RestaurantGRNModel>(HiveBoxNames.restaurantGrns),
        (m) => RestaurantGRNModel.fromMap(m),
        (g) => g.grnId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant GRNs: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantGrnItems",
        Hive.box<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems),
        (m) => RestaurantGRNItemModel.fromMap(m),
        (gi) => gi.grnItemId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant GRN items: $e");
    }

    // Supplier balance journal — restored alongside the suppliers so a
    // recovered balance still has its history.
    try {
      await restoreBoxWithId(
        "restaurantSupplierLedger",
        Hive.box<RestaurantSupplierLedgerEntryModel>(
            HiveBoxNames.restaurantSupplierLedger),
        (m) => RestaurantSupplierLedgerEntryModel.fromMap(m),
        (e) => e.entryId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant supplier ledger: $e");
    }

    // Damaged-goods / loss / stock-take chain (typeIds 143-149).
    try {
      await restoreBoxWithId(
        "restaurantPurchaseReturns",
        Hive.box<RestaurantPurchaseReturnModel>(
            HiveBoxNames.restaurantPurchaseReturns),
        (m) => RestaurantPurchaseReturnModel.fromMap(m),
        (r) => r.returnId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant purchase returns: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantPurchaseReturnItems",
        Hive.box<RestaurantPurchaseReturnItemModel>(
            HiveBoxNames.restaurantPurchaseReturnItems),
        (m) => RestaurantPurchaseReturnItemModel.fromMap(m),
        (ri) => ri.returnItemId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant purchase return items: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantSupplierClaims",
        Hive.box<RestaurantSupplierClaimModel>(
            HiveBoxNames.restaurantSupplierClaims),
        (m) => RestaurantSupplierClaimModel.fromMap(m),
        (c) => c.claimId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant supplier claims: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantSupplierClaimItems",
        Hive.box<RestaurantSupplierClaimItemModel>(
            HiveBoxNames.restaurantSupplierClaimItems),
        (m) => RestaurantSupplierClaimItemModel.fromMap(m),
        (ci) => ci.claimItemId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant supplier claim items: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantInventoryLosses",
        Hive.box<RestaurantInventoryLossModel>(
            HiveBoxNames.restaurantInventoryLosses),
        (m) => RestaurantInventoryLossModel.fromMap(m),
        (l) => l.lossId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant inventory losses: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantStockTakes",
        Hive.box<RestaurantStockTakeModel>(HiveBoxNames.restaurantStockTakes),
        (m) => RestaurantStockTakeModel.fromMap(m),
        (t) => t.takeId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant stock takes: $e");
    }

    try {
      await restoreBoxWithId(
        "restaurantStockTakeItems",
        Hive.box<RestaurantStockTakeItemModel>(
            HiveBoxNames.restaurantStockTakeItems),
        (m) => RestaurantStockTakeItemModel.fromMap(m),
        (ti) => ti.takeItemId,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant stock take items: $e");
    }
  }

  /// ---------------------------
  /// 🔧 RESTORE RETAIL DATA
  /// ---------------------------
  static Future<void> _restoreRetailData(Map<String, dynamic> data,
      {bool validateOnly = false, _RestoreRun? run}) async {
    final r = run ?? _RestoreRun(validateOnly: validateOnly);
    debugPrint(validateOnly
        ? "📦 Validating retail data..."
        : "📦 Restoring retail data...");

    // Helper function to restore typed boxes (converts Maps to model objects)
    // ⚠️ WARNING: without [idOf] this uses box.add() (auto-increment keys).
    // BKP-2: with [idOf] each record is keyed by its ID, none dropped
    // ([_putKeyedById]). Use restoreBoxTypedWithId() where repeats may collapse.
    Future<void> restoreBoxTyped<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap, {
        String Function(T)? idOf,
        }) async {
      if (data[keyName] == null) {
        // True replace: a box the backup does not carry is emptied.
        if (!validateOnly) {
          await r.write(keyName, box, () async {
            await box.clear();
            return 0;
          });
        }
        return;
      }
      if (validateOnly) {
        r.parse(box.name, keyName,
            () => _validateRecords(keyName, data[keyName], fromMap, idOf));
        return;
      }
      if (r.isTolerated(box.name)) {
        debugPrint("⚠️ $keyName could not be read — left unchanged");
        return;
      }

      debugPrint("📦 Restoring $keyName...");
      await r.write(keyName, box, () async {
        final items = data[keyName] as List;
        final models = [
          for (var item in items) fromMap(Map<String, dynamic>.from(item)),
        ];
        await box.clear();
        if (idOf != null) {
          await _putKeyedById(keyName, box, models, idOf);
        } else {
          for (final model in models) {
            await box.add(model);
          }
        }
        return models.length;
      });
    }

    // ✅ Helper function to restore typed boxes WITH ID as key
    // This preserves the original ID from the model as the Hive box key
    // Use this for models that are looked up by their ID (sales, customers, etc.)
    Future<void> restoreBoxTypedWithId<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        String Function(T) getIdFunc,
        ) async {
      if (data[keyName] == null) {
        // True replace: a box the backup does not carry is emptied.
        if (!validateOnly) {
          await r.write(keyName, box, () async {
            await box.clear();
            return 0;
          });
        }
        return;
      }
      if (validateOnly) {
        r.parse(box.name, keyName,
            () => _validateRecords(keyName, data[keyName], fromMap, getIdFunc));
        return;
      }
      if (r.isTolerated(box.name)) {
        debugPrint("⚠️ $keyName could not be read — left unchanged");
        return;
      }

      debugPrint("📦 Restoring $keyName (with ID keys)...");
      await r.write(keyName, box, () async {
        final items = data[keyName] as List;
        final byId = <String, T>{};
        for (var item in items) {
          final model = fromMap(Map<String, dynamic>.from(item));
          byId[getIdFunc(model)] = model;
        }
        await box.clear();
        for (final entry in byId.entries) {
          await box.put(entry.key, entry.value);  // ✅ Use ID as key, not auto-increment
        }
        return byId.length;
      });
    }

    // ✅ Restore Products (as ProductModel objects with ID keys)
    await restoreBoxTypedWithId(
      "products",
      Hive.box<ProductModel>(HiveBoxNames.products),
          (m) => ProductModel.fromMap(m),
          (p) => p.productId,  // Use productId as key
    );

    // ✅ Restore Variants (as VarianteModel objects with ID keys)
    await restoreBoxTypedWithId(
      "variants",
      Hive.box<VarianteModel>(HiveBoxNames.variants),
          (m) => VarianteModel.fromMap(m),
          (v) => v.varianteId,  // Use varianteId as key
    );

    // Report (never block) duplicate barcodes in the restored catalogue.
    //
    // A backup must ALWAYS restore -- refusing a row because the FILE contains a
    // duplicate would leave the catalogue half-populated, which is worse than
    // the duplicate. But a duplicate makes one variant permanently unscannable,
    // so it must not pass unnoticed either.
    if (!validateOnly) {
      try {
        final seen = <String, String>{};
        final dupes = <String>[];
        for (final v in Hive.box<VarianteModel>(HiveBoxNames.variants).values) {
          final code = v.barcode?.trim() ?? '';
          if (code.isEmpty) continue;
          final firstOwner = seen[code];
          if (firstOwner != null) {
            dupes.add('$code (${v.varianteId} vs $firstOwner)');
          } else {
            seen[code] = v.varianteId;
          }
        }
        if (dupes.isNotEmpty) {
          debugPrint("WARNING: restored catalogue has ${dupes.length} duplicate "
              "barcode(s); the second variant of each pair will not scan: "
              "${dupes.take(10).join(', ')}");
        }
      } catch (e) {
        debugPrint("Duplicate-barcode scan skipped: $e");
      }
    }

    // Restore App Counters (retail) -- see the export for why this matters.
    // Kept when the backup has none, so invoice numbers never go backwards.
    try {
      await _restoreKeyValueBox(data, "appCounters",
          Hive.box(HiveBoxNames.appCounters), r, clearWhenMissing: false);
    } catch (e) {
      debugPrint("Error restoring app counters: $e");
    }

    // ✅ Restore Cart Items
    await restoreBoxTyped(
      "cartItems",
      Hive.box<CartItemModel>(HiveBoxNames.cartItems),
          (m) => CartItemModel.fromMap(m),
      idOf: (c) => c.cartItemId, // BKP-2: CartRepository keys by cartItemId
    );

    // ✅ Restore Retail Categories
    if (data["categories"] != null) {
      try {
        final catBox = Hive.box<String>(HiveBoxNames.retailCategories);
        final names = r.parse(catBox.name, "categories", () {
          final items = data["categories"] as List;
          return [
            for (var item in items)
              if (item is Map && item.containsKey('name')) item['name'] as String,
          ];
        });
        if (!validateOnly && !r.isTolerated(catBox.name)) {
          debugPrint("📦 Restoring retail categories...");
          await r.write("categories", catBox, () async {
            await catBox.clear();
            for (final name in names) {
              await catBox.add(name);
            }
            return names.length;
          });
        }
      } catch (e) {
        debugPrint("⚠️ Error restoring retail categories: $e");
      }
    }

    // ✅ Restore Sales (as SaleModel objects with ID keys) - CRITICAL FIX
    await restoreBoxTypedWithId(
      "sales",
      Hive.box<SaleModel>(HiveBoxNames.sales),
          (m) => SaleModel.fromMap(m),
          (s) => s.saleId,  // Use saleId as key for proper lookup
    );

    // ✅ Restore Sale Items (as SaleItemModel objects with ID keys) - CRITICAL FIX
    await restoreBoxTypedWithId(
      "saleItems",
      Hive.box<SaleItemModel>(HiveBoxNames.saleItems),
          (m) => SaleItemModel.fromMap(m),
          (si) => si.saleItemId,  // Use saleItemId as key
    );

    // ✅ Restore Customers — shared box (restaurant + retail)
    await restoreBoxTypedWithId(
      "customers",
      Hive.box<Customer>(HiveBoxNames.customer),
          (m) => Customer.fromMap(m),
          (c) => c.customerId,  // Use customerId as key
    );

    // ✅ Restore Suppliers (as SupplierModel objects with ID keys)
    await restoreBoxTypedWithId(
      "suppliers",
      Hive.box<SupplierModel>(HiveBoxNames.suppliers),
          (m) => SupplierModel.fromMap(m),
          (s) => s.supplierId,  // Use supplierId as key
    );

    // Supplier balance journal, restored with the balances it explains. A
    // backup from before the ledger was exported has no key: clear instead of
    // keeping this device's rows, which would not add up to the restored
    // balances. An empty journal reads as "Balance brought forward" and is
    // backfilled as a real opening row on the next movement.
    try {
      final ledgerBox =
          Hive.box<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger);
      if (data["supplierLedger"] == null) {
        if (!validateOnly) {
          await r.write("supplierLedger", ledgerBox, () async {
            await ledgerBox.clear();
            return 0;
          });
        }
      } else {
        await restoreBoxTypedWithId(
          "supplierLedger",
          ledgerBox,
          (m) => SupplierLedgerEntryModel.fromMap(m),
          (e) => e.entryId,
        );
      }
    } catch (e) {
      debugPrint("⚠️ Error restoring supplier ledger: $e");
    }

    // Purchases/purchaseItems are no longer restored — the standalone Purchase
    // feature was removed. A backup taken before that still carries those keys;
    // skipping them is intentional, not an oversight.

    // Damaged-goods workflow raised from GRNs.
    await restoreBoxTypedWithId(
      "purchaseReturns",
      Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns),
      (m) => PurchaseReturnModel.fromMap(m),
      (r) => r.returnId,
    );
    await restoreBoxTypedWithId(
      "purchaseReturnItems",
      Hive.box<PurchaseReturnItemModel>(HiveBoxNames.purchaseReturnItems),
      (m) => PurchaseReturnItemModel.fromMap(m),
      (i) => i.returnItemId,
    );
    await restoreBoxTypedWithId(
      "supplierClaims",
      Hive.box<SupplierClaimModel>(HiveBoxNames.supplierClaims),
      (m) => SupplierClaimModel.fromMap(m),
      (c) => c.claimId,
    );
    await restoreBoxTypedWithId(
      "supplierClaimItems",
      Hive.box<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems),
      (m) => SupplierClaimItemModel.fromMap(m),
      (i) => i.claimItemId,
    );
    await restoreBoxTypedWithId(
      "inventoryLosses",
      Hive.box<InventoryLossModel>(HiveBoxNames.inventoryLosses),
      (m) => InventoryLossModel.fromMap(m),
      (l) => l.lossId,
    );

    // Manual stock adjustment audit trail.
    try {
      await restoreBoxTypedWithId(
        "stockMovements",
        Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements),
        (m) => StockMovementModel.fromMap(m),
        (m) => m.id,
      );
    } catch (e) {
      debugPrint("⚠️ Error restoring stock movements: $e");
    }

    // Cash drawer movements. A backup from before retail exported them has no
    // key: clear rather than keep this device's rows, which belong to a
    // different point in time than the restored sales.
    try {
      final cashBox =
          Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
      if (data["cashMovements"] == null) {
        if (!validateOnly) {
          await r.write("cashMovements", cashBox, () async {
            await cashBox.clear();
            return 0;
          });
        }
      } else {
        await restoreBoxTypedWithId(
          "cashMovements",
          cashBox,
          (m) => CashMovementModel.fromMap(m),
          (cm) => cm.id,
        );
      }
    } catch (e) {
      debugPrint("⚠️ Error restoring cash movements: $e");
    }

    // Physical stock count paperwork.
    await restoreBoxTypedWithId(
      "stockTakes",
      Hive.box<StockTakeModel>(HiveBoxNames.stockTakes),
      (m) => StockTakeModel.fromMap(m),
      (t) => t.takeId,
    );
    await restoreBoxTypedWithId(
      "stockTakeItems",
      Hive.box<StockTakeItemModel>(HiveBoxNames.stockTakeItems),
      (m) => StockTakeItemModel.fromMap(m),
      (i) => i.takeItemId,
    );

    // ✅ Restore EOD Reports - hardcoded for retail mode (we're inside _restoreRetailData)
    try {
      final eodBox = Hive.box<EndOfDayReport>('eodBox');
      await restoreBoxTyped("eodReports", eodBox, (m) => EndOfDayReport.fromMap(m),
          idOf: (e) => e.reportId); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring EOD reports: $e");
    }

    // ✅ Restore Expense Categories (uses typed box with registered adapter)
    try {
      final expenseCatBox = Hive.box<ExpenseCategory>('expenseCategory');
      await restoreBoxTyped("expenseCategories", expenseCatBox, (m) => ExpenseCategory.fromMap(m),
          idOf: (c) => c.id); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring expense categories: $e");
    }

    // ✅ Restore Expenses (uses typed box with registered adapter)
    try {
      final expenseBox = Hive.box<Expense>('expenseBox');
      await restoreBoxTyped("expenses", expenseBox, (m) => Expense.fromMap(m),
          idOf: (e) => e.id); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring expenses: $e");
    }

    // ✅ Restore Hold Sales & Hold Sale Items
    try {
      await restoreBoxTyped("holdSales", Hive.box<HoldSaleModel>(HiveBoxNames.holdSales), (m) => HoldSaleModel.fromMap(m),
          idOf: (h) => h.holdSaleId); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring hold sales: $e");
    }

    try {
      await restoreBoxTyped("holdSaleItems", Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems), (m) => HoldSaleItemModel.fromMap(m),
          idOf: (i) => i.holdSaleItemId); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring hold sale items: $e");
    }

    // ✅ Restore Purchase Orders & Purchase Order Items (with ID keys)
    try {
      await restoreBoxTypedWithId("purchaseOrders", Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders), (m) => PurchaseOrderModel.fromMap(m), (po) => po.poId);
    } catch (e) {
      debugPrint("⚠️ Error restoring purchase orders: $e");
    }

    try {
      await restoreBoxTypedWithId("purchaseOrderItems", Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems), (m) => PurchaseOrderItemModel.fromMap(m), (poi) => poi.poItemId);
    } catch (e) {
      debugPrint("⚠️ Error restoring purchase order items: $e");
    }

    // ✅ Restore GRNs & GRN Items (with ID keys)
    try {
      await restoreBoxTypedWithId("grns", Hive.box<GRNModel>(HiveBoxNames.grns), (m) => GRNModel.fromMap(m), (g) => g.grnId);
    } catch (e) {
      debugPrint("⚠️ Error restoring GRNs: $e");
    }

    try {
      await restoreBoxTypedWithId("grnItems", Hive.box<GRNItemModel>(HiveBoxNames.grnItems), (m) => GRNItemModel.fromMap(m), (gi) => gi.grnItemId);
    } catch (e) {
      debugPrint("⚠️ Error restoring GRN items: $e");
    }

    // ✅ Restore Bundles & Kit Assemblies (with ID keys)
    try {
      await restoreBoxTypedWithId("bundles", Hive.box<RetailBundleModel>(HiveBoxNames.bundles), (m) => RetailBundleModel.fromMap(m), (b) => b.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring bundles: $e");
    }

    try {
      await restoreBoxTypedWithId("kitAssemblies", Hive.box<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies), (m) => RetailKitAssemblyModel.fromMap(m), (k) => k.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring kit assemblies: $e");
    }

    // ✅ Restore Categories — shared box (restaurant + retail). Restaurant's
    // restore of this same box (key "categories") lives in
    // `_restoreRestaurantData`; this function needs its own copy since only
    // one of the two restore functions runs per import.
    try {
      await restoreBoxTypedWithId("categories", Hive.box<Category>(HiveBoxNames.category), (m) => Category.fromMap(m), (c) => c.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring categories: $e");
    }

    // ✅ Restore Payment Entries
    try {
      await restoreBoxTyped("paymentEntries", Hive.box<PaymentEntryModel>(HiveBoxNames.paymentEntries), (m) => PaymentEntryModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring payment entries: $e");
    }

    // ✅ Restore Credit Payments
    try {
      await restoreBoxTyped("creditPayments", Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments), (m) => CreditPaymentModel.fromMap(m),
          idOf: (c) => c.paymentId); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring credit payments: $e");
    }

    // ✅ Restore Attributes, Attribute Values, Product Attributes (with ID keys)
    try {
      await restoreBoxTypedWithId("attributes", Hive.box<AttributeModel>(HiveBoxNames.attributes), (m) => AttributeModel.fromMap(m), (a) => a.attributeId);
    } catch (e) {
      debugPrint("⚠️ Error restoring attributes: $e");
    }

    try {
      await restoreBoxTypedWithId("attributeValues", Hive.box<AttributeValueModel>(HiveBoxNames.attributeValues), (m) => AttributeValueModel.fromMap(m), (av) => av.valueId);
    } catch (e) {
      debugPrint("⚠️ Error restoring attribute values: $e");
    }

    try {
      await restoreBoxTyped("productAttributes", Hive.box<ProductAttributeModel>(HiveBoxNames.productAttributes), (m) => ProductAttributeModel.fromMap(m),
          // BKP-2: the link's own id — attributeId points at the attribute.
          idOf: (a) => a.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring product attributes: $e");
    }

    // Staff — shared box (restaurant + retail). Restaurant's restore of this
    // same box (key "staffBox") lives in `_restoreRestaurantData`; this
    // function needs its own copy since only one of the two restore
    // functions runs per import (chosen by the backup's own origin mode).
    try {
      await restoreBoxTypedWithId("staffBox", Hive.box<StaffModel>(HiveBoxNames.staff), (m) => StaffModel.fromMap(m), (s) => s.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring staff: $e");
    }

    // Shifts + Attendance — shared boxes (restaurant + retail). Restaurant's
    // restore of the same keys lives in `_restoreRestaurantData`; this function
    // needs its own copy for the same reason Staff does. ID-keyed, never the
    // auto-increment `restoreBoxTyped` — that duplicates rows on re-import.
    try {
      await restoreBoxTypedWithId("shifts", Hive.box<ShiftModel>(HiveBoxNames.shift), (m) => ShiftModel.fromMap(m), (s) => s.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring shifts: $e");
    }

    try {
      await restoreBoxTypedWithId("restaurantAttendance", Hive.box<AttendanceModel>(HiveBoxNames.attendance), (m) => AttendanceModel.fromMap(m), (a) => a.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring attendance: $e");
    }

    // Tax — shared box (restaurant + retail). Restaurant's restore of this
    // same box (key "taxes") lives in `_restoreRestaurantData`; same reasoning
    // as Staff above.
    try {
      await restoreBoxTypedWithId("taxes", Hive.box<Tax>(HiveBoxNames.tax), (m) => Tax.fromMap(m), (t) => t.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring taxes: $e");
    }

    // ✅ Restore Billing Tabs
    try {
      await restoreBoxTyped("billingTabs", Hive.box<BillingTabModel>(HiveBoxNames.billingTabs), (m) => BillingTabModel.fromMap(m),
          idOf: (t) => t.id); // BKP-2
    } catch (e) {
      debugPrint("⚠️ Error restoring billing tabs: $e");
    }

    // ✅ Restore Day Management Box (opening balance)
    try {
      await _restoreKeyValueBox(data, "dayManagement",
          Hive.box(HiveBoxNames.dayManagementBox), r, clearWhenMissing: true);
    } catch (e) {
      debugPrint("⚠️ Error restoring day management: $e");
    }

    // ✅ Restore Day Sessions (shared box, referenced by dayManagement)
    try {
      await restoreBoxTypedWithId("restaurantSessions", Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions), (m) => RestaurantSessionModel.fromMap(m), (s) => s.sessionId);
    } catch (e) {
      debugPrint("⚠️ Error restoring sessions: $e");
    }

    // ✅ Restore Saved Printers (shared box)
    try {
      await restoreBoxTypedWithId("printers", Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters), (m) => SavedPrinterModel.fromMap(m), (p) => p.id);
    } catch (e) {
      debugPrint("⚠️ Error restoring printers: $e");
    }

    // Admin credential restores via the generic localPrefs restore (see
    // _restoreLocalSettings) — no explicit handling needed here.

    // Boxes were written directly above, so ProductStore's in-memory lists
    // still hold the pre-restore data (and detached objects after box.clear()).
    if (validateOnly) return;
    await _postRestoreStep(r, postStepProductList, () async {
      await productStore.loadProducts();
      await productStore.loadVariants();
    });

    debugPrint("✅ Full retail data restored successfully!");
  }

  /// ---------------------------
  /// 🔧 SYNC SHAREDPREFERENCES FROM BUSINESS DETAILS
  /// ---------------------------
  /// Retail side uses SharedPreferences for store information
  /// This method syncs SharedPreferences from BusinessDetails after restore
  static Future<void> _syncSharedPreferencesFromBusinessDetails() async {
    try {
      debugPrint("📦 Syncing SharedPreferences from BusinessDetails...");

      // Get BusinessDetails from Hive
      final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
      if (businessDetailsBox.isEmpty) {
        debugPrint("⚠️ BusinessDetails box is empty - nothing to sync");
        return;
      }

      final businessDetails = businessDetailsBox.values.first;
      final prefs = await SharedPreferences.getInstance();

      // Sync all store information fields
      if (businessDetails.storeName != null && businessDetails.storeName!.isNotEmpty) {
        await prefs.setString('store_name', businessDetails.storeName!);
        debugPrint("📦 Synced store name: ${businessDetails.storeName}");
      }

      if (businessDetails.ownerName != null && businessDetails.ownerName!.isNotEmpty) {
        await prefs.setString('store_owner_name', businessDetails.ownerName!);
        debugPrint("📦 Synced owner name: ${businessDetails.ownerName}");
      }

      if (businessDetails.address != null && businessDetails.address!.isNotEmpty) {
        await prefs.setString('store_address', businessDetails.address!);
        debugPrint("📦 Synced address: ${businessDetails.address}");
      }

      if (businessDetails.city != null && businessDetails.city!.isNotEmpty) {
        await prefs.setString('store_city', businessDetails.city!);
        debugPrint("📦 Synced city: ${businessDetails.city}");
      }

      if (businessDetails.state != null && businessDetails.state!.isNotEmpty) {
        await prefs.setString('store_state', businessDetails.state!);
        debugPrint("📦 Synced state: ${businessDetails.state}");
      }

      if (businessDetails.pincode != null && businessDetails.pincode!.isNotEmpty) {
        await prefs.setString('store_pincode', businessDetails.pincode!);
        debugPrint("📦 Synced pincode: ${businessDetails.pincode}");
      }

      if (businessDetails.phone != null && businessDetails.phone!.isNotEmpty) {
        await prefs.setString('store_phone', businessDetails.phone!);
        debugPrint("📦 Synced phone: ${businessDetails.phone}");
      }

      if (businessDetails.email != null && businessDetails.email!.isNotEmpty) {
        await prefs.setString('store_email', businessDetails.email!);
        debugPrint("📦 Synced email: ${businessDetails.email}");
      }

      if (businessDetails.gstin != null && businessDetails.gstin!.isNotEmpty) {
        await prefs.setString('store_gst_number', businessDetails.gstin!);
        debugPrint("📦 Synced GST number: ${businessDetails.gstin}");
      }

      debugPrint("✅ SharedPreferences synced successfully from BusinessDetails");
    } catch (e, stackTrace) {
      debugPrint("⚠️ Error syncing SharedPreferences: $e");
      debugPrint("Stack trace: $stackTrace");
      // BKP-9: the caller reports it as a post-restore warning; the restore
      // itself continues.
      rethrow;
    }
  }
}