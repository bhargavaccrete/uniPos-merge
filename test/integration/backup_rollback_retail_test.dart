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

/// SB-1d (retail): a write failure partway through a restore rolls every box
/// back to its state before the restore and says so only when verified;
/// boxes an older backup lacks are emptied (true replace) and come back on
/// rollback; a section the restore tolerates as unreadable is left as it was
/// and reported, never silently emptied.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box<SavedPrinterModel> printers() =>
      Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);
  Box counters() => Hive.box(HiveBoxNames.appCounters);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Future<void> seedDevice() async {
    await sessions().clear();
    await sessions().put(
      'sess-device',
      RestaurantSessionModel(
        sessionId: 'sess-device',
        startTime: DateTime(2026, 10, 29, 18),
        openingCash: 300,
      ),
    );
    await printers().clear();
    await printers().put(
      'pr-device',
      SavedPrinterModel(
        id: 'pr-device',
        name: 'Counter',
        type: 'bluetooth',
        address: '00:11:22:33:44:55',
      ),
    );
    await dayMgmt().clear();
    await dayMgmt().putAll({'currentSessionId': 'sess-device', 'dayStarted': true});
    await counters().put('invoiceCounter', 812);
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_rollback_retail_');
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
    // grns is written after products, variants, sales, customers…
    UnifiedBackupService.failWritingKeyForTesting = 'grns';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      failedWith(rolledBack: true),
    );

    expect(await deviceState(tempDir), before,
        reason: 'every backed-up box, AppConfig and the files on disk match '
            'the state before the restore');
    expect(sessions().keys, ['sess-device']);
    expect(printers().keys, ['pr-device']);
    expect(dayMgmt().get('currentSessionId'), 'sess-device');
  });

  test('a failure in a settings write also rolls back', () async {
    final before = await deviceState(tempDir);
    // appConfig carries the business mode and setup flag.
    UnifiedBackupService.failWritingKeyForTesting = 'appConfig';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      failedWith(rolledBack: true),
    );
    expect(await deviceState(tempDir), before);
    expect(AppConfig.businessMode, BusinessMode.retail);
  });

  test('a successful restore matches the backup and reports nothing skipped',
      () async {
    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

    final restored = await exportedBackupData();
    final original = backup['data'] as Map<String, dynamic>;
    for (final key in retailBackedUp.values) {
      expect(restored[key], unorderedEquals(original[key] as List),
          reason: '$key comes back exactly as backed up');
    }
    expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
  });

  test('a legacy backup empties the boxes it lacks, but keeps counters',
      () async {
    final legacy = <String, dynamic>{
      'products': <dynamic>[],
      'suppliers': <dynamic>[],
    };

    await UnifiedBackupService.restoreDecodedBackupForTesting(legacy);

    expect(sessions().isEmpty, isTrue, reason: 'true replace');
    expect(printers().isEmpty, isTrue);
    expect(dayMgmt().isEmpty, isTrue);
    expect(counters().get('invoiceCounter'), 812,
        reason: 'emptying counters would reuse invoice numbers');
    expect(AppConfig.businessMode, BusinessMode.retail);
  });

  test('boxes a legacy backup emptied come back when a later write fails',
      () async {
    final before = await deviceState(tempDir);
    final legacy = <String, dynamic>{
      'products': <dynamic>[],
      'suppliers': <dynamic>[],
    };
    // Emptied after sessions and day state.
    UnifiedBackupService.failWritingKeyForTesting = 'printers';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(legacy),
      failedWith(rolledBack: true),
    );
    expect(await deviceState(tempDir), before);
    expect(sessions().keys, ['sess-device']);
    expect(printers().keys, ['pr-device']);
  });

  test('unreadable name-only categories leave the shared box as it was',
      () async {
    final bad = copy(backup);
    (bad['data'] as Map<String, dynamic>)['categories'] = [
      {'name': 'Shoes'},
    ];

    await UnifiedBackupService.restoreDecodedBackupForTesting(bad);

    expect(UnifiedBackupService.lastRestoreSkippedSections, ['categories']);
    expect(Hive.box<String>(HiveBoxNames.retailCategories).values, ['Shoes']);
    expect(sessions().keys, ['sess-backup'],
        reason: 'the rest of the backup was restored');
  });

  // Last: a failed rollback leaves the boxes in an unknown state.
  test('a rollback that cannot be completed is reported as not rolled back',
      () async {
    UnifiedBackupService.failWritingKeyForTesting = 'grns';
    UnifiedBackupService.failRollbackWritingKeyForTesting = 'products';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      failedWith(rolledBack: false),
    );
  });
}
