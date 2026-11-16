import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/mode_keys.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/common/start_of_day_backup_prompt.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';

import 'backup_box_registry.dart';

class _Docs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Docs(this.docs, this.downloads);
  final String docs;
  final String downloads;
  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
  @override
  Future<String?> getTemporaryPath() async => docs;
  @override
  Future<String?> getDownloadsPath() async => downloads;
}

/// Records that restore got past its plan gate to the file picker.
class _RecordingPicker extends FilePicker {
  int asked = 0;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    asked++;
    return null; // the user cancels
  }
}

/// M6b: every backup operation (download, folder, share, restore, automatic
/// backup, start-of-day prompt) asks THIS mode's data-backup entitlement.
void backupEntitlementSuite({required String mode}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory downloads;
  late _RecordingPicker picker;
  final retail = mode == 'retail';
  final ownKey = retail ? RetailEntKeys.dataBackup : EntKeys.dataBackup;
  final otherKey = retail ? EntKeys.dataBackup : RetailEntKeys.dataBackup;

  /// A licensed device whose verified manifest grants only [key].
  void licensedWith(String key) {
    Entitlements.instance.loadFromManifest(ManifestData(
      entitlements: {key: true},
      license: const {'status': 2},
      version: 1,
    ));
  }

  List<String> backupsIn(Directory d) => d.existsSync()
      ? d
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((n) => n.startsWith('BillBerryLite_') && n.endsWith('.zip'))
          .toList()
      : <String>[];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    root = await Directory.systemTemp.createTemp('backup_entitlement_$mode');
    final docs = Directory(p.join(root.path, 'documents'))..createSync();
    downloads = Directory(p.join(root.path, 'Downloads'))..createSync();
    PathProviderPlatform.instance = _Docs(docs.path, downloads.path);
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor(mode, Directory(docs.path));
    await AppConfig.box.put('isSetupComplete', true);
    await BackupEncryptionService.setPassword('246810');
    locator.registerSingleton<LicenseStore>(LicenseStore(LicenseApiService()));
    FilePicker.platform = picker = _RecordingPicker();
  });

  setUp(() async {
    picker.asked = 0;
    Entitlements.instance.clear();
    await Hive.box(HiveBoxNames.appState).delete('auto_backup_enabled');
    await Hive.box(HiveBoxNames.appState).delete('last_backup_date');
    for (final f in downloads.listSync()) {
      f.deleteSync(recursive: true);
    }
  });

  tearDownAll(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {/* Windows handle release */}
  });

  test('$mode: ModeKeys.dataBackup is this mode\'s key', () {
    expect(ModeKeys.dataBackup, ownKey);
  });

  test('$mode: automatic backup is OFF by default', () async {
    licensedWith(ownKey);
    expect(await AutoBackupService.isAutoBackupEnabled(), isFalse);
    await AutoBackupService.checkAndBackupForTesting();
    expect(backupsIn(downloads), isEmpty, reason: 'not switched on');
  });

  test('$mode: licensed with only the OTHER mode\'s key — every backup '
      'operation is refused', () async {
    licensedWith(otherKey);
    expect(await UnifiedBackupService.exportToDownloads(), isNull);
    expect(await UnifiedBackupService.exportToCustomFolder(downloads.path),
        isNull);
    expect(await UnifiedBackupService.exportToShare(), isNull);
    await Hive.box(HiveBoxNames.appState).put('auto_backup_enabled', true);
    var started = false;
    void watch() => started = started || AutoBackupService.isBackingUp.value;
    AutoBackupService.isBackingUp.addListener(watch);
    await AutoBackupService.checkAndBackupForTesting();
    AutoBackupService.isBackingUp.removeListener(watch);
    expect(started, isFalse,
        reason: 'the hourly check stops at its own plan gate');
    expect(backupsIn(downloads), isEmpty);
  });

  test('$mode: licensed with only its OWN key — download, folder and share '
      'backups are made; automatic backup runs', () async {
    licensedWith(ownKey);
    expect(await UnifiedBackupService.exportToDownloads(includeImages: false),
        isNotNull);
    final folder = Directory(p.join(root.path, 'folder'))..createSync();
    expect(await UnifiedBackupService.exportToCustomFolder(folder.path),
        isNotNull);
    expect(await UnifiedBackupService.exportToShare(), isNotNull);

    for (final f in downloads.listSync()) {
      f.deleteSync(recursive: true);
    }
    await Hive.box(HiveBoxNames.appState).put('auto_backup_enabled', true);
    await AutoBackupService.checkAndBackupForTesting();
    expect(backupsIn(downloads), hasLength(1),
        reason: 'the hourly check made today\'s backup');
    expect(await AutoBackupService.getLastBackupDate(),
        DateTime.now().toIso8601String().substring(0, 10));
  });

  testWidgets('$mode: restore — the OTHER key never reaches the file picker; '
      'its OWN key does', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    licensedWith(otherKey);
    expect(await UnifiedBackupService.importData(ctx), isFalse);
    expect(picker.asked, 0);

    licensedWith(ownKey);
    expect(await UnifiedBackupService.importData(ctx), isFalse,
        reason: 'the fake picker cancels');
    expect(picker.asked, 1, reason: 'the plan gate let restore through');
  });

  // Prompt tests last: the prompt shows at most once per process.
  testWidgets('$mode: start-of-day prompt — refused with the OTHER key, shown '
      'with its OWN key', (tester) async {
    await tester.runAsync(() => Hive.box(HiveBoxNames.appState)
        .put('auto_backup_enabled', true));
    Future<void> showPrompt() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) => TextButton(
              onPressed: () => StartOfDayBackupPrompt.show(c),
              child: const Text('home'),
            ))),
      ));
      await tester.tap(find.text('home'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    licensedWith(otherKey);
    await showPrompt();
    expect(find.text('Back Up Data'), findsNothing);

    licensedWith(ownKey);
    await showPrompt();
    expect(find.text('Back Up Data'), findsOneWidget);
  });
}
