import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/extramodel_303.dart';
import 'package:billberrylite/data/repositories/restaurant/eod_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/extra_repository.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

/// Batch 4b (BKP-2), Restaurant: extras and End of Day reports come back
/// from a restore keyed by their own IDs, so the app's repositories — which
/// look records up, update and delete them BY ID — work on restored data.
/// No record is lost: a repeated or blank ID keeps an automatic key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Box<Extramodel> extras() => Hive.box<Extramodel>('extra');
  Box<EndOfDayReport> eods() => Hive.box<EndOfDayReport>('restaurant_eodBox');
  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Extramodel extra(String id, String name) => Extramodel(Id: id, Ename: name);

  EndOfDayReport eod(String id, {double sales = 1000}) => EndOfDayReport(
        reportId: id,
        date: DateTime(2026, 11, 12),
        openingBalance: 500,
        orderSummaries: const [],
        totalDiscount: 0,
        totalTax: 0,
        categorySales: const [],
        paymentSummaries: const [],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: 1500,
          actualCash: 1500,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),
        totalSales: sales,
        closingBalance: 1500,
        taxSummaries: const [],
        totalOrderCount: 3,
        totalRefunds: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        mode: 'restaurant',
      );

  /// Seeds through the repositories, as the app writes (put by ID).
  Future<void> deviceHolds(
      {List<Extramodel> ex = const [], List<EndOfDayReport> eo = const []}) async {
    await extras().clear();
    await eods().clear();
    for (final e in ex) {
      await ExtraRepository().addExtra(e);
    }
    for (final r in eo) {
      await EodRepository().addEODReport(r);
    }
  }

  Future<Map<String, dynamic>> backupOf(
      {List<Extramodel> ex = const [], List<EndOfDayReport> eo = const []}) async {
    await deviceHolds(ex: ex, eo: eo);
    return copy(await UnifiedBackupService.collectAllDataForTesting());
  }

  Future<void> restore(Map<String, dynamic> backup) =>
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_bkp2_rest_');
    await openBoxesFor('restaurant', tempDir);
    // openBoxesFor sets the mode; the repositories pick their box from it.
    expect(AppConfig.businessMode, BusinessMode.restaurant);
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

  // ==========================================================================
  group('extras', () {
    test('restored under their IDs: found, updated in place, deleted',
        () async {
      final backup = await backupOf(
          ex: [extra('e1', 'Cheese'), extra('e2', 'Sauces')]);
      await deviceHolds(ex: [extra('e-device', 'Old')]);

      await restore(backup);

      expect(extras().keys.toSet(), {'e1', 'e2'});
      final repo = ExtraRepository();
      expect((await repo.getExtraById('e1'))?.Ename, 'Cheese');

      await repo.updateExtra(extra('e1', 'Extra cheese'));
      expect(extras().length, 2, reason: 'edited in place, not duplicated');
      expect((await repo.getExtraById('e1'))?.Ename, 'Extra cheese');

      await repo.deleteExtra('e2');
      expect(extras().keys, ['e1'], reason: 'delete by ID works');
    });
  });

  // ==========================================================================
  group('End of Day reports', () {
    test('restored under their IDs: updated in place, deleted', () async {
      final backup = await backupOf(eo: [eod('r1'), eod('r2')]);
      await deviceHolds(eo: [eod('r-device')]);

      await restore(backup);

      expect(eods().keys.toSet(), {'r1', 'r2'});
      final repo = EodRepository();
      await repo.updateEODReport(eod('r1', sales: 2500));
      expect(eods().length, 2, reason: 'no duplicate report');
      expect(eods().get('r1')!.totalSales, 2500);

      await repo.deleteEODReport('r2');
      expect(eods().keys, ['r1']);
    });

    test('reports with a blank ID are all kept (automatic keys)', () async {
      final backup = await backupOf(eo: [eod('r1')]);
      final list = (backup['data'] as Map)['eodReports'] as List;
      list.addAll([
        {...(list.first as Map), 'reportId': ''},
        {...(list.first as Map), 'reportId': ''},
      ]);

      await restore(backup);

      expect(eods().length, 3, reason: 'none collapsed into one');
      expect(eods().get('r1'), isNotNull);
      expect(UnifiedBackupService.lastRestoreUnkeyedRecords['eodReports'], 2);
    });
  });

  // ==========================================================================
  test('a repeated ID loses no record; the last copy takes the ID key',
      () async {
    final backup = await backupOf(ex: [extra('e1', 'Cheese')]);
    final list = (backup['data'] as Map)['extras'] as List;
    // A device restored before BKP-2 then edited: the old copy (automatic
    // key, listed first) and the edited one (ID key, listed last).
    list
      ..clear()
      ..addAll([
        extra('e1', 'Cheese (old)').toMap(),
        extra('e1', 'Cheese (edited)').toMap(),
      ]);

    await restore(backup);

    expect(extras().length, 2, reason: 'every record restored');
    expect((await ExtraRepository().getExtraById('e1'))?.Ename,
        'Cheese (edited)', reason: 'what an ID lookup returned before');
    expect(UnifiedBackupService.lastRestoreUnkeyedRecords['extras'], 1);
  });

  test('a normal restore reports no record without its ID key', () async {
    await restore(await backupOf(ex: [extra('e1', 'A')], eo: [eod('r1')]));
    expect(UnifiedBackupService.lastRestoreUnkeyedRecords, isEmpty);
  });

  test('a failed restore rolls extras and reports back under their IDs, '
      'verified', () async {
    final backup = await backupOf(ex: [extra('e-backup', 'X')]);
    await deviceHolds(
        ex: [extra('e1', 'Cheese'), extra('e2', 'Sauces')],
        eo: [eod('r1')]);
    // restaurantSessions is written after extras and End of Day reports.
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

    await expectLater(
      restore(backup),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(extras().keys.toSet(), {'e1', 'e2'});
    expect(eods().keys, ['r1']);
    await ExtraRepository().deleteExtra('e1');
    expect(extras().keys, ['e2'], reason: 'ID operations work after rollback');
  });
}
