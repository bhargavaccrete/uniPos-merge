import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// SB-1c (retail): the whole backup is read before anything is cleared. A
/// record the restore cannot read in a step that would abort part-way, or a
/// malformed settings block, refuses the backup with every box and setting
/// untouched. Valid current-format and legacy backups, including old
/// name-only categories, still restore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> validBackup;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);
  Box<String> legacyCategories() =>
      Hive.box<String>(HiveBoxNames.retailCategories);

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
    tempDir = await Directory.systemTemp.createTemp('backup_validation_retail_');
    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);

    await sessions().put(
      'sess-1',
      RestaurantSessionModel(
        sessionId: 'sess-1',
        startTime: DateTime(2026, 10, 29, 9),
        openingCash: 1000,
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

  test('a corrupt sale record refuses the backup and changes nothing',
      () async {
    await divergeFromBackup();
    final backup = copyOfValid();
    // "sales" is restored after products, variants, counters and the cart —
    // before validation those boxes had already been replaced.
    (backup['data'] as Map<String, dynamic>)['sales'] = ['not a record'];

    final before = await deviceState(tempDir);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(backup),
      refusedAsDamaged('"sales" record 1 of 1'),
    );

    expect(await deviceState(tempDir), before,
        reason: 'every box, the AppConfig box and the files on disk are untouched');
    expect(dayMgmt().get('currentSessionId'), 'sess-after-backup');
  });

  test('a malformed payment-methods block refuses the backup', () async {
    await divergeFromBackup();
    final backup = copyOfValid();
    (backup['data'] as Map<String, dynamic>)['paymentMethods'] = ['not a map'];

    final before = await deviceState(tempDir);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(backup),
      refusedAsDamaged('"paymentMethods" record 1 of 1'),
    );
    expect(await deviceState(tempDir), before);
    expect(AppConfig.businessMode, BusinessMode.retail);
  });

  test('old name-only categories are tolerated exactly as before', () async {
    final backup = copyOfValid();
    // Older retail backups stored categories as names only. The shared
    // category step cannot read them and has always skipped them; the legacy
    // category box still takes the names.
    (backup['data'] as Map<String, dynamic>)['categories'] = [
      {'name': 'Shoes'},
      {'name': 'Bags'},
    ];

    await UnifiedBackupService.restoreDecodedBackupForTesting(backup);

    expect(legacyCategories().values, ['Shoes', 'Bags']);
    expect(dayMgmt().get('currentSessionId'), 'sess-1',
        reason: 'the rest of the backup was restored');
  });

  test('a valid current-format backup restores every backed-up box',
      () async {
    await divergeFromBackup();

    await UnifiedBackupService.restoreDecodedBackupForTesting(copyOfValid());

    final restored = await exportedBackupData();
    final original = validBackup['data'] as Map<String, dynamic>;
    for (final key in retailBackedUp.values) {
      expect(restored[key], unorderedEquals(original[key] as List),
          reason: '$key comes back exactly as backed up');
    }
    expect(AppConfig.businessMode, BusinessMode.retail);
  });

  test('a valid legacy backup (no wrapper, no appMode) restores', () async {
    await divergeFromBackup();
    final legacy = <String, dynamic>{
      'products': <dynamic>[],
      'suppliers': <dynamic>[],
      'categories': [
        {'name': 'Toys'},
      ],
    };

    await UnifiedBackupService.restoreDecodedBackupForTesting(legacy);

    expect(legacyCategories().values, ['Toys']);
    expect(AppConfig.businessMode, BusinessMode.retail);
    expect(AppConfig.box.get('isSetupComplete'), isTrue);
  });

  test('a corrupt record in a legacy backup is refused before any write',
      () async {
    await divergeFromBackup();
    final legacy = <String, dynamic>{
      'products': ['not a record'],
      'suppliers': <dynamic>[],
    };

    final before = await deviceState(tempDir);
    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(legacy),
      refusedAsDamaged('"products" record 1 of 1'),
    );
    expect(await deviceState(tempDir), before);
  });
}
