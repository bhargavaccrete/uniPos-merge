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
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
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
import 'package:billberrylite/data/models/restaurant/db/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_handover_model.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/restaurant/db/attendance_model.dart';

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

// Decodes a password-protected (WinZip-AES) ZIP → file entries (CPU-heavy, runs
// in an isolate). [password] decrypts each entry's content.
List<Map<String, dynamic>> _decodeZipInIsolate((List<int>, String?) args) {
  final (zipBytes, password) = args;
  final archive = ZipDecoder().decodeBytes(zipBytes, password: password);
  return archive
      .where((f) => f.content != null)
      .map((f) => {'name': f.name, 'bytes': f.content as List<int>})
      .toList();
}

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

  /// ---------------------------
  /// ✅ EXPORT TO DOWNLOADS (AUTO-SAVE)
  /// ---------------------------
  /// Automatically saves backup to Downloads folder
  /// Returns the file path or null if failed
  static Future<String?> exportToDownloads({bool includeImages = true}) async {
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return null;
    if (kIsWeb) {
      return await _exportForWeb();
    }

    try {
      debugPrint("📦 Starting backup to Downloads (images: $includeImages)...");

      // Collect all data
      final data = await _collectAllData();

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
      final data = await _collectAllData();
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
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return null;
    if (kIsWeb) {
      return await _exportForWeb();
    }

    try {
      debugPrint("📦 Starting backup to custom folder: $folderPath");

      // Collect all data
      final data = await _collectAllData();

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
    if (!PlanEnforce.allows(EntKeys.dataBackup)) return null;
    if (kIsWeb) return await _exportForWeb();
    try {
      final data = await _collectAllData();
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
      Map<String, dynamic> data;

      if (fileName.toLowerCase().endsWith('.json')) {
        // Plain-JSON backups are unencrypted — rejected.
        throw Exception(_unencryptedMsg);
      }

      final String? password = await _showPasswordDialog(context);
      if (password == null) throw Exception("Restore cancelled: no password");

      List<Map<String, dynamic>> entries;
      if (BackupEncryptionService.isEncryptedBlob(rawBytes)) {
        // New protected backup: decrypt the outer layer first
        final decryptedZip = BackupEncryptionService.decryptBytes(rawBytes, password);
        if (decryptedZip == null) {
          throw Exception("Wrong password — cannot open backup");
        }
        try {
          entries = _decodeZipInIsolate((decryptedZip.toList(), password));
        } catch (_) {
          throw Exception("Wrong password or corrupted backup entries");
        }
      } else {
        // Legacy backup: check if plain
        if (_looksLikePlainBackup(rawBytes.toList())) {
          throw Exception(_unencryptedMsg);
        }
        try {
          entries = _decodeZipInIsolate((rawBytes.toList(), password));
        } catch (_) {
          throw Exception("Wrong password — cannot open backup");
        }
      }

      data = await _restoreEntries(entries, password);

      final backupMode = _detectModeFromBackup(data);
      debugPrint("📦 Web import: detected mode = $backupMode");
      await _ensureBoxesOpened(backupMode);
      await _restoreAllData(data, backupMode);
      debugPrint("✅ Web import completed!");
      return true;
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

      Map<String, dynamic> data;

      if (extension == '.json') {
        // Plain-JSON backups are unencrypted — rejected.
        throw Exception(_unencryptedMsg);
      } else {
        // Pass a password dialog as the provider for encrypted backups
        data = await _extractZipBackup(
          file,
          passwordProvider: () => _showPasswordDialog(context),
        );
      }

      final backupMode = _detectModeFromBackup(data);
      debugPrint("📦 Detected backup mode: $backupMode");

      await _ensureBoxesOpened(backupMode);
      await _restoreAllData(data, backupMode);

      debugPrint("✅ Import completed successfully!");
      return true;
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

  /// ---------------------------
  /// 🔧 COLLECT ALL DATA (MODE-AWARE)
  /// ---------------------------
  static Future<Map<String, dynamic>> _collectAllData() async {
    final exportMap = <String, List<Map<String, dynamic>>>{};

    if (AppConfig.isRestaurant) {
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
      }

      // Expense Categories (using helper - mode aware)
      try {
        final expenseCatBox = HiveExpenseCat.getECategory();
        exportMap["expenseCategories"] = expenseCatBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Expense category box error: $e");
        exportMap["expenseCategories"] = [];
      }

      // Expenses (using helper - mode aware)
      try {
        final expenseBox = HiveExpenceL.getexpenseBox();
        exportMap["expenses"] = expenseBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Expense box error: $e");
        exportMap["expenses"] = [];
      }

      // Tables
      try {
        exportMap["tables"] = Hive.box<TableModel>("tablesBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Tables box not found: $e");
        exportMap["tables"] = [];
      }

      // EOD Reports (using mode-aware box name)
      try {
        final eodBoxName = AppConfig.isRetail ? 'eodBox' : 'restaurant_eodBox';
        final eodBox = Hive.box<EndOfDayReport>(eodBoxName);
        exportMap["eodReports"] = eodBox.values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ EOD box error: $e");
        exportMap["eodReports"] = [];
      }

      // Current Orders
      try {
        exportMap["orders"] = Hive.box<OrderModel>("orderBox").values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint("⚠️ Orders box not found: $e");
        exportMap["orders"] = [];
      }

      // ✅ Restaurant Cart
      try {
        exportMap["restaurantCart"] = Hive.box<CartItem>(HiveBoxNames.restaurantCart).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Restaurant Cart exported: ${exportMap["restaurantCart"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Cart box not found: $e");
        exportMap["restaurantCart"] = [];
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
      }

      // ✅ Test Bill Box
      try {
        final box = Hive.box<TestBillModel>(HiveBoxNames.testBillBox);
        exportMap["testBillBox"] = box.values.map((TestBillModel e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Test Bill Box exported: ${exportMap["testBillBox"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Test Bill Box error: $e");
        exportMap["testBillBox"] = [];
      }

      // ✅ Shifts
      try {
        exportMap["shifts"] = Hive.box<ShiftModel>(HiveBoxNames.restaurantShift)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Shifts exported: ${exportMap["shifts"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Shifts box error: $e");
        exportMap["shifts"] = [];
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
      }

      // Restaurant Attendance
      try {
        exportMap["restaurantAttendance"] = Hive.box<AttendanceModel>(HiveBoxNames.restaurantAttendance)
            .values
            .map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>)
            .toList();
        debugPrint("📦 Attendance exported: ${exportMap["restaurantAttendance"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attendance box error: $e");
        exportMap["restaurantAttendance"] = [];
      }

      // Recipes (BOM) & Recipe Productions — inventory/recipe management
      try {
        exportMap["recipes"] = Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Recipes exported: ${exportMap["recipes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Recipes box error: $e");
        exportMap["recipes"] = [];
      }

      try {
        exportMap["recipeProductions"] = Hive.box<RecipeProductionModel>(HiveBoxNames.restaurantRecipeProductions).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Recipe Productions exported: ${exportMap["recipeProductions"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Recipe Productions box error: $e");
        exportMap["recipeProductions"] = [];
      }

      // Restaurant Suppliers, Purchase Orders & GRNs
      try {
        exportMap["restaurantSuppliers"] = Hive.box<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Suppliers exported: ${exportMap["restaurantSuppliers"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Suppliers box error: $e");
        exportMap["restaurantSuppliers"] = [];
      }

      try {
        exportMap["restaurantPurchaseOrders"] = Hive.box<RestaurantPurchaseOrderModel>(HiveBoxNames.restaurantPurchaseOrders).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Orders exported: ${exportMap["restaurantPurchaseOrders"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Orders box error: $e");
        exportMap["restaurantPurchaseOrders"] = [];
      }

      try {
        exportMap["restaurantPurchaseOrderItems"] = Hive.box<RestaurantPurchaseOrderItemModel>(HiveBoxNames.restaurantPurchaseOrderItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Order Items exported: ${exportMap["restaurantPurchaseOrderItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Order Items box error: $e");
        exportMap["restaurantPurchaseOrderItems"] = [];
      }

      try {
        exportMap["restaurantGrns"] = Hive.box<RestaurantGRNModel>(HiveBoxNames.restaurantGrns).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant GRNs exported: ${exportMap["restaurantGrns"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant GRNs box error: $e");
        exportMap["restaurantGrns"] = [];
      }

      try {
        exportMap["restaurantGrnItems"] = Hive.box<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant GRN Items exported: ${exportMap["restaurantGrnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant GRN Items box error: $e");
        exportMap["restaurantGrnItems"] = [];
      }

      // Supplier balance journal — must travel with the suppliers themselves,
      // or a restored balance has nothing explaining how it got there.
      try {
        exportMap["restaurantSupplierLedger"] = Hive.box<RestaurantSupplierLedgerEntryModel>(HiveBoxNames.restaurantSupplierLedger).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Supplier Ledger exported: ${exportMap["restaurantSupplierLedger"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Supplier Ledger box error: $e");
        exportMap["restaurantSupplierLedger"] = [];
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
      }

      try {
        exportMap["restaurantPurchaseReturnItems"] = Hive.box<RestaurantPurchaseReturnItemModel>(HiveBoxNames.restaurantPurchaseReturnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Purchase Return Items exported: ${exportMap["restaurantPurchaseReturnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Purchase Return Items box error: $e");
        exportMap["restaurantPurchaseReturnItems"] = [];
      }

      try {
        exportMap["restaurantSupplierClaims"] = Hive.box<RestaurantSupplierClaimModel>(HiveBoxNames.restaurantSupplierClaims).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Supplier Claims exported: ${exportMap["restaurantSupplierClaims"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Supplier Claims box error: $e");
        exportMap["restaurantSupplierClaims"] = [];
      }

      try {
        exportMap["restaurantSupplierClaimItems"] = Hive.box<RestaurantSupplierClaimItemModel>(HiveBoxNames.restaurantSupplierClaimItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Supplier Claim Items exported: ${exportMap["restaurantSupplierClaimItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Supplier Claim Items box error: $e");
        exportMap["restaurantSupplierClaimItems"] = [];
      }

      try {
        exportMap["restaurantInventoryLosses"] = Hive.box<RestaurantInventoryLossModel>(HiveBoxNames.restaurantInventoryLosses).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Inventory Losses exported: ${exportMap["restaurantInventoryLosses"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Inventory Losses box error: $e");
        exportMap["restaurantInventoryLosses"] = [];
      }

      try {
        exportMap["restaurantStockTakes"] = Hive.box<RestaurantStockTakeModel>(HiveBoxNames.restaurantStockTakes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Stock Takes exported: ${exportMap["restaurantStockTakes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Stock Takes box error: $e");
        exportMap["restaurantStockTakes"] = [];
      }

      try {
        exportMap["restaurantStockTakeItems"] = Hive.box<RestaurantStockTakeItemModel>(HiveBoxNames.restaurantStockTakeItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Restaurant Stock Take Items exported: ${exportMap["restaurantStockTakeItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Restaurant Stock Take Items box error: $e");
        exportMap["restaurantStockTakeItems"] = [];
      }

    } else if (AppConfig.isRetail) {
      debugPrint("📦 Collecting RETAIL data...");

      // Products
      try {
        exportMap["products"] = Hive.box<ProductModel>(HiveBoxNames.products).values.map((e) => e.toProduct()).toList();
      } catch (e) {
        debugPrint("⚠️ Products box error: $e");
        exportMap["products"] = [];
      }

      // Variants
      try {
        exportMap["variants"] = Hive.box<VarianteModel>(HiveBoxNames.variants).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Variants box error: $e");
        exportMap["variants"] = [];
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
      }

      // Sales
      try {
        exportMap["sales"] = Hive.box<SaleModel>(HiveBoxNames.sales).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Sales box error: $e");
        exportMap["sales"] = [];
      }

      // Sale Items
      try {
        exportMap["saleItems"] = Hive.box<SaleItemModel>(HiveBoxNames.saleItems).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Sale Items box error: $e");
        exportMap["saleItems"] = [];
      }

      // Customers — shared box (restaurant + retail)
      try {
        exportMap["customers"] = Hive.box<Customer>(HiveBoxNames.customer).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Customers box error: $e");
        exportMap["customers"] = [];
      }

      // Suppliers
      try {
        exportMap["suppliers"] = Hive.box<SupplierModel>(HiveBoxNames.suppliers).values.map((e) => e.toMap()).toList();
      } catch (e) {
        debugPrint("⚠️ Suppliers box error: $e");
        exportMap["suppliers"] = [];
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
        exportMap["purchaseReturnItems"] = [];
        exportMap["supplierClaims"] = [];
        exportMap["supplierClaimItems"] = [];
        exportMap["inventoryLosses"] = [];
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
        exportMap["stockTakeItems"] = [];
      }

      // Categories (String list)
      try {
        final catBox = Hive.box<String>(HiveBoxNames.retailCategories);
        exportMap["categories"] = catBox.values.map((c) => {'name': c}).toList();
      } catch (e) {
        debugPrint("⚠️ Retail Categories box error: $e");
        exportMap["categories"] = [];
      }

      // ✅ Cart Items
      try {
        exportMap["cartItems"] = Hive.box<CartItemModel>(HiveBoxNames.cartItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Cart Items exported: ${exportMap["cartItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Cart Items box error: $e");
        exportMap["cartItems"] = [];
      }

      // ✅ NEW: Add EOD Reports for Retail
      try {
        final eodBoxName = AppConfig.isRetail ? 'eodBox' : 'restaurant_eodBox';
        final eodBox = Hive.box<EndOfDayReport>(eodBoxName);
        exportMap["eodReports"] = eodBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail EOD Reports exported: ${exportMap["eodReports"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail EOD box error: $e");
        exportMap["eodReports"] = [];
      }

      // ✅ NEW: Add Expense Categories for Retail
      try {
        final expenseCatBox = HiveExpenseCat.getECategory();
        exportMap["expenseCategories"] = expenseCatBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Expense Categories exported: ${exportMap["expenseCategories"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Expense category box error: $e");
        exportMap["expenseCategories"] = [];
      }

      // ✅ NEW: Add Expenses for Retail
      try {
        final expenseBox = HiveExpenceL.getexpenseBox();
        exportMap["expenses"] = expenseBox.values.map((e) => e.toMap()).toList();
        debugPrint("📦 Retail Expenses exported: ${exportMap["expenses"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Retail Expense box error: $e");
        exportMap["expenses"] = [];
      }

      // ✅ Hold Sales & Hold Sale Items
      try {
        exportMap["holdSales"] = Hive.box<HoldSaleModel>(HiveBoxNames.holdSales).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Hold Sales exported: ${exportMap["holdSales"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Hold Sales box error: $e");
        exportMap["holdSales"] = [];
      }

      try {
        exportMap["holdSaleItems"] = Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Hold Sale Items exported: ${exportMap["holdSaleItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Hold Sale Items box error: $e");
        exportMap["holdSaleItems"] = [];
      }

      // ✅ Purchase Orders & Purchase Order Items
      try {
        exportMap["purchaseOrders"] = Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Purchase Orders exported: ${exportMap["purchaseOrders"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Purchase Orders box error: $e");
        exportMap["purchaseOrders"] = [];
      }

      try {
        exportMap["purchaseOrderItems"] = Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Purchase Order Items exported: ${exportMap["purchaseOrderItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Purchase Order Items box error: $e");
        exportMap["purchaseOrderItems"] = [];
      }

      // ✅ GRNs & GRN Items
      try {
        exportMap["grns"] = Hive.box<GRNModel>(HiveBoxNames.grns).values.map((e) => e.toMap()).toList();
        debugPrint("📦 GRNs exported: ${exportMap["grns"]!.length}");
      } catch (e) {
        debugPrint("⚠️ GRNs box error: $e");
        exportMap["grns"] = [];
      }

      try {
        exportMap["grnItems"] = Hive.box<GRNItemModel>(HiveBoxNames.grnItems).values.map((e) => e.toMap()).toList();
        debugPrint("📦 GRN Items exported: ${exportMap["grnItems"]!.length}");
      } catch (e) {
        debugPrint("⚠️ GRN Items box error: $e");
        exportMap["grnItems"] = [];
      }

      // ✅ Bundles & Kit Assemblies (bundle/repack inventory)
      try {
        exportMap["bundles"] = Hive.box<RetailBundleModel>(HiveBoxNames.bundles).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Bundles exported: ${exportMap["bundles"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Bundles box error: $e");
        exportMap["bundles"] = [];
      }

      try {
        exportMap["kitAssemblies"] = Hive.box<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Kit Assemblies exported: ${exportMap["kitAssemblies"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Kit Assemblies box error: $e");
        exportMap["kitAssemblies"] = [];
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
      }

      // ✅ Payment Entries
      try {
        exportMap["paymentEntries"] = Hive.box<PaymentEntryModel>(HiveBoxNames.paymentEntries).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Payment Entries exported: ${exportMap["paymentEntries"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Payment Entries box error: $e");
        exportMap["paymentEntries"] = [];
      }

      // ✅ Credit Payments
      try {
        exportMap["creditPayments"] = Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Credit Payments exported: ${exportMap["creditPayments"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Credit Payments box error: $e");
        exportMap["creditPayments"] = [];
      }

      // ✅ Attributes, Attribute Values, Product Attributes
      try {
        exportMap["attributes"] = Hive.box<AttributeModel>(HiveBoxNames.attributes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Attributes exported: ${exportMap["attributes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attributes box error: $e");
        exportMap["attributes"] = [];
      }

      try {
        exportMap["attributeValues"] = Hive.box<AttributeValueModel>(HiveBoxNames.attributeValues).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Attribute Values exported: ${exportMap["attributeValues"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Attribute Values box error: $e");
        exportMap["attributeValues"] = [];
      }

      try {
        exportMap["productAttributes"] = Hive.box<ProductAttributeModel>(HiveBoxNames.productAttributes).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Product Attributes exported: ${exportMap["productAttributes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Product Attributes box error: $e");
        exportMap["productAttributes"] = [];
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
      }

      // Tax — shared box (restaurant + retail), same reasoning as Staff above.
      try {
        exportMap["taxes"] = Hive.box<Tax>(HiveBoxNames.tax).values.map((e) => _deepCleanMap(e.toMap()) as Map<String, dynamic>).toList();
        debugPrint("📦 Taxes exported: ${exportMap["taxes"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Tax box error: $e");
        exportMap["taxes"] = [];
      }

      // ✅ Billing Tabs
      try {
        exportMap["billingTabs"] = Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).values.map((e) => e.toMap()).toList();
        debugPrint("📦 Billing Tabs exported: ${exportMap["billingTabs"]!.length}");
      } catch (e) {
        debugPrint("⚠️ Billing Tabs box error: $e");
        exportMap["billingTabs"] = [];
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
    }

    // Business Details Box
    try {
      final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
      exportMap["businessDetails"] = businessDetailsBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Business details exported: ${exportMap["businessDetails"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Business details box error: $e");
      exportMap["businessDetails"] = [];
    }

    // Business Type Box
    try {
      final businessTypeBox = Hive.box<BusinessType>(HiveBoxNames.businessTypeBox);
      exportMap["businessTypes"] = businessTypeBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Business types exported: ${exportMap["businessTypes"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Business type box error: $e");
      exportMap["businessTypes"] = [];
    }

    // Tax Details Box
    try {
      final taxBox = Hive.box<TaxDetails>(HiveBoxNames.taxBox);
      exportMap["taxDetails"] = taxBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Tax details exported: ${exportMap["taxDetails"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Tax details box error: $e");
      exportMap["taxDetails"] = [];
    }

    // Payment Methods Box (shared)
    try {
      final paymentMethodsBox = Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods);
      exportMap["paymentMethods"] = paymentMethodsBox.values.map((e) => e.toMap()).toList();
      debugPrint("📦 Payment methods exported: ${exportMap["paymentMethods"]!.length} items");
    } catch (e) {
      debugPrint("⚠️ Payment methods box error: $e");
      exportMap["paymentMethods"] = [];
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
    }

    // ✅ Backup password (flutter_secure_storage) so a restored device keeps it.
    try {
      final pwd = await BackupEncryptionService.getStoredPassword();
      exportMap["secureCreds"] =
          (pwd != null && pwd.isNotEmpty) ? [{'backupPassword': pwd}] : [];
    } catch (e) {
      debugPrint("⚠️ Secure creds export error: $e");
      exportMap["secureCreds"] = [];
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
        final downloadsPath = '/storage/emulated/0/Download';
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

      await outputFile.writeAsBytes(protectedZipData);

      debugPrint("✅ Backup saved: ${outputFile.path}");
      debugPrint("✅ Encrypted: $isEncrypted");

      return outputFile.path;
    } catch (e, stackTrace) {
      debugPrint("❌ ZIP backup creation failed: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// ---------------------------
  /// 🔧 EXTRACT ZIP BACKUP
  /// ---------------------------
  /// Backups are password-protected (AES) zips. We prompt for the password,
  /// then decrypt the whole archive with it. [passwordProvider] returns the
  /// entered password, or null to cancel.
  static Future<Map<String, dynamic>> _extractZipBackup(
    File file, {
    Future<String?> Function()? passwordProvider,
  }) async {
    final zipBytes = await file.readAsBytes();

    if (passwordProvider == null) {
      throw Exception("Backup is encrypted but no password provider was given");
    }
    final password = await passwordProvider();
    if (password == null) throw Exception("Restore cancelled: no password entered");

    List<Map<String, dynamic>> entries;
    if (BackupEncryptionService.isEncryptedBlob(zipBytes)) {
      // New protected backup: decrypt the outer layer first
      final decryptedZip = BackupEncryptionService.decryptBytes(zipBytes, password);
      if (decryptedZip == null) {
        throw Exception("Wrong password — cannot open backup");
      }
      try {
        entries = await compute(_decodeZipInIsolate, (decryptedZip.toList(), password));
      } catch (_) {
        throw Exception("Wrong password or corrupted backup entries");
      }
    } else {
      // Legacy backup: check if plain
      if (_looksLikePlainBackup(zipBytes)) {
        throw Exception(_unencryptedMsg);
      }
      try {
        entries = await compute(_decodeZipInIsolate, (zipBytes.toList(), password));
      } catch (_) {
        throw Exception("Wrong password — cannot open backup");
      }
    }

    return _restoreEntries(entries, password);
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
  static Future<Map<String, dynamic>> _restoreEntries(
      List<Map<String, dynamic>> entries, String password) async {
    Directory? productDir;
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      productDir = Directory('${appDir.path}/product_images');
    }
    List<int>? dataBytes;

    for (final f in entries) {
      final name = f['name'] as String;
      final bytes = f['bytes'] as List<int>;

      if (name.startsWith('item_img_') || name.startsWith('prod_img_')) {
        if (productDir == null) continue; // no filesystem on web
        if (!productDir.existsSync()) productDir.createSync(recursive: true);
        final imgName = name.startsWith('prod_img_')
            ? name.replaceFirst('prod_img_', '')
            : name;
        File('${productDir.path}/$imgName')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
      } else if (name.toLowerCase() == 'data.json') {
        dataBytes = bytes;
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
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } else {
      return jsonMap;
    }
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
  static Future<void> _restoreAllData(Map<String, dynamic> data, String backupMode) async {
    debugPrint("📦 Restoring data for mode: $backupMode");

    // Validate backup data structure
    if (!data.containsKey('data') || data['data'] == null) {
      debugPrint("❌ Invalid backup format: Missing 'data' key");
      debugPrint("📦 Backup structure: ${data.keys.toList()}");

      // Check if this is a legacy format (direct data without wrapper)
      if (data.containsKey('products') || data.containsKey('items') || data.containsKey('categories')) {
        debugPrint("📦 Detected legacy backup format (unwrapped data)");
        // Treat the entire data object as the backup data
        await _handleLegacyRestore(data, backupMode);
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
      await _restoreRestaurantData(backupData);
    } else if (backupMode == 'retail') {
      await _restoreRetailData(backupData);
    } else {
      throw Exception("Unsupported backup mode: $backupMode");
    }

    // ==================== RESTORE COMMON BOXES (both retail and restaurant) ====================

    // ✅ Restore app config FIRST (CRITICAL - contains business mode and setup status)
    if (backupData["appConfig"] != null && backupData["appConfig"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring app config...");
        final appConfigBox = Hive.box(HiveBoxNames.appConfig);
        await appConfigBox.clear();
        final appConfigData = backupData["appConfig"][0] as Map<String, dynamic>;
        for (var entry in appConfigData.entries) {
          await appConfigBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App config restored: ${appConfigData.keys.length} entries");
        debugPrint("📦 Business mode: ${appConfigBox.get('businessMode')}");
        debugPrint("📦 Setup complete: ${appConfigBox.get('isSetupComplete')}");
      } catch (e) {
        debugPrint("⚠️ Error restoring app config: $e");
      }
    }

    // Restore app state
    if (backupData["appState"] != null && backupData["appState"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring app state...");
        final appStateBox = Hive.box("app_state");
        await appStateBox.clear();
        final appStateData = backupData["appState"][0] as Map<String, dynamic>;
        for (var entry in appStateData.entries) {
          await appStateBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App state restored: ${appStateData.keys.length} settings");
      } catch (e) {
        debugPrint("⚠️ Error restoring app state: $e");
      }
    }

    // Restore store box (legacy store info)
    if (backupData["storeBox"] != null && backupData["storeBox"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring store box...");
        final storeBox = Hive.box(HiveBoxNames.storeBox);
        await storeBox.clear();
        final storeData = backupData["storeBox"][0] as Map<String, dynamic>;
        for (var entry in storeData.entries) {
          await storeBox.put(entry.key, entry.value);
        }
        debugPrint("📦 Store box restored: ${storeData.keys.length} entries");
      } catch (e) {
        debugPrint("⚠️ Error restoring store box: $e");
      }
    }

    // Restore business details
    if (backupData["businessDetails"] != null && backupData["businessDetails"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring business details...");
        final businessDetailsBox = Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
        await businessDetailsBox.clear();
        for (var item in backupData["businessDetails"]) {
          final map = Map<String, dynamic>.from(item);
          await businessDetailsBox.add(BusinessDetails.fromMap(map));
        }
        debugPrint("📦 Business details restored: ${backupData["businessDetails"].length} items");

        // ✅ CRITICAL: Sync SharedPreferences from BusinessDetails for retail
        // Retail side uses SharedPreferences for store info, not Hive
        // This must happen AFTER BusinessDetails is restored
        if (backupMode == 'retail') {
          await _syncSharedPreferencesFromBusinessDetails();
        }
      } catch (e) {
        debugPrint("⚠️ Error restoring business details: $e");
      }
    }

    // Restore business types
    if (backupData["businessTypes"] != null && backupData["businessTypes"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring business types...");
        final businessTypeBox = Hive.box<BusinessType>(HiveBoxNames.businessTypeBox);
        await businessTypeBox.clear();
        for (var item in backupData["businessTypes"]) {
          final map = Map<String, dynamic>.from(item);
          await businessTypeBox.add(BusinessType.fromMap(map));
        }
        debugPrint("📦 Business types restored: ${backupData["businessTypes"].length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring business types: $e");
      }
    }

    // Restore tax details
    if (backupData["taxDetails"] != null && backupData["taxDetails"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring tax details...");
        final taxBox = Hive.box<TaxDetails>(HiveBoxNames.taxBox);
        await taxBox.clear();
        for (var item in backupData["taxDetails"]) {
          final map = Map<String, dynamic>.from(item);
          await taxBox.add(TaxDetails.fromMap(map));
        }
        debugPrint("📦 Tax details restored: ${backupData["taxDetails"].length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring tax details: $e");
      }
    }

    // Restore payment methods
    if (backupData["paymentMethods"] != null && backupData["paymentMethods"].isNotEmpty) {
      try {
        debugPrint("📦 Restoring payment methods...");
        final paymentMethodsBox = Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods);
        await paymentMethodsBox.clear();
        for (var item in backupData["paymentMethods"]) {
          final map = Map<String, dynamic>.from(item);
          await paymentMethodsBox.add(pm.PaymentMethod.fromMap(map));
        }
        debugPrint("📦 Payment methods restored: ${backupData["paymentMethods"].length} items");
      } catch (e) {
        debugPrint("⚠️ Error restoring payment methods: $e");
      }
    }

    // ✅ CRITICAL: Update AppConfig with the correct business mode
    // Note: Only update if appConfig wasn't in the backup (for legacy backups)
    if (backupData["appConfig"] == null || backupData["appConfig"].isEmpty) {
      debugPrint("📦 AppConfig not found in backup - updating from detected mode: $backupMode");
      await _updateAppConfigFromBackup(backupMode);
    } else {
      debugPrint("📦 AppConfig already restored from backup - skipping manual update");
    }

    // ✅ Restore non-Hive settings (admin PIN, store/UPI, prefs, backup password)
    await _restoreLocalSettings(backupData);

    debugPrint("✅ Data restoration completed!");
  }

  /// Restores SharedPreferences (`localPrefs`) + the backup password
  /// (`secureCreds`) saved by `_collectAllData`. Re-applies the denylist so a
  /// tampered backup can't overwrite device id / license / printer keys.
  static Future<void> _restoreLocalSettings(Map<String, dynamic> backupData) async {
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
      // Don't throw - let the restore continue even if this fails
    }
  }

  /// ---------------------------
  /// 🔧 HANDLE LEGACY BACKUP RESTORE
  /// ---------------------------
  /// Handles restoration of legacy backup formats that don't have the wrapper structure
  static Future<void> _handleLegacyRestore(Map<String, dynamic> data, String backupMode) async {
    debugPrint("📦 Attempting legacy restore...");

    // Re-detect mode if unknown
    String mode = backupMode;
    if (mode == 'unknown') {
      if (data.containsKey('products') && data.containsKey('suppliers')) {
        mode = 'retail';
        debugPrint("📦 Detected retail mode from legacy backup");
      } else if (data.containsKey('items') || data.containsKey('tables')) {
        mode = 'restaurant';
        debugPrint("📦 Detected restaurant mode from legacy backup");
      } else {
        throw Exception("Cannot determine mode from legacy backup. Keys: ${data.keys.toList()}");
      }
    }

    // Ensure boxes are opened
    await _ensureBoxesOpened(mode);

    // Restore based on mode
    if (mode == 'restaurant') {
      await _restoreRestaurantData(data);
    } else if (mode == 'retail') {
      await _restoreRetailData(data);
    }

    // Update AppConfig with the correct business mode
    await _updateAppConfigFromBackup(mode);

    debugPrint("✅ Legacy backup restored successfully!");
  }

  /// ---------------------------
  /// 🔧 RESTORE RESTAURANT DATA
  /// ---------------------------
  static Future<void> _restoreRestaurantData(Map<String, dynamic> data) async {
    debugPrint("📦 Restoring restaurant data...");

    // Helper function to restore a box
    // ⚠️ WARNING: This uses box.add() which generates auto-increment keys
    // Use restoreBoxWithId() for models that need their ID as the key
    Future<void> restoreBox<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        ) async {
      if (data[keyName] == null) return;
      debugPrint("📦 Restoring $keyName...");
      await box.clear();
      final items = data[keyName] as List;
      // addAll = single batch write, far faster than N individual add() calls
      await box.addAll(items.map((item) => fromMap(Map<String, dynamic>.from(item))).toList());
      debugPrint("📦 $keyName: ${items.length} items restored");
    }

    Future<void> restoreBoxWithId<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        String Function(T) getIdFunc,
        ) async {
      if (data[keyName] == null) return;
      debugPrint("📦 Restoring $keyName (with ID keys)...");
      await box.clear();
      final items = data[keyName] as List;
      // putAll = single batch write, far faster than N individual put() calls
      final Map<String, T> batch = {};
      for (final item in items) {
        final model = fromMap(Map<String, dynamic>.from(item));
        batch[getIdFunc(model)] = model;
      }
      await box.putAll(batch);
      debugPrint("📦 $keyName: ${items.length} items restored with ID keys");
    }

    await restoreBoxWithId("categories", Hive.box<Category>(HiveBoxNames.category), (m) => Category.fromMap(m), (c) => c.id);
    await restoreBoxWithId("items", Hive.box<Items>("itemBoxs"), (m) => Items.fromMap(m), (i) => i.id);

    // Reload imageBytes for each item from its item_img_{id} file.
    // O(n) approach: build a key-by-ID lookup map first, then match files.
    try {
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
    } catch (e) {
      debugPrint("⚠️ Could not reload item images: $e");
    }
    await restoreBoxWithId("variants", Hive.box<VariantModel>("variante"), (m) => VariantModel.fromMap(m), (v) => v.id);
    await restoreBoxWithId("choices", Hive.box<ChoicesModel>("choice"), (m) => ChoicesModel.fromMap(m), (ch) => ch.id);
    await restoreBox("extras", Hive.box<Extramodel>("extra"), (m) => Extramodel.fromMap(m));
    await restoreBoxWithId("staffBox", Hive.box<StaffModel>(HiveBoxNames.staff), (m) => StaffModel.fromMap(m), (s) => s.id);
    await restoreBoxWithId("taxes", Hive.box<Tax>(HiveBoxNames.tax), (m) => Tax.fromMap(m), (t) => t.id);
    await restoreBoxWithId("expenseCategories", HiveExpenseCat.getECategory(), (m) => ExpenseCategory.fromMap(m), (ec) => ec.id);
    await restoreBoxWithId("expenses", HiveExpenceL.getexpenseBox(), (m) => Expense.fromMap(m), (e) => e.id);
    await restoreBoxWithId("tables", Hive.box<TableModel>("tablesBox"), (m) => TableModel.fromMap(m), (tb) => tb.id);

    // ✅ EOD Reports - hardcoded for restaurant mode (AppConfig not restored yet)
    await restoreBox("eodReports", Hive.box<EndOfDayReport>('restaurant_eodBox'), (m) => EndOfDayReport.fromMap(m));

    await restoreBoxWithId("pastOrders", Hive.box<PastOrderModel>("pastorderBox"), (m) => PastOrderModel.fromMap(m), (po) => po.id);
    await restoreBoxWithId("orders", Hive.box<OrderModel>("orderBox"), (m) => OrderModel.fromMap(m), (o) => o.id);

    // ✅ Restore Restaurant Cart
    try {
      await restoreBox("restaurantCart", Hive.box<CartItem>(HiveBoxNames.restaurantCart), (m) => CartItem.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring restaurant cart: $e");
    }

    // ✅ Restore App Counters
    try {
      if (data["appCounters"] != null && data["appCounters"].isNotEmpty) {
        debugPrint("📦 Restoring app counters...");
        final countersBox = Hive.box(HiveBoxNames.appCounters);
        await countersBox.clear();
        final countersData = data["appCounters"][0] as Map<String, dynamic>;
        for (var entry in countersData.entries) {
          await countersBox.put(entry.key, entry.value);
        }
        debugPrint("📦 App counters restored: ${countersData.keys.length} entries");
      }
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
        Hive.box<ShiftModel>(HiveBoxNames.restaurantShift),
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

    try {
      await restoreBoxWithId(
        "restaurantAttendance",
        Hive.box<AttendanceModel>(HiveBoxNames.restaurantAttendance),
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
  static Future<void> _restoreRetailData(Map<String, dynamic> data) async {
    debugPrint("📦 Restoring retail data...");

    // Helper function to restore typed boxes (converts Maps to model objects)
    // ⚠️ WARNING: This uses box.add() which generates auto-increment keys
    // Use restoreBoxTypedWithId() for models that need their ID as the key
    Future<void> restoreBoxTyped<T>(
        String keyName,
        Box<T> box,
        T Function(Map<String, dynamic>) fromMap,
        ) async {
      if (data[keyName] == null) return;

      debugPrint("📦 Restoring $keyName...");
      await box.clear();

      final items = data[keyName] as List;
      for (var item in items) {
        final map = Map<String, dynamic>.from(item);
        await box.add(fromMap(map));
      }

      debugPrint("📦 $keyName: ${items.length} items restored");
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
      if (data[keyName] == null) return;

      debugPrint("📦 Restoring $keyName (with ID keys)...");
      await box.clear();

      final items = data[keyName] as List;
      for (var item in items) {
        final map = Map<String, dynamic>.from(item);
        final model = fromMap(map);
        final id = getIdFunc(model);
        await box.put(id, model);  // ✅ Use ID as key, not auto-increment
      }

      debugPrint("📦 $keyName: ${items.length} items restored with ID keys");
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

    // Restore App Counters (retail) -- see the export for why this matters.
    try {
      if (data["appCounters"] != null && data["appCounters"].isNotEmpty) {
        final countersBox = Hive.box(HiveBoxNames.appCounters);
        await countersBox.clear();
        final countersData = data["appCounters"][0] as Map<String, dynamic>;
        for (var entry in countersData.entries) {
          await countersBox.put(entry.key, entry.value);
        }
        debugPrint("App counters restored: ${countersData.keys.length} entries");
      }
    } catch (e) {
      debugPrint("Error restoring app counters: $e");
    }

    // ✅ Restore Cart Items
    await restoreBoxTyped(
      "cartItems",
      Hive.box<CartItemModel>(HiveBoxNames.cartItems),
          (m) => CartItemModel.fromMap(m),
    );

    // ✅ Restore Retail Categories
    if (data["categories"] != null) {
      try {
        debugPrint("📦 Restoring retail categories...");
        final catBox = Hive.box<String>(HiveBoxNames.retailCategories);
        await catBox.clear();
        final items = data["categories"] as List;
        for (var item in items) {
          if (item is Map && item.containsKey('name')) {
            await catBox.add(item['name'] as String);
          }
        }
        debugPrint("📦 Retail categories restored: ${items.length} items");
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
      await restoreBoxTyped("eodReports", eodBox, (m) => EndOfDayReport.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring EOD reports: $e");
    }

    // ✅ Restore Expense Categories (uses typed box with registered adapter)
    try {
      final expenseCatBox = Hive.box<ExpenseCategory>('expenseCategory');
      await restoreBoxTyped("expenseCategories", expenseCatBox, (m) => ExpenseCategory.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring expense categories: $e");
    }

    // ✅ Restore Expenses (uses typed box with registered adapter)
    try {
      final expenseBox = Hive.box<Expense>('expenseBox');
      await restoreBoxTyped("expenses", expenseBox, (m) => Expense.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring expenses: $e");
    }

    // ✅ Restore Hold Sales & Hold Sale Items
    try {
      await restoreBoxTyped("holdSales", Hive.box<HoldSaleModel>(HiveBoxNames.holdSales), (m) => HoldSaleModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring hold sales: $e");
    }

    try {
      await restoreBoxTyped("holdSaleItems", Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems), (m) => HoldSaleItemModel.fromMap(m));
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
      await restoreBoxTyped("creditPayments", Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments), (m) => CreditPaymentModel.fromMap(m));
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
      await restoreBoxTyped("productAttributes", Hive.box<ProductAttributeModel>(HiveBoxNames.productAttributes), (m) => ProductAttributeModel.fromMap(m));
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
      await restoreBoxTyped("billingTabs", Hive.box<BillingTabModel>(HiveBoxNames.billingTabs), (m) => BillingTabModel.fromMap(m));
    } catch (e) {
      debugPrint("⚠️ Error restoring billing tabs: $e");
    }

    // ✅ Restore Day Management Box (opening balance)
    try {
      if (data["dayManagement"] != null && data["dayManagement"].isNotEmpty) {
        debugPrint("📦 Restoring day management...");
        final dayMgmtBox = Hive.box(HiveBoxNames.dayManagementBox);
        await dayMgmtBox.clear();
        final dayMgmtData = data["dayManagement"][0] as Map<String, dynamic>;
        for (var entry in dayMgmtData.entries) {
          await dayMgmtBox.put(entry.key, entry.value);
        }
        debugPrint("📦 Day management restored: ${dayMgmtData.keys.length} entries");
      }
    } catch (e) {
      debugPrint("⚠️ Error restoring day management: $e");
    }

    // Admin credential restores via the generic localPrefs restore (see
    // _restoreLocalSettings) — no explicit handling needed here.

    // Boxes were written directly above, so ProductStore's in-memory lists
    // still hold the pre-restore data (and detached objects after box.clear()).
    try {
      await productStore.loadProducts();
      await productStore.loadVariants();
    } catch (e) {
      debugPrint("⚠️ Could not refresh product store after restore: $e");
    }

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
      // Don't throw - let the restore continue even if this fails
    }
  }
}