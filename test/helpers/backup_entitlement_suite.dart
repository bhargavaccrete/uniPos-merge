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
import 'sign_in_fixture.dart';

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

/// M6b: every backup operation (download, folder, share, restore, daily
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
    await signInForTest(); // the admin — the prompt is for Admin / Manager
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

  test('$mode: the daily backup prompt is OFF by default', () async {
    licensedWith(ownKey);
    expect(await AutoBackupService.isAutoBackupEnabled(), isFalse);
    expect(await AutoBackupService.currentPrompt(), DailyBackupPrompt.none);
    expect(backupsIn(downloads), isEmpty);
  });

  test('$mode: switching the prompt on makes no backup by itself', () async {
    licensedWith(ownKey);
    await AutoBackupService.setAutoBackupEnabled(true);
    expect(await AutoBackupService.isAutoBackupEnabled(), isTrue);
    expect(backupsIn(downloads), isEmpty, reason: 'only the setting changes');
    expect(await AutoBackupService.getLastBackupDate(), isNull);
  });

  test('$mode: licensed with only the OTHER mode\'s key — every backup '
      'operation is refused', () async {
    licensedWith(otherKey);
    expect(await UnifiedBackupService.exportToDownloads(), isNull);
    expect(await UnifiedBackupService.exportToCustomFolder(downloads.path),
        isNull);
    expect(await UnifiedBackupService.exportToShare(), isNull);
    await Hive.box(HiveBoxNames.appState).put('auto_backup_enabled', true);
    expect(await AutoBackupService.runDailyBackup(), isNull);
    expect(AutoBackupService.status().lastError,
        UnifiedBackupService.backupNotInPlanMessage);
    expect(backupsIn(downloads), isEmpty);
  });

  test('$mode: licensed with only its OWN key — download, folder and share '
      'backups are made; the daily backup runs', () async {
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
    await Hive.box(HiveBoxNames.appState).delete('last_backup_date');
    await Hive.box(HiveBoxNames.appState).put('auto_backup_enabled', true);
    expect(await AutoBackupService.runDailyBackup(), isNotNull);
    expect(backupsIn(downloads), hasLength(1),
        reason: 'Backup Now made today\'s backup');
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
    await tester.runAsync(() async {
      final box = Hive.box(HiveBoxNames.appState);
      await box.put('auto_backup_enabled', true);
      // Switched on today (real I/O belongs in runAsync, not in the prompt).
      await box.put(AutoBackupService.promptSinceKey,
          DateTime.now().toIso8601String().substring(0, 10));
    });
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

  group('$mode: start-of-day prompt rules', () {
    String daysAgo(int d) => DateTime.now()
        .subtract(Duration(days: d))
        .toIso8601String()
        .substring(0, 10);

    Future<void> showPromptWith(WidgetTester tester,
        {required bool enabled, String? lastBackup, String? since}) async {
      licensedWith(ownKey);
      StartOfDayBackupPrompt.resetForTesting();
      await tester.runAsync(() async {
        final box = Hive.box(HiveBoxNames.appState);
        await box.put('auto_backup_enabled', enabled);
        if (lastBackup == null) {
          await box.delete('last_backup_date');
        } else {
          await box.put('last_backup_date', lastBackup);
        }
        if (since == null) {
          await box.delete(AutoBackupService.promptSinceKey);
        } else {
          await box.put(AutoBackupService.promptSinceKey, since);
        }
      });
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

    tearDown(StartOfDayBackupPrompt.resetForTesting);

    testWidgets('last backup 1–6 days ago: Backup Now and Skip Today',
        (tester) async {
      await showPromptWith(tester, enabled: true, lastBackup: daysAgo(3));
      expect(find.text('Back Up Data'), findsOneWidget);
      expect(find.text('Backup Now'), findsOneWidget);
      expect(find.text('Skip Today'), findsOneWidget);
    });

    testWidgets('7 days without a backup: Backup Now only, back cannot close it',
        (tester) async {
      await showPromptWith(tester, enabled: true, lastBackup: daysAgo(7));
      expect(find.text(StartOfDayBackupPrompt.requiredMessage), findsOneWidget);
      expect(find.text('Backup Now'), findsOneWidget);
      expect(find.text('Skip Today'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Back Up Data'), findsOneWidget,
          reason: 'the back button cannot dismiss the required prompt');
    });

    testWidgets('fresh install (never backed up): Backup Now and Skip Today',
        (tester) async {
      // Switched on today — what setAutoBackupEnabled / currentPrompt store.
      await showPromptWith(tester, enabled: true, since: daysAgo(0));
      expect(find.text('Back Up Data'), findsOneWidget);
      expect(find.text('Skip Today'), findsOneWidget);
      expect(find.text(StartOfDayBackupPrompt.requiredMessage), findsNothing);
    });

    testWidgets('never backed up, switched on 7+ days ago: required',
        (tester) async {
      await showPromptWith(tester, enabled: true, since: daysAgo(8));
      expect(find.text('Skip Today'), findsNothing);
      expect(find.text('Backup Now'), findsOneWidget);
    });

    testWidgets('setting off: no prompt, even after 7+ days', (tester) async {
      await showPromptWith(tester, enabled: false, lastBackup: daysAgo(30));
      expect(find.text('Back Up Data'), findsNothing);
    });

    testWidgets('already backed up today: no prompt', (tester) async {
      await showPromptWith(tester, enabled: true, lastBackup: daysAgo(0));
      expect(find.text('Back Up Data'), findsNothing);
    });
  });

  group('$mode: start-of-day prompt — who is asked', () {
    tearDown(() async {
      StartOfDayBackupPrompt.resetForTesting();
      await signInForTest(); // back to the admin for the other tests
    });

    Future<void> showAs(WidgetTester tester, String? role) async {
      licensedWith(ownKey);
      StartOfDayBackupPrompt.resetForTesting();
      await tester.runAsync(() async {
        await signInForTest(role: role);
        final box = Hive.box(HiveBoxNames.appState);
        await box.put('auto_backup_enabled', true);
        await box.delete('last_backup_date');
        await box.put(AutoBackupService.promptSinceKey,
            DateTime.now().toIso8601String().substring(0, 10));
      });
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

    testWidgets('Admin is asked', (tester) async {
      await showAs(tester, null);
      expect(find.text('Back Up Data'), findsOneWidget);
    });

    testWidgets('Manager is asked', (tester) async {
      await showAs(tester, 'Manager');
      expect(find.text('Back Up Data'), findsOneWidget);
    });

    testWidgets('Cashier is NOT asked', (tester) async {
      await showAs(tester, 'Cashier');
      expect(find.text('Back Up Data'), findsNothing);
    });

    testWidgets('Waiter is NOT asked', (tester) async {
      await showAs(tester, 'Waiter');
      expect(find.text('Back Up Data'), findsNothing);
    });
  });
}
