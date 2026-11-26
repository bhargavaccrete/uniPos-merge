import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// BLK-04: on a fresh install (business mode not chosen yet) a Restaurant
/// backup is accepted and sets the device up as Restaurant — the onboarding
/// "restore from backup" path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fresh_restore_restaurant_');
    await initHiveForBackupTest(tempDir);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a Restaurant backup restores onto a fresh install', () async {
    expect(AppConfig.isBusinessModeSet, isFalse);

    await UnifiedBackupService.restoreDecodedBackupForTesting(
        wrappedBackupOf('restaurant', sessionId: 'sess-x'));

    expect(AppConfig.businessMode, BusinessMode.restaurant);
    expect(AppConfig.box.get('isSetupComplete'), isTrue);
    expect(Hive.isBoxOpen(HiveBoxNames.restaurantItems), isTrue,
        reason: 'restaurant boxes were opened for the restore');
    final sessions =
        Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
    expect(sessions.get('sess-x')?.openingCash, 750);
    expect(Hive.box(HiveBoxNames.dayManagementBox).get('currentSessionId'),
        'sess-x');
  });
}
