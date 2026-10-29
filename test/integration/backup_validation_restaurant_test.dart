import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// SB-1c (restaurant): the whole backup is read before anything is cleared.
/// A record the restore cannot read in a step that would abort part-way, or a
/// malformed settings block, refuses the backup with every box and setting
/// untouched. Valid current-format and legacy backups still restore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> validBackup;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);

  /// A fresh deep copy of the valid backup, safe to corrupt per test.
  Map<String, dynamic> copyOfValid() =>
      jsonDecode(jsonEncode(validBackup)) as Map<String, dynamic>;

  /// Moves the device away from the backup, so a write would be visible.
  Future<void> divergeFromBackup() async {
    await sessions().put(
      'sess-after-backup',
      RestaurantSessionModel(
        sessionId: 'sess-after-backup',
        startTime: DateTime(2026, 10, 29, 18),
        openingCash: 300,
      ),
    );
    await categories().put('cat-after', Category(id: 'cat-after', name: 'Desserts'));
    await dayMgmt().put('currentSessionId', 'sess-after-backup');
  }

  Matcher refusedAsDamaged(String detail) => throwsA(
        predicate(
          (e) =>
              e.toString().contains('This backup file is damaged') &&
              e.toString().contains('Nothing on this device was changed') &&
              e.toString().contains(detail),
          'a damaged-backup refusal mentioning $detail',
        ),
      );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_validation_rest_');
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);

    await categories().put('cat-1', Category(id: 'cat-1', name: 'Starters'));
    await sessions().put(
      'sess-1',
      RestaurantSessionModel(
        sessionId: 'sess-1',
        startTime: DateTime(2026, 10, 29, 9),
        openingCash: 500,
      ),
    );
    await dayMgmt().putAll({'currentSessionId': 'sess-1', 'dayStarted': true});

    final exported = await UnifiedBackupService.collectAllDataForTesting();
    validBackup = jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a corrupt order record refuses the backup and changes nothing',
      () async {
    await divergeFromBackup();
    final backup = copyOfValid();
    // "orders" is restored late, after categories, items, past orders… —
    // before validation those boxes had already been replaced.
    (backup['data'] as Map<String, dynamic>)['orders'] = ['not a record'];

    final before = await deviceState(tempDir);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(backup),
      refusedAsDamaged('"orders" record 1 of 1'),
    );

    expect(await deviceState(tempDir), before,
        reason: 'every box, the AppConfig box and the files on disk are untouched');
    expect(categories().get('cat-after')?.name, 'Desserts');
    expect(dayMgmt().get('currentSessionId'), 'sess-after-backup');
  });

  test('a malformed settings block refuses the backup and changes nothing',
      () async {
    await divergeFromBackup();
    final backup = copyOfValid();
    (backup['data'] as Map<String, dynamic>)['appConfig'] = ['not a map'];

    final before = await deviceState(tempDir);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(backup),
      refusedAsDamaged('"appConfig" settings'),
    );

    expect(await deviceState(tempDir), before);
    expect(AppConfig.businessMode, BusinessMode.restaurant);
    expect(AppConfig.box.get('isSetupComplete'), isTrue);
  });

  test('a bad record in a step the restore tolerates does not block it',
      () async {
    final backup = copyOfValid();
    // itemCancellations is a try/catch-guarded restore step: today a bad
    // record there is logged and skipped, so validation must not refuse it.
    (backup['data'] as Map<String, dynamic>)['itemCancellations'] = ['bad'];

    await UnifiedBackupService.restoreDecodedBackupForTesting(backup);

    expect(categories().keys, ['cat-1'],
        reason: 'the rest of the backup was restored');
    expect(dayMgmt().get('currentSessionId'), 'sess-1');
  });

  test('a valid current-format backup restores every backed-up box',
      () async {
    await divergeFromBackup();

    await UnifiedBackupService.restoreDecodedBackupForTesting(copyOfValid());

    final restored = await exportedBackupData();
    final original = validBackup['data'] as Map<String, dynamic>;
    for (final key in restaurantBackedUp.values) {
      expect(restored[key], unorderedEquals(original[key] as List),
          reason: '$key comes back exactly as backed up');
    }
    expect(AppConfig.businessMode, BusinessMode.restaurant);
  });

  test('a valid legacy backup (no wrapper, no appMode) restores', () async {
    await divergeFromBackup();
    final legacy = <String, dynamic>{
      'categories': [
        Category(id: 'cat-legacy', name: 'Mains').toMap(),
      ],
      'tables': <dynamic>[],
    };

    await UnifiedBackupService.restoreDecodedBackupForTesting(legacy);

    expect(categories().keys, ['cat-legacy']);
    expect(AppConfig.businessMode, BusinessMode.restaurant);
    expect(AppConfig.box.get('isSetupComplete'), isTrue);
  });

  test('a corrupt record in a legacy backup is refused before any write',
      () async {
    await divergeFromBackup();
    final legacy = <String, dynamic>{
      'categories': [Category(id: 'cat-x', name: 'X').toMap()],
      'tables': ['not a record'],
    };

    final before = await deviceState(tempDir);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(legacy),
      refusedAsDamaged('"tables" record 1 of 1'),
    );
    expect(await deviceState(tempDir), before);
  });
}
