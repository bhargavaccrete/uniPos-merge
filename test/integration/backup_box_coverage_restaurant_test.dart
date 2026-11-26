import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

/// BLK-05 (restaurant): every box restaurant opens is backed up or
/// deliberately excluded, and the boxes the backup used to drop (item
/// cancellations, day state) survive the real export → JSON → restore path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Set<String> opened;

  final backedUp = {...commonBackedUp, ...restaurantBackedUp};
  final excluded = {...commonExcluded, ...restaurantExcluded};

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_cov_restaurant_');
    opened = await openBoxesFor('restaurant', tempDir);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Box<ItemCancellationModel> cancellations() =>
      Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations);
  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box dayMgmt() => Hive.box(HiveBoxNames.dayManagementBox);

  test('every box restaurant opens is backed up or deliberately excluded', () {
    expectBoxCoverage(opened: opened, backedUp: backedUp, excluded: excluded);
  });

  test('HiveBoxNames lists match what restaurant opens', () {
    expect(
      lowerNames(
          [...HiveBoxNames.allCommonBoxes, ...HiveBoxNames.allRestaurantBoxes]),
      opened,
    );
  });

  test('the restaurant export carries a key for every backed-up box', () async {
    final data = await exportedBackupData();
    expect(data.keys.toSet(), containsAll(backedUp.values));
  });

  test('item cancellations and day state survive export → restore', () async {
    await cancellations().put(
      'c1',
      ItemCancellationModel(
        id: 'c1',
        itemName: 'Paneer Tikka',
        variantName: 'Full',
        quantity: 2,
        amount: 480.5,
        reason: 'Customer changed mind',
        orderId: 'o-9',
        billNumber: 41,
        kotNumber: 7,
        staffName: 'Asha',
        timestamp: DateTime(2026, 10, 29, 13, 5),
        sessionId: 'sess-1',
        orderType: 'Dine In',
        tableNo: 'T4',
      ),
    );
    await cancellations().put(
      'c2',
      ItemCancellationModel(
        id: 'c2',
        itemName: 'Lassi',
        quantity: 1,
        amount: 90,
        reason: 'Wrong item',
        orderId: 'o-10',
        timestamp: DateTime(2026, 10, 29, 14),
      ),
    );
    await sessions().put(
      'sess-1',
      RestaurantSessionModel(
        sessionId: 'sess-1',
        startTime: DateTime(2026, 10, 29, 9),
        openingCash: 500,
      ),
    );
    await dayMgmt().putAll({
      'currentSessionId': 'sess-1',
      'openingBalance': 500.0,
      'dayStarted': true,
    });

    final cancellationsBefore = {
      for (final c in cancellations().values) c.id: c.toMap(),
    };
    final dayBefore = {for (final k in dayMgmt().keys) k: dayMgmt().get(k)};

    final data = await exportedBackupData();
    await cancellations().clear();
    await sessions().clear();
    await dayMgmt().clear();
    await dayMgmt().put('currentSessionId', 'stale-device-session');

    await UnifiedBackupService.restoreRestaurantDataForTesting(data);

    expect(
      {for (final c in cancellations().values) c.id: c.toMap()},
      cancellationsBefore,
      reason: 'every field of every cancellation survives',
    );
    expect(cancellations().get('c1')?.billNumber, 41, reason: 'keyed by id');
    expect({for (final k in dayMgmt().keys) k: dayMgmt().get(k)}, dayBefore,
        reason: "the backup's day state replaces this device's");
    expect(sessions().get(dayMgmt().get('currentSessionId')), isNotNull,
        reason: 'the restored current session exists in the sessions box');
  });

  test('every backed-up restaurant box round-trips unchanged', () async {
    await cancellations().put(
      'c3',
      ItemCancellationModel(
        id: 'c3',
        itemName: 'Tea',
        quantity: 1,
        amount: 20,
        reason: 'r',
        orderId: 'o',
        timestamp: DateTime(2026, 10, 29),
      ),
    );
    await dayMgmt().put('dayStarted', true);

    final keys = restaurantBackedUp.values.toSet();
    final original = await exportedBackupData();
    expect(isEmptyExport('itemCancellations', original['itemCancellations']),
        isFalse);
    expect(isEmptyExport('dayManagement', original['dayManagement']), isFalse);

    // Wipe every restaurant box through the restore path itself.
    await UnifiedBackupService.restoreRestaurantDataForTesting(
        emptyBackupFor(keys));
    final wiped = await exportedBackupData();
    for (final k in keys) {
      expect(isEmptyExport(k, wiped[k]), isTrue, reason: '$k was wiped');
    }

    await UnifiedBackupService.restoreRestaurantDataForTesting(original);
    final restored = await exportedBackupData();
    for (final k in keys) {
      expect(restored[k], unorderedEquals(original[k] as List),
          reason: '$k comes back exactly as exported');
    }
  });
}
