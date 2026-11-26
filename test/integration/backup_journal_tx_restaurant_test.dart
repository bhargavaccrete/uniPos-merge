import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/services/restaurant/void_order_commit.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';
import '../helpers/test_helpers.dart';

class _FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDocuments(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

/// The pending-work journal clear is part of the restore transaction
/// (Restaurant): the restored data and the emptied stock journal succeed
/// together, or the business data AND every original journal entry (Settle,
/// void, cancel, goods receipt) go back, so the original work still finishes
/// exactly once and stale entries never replay onto restored data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;

  Box<Items> items() => Hive.box<Items>(HiveBoxNames.restaurantItems);
  Box<OrderModel> orders() => Hive.box<OrderModel>(HiveBoxNames.restaurantOrders);
  Box<TableModel> tables() => Hive.box<TableModel>(HiveBoxNames.restaurantTables);
  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);
  Box journal() => Hive.box(HiveBoxNames.restaurantStockJournal);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  /// The journal exactly as stored, comparable across the restore.
  String journalState() => jsonEncode({
        for (final k in (journal().keys.map((k) => k.toString()).toList()
          ..sort()))
          k: journal().get(k),
      });

  Future<void> registerStores() async {
    await locator.reset();
    locator
      ..registerSingleton<ItemStore>(ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(PastOrderRepository()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerSingleton<OrderStore>(OrderStore(OrderRepository()))
      ..registerLazySingleton<TableStore>(() => TableStore(TableRepository()));
  }

  /// A fresh app process over what is on disk.
  Future<void> restart() async {
    await registerStores();
    await itemStore.loadItems();
    await orderStore.loadOrders();
  }

  JournalEntry entry(String id, String orderId, String itemId, double qty,
          String direction, {String? tableNo}) =>
      JournalEntry(
        id: id,
        orderId: orderId,
        createdAt: DateTime(2026, 11, 15, 10),
        target: const {},
        staffName: 'Ravi',
        tableNo: tableNo,
        orderSaved: true,
        units: [
          JournalUnit(
            uid: '$id:0',
            itemId: itemId,
            qty: qty,
            reason: 'pending work',
            itemName: itemId,
            unit: 'pcs',
            direction: direction,
          ),
        ],
      );

  /// This device: its own stock, an active order on T5, and four pieces of
  /// pending work — a Settle deduction, a void of o1, a cancel return and a
  /// goods-receipt intent.
  Future<void> seedDevice() async {
    await categories().clear();
    await categories()
        .put('cat-device', Category(id: 'cat-device', name: 'Desserts'));
    await items().clear();
    for (final id in ['A', 'B', 'C']) {
      await items().put(
          id, Items(id: id, name: id, trackInventory: true, stockQuantity: 10));
    }
    await orders().clear();
    await orders().put(
      'o1',
      OrderModel(
        id: 'o1',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: [
          makeCartItem(id: 'l1', productId: 'B', title: 'B', price: 10,
              quantity: 1),
        ],
        status: 'Processing',
        timeStamp: DateTime(2026, 11, 15, 9),
        orderType: 'Dine In',
        tableNo: 'T5',
        totalPrice: 10,
        kotNumbers: [1],
        itemCountAtLastKot: 1,
        kotBoundaries: [1],
      ),
    );
    await tables().clear();
    await tables().put(
        'T5', TableModel(id: 'T5', status: 'Running', currentOrderId: 'o1'));
    await Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
        .clear();
    await journal().clear();
    await StockJournal.save(
        entry('settle:s1', 'o-settled', 'A', 2, StockJournal.outbound));
    await StockJournal.save(entry(StockJournal.voidKey('o1'), 'o1', 'B', 1,
        StockJournal.inbound, tableNo: 'T5'));
    await StockJournal.save(
        entry('cancel:c1', 'o-cancelled', 'C', 3, StockJournal.inbound));
    await journal().put('grn:gi1', {
      'state': 'written',
      'before': 4.0,
      'after': 9.0,
    });
    await restart();
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_journal_tx_rest_');
    PathProviderPlatform.instance = _FakeDocuments(
        (Directory(p.join(tempDir.path, 'documents'))..createSync()).path);
    await openBoxesFor('restaurant', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await registerStores();

    // The backup: other stock, no active order, its own category.
    await categories()
        .put('cat-backup', Category(id: 'cat-backup', name: 'Starters'));
    for (final id in ['A', 'B', 'C']) {
      await items().put(
          id, Items(id: id, name: id, trackInventory: true, stockQuantity: 50));
    }
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    UnifiedBackupService.failWorkJournalClearForTesting = null;
    UnifiedBackupService.failWorkJournalPutBackForTesting = false;
    await seedDevice();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWorkJournalClearForTesting = null;
    UnifiedBackupService.failWorkJournalPutBackForTesting = false;
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> restore() =>
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

  double stock(String id) => items().get(id)!.stockQuantity;
  int rows() => [
        for (final id in ['A', 'B', 'C'])
          ...StockMovementRepository().movementsForItem(id),
      ].length;
  String world() => [stock('A'), stock('B'), stock('C'), rows(),
        orders().containsKey('o1'), tables().get('T5')?.status,
        journalState()].join('|');

  Future<void> recoverEverything() async {
    await restart();
    await StockJournal.recoverAll();
    await VoidOrderCommit.recoverAll();
    await StockJournal.recoverCancels();
  }

  // A ========================================================================
  test('A: a successful restore empties the journal, with no warning',
      () async {
    expect(journal().length, 4);
    await restore();

    expect(journal().isEmpty, isTrue);
    expect(categories().keys, ['cat-backup']);
    expect(stock('A'), 50);
    expect(UnifiedBackupService.lastRestorePostRestoreWarnings, isEmpty);
    expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);

    // Nothing is left to replay onto the restored data.
    await recoverEverything();
    expect([stock('A'), stock('B'), stock('C'), rows()], [50, 50, 50, 0]);
  });

  // B ========================================================================
  test('B: a failed clear rolls everything back; every entry is still there',
      () async {
    final before = await deviceState(tempDir);
    final journalBefore = journalState();
    UnifiedBackupService.failWorkJournalClearForTesting = 0;

    await expectLater(
      restore(),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)
          .having((e) => e.dataRolledBack, 'dataRolledBack', isTrue)
          .having((e) => e.journalRestored, 'journalRestored', isTrue)
          .having((e) => e.unrestoredJournal, 'unrestoredJournal', isNull)
          .having((e) => e.userMessage, 'userMessage',
              contains('your previous data was put back and checked'))),
    );

    expect(await deviceState(tempDir), before,
        reason: 'all original business data is back');
    expect(journalState(), journalBefore);
    expect(categories().keys, ['cat-device']);
    expect(stock('A'), 10);
  });

  // C ========================================================================
  group('C: a clear that fails part-way', () {
    test('every original entry is put back on rollback', () async {
      final before = await deviceState(tempDir);
      final journalBefore = journalState();
      UnifiedBackupService.failWorkJournalClearForTesting = 2;

      await expectLater(
        restore(),
        throwsA(isA<RestoreFailedException>()
            .having((e) => e.rolledBack, 'rolledBack', isTrue)),
      );

      expect(journal().length, 4);
      expect(journalState(), journalBefore,
          reason: 'the removed entries came back exactly');
      expect(await deviceState(tempDir), before);
    });

    test('if putting the journal back fails: business data verified, journal '
        'not, and the message says exactly that', () async {
      UnifiedBackupService.failWorkJournalClearForTesting = 2;
      UnifiedBackupService.failWorkJournalPutBackForTesting = true;

      Object? error;
      try {
        await restore();
      } catch (e) {
        error = e;
      }

      expect(error, isA<RestoreFailedException>());
      final failure = error as RestoreFailedException;
      expect(failure.rolledBack, isFalse,
          reason: 'the device is not exactly as before');
      expect(failure.dataRolledBack, isTrue,
          reason: 'the business data was put back and verified');
      expect(failure.journalRestored, isFalse);
      expect(failure.unrestoredJournal, 'Restaurant stock journal');
      expect(failure.unrestoredJournalEntries.keys.toSet(),
          {'settle:s1', 'void:o1', 'cancel:c1', 'grn:gi1'},
          reason: 'the entries are kept, never silently discarded');
      expect(failure.userMessage,
          contains('Your business data was put back and checked'));
      expect(failure.userMessage,
          contains('4 entries of unfinished stock work in the Restaurant '
              'stock journal could not be put back'));
      expect(failure.userMessage, isNot(contains('could NOT be fully put back')),
          reason: 'must not say the business data was not restored');
      expect(failure.toString(), contains('dataRolledBack: true'));
      expect(failure.toString(), contains('journalRestored: false'));
      expect(failure.toString(), contains('Restaurant stock journal'));
      expect(journal().length, 2, reason: 'the part-way clear did happen');
      expect(categories().keys, ['cat-device'],
          reason: 'the business data itself was still rolled back');
    });
  });

  // D ========================================================================
  test('D: after a rollback and a restart, Settle, void and cancel finish '
      'exactly once; a second recovery changes nothing', () async {
    UnifiedBackupService.failWorkJournalClearForTesting = 1;
    await expectLater(restore(), throwsA(isA<RestoreFailedException>()));

    await recoverEverything();
    expect(stock('A'), 8, reason: 'the Settle deduction, once');
    expect(stock('B'), 11, reason: 'the void return, once');
    expect(stock('C'), 13, reason: 'the cancel return, once');
    expect(rows(), 3, reason: 'one movement row per unit');
    expect(orders().containsKey('o1'), isFalse,
        reason: 'the void finished on the ORIGINAL order');
    expect(tables().get('T5')!.status, 'Available');
    expect(journal().keys, ['grn:gi1'],
        reason: 'only the goods-receipt intent is left, for its own resume');

    final once = world();
    await recoverEverything();
    expect(world(), once, reason: 'a second recovery changes nothing');
  });

  test('a write failure before the clear leaves the journal untouched',
      () async {
    final journalBefore = journalState();
    UnifiedBackupService.failWritingKeyForTesting = 'restaurantSessions';

    await expectLater(
      restore(),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );
    expect(journalState(), journalBefore);
    UnifiedBackupService.failWritingKeyForTesting = null;
  });

  // Last: a failed data rollback leaves boxes in an unknown state.
  group('the outcome when the business-data rollback is not verified', () {
    tearDown(() {
      UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    });

    test('data not verified, journal put back', () async {
      UnifiedBackupService.failWorkJournalClearForTesting = 0;
      UnifiedBackupService.failRollbackWritingKeyForTesting = 'categories';

      Object? error;
      try {
        await restore();
      } catch (e) {
        error = e;
      }
      final failure = error as RestoreFailedException;
      expect(failure.dataRolledBack, isFalse);
      expect(failure.journalRestored, isTrue);
      expect(failure.rolledBack, isFalse);
      expect(failure.unrestoredJournal, isNull);
      expect(failure.userMessage, contains('could NOT be fully put back'));
      expect(failure.userMessage, isNot(contains('unfinished stock work')));
      expect(failure.toString(),
          contains('dataRolledBack: false, journalRestored: true'));
      expect(journal().length, 4);
    });

    test('both fail: both flags false, both stated', () async {
      UnifiedBackupService.failWorkJournalClearForTesting = 2;
      UnifiedBackupService.failWorkJournalPutBackForTesting = true;
      UnifiedBackupService.failRollbackWritingKeyForTesting = 'categories';

      Object? error;
      try {
        await restore();
      } catch (e) {
        error = e;
      }
      final failure = error as RestoreFailedException;
      expect(failure.dataRolledBack, isFalse);
      expect(failure.journalRestored, isFalse);
      expect(failure.rolledBack, isFalse);
      expect(failure.unrestoredJournalEntries, hasLength(4));
      expect(failure.userMessage, contains('could NOT be fully put back'));
      expect(failure.userMessage,
          contains('4 entries of unfinished stock work in the Restaurant '
              'stock journal could not be put back'));
      expect(failure.toString(),
          contains('dataRolledBack: false, journalRestored: false'));
    });
  });
}
