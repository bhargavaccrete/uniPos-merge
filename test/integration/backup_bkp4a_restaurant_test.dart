import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/test_helpers.dart';

/// Batch 4a (BKP-3, BKP-4), through the real backup service: an open order's
/// bill number, session, last-modified stamp and KOT times survive a
/// restore and a rolled-back restore, an older backup without them still
/// restores, and the rollback's own comparison sees each of them.
///
/// Orders are compared as Hive objects, field by field — never through
/// `toMap`, which is exactly what BKP-4 says cannot see a dropped field.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Box<OrderModel> orders() => Hive.box<OrderModel>('orderBox');
  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  OrderModel order(String id, {bool withFields = true}) => OrderModel(
        id: id,
        customerName: 'Asha',
        customerNumber: '',
        customerEmail: '',
        items: [
          makeCartItem(id: '$id-l1', productId: 'p1', title: 'Paneer',
              price: 100, quantity: 2),
        ],
        status: 'Cooking',
        timeStamp: DateTime(2026, 11, 12, 12, 30),
        orderType: 'Dine In',
        tableNo: 'T4',
        totalPrice: 200,
        kotNumbers: [7, 9],
        itemCountAtLastKot: 1,
        kotBoundaries: [1, 1],
        kotStatuses: {7: 'Ready', 9: 'Cooking'},
        totalPaid: 100,
        paymentListJson: '[{"method":"cash","amount":100.0}]',
        billNumber: withFields ? 41 : null,
        sessionId: withFields ? 'sess-$id' : null,
        lastModifiedBy: withFields ? 'Ravi' : null,
        lastModifiedAt: withFields ? DateTime(2026, 11, 12, 12, 45, 10) : null,
        kotTimestamps: withFields
            ? {
                7: DateTime(2026, 11, 12, 12, 30, 5),
                9: DateTime(2026, 11, 12, 12, 50, 1),
              }
            : null,
      );

  /// The five BKP-3 fields of a saved order, read straight from Hive.
  Map<String, Object?> fiveOf(String id) {
    final o = orders().get(id)!;
    return {
      'billNumber': o.billNumber,
      'sessionId': o.sessionId,
      'lastModifiedBy': o.lastModifiedBy,
      'lastModifiedAt': o.lastModifiedAt,
      'kotTimestamps': o.kotTimestamps,
    };
  }

  Map<String, Object?> expectedFive(String id) => {
        'billNumber': 41,
        'sessionId': 'sess-$id',
        'lastModifiedBy': 'Ravi',
        'lastModifiedAt': DateTime(2026, 11, 12, 12, 45, 10),
        'kotTimestamps': {
          7: DateTime(2026, 11, 12, 12, 30, 5),
          9: DateTime(2026, 11, 12, 12, 50, 1),
        },
      };

  /// A backup of a device holding exactly [held].
  Future<Map<String, dynamic>> backupOf(List<OrderModel> held) async {
    await orders().clear();
    for (final o in held) {
      await orders().put(o.id, o);
    }
    return copy(await UnifiedBackupService.collectAllDataForTesting());
  }

  Future<void> deviceHolds(List<OrderModel> held) async {
    await orders().clear();
    for (final o in held) {
      await orders().put(o.id, o);
    }
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_bkp4a_rest_');
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
  });

  setUp(() {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a restore puts the five fields back exactly', () async {
    final backup = await backupOf([order('o-backup')]);
    await deviceHolds([order('o-device')]);

    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

    expect(orders().keys, ['o-backup']);
    expect(fiveOf('o-backup'), expectedFive('o-backup'));
    expect(orders().get('o-backup')!.kotTimestamps!.keys.first, isA<int>());
  });

  test('the backup file carries them (kotTimestamps as string keys)',
      () async {
    final backup = await backupOf([order('o1')]);
    final saved = ((backup['data'] as Map)['orders'] as List).single as Map;
    expect(saved['billNumber'], 41);
    expect(saved['sessionId'], 'sess-o1');
    expect(saved['lastModifiedBy'], 'Ravi');
    expect(saved['lastModifiedAt'], '2026-11-12T12:45:10.000');
    expect(saved['kotTimestamps'], {
      '7': '2026-11-12T12:30:05.000',
      '9': '2026-11-12T12:50:01.000',
    });
  });

  test('an older backup without the five keys restores, with them null',
      () async {
    final backup = await backupOf([order('o-old')]);
    for (final o in ((backup['data'] as Map)['orders'] as List)) {
      (o as Map)
        ..remove('billNumber')
        ..remove('sessionId')
        ..remove('lastModifiedBy')
        ..remove('lastModifiedAt')
        ..remove('kotTimestamps');
    }
    await deviceHolds([order('o-device')]);

    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

    expect(orders().keys, ['o-old']);
    expect(fiveOf('o-old').values, everyElement(isNull));
    expect(orders().get('o-old')!.totalPaid, 100, reason: 'the rest restored');
  });

  test('a failed restore rolls the device back WITH the five fields, '
      'verified', () async {
    final backup = await backupOf([order('o-backup')]);
    await deviceHolds([order('o-device'), order('o-plain', withFields: false)]);
    // restaurantSessions is written after the orders.
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(orders().keys.toSet(), {'o-device', 'o-plain'});
    expect(fiveOf('o-device'), expectedFive('o-device'));
    expect(fiveOf('o-plain').values, everyElement(isNull),
        reason: 'unset stays unset');
  });

  test('the rollback comparison sees a change in each of the five fields',
      () async {
    final export = await backupOf([order('o1')]);
    expect(UnifiedBackupService.sameBackedUpDataForTesting(export, copy(export)),
        isTrue);

    for (final (field, other) in <(String, Object?)>[
      ('billNumber', 42),
      ('sessionId', 'sess-other'),
      ('lastModifiedBy', 'Meena'),
      ('lastModifiedAt', '2026-11-12T13:00:00.000'),
      ('kotTimestamps', {'7': '2026-11-12T12:30:05.000'}),
      ('billNumber', null),
    ]) {
      final changed = copy(export);
      ((changed['data'] as Map)['orders'] as List).single[field] = other;
      expect(
          UnifiedBackupService.sameBackedUpDataForTesting(export, changed),
          isFalse,
          reason: '$field → $other must not compare equal');
    }
  });
}
