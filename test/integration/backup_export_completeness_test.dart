import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';

import '../helpers/backup_box_registry.dart';

/// Manual and automatic backups: an export with a section that could not be
/// read is never saved as a usable backup, and the reason names the section.
class _FakeDirs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakeDirs(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getDownloadsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory files;

  List<File> backupFiles() => files
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => p.basename(f.path).startsWith('BillBerryLite_'))
      .toList();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_export_');
    files = Directory(p.join(tempDir.path, 'files'))..createSync();
    PathProviderPlatform.instance = _FakeDirs(files.path);
    await openBoxesFor('retail', tempDir);
    if (!locator.isRegistered<LicenseStore>()) {
      locator.registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService())..licenseBypassed = true);
    }
    FlutterSecureStorage.setMockInitialValues({});
    await BackupEncryptionService.setPassword('export-pass');
  });

  setUp(() {
    for (final f in backupFiles()) {
      f.deleteSync();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Runs [export] with the printers box unreadable.
  Future<String?> withUnreadablePrinters(
      Future<String?> Function() export) async {
    await Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters).close();
    try {
      return await export();
    } finally {
      await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
    }
  }

  test('download backup (manual and automatic) refuses an incomplete export',
      () async {
    final path = await withUnreadablePrinters(
        () => UnifiedBackupService.exportToDownloads(includeImages: false));

    expect(path, isNull, reason: 'not presented as a successful backup');
    expect(backupFiles(), isEmpty, reason: 'no incomplete file is written');
    expect(UnifiedBackupService.lastExportError, contains('Backup not saved'));
    expect(UnifiedBackupService.lastExportError, contains('printers'));
  });

  test('share backup refuses an incomplete export', () async {
    final path =
        await withUnreadablePrinters(UnifiedBackupService.exportToShare);

    expect(path, isNull);
    expect(backupFiles(), isEmpty);
    expect(UnifiedBackupService.lastExportError, contains('printers'));
  });

  test('a complete export saves the backup and clears the earlier error',
      () async {
    final path =
        await UnifiedBackupService.exportToDownloads(includeImages: false);

    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    expect(UnifiedBackupService.lastExportError, isNull,
        reason: 'a stale failure never leaks into a later backup');
  });
}
