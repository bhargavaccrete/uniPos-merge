import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// BLK-04 on a configured RESTAURANT device: a Retail backup is refused
/// before any box is opened or anything is written, and a Restaurant backup
/// still restores.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cross_mode_restaurant_');
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);

    await sessions().put(
      'sess-device',
      RestaurantSessionModel(
        sessionId: 'sess-device',
        startTime: DateTime(2026, 10, 29, 8),
        openingCash: 2000,
      ),
    );
    await dayMgmt().putAll({'currentSessionId': 'sess-device', 'dayStarted': true});
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Matcher refusedAs(String backupLabel) => throwsA(
        predicate(
          (e) =>
              e.toString().contains('This is a $backupLabel backup') &&
              e.toString().contains('set up for Restaurant'),
          'a cross-mode refusal for a $backupLabel backup',
        ),
      );

  test('a Retail backup is refused and nothing changes', () async {
    final before = await deviceState(tempDir);

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(
        wrappedBackupOf('retail'),
        images: oneImageEntry,
      ),
      refusedAs('Retail'),
    );

    expect(await deviceState(tempDir), before,
        reason: 'every box, the AppConfig box and the files on disk are untouched');
    expect(AppConfig.businessMode, BusinessMode.restaurant);
    expect(Hive.isBoxOpen(HiveBoxNames.products), isFalse,
        reason: 'refused before any retail box was opened');
    expect(dayMgmt().get('currentSessionId'), 'sess-device');
  });

  test('a legacy Retail backup (no appMode) is refused too', () async {
    final before = await deviceState(tempDir);

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(
          legacyBackupOf('retail')),
      refusedAs('Retail'),
    );

    expect(await deviceState(tempDir), before);
    expect(AppConfig.businessMode, BusinessMode.restaurant);
    expect(Hive.isBoxOpen(HiveBoxNames.products), isFalse);
  });

  test('a Restaurant backup still restores on a Restaurant device', () async {
    final backup =
        wrappedBackupOf('restaurant', sessionId: 'sess-restaurant-backup');

    await UnifiedBackupService.restoreDecodedBackupForTesting(backup);

    expect(AppConfig.businessMode, BusinessMode.restaurant);
    expect(sessions().keys, ['sess-restaurant-backup'],
        reason: "the backup's sessions replace the device's");
    expect(sessions().get('sess-restaurant-backup')?.openingCash, 750);
    expect(dayMgmt().get('currentSessionId'), 'sess-restaurant-backup');
  });
}
