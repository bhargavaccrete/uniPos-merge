import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/screens/common/backup/restore_skipped_notice.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

class _FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDocuments(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

/// The approved BKP-9 classification for Restaurant. Written out here, not
/// read from the service, so dropping a section from the service's set fails.
const restaurantCritical = [
  'itemCancellations',
  'cashMovements',
  'cashHandovers',
  'restaurantSessions',
  'dayManagement',
  'shifts',
  'appCounters',
  'customers',
  'stockMovements',
  'recipes',
  'recipeProductions',
  'restaurantSuppliers',
  'restaurantSupplierLedger',
  'restaurantPurchaseOrders',
  'restaurantPurchaseOrderItems',
  'restaurantGrns',
  'restaurantGrnItems',
  'restaurantPurchaseReturns',
  'restaurantPurchaseReturnItems',
  'restaurantSupplierClaims',
  'restaurantSupplierClaimItems',
  'restaurantInventoryLosses',
  'restaurantStockTakes',
  'restaurantStockTakeItems',
];

/// Sections whose restore step was already strict before BKP-9.
const restaurantAlreadyStrict = [
  'categories',
  'items',
  'variants',
  'choices',
  'extras',
  'staffBox',
  'taxes',
  'expenseCategories',
  'expenses',
  'tables',
  'eodReports',
  'pastOrders',
  'orders',
];

const restaurantNonCritical = [
  'restaurantCart',
  'testBillBox',
  'printers',
  'restaurantAttendance',
];

/// BKP-9 (Restaurant): an unreadable money, stock or ledger section refuses
/// the whole restore before anything is written; a non-critical one is
/// skipped and the result says "Import completed with warnings".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory docs;
  late Map<String, dynamic> backup;

  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);
  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box<ItemCancellationModel> cancellations() =>
      Hive.box<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations);
  Box<RecipeModel> recipes() =>
      Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes);
  Directory snapshots() => Directory(p.join(docs.path, 'restore_snapshots'));

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Map<String, dynamic> withUnreadable(Iterable<String> keys) {
    final bad = copy(backup);
    for (final k in keys) {
      (bad['data'] as Map<String, dynamic>)[k] = ['not a record'];
    }
    return bad;
  }

  ItemCancellationModel cancellation(String id) => ItemCancellationModel(
        id: id,
        itemName: 'Soup',
        quantity: 1,
        amount: 120,
        reason: 'Cold',
        orderId: 'o-$id',
        timestamp: DateTime(2026, 11, 14, 12),
      );

  /// This device after the backup was taken: different from it everywhere
  /// the tests look, so any write the restore makes would show.
  Future<void> seedDevice() async {
    await categories().clear();
    await categories()
        .put('cat-device', Category(id: 'cat-device', name: 'Desserts'));
    await sessions().clear();
    await sessions().put(
        'sess-device',
        RestaurantSessionModel(
            sessionId: 'sess-device',
            startTime: DateTime(2026, 11, 14, 18),
            openingCash: 300));
    await cancellations().clear();
    await cancellations().put('c-device', cancellation('c-device'));
    await recipes().clear();
    await recipes().put('rcp-device',
        RecipeModel(id: 'rcp-device', itemId: 'item-device', yieldQty: 4));
  }

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('backup_bkp9_rest_');
    docs = Directory(p.join(tempDir.path, 'documents'))..createSync();
    PathProviderPlatform.instance = _FakeDocuments(docs.path);
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);

    await categories()
        .put('cat-backup', Category(id: 'cat-backup', name: 'Starters'));
    await sessions().put(
        'sess-backup',
        RestaurantSessionModel(
            sessionId: 'sess-backup',
            startTime: DateTime(2026, 11, 13, 9),
            openingCash: 500));
    await cancellations().put('c-backup', cancellation('c-backup'));
    await recipes().put(
        'rcp-backup', RecipeModel(id: 'rcp-backup', itemId: 'item-backup'));
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    UnifiedBackupService.failPostRestoreStepForTesting = null;
    await seedDevice();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failPostRestoreStepForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> restore(Map<String, dynamic> b) =>
      UnifiedBackupService.restoreDecodedBackupForTesting(b);

  Matcher refusedFor(List<String> sections) => throwsA(
        isA<RestoreRefusedException>()
            .having((e) => e.sections, 'sections', sections)
            .having((e) => e.message, 'message',
                allOf(contains(sections.join(', ')),
                    contains('Nothing on this device was changed'))),
      );

  // ==========================================================================
  test('the service classifies exactly the approved Restaurant sections', () {
    expect(UnifiedBackupService.restaurantCriticalSections,
        unorderedEquals(restaurantCritical));
    final all = {
      ...restaurantCritical,
      ...restaurantAlreadyStrict,
      ...restaurantNonCritical,
    };
    expect(all, unorderedEquals(restaurantBackedUp.values),
        reason: 'every restored section is classified exactly once');
    expect(all.length,
        restaurantCritical.length +
            restaurantAlreadyStrict.length +
            restaurantNonCritical.length);
  });

  group('an unreadable critical section refuses the restore, device unchanged',
      () {
    for (final key in restaurantCritical) {
      test(key, () async {
        final before = await deviceState(tempDir);
        await expectLater(restore(withUnreadable([key])), refusedFor([key]));
        expect(await deviceState(tempDir), before);
        expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
      });
    }
  });

  group('an unreadable already-strict section still refuses, device unchanged',
      () {
    for (final key in restaurantAlreadyStrict) {
      test(key, () async {
        final before = await deviceState(tempDir);
        await expectLater(
          restore(withUnreadable([key])),
          throwsA(predicate((e) =>
              e.toString().contains('This backup file is damaged') &&
              e.toString().contains('Nothing on this device was changed'))),
        );
        expect(await deviceState(tempDir), before);
      });
    }
  });

  test('itemCancellations: the device keeps its own cancellations and '
      'nothing from the backup is written', () async {
    await expectLater(restore(withUnreadable(['itemCancellations'])),
        refusedFor(['itemCancellations']));
    expect(cancellations().keys, ['c-device']);
    expect(categories().keys, ['cat-device']);
    expect(sessions().keys, ['sess-device']);
  });

  test('recipes: the device keeps its own recipes and nothing is written',
      () async {
    await expectLater(
        restore(withUnreadable(['recipes'])), refusedFor(['recipes']));
    expect(recipes().keys, ['rcp-device']);
    expect(recipes().get('rcp-device')!.yieldQty, 4);
    expect(categories().keys, ['cat-device']);
  });

  test('several unreadable sections: all critical ones are named, sorted',
      () async {
    final before = await deviceState(tempDir);
    await expectLater(
      restore(withUnreadable(['recipes', 'printers', 'cashMovements'])),
      refusedFor(['cashMovements', 'recipes']),
    );
    expect(await deviceState(tempDir), before);
  });

  test('the refusal comes before the safety snapshot is taken', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await BackupEncryptionService.setPassword('pw-bkp9');
    try {
      if (snapshots().existsSync()) snapshots().deleteSync(recursive: true);
      await expectLater(restore(withUnreadable(['itemCancellations'])),
          refusedFor(['itemCancellations']));
      expect(snapshots().existsSync(), isFalse,
          reason: 'no snapshot: the refusal happened before it');

      // Control: the same restore without the bad section does take one.
      await restore(copy(backup));
      expect(snapshots().existsSync() && snapshots().listSync().isNotEmpty,
          isTrue);
    } finally {
      FlutterSecureStorage.setMockInitialValues({});
    }
  });

  // ==========================================================================
  group('an unreadable non-critical section is skipped and reported', () {
    for (final key in restaurantNonCritical) {
      test(key, () async {
        await restore(withUnreadable([key]));
        expect(UnifiedBackupService.lastRestoreSkippedSections, [key]);
        expect(categories().keys, ['cat-backup'],
            reason: 'the rest of the backup was restored');
        expect(cancellations().keys, ['c-backup']);
        final result = restoreResultContent(
          skipped: UnifiedBackupService.lastRestoreSkippedSections,
          postRestoreWarnings:
              UnifiedBackupService.lastRestorePostRestoreWarnings,
          web: false,
        );
        expect(result.title, 'Import completed with warnings');
        expect(result.hasWarnings, isTrue);
        expect(result.message, contains(key));
        expect(result.message, isNot(contains('successfully')));
      });
    }
  });

  test('a clean restore reports nothing and says "Data imported successfully"',
      () async {
    await restore(copy(backup));
    expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
    expect(UnifiedBackupService.lastRestorePostRestoreWarnings, isEmpty);
    final result = restoreResultContent(
      skipped: UnifiedBackupService.lastRestoreSkippedSections,
      postRestoreWarnings: UnifiedBackupService.lastRestorePostRestoreWarnings,
      web: false,
    );
    expect(result.title, 'Import Completed');
    expect(result.message, startsWith('Data imported successfully!'));
    expect(result.hasWarnings, isFalse);
  });

  // ==========================================================================
  group('device settings that fail to restore are warnings', () {
    test('localPrefs', () async {
      final b = copy(backup);
      (b['data'] as Map<String, dynamic>)['localPrefs'] = [
        {'key': 'some_flag', 'type': 'bool', 'value': 'not a bool'},
      ];
      await restore(b);
      expect(UnifiedBackupService.lastRestoreSkippedSections, ['localPrefs']);
      expect(categories().keys, ['cat-backup']);
      expect(
          restoreResultContent(
                  skipped: UnifiedBackupService.lastRestoreSkippedSections,
                  postRestoreWarnings: const [],
                  web: false)
              .title,
          'Import completed with warnings');
    });

    test('secureCreds', () async {
      final b = copy(backup);
      (b['data'] as Map<String, dynamic>)['secureCreds'] = ['not a map'];
      await restore(b);
      expect(UnifiedBackupService.lastRestoreSkippedSections, ['secureCreds']);
    });

    test('both, together with a skipped section', () async {
      final b = withUnreadable(['printers']);
      (b['data'] as Map<String, dynamic>)
        ..['localPrefs'] = [
          {'key': 'n', 'type': 'int', 'value': 'x'},
        ]
        ..['secureCreds'] = [7];
      await restore(b);
      expect(UnifiedBackupService.lastRestoreSkippedSections,
          ['localPrefs', 'printers', 'secureCreds']);
    });
  });

  group('a post-restore step that fails is a warning, not success', () {
    // The stock journal clear is no longer a post-restore step: it is part of
    // the restore and rolls back on failure (backup_journal_tx_*_test.dart).
    for (final step in [
      UnifiedBackupService.postStepItemImages,
    ]) {
      test(step, () async {
        UnifiedBackupService.failPostRestoreStepForTesting = step;
        await restore(copy(backup));
        expect(UnifiedBackupService.lastRestorePostRestoreWarnings, [step]);
        expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
        expect(categories().keys, ['cat-backup'],
            reason: 'the restore itself completed');
        final result = restoreResultContent(
          skipped: UnifiedBackupService.lastRestoreSkippedSections,
          postRestoreWarnings:
              UnifiedBackupService.lastRestorePostRestoreWarnings,
          web: true,
        );
        expect(result.title, 'Import completed with warnings');
        expect(result.message, contains(step));
        expect(result.message, isNot(contains('successfully')));
      });
    }
  });

  // ==========================================================================
  test('rollback is unchanged: a write failure with a skipped section still '
      'rolls everything back, verified', () async {
    final before = await deviceState(tempDir);
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

    await expectLater(
      restore(withUnreadable(['printers'])),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );
    expect(await deviceState(tempDir), before);
    expect(cancellations().keys, ['c-device']);
    expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty,
        reason: 'a failed restore reports no partial result');
  });

  testWidgets('onboarding: the notice after a real restore shows the warning '
      'title and the skipped section', (tester) async {
    await tester.runAsync(() async {
      await seedDevice();
      await restore(withUnreadable(['testBillBox']));
    });
    expect(UnifiedBackupService.lastRestoreSkippedSections, ['testBillBox']);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRestoreSkippedNotice(
                context, UnifiedBackupService.lastRestoreSkippedSections),
            child: const Text('restored'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('restored'));
    await tester.pumpAndSettle();

    expect(find.text('Import completed with warnings'), findsOneWidget);
    expect(find.textContaining('testBillBox'), findsOneWidget);
  });
}
