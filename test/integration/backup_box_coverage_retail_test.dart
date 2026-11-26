import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

/// BLK-05 (retail): every box retail opens is backed up or deliberately
/// excluded, and the boxes the retail backup used to drop (day sessions,
/// saved printers) survive the real export → JSON → restore path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Set<String> opened;

  final backedUp = {...commonBackedUp, ...retailBackedUp};
  final excluded = {...commonExcluded, ...retailExcluded};

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_cov_retail_');
    opened = await openBoxesFor('retail', tempDir);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box<SavedPrinterModel> printers() =>
      Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);

  test('every box retail opens is backed up or deliberately excluded', () {
    expectBoxCoverage(opened: opened, backedUp: backedUp, excluded: excluded);
  });

  test('HiveBoxNames lists match what retail opens', () {
    expect(
      lowerNames(
          [...HiveBoxNames.allCommonBoxes, ...HiveBoxNames.allRetailBoxes]),
      opened,
    );
  });

  test('the retail export carries a key for every backed-up box', () async {
    final data = await exportedBackupData();
    expect(data.keys.toSet(), containsAll(backedUp.values));
  });

  test('day sessions and printers survive export → restore', () async {
    await sessions().put(
      'sess-r1',
      RestaurantSessionModel(
        sessionId: 'sess-r1',
        startTime: DateTime(2026, 10, 28, 9),
        endTime: DateTime(2026, 10, 28, 21),
        openingCash: 1000,
        closingCash: 6420.5,
        isClosed: true,
      ),
    );
    await sessions().put(
      'sess-r2',
      RestaurantSessionModel(
        sessionId: 'sess-r2',
        startTime: DateTime(2026, 10, 29, 9),
        openingCash: 1000,
      ),
    );
    await printers().put(
      'pr-1',
      SavedPrinterModel(
        id: 'pr-1',
        name: 'Counter',
        type: 'bluetooth',
        address: '00:11:22:33:44:55',
        paperSize: 58,
        isDefault: true,
      ),
    );
    await dayMgmt().put('currentSessionId', 'sess-r2');

    final sessionsBefore = {
      for (final s in sessions().values) s.sessionId: s.toMap(),
    };
    final printersBefore = {for (final x in printers().values) x.id: x.toMap()};

    final data = await exportedBackupData();
    await sessions().clear();
    await printers().clear();
    await dayMgmt().clear();

    await UnifiedBackupService.restoreRetailDataForTesting(data);

    expect({for (final s in sessions().values) s.sessionId: s.toMap()},
        sessionsBefore,
        reason: 'every field of every session survives');
    expect({for (final x in printers().values) x.id: x.toMap()},
        printersBefore,
        reason: 'every field of every saved printer survives');
    expect(sessions().get(dayMgmt().get('currentSessionId')), isNotNull,
        reason: 'restored day state points at a restored session');
  });

  test('every backed-up retail box round-trips unchanged', () async {
    await sessions().put(
      's3',
      RestaurantSessionModel(
        sessionId: 's3',
        startTime: DateTime(2026, 10, 29),
        openingCash: 0,
      ),
    );
    await dayMgmt().put('dayStarted', true);

    final keys = retailBackedUp.values.toSet();
    final original = await exportedBackupData();
    expect(isEmptyExport('restaurantSessions', original['restaurantSessions']),
        isFalse);
    expect(isEmptyExport('printers', original['printers']), isFalse);

    // Wipe every retail box through the restore path itself.
    await UnifiedBackupService.restoreRetailDataForTesting(
        emptyBackupFor(keys));
    final wiped = await exportedBackupData();
    for (final k in keys) {
      expect(isEmptyExport(k, wiped[k]), isTrue, reason: '$k was wiped');
    }

    await UnifiedBackupService.restoreRetailDataForTesting(original);
    final restored = await exportedBackupData();
    for (final k in keys) {
      expect(restored[k], unorderedEquals(original[k] as List),
          reason: '$k comes back exactly as exported');
    }
  });
}
