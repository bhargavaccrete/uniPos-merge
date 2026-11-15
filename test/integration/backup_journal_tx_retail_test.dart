import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/retail_checkout_commit.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/cart_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// The pending-work journal clear is part of the restore transaction
/// (Retail): the restored data and the emptied checkout journal succeed
/// together, or the business data AND every original checkout entry go back,
/// so the original sale still finishes exactly once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;
  const now = '2026-11-15T10:00:00.000';

  Box<VarianteModel> variants() =>
      Hive.box<VarianteModel>(HiveBoxNames.variants);
  Box<SaleModel> sales() => Hive.box<SaleModel>(HiveBoxNames.sales);
  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box journal() => Hive.box(HiveBoxNames.retailCheckoutJournal);
  Box<StockMovementModel> movements() =>
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  String journalState() => jsonEncode({
        for (final k in (journal().keys.map((k) => k.toString()).toList()
          ..sort()))
          k: journal().get(k),
      });

  /// A fresh app process over what is on disk.
  Future<void> restart() async {
    await locator.reset();
    locator
      ..registerSingleton<ProductStore>(ProductStore())
      ..registerSingleton<BundleRepository>(BundleRepository())
      ..registerSingleton<AuthService>(AuthService())
      ..registerSingleton<CustomerStore>(CustomerStore(CustomerRepository()))
      ..registerSingleton<GstService>(GstService())
      ..registerSingleton<BusinessDetailsRepository>(BusinessDetailsRepository())
      ..registerSingleton<AttributeStore>(AttributeStore())
      ..registerSingleton<SaleStore>(SaleStore())
      ..registerSingleton<NotificationStore>(
          NotificationStore(NotificationRepository()))
      ..registerLazySingleton<CartStore>(() => CartStore(CartRepository()));
    await productStore.ensureLoaded();
  }

  VarianteModel variant(double stock) => VarianteModel(
      varianteId: 'v1', productId: 'pv1', stockQty: stock, createdAt: now,
      status: 'active');

  CartItemModel line() => CartItemModel(
        cartItemId: 'c1',
        variantId: 'v1',
        productId: 'pv1',
        productName: 'Tea',
        price: 100,
        qty: 2,
        total: 200,
        addedAt: now,
      );

  RetailCheckoutEntry entry(String saleId) => RetailCheckoutEntry(
        saleId: saleId,
        invoiceNumber: 'INV-$saleId',
        tabId: null,
        staffName: 'Ravi',
        sessionId: null,
        createdAt: DateTime(2026, 11, 15, 10),
        lines: [line()],
        posting: null,
      );

  /// This device: its own stock and session, sale S1 saved but its stock not
  /// yet deducted (pending entry), and an entry for S2 whose sale never
  /// landed.
  Future<void> seedDevice() async {
    await variants().put('v1', variant(10));
    await sessions().clear();
    await sessions().put(
        'sess-device',
        RestaurantSessionModel(
            sessionId: 'sess-device',
            startTime: DateTime(2026, 11, 15, 8),
            openingCash: 300));
    await sales().clear();
    await sales().put(
      'S1',
      SaleModel(
        saleId: 'S1',
        totalItems: 2,
        subtotal: 200,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: 200,
        paymentType: 'cash',
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await movements().clear();
    await journal().clear();
    await entry('S1').save();
    await entry('S2').save();
    await restart();
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_journal_tx_retail_');
    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await restart();

    // The backup: the product with other stock, its own session, no sales.
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
        'pv1',
        ProductModel(
            productId: 'pv1', productName: 'Tea', category: '',
            hasVariants: false, createdAt: now, updateAt: now));
    await variants().put('v1', variant(40));
    await sessions().put(
        'sess-backup',
        RestaurantSessionModel(
            sessionId: 'sess-backup',
            startTime: DateTime(2026, 11, 14, 8),
            openingCash: 1000));
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
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

  double stock() => variants().get('v1')!.stockQty;
  String world() =>
      [stock(), movements().length, sales().keys.toList(), journalState()]
          .join('|');

  test('A: a successful restore empties the checkout journal, no warning',
      () async {
    expect(journal().length, 2);
    await restore();

    expect(journal().isEmpty, isTrue);
    expect(stock(), 40);
    expect(sessions().keys, ['sess-backup']);
    expect(UnifiedBackupService.lastRestorePostRestoreWarnings, isEmpty);

    await restart();
    await RetailCheckoutCommit.recoverAll();
    expect([stock(), movements().length], [40, 0],
        reason: 'nothing replays onto the restored data');
  });

  test('B: a failed clear rolls everything back; every entry is still there',
      () async {
    final before = await deviceState(tempDir);
    final journalBefore = journalState();
    UnifiedBackupService.failWorkJournalClearForTesting = 0;

    await expectLater(
      restore(),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );
    expect(await deviceState(tempDir), before);
    expect(journalState(), journalBefore);
    expect(stock(), 10);
  });

  group('C: a clear that fails part-way', () {
    test('every original entry is put back on rollback', () async {
      final before = await deviceState(tempDir);
      final journalBefore = journalState();
      UnifiedBackupService.failWorkJournalClearForTesting = 1;

      await expectLater(
        restore(),
        throwsA(isA<RestoreFailedException>()
            .having((e) => e.rolledBack, 'rolledBack', isTrue)),
      );
      expect(journalState(), journalBefore);
      expect(await deviceState(tempDir), before);
    });

    test('if putting it back fails: business data verified, journal not',
        () async {
      UnifiedBackupService.failWorkJournalClearForTesting = 1;
      UnifiedBackupService.failWorkJournalPutBackForTesting = true;

      Object? error;
      try {
        await restore();
      } catch (e) {
        error = e;
      }
      final failure = error as RestoreFailedException;
      expect(failure.rolledBack, isFalse);
      expect(failure.dataRolledBack, isTrue);
      expect(failure.journalRestored, isFalse);
      expect(failure.unrestoredJournal, 'Retail checkout journal');
      expect(failure.unrestoredJournalEntries.keys.toSet(), {'S1', 'S2'});
      expect(failure.userMessage,
          contains('Your business data was put back and checked'));
      expect(failure.userMessage,
          contains('2 entries of unfinished stock work in the Retail checkout '
              'journal could not be put back'));
      expect(failure.userMessage, isNot(contains('could NOT be fully put back')));
      expect(journal().length, 1, reason: 'the part-way clear did happen');
      expect(sessions().keys, ['sess-device'],
          reason: 'the business data itself was rolled back');
    });
  });

  test('D/E: after a rollback and a restart, existing Retail recovery finishes '
      'S1 exactly once and discards S2; a second recovery changes nothing',
      () async {
    UnifiedBackupService.failWorkJournalClearForTesting = 1;
    await expectLater(restore(), throwsA(isA<RestoreFailedException>()));

    await restart();
    final failures = await RetailCheckoutCommit.recoverAll();
    expect(failures, isEmpty);
    expect(stock(), 8, reason: 'S1 deducted once, from the ORIGINAL stock');
    expect(movements().length, 1);
    expect(sales().keys, ['S1'], reason: 'S2 never landed; nothing invented');
    expect(journal().isEmpty, isTrue);

    final once = world();
    await restart();
    await RetailCheckoutCommit.recoverAll();
    expect(world(), once);
  });

  // Last: a failed data rollback leaves boxes in an unknown state.
  test('both rollbacks fail: both flags false, both stated', () async {
    UnifiedBackupService.failWorkJournalClearForTesting = 1;
    UnifiedBackupService.failWorkJournalPutBackForTesting = true;
    UnifiedBackupService.failRollbackWritingKeyForTesting = 'products';
    try {
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
      expect(failure.userMessage, contains('could NOT be fully put back'));
      expect(failure.userMessage,
          contains('2 entries of unfinished stock work in the Retail checkout '
              'journal could not be put back'));
      expect(failure.toString(),
          contains('dataRolledBack: false, journalRestored: false'));
    } finally {
      UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    }
  });
}
