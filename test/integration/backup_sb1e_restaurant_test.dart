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

/// SB-1e (restaurant):
/// E1 — a restore whose safety copy cannot be made complete never starts.
/// E3 — the pending stock journal survives a failed restore and is cleared
///      only after a whole restore succeeded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box journal() => Hive.box(HiveBoxNames.restaurantStockJournal);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Map<String, dynamic> pendingEntry() =>
      {'id': 'settle:o-7', 'orderSaved': true, 'units': <dynamic>[]};

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_sb1e_rest_');
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await sessions().put(
      'sess-backup',
      RestaurantSessionModel(
        sessionId: 'sess-backup',
        startTime: DateTime(2026, 10, 28, 9),
        openingCash: 500,
      ),
    );
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await sessions().clear();
    await sessions().put(
      'sess-device',
      RestaurantSessionModel(
        sessionId: 'sess-device',
        startTime: DateTime(2026, 10, 29, 18),
        openingCash: 300,
      ),
    );
    await journal().clear();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('E1 incomplete safety copy', () {
    test('a section that cannot be exported stops the restore before any write',
        () async {
      final before = await deviceState(tempDir);
      // The printers box can't be read, so the snapshot would hold nothing
      // for it and a rollback would empty it while "verifying" equal.
      await Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters).close();

      Object? error;
      try {
        await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));
      } catch (e) {
        error = e;
      } finally {
        await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
      }

      expect(error, isNot(isA<RestoreFailedException>()),
          reason: 'refused before writing, not a failed write');
      expect(error.toString(), contains('The restore did not start'));
      expect(error.toString(), contains('complete safety copy'));
      expect(error.toString(), contains('printers'));
      expect(await deviceState(tempDir), before,
          reason: 'nothing on the device changed');
    });

    test('a later restore is not blocked by the earlier export failure',
        () async {
      await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));
      expect(sessions().keys, ['sess-backup']);
    });
  });

  group('E3 pending stock journal', () {
    test('a failed restore keeps the stock still owed', () async {
      await journal().put('settle:o-7', pendingEntry());
      UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

      await expectLater(
        UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
        throwsA(isA<RestoreFailedException>()
            .having((e) => e.rolledBack, 'rolledBack', isTrue)),
      );

      expect(journal().keys, ['settle:o-7']);
      expect(journal().get('settle:o-7'), pendingEntry());
    });

    test('a failure in the last common settings step also keeps it', () async {
      await journal().put('settle:o-7', pendingEntry());
      UnifiedBackupService.failWritingKeyForTesting = 'paymentMethods';

      await expectLater(
        UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(journal().keys, ['settle:o-7']);
    });

    test('a successful restore clears it', () async {
      await journal().put('settle:o-7', pendingEntry());

      await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

      expect(journal().isEmpty, isTrue,
          reason: 'its entries refer to orders and stock the restore replaced');
    });
  });
}
