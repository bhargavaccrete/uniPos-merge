import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// SB-1e E1 (retail): a restore whose safety copy cannot be made complete
/// never starts, and the failure does not leak into the next restore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_sb1e_retail_');
    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await sessions().put(
      'sess-backup',
      RestaurantSessionModel(
        sessionId: 'sess-backup',
        startTime: DateTime(2026, 10, 28, 9),
        openingCash: 1000,
      ),
    );
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
    await sessions().clear();
    await sessions().put(
      'sess-device',
      RestaurantSessionModel(
        sessionId: 'sess-device',
        startTime: DateTime(2026, 10, 29, 18),
        openingCash: 300,
      ),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a section that cannot be exported stops the restore before any write',
      () async {
    final before = await deviceState(tempDir);
    await Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters).close();

    Object? error;
    try {
      await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));
    } catch (e) {
      error = e;
    } finally {
      await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
    }

    expect(error, isNot(isA<RestoreFailedException>()));
    expect(error.toString(), contains('The restore did not start'));
    expect(error.toString(), contains('printers'));
    expect(await deviceState(tempDir), before);
    expect(sessions().keys, ['sess-device']);
  });

  test('a later restore is not blocked by the earlier export failure',
      () async {
    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));
    expect(sessions().keys, ['sess-backup']);
  });
}
