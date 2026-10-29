import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// Onboarding restore while setup is unfinished (no business mode yet), after
/// the wizard already saved data: the restore screen warns only when there
/// is something to lose, and a failed restore puts that data back — the
/// safety snapshot covers the boxes the restore writes even with no mode.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Box<BusinessDetails> details() =>
      Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox);
  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);
  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_onboarding_');
    await initHiveForBackupTest(tempDir);
    // As the wizard does after "Business Type: Retail", before setup is done.
    await HiveInit.openCommonBoxes();
    await HiveInit.openRetailBoxes();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a pristine install has nothing to lose (no warning)', () {
    expect(AppConfig.isBusinessModeSet, isFalse);
    expect(UnifiedBackupService.hasSetupDataToLose(), isFalse,
        reason: 'only the seeded default payment methods exist');
  });

  test('saved setup data is detected (warning shown)', () async {
    await details().add(BusinessDetails(storeName: 'Berry Fashion'));
    expect(UnifiedBackupService.hasSetupDataToLose(), isTrue);
  });

  test('a failed onboarding restore puts the setup data back', () async {
    await categories().put('cat-setup', Category(id: 'cat-setup', name: 'Shirts'));
    await sessions().put(
      'sess-setup',
      RestaurantSessionModel(
        sessionId: 'sess-setup',
        startTime: DateTime(2026, 10, 29, 9),
        openingCash: 0,
      ),
    );
    final before = await deviceState(tempDir);
    // grns is emptied (true replace) after categories, sessions… were.
    UnifiedBackupService.failWritingKeyForTesting = 'grns';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(
          wrappedBackupOf('retail')),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(categories().keys, ['cat-setup'],
        reason: 'mode-branch data is in the snapshot even with no mode set');
    expect(sessions().keys, ['sess-setup']);
    expect(details().values.single.storeName, 'Berry Fashion');
    expect(AppConfig.isBusinessModeSet, isFalse);
    expect(await deviceState(tempDir), before);
  });

  test('the onboarding restore warns only when there is data to lose', () {
    final source = File(
            'lib/presentation/screens/onboarding/existingUserRestoreScreen.dart')
        .readAsStringSync();
    final guard = source.indexOf(RegExp(
        r'if \(UnifiedBackupService\.hasSetupDataToLose\(\)\) \{\s*if \(!await confirmRestoreReplacesData\(context\)\) return;'));
    final import = source.indexOf('UnifiedBackupService.importFromFilePath(');

    expect(guard, isNonNegative);
    expect(import, greaterThan(guard), reason: 'warned before restoring');
  });
}
