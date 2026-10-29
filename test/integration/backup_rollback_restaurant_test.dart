import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// SB-1d (restaurant): a write failure partway through a restore rolls every
/// box back to its state before the restore and says so only when verified;
/// boxes an older backup lacks are emptied (true replace) and come back on
/// rollback; a section the restore tolerates as unreadable is left as it was
/// and reported, never silently emptied.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;

  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);
  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box<ItemCancellationModel> cancellations() =>
      Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations);
  Box<Items> items() => Hive.box<Items>(HiveBoxNames.restaurantItems);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);
  Box counters() => Hive.box(HiveBoxNames.appCounters);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  ItemCancellationModel cancellation(String id) => ItemCancellationModel(
        id: id,
        itemName: 'Soup',
        quantity: 1,
        amount: 120,
        reason: 'Cold',
        orderId: 'o-$id',
        timestamp: DateTime(2026, 10, 29, 12),
      );

  /// This device's data after the backup was taken: different in every box
  /// the tests look at, so any leftover restore write would show.
  Future<void> seedDevice() async {
    await categories().clear();
    await categories().put('cat-device', Category(id: 'cat-device', name: 'Desserts'));
    await sessions().clear();
    await sessions().put(
      'sess-device',
      RestaurantSessionModel(
        sessionId: 'sess-device',
        startTime: DateTime(2026, 10, 29, 18),
        openingCash: 300,
      ),
    );
    await cancellations().clear();
    await cancellations().put('c-device', cancellation('c-device'));
    await items().clear();
    await items().put(
      'item-device',
      Items(
        id: 'item-device',
        name: 'Brownie',
        imageBytes: Uint8List.fromList([9, 8, 7]),
      ),
    );
    await dayMgmt().clear();
    await dayMgmt().putAll({'currentSessionId': 'sess-device', 'dayStarted': true});
    await counters().put('billCounter', 57);
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_rollback_rest_');
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);

    // The backup: its own categories, sessions and day state.
    await categories().put('cat-backup', Category(id: 'cat-backup', name: 'Starters'));
    await sessions().put(
      'sess-backup',
      RestaurantSessionModel(
        sessionId: 'sess-backup',
        startTime: DateTime(2026, 10, 28, 9),
        openingCash: 500,
      ),
    );
    await dayMgmt().putAll({'currentSessionId': 'sess-backup', 'dayStarted': true});
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    await seedDevice();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Matcher failedWith({required bool rolledBack}) => throwsA(
        isA<RestoreFailedException>()
            .having((e) => e.rolledBack, 'rolledBack', rolledBack),
      );

  test('a write failure partway rolls every box back and says so', () async {
    final before = await deviceState(tempDir);
    // restaurantSessions is written after categories, items, orders…: by the
    // time it fails, those boxes already hold the backup.
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      failedWith(rolledBack: true),
    );

    expect(await deviceState(tempDir), before,
        reason: 'every backed-up box, AppConfig and the files on disk match '
            'the state before the restore');
    expect(categories().keys, ['cat-device']);
    expect(sessions().keys, ['sess-device']);
    expect(dayMgmt().get('currentSessionId'), 'sess-device');
    expect(items().get('item-device')?.imageBytes, [9, 8, 7],
        reason: 'item image bytes, which the export strips, are put back too');
  });

  test('a failure in a settings write also rolls back', () async {
    final before = await deviceState(tempDir);
    UnifiedBackupService.failWritingKeyForTesting = 'paymentMethods';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      failedWith(rolledBack: true),
    );
    expect(await deviceState(tempDir), before);
    expect(AppConfig.businessMode, BusinessMode.restaurant);
  });

  test('a successful restore matches the backup and reports nothing skipped',
      () async {
    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

    final restored = await exportedBackupData();
    final original = backup['data'] as Map<String, dynamic>;
    for (final key in restaurantBackedUp.values) {
      expect(restored[key], unorderedEquals(original[key] as List),
          reason: '$key comes back exactly as backed up');
    }
    expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
  });

  test('a legacy backup empties the boxes it lacks, but keeps counters',
      () async {
    final legacy = <String, dynamic>{
      'categories': [Category(id: 'cat-legacy', name: 'Mains').toMap()],
      'tables': <dynamic>[],
    };

    await UnifiedBackupService.restoreDecodedBackupForTesting(legacy);

    expect(categories().keys, ['cat-legacy']);
    expect(cancellations().isEmpty, isTrue,
        reason: 'true replace: the backup has no cancellations');
    expect(sessions().isEmpty, isTrue);
    expect(dayMgmt().isEmpty, isTrue);
    expect(counters().get('billCounter'), 57,
        reason: 'emptying counters would restart bill numbers');
  });

  test('boxes a legacy backup emptied come back when a later write fails',
      () async {
    final before = await deviceState(tempDir);
    final legacy = <String, dynamic>{
      'categories': [Category(id: 'cat-legacy', name: 'Mains').toMap()],
      'tables': <dynamic>[],
    };
    // Written (emptied) late, after cancellations and sessions were emptied.
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantStockTakeItems';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(legacy),
      failedWith(rolledBack: true),
    );
    expect(await deviceState(tempDir), before);
    expect(cancellations().keys, ['c-device']);
    expect(sessions().keys, ['sess-device']);
  });

  test('an unreadable tolerated section is left as it was and reported',
      () async {
    final bad = copy(backup);
    (bad['data'] as Map<String, dynamic>)['itemCancellations'] = ['not a record'];

    await UnifiedBackupService.restoreDecodedBackupForTesting(bad);

    expect(cancellations().keys, ['c-device'],
        reason: 'not silently emptied');
    expect(UnifiedBackupService.lastRestoreSkippedSections,
        ['itemCancellations']);
    expect(categories().keys, ['cat-backup'],
        reason: 'the rest of the backup was restored');
  });

  // Last: a failed rollback leaves the boxes in an unknown state.
  test('a rollback that cannot be completed is reported as not rolled back',
      () async {
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';
    UnifiedBackupService.failRollbackWritingKeyForTesting = 'categories';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      failedWith(rolledBack: false),
    );
  });
}
