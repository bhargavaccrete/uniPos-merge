import 'dart:io';

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
import 'package:billberrylite/core/init/restore_record.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/domain/services/common/auto_backup_retention.dart';
import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/backup_storage_permission.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/common_setting_tiles.dart';

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

/// BKP-6 for one business mode, on real files: daily (start-of-day prompt)
/// backup results and the `backup_failed` notification, retention after a
/// verified backup only, any successful backup counting as today's, backups
/// never overlapping, clear reasons for manual failures, and share-cache
/// clean-up.
void autoBackupStatusSuite({required String mode}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pin = '246810';
  late Directory root;
  late Directory docs;
  late Directory downloads;

  Box appState() => Hive.box(HiveBoxNames.appState);
  List<AppNotificationModel> failedEvents() =>
      notificationStore.activeOf(AutoBackupService.failedEvent,
          subjectType: 'system');
  List<String> autoFiles() => downloads
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .where((n) => n.startsWith(AutoBackupRetention.prefix))
      .toList();
  String autoName(DateTime t) =>
      'BillBerryLite_daily_${t.toIso8601String().replaceAll(':', '-').substring(0, 19)}.zip';
  String today() => DateTime.now().toIso8601String().substring(0, 10);

  /// The write reads back wrong (BKP-11 verification fails).
  void breakTheWrite() => UnifiedBackupService.afterBackupWriteForTesting =
      (f) async {
        final b = f.readAsBytesSync();
        f.writeAsBytesSync(b.sublist(0, b.length ~/ 2), flush: true);
      };

  /// The user taps "Backup Now" on the start-of-day prompt.
  Future<String?> dailyBackup() => AutoBackupService.runDailyBackup();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    root = await Directory.systemTemp.createTemp('auto_backup_status_$mode');
    docs = Directory(p.join(root.path, 'documents'))..createSync();
    downloads = Directory(p.join(root.path, 'Downloads'))..createSync();
    PathProviderPlatform.instance = _Docs(docs.path, downloads.path);
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor(mode, Directory(docs.path));
    await AppConfig.box.put('isSetupComplete', true);
    locator
      ..registerSingleton<LicenseStore>(
          LicenseStore(LicenseApiService())..licenseBypassed = true)
      ..registerSingleton<NotificationStore>(
          NotificationStore(NotificationRepository()));
  });

  setUp(() async {
    BackupStoragePermission.resetForTesting();
    UnifiedBackupService.afterBackupWriteForTesting = null;
    FlutterSecureStorage.setMockInitialValues({});
    await BackupEncryptionService.setPassword(pin);
    await appState().put('auto_backup_enabled', true);
    for (final k in [
      'last_backup_date',
      'last_auto_backup_attempt',
      'last_auto_backup_success',
      'last_auto_backup_error',
    ]) {
      await appState().delete(k);
    }
    for (final n in failedEvents()) {
      await notificationStore.resolve(n.eventCode, n.subjectType, n.subjectId);
    }
    for (final f in downloads.listSync()) {
      f.deleteSync(recursive: true);
    }
  });

  tearDownAll(() async {
    BackupStoragePermission.resetForTesting();
    UnifiedBackupService.afterBackupWriteForTesting = null;
    await locator.reset();
    await Hive.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {/* Windows handle release */}
  });

  test('$mode: a failed daily backup is recorded and raises ONE '
      'notification; retries do not spam; the next success clears it',
      () async {
    breakTheWrite();
    expect(await dailyBackup(), isNull);
    var s = AutoBackupService.status();
    expect(s.lastError, startsWith('Backup not saved'));
    expect(s.lastAttempt, isNotNull);
    expect(s.lastSuccess, isNull);
    expect(failedEvents(), hasLength(1));
    expect(failedEvents().single.data, contains('Backup not saved'));
    expect(autoFiles(), isEmpty);
    expect(await AutoBackupService.getLastBackupDate(), isNull,
        reason: 'a failure is not today\'s backup');

    await dailyBackup();
    await dailyBackup();
    expect(failedEvents(), hasLength(1), reason: 'retries, one event');
    expect(
        Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications)
            .values
            .where((n) => n.eventCode == AutoBackupService.failedEvent),
        hasLength(1),
        reason: 'not even a resolved duplicate');

    UnifiedBackupService.afterBackupWriteForTesting = null;
    expect(await dailyBackup(), isNotNull);
    s = AutoBackupService.status();
    expect(s.lastError, isNull);
    expect(s.lastSuccess, isNotNull);
    expect(failedEvents(), isEmpty, reason: 'resolved by the success');
    expect(autoFiles(), hasLength(1));
    expect(await AutoBackupService.getLastBackupDate(), today());
  });

  test('$mode: no backup PIN — told, not silent', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect(await dailyBackup(), isNull);
    expect(AutoBackupService.status().lastError,
        AutoBackupService.noPasswordMessage);
    expect(failedEvents(), hasLength(1));
  });

  test('$mode: a MANUAL backup counts as today\'s backup and clears the last '
      'daily failure', () async {
    breakTheWrite();
    await dailyBackup();
    expect(failedEvents(), hasLength(1));

    UnifiedBackupService.afterBackupWriteForTesting = null;
    expect(await UnifiedBackupService.exportToDownloads(includeImages: false),
        isNotNull);
    final s = AutoBackupService.status();
    expect(s.lastError, isNull);
    expect(s.lastSuccess, isNotNull);
    expect(failedEvents(), isEmpty);
    expect(await AutoBackupService.getLastBackupDate(), today());
    expect(autoFiles(), isEmpty, reason: 'a manual backup is not a daily one');
  });

  test('$mode: two backups at once never break each other (one at a time)',
      () async {
    Future<String?>? second;
    UnifiedBackupService.afterBackupWriteForTesting = (part) async {
      if (second != null) return;
      // While the first backup's temporary file exists, a second starts.
      second = UnifiedBackupService.exportToDownloads(includeImages: false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(part.existsSync(), isTrue,
          reason: 'the second backup must not delete this .part file');
    };
    final first = await dailyBackup();
    final other = await second!;
    expect(first, isNotNull);
    expect(other, isNotNull);
    expect(File(first!).existsSync(), isTrue);
    expect(File(other!).existsSync(), isTrue);
    expect(AutoBackupService.status().lastError, isNull);
    expect(
        downloads.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
  });

  group('$mode: storage permission on Android 7–10', () {
    var asked = 0;
    void oldAndroid({required bool granted, bool grantOnAsk = false}) {
      asked = 0;
      BackupStoragePermission.isAndroidOverride = true;
      BackupStoragePermission.sdkIntOverride = () async => 28;
      BackupStoragePermission.isGrantedOverride = () async => granted;
      BackupStoragePermission.requestOverride = () async {
        asked++;
        return grantOnAsk;
      };
    }

    test('daily backup asks; refused gives a clear reason, no file, not '
        'marked done', () async {
      oldAndroid(granted: false);
      expect(await dailyBackup(), isNull);
      expect(asked, 1, reason: 'the user is on screen, so it asks');
      expect(AutoBackupService.status().lastError,
          UnifiedBackupService.storagePermissionDeniedMessage);
      expect(failedEvents(), hasLength(1));
      expect(autoFiles(), isEmpty);
      expect(await AutoBackupService.getLastBackupDate(), isNull,
          reason: 'not marked done, so the prompt asks again');
    });

    test('daily backup with permission granted runs', () async {
      oldAndroid(granted: true);
      expect(await dailyBackup(), isNotNull);
      expect(AutoBackupService.status().lastError, isNull);
      expect(autoFiles(), hasLength(1));
    });

    test('manual backup asks; refused gives a clear reason, allowed saves',
        () async {
      oldAndroid(granted: false);
      expect(await UnifiedBackupService.exportToDownloads(), isNull);
      expect(asked, 1);
      expect(UnifiedBackupService.lastExportError,
          UnifiedBackupService.storagePermissionDeniedMessage);

      oldAndroid(granted: false, grantOnAsk: true);
      expect(await UnifiedBackupService.exportToDownloads(), isNotNull);
      expect(asked, 1);
    });
  });

  testWidgets('$mode: the Backup screen shows last success and last failure',
      (tester) async {
    await tester.runAsync(() async {
      await appState().put('last_auto_backup_success', '2026-11-15T09:00:00');
      await appState().put('last_auto_backup_attempt', '2026-11-16T09:00:00');
      await appState().put('last_auto_backup_error', 'Disk full');
    });
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AutoBackupStatusTile())));
    expect(find.text('Last successful: 15 Nov 2026, 09:00 AM'), findsOneWidget);
    expect(find.text('Last attempt failed (16 Nov 2026, 09:00 AM): Disk full'),
        findsOneWidget);
  });

  test('$mode: a failed backup never prunes; a verified one prunes old '
      'daily backups only', () async {
    final today = DateTime.now();
    final old = [
      for (var i = 1; i <= 60; i++)
        autoName(DateTime(today.year, today.month, today.day - i, 9)),
    ];
    for (final n in [
      ...old,
      'BillBerryLite_encrypted_2025-01-01T09-00-00.zip', // manual
      'my notes.txt',
    ]) {
      File(p.join(downloads.path, n)).writeAsBytesSync([1]);
    }

    breakTheWrite();
    await dailyBackup();
    expect(autoFiles(), hasLength(60), reason: 'failure: nothing pruned');

    UnifiedBackupService.afterBackupWriteForTesting = null;
    await dailyBackup();
    final left = downloads.listSync().map((f) => p.basename(f.path)).toSet();
    expect(left, contains('BillBerryLite_encrypted_2025-01-01T09-00-00.zip'));
    expect(left, contains('my notes.txt'));
    final autos = autoFiles();
    expect(autos, hasLength(14 + 8), reason: '14 daily + 8 weekly');
    final newest = autos
        .map((n) => AutoBackupRetention.stampOf(n)!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    expect(newest.day, today.day, reason: 'the new verified backup is kept');
  });

  test('$mode: a backup an open restore record points to is never pruned',
      () async {
    final today = DateTime.now();
    final old = [
      for (var i = 1; i <= 60; i++)
        autoName(DateTime(today.year, today.month, today.day - i, 9)),
    ];
    for (final n in old) {
      File(p.join(downloads.path, n)).writeAsBytesSync([1]);
    }
    final protectedPath = p.join(downloads.path, old.last);
    await RestoreRecordStore.write(
        docs.path,
        RestoreRecord(
          snapshotPath: protectedPath,
          snapshotSha256: 'x',
          mode: mode,
          startedAt: today,
          source: RestoreSource.normal,
          pin: SnapshotPin.deviceBackupPin,
          journal: const [],
        ));
    try {
      await dailyBackup();
      expect(File(protectedPath).existsSync(), isTrue);
    } finally {
      await RestoreRecordStore.close(docs.path, 'test');
    }
  });

  group('$mode: manual backup failure reasons', () {
    test('no backup PIN', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final out = Directory(p.join(root.path, 'm1'))..createSync();
      expect(await UnifiedBackupService.exportToCustomFolder(out.path), isNull);
      expect(UnifiedBackupService.lastExportError,
          contains('No backup password is set'));
    });

    test('a location that cannot be written', () async {
      final blocker = File(p.join(root.path, 'not_a_folder'))
        ..writeAsStringSync('x');
      expect(
          await UnifiedBackupService.exportToCustomFolder(
              p.join(blocker.path, 'sub')),
          isNull);
      expect(UnifiedBackupService.lastExportError, startsWith('Backup not saved'));
    });

    test('not enough storage space', () async {
      UnifiedBackupService.afterBackupWriteForTesting = (f) async =>
          throw const FileSystemException(
              'write failed', 'x', OSError('No space left on device', 28));
      final out = Directory(p.join(root.path, 'm3'))..createSync();
      expect(await UnifiedBackupService.exportToCustomFolder(out.path), isNull);
      expect(UnifiedBackupService.lastExportError, contains('No space left'));
    });

    test('a verification failure', () async {
      breakTheWrite();
      final out = Directory(p.join(root.path, 'm4'))..createSync();
      expect(await UnifiedBackupService.exportToCustomFolder(out.path), isNull);
      expect(UnifiedBackupService.lastExportError,
          allOf(startsWith('Backup not saved'), contains('bytes were saved')));
    });

    test('the plan does not include backups', () async {
      // A licensed device whose verified plan has no backup entitlement.
      locator<LicenseStore>().licenseBypassed = false;
      Entitlements.instance.loadFromManifest(const ManifestData(
          entitlements: {'something_else': true},
          license: {'status': 2},
          version: 1));
      try {
        expect(await UnifiedBackupService.exportToDownloads(), isNull);
        expect(UnifiedBackupService.lastExportError,
            UnifiedBackupService.backupNotInPlanMessage);
        expect(await UnifiedBackupService.exportToShare(), isNull);
        expect(UnifiedBackupService.lastExportError,
            UnifiedBackupService.backupNotInPlanMessage);
        final out = Directory(p.join(root.path, 'm5'))..createSync();
        expect(await UnifiedBackupService.exportToCustomFolder(out.path), isNull);
        expect(UnifiedBackupService.lastExportError,
            UnifiedBackupService.backupNotInPlanMessage);
      } finally {
        Entitlements.instance.clear();
        locator<LicenseStore>().licenseBypassed = true;
      }
    });

    test('mapping of storage and permission errors', () {
      String m(FileSystemException e) =>
          UnifiedBackupService.backupFailureMessage(e);
      expect(m(const FileSystemException('w', '/d', OSError('x', 28))),
          contains('not enough free storage space'));
      expect(m(const FileSystemException('w', 'D:\\', OSError('x', 112))),
          contains('not enough free storage space'));
      expect(m(const PathAccessException('/d', OSError('denied', 13))),
          contains('not allowed to write'));
      expect(m(const FileSystemException('w', 'C:\\x', OSError('x', 5))),
          contains('not allowed to write'));
    });
  });

  test('$mode: share copies older than 24 hours are removed; recent ones and '
      'backups elsewhere are kept', () async {
    final cache = Directory(p.join(docs.path, 'backup_share_cache'))
      ..createSync(recursive: true);
    final old = File(p.join(cache.path, 'BillBerryLite_encrypted_old.zip'))
      ..writeAsBytesSync([1]);
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 25)));
    final recent = File(p.join(cache.path, 'BillBerryLite_encrypted_recent.zip'))
      ..writeAsBytesSync([1]);
    final other = File(p.join(cache.path, 'keep.txt'))..writeAsBytesSync([1]);
    final manual = File(
        p.join(downloads.path, 'BillBerryLite_encrypted_2020-01-01T09-00-00.zip'))
      ..writeAsBytesSync([1]);
    manual.setLastModifiedSync(DateTime(2020));

    final made = await UnifiedBackupService.exportToShare();
    expect(made, isNotNull);
    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
    expect(manual.existsSync(), isTrue, reason: 'not a share copy');
  });
}
